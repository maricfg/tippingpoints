/*______________________________________________________________________________________
|                                                     									|
|							Social Tipping Points - Kenya								|	
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
	gen double habitable_id = qn
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 3000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
end

* Household level

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Main File.dta", clear
	habitableid
	drop date_of_visit enum_name qn adm1_pull_id - adm6 hhid resname restel kinname kintel res_name partner_name adm6a - duration_HH_MM_SS adm5 htype_lbl dc_tenure - comments_specify
	
rename zone_id adm0
rename ___adm6_latitude gps_latitude
	destring gps_latitude, replace
rename ___adm6_longitude gps_longitude
	destring gps_longitude, replace
rename ___adm6_altitude gps_altitude
	destring gps_altitude, replace
rename ___adm6_precision gps_accuracy
	destring gps_accuracy, replace

order adm1 adm2 adm3 adm4, after(adm0)

// Generate country variable to help later when data sets are combined
gen country = 3
	label var country "Country"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia" 5 "Thailand"
	label val country country
	order country, before (adm0)

// Generate wave variable
gen wave = 1
	label var wave "Data collected in wave 1 (2022) or wave 2 (2023)"
	order wave, before (country)

// Correct number of children
replace adults = hhsize if adults>hhsize & adults<. // Some households have more adult members than total hhsize - 11 obs
	replace children = hhsize - adults if adults>=hhsize & adults<.
	label var children "Number of children in the household"
	rename adults nadult
	label var hhsize "Household size"
	label var nadult "Number of adults in the household"
	
// Harmonise ethnicity with other countries
recode reseth (1=304) (2=301) (3=302) (4=304) (5=304) (6=304)
	replace reseth = 303 if reseth_other=="Njemis" | reseth_other=="Njemps"
	replace reseth = 304 if reseth_other=="Masai" | reseth_other=="Pokot" | reseth_other=="Turkana"
	label var reseth "Ethnicitiy of respondent"
	label define ethnicity 101 "Akan" 102 "Ga-Dangme" 103 "Ewe" 104 "Guan" 105 "Gruma" 106 "Mole-Dagbani" 107 "Grussi" 108 "Mande" 109 "Basali" 110 "Fulani" 111 "Kotokoli" 112 "Kabire" 113 "Konkomba" 114 "Togo Karra" 115 "Other Ghana" 201 "Bambara" 202 "Malinké" 203 "Peul/Foulfoulbé" 204 "Sonrai/Djerma" 205 "Sarakolé/Soninké" 206 "Kassonké" 207 "Sénoufo" 208 "Dogon" 209 "Maure" 210 "Tamacheq" 211 "Bobo" 212 "Dafing" 213 "Minianka" 214 "Haoussa" 215 "Samogo" 216 "Bozo" 217 "Arabe" 218 "Mossi" 219 "Other Mali" 301 "Kamba" 302 "Kalenjin" 303 "Njemps" 304 "Other Kenya", replace
	label values reseth ethnicity

// Harmonise religion with other countries
recode resrel (7=8) (8=9)
	label var resrel "Religion of respondent"
	label define religion 1 "No religion" 2 "Christianity" 3 "Islam" 4 "Buddhism" 5 "Hinduism" 6 "Animist" 7 "Tradionalist" 8 "Other" 9 "Not know"
	label val resrel religion

preserve
	keep habitable_id reseth resrel
	rename (reseth resrel) (reseth_w1 resrel_w1)
	sort habitable_id
	tempfile res1 
	save	`res1'
restore
	
// Harmonise timestamp with wave 2
rename start timesta
	format timesta %td

rename end timeend
	format timeend %td
	
tempfile intro
save	`intro'

* Household roster

use ___uuid qn using "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Main File.dta", clear
	sort ___uuid
tempfile id
save	`id'

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - HH Roster.dta", clear
	sort ___uuid
	merge m:1 ___uuid using `id', nogen keepusing(qn) keep(match) // Dropped 2 HHMs from same hh that do not have matching file at hh level
	habitableid
	sort habitable_id hhmid
	drop name ___index - ___uuid qn hh_roster_key

// Standardise labels
label var sex "Sex at birth"
	label define sex 0 "Female" 1 "Male", replace
	label values sex sex
label var age "Age (in completed years)"
label var marry "Marital status"
	label define marry 1 "Never married" 2 "Married" 3 "Divorced" 4 "Separated" 5 "Widow/widower", replace
	label values marry marry
label var relhh "Relationship to household head"
	recode relhh (-6666 = 6)
	label define relhh 0 "Head" 1 "Spouse" 2 "Partner" 3 "Parent" 4 "Child" 5 "Sibling" 6 "Other", replace
	label values relhh relhh
label var grade "Highest grade that person has completed (excluding pre-primary)"
	label define grade 0 "None" 18 "Grade 1 to 8" 19 "Grade 9 to 12" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)" 30 "Adult literacy" 31 "Religious education" -6666 "Other", replace
	recode grade (18 30 31 = 17)
	replace grade = 19 if grade_other=="A-level" | grade_other=="FORM 4" | grade_other=="Form  four" | grade_other=="Form 4" | grade_other=="Form four"
	replace grade = 17 if grade_other=="Class 8" | grade_other=="Form three" | grade_other=="Form two" 
	drop grade_other
	label define grade 0 "None" 17 "Primary" 18 "Lower secondary" 19 "Upper secondary" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)", replace
	label values grade grade
label var liveh "Does person currently live with this household?"
	label define liveh 1 "Yes" 2 "No, living somewhere else in the same locality" 3 "No, living somewhere else outside the locality" 4 "No, passed away", replace
	label values liveh liveh
label var mig "Since 2012, has X lived outside the commune for at least 3 months?"
	label define mig 0 "No" 1 "Yes", replace
	label values mig mig
	
expand 11	
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
	replace year = 2022 if year==11
	sort habitable_id hhmid year
	
tempfile hhm
save	`hhm'

* Migration history

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Migration Section.dta", clear
	merge m:1 ___uuid using `id', keepusing(qn) keep(match) nogen // Dropped 2 obs from same hh that do not have matching file at hh level	
	habitableid
	rename mig_hhmid hhmid
	sort habitable_id hhmid
	drop mig_name ___index - qn coutr_address
	
rename migyear year
	rename coun level1
	rename subcou level2
	rename ward level3
	rename reason_other reason_specify

label var level1 "Level 1"
label var level2 "Level 2"
label var level3 "Level 3"

sort habitable_id hhmid moveid
/*by habitable_id hhmid: egen tocorrect1 = count(year) if year==-99
by habitable_id hhmid: egen tocorrect2 = min(tocorrect1)
by habitable_id hhmid: replace year = year[_n-1]-1 if year==-99 & tocorrect1==1 & tocorrect2>=1 & tocorrect2<. // To assign previous year to respondents that had lived all their lives there.
drop tocorrect* */
replace coutr = . if year==-99 // 28 obs
replace year = . if year==-99

replace reason = 1 if reason_specify=="Bought land" | reason_specify=="Given land" | reason_specify=="Retirement" 
replace reason = 3 if reason_specify=="Marriage" 
replace reason = 6 if regexm(reason_specify,"water")==1
replace reason = 6 if reason_specify=="Pandemic" | reason_specify=="Religious" | reason_specify=="Retrenchment" | reason_specify=="Visit"		
label define reason 1 "Work- or income-related reasons" 2 "Educational reasons" 3 "Family-related reasons" 4 "Environment-related reasons" 5 "Conflict" 6 "Other", replace	
label values reason reason

sort habitable_id hhmid year

tempfile mighis
save	`mighis'

* Dwelling characteristics

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Main File.dta", clear
	habitableid
	keep habitable_id building typeofhouse dc_tenure - dc_tec_0
	
rename dc_* *
	rename floor_other floor_specify
	rename cfuel_other cfuel_specify
	rename water_other water_specify
	rename tec_* tec*

rename tec0 tec8
	label var tec1 "Radio"
	label var tec2 "TV"
	label var tec3 "Computer/laptop"
	label var tec4 "Tablet"
	label var tec5 "Landline"
	label var tec6 "Mobile phone without internet"
	label var tec7 "Mobile phone with internet"
	label var tec8 "None"
	
tempfile dwe
save	`dwe'

keep habitable_id rooms roof wall floor elect cfuel water toilet tec1 tec2 tec3 tec4 tec5 tec6 tec7 tec8 floor_specify cfuel_specify water_specify
ds habitable_id, not
rename (`r(varlist)') (=_w1)
tempfile hh1
save	`hh1'

* Livelihoods

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Main File.dta", clear
	habitableid
	keep habitable_id lh_empl - lh_hhpay_probe2
	
rename lh_* *	
rename (act1_other act2_other actsec1_other actsec2_other acttp1_other acttp2_other) (act1_specify act2_specify actsec1_specify actsec2_specify acttp1_specify acttp2_specify) 
label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"
	
tempfile liv
save	`liv'

use "$INPUT\Kenya\Spouse\Habitable - Spouse Questionnaire -Main File.dta", clear
	habitableid
	keep habitable_id - end lh_empl - lh_chact

rename lh_* *	
rename (act1_other act2_other actsec1_other actsec2_other acttp1_other acttp2_other) (act1_specify act2_specify actsec1_specify actsec2_specify acttp1_specify acttp2_specify) 
label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"

bys habitable_id: gen test = _n // Only one wife per household head
	drop test 

ds habitable_id, not
rename (`r(varlist)') (s=)
sort habitable_id
	
tempfile sact
save	`sact'

* Perceptions of climate risks

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Events Section.dta", clear
	merge m:1 ___uuid using `id', keepusing(qn) keep(match master) nogen // Kept 2 obs from same hh that do not have matching file at hh level	
	habitableid
	drop ___index - qn evt_note3 evtname_en

rename (evtha evtfi) (evtlha evtlfi)
	
reshape wide evtfrq-evtoth, i(habitable_id) j(evtid)
	label var evtfrq1 "Frequency of flood"
	label var evtyr1 "In which year did flood affect you the most?"
	label var evtint1 "How strong was the flood?"
	label var evtlh1 "Percentage loss on housing by flood"
	label var evtla1 "Percentage loss on land by flood"
	label var evtlha1 "Percentage loss on harvest by flood"
	label var evtll1 "Percentage loss on livestock by flood"
	label var evtlfi1 "Percentage loss on fisheries by flood"
	label var evtlhh1 "Percentage loss on health of household members by flood"
	label var evtlhd1 "Did any household member die as a result of flood?"
	label var evtoth1 "Was there any non-environmental event that also caused losses around the same time?"

	label var evtfrq2 "Frequency of drought"
	label var evtyr2 "In which year did drought affect you the most?"
	label var evtint2 "How strong was the drought"
	label var evtlh2 "Percentage loss on housing by drought"
	label var evtla2 "Percentage loss on land by drought"
	label var evtlha2 "Percentage loss on harvest by drought"
	label var evtll2 "Percentage loss on livestock by drought"
	label var evtlfi2 "Percentage loss on fisheries by drought"
	label var evtlhh2 "Percentage loss on health of household members by drought"
	label var evtlhd2 "Did any household member die as a result of drought?"
	label var evtoth2 "Was there any non-environmental event that also caused losses around the same time?"

	label var evtfrq3 "Frequency of erratic rainfall"
	label var evtyr3 "In which year did erratic rainfall affect you the most?"
	label var evtint3 "How strong was the erratic rainfall?"
	label var evtlh3 "Percentage loss on housing by erratic rainfall"
	label var evtla3 "Percentage loss on land by erratic rainfall"
	label var evtlha3 "Percentage loss on harvest by erratic rainfall"
	label var evtll3 "Percentage loss on livestock by erratic rainfall"
	label var evtlfi3 "Percentage loss on fisheries by erratic rainfall"
	label var evtlhh3 "Percentage loss on health of household members by erratic rainfall"
	label var evtlhd3 "Did any household member die as a result of erratic rainfall?"
	label var evtoth3 "Was there any non-environmental event that also caused losses around the same time?"

	label var evtfrq4 "Frequency of heatwave"
	label var evtyr4 "In which year did heatwave affect you the most?"
	label var evtint4 "How strong was the heatwave?"
	label var evtlh4 "Percentage loss on housing by heatwave"
	label var evtla4 "Percentage loss on land by heatwave"
	label var evtlha4 "Percentage loss on harvest by heatwave"
	label var evtll4 "Percentage loss on livestock by heatwave"
	label var evtlfi4 "Percentage loss on fisheries by heatwave"
	label var evtlhh4 "Percentage loss on health of household members by heatwave"
	label var evtlhd4 "Did any household member die as a result of heatwave?"
	label var evtoth4 "Was there any non-environmental event that also caused losses around the same time?"

	label define yesno 0 "No" 1 "Yes", replace
	label values evtlhd1 evtlhd2 evtlhd3 evtlhd4 evtoth1 evtoth2 evtoth3 evtoth4 yesno
	
tempfile risks
save	`risks'

* Household adaptation

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Household adaptation.dta", clear
	merge m:1 ___uuid using `id', keepusing(qn) keep(match master) nogen // Kept 2 obs from same hh that do not have matching file at hh level		
	habitableid
	drop ___index - ___uuid adpname_en qn

rename adp_other adp_specify
	drop adp_specify // Temporarily excluded from the analysis
	
reshape wide adp adpch adpno, i(habitable_id) j(adpid)
	label var adp1 "Household adapted through financial means (e.g.loans, insurance, cooperatives)"
	label var adp2 "Household adapted through external assistance"
	label var adp3 "Household adapted through home improvements"
	label var adp4 "Household adapted through protection (own or community shelter)"
	label var adp5 "Household adapted through hired labour"
	label var adp6 "Household adapted through improved production (e.g. diversified crops, used fertiliser, alterantive sources of irrigation)"
	label var adp7 "Household adapted through accessed training"
	label var adp8 "Household adapted through innovation of techniques (e.g. bought new equipment, new breeds)"
	label var adp9 "Household adapted through female labour outside the house"
	label var adp10 "Household adapted through hours worked by household members"
	label var adp11 "Household adapted through changed main activity (e.g. started ir stopped work)"
	label var adp12 "Household adapted through mobility within ward"
	label var adp13 "Household adapted through migration outside ward"
	label var adp14 "Household adapted through return migration to ward"
	label var adp15 "Household adapted through other response, specify"
	label values adp? adp?? yesno
	
	label var adpch1 "Have your financial means increased or decreased"
	label var adpch2 "Has this external assistance increased or decreased"
	label var adpch3 "Have home improvements increased or decreased"
	label var adpch4 "Has protection increased or decreased"
	label var adpch5 "Has hired labour increased or decreased"
	label var adpch6 "Has improved production increased or decreased"
	label var adpch7 "Has training increased or decreased"
	label var adpch8 "Has innovation of techniques increased or decreased"
	label var adpch9 "Has female labour outside the house  increased or decreased"
	label var adpch10 "Has hours workd increased or decreased"
	label var adpch11 "Has changed main work activity increased or decreased"
	label var adpch12 "Has mobility within ward increased or decreased"
	label var adpch13 "Has migration outside ward increased or decreased"
	label var adpch14 "Has return migration to ward increased or decreased"
	label var adpch15 "Has other increased or decreased"
	label define direction 1 "Increased" 2 "Decreased", replace
	foreach var of varlist adpch1 adpch2 adpch3 adpch4 adpch5 adpch6 adpch7 adpch8 adpch9 adpch10 adpch11 adpch12 adpch13 adpch14 adpch15 {
		label values `var' direction
	}

	label define noadap 1 "Would like but have not done it" 2 "Are not interested", replace
	foreach var of varlist adpno1 adpno2 adpno3 adpno4 adpno5 adpno6 adpno7 adpno8 adpno9 adpno10 adpno11 adpno12 adpno13 adpno14 adpno15 {
		label var `var' "Reason for no adaptation"
		label values `var' noadap
	}

tempfile hhadap
save	`hhadap'

* Adaptive capacity

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Main File.dta", clear
	habitableid
	keep habitable_id ac1 - ac12

tempfile adapc
save	`adapc'

* Personality traits

use "$INPUT\Kenya\HH\Habitable- HH Questionnaire - Main File.dta", clear
	habitableid
	keep habitable_id pw1 - pw11

tempfile ptraits
save	`ptraits'

* Merge all sections

use `intro', clear
	merge 1:1 habitable_id using `dwe', nogen 
	merge 1:1 habitable_id using `liv', nogen
	merge 1:1 habitable_id using `sact', nogen keepusing(sactpay1 sactpay2) keep(match master) // To exclude 186 spouses with no hh head data
	merge 1:1 habitable_id using `risks', nogen
	merge 1:1 habitable_id using `hhadap', nogen
	merge 1:1 habitable_id using `adapc', nogen
	merge 1:1 habitable_id using `ptraits', nogen
	
tempfile ke1
save	`ke1'

use `hhm', clear
	merge 1:m habitable_id hhmid year using `mighis', nogen
	tempfile long
	save	`long'

use `ke1', clear
	merge 1:m habitable_id using `long', nogen
	drop if habitable_id==. // 1 obs
	sort habitable_id hhmid year
	
by habitable_id hhmid year: gen test = _n
	tab test, m // Up to 3 obs per year
	drop test

gen roster_source = "Old members"	
	
tempfile kepy1
save	`kepy1'

collapse wave liveh, by(habitable_id hhmid)
tempfile id1
save	`id1'

collapse wave, by(habitable_id)
tempfile test1
save	`test1'

*********************************************************** W2 *************************************************************
	
use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Main File - STATA.dta", clear
	habitableid
	drop date_of_visit qn - adm6 rec_note1 - hhid adm5 resname name_note1x - restel_again adm6a dc_note1 - ___index
	
rename ___adm6_latitude gps_latitude
rename ___adm6_longitude gps_longitude
rename ___adm6_altitude gps_altitude
rename ___adm6_precision gps_accuracy

sort gps_latitude gps_longitude
tempfile new
save	`new'
	
// To remove location from wave 2 in order to keep location from wave 1 only
*drop gps_latitude - adm4

// Generate country variable to help later when datasets are combined
gen country = 3
	label var country "Country"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia" 5 "Thailand"
	label val country country
	order country, after(habitable_id)

// Generate wave variable
gen wave = 2
	label var wave "Data collected in wave 1 (2022) or wave 2 (2023)"
	order wave, before (country)
		
// Correct number of children
replace adults = hhsize if adults > hhsize & adults<. // some households have more adult members than total hhsize - 0 changes made
	replace children = hhsize - adults if adults>=hhsize & adults<.
	label var children "Number of children in the household"
	rename adults nadult
	label var hhsize "Household size"
	label var nadult "Number of adults in the household"
	
// Harmonise ethnicity with other countries
recode reseth (1=304) (2=301) (3=302) (4=304) (5=304) (6=304)
	replace reseth = 303 if reseth_other=="Njemis" | reseth_other=="Njemps" | reseth_other=="Ijemps" | reseth_other=="Ijems" | reseth_other=="Injemps" | reseth_other=="Njemps" | reseth_other=="Njems" 
	replace reseth = 304 if reseth_other=="Masai" | reseth_other=="Pokot" | reseth_other=="Turkana" | reseth_other=="Ilchamus" 
	label var reseth "Ethnicitiy of respondent"
	label define ethnicity 101 "Akan" 102 "Ga-Dangme" 103 "Ewe" 104 "Guan" 105 "Gruma" 106 "Mole-Dagbani" 107 "Grussi" 108 "Mande" 109 "Basali" 110 "Fulani" 111 "Kotokoli" 112 "Kabire" 113 "Konkomba" 114 "Togo Karra" 115 "Other Ghana" 201 "Bambara" 202 "Malinké" 203 "Peul/Foulfoulbé" 204 "Sonrai/Djerma" 205 "Sarakolé/Soninké" 206 "Kassonké" 207 "Sénoufo" 208 "Dogon" 209 "Maure" 210 "Tamacheq" 211 "Bobo" 212 "Dafing" 213 "Minianka" 214 "Haoussa" 215 "Samogo" 216 "Bozo" 217 "Arabe" 218 "Mossi" 219 "Other Mali" 301 "Kamba" 302 "Kalenjin" 303 "Njemps" 304 "Other Kenya", replace
	label values reseth ethnicity

// Harmonise religion with other countries
recode resrel (7=8) (8=9)
	label var resrel "Religion of respondent"
	label define religion 1 "No religion" 2 "Christianity" 3 "Islam" 4 "Buddhism" 5 "Hinduism" 6 "Animist" 7 "Tradionalist" 8 "Other" 9 "Not know", replace
	label val resrel religion

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
	
// Harmonise timestamp with wave 2
rename start timesta
	format timesta %td

rename end timeend
	format timeend %td

sort habitable_id
	
tempfile intro2
save	`intro2'	

* Dwelling characteristics

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Main File - STATA.dta", clear
	habitableid
	keep habitable_id dc_improv_qlbl dc_improv dc_tenure - dc_tec_0
	
rename dc_* *
	rename roof_other roof_specify
	rename wall_other wall_specify
	rename floor_other floor_specify
	rename cfuel_other cfuel_specify
	rename water_other water_specify
	rename toilet_other toilet_specify
	rename tec_* tec*
		
rename tec0 tec8
	label var tec1 "Radio"
	label var tec2 "TV"
	label var tec3 "Computer/laptop"
	label var tec4 "Tablet"
	label var tec5 "Landline"
	label var tec6 "Mobile phone without internet"
	label var tec7 "Mobile phone with internet"
	label var tec8 "None"
	
merge 1:1 habitable_id using `hh1', nogen keep(master match)

	foreach v of varlist rooms roof wall floor elect cfuel water toilet elect tec1 tec2 tec3 tec4 tec5 tec6 tec7 tec8	{
		replace `v' = `v'_w1 if `v'==.
	}
	foreach v of varlist floor_specify cfuel_specify water_specify	{
		replace `v' = `v'_w1 if `v'==""
	}
	
	drop rooms_w1 roof_w1 wall_w1 floor_w1 elect_w1 cfuel_w1 water_w1 toilet_w1 tec1_w1 tec2_w1 tec3_w1 tec4_w1 tec5_w1 tec6_w1 tec7_w1 tec8_w1 floor_specify_w1 cfuel_specify_w1 water_specify_w1
	
tempfile dwe2
save	`dwe2'	

* Livelihoods

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Main File - STATA.dta", clear
	habitableid
	keep habitable_id lh_empl - lh_hhrempay
	
rename lh_* *	
	label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"

tempfile liv2
save	`liv2'

use "$INPUT\Kenya\Wave 2\Spouse_Wave 2_20230711\Spouse_Wave 2_20230711\Spouse W2 - Main File -  STATA.dta", clear
	habitableid
	keep habitable_id - end lh_empl - lh_hhrempay

rename lh_* *	
rename (act1_other act2_other actsec1_other actsec2_other acttp1_other acttp2_other) (act1_specify act2_specify actsec1_specify actsec2_specify acttp1_specify acttp2_specify) 
label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"

bys habitable_id: gen test = _n // Only one wife per household head
	drop test 

ds habitable_id, not
rename (`r(varlist)') (s=)
sort habitable_id
	
tempfile sact2
save	`sact2'
	
* Perceptions of climatic risks	

use ___uuid qn using "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Main File - STATA.dta", clear
	sort ___uuid
tempfile id
save	`id'

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Perceptions of climatic risk - STATA.dta", clear
	rename ___submission__uuid ___uuid
	sort ___uuid
	merge m:1 ___uuid using `id', keepusing(qn) keep(match master) nogen
	habitableid
	drop ___index - qn evt_note2 evt_note3 evtname_en
	
rename (evtha evtfi) (evtlha evtlfi)
	destring evtid, replace
	
reshape wide evtfrq-evtoth, i(habitable_id) j(evtid)
	label var evtfrq1 "Frequency of flood"
	label var evtyr1 "In which year did flood affect you the most?"
	label var evtint1 "How strong was the flood?"
	label var evtlh1 "Percentage loss on housing by flood"
	label var evtla1 "Percentage loss on land by flood"
	label var evtlha1 "Percentage loss on harvest by flood"
	label var evtll1 "Percentage loss on livestock by flood"
	label var evtlfi1 "Percentage loss on fisheries by flood"
	label var evtlhh1 "Percentage loss on health of household members by flood"
	label var evtlhd1 "Did any household member die as a result of flood?"
	label var evtoth1 "Was there any non-environmental event that also caused losses around the same time?"

	label var evtfrq2 "Frequency of drought"
	label var evtyr2 "In which year did drought affect you the most?"
	label var evtint2 "How strong was the drought"
	label var evtlh2 "Percentage loss on housing by drought"
	label var evtla2 "Percentage loss on land by drought"
	label var evtlha2 "Percentage loss on harvest by drought"
	label var evtll2 "Percentage loss on livestock by drought"
	label var evtlfi2 "Percentage loss on fisheries by drought"
	label var evtlhh2 "Percentage loss on health of household members by drought"
	label var evtlhd2 "Did any household member die as a result of drought?"
	label var evtoth2 "Was there any non-environmental event that also caused losses around the same time?"

	label var evtfrq3 "Frequency of erratic rainfall"
	label var evtyr3 "In which year did erratic rainfall affect you the most?"
	label var evtint3 "How strong was the erratic rainfall?"
	label var evtlh3 "Percentage loss on housing by erratic rainfall"
	label var evtla3 "Percentage loss on land by erratic rainfall"
	label var evtlha3 "Percentage loss on harvest by erratic rainfall"
	label var evtll3 "Percentage loss on livestock by erratic rainfall"
	label var evtlfi3 "Percentage loss on fisheries by erratic rainfall"
	label var evtlhh3 "Percentage loss on health of household members by erratic rainfall"
	label var evtlhd3 "Did any household member die as a result of erratic rainfall?"
	label var evtoth3 "Was there any non-environmental event that also caused losses around the same time?"

	label var evtfrq4 "Frequency of heatwave"
	label var evtyr4 "In which year did heatwave affect you the most?"
	label var evtint4 "How strong was the heatwave?"
	label var evtlh4 "Percentage loss on housing by heatwave"
	label var evtla4 "Percentage loss on land by heatwave"
	label var evtlha4 "Percentage loss on harvest by heatwave"
	label var evtll4 "Percentage loss on livestock by heatwave"
	label var evtlfi4 "Percentage loss on fisheries by heatwave"
	label var evtlhh4 "Percentage loss on health of household members by heatwave"
	label var evtlhd4 "Did any household member die as a result of heatwave?"
	label var evtoth4 "Was there any non-environmental event that also caused losses around the same time?"

	label define yesno 0 "No" 1 "Yes", replace
	label values evtlhd1 evtlhd2 evtlhd3 evtlhd4 evtoth1 evtoth2 evtoth3 yesno

tempfile risks2
save	`risks2'
	
* Household adaptation	

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Household Adaptation - STATA.dta", clear
	rename ___submission__uuid ___uuid
	sort ___uuid
	merge m:1 ___uuid using `id', keepusing(qn) keep(match master) nogen
	habitableid
	drop ___index - qn adpname_en

destring adpid, replace
rename adp_other adp_specify
	drop adp_specify // Temporarily excluded from the analysis
	
reshape wide adp adpch adpno, i(habitable_id) j(adpid)
	label var adp1 "Household adapted through financial means (e.g.loans, insurance, cooperatives)"
	label var adp2 "Household adapted through external assistance"
	label var adp3 "Household adapted through home improvements"
	label var adp4 "Household adapted through protection (own or community shelter)"
	label var adp5 "Household adapted through hired labour"
	label var adp6 "Household adapted through improved production (e.g. diversified crops, used fertiliser, alterantive sources of irrigation)"
	label var adp7 "Household adapted through accessed training"
	label var adp8 "Household adapted through innovation of techniques (e.g. bought new equipment, new breeds)"
	label var adp9 "Household adapted through female labour outside the house"
	label var adp10 "Household adapted through hours worked by household members"
	label var adp11 "Household adapted through changed main activity (e.g. started ir stopped work)"
	label var adp12 "Household adapted through mobility within ward"
	label var adp13 "Household adapted through migration outside ward"
	label var adp14 "Household adapted through return migration to ward"
	label var adp15 "Household adapted through other response, specify"
	label values adp? adp?? yesno
	
	label var adpch1 "Have your financial means increased or decreased"
	label var adpch2 "Has this external assistance increased or decreased"
	label var adpch3 "Have home improvements increased or decreased"
	label var adpch4 "Has protection increased or decreased"
	label var adpch5 "Has hired labour increased or decreased"
	label var adpch6 "Has improved production increased or decreased"
	label var adpch7 "Has training increased or decreased"
	label var adpch8 "Has innovation of techniques increased or decreased"
	label var adpch9 "Has female labour outside the house  increased or decreased"
	label var adpch10 "Has hours workd increased or decreased"
	label var adpch11 "Has changed main work activity increased or decreased"
	label var adpch12 "Has mobility within ward increased or decreased"
	label var adpch13 "Has migration outside ward increased or decreased"
	label var adpch14 "Has return migration to ward increased or decreased"
	label var adpch15 "Has other increased or decreased"
	label define direction 1 "Increased" 2 "Decreased", replace
	foreach var of varlist adpch1 adpch2 adpch3 adpch4 adpch5 adpch6 adpch7 adpch8 adpch9 adpch10 adpch11 adpch12 adpch13 adpch14 adpch15 {
		label values `var' direction
	}

	label define noadap 1 "Would like but have not done it" 2 "Are not interested", replace
	foreach var of varlist adpno1 adpno2 adpno3 adpno4 adpno5 adpno6 adpno7 adpno8 adpno9 adpno10 adpno11 adpno12 adpno13 adpno14 adpno15 {
		label var `var' "Reason for no adaptation"
		label values `var' noadap
	}

tempfile hhadap2
save	`hhadap2'

* Adaptive capacity

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Main File - STATA.dta", clear
	habitableid
	drop start - ac_note2 pw_note1 - ___index

tempfile adapc2
save	`adapc2'

* Personality traits

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Main File - STATA.dta", clear
	habitableid
	keep habitable_id pw8 - pw11

tempfile ptraits2
save	`ptraits2'

* Place attachment

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Main File - STATA.dta", clear
	habitableid
	keep habitable_id place1 - place6

tempfile place
save	`place'

* Social capital

/*use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Social capital Q7 and 8- STATA.dta", clear
	rename ___submission__uuid ___uuid
	sort ___uuid
	merge m:1 ___uuid using `id', keepusing(qn) keep(match master) nogen
	habitableid
	sort habitable_id pos1 pos2
	keep habitable_id pos1 - soc8_other
	tempfile idsk
	save	`idsk'
*/
use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Main File - STATA.dta", clear
	habitableid
	keep habitable_id soc1 - soc6_count
	*merge 1:m habitable_id using `idsk', keep(match master) nogen

tempfile sock
save	`sock'

* Household roster

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - HH Roster- STATA.dta", clear
	rename ___submission__uuid ___uuid
	sort ___uuid
	merge m:1 ___uuid using `id', keepusing(qn) nogen 
	habitableid
	rename ___index hhmid2
	order hhmid2, after(hhmid)
	sort habitable_id hhmid2
	drop fname - name ___parent_table_name - qn
	
replace liveh = nm_liveh if liveh==. & nm_liveh<. // 136 obs
replace liveh = 1 if liveh==. & habitable_id==3000000502159 & hhmid==1 // 1 obs
replace liveh = 1 if liveh==. & hh_roster_key_pre=="New member registered" // 56 obs
	
// Standardise labels
label var sex "Sex at birth"
	label define sex 0 "Female" 1 "Male", replace
	label values sex sex
label var age "Age (in completed years)"
label var marry "Marital status"
	label define marry 1 "Never married" 2 "Married" 3 "Divorced" 4 "Separated" 5 "Widow/widower", replace
	label values marry marry
label var relhh "Relationship to household head"
	recode relhh (-6666 = 6)
	label define relhh 0 "Head" 1 "Spouse" 2 "Partner" 3 "Parent" 4 "Child" 5 "Sibling" 6 "Other", replace
	label values relhh relhh
label var grade "Highest grade that person has completed (excluding pre-primary)"
	label define grade 0 "None" 18 "Grade 1 to 8" 19 "Grade 9 to 12" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)" 30 "Adult literacy" 31 "Religious education" -6666 "Other", replace
	recode grade (18 30 31 = 17)
	replace grade = 19 if grade_other=="A-level" | grade_other=="FORM 4" | grade_other=="Form  four" | grade_other=="Form 4" | grade_other=="Form four"
	replace grade = 17 if grade_other=="Class 8" | grade_other=="Form three" | grade_other=="Form two" 
	drop grade_other
	label define grade 0 "None" 17 "Primary" 18 "Lower secondary" 19 "Upper secondary" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)", replace
	label values grade grade
label var liveh "Does person currently live with this household?"
	label define liveh 1 "Yes" 2 "No, living somewhere else in the same locality" 3 "No, living somewhere else outside the locality" 4 "No, passed away", replace
	label values liveh liveh
label var mig "Since welast interviewed you, has X lived outside the commune for at least 3 months?"
	label define mig 0 "No" 1 "Yes", replace
	label values mig mig
	
*bys habitable_id hhmid: gen test = _n // Each household member moved only once	(either 2022 or 2023)
expand 12	
	sort habitable_id hhmid2
	by habitable_id hhmid2: gen year = _n
	order year, after(hhmid2)
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
	sort habitable_id hhmid2 year
	
tempfile hhm2
save	`hhm2'

* Migration history

use "$INPUT\Kenya\Wave 2\HH _Wave 2_20230711\HH _Wave 2_20230711\HH W2 - Migration history - STATA.dta", clear
	rename ___submission__uuid ___uuid
	sort ___uuid
	merge m:1 ___uuid using `id', keepusing(qn) nogen 
	habitableid
	rename ___parent_index hhmid2
	order hhmid2, after(habitable_id)
	sort habitable_id hhmid2
	drop ___index ___parent_table_name ___uuid qn

rename migyear year
	rename coun level1
	rename subcou level2
	rename ward level3
	rename reason_other reason_specify

label var level1 "Level 1"
label var level2 "Level 2"
label var level3 "Level 3"

destring moveid, replace

sort habitable_id hhmid moveid
/*by habitable_id hhmid: egen tocorrect1 = count(year) if year==77777 | year==99999
by habitable_id hhmid: egen tocorrect2 = min(tocorrect1)
replace coutr = . if year==77777 | year==99999
by habitable_id hhmid: replace year = year[_n-1]-1 if (year==99999 | year==77777) & tocorrect1==1 & tocorrect2==1 // To assign previous year to respondents that had lived all their lives there.
drop tocorrect* */

replace coutr = . if year==77777 | year==99999
replace year = . if year==77777 | year==99999

replace reason = 1 if reason_specify=="Completed contract"  
replace reason = 3 if reason_specify=="Marriage" | reason_specify=="Married she lives at her husband's home" | reason_specify=="Separated with the Husband"
replace reason = 6 if reason_specify=="Break from school." | reason_specify=="Health reasons" | reason_specify=="School break of two weeks" | reason_specify=="Unknown"	
// School breaks of less than 3 months should not have been captured in the survey.
label define reason 1 "Work- or income-related reasons" 2 "Educational reasons" 3 "Family-related reasons" 4 "Environment-related reasons" 5 "Conflict" 6 "Other", replace	
label values reason reason

// 77 moves have no year - Replacing year with the furthest possible year
destring migyear_pre, replace
replace year = migyear_pre + 1 if (year==77777 | year==99999) & migyear_pre<2023
replace year = migyear_pre if (year==77777 | year==99999) & migyear_pre==2023

sort habitable_id hhmid2 year

tempfile mighis2
save	`mighis2'

* Merge all sections

use `intro2', clear
	merge 1:1 habitable_id using `dwe2', nogen 
	merge 1:1 habitable_id using `liv2', nogen
	merge 1:1 habitable_id using `sact2', nogen keepusing(sactpay1 sactpay2) keep(match master) // To exclude 187 spouses with no hh head data
	merge 1:1 habitable_id using `risks2', nogen
	merge 1:1 habitable_id using `hhadap2', nogen
	merge 1:1 habitable_id using `adapc2', nogen
	merge 1:1 habitable_id using `ptraits2', nogen
	merge 1:1 habitable_id using `place', nogen
	merge 1:1 habitable_id using `sock', nogen

tempfile ke2
save	`ke2'

use `hhm2', clear
	merge 1:m habitable_id hhmid2 year using `mighis2', nogen keep(match master)
	tempfile long2
	save	`long2'

use `ke2', clear
	merge 1:m habitable_id using `long2', nogen 
	sort habitable_id hhmid year

bys habitable_id hhmid year: gen test = _n
	tab test, m
	drop test
 	
tempfile kepy2
save	`kepy2'

collapse wave liveh, by(habitable_id hhmid)
tempfile id2
save	`id2'

collapse wave, by(habitable_id)
tempfile test2
save	`test2'
	
*********************************************************** W1 & W2 *************************************************************

use `test1', clear
	merge 1:1 habitable_id using `test2' // 15% household attrition
	keep if _merge==1
	rename _merge attr
	drop wave
	tempfile attrition
	save	`attrition'
	
use `id1', clear
	tab liveh // No HHMs passed away in Wave 1
	merge 1:1 habitable_id hhmid using `id2', update replace // To identify hhm who have passed away in Wave 2 (liveh has non-missing values in both waves)
		tab liveh // 18 HHMs passed away in Wave 2
		drop wave
		rename _merge waveid
		recode waveid (5=3)
		label define waveid 1 "Only in Wave 1" 2 "Only in Wave 2" 3 "In both waves", replace // 157 households (398 HHMs) in Wave 1 only and all correspond to attrition
		label values waveid waveid
		label var waveid "Wave for each individual"
	merge m:1 habitable_id using `attrition', nogen
		drop if attr==1 // To keep only households present in both waves
sort habitable_id hhmid	
	egen py = group(habitable_id hhmid)
	order py, after(hhmid)
	*drop if liveh==4 // To drop hhm who passed away - 18 obs
	drop liveh

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
	
tempfile w1w2
save	`w1w2'

use `kepy1', clear
	append using `kepy2' // Each wave contains all years since 2012, and year 2022 appears in both waves. More than one move per year was recorded.
	
// To clean empty duplicates and duplicates for year 2022

sort habitable_id hhmid year wave
	order hhmid, after(habitable_id)
	order year, after(hhmid)

count if roster_source=="New members" & wave==1	// 0 obs

drop if roster_source=="Old members" & year<2022 & wave==2
	
bys habitable_id hhmid year: egen todrop1 = count(coutr)
	drop if todrop1==0 & roster_source=="Old members" & year==2022 & wave==2 // If never moved, keep wave 1.
sort habitable_id hhmid year wave
	drop if todrop1==1 & roster_source=="Old members" & year==2022 & coutr==. // If moved only once, keep the wave when moved.
sort habitable_id hhmid year wave moveid // The lower the moveid the more recent the move.
	*by habitable_id hhmid year wave: gen todrop2 = _n if todrop1==2 | todrop1==3
	drop if todrop1==2 & roster_source=="Old members" & year==2022 & coutr==. // If moved twice (0,2 or 2,0), drop wave with no move. If (1,1), keep both waves.
	drop if todrop1==3 & roster_source=="Old members" & year==2022 & coutr==. // If moved three times (0,3 or 3,0), drop wave with no move. If (2,1 or 1,2), keep both waves.
drop todrop*

// To keep only the longest move per year

* To calculate length of migration event in months
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

gsort habitable_id hhmid year wave -length
	by habitable_id hhmid year wave: gen todrop1 = _n
	drop if todrop1>1 & todrop1<. // To drop shorter moves per year within each wave
	
gsort habitable_id hhmid year -length
	by habitable_id hhmid year: gen todrop2 = _n
	drop if todrop2>1 & todrop2<. // To drop shorter moves between waves
	
by habitable_id hhmid year: gen test = _n
	tab test
	drop todrop* test length

tempfile kepy
save	`kepy'

use `w1w2', clear	
merge 1:1 habitable_id hhmid year using `kepy', nogen keep(match master) // To exclude HHMs in attrition households - 398 HHMs

distinct py
distinct habitable_id

order wave, after(year)
	replace wave = 1 if year<=2021
	replace wave = 2 if year>=2022 & year<=2023
	order sex - reason_specify, last
	order new_members_yn, before(sex)	
	order improv, before(tenure)
	order hhrem hhrempay, after(sactpay2)
	sort habitable_id hhmid year
	
encode roster_source, generate(new)
	recode new (2=0)
	label var new "New household in Wave 2"
	label define newhh 0 "Old" 1 "New", replace 
	label values new newhh

* Locality checks

bys adm4 year: egen clean = mean(adm3)
	replace adm3 = 13 if adm4==25 & adm3==12 & adm2==1713 & adm1==17
	bys adm4 year: egen clean2 = mean(adm3)
	drop clean*

preserve
	sort habitable_id hhmid year
	collapse adm4 new, by(habitable_id year) // 50 households are new	
	by habitable_id: gen test = (adm4[1]!=adm4[_N]) // 13 entire households moved between waves
restore
	
* Individual characteristics

// To fill in missing info on initial location
sort habitable_id hhmid year
foreach v of var country adm1-adm4 	{
	by habitable_id hhmid: replace `v' = `v'[_n-1] if wave==2 & waveid==3
}
foreach v of var country adm1-adm4 	{
	by habitable_id: replace `v' = `v'[1] if year<=2021 & waveid==2
}

// To correct time-varying characteristics
sort habitable_id hhmid year 

	// For individuals in both waves
	by habitable_id hhmid: replace age = age[_n-1]+1 if year==2023 & waveid==3
	forvalues i=2021(-1)2012	{
		by habitable_id hhmid: replace age = age[_n+1]-1 if year==`i' & waveid==3
	}

	// For individuals only in wave 2
	by habitable_id hhmid: replace age = age[_n+1]-1 if year==2022 & waveid==2
	
// To correct time-invariant characteristics
sort habitable_id hhmid year 
foreach var in wave timesta timeend adm1 adm2 adm3 adm4 gps_latitude gps_longitude gps_altitude gps_accuracy hhsize nadult children sex marry relhh grade liveh mig {
	by habitable_id hhmid: replace `var' = `var'[_N] if year==2022 & !missing(`var'[_N])
}
	
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
	tab nmoves // Max number of moves = 4	
	forvalues j=1/4	{
	by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & (liveh==1|liveh==2) & nmoves==`j' & waveid==3 // Even if dury==0, moves that last less than a year are also counted
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & (liveh==1|liveh==2) & nmoves==`j' & waveid==3
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==3 // HHMs who left Kenya, but returned
		}
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==3
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2022 & liveh==3 & nmoves==`j' & waveid==3 // To identify HHMs outside the locality at the time of interview in wave 1
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2023 & liveh==3 & nmoves==`j' & waveid==3 // To identify HHMs outside the locality at the time of interview in wave 2	
		by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & liveh==3 & nmoves==`j' & waveid==3
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & liveh==3 & nmoves==`j' & waveid==3
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & liveh==3 & nmoves==`j' & waveid==3 
		}		
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & liveh==3 & nmoves==`j' & waveid==3
	}
	
	// HHMs only in Wave 2

	// ... who never migrated
	sort habitable_id hhmid year	
	replace inhh = 1 if inhh==. & liveh==1 & nmoves==0 & waveid==2
	replace inhh = 2 if inhh==. & liveh==2 & nmoves==0 & waveid==2
	replace inhh = 3 if inhh==. & liveh==3 & nmoves==0 & waveid==2

	// ... who moved at least once
	sort habitable_id hhmid year	
	forvalues j=1/4	{
	by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & (liveh==1|liveh==2) & nmoves==`j' & waveid==2
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & (liveh==1|liveh==2) & nmoves==`j' & waveid==2
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==2
		}
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==2
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2022 & liveh==3 & nmoves==`j' & waveid==2
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2023 & liveh==3 & nmoves==`j' & waveid==2
		by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & liveh==3 & nmoves==`j' & waveid==2
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & liveh==3 & nmoves==`j' & waveid==2
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & liveh==3 & nmoves==`j' & waveid==2 
		}		
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & liveh==3 & nmoves==`j' & waveid==2
	}

	// HHMs who passed away
	
	// ... in Wave 2
	replace inhh = 4 if liveh==4 // Assumed HHMs passed on the year of the interview
	
	
* Migration

gen moved = 0
	replace moved = 1 if !missing(coutr)
	label var moved "Migrated outside the locality this year"
	label define moved 0 "No" 1"Yes", replace
	label values moved moved
	
* To calculate total moves per year
bys year: egen total_mig = total(moved) if moved==1

* To calculate total labour moves per year
bys year: egen labour_mig = total(moved) if moved==1 & reason==1

* To calculate length of migration event in months
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
		label var pop_at_riskl41 "Population at risk of migration"

	// Calculate the outmigration rate
	bys adm4 year: gen outmig_ratel4 = (yearly_migl4 / pop_at_riskl4) * 100
		label var outmig_ratel4 "Percentage of long-term outmigration per year"
		
	// Calculate the change in outmigration taken as a share of the initial population at risk
	bys adm4 year: gen outmig_sharel4 = (yearly_migl4 / pop_at_riskl41) * 100
		label var outmig_sharel4 "Long-term outmigration as a share of initial population at risk"

* Income

egen hsinc_kes = rowtotal(actpay1 actpay2 sactpay1 sactpay2)
	label var hsinc_kes "Head and spouse annual income (KES)"
	
// Mid-date of wave 1: 20/05/2022

gen hsinc_usd = hsinc_kes*0.008584 if wave==1
	label var hsinc_usd "Head and spouse annual income (USD)"

gen hhpay_usd = hhpay*0.008584 if wave==1
	label var hhpay_usd "Household annual income (USD)"

// Mid-date of wave 2: 23/05/2023

replace hsinc_usd = hsinc_kes*0.007246 if wave==2

replace hhpay_usd = hhpay*0.007246 if wave==2

su hsinc_usd if wave==1, det
	centile hsinc_usd if wave==1, centile(99.5)
	*The 99.5 percentile is at 11493.98
	replace hsinc_usd = 11493.98 if hsinc_usd>11493.98 & hsinc_usd<. & wave==1 // 198 obs

su hhpay_usd if wave==1, det
	centile hhpay_usd if wave==1, centile(99.5)
	*The 99.5 percentile is at 12876
	replace hhpay_usd = 12876 if hhpay_usd>12876 & hhpay_usd<. & wave==1 // 66 obs

su hsinc_usd if wave==2, det
	centile hsinc_usd if wave==2, centile(99.5)
	*The 99.5 percentile is at 6231.56
	replace hsinc_usd = 6231.56 if hsinc_usd>6231.56 & hsinc_usd<. & wave==2 // 24 obs

su hhpay_usd if wave==2, det
	centile hhpay_usd if wave==2, centile(99.5)
	*The 99.5 percentile is at 6086.64
	replace hhpay_usd = 6086.64 if hhpay_usd>6086.64 & hhpay_usd<. & wave==2 // 13 obs
	
* Remittances	

gen remit = 0 if wave==2	
	replace remit = hhrempay*0.007246 if wave==2
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

forvalues i=1/15	{
	replace adp`i' = . if adp`i'==-7777 | adp`i'==-8888
}

egen adap = rowtotal(adp1 adp2 adp3 adp4 adp5 adp6 adp7 adp8 adp9 adp10 adp11 adp12 adp13 adp14 adp15)
	label var adap "Number of household adaptation measures"
	
egen insitu = rowtotal(adp1 adp2 adp3 adp4 adp5 adp6 adp7 adp8 adp9 adp10 adp11)
	label var insitu "Number of in situ adaptation measures"
 	
* Expected loss

su evtlh1 evtlh2 evtlh3 evtlh4, det

	gen loss_housing_1 = evtlh1*hhpay_usd/100
	replace loss_housing_1 = 0 if loss_housing_1 == .
	label var loss_housing_1 "Loss of housing from floods (USD)"
	gen loss_land_1 = evtla1*hhpay_usd/100
	replace loss_land_1 = 0 if loss_land_1 == .
	label var loss_land_1 "Loss of land from floods (USD)"
	gen loss_harvest_1 = evtlha1*hhpay_usd/100
	replace loss_harvest_1 = 0 if loss_harvest_1 == .
	label var loss_harvest_1 "Loss of harvest from floods (USD)"
	gen loss_livestock_1 = evtll1*hhpay_usd/100
	replace loss_livestock_1 = 0 if loss_livestock_1 == .
	label var loss_livestock_1 "Loss of livestock from floods (USD)"
	gen loss_fisheries_1 = evtlfi1*hhpay_usd/100
	replace loss_fisheries_1 = 0 if loss_fisheries_1 == .
	label var loss_fisheries_1 "Loss of fisheries from floods (USD)"
	gen loss_health_1 = evtlhh1*hhpay_usd/100
	replace loss_health_1 = 0 if loss_health_1 == .
	label var loss_health_1 "Loss of health from floods (USD)"
	
	gen loss_housing_2 = evtlh2*hhpay_usd/100
	replace loss_housing_2 = 0 if loss_housing_2 == .
	label var loss_housing_2 "Loss of housing from drought (USD)"
	gen loss_land_2 = evtla2*hhpay_usd/100
	replace loss_land_2 = 0 if loss_land_2 == .
	label var loss_land_2 "Loss of land from drought (USD)"
	gen loss_harvest_2 = evtlha2*hhpay_usd/100
	replace loss_harvest_2 = 0 if loss_harvest_2 == .
	label var loss_harvest_2 "Loss of harvest from drought (USD)"
	gen loss_livestock_2 = evtll2*hhpay_usd/100
	replace loss_livestock_2 = 0 if loss_livestock_2 == .
	label var loss_livestock_2 "Loss of livestock from drought (USD)"
	gen loss_fisheries_2 = evtlfi2*hhpay_usd/100
	replace loss_fisheries_2 = 0 if loss_fisheries_2 == .
	label var loss_fisheries_2 "Loss of fisheries from drought (USD)"
	gen loss_health_2 = evtlhh2*hhpay_usd/100
	replace loss_health_2 = 0 if loss_health_2 == .
	label var loss_health_2 "Loss of health from drought (USD)"

	gen loss_housing_3 = evtlh3*hhpay_usd/100
	replace loss_housing_3 = 0 if loss_housing_3 == .
	label var loss_housing_3 "Loss of housing from erratic rainfall (USD)"
	gen loss_land_3 = evtla3*hhpay_usd/100
	replace loss_land_3 = 0 if loss_land_3 == .
	label var loss_land_3 "Loss of land from erratic rainfall (USD)"
	gen loss_harvest_3 = evtlha3*hhpay_usd/100
	replace loss_harvest_3 = 0 if loss_harvest_3 == .
	label var loss_harvest_3 "Loss of harvest from erratic rainfall (USD)"
	gen loss_livestock_3 = evtll3*hhpay_usd/100
	replace loss_livestock_3 = 0 if loss_livestock_3 == .
	label var loss_livestock_3 "Loss of livestock from erratic rainfall (USD)"
	gen loss_fisheries_3 = evtlfi3*hhpay_usd/100
	replace loss_fisheries_3 = 0 if loss_fisheries_3 == .
	label var loss_fisheries_3 "Loss of fisheries from erratic rainfall (USD)"
	gen loss_health_3 = evtlhh3*hhpay_usd/100
	replace loss_health_3 = 0 if loss_health_3 == .
	label var loss_health_3 "Loss of health from erratic rainfall (USD)"

	gen loss_housing_4 = evtlh4*hhpay_usd/100
	replace loss_housing_4 = 0 if loss_housing_4 == .
	label var loss_housing_4 "Loss of housing from heatwave (USD)"
	gen loss_land_4 = evtla4*hhpay_usd/100
	replace loss_land_4 = 0 if loss_land_4 == .
	label var loss_land_4 "Loss of land from heatwave (USD)"
	gen loss_harvest_4 = evtlha4*hhpay_usd/100
	replace loss_harvest_4 = 0 if loss_harvest_4 == .
	label var loss_harvest_4 "Loss of harvest from heatwave (USD)"
	gen loss_livestock_4 = evtll4*hhpay_usd/100
	replace loss_livestock_4 = 0 if loss_livestock_4 == .
	label var loss_livestock_4 "Loss of livestock from heatwave (USD)"
	gen loss_fisheries_4 = evtlfi4*hhpay_usd/100
	replace loss_fisheries_4 = 0 if loss_fisheries_4 == .
	label var loss_fisheries_4 "Loss of fisheries from heatwave (USD)"
	gen loss_health_4 = evtlhh4*hhpay_usd/100
	replace loss_health_4 = 0 if loss_health_4 == .
	label var loss_health_4 "Loss of health from heatwave (USD)"
	
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

recode evtfrq1 evtfrq2 evtfrq3 evtfrq4 (2=1) (3=1) (4=1) (5=0) (6=0) (.= 0) (-77=0) (-79=0)
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
	label var noedu4 "Share of individuals with no education in the site on a given year"
	
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
	keep if country==3		
	sort habitable_id year
tempfile clim
save	`clim'
	
use `hhmy', clear
	merge m:1 habitable_id year using `clim', nogen keep(match) 
	*replace hhmid = 1 if hhmid==. & year>=2002 & year<=2011 // _m==2 To assign lagged climate variables (years 2002 to 2011) to head of household
	*drop if hhmid==.
	*replace hhmid = 1 if hhmid==. & year==2023 // _m==2 To assign attrition households (year 2023) to head of household
	drop py
	egen panelid = group(habitable_id hhmid)
	order panelid, after(hhmid)

	tab adm1, gen(reg)
	tab adm4, gen(loc)
	tab year, gen(year) // 22 years (2002-2023)

sort habitable_id hhmid year
	
save "$OUTPUT\HHMY_KE.dta", replace 

* Collapsing person-year dataset into locality-year dataset

use "$OUTPUT\HHMY_KE.dta", clear

keep if year>=2012 & year<=2023

preserve
	collapse (mean) country region adm1 adm2 adm3 outmig_share4 outmig_sharel4 outmig_rate4 outmig_ratel4 temp_div prcp_div female4 nomarry4 noedu4 age4 lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div mean_temp sd_temp SPEI12_year lag_SPEI12 lag2_SPEI12, by(adm4 year)
	rename (temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12) ///
	(temp_div4 prcp_div4 lag_temp_div4 lag_prcp_div4 lag2_temp_div4 lag2_prcp_div4 SPEI12_year4 lag_SPEI124 lag2_SPEI124)
	sort adm1 adm2 adm3 adm4 year
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
	order adm4, after(adm3)
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

save "$OUTPUT\ADM_KE.dta", replace

* Standardising variable names across countries

use "$OUTPUT\ADM_KE.dta", clear

rename (temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121) (temp_div_s1 prcp_div_s1 lag_temp_div_s1 lag_prcp_div_s1 lag2_temp_div_s1 lag2_prcp_div_s1 SPEI12_year_s1 lag_SPEI12_s1 lag2_SPEI12_s1)

rename (outmig_share4 outmig_sharel4 outmig_rate4 outmig_ratel4 temp_div4 prcp_div4 female4 nomarry4 noedu4 age4 lag_temp_div4 lag_prcp_div4 lag2_temp_div4 lag2_prcp_div4 SPEI12_year4 lag_SPEI124 lag2_SPEI124) (outmig_share_s2 outmig_sharel_s2 outmig_rate_s2 outmig_ratel_s2 temp_div_s2 prcp_div_s2 female_s2 nomarry_s2 noedu_s2 age_s2 lag_temp_div_s2 lag_prcp_div_s2 lag2_temp_div_s2 lag2_prcp_div_s2 SPEI12_year_s2 lag_SPEI12_s2 lag2_SPEI12_s2)

save "$OUTPUT\ADM_KE.dta", replace
