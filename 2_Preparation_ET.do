/*______________________________________________________________________________________
|                                                     									|
|							Social Tipping Points - Ethiopia							|	
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
	gen double habitable_id = _submission__id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
end

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

* Household level

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-General.dta", clear
	gen double habitable_id = _id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
	low
	keep habitable_id - othkin _gps_latitude - _gps_precision
	drop hid today deviceid i ii kin kinrel othkin // iii thanks address enumid enum_note consent typel restel iv v perception vi viii

rename _gps_* gps_*
	rename gps_precision gps_accuracy
	order gps_*, after(adm5)

// Generate country variable to help later when data sets are combined
gen country = 4
	label var country "Country"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia" 5 "Thailand"
	label val country country
	order country, before (adm1)

// Generate wave variable
gen wave = 1
	label var wave "Data collected in wave 1 (2022) or wave 2 (2023)"
	order wave, before (country)

// Correct number of children
replace adults = hhsize if adults>hhsize & adults<. // some households may have more adult members than total hhsize - 0 changes made
	gen children = hhsize - adults
	label var children "Number of children in the household"
	order children, after(adults)
	rename adults nadult
	label var hhsize "Household size"
	label var nadult "Number of adults in the household"
	
// Harmonise ethnicity with other countries
recode reseth (1=305) (2=306) (3=307) (4=308) (5=309) (6=310) (7=311) (8=312) (9=313) (10=314) (11=315)
	label var reseth "Ethnicitiy of respondent"
	label define ethnicity 101 "Akan" 102 "Ga-Dangme" 103 "Ewe" 104 "Guan" 105 "Gruma" 106 "Mole-Dagbani" 107 "Grussi" 108 "Mande" 109 "Basali" 110 "Fulani" 111 "Kotokoli" 112 "Kabire" 113 "Konkomba" 114 "Togo Karra" 115 "Other Ghana" 201 "Bambara" 202 "Malinké" 203 "Peul/Foulfoulbé" 204 "Sonrai/Djerma" 205 "Sarakolé/Soninké" 206 "Kassonké" 207 "Sénoufo" 208 "Dogon" 209 "Maure" 210 "Tamacheq" 211 "Bobo" 212 "Dafing" 213 "Minianka" 214 "Haoussa" 215 "Samogo" 216 "Bozo" 217 "Arabe" 218 "Mossi" 219 "Other Mali" 301 "Kamba" 302 "Kalenjin" 303 "Njemps" 304 "Other Kenya" 305 "Oromo" 306 "Amhara" 307 "Gamo" 308 "Goffa" 309 "Wolayita" 310 "Hadiya" 311 "Kambata" 312 "Guraghe" 313 "Kebena" 314 "Oyida" 315 "Other Ethiopia", replace
	label values reseth ethnicity
	drop otheth
// Harmonise religion with other countries
recode resrel (1 2 3 = 2) (4=3) (5 7 = 8) (6=1)
	label var resrel "Religion of respondent"
	label define religion 1 "No religion" 2 "Christianity" 3 "Islam" 4 "Buddhism" 5 "Hinduism" 6 "Animist" 7 "Tradionalist" 8 "Other" 9 "Not know", replace
	label val resrel religion
	drop othrel

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

sort hhid
tempfile w1
save	`w1'

* Household roster

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-Roster.dta", clear
	habitableid
	low
	drop hhsnum _index-tag id numig numadlcl
	rename lno hhmid
	order hhmid, after(habitable_id)
	drop if adult==0

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
	label define grade 0 "None" 1 "Grade 1" 2 "Grade 2" 3 "Grade 3" 4 "Grade 4" 5 "Grade 5" 6 "Grade 6" 7 "Grade 7" 8 "Grade 8" 9 "Grade 9" 10 "Grade 10" 11 "Grade 11" 12 "Grade 12" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)" 30 "Adult literacy" 31 "Religious education" 32 "Other" 77 "Not know", replace
	recode grade (1 2 3 4 5 = 0) (6 7 8 9 30 31 = 17) (10 11 = 18) (12=19) (32 77 = .)
	replace grade = 22 if othgrade == "Master" | othgrade == "Diploma" // Master and diploma both being higher education 
	drop othgrade
	label define grade 0 "None" 17 "Primary" 18 "Lower secondary" 19 "Upper secondary" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)", replace
	label values grade grade
label var liveh "Does person currently live with this household?"
	label define liveh 1 "Yes" 2 "No, living somewhere else in the same locality" 3 "No, living somewhere else outside the locality" 4 "No, passed away", replace
	label values liveh liveh
label var mig "Since 2012, has X lived outside the woreda for at least 3 months?"
	label define mig 0 "No" 1 "Yes", replace
	label values mig mig

sort habitable_id hhmid

preserve
ds habitable_id hhmid, not
rename (`r(varlist)') (=_w1)
tempfile roster1
save	`roster1'
restore
	
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
	
tempfile hhm
save	`hhm'

* Migration roster

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-mighist-1.dta", clear
	habitableid
	low
	rename lno hhmid
	drop name _parent_table_name - _submission__tags
	label var ntimes "Number of migration events over 10-year span"
	rename migyear* _migyear*
	sort habitable_id hhmid

tempfile mighist
save	`mighist'

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-moves.dta", clear
	habitableid
	low
	drop _index-_submission__tags

rename region level1
	rename zone level2
	rename wore level3
	rename othreason reason_specify

label var level1 "Level 1"
label var level2 "Level 2"
label var level3 "Level 3"

label var mvyear "Year of migration (Ethiopian calendar)"
gen year = mvyear + 8 // matches migration date with the one reported in migration history
	replace year = mvyear if mvyear>2018 & mvyear<.
	label var year "Year of migration (Gregorian calendar)"
	order year, before(mvyear)
	drop mvyear
	
sort habitable_id indmig

merge m:1 indmig using `mighist', keepusing(hhmid) nogen
	order hhmid, after(habitable_id)

sort habitable_id hhmid
	
tempfile moves
save	`moves'

* Dwelling characteristics

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-General.dta", clear
	gen double habitable_id = _id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
	low
	keep habitable_id tenure - tec7
	
rename othroof roof_specify
	rename othwall wall_specify
	rename othcfuel fuel_specify
	rename othwater water_specify
	rename othtoilet toilet_specify
	drop tec
	
label var tec1 "Radio"
	label var tec2 "TV"
	label var tec3 "Computer/laptop"
	label var tec4 "Tablet"
	label var tec5 "Landline"
	label var tec6 "Mobile phone without internet"
	label var tec7 "Mobile phone with internet"

drop *_specify
	
tempfile dwe
save	`dwe'

ds habitable_id, not
rename (`r(varlist)') (=_w1)
tempfile hh1
save	`hh1'

* Livelihoods

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-General.dta", clear
	gen double habitable_id = _id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
	low
	keep habitable_id empl - chact
	
tempfile liv1
save	`liv1'

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-activity.dta", clear
	habitableid
	low
	drop _index-_submission__tags hhsnum actvid

rename (actother othactsec othacttp) (act_specify actsec_specify acttp_specify)
reshape wide act act_specify actsec actsec_specify acttp acttp_specify actpay, i(habitable_id) j(actid)
	label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"
rename (act_specify1 act_specify2 actsec_specify1 actsec_specify2 acttp_specify1 acttp_specify2) (act1_specify act2_specify actsec1_specify actsec2_specify acttp1_specify acttp2_specify)

sort habitable_id

tempfile liv2
save	`liv2'

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-NETINC.dta", clear
	habitableid
	low
	rename id hhmid
	keep habitable_id hhmid wage semp rent _submission__uuid
	
reshape wide wage semp rent, i(habitable_id) j(hhmid)
drop wage8 semp8 rent8 // No obs
forvalues i=1/7		{	
	label var wage`i' "Net annual income from wages/salaries"
	label var semp`i' "Net annual income from self-employment"
	label var rent`i' "Net annual income from rents"
}

sort habitable_id

tempfile liv3
save	`liv3'

use "$INPUT\Ethiopia\Spouse-AAU\SpouseData.dta", clear
	low
	keep hhsnum hhsno hhid _id _uuid
	format _id %15.0f
	sort _id
	tempfile spouse
	save	`spouse'

use "$INPUT\Ethiopia\Spouse-AAU\SpouseData-activity.dta", clear
	format _submission__id %15.0f
	rename _submission__id _id
	sort _id
	merge m:1 _id using `spouse', nogen keep(match) // To drop 2 spouses with no household data
	low
	label var sno "Spouse index"
	order hhsnum, first 
	order sno, after(hhsnum)
	drop actvid _index _parent_table_name _submission__submission_time - _submission__tags

rename (actother othactsec othacttp) (act_specify actsec_specify acttp_specify)
	replace act = 21 if act_specify=="None" | act_specify=="None " | act_specify=="Not have work" | act_specify=="Nothing" | act_specify=="Nothing " 
reshape wide act act_specify actsec actsec_specify acttp acttp_specify actpay, i(hhsnum sno) j(actid)
	label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"
rename (act_specify1 act_specify2 actsec_specify1 actsec_specify2 acttp_specify1 acttp_specify2) (act1_specify act2_specify actsec1_specify actsec2_specify acttp1_specify acttp2_specify)

bys hhsnum: gen test = _n // Only one wife per household head
	tab test
	drop test 

ds hhsnum sno, not
rename (`r(varlist)') (s=)
sort hhsnum sno
	
tempfile sact
save	`sact'

* Perceptions of climate risks

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-General.dta", clear
	gen double habitable_id = _id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
	low
	keep habitable_id evtfrq1 - q71

rename (evtha* evtfi* q71) (evtlha* evtlfi* evtoth)
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

	label define yesno 0 "No" 1 "Yes", replace
	label values evtlhd1 evtlhd2 evtlhd3 evtlhd4 evtoth yesno
	
tempfile risks
save	`risks'

* Household Adaptation

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-General.dta", clear
	gen double habitable_id = _id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
	low
	keep habitable_id adpdec - othadpnet

tempfile hhadap1
save	`hhadap1'
	
use "$INPUT\Ethiopia\Household-AAU\HouseholdData-adapthh.dta", clear
	habitableid
	low
	replace adpid = repeat // To correct repeated numbering of adaptation responses
	keep habitable_id adpid adp adpch adpno
	
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
	label define direction 1 "Increased" 2 "Decreased", replace
	foreach var of varlist adpch1 adpch2 adpch3 adpch4 adpch5 adpch6 adpch7 adpch8 adpch9 adpch10 adpch11 adpch12 adpch13 adpch14 {
		label values `var' direction
	}

	label define noadap 1 "Would like but have not done it" 2 "Are not interested", replace
	foreach var of varlist adpno1 adpno2 adpno3 adpno4 adpno5 adpno6 adpno7 adpno8 adpno9 adpno10 adpno11 adpno12 adpno13 adpno14 {
		label var `var' "Reason for no adaptation"
		label values `var' noadap
	}

sort habitable_id
	
tempfile hhadap2
save	`hhadap2'

* Adaptive capacity

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-General.dta", clear
	gen double habitable_id = _id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
	low
	keep habitable_id ac1 - ac12

tempfile adapc
save	`adapc'

* Personality traits

use "$INPUT\Ethiopia\Household-AAU\HouseholdData-General.dta", clear
	gen double habitable_id = _id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 // Homogeneise id starting with country number
	order habitable_id, first
	label var habitable_id "Habitable ID"
	low
	keep habitable_id pw1 - pw11

tempfile ptraits
save	`ptraits'


* Merge all sections

use `intro', clear
	merge 1:1 habitable_id using `dwe', nogen 
	merge 1:1 habitable_id using `liv1', nogen
	merge 1:1 habitable_id using `liv2', nogen
	merge 1:1 habitable_id using `liv3', nogen
		sort hhsnum
	merge 1:1 hhsnum using `sact', keepusing(sactpay1 sactpay2) keep(match master) nogen
	merge 1:1 habitable_id using `risks', nogen
	merge 1:1 habitable_id using `hhadap1', nogen
	merge 1:1 habitable_id using `hhadap2', nogen
	merge 1:1 habitable_id using `adapc', nogen
	merge 1:1 habitable_id using `ptraits', nogen
	
tempfile et1
save	`et1'

use `hhm', clear
	merge 1:1 habitable_id hhmid year using `moves', nogen
	tempfile long
	save	`long'

use `et1', clear
	merge 1:m habitable_id using `long', nogen
	sort habitable_id hhmid year

by habitable_id hhmid year: gen test = _n
	tab test, m // 1 obs per year
	drop test
	
tempfile etpy1
save	`etpy1'

collapse wave liveh, by(habitable_id hhmid)
tempfile id1
save	`id1'

collapse wave, by(habitable_id)
tempfile test1
save	`test1'

*********************************************************** W2 *************************************************************

* Household level

use "$INPUT\Ethiopia\Wave 2\Old\Wave_2_Household_Data.dta", clear
	low
	sort hhid
	merge 1:m hhid using `w1', nogen keepusing(habitable_id hhsnum) keep(match master)
	sort habitable_id
	order habitable_id, first
	drop address gps enumid consent resname resrep restel name*
	
rename _gps_* gps_*
	rename gps_precision gps_accuracy
	order gps_*, after(adm5)

// To remove location from wave 2 in order to keep location from wave 1 only
*drop adm1 - gps_accuracy 
	
// Generate country variable to help later when data sets are combined
gen country = 4
	label var country "Country"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia" 5 "Thailand", replace
	label val country country
	order country, after(habitable_id)

// Generate wave variable
gen wave = 2
	label var wave "Data collected in wave 1 (2022) or wave 2 (2023)"
	order wave, before (country)

// Correct number of children
replace adults = hhsize if adults>hhsize & adults<. // some households may have more adult members than total hhsize - 0 changes made
	gen children = hhsize - adults if adults<=hhsize & hhsize<.
	label var children "Number of children in the household"
	order children, after(adults)
	rename adults nadult
	label var hhsize "Household size"
	label var nadult "Number of adults in the household"
	
// Harmonise ethnicity with other countries
recode reseth (1=305) (2=306) (3=307) (4=308) (5=309) (6=310) (7=311) (8=312) (9=313) (10=314) (11=315)
	label var reseth "Ethnicitiy of respondent"
	label define ethnicity 101 "Akan" 102 "Ga-Dangme" 103 "Ewe" 104 "Guan" 105 "Gruma" 106 "Mole-Dagbani" 107 "Grussi" 108 "Mande" 109 "Basali" 110 "Fulani" 111 "Kotokoli" 112 "Kabire" 113 "Konkomba" 114 "Togo Karra" 115 "Other Ghana" 201 "Bambara" 202 "Malinké" 203 "Peul/Foulfoulbé" 204 "Sonrai/Djerma" 205 "Sarakolé/Soninké" 206 "Kassonké" 207 "Sénoufo" 208 "Dogon" 209 "Maure" 210 "Tamacheq" 211 "Bobo" 212 "Dafing" 213 "Minianka" 214 "Haoussa" 215 "Samogo" 216 "Bozo" 217 "Arabe" 218 "Mossi" 219 "Other Mali" 301 "Kamba" 302 "Kalenjin" 303 "Njemps" 304 "Other Kenya" 305 "Oromo" 306 "Amhara" 307 "Gamo" 308 "Goffa" 309 "Wolayita" 310 "Hadiya" 311 "Kambata" 312 "Guraghe" 313 "Kebena" 314 "Oyida" 315 "Other Ethiopia", replace
	label values reseth ethnicity
	drop otheth // No obs
// Harmonise religion with other countries
recode resrel (1 2 3 = 2) (4=3) (5 7 = 8) (6=1)
	label var resrel "Religion of respondent"
	label define religion 1 "No religion" 2 "Christianity" 3 "Islam" 4 "Buddhism" 5 "Hinduism" 6 "Animist" 7 "Tradionalist" 8 "Other" 9 "Not know", replace
	label val resrel religion
	drop othrel

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
	
// Harmonise timestamp with wave 1
rename start timesta
	format timesta %td

rename end timeend
	format timeend %td
	
tempfile ros2
save	`ros2'	
	
// Reshape household member roster

preserve
use `ros2', clear
	merge 1:m habitable_id using `roster1', keep(match) // To bring all HHMs details from Wave 1
	sort habitable_id hhmid
	drop sex1 - numig11
	rename *_w1 *
tempfile roster2
save	`roster2'

use `ros2', clear
keep habitable_id wave sex1 - numig11
reshape long sex@ age@ adult@ marry@ relhh@ othrelhh@ grade@ othgrade@ liveh@ mig@ numig@, i(habitable_id) j(hhmid)
	drop if adult==0
	drop if sex==. & age==. & adult==. & marry==. & relhh==. & grade==. & liveh==. // 10,048 obs
	replace hhmid = hhmid+15 // Max value of hhmid in Wave 1 is 15
	sort habitable_id hhmid
tempfile new2
save	`new2'

use `roster2', clear
	append using `new2' // 223 new HHMs in Wave 2
	sort habitable_id hhmid

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
	replace relhh = 6 if !missing(othrelhh)
	label define relhh 0 "Head" 1 "Spouse" 2 "Partner" 3 "Parent" 4 "Child" 5 "Sibling" 6 "Other", replace
	label values relhh relhh
label var grade "Highest grade that person has completed (excluding pre-primary)"
	label define grade 0 "None" 1 "Grade 1" 2 "Grade 2" 3 "Grade 3" 4 "Grade 4" 5 "Grade 5" 6 "Grade 6" 7 "Grade 7" 8 "Grade 8" 9 "Grade 9" 10 "Grade 10" 11 "Grade 11" 12 "Grade 12" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)" 30 "Adult literacy" 31 "Religious education" 32 "Other" 77 "Not know", replace
	recode grade (1 2 3 4 5 = 0) (6 7 8 9 30 31 = 17) (10 11 = 18) (12=19) (32 77 = .)
	replace grade = 22 if othgrade == "Master" | othgrade == "Diploma" // Master and diploma both being higher education 
	replace grade = . if othgrade=="Don't know"
	drop othgrade
	label define grade 0 "None" 17 "Primary" 18 "Lower secondary" 19 "Upper secondary" 20 "Post-secondary; Vocational" 21 "University (undergraduate)" 22 "University (postgraduate)", replace
	label values grade grade
label var liveh "Does person currently live with this household?"
	label define liveh 1 "Yes" 2 "No, living somewhere else in the same locality" 3 "No, living somewhere else outside the locality" 4 "No, passed away", replace
	label values liveh liveh
label var mig "Since 2012, has X lived outside the woreda for at least 3 months?"
	label define mig 0 "No" 1 "Yes", replace
	label values mig mig
expand 2	
	sort habitable_id hhmid	
	by habitable_id hhmid: gen year = _n
	order year, after(hhmid)
	replace year = 2022 if year==1
	replace year = 2023 if year==2
	sort habitable_id hhmid year
tempfile hhm2
save	`hhm2'
restore

// Reshape migration history
preserve
keep habitable_id nmig1 - othreason7
reshape long nmig@ migyear@ ntimes@ mvyear@ coutr@ outeth@ region@ zone@ wore@ dury@ durm@ durmy@ reason@ othreason@, i(habitable_id) j(hhmid)
rename migyear year
	replace year = 2022 if mvyear=="2022"
	drop mvyear
	keep if year<.
replace coutr = 37 if outeth=="Djibouti" | outeth=="Jordan" | outeth=="UAE" | outeth=="USA"
	drop outeth othreason
sort habitable_id hhmid year
tempfile mighis2
save	`mighis2'

use `hhm2', clear
	merge 1:1 habitable_id hhmid year using `mighis2', keep(match master) nogen
	sort habitable_id hhmid year
tempfile long2
save	`long2'
restore	

// Dwelling characteristics

drop sex1 - othreason7

rename othroof roof_specify
	rename othwall wall_specify
	rename othcfuel fuel_specify
	rename othwater water_specify
	rename othtoilet toilet_specify
	drop tec

merge 1:1 habitable_id using `hh1', nogen keep(master match)

	foreach v of varlist rooms roof wall floor elect cfuel water toilet tec1 tec2 tec3 tec4 tec5 tec6 tec7	{
		replace `v' = `v'_w1 if `v'==.
	}
	drop rooms_w1 roof_w1 wall_w1 floor_w1 elect_w1 cfuel_w1 water_w1 toilet_w1 tec1_w1 tec2_w1 tec3_w1 tec4_w1 tec5_w1 tec6_w1 tec7_w1 tenure_w1 

drop roof_specify wall_specify fuel_specify water_specify toilet_specify
	
// Harmonise livelihoods labels
label var act1 "Main work activity"
	label var act2 "Second main work activity"
	label var actsec1 "Sector"
	label var actsec2 "Sector"
	label var acttp1 "Type of activity"
	label var acttp2 "Type of activity"
	label var actpay1 "Annual earnings from activity"
	label var actpay2 "Annual earnings from activity"

// Harmonise climate risks labels	
rename (evtha? evtfi? q71) (evtlha? evtlfi? evtoth)
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
	
	label var evtoth "Was there any non-environmental event that also caused losses around the same time?"

	label define yesno 0 "No" 1 "Yes", replace
	label values evtlhd1 evtlhd2 evtlhd3 evtlhd4 evtoth yesno
	
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
	label var othadpid "Household adapted through other response, specify"
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
	label define direction 1 "Increased" 2 "Decreased", replace
	foreach var of varlist adpch1 adpch2 adpch3 adpch4 adpch5 adpch6 adpch7 adpch8 adpch9 adpch10 adpch11 adpch12 adpch13 adpch14 {
		label values `var' direction
	}

	label define noadap 1 "Would like but have not done it" 2 "Are not interested", replace
	foreach var of varlist adpno1 adpno2 adpno3 adpno4 adpno5 adpno6 adpno7 adpno8 adpno9 adpno10 adpno11 adpno12 adpno13 adpno14 {
		label var `var' "Reason for no adaptation"
		label values `var' noadap
	}

tempfile et2
save	`et2'

* Spouse data 

use "$INPUT\Ethiopia\Wave 2\Old\Wave_2_Spouse_Data.dta", clear
low
	sort hhid
	merge 1:m hhid using `w1', nogen keepusing(habitable_id) keep(match master)
	sort habitable_id
	order habitable_id, first

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

ds habitable_id resid, not
rename (`r(varlist)') (s=)
sort habitable_id
	
tempfile sact2
save	`sact2'

use `et2', clear
	merge 1:1 habitable_id using `sact2', nogen keepusing(sactpay1 sactpay2) keep(match master)
	merge 1:m habitable_id using `long2', nogen
	sort habitable_id hhmid year

by habitable_id hhmid year: gen test = _n
	tab test, m // 1 obs per year
	drop test
	
tempfile etpy2
save	`etpy2'

collapse wave liveh, by(habitable_id hhmid)
tempfile id2
save	`id2'

collapse wave, by(habitable_id)
tempfile test2
save	`test2'
	
*********************************************************** W1 & W2 *************************************************************

use `test1', clear
	merge 1:1 habitable_id using `test2' // 7% household attrition
	keep if _merge==1
	rename _merge attr
	drop wave
	tempfile attrition
	save	`attrition'
	
use `id1', clear
	tab liveh // 83 HHMs passed away in Wave 1
	merge 1:1 habitable_id hhmid using `id2'
		drop wave
		rename _merge waveid
		label define waveid 1 "Only in Wave 1" 2 "Only in Wave 2" 3 "In both waves", replace // 189 HHMs in Wave 1 only and all correspond to attrition (69 households)
		label values waveid waveid
		label var waveid "Wave for each individual"
	merge m:1 habitable_id using `attrition', nogen
		drop if attr==1	// To keep households present in both waves
sort habitable_id hhmid
	egen py = group(habitable_id hhmid)
	order py, after(hhmid)
	*drop if liveh==4 // To drop 83 hhm who passed away
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

use `etpy1', clear
	append using `etpy2' // Year 2022 appears in each wave. More than one move per year was recorded.
	
// To clean empty duplicates and duplicates for year 2022

order hhmid, after(habitable_id)
	order year, after(hhmid)

bys habitable_id hhmid year: egen todrop1 = count(coutr)
	drop if todrop1==0 & year==2022 & wave==2 // If never moved, keep wave 1.
sort habitable_id hhmid year wave
	drop if todrop1==1 & year==2022 & coutr==. // If moved only once, keep the wave when moved.
sort habitable_id hhmid year wave
	*by habitable_id hhmid year wave: gen todrop2 = _n if todrop1==2
	drop if todrop1==2 & year==2022 & coutr==. // If moved twice (0,2 or 2,0), drop wave with no move. If (1,1), keep both waves.
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
	
bys habitable_id hhmid year: gen test = _n
	tab test
	drop todrop* test length
	
tempfile etpy
save	`etpy'

use `w1w2', clear
	merge 1:1 habitable_id hhmid year using `etpy', nogen keep(match master) // To exclude HHMs in attrition households

distinct py
distinct habitable_id

order wave, after(year)
	replace wave = 1 if year<=2021
	replace wave = 2 if year>=2022 & year<=2023
	order sex - reason_specify, last
	order nros1 - newrost, before(sex)	
	order improv, before(tenure)
	order hhrem hhrempay, after(sactpay2)
	sort habitable_id hhmid year

* Locality checks

preserve
	sort habitable_id hhmid year
	collapse adm5, by(habitable_id year) 
	by habitable_id: gen test = (adm5[1]!=adm5[_N]) // 0 entire households moved between waves
restore

* Individual characteristics

// To fill in missing info on initial location
sort habitable_id hhmid year
foreach v of var country adm1-adm5 	{
	by habitable_id hhmid: replace `v' = `v'[_n-1] if wave==2 & waveid==1	
	by habitable_id hhmid: replace `v' = `v'[_n-1] if wave==2 & waveid==3
}
foreach v of var country adm1-adm5 	{
	by habitable_id: replace `v' = `v'[1] if waveid==2
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
replace liveh = 3 if missing(liveh) & year<=2021 // To fill in status of new HHMs only in Wave 2

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
	tab nmoves // Max number of moves = 11
	forvalues j=1/11	{
	by habitable_id hhmid: replace inhh = 3 if inhh==. & !missing(coutr) & (liveh==1|liveh==2) & nmoves==`j' & waveid==3 // Even if dury==0, moves that last less than a year are also counted
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & dury[_n-`i']>=`i'+1 & dury[_n-`i']<=12 & (liveh==1|liveh==2) & nmoves==`j' & waveid==3
		}
		forvalues i=1/11	{
			by habitable_id hhmid: replace inhh = 3 if inhh==. & coutr[_n-`i']==2 & missing(dury) & (liveh==1|liveh==2) & nmoves==`j' & waveid==3 // HHMs who left Ethiopia, but returned
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
	forvalues j=1/11	{
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

// To calculate outmigration rates at Administrative Level 5 of the original sampling sites

sort habitable_id hhmid year
	
	// Create a variable for migrants for each year
	bys adm5 year: egen yearly_mig5 = total(moved)
		label var yearly_mig5 "Annual number of migrants"

	// Calculate the population at risk per year
	gen inloc5 = (inhh==1 | inhh==2)
		label var inloc5 "In the locality this year"
	bys adm5 year: egen totinloc5 = total(inloc5)
		egen pop_at_risk5 = rowtotal(totinloc5 yearly_mig5)
		label var pop_at_risk5 "Population at risk of migration"		
	sort adm5 habitable_id hhmid year 
	by adm5: gen pop_at_risk51 = pop_at_risk5[1]
		label var pop_at_risk51 "Initial population at risk of migration"

	// Calculate the outmigration rate
	bys adm5 year: gen outmig_rate5 = (yearly_mig5 / pop_at_risk5) * 100
		label var outmig_rate5 "Percentage of outmigration per year"

	// Calculate the change in outmigration taken as a share of the initial population at risk
	bys adm5 year: gen outmig_share5 = (yearly_mig5 / pop_at_risk51) * 100
		label var outmig_share5 "Outmigration as a share of initial population at risk"

// To calculate outmigration rates only for long-term migration at administration level 5

sort habitable_id hhmid year
	
	// Create a variable for migrants for each year
	gen lmoved = (moved==1 & length>=12 & !missing(length))
	bys adm5 year: egen yearly_migl5 = total(lmoved)
		label var yearly_migl5 "Annual number of long-term migrants"

	// Calculate the population at risk per year
	gen inlocl5 = (inhh==1 | inhh==2 | (moved==1 & length<12))
		label var inlocl5 "In the locality this year"
	bys adm5 year: egen totinlocl5 = total(inlocl5)
		egen pop_at_riskl5 = rowtotal(totinlocl5 yearly_migl5)	
		label var pop_at_riskl5 "Population at risk of migration"
	sort adm5 habitable_id hhmid year 
	by adm5: gen pop_at_riskl51 = pop_at_riskl5[1]
		label var pop_at_riskl51 "Initial population at risk of migration"

	// Calculate the outmigration rate
	bys adm5 year: gen outmig_ratel5 = (yearly_migl5 / pop_at_riskl5) * 100
		label var outmig_ratel5 "Percentage of long-term outmigration per year"
		
	// Calculate the change in outmigration taken as a share of the initial population at risk
	bys adm5 year: gen outmig_sharel5 = (yearly_migl5 / pop_at_riskl51) * 100
		label var outmig_sharel5 "Long-term outmigration as a share of initial population at risk"

* Income

egen hsinc_birr = rowtotal(actpay1 actpay2 sactpay1 sactpay2)
	label var hsinc_birr "Head and spouse annual income (ETB)"

egen hhpay = rowtotal(wage1 - rent7 wage8 semp8 rent8 wage9 semp9 rent9 wage10 semp10 rent10)
	label var hsinc_birr "Household annual income (ETB)"
	
// Mid-date of wave 1: 12/10/2022

gen hsinc_usd = hsinc_birr*0.01893 if wave==1
	label var hsinc_usd "Head and spouse annual income (USD)"

gen hhpay_usd = hhpay*0.01893 if wave==1
	label var hhpay_usd "Household annual income (USD)"

// Mid-date of wave 2: 11/12/2023

replace hsinc_usd = hsinc_birr*0.01783 if wave==2

replace hhpay_usd = hhpay*0.01783 if wave==2

su hsinc_usd if wave==1, det
	centile hsinc_usd if wave==1, centile(99.5)
	*The 99.5 percentile is at 9465
	replace hsinc_usd = 9465 if hsinc_usd>9465 & hsinc_usd<. & wave==1 // 176 obs

su hhpay_usd if wave==1, det
	centile hhpay_usd if wave==1, centile(99.5)
	*The 99.5 percentile is at 7477.35
	replace hhpay_usd = 7477.35 if hhpay_usd>7477.35 & hhpay_usd<. & wave==1 // 170 obs

su hsinc_usd if wave==2, det
	centile hsinc_usd if wave==2, centile(99.5)
	*The 99.5 percentile is at 14210.51
	replace hsinc_usd = 14210.51 if hsinc_usd>14210.51 & hsinc_usd<. & wave==2 // 13 obs

su hhpay_usd if wave==2, det
	centile hhpay_usd if wave==2, centile(99.5)
	*The 99.5 percentile is at 9806.5
	replace hhpay_usd = 9806.5 if hhpay_usd>9806.5 & hhpay_usd<. & wave==2 // 12 obs
	
* Remittances	

gen remit = 0 if wave==2	
	replace remit = hhrempay*0.01783 if wave==2
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

forvalues i=1/14	{
	replace adp`i' = . if adp`i'==-7777 | adp`i'==-8888
}

egen adap = rowtotal(adp1 adp2 adp3 adp4 adp5 adp6 adp7 adp8 adp9 adp10 adp11 adp12 adp13 adp14)
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

gen denom = (moved==1 | inloc5==1)
	
gen female = 1 if sex==0 | sex==2 
	replace female = 0 if sex==1
	label var female "Female"
	gen _female = female if denom==1
	bys adm5 year: egen female5 = mean(_female)
	label var female5 "Share of females in the site on a given year"

gen married = 1 if marry==2
	replace married = 0 if marry!=2 & !missing(marry)
	label var married "Married"

gen nomarry = 1 if marry==1
	replace nomarry = 0 if marry!=1 & !missing(marry)
	label var nomarry "Never married"
	gen _nomarry = nomarry if denom==1
	bys adm5 year: egen nomarry5 = mean(_nomarry)
	label var nomarry5 "Share of adults who never married in the site on a given year"
	
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
	bys adm5 year: egen noedu5 = mean(_noedu)
	label var noedu5 "Share of individuals with no education in the site on a given year"
	
gen relhead = (relhh==0) if !missing(relhh)
	label define relhead 0 "Other" 1 "Head", replace
	label values relhead relhead
	label var relhead "Head of the household"

gen relmaj = (resrel==2)
	label var relmaj "Member of religious majority"
	
foreach v of varlist age wi hhpay_usd relmaj	{
	gen _`v' = `v' if denom==1
	bys adm5 year: egen `v'5 = mean(_`v')
}
label var age5 "Average age in the site on a given year"
label var wi5 "Average wealth index in the site on a given year"
label var relmaj5 "Share of majority religion"

drop _*

sort habitable_id hhmid py year hhsnum hhsno hhid
	by habitable_id hhmid: replace hhsnum = hhsnum[_N] if missing(hhsnum)
	rename habitable_id habitable_id2
	bys hhsnum hhmid year: gen test = _n
	tab test, m
	drop test

rename hhsnum habitable_id
sort habitable_id year
	
tempfile hhmy
save	`hhmy'

* To merge climate data

use "$OUTPUT\All_climate_annual.dta", clear
	keep if country==4
	tempfile clim
	save	`clim'
	
use `hhmy', clear
	merge m:1 habitable_id year using `clim', nogen keep(match) // _m==2 for lagged climate (years 2002 to 2011) and attrition
	*replace hhmid = 1 if hhmid==. & year>=2002 & year<=2011 // To assign lagged climate variables to head of household
	*drop if hhmid==.
	drop py
	drop habitable_id
	rename habitable_id2 habitable_id
	egen panelid = group(habitable_id hhmid)
	order habitable_id, first
	order panelid, after(hhmid)
	
tab adm1, gen(reg)
	tab adm5, gen(loc)
	tab year, gen(year) // 22 years (2002-2023)

sort habitable_id hhmid year
	
save "$OUTPUT\HHMY_ET.dta", replace

* Collapsing person-year dataset into locality-year dataset

use "$OUTPUT\HHMY_ET.dta", clear

keep if year>=2012 & year<=2023

preserve
	collapse (mean) country region adm1 adm2 adm3 adm4 outmig_share5 outmig_sharel5 outmig_rate5 outmig_ratel5 temp_div prcp_div female5 nomarry5 noedu5 age5 lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div mean_temp sd_temp SPEI12_year lag_SPEI12 lag2_SPEI12, by(adm5 year)
	rename (temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12) ///
	(temp_div5 prcp_div5 lag_temp_div5 lag_prcp_div5 lag2_temp_div5 lag2_prcp_div5 SPEI12_year5 lag_SPEI125 lag2_SPEI125)
	sort adm1 adm2 adm3 adm4 year
	tempfile v5
	save	`v5'
restore

preserve
collapse (mean) temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12, by(adm1 year)
	rename (temp_div prcp_div lag_temp_div lag_prcp_div lag2_temp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12) ///
	(temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121)
	sort adm1 year
	tempfile v1
	save	`v1'
restore
	
use `v5', clear
	merge m:1 adm1 year using `v1', keepusing(temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121) nogen
	order adm5, after(adm4)
	label var outmig_share5 "Outmigration share at the site level"
	label var temp_div5 "Temperature anomalies at the site level"
	label var prcp_div5 "Rainfall anomalies at the site level"
	label var mean_temp "Long-run temperature mean (2002-2011)"
	label var sd_temp "Long-run temperature SD (2002-2011)"	
	label var female5 "Share of females at the site level"
	label var nomarry5 "Share of non-married adults at the site level"	
	label var age5 "Average age at the site level"
	label var noedu5 "Share of adults with no education at the site level"
	label var temp_div1 "Temperature anomalies at the region level"
	label var prcp_div1 "Rainfall anomalies at the region level"
	label var lag_temp_div5 "One-lag temperature anomalies at the site level"
	label var lag2_temp_div5 "Two-lag temperature anomalies at the site level"
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia", replace
	label val country country
	label define region 1 "Volta" 2 "Northern" 3 "Kayes" 4 "Sikasso" 5 "Makueni" 6 "Baringo" 7 "Oromia" 8 "SNNP", replace
	label val region region

tab adm1, gen(reg)
tab adm5, gen(loc)
tab year, gen(year)
	
save "$OUTPUT\ADM_ET.dta", replace

* Standardising variable names across countries

use "$OUTPUT\ADM_ET.dta", clear

rename (temp_div1 prcp_div1 lag_temp_div1 lag_prcp_div1 lag2_temp_div1 lag2_prcp_div1 SPEI12_year1 lag_SPEI121 lag2_SPEI121) (temp_div_s1 prcp_div_s1 lag_temp_div_s1 lag_prcp_div_s1 lag2_temp_div_s1 lag2_prcp_div_s1 SPEI12_year_s1 lag_SPEI12_s1 lag2_SPEI12_s1)

rename (outmig_share5 outmig_sharel5 outmig_rate5 outmig_ratel5 temp_div5 prcp_div5 female5 nomarry5 noedu5 age5 lag_temp_div5 lag_prcp_div5 lag2_temp_div5 lag2_prcp_div5 SPEI12_year5 lag_SPEI125 lag2_SPEI125) (outmig_share_s2 outmig_sharel_s2 outmig_rate_s2 outmig_ratel_s2 temp_div_s2 prcp_div_s2 female_s2 nomarry_s2 noedu_s2 age_s2 lag_temp_div_s2 lag_prcp_div_s2 lag2_temp_div_s2 lag2_prcp_div_s2 SPEI12_year_s2 lag_SPEI12_s2 lag2_SPEI12_s2)

save "$OUTPUT\ADM_ET.dta", replace


