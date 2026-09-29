/*______________________________________________________________________________________
|                                                     									|
|							Social Tipping Points - All countries						|	
|  Routine to assembly datasets on climate variability.									|
|_______________________________________________________________________________________|*/

clear all
set more off, perm
*set graphics off
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

* DATA PREPARATION
* ----------------

use "$INPUT\All_climate_monthly.dta", clear
	order adm4 adm5, after(adm3)
	order year month, after(y)

	
*** Clean identifiers

// Create a single identifier for each pair of coordinates
egen long_lat = group(gps_longitude gps_latitude)
	label var long_lat "Single identifier for each pair of household coordinates"
	order long_lat, after(gps_longitude)
	sort long_lat year

egen xy = group(x y)
	order xy, after (y)
	
recode country (2=3) (3=2)
	label define country 1 "Ghana" 2 "Mali" 3 "Kenya" 4 "Ethiopia", replace
	label val country country
	label var country "Country"
	tab country

// Correct regional labels

gen region = 1 if adm1 == "Volta"
replace region = 2 if adm1 == "Nothern"
replace region = 3 if adm1 == "Kayes"
replace region = 4 if adm1 == "Sikasso"
replace region = 5 if adm1 == "Makueni" | new_household=="true"
replace region = 6 if adm1 == "Baringo"
replace region = 7 if adm1 == "Oromia"
replace region = 8 if adm1 == "SNNP"
label define region 1 "Volta" 2 "Northern" 3 "Kayes" 4 "Sikasso" 5 "Makueni" 6 "Baringo" 7 "Oromia" 8 "SNNP", replace
label val region region
tab region

drop adm1 adm2 adm3
order region, after(country)
	
// Standardise household identifier
	
rename habitableid habitable_id
	format habitable_id %13.0f
	sort habitable_id
	replace habitable_id = 1000000000000+habitable_id if habitable_id<1000000000000 & country==1 // Homogeneise id starting with country number
	replace habitable_id = 2000000000000+habitable_id if habitable_id<1000000000000 & country==2 // Homogeneise id starting with country number	
	replace habitable_id = 3000000000000+habitable_id if habitable_id<1000000000000 & country==3 // Homogeneise id starting with country number
	*replace habitable_id = 4000000000000+habitable_id if habitable_id<1000000000000 & country==4 // Homogeneise id starting with country number
	replace habitable_id = 3000000369201 if habitable_id==. & new_id==4071
	replace habitable_id = 3000000710682 if habitable_id==. & new_id==4085
	replace habitable_id = 3000000161671 if habitable_id==. & new_id==4061
	replace habitable_id = 3000000337726 if habitable_id==. & new_id==4067
	replace habitable_id = 3000000346658 if habitable_id==. & new_id==4069
	replace habitable_id = 3000000837499 if habitable_id==. & new_id==4095
	replace habitable_id = 3000000857188 if habitable_id==. & new_id==4096
	replace habitable_id = 3000000192825 if habitable_id==. & new_id==4062
	replace habitable_id = 3000000132250 if habitable_id==. & new_id==4059
	replace habitable_id = 3000000739760 if habitable_id==. & new_id==4088
	replace habitable_id = 3000000980027 if habitable_id==. & new_id==4103
	replace habitable_id = 3000000757772 if habitable_id==. & new_id==4091
	replace habitable_id = 3000000722509 if habitable_id==. & new_id==4086
	replace habitable_id = 3000000201696 if habitable_id==. & new_id==4063
	replace habitable_id = 3000000614698 if habitable_id==. & new_id==4081
	replace habitable_id = 3000000983250 if habitable_id==. & new_id==4104
	replace habitable_id = 3000000739838 if habitable_id==. & new_id==4089
	replace habitable_id = 3000000367834 if habitable_id==. & new_id==4070
	replace habitable_id = 3000000610255 if habitable_id==. & new_id==4079
	replace habitable_id = 3000000340022 if habitable_id==. & new_id==4068
	replace habitable_id = 3000000723354 if habitable_id==. & new_id==4087
	replace habitable_id = 3000000692002 if habitable_id==. & new_id==4084
	replace habitable_id = 3000000991648 if habitable_id==. & new_id==4105
	replace habitable_id = 3000000314808 if habitable_id==. & new_id==4065
	replace habitable_id = 3000000747572 if habitable_id==. & new_id==4090
	replace habitable_id = 3000000938603 if habitable_id==. & new_id==4102
	replace habitable_id = 3000000887235 if habitable_id==. & new_id==4098
	replace habitable_id = 3000000147782 if habitable_id==. & new_id==4060
	replace habitable_id = 3000000632986 if habitable_id==. & new_id==4082
	replace habitable_id = 3000000513586 if habitable_id==. & new_id==4077
	replace habitable_id = 3000000510713 if habitable_id==. & new_id==4076
	replace habitable_id = 3000000887029 if habitable_id==. & new_id==4097
	replace habitable_id = 3000000788827 if habitable_id==. & new_id==4092
	replace habitable_id = 3000000505500 if habitable_id==. & new_id==4075
	replace habitable_id = 3000000803448 if habitable_id==. & new_id==4094
	replace habitable_id = 3000000559910 if habitable_id==. & new_id==4078
	replace habitable_id = 3000000793167 if habitable_id==. & new_id==4093
	replace habitable_id = 3000000897194 if habitable_id==. & new_id==4099
	replace habitable_id = 3000000459190 if habitable_id==. & new_id==4073
	replace habitable_id = 3000000224312 if habitable_id==. & new_id==4064
	replace habitable_id = 3000000476116 if habitable_id==. & new_id==4074
	replace habitable_id = 3000000611265 if habitable_id==. & new_id==4080
	replace habitable_id = 3000000124811 if habitable_id==. & new_id==4058
	replace habitable_id = 3000000903447 if habitable_id==. & new_id==4101
	replace habitable_id = 3000000331714 if habitable_id==. & new_id==4066
	replace habitable_id = 3000000423543 if habitable_id==. & new_id==4072
	replace habitable_id = 3000000899928 if habitable_id==. & new_id==4100
	replace habitable_id = 3000000682166 if habitable_id==. & new_id==4083
	replace habitable_id = 3000000872986 if habitable_id==. & new_id==4106 & long_lat==2456
	replace habitable_id = 3000000995865 if habitable_id==. & new_id==4106 & long_lat==2457
	sort habitable_id year
	
keep habitable_id year month country region long_lat xy pavg tavg SPEI1 SPEI12
	
	
*** Generate annual averages of the monthly data

bysort habitable_id year: egen pavg_year = mean(pavg)
label var pavg_year "Average daily rainfall in mm over the year"

bysort habitable_id year: egen tavg_year = mean(tavg)
label var  tavg_year "Average daily temperature in C over the year"

bysort habitable_id year: egen SPEI1_year = mean(SPEI1)
label var SPEI1_year "Average SPEI1 by year"

bysort habitable_id year: egen SPEI12_year = mean(SPEI12)
label var SPEI12_year "Average SPEI12 by year"

collapse (firstnm) country region xy pavg_year tavg_year SPEI1_year SPEI12_year, by(habitable_id year)

label var habitable_id "Household identifier"
label var year "Year"
label var country "Country"
label var region "Region"
label var xy "Single identifier for the nearest ERA5 raster point"
label var pavg_year "Average daily rainfall in a year"
label var tavg_year "Average daily temperature in a year"
label var SPEI1_year "Standardised Precipitation Evapotranspiration Index (SPEI1)"
label var SPEI12_year "Standardised Precipitation Evapotranspiration Index (SPEI12)"


*** Generate temperature and precipitation anomalies from decadal mean (2002-2011) in the location
	
// Temperature

sort xy year

by xy: egen mean_temp = mean(cond(year >= 2002 & year <= 2011, tavg_year, .))
	label var mean_temp "Average temperature between 2002-2011 in the location"

by xy: egen sd_temp = sd(cond(year >= 2002 & year <= 2011, tavg_year, .))
	label var sd_temp "SD of temperature between 2002-2011 in the location"
	
gen temp_div = (tavg_year - mean_temp)/sd_temp 
	label var temp_div "Temperature anomalies from decadal mean (2002-2011) in the location"

// Precipitation

by xy: egen mean_prcp = mean(cond(year >= 2002 & year <= 2011, pavg_year, .))
	label var mean_prcp "Average precipitation between 2002-2011 in the location"

by xy: egen sd_prcp = sd(cond(year >= 2002 & year <= 2011, pavg_year, .))
	label var sd_prcp "SD of precipitation between 2002-2011 in the location"
	
gen prcp_div = (pavg_year - mean_prcp)/sd_prcp 
	label var prcp_div "Precipitation anomalies from decadal mean (2002-2011) in the location"

	
*** Create lagged variables

sort habitable_id year 
distinct habitable_id //4107 households
isid habitable_id year // yes

//Set time variable
xtset habitable_id year, yearly

//Lagged variables
gen lag_temp_div = L.temp_div
label var lag_temp_div "Temperature anomalies lagged by one year"

gen lag2_temp_div = L2.temp_div
label var lag2_temp_div "Temperature anomalies lagged by two years"

gen lag_prcp_div = L.prcp_div
label var lag_prcp_div "Precipitation anomalies lagged by one year"

gen lag2_prcp_div = L2.prcp_div
label var lag2_prcp_div "Precipitation anomalies lagged by two years"

gen lag_SPEI12 = L.SPEI12_year
label var lag_SPEI12 "SPEI12 lagged by one year"

gen lag2_SPEI12 = L2.SPEI12_year
label var lag2_SPEI12 "SPEI12 lagged by two years"

xtset, clear

keep habitable_id year country region temp_div prcp_div lag_temp_div lag2_temp_div mean_temp sd_temp lag_prcp_div lag2_prcp_div SPEI12_year lag_SPEI12 lag2_SPEI12
sort country region habitable_id year

save "$OUTPUT\All_climate_annual.dta", replace
