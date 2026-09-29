/*______________________________________________________________________________________
|                                                     									|
|              			Social Tipping Points in Climate Migration                      |
|_______________________________________________________________________________________|*/

* To be run with Stata 19.
* Before running the master do-file, the user should update the following paths:

clear all
set more off

if "`c(username)'" == "mdfg501" {
    global ROOT C:\Users\mdfg501\OneDrive
}
else {
    global ROOT C:\Users\maric\OneDrive
}
global SYNTAX  $ROOT\Documents\Exeter\HABITABLE\WP1\Papers\SocialTippingPoints\Syntax\v2

****************************************************************************************************************************************

do "$SYNTAX/1_Preparation_climate.do"
do "$SYNTAX/2_Preparation_GH.do"
do "$SYNTAX/2_Preparation_MA.do"
do "$SYNTAX/2_Preparation_KE.do"
do "$SYNTAX/2_Preparation_ET.do"
do "$SYNTAX/3_Analysis_GH.do"
do "$SYNTAX/3_Analysis_MA.do"
do "$SYNTAX/3_Analysis_KE.do"
do "$SYNTAX/3_Analysis_ET.do"

clear all