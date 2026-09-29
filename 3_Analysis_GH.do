/*______________________________________________________________________________________
|                                                                                       |
|              Social Tipping Points in Climate Migration - Ghana                       |
|              																			|
| Routine to undertake threshold analysis following Card, Mas & Rothstein (2008):       |
|																						|
| a) Descriptive statistics 												            |
| b) Stage one: Threshold search                                                        |
| c) Stage two: Regression discontinuity tests at the selected threshold 	            |
| d) Continuous cubic function in SPEI: OLS and fractional logit						|
|_______________________________________________________________________________________|*/

*=======================================================================================================================================
* Preamble
*=======================================================================================================================================

version 19            // Routine run in Stata 19.5
set rng mt64          // Makes the random-number generator explicit for the splits

*net install rdrobust, from(https://raw.githubusercontent.com/rdpackages/rdrobust/master/stata) replace
which rdrobust		  // Version 11.1.0 (22 May 2026)
which rdplot		  // Version 11.1.0 (22 May 2026)

clear all
set more off

if "`c(username)'" == "mdfg501" {
    global ROOT C:\Users\mdfg501\OneDrive
}
else {
    global ROOT C:\Users\maric\OneDrive
}
global INPUT  $ROOT\Documents\Exeter\HABITABLE\WP1\Papers\SocialTippingPoints\Data
global OUTPUT $ROOT\Documents\Exeter\HABITABLE\WP1\Papers\SocialTippingPoints\Output\v2
capture mkdir "$OUTPUT"

*=======================================================================================================================================
* Settings
*=======================================================================================================================================

* Country
local cc        "GH"                  // GH | MA | KE | ET
local cname     "Ghana"               // Ghana | Mali | Kenya | Ethiopia
local combine   0                     // 1 on the last run: four-panel figures + pooled files

* Variables
local y         outmig_rate_s2        // Dependent variable
local x         SPEI12_year_s2        // Running variable
local clvar     adm4                  // Site identifier: xtset panel unit, clustering unit, and the unit split 2/3-1/3
local reg       reg2                  // Region dummy
local lagvars   "outmig_rate_s2 female_s2 nomarry_s2 noedu_s2 age_s2 SPEI12_year_s2"

* Covariates
// rdrobust's covs() does not accept factor-variable operators: year dummies are spelled out. year1 = 2012 is lost to the lags and year2 = 2013 is the base.
local covs_rd   "loutmig_rate_s2 lfemale_s2 lnomarry_s2 lnoedu_s2 lage_s2 year3 year4 year5 year6 year7 year8 year9 year10 year11 `reg'"
// regress / fracreg / margins accept factor variables
local covs_reg  "loutmig_rate_s2 lfemale_s2 lnomarry_s2 lnoedu_s2 lage_s2 i.year `reg'"
local yscale    100                   // Dependent variable is in percent

* Design
local trend        3        // Smooth control in stage one: 0 none, 1 linear, 3 cubic
local srch_lo      10       // Search window percentiles
local srch_hi      90
local drought_only 1        // 1 = candidate thresholds restricted to SPEI < 0
local p_list       1 2 3    // Local polynomial orders for the full-sample RD
local p_placebo    1 3      // Orders for the placebo tests
local p_split      1        // Order for the split-sample test and the RD plots
local nsplits      100      // Random 2/3-1/3 splits
local seed         20260922 // Same seed for every country (disjoint data)
local near         0.1      // Split thresholds within +/- `near' of c* count as "near"
local fracreg      1        // 1 = also estimate equation (3) as a fractional logit

local crit = -2*ln(1 - sqrt(0.95))    // Hansen (2000) 95% critical value = 7.3523

*=======================================================================================================================================
* Programs
*=======================================================================================================================================

// tp_search: stage-one threshold search
// Returns r(tp), r(r2), r(atedge), r(ncand), r(lo), r(hi)
// With profile(name), posts every candidate to that postfile handle: (c) (r2) (ssr) (n) (tstat)
   
capture program drop tp_search
program define tp_search, rclass
    syntax [if], y(name) x(name) reg(string) cluster(name) trend(integer) ///
        lo(real) hi(real) drought(integer) [profile(string)]

    preserve
    if `"`if'"' != "" quietly keep `if'
    quietly keep if !missing(`y', `x', `reg')

    _pctile `x', p(5 `lo' `hi' 95)
    local t_lo = r(r1)
    local s_lo = r(r2)
    local s_hi = r(r3)
    local t_hi = r(r4)
    quietly keep if inrange(`x', `t_lo', `t_hi')

    local tterms ""
    if `trend' == 1 local tterms "c.`x'"
    if `trend' == 3 local tterms "c.`x'##c.`x'##c.`x'"

    * Clustered SEs only when the profile (and its significance markers) is wanted
    local vceopt ""
    if "`profile'" != "" local vceopt "vce(cluster `cluster')"

    * Rank distinct SPEI values so each threshold matches an observed value exactly
    egen long rk = group(`x')
    quietly summarize rk, meanonly
    local maxrk = r(max)

    local best_r2 = -1
    local best_c  = .
    local c_min   = .
    local c_max   = .
    local ncand   = 0

    forvalues r = 1/`maxrk' {
        quietly summarize `x' if rk == `r', meanonly
        local c = r(mean)
        if (`c' < `s_lo' | `c' > `s_hi') continue
        if (`drought' == 1 & `c' >= 0) continue

        capture drop d
        * 1(SPEI < c): drier side. Observations at c belong to the wetter side, as in rdrobust (x >= c on the right), so both stages
		* split the sample identically at c*.
        quietly gen byte d = (rk < `r')
        capture quietly regress `y' i.d `reg' `tterms', `vceopt'
        if _rc == 0 {
            local ++ncand
            if missing(`c_min') local c_min = `c'
            local c_max = `c'
            if "`profile'" != "" {
                mat coef = r(table)
                post `profile' (`c') (e(r2)) (e(rss)) (e(N)) (el(coef,3,2))
            }
            if e(r2) > `best_r2' {
                local best_r2 = e(r2)
                local best_c  = `c'
            }
        }
    }
    restore

    return scalar tp     = `best_c'
    return scalar r2     = `best_r2'
    return scalar atedge = (`best_c' == `c_min' | `best_c' == `c_max')
    return scalar ncand  = `ncand'
    return scalar lo     = `c_min'
    return scalar hi     = `c_max'
end

// rd_post: one rdrobust call, results appended to a postfile
// MDE (80% power, 5% two-sided) = (1.96 + 0.84) x robust SE
// Also stores the wetter-side intercept at c* (ywet), a local baseline level
   
capture program drop rd_post
program define rd_post
    syntax varname [if], x(name) cluster(name) c(real) p(integer) ///
        post(string) test(string) sample(string) [covs(string) quietly]

    local covopt ""
    if "`covs'" != "" local covopt "covs(`covs')"
    local noi = cond("`quietly'" != "", "quietly", "noisily")

    capture `noi' rdrobust `varlist' `x' `if', c(`c') p(`p') kernel(tri) ///
        bwselect(msetwo) `covopt' vce(cluster `cluster') masspoints(adjust) all

    if _rc == 0 {
        * To account for names differing across rdrobust versions
        local tau_cl = e(tau_cl)
        local se_cl  = e(se_tau_cl)
        local tau_bc = e(tau_bc)
        local se_rb  = e(se_tau_rb)
        local pv_rb  = e(pv_rb)
        local cil    = e(ci_l_rb)
        local cir    = e(ci_r_rb)
        local nl     = e(N_h_l)
        local nr     = e(N_h_r)
        if missing(`nl')     local nl = e(N_l)
        if missing(`nr')     local nr = e(N_r)
        if missing(`tau_bc') local tau_bc = `tau_cl'
        if missing(`se_rb')  local se_rb  = `se_cl'
        if missing(`pv_rb')  local pv_rb  = 2*normal(-abs(`tau_bc'/`se_rb'))
        if missing(`cil')    local cil    = `tau_bc' - invnormal(0.975)*`se_rb'
        if missing(`cir')    local cir    = `tau_bc' + invnormal(0.975)*`se_rb'
        local mde = (invnormal(0.975) + invnormal(0.80)) * `se_rb'

        * Wetter-side (above the cut-off) intercept
        local ywet = .
        capture matrix Bw = e(beta_Y_p_r)
        if _rc capture matrix Bw = e(beta_p_r)
        if !_rc local ywet = el(Bw, 1, 1)

        post `post' ("`test'") ("`sample'") ("`varlist'") (`p') (`c') ///
            (`tau_cl') (`se_cl') (`tau_bc') (`se_rb') (`pv_rb') ///
            (`cil') (`cir') (e(h_l)) (e(h_r)) (`nl') (`nr') (`mde') (`ywet')
    }
    else {
        post `post' ("`test'") ("`sample'") ("`varlist'") (`p') (`c') ///
            (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
    }
end

*=======================================================================================================================================
* Data
*=======================================================================================================================================

use "$INPUT\ADM_`cc'.dta", clear
keep if year >= 2012 & year <= 2022

* Lags built before any trimming
xtset `clvar' year, yearly
foreach v of local lagvars {
    capture drop l`v'
    gen double l`v' = L.`v'
}
xtset, clear

* Permanent intermediate files
local f_profile "$OUTPUT\Profile_`cc'_raw.dta"
local f_results "$OUTPUT\RDresults_`cc'_raw.dta"
local f_splits  "$OUTPUT\Splits_`cc'_raw.dta"
local f_eq2     "$OUTPUT\Eq2_`cc'_raw.dta"

*=======================================================================================================================================
* Descriptives
*=======================================================================================================================================

di as txt _n(2) "{hline 78}" _n "`cname': descriptives" _n "{hline 78}"
summarize `y' `x', detail

quietly count if !missing(`y', `x')
local n_sy = r(N)
capture drop tagsite
egen byte tagsite = tag(`clvar') if !missing(`y', `x')
quietly count if tagsite == 1
local n_sites = r(N)
drop tagsite

quietly summarize `x'
local x_mean = r(mean)
local x_sd   = r(sd)
local x_min  = r(min)
local x_max  = r(max)
quietly count if !missing(`x')
local n_x = r(N)
foreach t in 1 15 2 {
    local tv = -`t'/cond(`t' == 15, 10, 1)
    quietly count if `x' < `tv' & !missing(`x')
    local sh`t' = 100*r(N)/`n_x'
    di as txt "Share of site-years with SPEI < `tv': " as res %5.1f `sh`t'' "%"
}

* AR(1) of annual SPEI-12 (persistence of drought)
local ar1 = .
capture quietly regress `x' l`x', vce(cluster `clvar')
if _rc == 0 local ar1 = _b[l`x']
di as txt "AR(1) coefficient of SPEI-12:     " as res %6.3f `ar1'

quietly summarize `y'
local ybar = r(mean)
di as txt "Mean outmigration rate:           " as res %6.3f `ybar'

preserve
clear
set obs 1
gen str2   country   = "`cc'"
gen long   site_years = `n_sy'
gen long   sites     = `n_sites'
gen double spei_mean = `x_mean'
gen double spei_sd   = `x_sd'
gen double spei_min  = `x_min'
gen double spei_max  = `x_max'
gen double pct_below_m1   = `sh1'
gen double pct_below_m1_5 = `sh15'
gen double pct_below_m2   = `sh2'
gen double spei_ar1  = `ar1'
gen double ymean     = `ybar'
save "$OUTPUT\Descriptives_`cc'.dta", replace
export delimited using "$OUTPUT\Descriptives_`cc'.csv", replace
restore

gen sh1 = (SPEI12_year_s2<-1)
	label var sh1 "Share of cluster-years with SPEI<-1"

gen sh15 = (SPEI12_year_s2<-1.5)
	label var sh15 "Share of cluster-years with SPEI<-1.5"
	
gen sh2 = (SPEI12_year_s2<-2)
	label var sh2 "Share of cluster-years with SPEI<-2"
	
estpost tabstat `y' `x' sh1 sh15 sh2 female_s2 nomarry_s2 noedu_s2 age_s2, statistics(mean sd min max count) columns(statistics) 
	estout using "$OUTPUT\Descriptives.xls", replace cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2)) count(fmt(0))") 

*=======================================================================================================================================
* Stage one: Threshold search
*=======================================================================================================================================

capture postclose pp
postfile pp double(c r2 ssr n tstat) using "`f_profile'", replace

tp_search, y(`y') x(`x') reg(`reg') cluster(`clvar') trend(`trend') ///
    lo(`srch_lo') hi(`srch_hi') drought(`drought_only') profile(pp)
postclose pp

local tp     = r(tp)
local tp_r2  = r(r2)
local atedge = r(atedge)
local ncand  = r(ncand)
local tplab : display %6.3f `tp'

di as txt _n(2) "{hline 78}" _n "`cname': stage one" _n "{hline 78}"
di as txt "Candidate thresholds evaluated: " as res `ncand'
di as txt "Search window in SPEI units:    [" as res %6.3f r(lo) as txt ", " as res %6.3f r(hi) as txt "]"
di as txt "Selected threshold:             " as res %9.4f `tp' as txt "   R2 = " as res %6.4f `tp_r2'
di as txt "Maximum at edge of window:      " as res `atedge' as txt "   (1 = boundary solution, treat with caution)"

* LR statistic and indicative 95% confidence set

preserve
use "`f_profile'", clear
quietly count
if r(N) == 0 {
    di as error "Stage one posted no candidates - check the search window and variable names"
    exit 498
}
quietly summarize ssr
local ssr_min = r(min)
gen double LR = n * (ssr - `ssr_min') / `ssr_min'
gen byte in_cs = (LR <= `crit')
gen byte sig   = (abs(tstat) > 1.96 & tstat < .)

quietly summarize LR
local lrmax = r(max)
local lrlab : display %4.1f `lrmax'

sort c
quietly count if in_cs
local n_cs = r(N)
gen byte seg_start = in_cs & (_n == 1 | in_cs[_n-1] == 0)
quietly count if seg_start
local n_seg = r(N)
quietly summarize c if in_cs
local cs_lo = r(min)
local cs_hi = r(max)
di as txt "Indicative 95% LR confidence set: [" as res %6.3f `cs_lo' as txt ", " as res %6.3f `cs_hi' ///
    as txt "] covering " as res `n_cs' as txt " of " as res `ncand' as txt " candidates in " as res `n_seg' as txt " segment(s)"
di as txt "Maximum LR in search window:      " as res %6.2f `lrmax'
quietly count if sig
di as txt "Candidates with a significant step: " as res r(N) as txt " of " as res `ncand'

save "$OUTPUT\Profile_`cc'.dta", replace
export delimited using "$OUTPUT\Profile_`cc'.csv", replace

* R2 profile

twoway (line r2 c, sort lcolor(gs12) lwidth(thin)) ///
       (scatter r2 c if sig==0, msymbol(Oh) mcolor(gs9) msize(small)) ///
       (scatter r2 c if sig==1, msymbol(O) mcolor(teal) msize(small)), ///
       xline(`tp', lpattern(dash) lcolor(red)) ///
       xtitle("Candidate SPEI threshold", size(small)) ytitle("R{superscript:2}", size(small)) ///
       xlabel(, labsize(small)) ylabel(, labsize(small)) legend(off) ///
       note("Dashed line: selected threshold = `tplab'", size(small)) ///
       title("`cname'") graphregion(color(white))
    graph save   "$OUTPUT\R2profile_`cc'", replace
    graph export "$OUTPUT\R2profile_`cc'.png", width(2000) replace

* LR profile

twoway (line LR c, sort lcolor(teal) lwidth(medthick)) ///
       (scatter LR c if in_cs, msymbol(O) mcolor(cranberry) msize(vsmall)), ///
       yline(`crit', lpattern(dash) lcolor(red)) xline(`tp', lpattern(dash) lcolor(gs8)) ///
       xtitle("Candidate SPEI threshold", size(small)) ytitle("LR statistic", size(small)) ///
       xlabel(, labsize(small)) ylabel(0(5)25, labsize(small)) yscale(range(0 25)) ///
       legend(off) ///
       note("Dashed red line: 95% critical value (Hansen 2000). Maximum LR = `lrlab'", size(small)) ///
       title("`cname'") graphregion(color(white))
    graph save   "$OUTPUT\LRprofile_`cc'", replace
    graph export "$OUTPUT\LRprofile_`cc'.png", width(2000) replace
restore

* Stage-one summary

preserve
clear
set obs 1
gen str2   country = "`cc'"
gen double tp      = `tp'
gen double r2      = `tp_r2'
gen byte   atedge  = `atedge'
gen int    ncand   = `ncand'
gen double cs_lo   = `cs_lo'
gen double cs_hi   = `cs_hi'
gen int    cs_segments = `n_seg'
gen double lr_max  = `lrmax'
save "$OUTPUT\Stage1_`cc'.dta", replace
export delimited using "$OUTPUT\Stage1_`cc'.csv", replace
restore

*=======================================================================================================================================
* Stage two: Regression discontinuity tests at the selected threshold
*=======================================================================================================================================

capture postclose rp
postfile rp str14 test str12 sample str20 outcome int p ///
    double(c tau_cl se_cl tau_bc se_rb pv_rb ci_l_rb ci_r_rb h_l h_r N_l N_r mde ywet) ///
    using "`f_results'", replace

di as txt _n(2) "{hline 78}" _n "`cname': stage two - local RD at " %8.4f `tp' _n "{hline 78}"
foreach p of local p_list {
    * Main specification: no covariates
    rd_post `y', x(`x') cluster(`clvar') c(`tp') p(`p') ///
        post(rp) test("Local RD") sample("Full")
    * Robustness: covariate-adjusted
    rd_post `y', x(`x') cluster(`clvar') c(`tp') p(`p') covs(`covs_rd') ///
        post(rp) test("Local RD") sample("Full +covs")
}

* Placebos (unadjusted)

di as txt _n(2) "{hline 78}" _n "`cname': placebo tests at " %8.4f `tp' _n "{hline 78}"
foreach p of local p_placebo {
    * (a) lagged outmigration
    rd_post loutmig_rate_s2, x(`x') cluster(`clvar') c(`tp') p(`p') ///
        post(rp) test("Placebo") sample("Full")
    * (b) lagged SPEI
    rd_post l`x', x(`x') cluster(`clvar') c(`tp') p(`p') ///
        post(rp) test("Placebo") sample("Full")
}

* Split-sample test (unadjusted)

di as txt _n(2) "{hline 78}" _n "`cname': split-sample test, `nsplits' split(s)" _n "{hline 78}"
capture postclose sp
postfile sp int split double(tp_s r2_s atedge_s tau_bc se_rb pv_rb ci_l_rb ci_r_rb mde n_test) ///
    using "`f_splits'", replace

forvalues s = 1/`nsplits' {
    set seed `=`seed' + `s''
    capture drop u search
    sort `clvar' year, stable
    by `clvar': gen double u = runiform() if _n == 1
    bysort `clvar' (u): replace u = u[1]
    gen byte search = (u < 2/3)

    quietly tp_search if search == 1, y(`y') x(`x') reg(`reg') cluster(`clvar') ///
        trend(`trend') lo(`srch_lo') hi(`srch_hi') drought(`drought_only')
    local tp_s     = r(tp)
    local r2_s     = r(r2)
    local atedge_s = r(atedge)

    * To keep the first split so its test sample can be plotted below
    if `s' == 1 {
        local tp_s1 = `tp_s'
        capture drop search1
        gen byte search1 = search
    }

    capture quietly rdrobust `y' `x' if search == 0, c(`tp_s') p(`p_split') kernel(tri) ///
        bwselect(msetwo) vce(cluster `clvar') masspoints(adjust) all
    if _rc == 0 {
        local b   = cond(missing(e(tau_bc)), e(tau_cl), e(tau_bc))
        local se  = cond(missing(e(se_tau_rb)), e(se_tau_cl), e(se_tau_rb))
        local pv  = cond(missing(e(pv_rb)), 2*normal(-abs(`b'/`se')), e(pv_rb))
        local cil = cond(missing(e(ci_l_rb)), `b' - invnormal(0.975)*`se', e(ci_l_rb))
        local cir = cond(missing(e(ci_r_rb)), `b' + invnormal(0.975)*`se', e(ci_r_rb))
        local nn  = cond(missing(e(N_h_l)), e(N_l)+e(N_r), e(N_h_l)+e(N_h_r))
        post sp (`s') (`tp_s') (`r2_s') (`atedge_s') (`b') (`se') (`pv') ///
            (`cil') (`cir') ((invnormal(0.975)+invnormal(0.80))*`se') (`nn')
    }
    else {
        post sp (`s') (`tp_s') (`r2_s') (`atedge_s') (.) (.) (.) (.) (.) (.) (.)
    }
    if mod(`s', 10) == 0 di as txt "  ... split `s' of `nsplits'"
}
postclose sp

*=======================================================================================================================================
* RD Plots
*=======================================================================================================================================

* Full sample at the selected threshold

rdplot `y' `x', c(`tp') p(`p_split') binselect(esmv) kernel(tri) ci(95) ///
    masspoints(adjust) ///
    graph_options(title("`cname'") ///
        xtitle("SPEI-12", size(small)) ytitle("Outmigration rate", size(small)) ///
        note("Threshold = `tplab'; bins selected by evenly-spaced, mimicking variance", size(small)) ///
        legend(off) graphregion(color(white)))
    graph save   "$OUTPUT\RDplot_`cc'", replace
    graph export "$OUTPUT\RDplot_`cc'.png", width(2000) replace

* Test sample of the first split, at the threshold chosen on its search sample

local tps1lab : display %6.3f `tp_s1'
capture rdplot `y' `x' if search1 == 0, c(`tp_s1') p(`p_split') binselect(esmv) ///
    kernel(tri) ci(95) masspoints(adjust) ///
    graph_options(title("`cname' - test sample (1/3)") ///
        xtitle("SPEI-12", size(small)) ytitle("Outmigration rate", size(small)) ///
        note("Threshold `tps1lab' located on the 2/3 search sample", size(small)) ///
        legend(off) graphregion(color(white)))
    if _rc == 0 {
        graph save   "$OUTPUT\RDplot_split_`cc'", replace
        graph export "$OUTPUT\RDplot_split_`cc'.png", width(2000) replace
    }

* Placebo: lagged outmigration at the same threshold

rdplot loutmig_rate_s2 `x', c(`tp') p(`p_split') binselect(esmv) kernel(tri) ci(95) ///
    masspoints(adjust) ///
    graph_options(title("`cname' - placebo: lagged outmigration") ///
        xtitle("SPEI-12", size(small)) ytitle("Lagged outmigration rate", size(small)) ///
        note("Threshold = `tplab'", size(small)) ///
        legend(off) graphregion(color(white)))
    graph save   "$OUTPUT\RDplot_placebo_`cc'", replace
    graph export "$OUTPUT\RDplot_placebo_`cc'.png", width(2000) replace

*=======================================================================================================================================
* Continuous cubic polynomial
*=======================================================================================================================================

di as txt _n(2) "{hline 78}" _n "`cname': equation 3.3, cubic in SPEI" _n "{hline 78}"
capture postclose eq
postfile eq str8 model double(b1 se1 b2 se2 b3 se3 p_joint N) using "`f_eq2'", replace

regress `y' c.`x'##c.`x'##c.`x' `covs_reg', vce(cluster `clvar')
estimates store eq2_`cc'
test c.`x'#c.`x' c.`x'#c.`x'#c.`x'
local pj = r(p)
di as txt "OLS: joint test of the quadratic and cubic terms: p = " as res %6.4f `pj'
post eq ("OLS") (_b[`x']) (_se[`x']) (_b[c.`x'#c.`x']) (_se[c.`x'#c.`x']) ///
    (_b[c.`x'#c.`x'#c.`x']) (_se[c.`x'#c.`x'#c.`x']) (`pj') (e(N))

quietly summarize `x', detail
local xlo = r(p5)
local xhi = r(p95)
local xl  = floor(`xlo'*2)/2
local xh  = ceil(`xhi'*2)/2
local atgrid "`=round(`xlo',0.1)'(0.1)`=round(`xhi',0.1)'"

* Predictions from the OLS version, averaged over observed covariates

margins, at(`x' = (`atgrid')) vsquish
marginsplot, recast(line) recastci(rarea) ciopts(color(teal%25) lwidth(none)) ///
    plotopts(lcolor(teal) lwidth(medthick)) ///
    xline(`tp', lpattern(dash) lcolor(red)) ///
    xlabel(`xl'(0.5)`xh', labsize(small)) ylabel(, labsize(small)) ///
    xtitle("SPEI-12", size(small)) ytitle("Predicted outmigration rate", size(small)) ///
    title("`cname'") graphregion(color(white))
    graph save   "$OUTPUT\Poly_`cc'", replace
    graph export "$OUTPUT\Poly_`cc'.png", width(2000) replace

if `fracreg' == 1 {
    * Fractional logit (Papke & Wooldridge 1996): E[y|x] = exp(xb)/(1+exp(xb)), estimated by quasi-ML. Predictions stay in [0,1] and exact zeros are allowed.
    capture drop y01
    gen double y01 = `y'/`yscale'
    fracreg logit y01 c.`x'##c.`x'##c.`x' `covs_reg', vce(cluster `clvar')
    estimates store eq2frac_`cc'
    test c.`x'#c.`x' c.`x'#c.`x'#c.`x'
    local pjf = r(p)
    di as txt "Fractional logit: joint test of the quadratic and cubic terms: p = " as res %6.4f `pjf'
    post eq ("FracLogit") (_b[`x']) (_se[`x']) (_b[c.`x'#c.`x']) (_se[c.`x'#c.`x']) ///
        (_b[c.`x'#c.`x'#c.`x']) (_se[c.`x'#c.`x'#c.`x']) (`pjf') (e(N))

    * Predictions rescaled to the rate
    margins, at(`x' = (`atgrid')) expression(predict()*`yscale') vsquish
    marginsplot, recast(line) recastci(rarea) ciopts(color(teal%25) lwidth(none)) ///
        plotopts(lcolor(teal) lwidth(medthick)) ///
        xline(`tp', lpattern(dash) lcolor(red)) ///
        xlabel(`xl'(0.5)`xh', labsize(small)) ylabel(, labsize(small)) ///
        xtitle("SPEI-12", size(small)) ytitle("Predicted outmigration rate", size(small)) ///
        title("`cname'") graphregion(color(white))
        graph save   "$OUTPUT\Poly_frac_`cc'", replace
        graph export "$OUTPUT\Poly_frac_`cc'.png", width(2000) replace
}
postclose eq

use "`f_eq2'", clear
gen str2 country = "`cc'"
order country
list, noobs abbrev(12)
save "$OUTPUT\Eq2_`cc'.dta", replace
export delimited using "$OUTPUT\Eq2_`cc'.csv", replace

*=======================================================================================================================================
* Results
*=======================================================================================================================================

postclose rp
use "`f_results'", clear
quietly count
di as txt "RD rows written: " as res r(N)

gen str2   country = "`cc'"
gen double ymean   = `ybar'

* Delta: outmigration just on the drier side of c* minus just on the wetter side.
// rdrobust reports above minus below; drought lies below the cut-off, so Delta is minus the rdrobust estimate. Delta > 0 = jump, Delta < 0 = dip. 
gen double delta    = -tau_bc
gen double delta_lo = -ci_r_rb
gen double delta_hi = -ci_l_rb

* Relative to the country mean. Not meaningful for the lagged-SPEI placebo, so set to missing.
gen double delta_pct    = 100*delta/ymean
gen double delta_lo_pct = 100*delta_lo/ymean
gen double delta_hi_pct = 100*delta_hi/ymean
gen double mde_pct      = 100*mde/ymean

* Relative to the wetter-side level at c* (local baseline)
gen double delta_pct_local = 100*delta/ywet
foreach v of varlist delta_pct delta_lo_pct delta_hi_pct mde_pct delta_pct_local {
    replace `v' = . if outcome == "l`x'"
}

order country test sample outcome p c delta se_rb pv_rb delta_lo delta_hi mde ///
    delta_pct delta_lo_pct delta_hi_pct mde_pct ymean ywet delta_pct_local
format c tau_cl se_cl tau_bc se_rb ci_l_rb ci_r_rb h_l h_r mde ywet ymean ///
    delta delta_lo delta_hi %8.3f
format delta_pct delta_lo_pct delta_hi_pct mde_pct delta_pct_local %6.1f
format pv_rb %6.3f
di as txt _n(2) "{hline 78}" _n "`cname': RD results at the full-sample threshold" _n "{hline 78}"
list test sample outcome p delta se_rb pv_rb delta_lo delta_hi mde mde_pct N_l N_r, ///
    noobs sep(0) abbrev(12)
save "$OUTPUT\RDresults_`cc'.dta", replace
export delimited using "$OUTPUT\RDresults_`cc'.csv", replace

*=======================================================================================================================================
* Results from split-sample summary
*=======================================================================================================================================

use "`f_splits'", clear
quietly count
di as txt "Split rows written: " as res r(N)
gen double delta    = -tau_bc
gen double delta_lo = -ci_r_rb
gen double delta_hi = -ci_l_rb

di as txt _n(2) "{hline 78}" _n "`cname': split-sample summary" _n "{hline 78}"
summarize tp_s, detail
quietly count if pv_rb < .
local nok = r(N)
quietly count if atedge_s == 1
local n_edge = r(N)
quietly count if abs(tp_s - `tp') <= `near' & !missing(tp_s)
local n_near = r(N)
quietly count if pv_rb < 0.05 & delta > 0 & !missing(delta)
local n_jump = r(N)
quietly count if pv_rb < 0.05 & delta < 0 & !missing(delta)
local n_dip  = r(N)
quietly summarize mde, detail
local mde_med = r(p50)
quietly summarize delta, detail
local d_med = r(p50)

di as txt "Splits with a boundary threshold:          " as res `n_edge' as txt " of " as res `nsplits'
di as txt "Split thresholds within `near' of c*:         " as res `n_near' as txt " of " as res `nsplits'
di as txt "Significant jumps (Delta > 0, 5%):         " as res `n_jump' as txt " of " as res `nok'
di as txt "Significant dips (Delta < 0, 5%):          " as res `n_dip'  as txt " of " as res `nok'
di as txt "Median Delta across splits:                " as res %6.3f `d_med'
di as txt "Median minimum detectable effect:          " as res %6.3f `mde_med'

histogram tp_s, width(0.05) frequency color(teal%60) xline(`tp', lcolor(red) lpattern(dash)) ///
    xtitle("Threshold selected in 2/3 search sample", size(small)) ytitle("Number of splits", size(small)) title("`cname'") ///
    graphregion(color(white))
    graph save   "$OUTPUT\SplitThresholds_`cc'", replace
    graph export "$OUTPUT\SplitThresholds_`cc'.png", width(2000) replace

save "$OUTPUT\Splits_`cc'.dta", replace
export delimited using "$OUTPUT\Splits_`cc'.csv", replace

preserve
clear
set obs 1
gen str2   country   = "`cc'"
gen double tp_full   = `tp'
gen int    nsplits   = `nsplits'
gen int    n_valid   = `nok'
gen int    n_edge    = `n_edge'
gen int    n_near    = `n_near'
gen double near_band = `near'
gen int    n_sig_jump = `n_jump'
gen int    n_sig_dip  = `n_dip'
gen double median_delta = `d_med'
gen double median_mde   = `mde_med'
save "$OUTPUT\SplitSummary_`cc'.dta", replace
export delimited using "$OUTPUT\SplitSummary_`cc'.csv", replace
restore

*=======================================================================================================================================
* Combining all countries' graphs
*=======================================================================================================================================

if `combine' == 1 {
    local ctry "GH MA KE ET"

    * Pooled results files
    foreach f in RDresults Stage1 Descriptives Eq2 SplitSummary {
        clear
        foreach k of local ctry {
            capture confirm file "$OUTPUT/`f'_`k'.dta"
            if _rc == 0 append using "$OUTPUT/`f'_`k'.dta"
        }
        save "$OUTPUT/`f'_all.dta", replace
        export delimited using "$OUTPUT/`f'_all.csv", replace
    }

    * Four-panel figures
    foreach g in LRprofile RDplot RDplot_placebo R2profile RDplot_split {
        local gl ""
        foreach k of local ctry {
            capture confirm file "$OUTPUT/`g'_`k'.gph"
            if _rc == 0 local gl `"`gl' "$OUTPUT/`g'_`k'""'
        }
        graph combine `gl', cols(2) graphregion(color(white))
        graph export "$OUTPUT/`g'_all.png", width(2400) replace
    }

    local gl ""
    foreach k of local ctry {
        local gl `"`gl' "$OUTPUT\SplitThresholds_`k'""'
    }
    graph combine `gl', cols(2) graphregion(color(white)) ///
        note("Dashed line: full-sample threshold", size(small))
    graph export "$OUTPUT\SplitThresholds_all.png", width(2400) replace

    foreach g in Poly Poly_frac {
        local gl ""
        foreach k of local ctry {
            capture confirm file "$OUTPUT/`g'_`k'.gph"
            if _rc == 0 local gl `"`gl' "$OUTPUT/`g'_`k'""'
        }
        if `"`gl'"' != "" {
            graph combine `gl', cols(2) graphregion(color(white)) ///
                note("Dashed line: stage-one threshold", size(small))
            graph export "$OUTPUT/`g'_all.png", width(2400) replace
        }
    }
}
