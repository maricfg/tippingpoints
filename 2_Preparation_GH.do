/*______________________________________________________________________________________
|                                                     									|
|							Social Tipping Points - Ghana								|	
|  Routine to assembly datasets on climate variability and internal migration.			|
|_______________________________________________________________________________________|*/

clear all
set more off, perm
set graphics off
set maxvar 10000

if "`c(username)'" == "mdfg501" {
		 global ROOT C:\Users\mdfg501\OneDrive
	}
	else {    
		 global ROOT C:\Users\maric\OneDrive
	}	
global INPUT $ROOT\Documents\Exeter\HABITABLE\WP1\DataManagement\Data\Raw
global OUTPUT $ROOT\Documents\Exeter\HABITABLE\WP1\Papers\SocialTippingPoints\Data
*****************************************************************************************************************************************************


*********************************************************** W1 *************************************************************

// Create unique identifier
program habitableid 
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 1000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
end

* Intro

use "$INPUT\Ghana\Ghana Raw\Intro.dta", clear
	habitableid
	rename kinrel_other1 kinrel_other

// No admin level 4, generate one to make it the same structure as in other countries
rename adm3 adm4
	gen adm3 = .
	order adm3, after (adm2)
	label var adm3 "Subdistrict"
	
// Generate country variable to help later when data sets are combined
gen country = 1
	label var country "Country"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia" 5 "Thailand"
	label val country country
	order country, before (adm1)

// Generate wave variable
gen wave = 1
	label var wave "Data collected in wave 1 (2022) or wave 2 (2023)"
	order wave, before (country)

// Generate number of children
replace adults = hhsize if adults>hhsize & adults<. // Some households have more adult members than total hhsize - 7 obs
	gen children = hhsize - adults
	label var children "Number of children in the household"
	order children, after (adults)
	rename adults nadult
	label var hhsize "Household size"
	label var nadult "Number of adults in the household"
	
// Ethnicity other - correct different spelling
recode reseth (1=101) (2=102) (3=103) (4=104) (5=105) (6=106) (7=107) (8=108)	
	label var reseth "Ethnicity of respondent"
	label define ethnicity 101 "Akan" 102 "Ga-Dangme" 103 "Ewe" 104 "Guan" 105 "Gruma" 106 "Mole-Dagbani" 107 "Grussi" 108 "Mande" 109 "Basali" 110 "Fulani" 111 "Kotokoli" 112 "Kabire" 113 "Konkomba" 114 "Togo Karra" 115 "Other Ghana" 201 "Bambara" 202 "Malinké" 203 "Peul/Foulfoulbé" 204 "Sonrai/Djerma" 205 "Sarakolé/Soninké" 206 "Kassonké" 207 "Sénoufo" 208 "Dogon" 209 "Maure" 210 "Tamacheq" 211 "Bobo" 212 "Dafing" 213 "Minianka" 214 "Haoussa" 215 "Samogo" 216 "Bozo" 217 "Arabe" 218 "Mossi" 219 "Other Mali"
	label val reseth ethnicity
	replace reseth = 109 if reseth_other == "Basaali" | reseth_other == "Basali" | reseth_other == "Basari"
	replace reseth = 110 if reseth_other == "Fulani"
	replace reseth = 111 if reseth_other == "KOTOKOLI"
	replace reseth = 112 if reseth_other == "Kabire" | reseth_other == "Kabira"
	replace reseth = 113 if reseth_other == "Konkomba" | reseth_other == "Komkomba" | reseth_other == "Konkonba" | reseth_other == "Konomba" | reseth_other == "konkomba"
	replace reseth = 114 if reseth_other == "TOGO KARRA"
	drop reseth_other

// Correct respondents that have no religion and were recorded as others
recode resrel (8=1)
	label var resrel "Religion of respondent"
	label define religion 1 "No religion" 2 "Christianity" 3 "Islam" 4 "Buddhism" 5 "Hinduism" 6 "Animist" 7 "Tradionalist" 8 "Other" 9 "Not know"
	label val resrel religion
	drop resrel_other

preserve
	keep habitable_id reseth resrel
	rename (reseth resrel) (reseth_w1 resrel_w1)
	sort habitable_id
	tempfile res1 
	save	`res1'
restore
	
// Harmonise timestamp with other countries
rename (timestart timeend) (atimestart atimeend)
	gen timeend = date(date,"YMD",2024)
	label var timeend "Date"
	format timeend %td
	order timeend, before(atimestart)
	drop date
	
tempfile intro
save	`intro'
	
* Individual level and migration history

use "$INPUT\Ghana\Ghana Raw\Household Data.dta", clear
	habitableid
	drop timestart-htype
	rename id hhmid
	drop if hhmid==. // To drop 20 observations with missing data
	
preserve
	keep habitable_id-any
	// Harmonise grades with other countries
	recode grade (30 31 = 17) (32 77=.)
	label define grade 0 "None" 17 "Primary" 18 "Lower secondary" 19 "Upper secondary" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)", replace
	replace grade = 18 if regexm(grade_specify,"middle")==1 | regexm(grade_specify,"MIDDLE")==1 | regexm(grade_specify,"form 4")==1 | regexm(grade_specify,"FORM 4")==1
	label values grade grade
	expand 10 // This is aligned with the Migration History, NOT the time of the interview - Cleaned when appended with Wave 2	
	sort habitable_id hhmid	
	by habitable_id hhmid: gen year = _n
	order year, after(hhmid)
	replace year = 2012 if year==1
	replace year = 2013 if year==2
	replace year = 2014 if year==3
	replace year = 2015 if year==4
	replace year = 2016 if year==5
	replace year = 2017 if year==6
	replace year = 2018 if year==7
	replace year = 2019 if year==8
	replace year = 2020 if year==9
	replace year = 2021 if year==10	
	sort habitable_id hhmid year
	tempfile hhm
	save	`hhm'
restore
	
preserve 
	keep habitable_id hhmid coutr_2021-specify_2012
	reshape long coutr_@ region_@ distr_@ dury_@ durm_@ reason_@ specify_@, i(habitable_id hhmid) j(year)
	rename *_ *
	label define reason 1 "Work- or income-related reasons" 2 "Educational reasons" 3 "Family-related reasons" 4 "Environment-related reasons" 5 "Conflict" 6 "Other, specify", replace	
	recode reason (5=4) (6=5) (7=6)
	label values reason reason
	rename specify reason_specify	
	rename region level1
	rename distr level2
	label var level1 "Level 1"
	label var level2 "Level 2"	
	sort habitable_id hhmid year
	tempfile mighis
	save	`mighis'
restore 
	
* Dwelling characteristics

use "$INPUT\Ghana\Ghana Raw\Dwelling Characteristics Data.dta", clear
	habitableid
	drop timestart-htype
	rename tec _tec
	forvalues i=1/7	{
		gen tec`i' = 1 if regexm(_tec, "`i'")==1
		replace tec`i' = 0 if regexm(_tec, "`i'")==0
	}
	label var tec1 "Radio"
	label var tec2 "TV"
	label var tec3 "Computer/laptop"
	label var tec4 "Tablet"
	label var tec5 "Landline"
	label var tec6 "Mobile phone without internet"
	label var tec7 "Mobile phone with internet"
	drop _tec
	
tempfile dwe
save	`dwe'

keep habitable_id rooms roof wall floor elect cfuel water toilet tec1 tec2 tec3 tec4 tec5 tec6 tec7
ds habitable_id, not
rename (`r(varlist)') (=_w1)
tempfile hh1
save	`hh1'

* Livelihoods

use "$INPUT\Ghana\Ghana Raw\Livelihood Data.dta", clear
	habitableid
	drop timestart-htype
	rename *_? *?
tempfile liv
save	`liv'

* Spouse pay

use "$INPUT\Ghana\Ghana Raw\Spouse Livelihood Data.dta", clear
	habitableid
	drop timestart-htype
	rename *_? *?
	ds habitable_id, not
	rename (`r(varlist)') (s=)
	sort habitable_id

tempfile sact
save	`sact'
	
* Perceptions of climate risks

use "$INPUT\Ghana\Ghana Raw\Perceptions of Climatic risk Data.dta", clear
	habitableid
	drop timestart-htype
	rename *_? *?
	rename yes_no? evt?
	label var evt1 "Floods happened?"
	label var evt2 "Drought happened?"
	label var evt3 "Erratic rainfall happened?"
	label var evt4 "Heatwave happened?"

tempfile risks
save	`risks'

* Household adaptation

use "$INPUT\Ghana\Ghana Raw\Household Adaptation Data.dta", clear
	habitableid
	drop timestart-htype
	rename *_0? *?
	rename *_# *#
	
tempfile hhadap
save	`hhadap'

* Adaptive capacity

use "$INPUT\Ghana\Ghana Raw\Adaptive Capacity Data.dta", clear
	habitableid
	drop timestart-htype
	rename adpnet_specify1 adpnet_specify

tempfile adapc
save	`adapc'

* Personality traits

use "$INPUT\Ghana\Ghana Raw\Psychological Wellbeing Data.dta", clear
	habitableid
	drop timestart-htype
	
tempfile ptraits
save	`ptraits'

* Merge all sections

use `intro', clear
	merge 1:1 habitable_id using `dwe', nogen 
	merge 1:1 habitable_id using `liv', nogen
	merge 1:1 habitable_id using `sact', nogen keepusing(sactpay1 sactpay2)
	merge 1:1 habitable_id using `risks', nogen
	merge 1:1 habitable_id using `hhadap', nogen
	merge 1:1 habitable_id using `adapc', nogen
	merge 1:1 habitable_id using `ptraits', nogen
	
tempfile gh1
save	`gh1'

use `hhm', clear
	merge 1:1 habitable_id hhmid year using `mighis', nogen
tempfile long
save	`long'

use `gh1', clear
	merge 1:m habitable_id using `long', nogen
	sort habitable_id hhmid year
tempfile ghpy1
save	`ghpy1'

collapse wave liveh, by(habitable_id hhmid)
tempfile id1
save	`id1'

collapse wave, by(habitable_id)
tempfile test1
save	`test1'
*********************************************************** W2 *************************************************************

* Household level

use "$INPUT\Ghana\Wave 2\Final Data_W2\Household Data.dta", clear
	format habitable_id %9.0f
	replace habitable_id = habitable_id - 1000000000 if adm1==1
	replace habitable_id = habitable_id - 2000000000 if adm1==2
	replace habitable_id = 208123415 if habitable_id==-1444371188	
	habitableid
	drop resname restel resrep

// Harmonise timestamp with other countries
rename (timestart timeend) (atimestart atimeend)
	gen timeend = date(date,"YMD",2024)
	label var timeend "Date"
	format timeend %td
	order timeend, before(atimestart)
	drop date

// No admin level 4, generate one to make it the same structure as in other countries
rename adm3 adm4
	gen adm3 = .
	order adm3, after (adm2)
	label var adm3 "Subdistrict"

// To remove location from wave 2 in order to keep location from wave 1 only
*drop adm1 - gps_readtime
	
// Generate country variable to help later when data sets are combined
gen country = 1
	label var country "Country"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia" 5 "Thailand"
	label val country country
	order country, after (habitable_id)

// Generate wave variable
gen wave = 2
	label var wave "Data collected in wave 1 (2022) or wave 2 (2023)"
	order wave, before (country)

tempfile hh2
save	`hh2'
	
// Generate number of children
use "$INPUT\Ghana\Wave 2\Final Data_W2\Householdhead + Spouse.dta", clear
	format habitable_id %9.0f
	replace habitable_id = habitable_id - 1000000000 if adm1==1
	replace habitable_id = habitable_id - 2000000000 if adm1==2 
	* To correct id for the same household (based on GPS) with different identifier between rounds
	replace habitable_id = 208123415 if habitable_id==-1444371188	
	habitableid
	keep if restype<.
	sort habitable_id
	tempfile both
	save	`both'

// Spouse pay
use "$INPUT\Ghana\Wave 2\Final Data_W2\Spouse Data.dta", clear
	drop if habitable_id==1110160917 & gps_latitude<6 // Remove duplicate - kept wife with the same GPS coordenates
	habitableid
	rename *_? *?
	ds habitable_id, not
	rename (`r(varlist)') (s=)
	sort habitable_id
	tempfile sact2
	save	`sact2'
	
use `hh2', clear
	merge 1:1 habitable_id using `both', keepusing(hhsize adults) keep(master match) nogen
	replace adults = hhsize if adults>hhsize & adults<. // 0 obs
	gen children = hhsize - adults
	label var children "Number of children in the household" // Empty variable
	order children, after (adults)
	rename adults nadult
	label var hhsize "Household size" // Empty variable
	label var nadult "Number of adults in the household" // Empty variable
	order hhsize-children, after(resrel_other)
	merge 1:1 habitable_id using `sact2', keepusing(sactpay1 sactpay2) nogen

// Ethnicity other - correct different spelling
recode reseth (1=101) (2=102) (3=103) (4=104) (5=105) (6=106) (7=107) (8=108) (9=115)	
	label var reseth "Ethnicity of respondent"
	label define ethnicity 101 "Akan" 102 "Ga-Dangme" 103 "Ewe" 104 "Guan" 105 "Gruma" 106 "Mole-Dagbani" 107 "Grussi" 108 "Mande" 109 "Basali" 110 "Fulani" 111 "Kotokoli" 112 "Kabire" 113 "Konkomba" 114 "Togo Karra" 115 "Other Ghana" 201 "Bambara" 202 "Malinké" 203 "Peul/Foulfoulbé" 204 "Sonrai/Djerma" 205 "Sarakolé/Soninké" 206 "Kassonké" 207 "Sénoufo" 208 "Dogon" 209 "Maure" 210 "Tamacheq" 211 "Bobo" 212 "Dafing" 213 "Minianka" 214 "Haoussa" 215 "Samogo" 216 "Bozo" 217 "Arabe" 218 "Mossi" 219 "Other Mali"
	label val reseth ethnicity
	replace reseth = 109 if reseth_other == "Basaali" | reseth_other == "Basali" | reseth_other == "Basari"
	replace reseth = 110 if reseth_other == "Fulani" | reseth_other=="fulani"
	replace reseth = 111 if reseth_other == "KOTOKOLI" | reseth_other=="Kotokoli"
	replace reseth = 112 if reseth_other == "Kabire" | reseth_other == "Kabira" | reseth_other=="Kabri"
	replace reseth = 113 if reseth_other == "Konkomba" | reseth_other=="Komkomba" | reseth_other=="Konkonba" | reseth_other=="Konomba" | reseth_other=="konkomba" | reseth_other=="KOKOMBA" | reseth_other=="KONKOMBA" | reseth_other=="Kokonba" | reseth_other=="kokomba" | reseth_other=="konkonba" | reseth_other=="konkonsa"
	replace reseth = 114 if reseth_other == "TOGO KARRA"
	drop reseth_other

// Correct respondents that have no religion and were recorded as others
label var resrel "Religion of respondent"
	label define religion 1 "No religion" 2 "Christianity" 3 "Islam" 4 "Buddhism" 5 "Hinduism" 6 "Animist" 7 "Tradionalist" 8 "Other" 9 "Not know"
	label val resrel religion
	drop resrel_other

merge 1:1 habitable_id using `res1', nogen keep(match master)
	rename (reseth resrel) (reseth_w2 resrel_w2)
	gen reseth = reseth_w1
		replace reseth = reseth_w2 if reseth_w1!=reseth_w2 & reseth_w2<.
		label var reseth "Ethnicity of respondent"
		label values reseth ethnicity
	gen resrel = resrel_w1
		replace resrel = resrel_w2 if resrel_w1!=resrel_w2 & resrel_w2<.
		label var resrel "Religion of respondent"
		label values resrel religion
	drop resrel_w1 resrel_w2 reseth_w1 reseth_w2
	
drop id_36-specify_2012_50 // The largest household has 35 members
rename *_0? *_?
reshape long id_@ sex_@ age_@ marry_@ relhh_@ relhh_specify_@ grade_@ grade_specify_@ liveh_@ mig_@ coutr_2023_@ region_2023_@ distr_2023_@ dury_2023_@ durm_2023_@ reason_2023_@ specify_2023_@ coutr_2022_@ region_2022_@ distr_2022_@ dury_2022_@ durm_2022_@ reason_2022_@ specify_2022_@ coutr_2021_@ region_2021_@ distr_2021_@ dury_2021_@ durm_2021_@ reason_2021_@ specify_2021_@ coutr_2020_@ region_2020_@ distr_2020_@ dury_2020_@ durm_2020_@ reason_2020_@ specify_2020_@ coutr_2019_@ region_2019_@ distr_2019_@ dury_2019_@ durm_2019_@ reason_2019_@ specify_2019_@ coutr_2018_@ region_2018_@ distr_2018_@ dury_2018_@ durm_2018_@ reason_2018_@ specify_2018_@ coutr_2017_@ region_2017_@ distr_2017_@ dury_2017_@ durm_2017_@ reason_2017_@ specify_2017_@ coutr_2016_@ region_2016_@ distr_2016_@ dury_2016_@ durm_2016_@ reason_2016_@ specify_2016_@ coutr_2015_@ region_2015_@ distr_2015_@ dury_2015_@ durm_2015_@ reason_2015_@ specify_2015_@ coutr_2014_@ region_2014_@ distr_2014_@ dury_2014_@ durm_2014_@ reason_2014_@ specify_2014_@ coutr_2013_@ region_2013_@ distr_2013_@ dury_2013_@ durm_2013_@ reason_2013_@ specify_2013_@ coutr_2012_@ region_2012_@ distr_2012_@ dury_2012_@ durm_2012_@ reason_2012_@ specify_2012_@, i(habitable_id) j(hhmid)
	rename *_ *
	drop if id==.
	drop resid1
	forvalues i=2012/2023	{
		count if coutr_`i'==. & region_`i'==. & distr_`i'==. & dury_`i'==. & durm_`i'==. & reason_`i'==. & specify_`i'==""
	}
	// Migration history only has non-missing values since 2021
	drop coutr_2020-specify_2012
	// Remove 2021 moves to avoid duplicating with wave 1
	drop coutr_2021-specify_2021
	
reshape long coutr_@ region_@ distr_@ dury_@ durm_@ reason_@ specify_@, i(habitable_id hhmid) j(year)
	rename *_ *
	label define reason 1 "Work- or income-related reasons" 2 "Educational reasons" 3 "Family-related reasons" 4 "Environment-related reasons" 5 "Conflict" 6 "Other, specify", replace	
	recode reason (5=4) (6=5) (7=6)
	label values reason reason
	rename specify reason_specify
	rename region level1
	rename distr level2
	label var level1 "Level 1"
	label var level2 "Level 2"	
	sort habitable_id hhmid year

// Harmonise grades with other countries
recode grade (30 31 = 17) (32 77=.)
	label define grade 0 "None" 17 "Primary" 18 "Lower secondary" 19 "Upper secondary" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)", replace
	label values grade grade
	
tempfile long2
save	`long2'

* Individual level

use "$INPUT\Ghana\Wave 2\Final Data_W2\Individual Data.dta", clear
	format habitable_id %9.0f
	replace habitable_id = habitable_id - 1000000000 if adm1==1
	replace habitable_id = habitable_id - 2000000000 if adm1==2 
	* To correct id for the same household (based on GPS) with different identifier between rounds
	replace habitable_id = 208123415 if habitable_id==-1444371188	
	habitableid
	drop timestart-q24_2 comments
			
	rename tec _tec
	forvalues i=1/7	{
		gen tec`i' = 1 if regexm(_tec, "`i'")==1
		replace tec`i' = 0 if regexm(_tec, "`i'")==0
	}
	label var tec1 "Radio"
	label var tec2 "TV"
	label var tec3 "Computer/laptop"
	label var tec4 "Tablet"
	label var tec5 "Landline"
	label var tec6 "Mobile phone without internet"
	label var tec7 "Mobile phone with internet"
	drop _tec

merge 1:1 habitable_id using `hh1', nogen keep(match master)

	foreach v of varlist rooms roof wall floor elect cfuel water toilet tec1 tec2 tec3 tec4 tec5 tec6 tec7	{
		replace `v' = `v'_w1 if `v'==.
	}
	drop rooms_w1 roof_w1 wall_w1 floor_w1 elect_w1 cfuel_w1 water_w1 toilet_w1 tec1_w1 tec2_w1 tec3_w1 tec4_w1 tec5_w1 tec6_w1 tec7_w1
	
	rename *_? *?
	rename response_specify_15 response_specify 
	rename yes_no? evt?
	label var evt4 "Heatwave happened?"
	rename *_0? *?
	rename *_# *#
	rename adpnet_specify1 adpnet_specify

tempfile gh2
save	`gh2'

use `gh2', clear
	merge 1:m habitable_id using `long2', nogen
	sort habitable_id hhmid year

tempfile ghpy2
save	`ghpy2'

collapse wave liveh, by(habitable_id hhmid)
tempfile id2
save	`id2'

collapse wave, by(habitable_id)
tempfile test2
save	`test2'
	
*********************************************************** W1 & W2 *************************************************************
use `test1', clear
	merge 1:1 habitable_id using `test2', nogen // 0% household attrition
	
use `id1', clear
	merge 1:1 habitable_id hhmid using `id2'
	drop wave
	rename _merge waveid
	label define waveid 1 "Only in Wave 1" 2 "Only in Wave 2" 3 "In both waves", replace
	label values waveid waveid
	label var waveid "Wave for each individual"
sort habitable_id hhmid
	egen py = group(habitable_id hhmid)
	order py, after(hhmid)
	*drop if liveh==4 // To drop 4 hhm who passed away (3 elderly and 1 young)
	replace waveid = 1 if liveh==4
	drop liveh // This is a mean-generated value resulting from a collapsed dataset
		
expand 12
	sort habitable_id hhmid waveid
	by habitable_id hhmid: gen year = _n
	order year, after(py)
	replace year = 2012 if year==1
	replace year = 2013 if year==2
	replace year = 2014 if year==3
	replace year = 2015 if year==4
	replace year = 2016 if year==5
	replace year = 2017 if year==6
	replace year = 2018 if year==7
	replace year = 2019 if year==8
	replace year = 2020 if year==9
	replace year = 2021 if year==10	
	replace year = 2022 if year==11
	replace year = 2023 if year==12
	sort habitable_id hhmid year 
	
merge 1:1 habitable_id hhmid year using `ghpy1', nogen
merge 1:1 habitable_id hhmid year using `ghpy2', nogen nolabel update

distinct py
distinct habitable_id

order wave, after(year)
	replace wave = 1 if wave==. & (year>=2012 & year<=2021)
	replace wave = 2 if wave==. & (year>=2022 & year<=2023)
	order sex - reason_specify, last
	order q24_1 q24_2, before(sex)	
	order improv, before(tenure)
	order hhrem hhrempay response_specify, after(sactpay2)
	sort habitable_id hhmid year

* Locality checks

preserve
sort habitable_id hhmid year
collapse adm4, by(habitable_id year)	
	by habitable_id: gen test = (adm4[1]!=adm4[_N]) // No entire households moved between waves
restore
	
* Individual characteristics

// To fill in missing info on initial location
sort habitable_id hhmid year
foreach v of var country adm1-adm4 	{
	by habitable_id hhmid: replace `v' = `v'[_n-1] if missing(`v') & wave==2 & waveid==1
	by habitable_id hhmid: replace `v' = `v'[_n-1] if missing(`v') & wave==2 & waveid==3
}
foreach v of var country adm1-adm4 	{
	by habitable_id: replace `v' = `v'[1] if missing(`v') & wave==1 & waveid==2
}

// To correct time-varying characteristics
sort habitable_id hhmid year 

	// For individuals in both waves
	by habitable_id hhmid: replace age = age[_n-1]+1 if year==2023 & waveid==3
	forvalues i=2021(-1)2012	{
		by habitable_id hhmid: replace age = age[_n+1]-1 if year==`i' & waveid==3
	}

	// For individuals only in wave 1
	by habitable_id hhmid: replace age = age[_n-1] if year==2022 & waveid==1
	forvalues i=2021(-1)2012	{
		by habitable_id hhmid: replace age = age[_n+1]-1 if year==`i' & waveid==1
	}
		
	// For individuals only in wave 2
	by habitable_id hhmid: replace age = age[_n+1]-1 if year==2022 & waveid==2
	
// To correct time-invariant characteristics
sort habitable_id hhmid year 
	by habitable_id hhmid: replace resrel = resrel[_N] if year<=2022 & missing(resrel) & !missing(resrel[_N])
	
// To identify who lives in the household in each year based on Roster and Migration History - br habitable_id hhmid year adm2 sex liveh coutr level2 dury durm inhh if waveid==

	// HHMs in both waves
	gen inhh = 1 if liveh==1 & year==2021 & waveid==3
	replace inhh = 1 if liveh==1 & year==2023 & waveid==3
	replace inhh = 2 if liveh==2 & year==2021 & waveid==3
	replace inhh = 2 if liveh==2 & year==2023 & waveid==3
	replace inhh = 3 if liveh==3 & year==2021 & waveid==3
	replace inhh = 3 if liveh==3 & year==2023 & waveid==3
	label var inhh "HHM status in household this year"
	label define inhh 1 "In the household" 2 "Outside the household - in locality" 3 "Outside the household - out of locality" 4 "Passed away", replace
	label values inhh inhh
	
	// ... who never migrated
	sort habitable_id hhmid year
	by habitable_id hhmid: egen nmoves = count(coutr) // Counts non-missing values including 0s
	replace inhh = 1 if liveh==1 & nmoves==0 & waveid==3 // Based on Migration History and Household Roster
	replace inhh = 2 if liveh==2 & nmoves==0 & waveid==3
	replace inhh = 3 if liveh==3 & nmoves==0 & waveid==3
	
	// ... who migrated at least once
	sort habitable_id hhmid year
	tab nmoves // Max number of moves = 12
	forvalues j=1/12	{
	by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & (liveh==1|liveh==2) & nmoves==`j' & waveid==3 // To identify year of move of HHMs who moved and returned to locality by the time of interview. Even if dury==0, moves that last less than a year are also counted
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & (liveh==1|liveh==2) & nmoves==`j' & waveid==3 // To populate years outside locality
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==3 // HHMs who left Ghana, but returned
		}
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==3
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2022 & liveh==3 & nmoves==`j' & waveid==3 // To identify HHMs outside the locality at the time of interview in wave 1
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2023 & liveh==3 & nmoves==`j' & waveid==3 // To identify HHMs outside the locality at the time of interview in wave 2
		by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & liveh==3 & nmoves==`j' & waveid==3 // To identify when they moved
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & liveh==3 & nmoves==`j' & waveid==3 // To populate years outside locality
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & liveh==3 & nmoves==`j' & waveid==3 // HHMs who left Ghana and still live abroad
		}		
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & liveh==3 & nmoves==`j' & waveid==3
	}

	// HHMs only in Wave 1
	replace inhh = 1 if inhh==. & liveh==1 & year==2021 & waveid==1
	replace inhh = 2 if inhh==. & liveh==2 & year==2021 & waveid==1
	replace inhh = 3 if inhh==. & liveh==3 & year==2021 & waveid==1
	
	// ... who never migrated
	replace inhh = 1 if inhh==. & liveh==1 & nmoves==0 & waveid==1
	replace inhh = 2 if inhh==. & liveh==2 & nmoves==0 & waveid==1
	replace inhh = 3 if inhh==. & liveh==3 & nmoves==0 & waveid==1
	
	// ... who moved at least once
	forvalues j=1/12	{
	by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & (liveh==1|liveh==2) & nmoves==`j' & waveid==1
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & (liveh==1|liveh==2) & nmoves==`j' & waveid==1
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==1
		}
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==1
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2022 & liveh==3 & nmoves==`j' & waveid==1
		by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & liveh==3 & nmoves==`j' & waveid==1
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & liveh==3 & nmoves==`j' & waveid==1
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & liveh==3 & nmoves==`j' & waveid==1 
		}		
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & liveh==3 & nmoves==`j' & waveid==1
	}
	
	by habitable_id hhmid: replace inhh = 2 if inhh==. & liveh[_n-1]==1 & year==2022 & waveid==1 // Conservative approach: HHMs only in Wave 1 remain in the locality in Wave 2
	by habitable_id hhmid: replace inhh = 2 if inhh==. & liveh[_n-2]==1 & year==2023 & waveid==1 
	by habitable_id hhmid: replace inhh = 2 if inhh==. & liveh[_n-1]==2 & year==2022 & waveid==1 // HHMs not in household in Wave 1 have the same status in Wave 2
	by habitable_id hhmid: replace inhh = 2 if inhh==. & liveh[_n-2]==2 & year==2023 & waveid==1
	by habitable_id hhmid: replace inhh = 3 if inhh==. & liveh[_n-1]==3 & year==2022 & waveid==1
	by habitable_id hhmid: replace inhh = 3 if inhh==. & liveh[_n-2]==3 & year==2023 & waveid==1
	
	// HHMs only in Wave 2 
	by habitable_id hhmid: replace inhh = 1 if inhh==. & liveh==1 & year==2023 & waveid==2
	by habitable_id hhmid: replace inhh = 1 if inhh==. & liveh[_n+1]==1 & year==2022 & waveid==2 // No HHM moved
	by habitable_id hhmid: replace inhh = 2 if inhh==. & liveh==2 & year==2023 & waveid==2
	by habitable_id hhmid: replace inhh = 2 if inhh==. & liveh[_n+1]==2 & year==2022 & waveid==2
	by habitable_id hhmid: replace inhh = 3 if inhh==. & liveh==3 & year==2023 & waveid==2
	by habitable_id hhmid: replace inhh = 3 if inhh==. & liveh[_n+1]==3 & year==2022 & waveid==2
	by habitable_id hhmid: replace inhh = 2 if inhh==. & liveh==. & year<=2021 & waveid==2 // Conservative approach: HHMs only in Wave 2 remain in the locality in Wave 1

	// HHMs who passed away
	
	// ... in Wave 1
	replace liveh = 4 if liveh[_n-1]==4 & year==2022 // To correct absence in Wave 2
	replace liveh = 4 if liveh[_n-1]==4 & year==2023
	replace inhh = 1 if liveh==4 & year<=2020 // Assumed that HHM passed away on the year of the interview
	replace inhh = 4 if liveh==4 & year>=2021 & year<=2023
	
		
* Migration

gen moved = 0
	replace moved = 1 if !missing(coutr)
	label var moved "Migrated outside the locality this year"
	label define moved 0 "No" 1"Yes", replace
	label values moved moved

// To calculate total moves per year
bys year: egen total_mig = total(moved)

// To calculate total labour moves per year
bys year: egen labour_mig = total(moved) if reason==1

// To calculate length of migration event in months
gen length = .
replace length = durm if dury < 1
replace length = durm + 12 if dury == 1 & durm <= 11
replace length = durm + 24 if dury == 2 & durm <= 11
replace length = durm + 36 if dury == 3 & durm <= 11
replace length = durm + 48 if dury == 4 & durm <= 11
replace length = durm + 60 if dury == 5 & durm <= 11
replace length = durm + 72 if dury == 6 & durm <= 11
replace length = durm + 84 if dury == 7 & durm <= 11
replace length = durm + 96 if dury == 8 & durm <= 11
replace length = durm + 108 if dury == 9 & durm <= 11
replace length = durm + 120 if dury == 10 & durm <= 11
label var length "Length of migration event (in months)"

bys year: egen short_mig = total(moved) if length<12
bys year: egen long_mig = total(moved) if length>=12 & !missing(length)

// To calculate outmigration rates at Administrative Level 4 of the original sampling sites

sort habitable_id hhmid year
	
	// Create a variable for migrants for each year
	bys adm4 year: egen yearly_mig4 = total(moved)
		label var yearly_mig4 "Annual number of migrants"

	// Calculate the population at risk per year
	gen inloc4 = (inhh==1 | inhh==2)
		label var inloc4 "In the locality this year"
	bys adm4 year: egen totinloc4 = total(inloc4)
		egen pop_at_risk4 = rowtotal(totinloc4 yearly_mig4)
		label var pop_at_risk4 "Population at risk of migration"
	sort adm4 habitable_id hhmid year 
	by adm4: gen pop_at_risk41 = pop_at_risk4[1]
		label var pop_at_risk41 "Initial population at risk of migration"

	// Calculate the outmigration rate
	bys adm4 year: gen outmig_rate4 = (yearly_mig4 / pop_at_risk4) * 100
		label var outmig_rate4 "Percentage of outmigration per year"

	// Calculate the change in outmigration taken as a share of the initial population at risk
	bys adm4 year: gen outmig_share4 = (yearly_mig4 / pop_at_risk41) * 100
		label var outmig_share4 "Outmigration as a share of initial population at risk"

// To calculate outmigration rates only for long-term migration at administration level 4

sort habitable_id hhmid year
	
	// Create a variable for migrants for each year
	gen lmoved = (moved==1 & length>=12 & !missing(length))
	bys adm4 year: egen yearly_migl4 = total(lmoved)
		label var yearly_migl4 "Annual number of long-term migrants"

	// Calculate the population at risk per year
	gen inlocl4 = (inhh==1 | inhh==2 | (moved==1 & length<12))
		label var inlocl4 "In the locality this year"
	bys adm4 year: egen totinlocl4 = total(inlocl4)
		egen pop_at_riskl4 = rowtotal(totinlocl4 yearly_migl4)	
		label var pop_at_riskl4 "Population at risk of migration"
	sort adm4 habitable_id hhmid year 
	by adm4: gen pop_at_riskl41 = pop_at_riskl4[1]
		label var pop_at_riskl41 "Initial population at risk of migration"

	// Calculate the outmigration rate
	bys adm4 year: gen outmig_ratel4 = (yearly_migl4 / pop_at_riskl4) * 100
		label var outmig_ratel4 "Percentage of long-term outmigration per year"

	// Calculate the change in outmigration taken as a share of the initial population at risk
	bys adm4 year: gen outmig_sharel4 = (yearly_migl4 / pop_at_riskl41) * 100
		label var outmig_sharel4 "Long-term outmigration as a share of initial population at risk"
	
	
* Income

egen hsinc_ghc = rowtotal(actpay1 actpay2 sactpay1 sactpay2)
	label var hsinc_ghc "Head and spouse annual income (GHC)"

// Mid-date of wave 1: 18/04/2022
gen hsinc_usd = hsinc_ghc*0.1315 if wave==1
	label var hsinc_usd "Head and spouse annual income (USD)"
gen hhpay_usd = hhpay*0.1315 if wave==1
	label var hhpay_usd "Household annual income (USD)"
	
// Mid-date of wave 2: 18/07/2023	
replace hsinc_usd = hsinc_ghc*0.08797 if wave==2
	label var hsinc_usd "Head and spouse annual income (USD)"
replace hhpay_usd = hhpay*0.08797 if wave==2
	label var hhpay_usd "Household annual income (USD)"

su hsinc_usd if wave==1, det
	centile hsinc_usd if wave==1, centile(99.5)
	*The 99.5 percentile is at 9834.885
	replace hsinc_usd = 9834.885 if hsinc_usd>9834.885 & hsinc_usd<. & wave==1 

su hhpay_usd if wave==1, det
	centile hhpay_usd if wave==1, centile(99.5)
	replace hhpay_usd = 11688.77 if hhpay_usd>11688.77 & hhpay_usd<. & wave==1 
	
su hsinc_usd if wave==2, det
	centile hsinc_usd if wave==2, centile(99.5)
	replace hsinc_usd = 4750.38 if hsinc_usd>4750.38 & hsinc_usd<. & wave==2 
	
su hhpay_usd if wave==2, det
	centile hhpay_usd if wave==2, centile(99.5)
	replace hhpay_usd = 7917.3 if hhpay_usd>7917.3 & hhpay_usd<. & wave==2 

/*graph box hhpay_usd hsinc_usd hhpay_usd hsinc_usd, box(1, fcolor(teal) lcolor(teal)) box(2, fcolor(dkorange) lcolor(dkorange)) box(3, fcolor(olive_teal) lcolor(olive_teal)) box(4, fcolor(gold) lcolor(gold)) marker(1, mcolor(teal)) marker(2, mcolor(dkorange)) marker(3, mcolor(olive_teal)) marker(4, mcolor(gold)) ytitle(`"Annual income in USD"') by(, legend(position(6))) legend (label(1 "Household annual income (2022)") label(2 "Head and spouse annual income (2022)") label(3 "Household annual income (2023)") label(4 "Head and spouse annual income (2023)")) by(adm1, note(" ")) */

ttest hsinc_usd=hhpay_usd if wave==1 // Statistically the same
ttest hsinc_usd=hhpay_usd if wave==2 // Statistically different

* Remittances

gen remit = 0 if wave==2
	replace remit = hhrempay*0.08797 if wave==2 & !missing(hhrempay)
	label var remit "Household remittances (USD)"

* Wealth

// Generate Housing Quality Index
* crowding 
	gen roompp=(rooms/hhsize)/1.5
	replace roompp=1 if roompp>1 & !missing(roompp)
	label var roompp "Rooms per person living in the household"				
* wall materials - 1: Cement and concrete, bricks, Sandstones; 0: all the rest
	gen wallq = wall==1 | wall==2 | wall==3
	label var wallq "wall index for hq"
* roof material - 1: Galvanised/corrugated iron, Concrete/ cement; Tiles/ slates; 0: all the rest.
	gen  roofq = roof==1 | roof==2 | roof==3
	label var roofq "roof index for hq"
* floor material - 1: concrete/cement, tile, marble stone, laminated material; 0: all the rest		
	gen floorq = floor==1 | floor==2 | floor==3 | floor==4 
	label var floorq "floor index for hq"
* housing quality index
	egen hq=rowtotal(roompp wallq roofq floorq)
	replace hq= hq/4
	label var hq "Housing Quality Index"

// Generate Consumer Durables Index - includes same items across rounds
* same items are: 1 Radio, 2 TV, 3 Computer, 4 Tablet, 5 Landline, 6 Mobile without internet, 7 Mobile with internet
	egen cd = rowtotal(tec1 tec2 tec3 tec4 tec5 tec6 tec7)
	replace cd=cd/7
	label var cd "Consumer Durable Index"
	
// Generate Access to Services Index
* access to electricity
	gen elecq=elect		
* sanitation - 1: flush toilet, septic tank in dwelling; pit latrine (household); 0: all the rest
	gen toiletq = toilet==1 | toilet==2 | toilet==4 
* drinking water - 1: piped into dwelling/ yard/ plot, tubewell in dwelling/ yard/ ploy, public standpipe; 0: all the rest
	gen waterq = water==1 | water==2 | water==3  		
* cooking fuel - 1: kerosene and parafin, gas and electricity; 0: all the rest
	gen cookingq = cfuel== 1 | cfuel== 2		
* access to services index
	egen sv= rowtotal(elecq toiletq waterq cookingq)
	replace sv = sv/4
	label var sv "Access to Services index"
			
// Generate Wealth Index
	egen wi = rowtotal(hq cd sv)
	replace wi = wi/3
	label var wi "Wealth Index"

* Household adaptation

egen adap = rowtotal(adp1 adp2 adp3 adp4 adp5 adp6 adp7 adp8 adp9 adp10 adp11 adp12 adp13 adp14 adp15)
	label var adap "Number of household adaptation measures"
	
egen insitu = rowtotal(adp1 adp2 adp3 adp4 adp5 adp6 adp7 adp8 adp9 adp10 adp11)
	label var insitu "Number of in situ adaptation measures"

* Expected loss

su evtlh1 evtlh2 evtlh3 evtlh4 if wave==1, det
	centile evtlh2 if wave==1, centile(99.5) // 80 is cut off to correct for outliers that seem like years rather than percentages
	replace evtlh2 = 80 if evtlh2>200 & !missing(evtlh2)

su evtlh1 evtlh2 evtlh3 evtlh4 if wave==2, det
	
forvalues i=1/4 {
	gen loss_housing_`i' = evtlh`i'*hhpay_usd/100
	replace loss_housing_`i' = 0 if loss_housing_`i'==.
	label var loss_housing_`i' "Loss of housing through shock (USD)"
	gen loss_land_`i' = evtla`i'*hhpay_usd/100
	replace loss_land_`i' = 0 if loss_land_`i'==.
	label var loss_land_`i' "Loss of land through shock (USD)"
	gen loss_harvest_`i' = evtlha`i'*hhpay_usd/100
	replace loss_harvest_`i' = 0 if loss_harvest_`i'==.
	label var loss_harvest_`i' "Loss of harvest through shock (USD)"
	gen loss_livestock_`i' = evtll`i'*hhpay_usd/100
	replace loss_livestock_`i' = 0 if loss_livestock_`i'==.
	label var loss_livestock_`i' "Loss of livestock through shock (USD)"
	gen loss_fisheries_`i' = evtlfi`i'*hhpay_usd/100
	replace loss_fisheries_`i' = 0 if loss_fisheries_`i'==.
	label var loss_fisheries_`i' "Loss of fisheries through shock (USD)"
	gen loss_health_`i' = evtlhh`i'*hhpay_usd/100
	replace loss_health_`i' = 0 if loss_health_`i'==.
	label var loss_health_`i' "Loss of health through shock (USD)"
}

egen loss_flood = rowtotal(loss_housing_1 loss_land_1 loss_harvest_1 loss_livestock_1 loss_fisheries_1)
	label var loss_flood "Loss from floods (USD)"
egen loss_drought = rowtotal(loss_housing_2 loss_land_2 loss_harvest_2 loss_livestock_2 loss_fisheries_2)
	label var loss_drought "Loss from droughts (USD)"
egen loss_rainfall = rowtotal(loss_housing_3 loss_land_3 loss_harvest_3 loss_livestock_3 loss_fisheries_3)
	label var loss_rainfall "Loss from erratic rainfall (USD)"
egen loss_heatwave = rowtotal(loss_housing_4 loss_land_4 loss_harvest_4 loss_livestock_4 loss_fisheries_4)
	label var loss_heatwave "Loss from heatwave (USD)"
egen loss_total = rowtotal(loss_flood loss_drought loss_rainfall loss_heatwave)
	label var loss_total "Total loss from climate shocks (USD)"

recode evtfrq1 evtfrq2 evtfrq3 evtfrq4 (2=1) (3=1) (4=1) (5=0) (6=0) (7=0) (.= 0)
	label define shocks 1 "At least once in a year" 0 "Else", replace
	label values evtfrq1 evtfrq2 evtfrq3 evtfrq4 shocks
	label var evtfrq1 "Floods"
	label var evtfrq2 "Drought"
	label var evtfrq3 "Erratic rainfall"
	label var evtfrq4 "Heatwave"
	label var insitu "In situ adaptation"
		
* Demographics 	

gen denom = (moved==1 | inloc4==1)
	
gen female = 1 if sex==0 | sex==2 
	replace female = 0 if sex==1
	label var female "Female"
	gen _female = female if denom==1
	bys adm4 year: egen female4 = mean(_female)
	label var female4 "Share of females in the site on a given year"

gen married = 1 if marry==2
	replace married = 0 if marry!=2 & !missing(marry)
	label var married "Married"

gen nomarry = 1 if marry==1
	replace nomarry = 0 if marry!=1 & !missing(marry)
	label var nomarry "Never married"
	gen _nomarry = nomarry if denom==1
	bys adm4 year: egen nomarry4 = mean(_nomarry)
	label var nomarry4 "Share of adults who never married in the site on a given year"
	
gen edu = 0 if grade==0
	replace edu = 1 if grade==17 
	replace edu = 2 if grade==18 | grade==19
	replace edu = 3 if grade==20
	replace edu = 4 if grade==21 | grade==22
	label define edu 0 "None" 1 "Primary or other" 2 "Secondary" 3 "Vocational" 4 "Tertiary", replace
	label values edu edu
	label var edu "Highest grade attained"

gen noedu = 1 if grade==0
	replace noedu = 0 if grade>0 & !missing(grade)
	label var noedu "No education"
	gen _noedu = noedu if denom==1
	bys adm4 year: egen noedu4 = mean(_noedu)
	label var noedu4 "Share of household members with no education in the site on a given year"
	
gen relhead = (relhh==0) if !missing(relhh)
	label define relhead 0 "Other" 1 "Head", replace
	label values relhead relhead
	label var relhead "Head of the household"

gen relmaj = (resrel==2)
	label var relmaj "Member of religious majority"
	
foreach v of varlist age wi hhpay_usd relmaj	{
	gen _`v' = `v' if denom==1
	bys adm4 year: egen `v'4 = mean(_`v')
}
label var age4 "Average age in the site on a given year"
label var wi4 "Average wealth index in the site on a given year"
label var relmaj4 "Share of majority religion"

drop _*

sort habitable_id year
	
tempfile hhmy
save	`hhmy'
	
* To merge climate data

use "$OUTPUT\All_climate_annual.dta", clear
	keep if country==1
	tempfile clim
	save	`clim'
	
use `hhmy', clear
	merge m:1 habitable_id year using `clim', nogen keep(match) // _m==2 for lagged climate (years 2002 to 2011)
	*replace hhmid = 1 if hhmid==. & year>=2002 & year<=2011 // To assign lagged climate variables to head of household
	drop py
	egen panelid = group(habitable_id hhmid)
	order panelid, after(hhmid)
	
tab adm1, gen(reg)
	tab adm4, gen(loc)
	tab year, gen(year) // 22 years (2002-2023)

sort habitable_id hhmid year
	
save "$OUTPUT\HHMY_GH.dta", replace

* Collapsing person-year dataset into locality-year dataset

use "$OUTPUT\HHMY_GH.dta", clear

keep if year>=2012 & year<=2023

preserve
	collapse (mean) country region adm1 adm2 outmig_share4 outmig_sharel4 outmig_rate4 outmig_ratel4 temp_div prcp_div female4 nomarry4 noedu4 age4 lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div mean_temp sd_temp SPEI12_year lag_SPEI12 lag2_SPEI12, by(adm4 year)
	rename (temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12) ///
	(temp_div4 prcp_div4 lag_temp_div4 lag_prcp_div4 lag2_temp_div4 lag2_prcp_div4 SPEI12_year4 lag_SPEI124 lag2_SPEI124)
	sort adm1 adm2 adm4 year
	tempfile v4
	save	`v4'
restore

preserve
collapse (mean) temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12, by(adm1 year)
	rename (temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12) ///
	(temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121)
	sort adm1 year
	tempfile v1
	save	`v1'
restore
	
use `v4', clear
	merge m:1 adm1 year using `v1', keepusing(temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121) nogen
	order adm4, after(adm2)
	label var outmig_rate4 "Outmigration rate at the site level"
	label var outmig_share4 "Outmigration share at the site level"
	label var temp_div4 "Temperature anomalies at the site level"
	label var prcp_div4 "Rainfall anomalies at the site level"
	label var mean_temp "Long-run temperature mean (2002-2011)"
	label var sd_temp "Long-run temperature SD (2002-2011)"
	label var female4 "Share of females at the site level"
	label var nomarry4 "Share of non-married adults at the site level"
	label var age4 "Average age at the site level"
	label var noedu4 "Share of adults with no education at the site level"
	label var temp_div1 "Temperature anomalies at the region level"
	label var prcp_div1 "Rainfall anomalies at the region level"
	label var lag_temp_div4 "One-lag temperature anomalies at the site level"
	label var lag2_temp_div4 "Two-lag temperature anomalies at the site level"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia", replace
	label val country country
	label define region 1 "Volta" 2 "Northern" 3 "Kayes" 4 "Sikasso" 5 "Makueni" 6 "Baringo" 7 "Oromia" 8 "SNNP", replace
	label val region region

tab adm1, gen(reg)
tab adm4, gen(loc)
tab year, gen(year)
		
save "$OUTPUT\ADM_GH.dta", replace

* Standardising variable names across countries

use "$OUTPUT\ADM_GH.dta", clear

rename (temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121) (temp_div_s1 prcp_div_s1 lag_temp_div_s1 lag_prcp_div_s1 lag2_temp_div_s1 lag2_prcp_div_s1 SPEI12_year_s1 lag_SPEI12_s1 lag2_SPEI12_s1)

rename (outmig_share4 outmig_sharel4 outmig_rate4 outmig_ratel4 temp_div4 prcp_div4 female4 nomarry4 noedu4 age4 lag_temp_div4 lag_prcp_div4 lag2_temp_div4 lag2_prcp_div4 SPEI12_year4 lag_SPEI124 lag2_SPEI124) (outmig_share_s2 outmig_sharel_s2 outmig_rate_s2 outmig_ratel_s2 temp_div_s2 prcp_div_s2 female_s2 nomarry_s2 noedu_s2 age_s2 lag_temp_div_s2 lag_prcp_div_s2 lag2_temp_div_s2 lag2_prcp_div_s2 SPEI12_year_s2 lag_SPEI12_s2 lag2_SPEI12_s2)

save "$OUTPUT\ADM_GH.dta", replace
