/*______________________________________________________________________________________
|                                                     									|
|							Social Tipping Points - Mali								|	
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

// Rename lower case
program low
	foreach v of varlist _all {
     capture rename `v', lower
     if c(rc) != 0 {
         local newname: permname `=lower("`v'")'
         label var `v' `"RENAME of `v' (`:var label `v'')
        rename `v' `newname'
		}
	}
end

// Create unique identifier
program habitableid 
	egen habitable_id = concat(adm1 adm2 adm3 adm4 hhid)
	destring habitable_id, replace
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 2000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
end

* Household level

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION I + II  (Recruitment + Contact).dta", clear
	low
	habitableid

drop address resname restel kinname kintel
	
rename consentement consent
rename lat gps_latitude
rename lon gps_longitude
rename alt gps_altitude
rename acc gps_accuracy
rename kinrel_aut kinrel_other
rename nomcm namehhhead
rename restreinte resrel
rename restreinte_aut resrel_other

recode adm1 (3=2)
	label define adm1 1 "Kayes" 2 "Sikasso", replace
	label values adm1 adm1

// Generate country variable to help later when data sets are combined
gen country = 2
	label var country "Country"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia" 5 "Thailand"
	label val country country
	order country, before (adm1)

// Generate wave variable
gen wave = 1
	label var wave "Data collected in wave 1 (2022) or wave 2 (2023)"
	order wave, before (country)

// Generate number of children
replace adults = hhsize if adults>hhsize & adults<. // Some households have more adult members than total hhsize - 2 obs
	gen children = hhsize - adults
	label var children "Number of children in the household"
	order children, after (adults)
	rename adults nadult
	label var hhsize "Household size"
	label var nadult "Number of adults in the household"
	
// Harmonise ethnicity with other countries
recode reseth (1=201) (2=202) (3=203) (4=204) (5=205) (6=206) (7=207) (8=208) (9=209) (10=210) (11=211) (12=212) (13=213) (14=214) (15=215) (16=216) (17=217) (18=218) (19=219)
	label var reseth "Ethnicitiy of respondent"
	label define ethnicity 101 "Akan" 102 "Ga-Dangme" 103 "Ewe" 104 "Guan" 105 "Gruma" 106 "Mole-Dagbani" 107 "Grussi" 108 "Mande" 109 "Basali" 110 "Fulani" 111 "Kotokoli" 112 "Kabire" 113 "Konkomba" 114 "Togo Karra" 115 "Other Ghana" 201 "Bambara" 202 "Malinké" 203 "Peul/Foulfoulbé" 204 "Sonrai/Djerma" 205 "Sarakolé/Soninké" 206 "Kassonké" 207 "Sénoufo" 208 "Dogon" 209 "Maure" 210 "Tamacheq" 211 "Bobo" 212 "Dafing" 213 "Minianka" 214 "Haoussa" 215 "Samogo" 216 "Bozo" 217 "Arabe" 218 "Mossi" 219 "Other Mali"
	label values reseth ethnicity

// Harmonise religion with other countries
recode resrel (7=8) (8=9)
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
	
// Harmonise timestamp with wave 2
gen _timesta = substr(timesta,1,2) + "/" + 	substr(timesta,3,2) + "/" + substr(timesta,5,4)
	gen timesta_ = date(_timesta,"DMY",2024)
	format timesta_ %td
	drop timesta _timesta
	rename timesta_ timesta

gen _timeend = substr(timeend,1,2) + "/" + 	substr(timeend,3,2) + "/" + substr(timeend,5,4)
	gen timeend_ = date(_timeend,"DMY",2024)
	format timeend_ %td
	drop timeend _timeend
	rename timeend_ timeend
	
tempfile intro
save	`intro'

* Household roster

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION III (Household roster).dta", clear
	low
	habitableid

drop adm1-hhid nom cenumid-resultat_collect
	rename id hhmid

// Translate labels from French to English
label var sex "Sex at birth"
	label define sex 0 "Female" 1 "Male"
	label values sex sex
label var age "Age (in completed years)"
label var marry "Marital status"
	label define marry 1 "Never married" 2 "Married" 3 "Divorced" 4 "Separated" 5 "Widow/widower"
	label values marry marry
label var relhh "Relationship to household head"
	label define relhh 0 "Head" 1 "Spouse" 2 "Partner" 3 "Parent" 4 "Child" 5 "Sibling" 6 "Other"
	label values relhh relhh
label var grade "Highest grade that person has completed (excluding pre-primary)"
	label define grade 0 "None" 1 "Grade 1" 2 "Grade 2" 3 "Grade 3" 4 "Grade 4" 5 "Grade 5" 6 "Grade 6" 7 "Grade 7" 8 "Grade 8" 9 "Grade 9" 10 "Grade 10" 11 "Grade 11" 12 "Grade 12" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)" 30 "Adult literacy" 31 "Religious education" 32 "Other" 77 "Not know"
	recode grade (1 2 3 4 5 = 0) (6 7 8 30 31 = 17) (9 10 11 = 18) (12=19) (32 77=.)
	replace grade = 17 if grade_aut=="cours du soir"
	drop grade_aut
	label define grade 0 "None" 17 "Primary" 18 "Lower secondary" 19 "Upper secondary" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)", replace
	label values grade grade
label var liveh "Does person currently live with this household?"
	label define liveh 1 "Yes" 2 "No, living somewhere else in the same locality" 3 "No, living somewhere else outside the locality" 4 "No, passed away"
	label values liveh liveh
label var mig "Since 2012, has X lived outside the commune for at least 3 months?"
	label define mig 0 "No" 1 "Yes"
	label values mig mig

sort habitable_id hhmid	
	
expand 10	
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

* Migration history

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION IV.dta", clear
	low
	habitableid

drop adm1-hhid
	rename id hhmid
	rename migyear year
	rename region level1
	rename cercle level2
	rename comne level3
	rename raison reason
	rename raisonprecisez reason_specify

label var level1 "Level 1"
label var level2 "Level 2"
label var level3 "Level 3"
		
label define reason 1 "Work- or income-related reasons" 2 "Educational reasons" 3 "Family-related reasons" 4 "Environment-related reasons" 5 "Conflict" 6 "Other, specify", replace	
label values reason reason

sort habitable_id hhmid year

tempfile mighis
save	`mighis'

* Dwelling characteristics

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION V.dta", clear
	low
	habitableid

drop adm1-hhid
	rename pieces rooms
	rename toit roof
	rename toit_aut roof_specify
	rename mur wall
	rename mur_aut wall_specify
	rename plancher floor
	rename cfuel_aut cfuel_specify
	rename eau water
	rename eau_aut water_specify
	rename toilette toilet
	rename toilette_aut toilet_specify
	
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

* Livelihoods 1

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION VI1.dta", clear
	low
	habitableid

drop adm1-hhid

tempfile liv1
save	`liv1'

* Livelihoods 2

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION VI2.dta", clear
	low
	habitableid

drop adm1-hhid
sort habitable_id actid
rename (act_aut actsec_aut acttp_aut ajout_act) (act_specify actsec_specify acttp_specify add_activity) 
drop if actid==. // 16 obs

reshape wide act act_specify actsec actsec_specify acttp acttp_specify actpay add_activity, i(habitable_id) j(actid)
	label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"
	label var add_activity1 "Is there a second income activity?"
	drop add_activity2 // No obs
	
tempfile liv2
save	`liv2'

use "$INPUT\Mali\Spouse questionnaire\SECTION III2F.dta", clear
	low
	habitableid

drop adm1-hhid
sort habitable_id actid
rename *_f *
rename *f_aut *_specify
rename ajoutf_act add_activity
drop if actid==. // 16 obs
reshape wide act act_specify actsec actsec_specify acttp acttp_specify actpay add_activity, i(habitable_id num_id) j(actid)
	label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"
	label var add_activity1 "Is there a second income activity?"

by habitable_id: gen test = _n
	sort habitable_id test
	drop if habitable_id==2001111118526 & num_id==2 // Keeping the first wife interviewed - no GPS or address
	drop if habitable_id==2001111124626 & num_id==3 // Keeping the first wife interviewed - no GPS or address
	drop test 

ds habitable_id num_id, not
rename (`r(varlist)') (s=)
sort habitable_id
	
tempfile sact
save	`sact'

* Perceptions of climate risks

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION VII.dta", clear
	low
	habitableid
	drop adm1-hhid
	
rename (evtha evtfi) (evtlha evtlfi)
	
reshape wide evtfrq-evtoth, i(habitable_id) j(evt)
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

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION VIII.dta", clear
	low
	habitableid
	drop adm1-hhid

rename adpid_aut adpid_specify
	drop adpid_specify // Additional adaptation measures reported in this variable
	
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

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION IX.dta", clear
	low
	habitableid
	drop adm1-hhid

tempfile adapc
save	`adapc'

* Personality traits

use "$INPUT\Mali\Household questionnaire\Renames Mali data\SECTION X.dta", clear
	low
	habitableid
	drop adm1-hhid

tempfile ptraits
save	`ptraits'

* Merge all sections

use `intro', clear
	merge 1:1 habitable_id using `dwe', nogen keep(match) // To drop 9 obs only in master that did not give consent
	merge 1:1 habitable_id using `liv1', nogen
	merge 1:1 habitable_id using `liv2', nogen
	merge 1:1 habitable_id using `sact', nogen keepusing(sactpay1 sactpay2)
	merge 1:1 habitable_id using `risks', nogen
	merge 1:1 habitable_id using `hhadap', nogen
	merge 1:1 habitable_id using `adapc', nogen
	merge 1:1 habitable_id using `ptraits', nogen
	
tempfile ma1
save	`ma1'

use `hhm', clear
	merge 1:1 habitable_id hhmid year using `mighis', nogen keep(match master) // To drop 4 obs with empty migration history
tempfile long
save	`long'
	
use `ma1', clear
	merge 1:m habitable_id using `long', nogen
	sort habitable_id hhmid year	
tempfile mapy1
save	`mapy1'

collapse wave liveh, by(habitable_id hhmid)
tempfile id1
save	`id1'

collapse wave, by(habitable_id)
tempfile test1
save	`test1'

*********************************************************** W2 *************************************************************
	
use "$INPUT\Mali\Wave 2\basesbrutesdehabitable\basesbrutesdehabitable\Household_level_dataset.dta", clear
	low	
	ds hhsize_p1 adults_p1 hhmig_p1, not
	rename (`r(varlist)') (x=)
	rename x*_p2 *
	rename x*_p2_# *#
	rename x*_p2_aut_# *_specify#
	rename x*_p2_aut *_specify
	rename x* *
	ds hhsize_p1 adults_p1 hhmig_p1
	rename (`r(varlist)') (x=)
	rename x*_p1 *_w1
	rename *0? *?
	habitableid

recode adm1 (3=2)
	label define adm1 1 "Kayes" 2 "Sikasso", replace
	label values adm1 adm1

// To remove location from wave 2 in order to keep location from wave 1 only
*drop adm1 - adm4 lat - acc
		
// Generate country variable to help later when datasets are combined
gen country = 2
	label var country "Country"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia" 5 "Thailand"
	label val country country
	order country, after (habitable_id)

// Generate wave variable
gen wave = 2
	label var wave "Data collected in wave 1 (2022) or wave 2 (2023)"
	order wave, before (country)
		
drop consentement address resname restel
	/*rename lat gps_latitude
	rename lon gps_longitude
	rename alt gps_altitude
	rename acc gps_accuracy*/
	rename restreinte resrel
	rename restreinte_specify resrel_other

// Harmonise ethnicity with other countries
recode reseth (1=201) (2=202) (3=203) (4=204) (5=205) (6=206) (7=207) (8=208) (9=209) (10=210) (11=211) (12=212) (13=213) (14=214) (15=215) (16=216) (17=217) (18=218) (19=219)
	label var reseth "Ethnicitiy of respondent"
	label define ethnicity 101 "Akan" 102 "Ga-Dangme" 103 "Ewe" 104 "Guan" 105 "Gruma" 106 "Mole-Dagbani" 107 "Grussi" 108 "Mande" 109 "Basali" 110 "Fulani" 111 "Kotokoli" 112 "Kabire" 113 "Konkomba" 114 "Togo Karra" 115 "Other Ghana" 201 "Bambara" 202 "Malinké" 203 "Peul/Foulfoulbé" 204 "Sonrai/Djerma" 205 "Sarakolé/Soninké" 206 "Kassonké" 207 "Sénoufo" 208 "Dogon" 209 "Maure" 210 "Tamacheq" 211 "Bobo" 212 "Dafing" 213 "Minianka" 214 "Haoussa" 215 "Samogo" 216 "Bozo" 217 "Arabe" 218 "Mossi" 219 "Other Mali"
	label values reseth ethnicity

// Harmonise religion with other countries
recode resrel (7=8) (8=9)
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
	
// Harmonise dwelling characteristics labels
rename pieces rooms
	rename toit roof
	rename toit_specify roof_specify
	rename mur wall
	rename mur_specify wall_specify
	rename plancher floor
	rename eau water
	rename eau_specify water_specify
	rename toilette toilet
	rename toilette_specify toilet_specify
	
rename tec _tec
	gen tec = .
	forvalues i=1/7	{
		replace tec = `i' if regexm(_tec, "`i'")==1
	}
	tab tec, gen(tec)
	label var tec1 "Radio"
	label var tec2 "TV"
	label var tec3 "Computer/laptop"
	label var tec4 "Tablet"
	label var tec5 "Landline"
	label var tec6 "Mobile phone without internet"
	label var tec7 "Mobile phone with internet"
	drop _tec tec
	order tec1 tec2 tec3 tec4 tec5 tec6 tec7, after(toilet_specify)

merge 1:1 habitable_id using `hh1', nogen keep(master match)

	foreach v of varlist rooms roof wall floor elect cfuel water toilet tec1 tec2 tec3 tec4 tec5 tec6 tec7	{
		replace `v' = `v'_w1 if `v'==.
	}
	drop rooms_w1 roof_w1 wall_w1 floor_w1 elect_w1 cfuel_w1 water_w1 toilet_w1 tec1_w1 tec2_w1 tec3_w1 tec4_w1 tec5_w1 tec6_w1 tec7_w1
	
// Harmonise livelihoods labels
rename ajout_act1 add_activity1	
	label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"
	label var add_activity1 "Is there a second income activity?"

// Harmonise climate risks labels	
rename (evtha? evtfi?) (evtlha? evtlfi?)
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
	*label var evtoth4 "Was there any non-environmental event that also caused losses around the same time?" // Variable missing

	label define yesno 0 "No" 1 "Yes", replace
	label values evtlhd1 evtlhd2 evtlhd3 evtlhd4 evtoth1 evtoth2 evtoth3 yesno

// Harmonise household adaptation labels
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

// Hamornise timestamp with wave 1
gen _timesta = dofc(timesta)
	format _timesta %td
	drop timesta
	rename _timesta timesta
	
gen _timeend = dofc(timeend)
	format _timeend %td
	drop timeend
	rename _timeend timeend
	
sort habitable_id
	
tempfile ma2
save	`ma2'

import spss using "$INPUT\Mali\Wave 2\Spouse_dataset.sav", clear
	low
	rename *_f_p2 *
	rename *_p2 *
	rename *_f_p2_* *_*
	habitableid
	keep habitable_id num_id actid_1-actpay_2
	rename *_? *?
	rename *_p2? *?
	rename *f_aut? *_specify?

sort habitable_id actid1 actid2
drop if actid1==. & actid2==. // 5 obs
	label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"

ds habitable_id num_id, not
rename (`r(varlist)') (s=)
sort habitable_id
	
tempfile sact2
save	`sact2'

use "$INPUT\Mali\Wave 2\basesbrutesdehabitable\basesbrutesdehabitable\Individual_level_dataset.dta", clear
	low	
	ds 
	rename (`r(varlist)') (x=)
	rename x*_p2 *
	rename x*_p2_aut *_specify
	rename x* *
	habitableid
	rename id hhmid
	drop nom
	keep habitable_id-autremen

recode adm1 (3=2)
	label define adm1 1 "Kayes" 2 "Sikasso", replace
	label values adm1 adm1
	
// Translate labels from French to English
label var sex "Sex at birth"
	label define sex 0 "Female" 1 "Male"
	label values sex sex
label var age "Age (in completed years)"
label var marry "Marital status"
	label define marry 1 "Never married" 2 "Married" 3 "Divorced" 4 "Separated" 5 "Widow/widower"
	label values marry marry
label var relhh "Relationship to household head"
	label define relhh 0 "Head" 1 "Spouse" 2 "Partner" 3 "Parent" 4 "Child" 5 "Sibling" 6 "Other"
	label values relhh relhh
label var grade "Highest grade that person has completed (excluding pre-primary)"
	label define grade 0 "None" 1 "Grade 1" 2 "Grade 2" 3 "Grade 3" 4 "Grade 4" 5 "Grade 5" 6 "Grade 6" 7 "Grade 7" 8 "Grade 8" 9 "Grade 9" 10 "Grade 10" 11 "Grade 11" 12 "Grade 12" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)" 30 "Adult literacy" 31 "Religious education" 32 "Other" 77 "Not know"
	recode grade (1 2 3 4 5 = 0) (6 7 8 30 31 = 17) (9 10 11 = 18) (12=19) (32 77=.)
	replace grade = 17 if grade_specify=="cours du soir"
	drop grade_specify
	label define grade 0 "None" 17 "Primary" 18 "Lower secondary" 19 "Upper secondary" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)", replace
	label values grade grade
label var liveh "Does person currently live with this household?"
	label define liveh 1 "Yes" 2 "No, living somewhere else in the same locality" 3 "No, living somewhere else outside the locality" 4 "No, passed away"
	label values liveh liveh
label var mig "Since 2022, has X lived outside the commune for at least 3 months?"
	label define mig 0 "No" 1 "Yes"
	label values mig mig

recode autremen (2=0)
	label define autremen 0 "No" 1 "Yes", replace
	label values autremen autremen

label define pass 1 "Passed away" 2 "Always present" 3 "Newly arrived" 4 "Forgotten on wave 1", replace
	label values pass_an pass
	
*bys habitable_id hhmid: gen test = _n // Each household member moved only once	(either 2022 or 2023)
expand 2	
	sort habitable_id hhmid	
	by habitable_id hhmid: gen year = _n
	order year, after(hhmid)
	replace year = 2022 if year==1
	replace year = 2023 if year==2
	sort habitable_id hhmid year
	
tempfile hhm2
save	`hhm2'

use "$INPUT\Mali\Wave 2\basesbrutesdehabitable\basesbrutesdehabitable\Individual_level_dataset.dta", clear
	low	
	ds 
	rename (`r(varlist)') (x=)
	rename x*_p2 *
	rename x*_p2_aut *_specify
	rename x* *
	habitableid
	rename id hhmid
	drop nom
	rename migyear year
	keep habitable_id hhmid year-raisonprecisez
	keep if year<.

// Harmonise migration history labels
rename region level1
	rename cercle level2
	rename comne level3
	rename raison reason
	rename raisonprecisez reason_specify

label var level1 "Level 1"
label var level2 "Level 2"
label var level3 "Level 3"
	
label define reason 1 "Work- or income-related reasons" 2 "Educational reasons" 3 "Family-related reasons" 4 "Environment-related reasons" 5 "Conflict" 6 "Other, specify", replace	
label values reason reason

sort habitable_id hhmid year

tempfile mighis2
save	`mighis2'

use `hhm2', clear
	merge 1:1 habitable_id hhmid year using `mighis2', nogen
	sort habitable_id hhmid year

tempfile long2
save	`long2'

use `ma2', clear
	merge 1:1 habitable_id using `sact2', nogen keepusing(sactpay1 sactpay2)
	merge 1:m habitable_id using `long2', nogen
	sort habitable_id hhmid year

tempfile mapy2
save	`mapy2'

collapse wave liveh, by(habitable_id hhmid)
tempfile id2
save	`id2'

collapse wave, by(habitable_id)
tempfile test2
save	`test2'
	
*********************************************************** W1 & W2 *************************************************************

use `test1', clear
	merge 1:1 habitable_id using `test2' // 0.4% household attrition
	keep if _merge==1
	rename _merge attr
	drop wave
	tempfile attrition
	save	`attrition'
	
use `id1', clear
	merge 1:1 habitable_id hhmid using `id2'
		rename _merge waveid
		label define waveid 1 "Only in Wave 1" 2 "Only in Wave 2" 3 "In both waves", replace
		label values waveid waveid
		label var waveid "Wave for each individual"
		drop wave
	merge m:1 habitable_id using `attrition', nogen
		drop if attr==1 // To keep only households present in both waves
sort habitable_id hhmid	
	egen py = group(habitable_id hhmid)
	order py, after(hhmid)
	*drop if liveh==4 // To drop 12 hhm who passed away
	replace waveid = 1 if liveh==4	
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
	
merge 1:1 habitable_id hhmid year using `mapy1', nogen keep(match master)
merge 1:1 habitable_id hhmid year using `mapy2', nogen nolabel update

distinct py
distinct habitable_id

order wave, after(year)
	replace wave = 1 if wave==. & (year>=2012 & year<=2021)
	replace wave = 2 if wave==. & (year>=2022 & year<=2023)
	order sex - reason_specify, last
	order q25_1 q25_2, before(sex)	
	order improv, before(tenure)
	order hhrem hhrempay, after(sactpay2)
	sort habitable_id hhmid year

* Locality checks

preserve
sort habitable_id hhmid year
collapse adm3, by(habitable_id year)	
	by habitable_id: gen test = (adm3[1]!=adm3[_N]) // No entire households moved between waves
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
	tab nmoves // Max number of moves = 1
	by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & (liveh==1|liveh==2) & nmoves==1 & waveid==3 // Even if dury==0, moves that last less than a year are also counted
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & (liveh==1|liveh==2) & nmoves==1 & waveid==3
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & (liveh==1|liveh==2) & nmoves==1 & waveid==3 // HHMs who left Mali, but returned
		}
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & (liveh==1|liveh==2) & nmoves==1 & waveid==3
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2022 & liveh==3 & nmoves==1 & waveid==3 // To identify HHMs outside the locality at the time of interview in wave 1
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2023 & liveh==3 & nmoves==1 & waveid==3 // To identify HHMs outside the locality at the time of interview in wave 2
		by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & liveh==3 & nmoves==1 & waveid==3
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & liveh==3 & nmoves==1 & waveid==3
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & liveh==3 & nmoves==1 & waveid==3 
		}		
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & liveh==3 & nmoves==1 & waveid==3

	// HHMs only in Wave 1
	replace inhh = 1 if inhh==. & liveh==1 & year==2021 & waveid==1
	replace inhh = 2 if inhh==. & liveh==2 & year==2021 & waveid==1
	replace inhh = 3 if inhh==. & liveh==3 & year==2021 & waveid==1
	
	// ... who never migrated
	replace inhh = 1 if inhh==. & liveh==1 & nmoves==0 & waveid==1
	replace inhh = 2 if inhh==. & liveh==2 & nmoves==0 & waveid==1
	replace inhh = 3 if inhh==. & liveh==3 & nmoves==0 & waveid==1
	
	// ... who moved at least once
	by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & (liveh==1|liveh==2) & nmoves==1 & waveid==1
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & (liveh==1|liveh==2) & nmoves==1 & waveid==1
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & (liveh==1|liveh==2) & nmoves==1 & waveid==1
		}
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & (liveh==1|liveh==2) & nmoves==1 & waveid==1
	by habitable_id hhmid: replace inhh = 3 if inhh==. & year==2022 & liveh==3 & nmoves==1 & waveid==1
		by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & liveh==3 & nmoves==1 & waveid==1
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & liveh==3 & nmoves==1 & waveid==1
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & liveh==3 & nmoves==1 & waveid==1 
		}		
		by habitable_id hhmid: replace inhh = 1 if inhh==. & missing(coutr) & missing(dury) & liveh==3 & nmoves==1 & waveid==1

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

// To calculate outmigration rates at Administrative Level 3 of the original sampling sites

sort habitable_id hhmid year
	
	// Create a variable for migrants for each year
	bys adm3 year: egen yearly_mig3 = total(moved)
		label var yearly_mig3 "Annual number of migrants"

	// Calculate the population at risk per year
	gen inloc3 = (inhh==1 | inhh==2)
		label var inloc3 "In the locality this year"
	bys adm3 year: egen totinloc3 = total(inloc3)
		egen pop_at_risk3 = rowtotal(totinloc3 yearly_mig3)
		label var pop_at_risk3 "Population at risk of migration"
	sort adm3 habitable_id hhmid year 
	by adm3: gen pop_at_risk31 = pop_at_risk3[1]
		label var pop_at_risk31 "Initial population at risk of migration"

	// Calculate the outmigration rate
	bys adm3 year: gen outmig_rate3 = (yearly_mig3 / pop_at_risk3) * 100
		label var outmig_rate3 "Percentage of outmigration per year"

	// Calculate the change in outmigration taken as a share of the initial population at risk
	bys adm3 year: gen outmig_share3 = (yearly_mig3 / pop_at_risk31) * 100
		label var outmig_share3 "Outmigration as a share of initial population at risk"

// To calculate outmigration rates only for long-term migration at administration level 3

sort habitable_id hhmid year
	
	// Create a variable for migrants for each year
	gen lmoved = (moved==1 & length>=12 & !missing(length))
	bys adm3 year: egen yearly_migl3 = total(lmoved)
		label var yearly_migl3 "Annual number of long-term migrants"

	// Calculate the population at risk per year
	gen inlocl3 = (inhh==1 | inhh==2 | (moved==1 & length<12))
		label var inlocl3 "In the locality this year"
	bys adm3 year: egen totinlocl3 = total(inlocl3)
		egen pop_at_riskl3 = rowtotal(totinlocl3 yearly_migl3)	
		label var pop_at_riskl3 "Population at risk of migration"
	sort adm3 habitable_id hhmid year 
	by adm3: gen pop_at_riskl31 = pop_at_riskl3[1]
		label var pop_at_riskl31 "Initial population at risk of migration"

	// Calculate the outmigration rate
	bys adm3 year: gen outmig_ratel3 = (yearly_migl3 / pop_at_riskl3) * 100
		label var outmig_ratel3 "Percentage of long-term outmigration per year"
		
	// Calculate the change in outmigration taken as a share of the initial population at risk
	bys adm3 year: gen outmig_sharel3 = (yearly_migl3 / pop_at_riskl31) * 100
		label var outmig_sharel3 "Long-term outmigration as a share of initial population at risk"
	
* Income

egen hsinc_xof = rowtotal(actpay1 actpay2 sactpay1 sactpay2)
	label var hsinc_xof "Head and spouse annual income (XOF)"
	
// Mid-date of wave 1: 22/05/2022

gen hsinc_usd = hsinc_xof*0.0016 if wave==1
	label var hsinc_usd "Head and spouse annual income (USD)"

gen hhpay_usd = hhpay*0.0016 if wave==1
	label var hhpay_usd "Household annual income (USD)"

// Mid-date of wave 2: 15/06/2023

replace hsinc_usd = hsinc_xof*0.001669 if wave==2

replace hhpay_usd = hhpay*0.001669 if wave==2

su hsinc_usd if wave==1, det
	centile hsinc_usd if wave==1, centile(99.5)
	*The 99.5 percentile is at 800048
	replace hsinc_usd = 800048 if hsinc_usd>800048 & hsinc_usd<. & wave==1 // 63 obs

su hhpay_usd if wave==1, det
	centile hhpay_usd if wave==1, centile(99.5)
	*The 99.5 percentile is at 6000
	replace hhpay_usd = 6000 if hhpay_usd>6000 & hhpay_usd<. & wave==1 // 49 obs

su hsinc_usd if wave==2, det
	centile hsinc_usd if wave==2, centile(99.5)
	*The 99.5 percentile is at 11766.45
	replace hsinc_usd = 11766.45 if hsinc_usd>11766.45 & hsinc_usd<. & wave==2 // 63 obs

su hhpay_usd if wave==2, det
	centile hhpay_usd if wave==2, centile(99.5)
	*The 99.5 percentile is at 11683
	replace hhpay_usd = 11683 if hhpay_usd>11683 & hhpay_usd<. & wave==2 // 49 obs

ttest hsinc_usd=hhpay_usd if wave==1 // Statistically different
ttest hsinc_usd=hhpay_usd if wave==2 // Statistically different
	
* Remittances	

gen remit = 0 if wave==2	
	replace remit = hhrempay*0.001669 if wave==2
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

gen denom = (moved==1 | inloc3==1)
	
gen female = 1 if sex==0 | sex==2 
	replace female = 0 if sex==1
	label var female "Female"
	gen _female = female if denom==1
	bys adm3 year: egen female3 = mean(_female)
	label var female3 "Share of females in the site on a given year"

gen married = 1 if marry==2
	replace married = 0 if marry!=2 & !missing(marry)
	label var married "Married"

gen nomarry = 1 if marry==1
	replace nomarry = 0 if marry!=1 & !missing(marry)
	label var nomarry "Never married"
	gen _nomarry = nomarry if denom==1
	bys adm3 year: egen nomarry3 = mean(_nomarry)
	label var nomarry3 "Share of adults who never married in the site on a given year"
	
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
	bys adm3 year: egen noedu3 = mean(_noedu)
	label var noedu3 "Share of individuals with no education in the site on a given year"
	
gen relhead = (relhh==0) if !missing(relhh)
	label define relhead 0 "Other" 1 "Head", replace
	label values relhead relhead
	label var relhead "Head of the household"

gen relmaj = (resrel==3)
	label var relmaj "Member of religious majority"
	
foreach v of varlist age wi hhpay_usd relmaj	{
	gen _`v' = `v' if denom==1
	bys adm3 year: egen `v'3 = mean(_`v')
}
label var age3 "Average age in the site on a given year"
label var wi3 "Average wealth index in the site on a given year"
label var relmaj3 "Share of majority religion"

drop _*

sort habitable_id year
	
tempfile hhmy
save	`hhmy'
	
* To merge climate data

use "$OUTPUT\All_climate_annual.dta", clear
	keep if country==2 	
	tempfile clim
	save	`clim'
	
use `hhmy', clear
	merge m:1 habitable_id year using `clim', nogen keep(match) // _m==2 for lagged climate (years 2002 to 2011)
	*replace hhmid = 1 if hhmid==. & year>=2002 & year<=2011 // To assign lagged climate variables to head of household
	*replace hhmid = 1 if hhmid==. & year>=2022 & year<=2023 & waveid==1 // To keep climate variables for households in wave 1, but not in wave 2
	*drop if hhmid==. // To drop attrition	
	drop py
	egen panelid = group(habitable_id hhmid)
	order panelid, after(hhmid)

	tab adm1, gen(reg)
	tab adm3, gen(loc)
	tab year, gen(year) // 22 years (2002-2023)

sort habitable_id hhmid year
	
save "$OUTPUT\HHMY_MA.dta", replace 
	
* Collapsing person-year dataset into locality-year dataset

use "$OUTPUT\HHMY_MA.dta", clear

keep if year>=2012 & year<=2023

preserve
	collapse (mean) country region adm1 adm2 outmig_share3 outmig_sharel3 outmig_rate3 outmig_ratel3 temp_div prcp_div female3 nomarry3 noedu3 age3 lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div mean_temp sd_temp SPEI12_year lag_SPEI12 lag2_SPEI12, by(adm3 year)
	rename (temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12) ///
	(temp_div3 prcp_div3 lag_temp_div3 lag_prcp_div3 lag2_temp_div3 lag2_prcp_div3 SPEI12_year3 lag_SPEI123 lag2_SPEI123)
	sort adm1 adm2 adm3 year
	tempfile v3
	save	`v3'
restore

preserve
collapse (mean) temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12, by(adm1 year)
	rename (temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12) ///
	(temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121)
	sort adm1 year
	tempfile v1
	save	`v1'
restore
	
use `v3', clear
	merge m:1 adm1 year using `v1', keepusing(temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121) nogen
	order adm3, after(adm2)
	label var outmig_share3 "Outmigration share at the site level"
	label var temp_div3 "Temperature anomalies at the site level"
	label var prcp_div3 "Rainfall anomalies at the site level"
	label var mean_temp "Long-run temperature mean (2002-2011)"
	label var sd_temp "Long-run temperature SD (2002-2011)"	
	label var female3 "Share of females at the site level"
	label var nomarry3 "Share of non-married adults at the site level"	
	label var age3 "Average age at the site level"
	label var noedu3 "Share of adults with no education at the site level"
	label var temp_div1 "Temperature anomalies at the region level"
	label var prcp_div1 "Rainfall anomalies at the region level"
	label var lag_temp_div3 "One-lag temperature anomalies at the site level"
	label var lag2_temp_div3 "Two-lag temperature anomalies at the site level"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia", replace
	label val country country
	label define region 1 "Volta" 2 "Northern" 3 "Kayes" 4 "Sikasso" 5 "Makueni" 6 "Baringo" 7 "Oromia" 8 "SNNP", replace
	label val region region

tab adm1, gen(reg)
tab adm3, gen(loc)
tab year, gen(year)

save "$OUTPUT\ADM_MA.dta", replace

* Standardising variable names across countries

use "$OUTPUT\ADM_MA.dta", clear

rename (temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121) (temp_div_s1 prcp_div_s1 lag_temp_div_s1 lag_prcp_div_s1 lag2_temp_div_s1 lag2_prcp_div_s1 SPEI12_year_s1 lag_SPEI12_s1 lag2_SPEI12_s1)

rename (outmig_share3 outmig_sharel3 outmig_rate3 outmig_ratel3 temp_div3 prcp_div3 female3 nomarry3 noedu3 age3 lag_temp_div3 lag_prcp_div3 lag2_temp_div3 lag2_prcp_div3 SPEI12_year3 lag_SPEI123 lag2_SPEI123) (outmig_share_s2 outmig_sharel_s2 outmig_rate_s2 outmig_ratel_s2 temp_div_s2 prcp_div_s2 female_s2 nomarry_s2 noedu_s2 age_s2 lag_temp_div_s2 lag_prcp_div_s2 lag2_temp_div_s2 lag2_prcp_div_s2 SPEI12_year_s2 lag_SPEI12_s2 lag2_SPEI12_s2)

save "$OUTPUT\ADM_MA.dta", replace

