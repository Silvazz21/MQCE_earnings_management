
clear

** Clear data in memory


capture log	close 

log using "/Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD/results.txt", text replace 
set	more off


** Define working directory

cd "/Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD"

** Import database as .csv and save as .dta file

** import delimited "/Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD/BD_final.csv"

** save "/Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD/BD_final.dta" file /Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD/BD_final.dta saved


** Open database

use "/Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD/BD_final.dta" , clear


** Label database

label data "Database of financial information from listed firms in Europe for 2022, available in Orbis BvD."


** Filtering database to contain only firms with the Nace Rev2 code 2120 - Manufacture of pharmaceutical preparations

keep if nace_rev_2 == 2120

** Removing rows with missing values in each variable

foreach var of varlist * {
    drop if missing(`var')
}

** Generating index variable

gen obs = _n

label variable obs "Observations"


** Generating variables in millions of euros for visualization

gen total_assets_eur_2022_M = total_assets_eur_2022/1000000

label variable total_assets_eur_2022_M "Total assets in millions of euros"

gen total_revenues_eur_2022_M = total_revenues_eur_2022/1000000

label variable total_revenues_eur_2022_M "Total revenues in millions of euros"

gen pat_eur_20_M = pat_eur_2022/1000000

label variable pat_eur_20_M "Earnings before ex. items in millions of euros"

label variable number_of_employees_2022 "Number of employees"

** Generating scatter plot to visualize variables 

scatter number_of_employees_2022 obs, name(graph1, replace) ///

scatter total_assets_eur_2022_M obs, name(graph2, replace) ///

scatter total_revenues_eur_2022_M obs, name(graph3, replace) ///

scatter pat_eur_20_M obs, name(graph4, replace) /// 
	   
graph combine graph1 graph2 graph3 graph4, col(2)

** Exporting graph 

graph export "/Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD/scatter_1.pdf", as(pdf) name("Graph") replace

histogram number_of_employees_2022, percent name(graph5, replace)

histogram total_assets_eur_2022_M, percent name(graph6, replace)

histogram total_revenues_eur_2022_M, percent name(graph7, replace) ///

histogram pat_eur_20_M, percent name(graph8, replace) /// 
	   
graph combine graph5 graph6 graph7 graph8, col(2)

graph export "/Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD/hist_1.pdf", as(pdf) name("Graph") replace


** Dropping firms with more than 20 000 employees

drop if number_of_employees_2022 > 10000


** Generating the same plot, with firms to be included in the analysis

histogram number_of_employees_2022, percent name(graph9, replace)

histogram total_assets_eur_2022_M, percent name(graph10, replace)

histogram total_revenues_eur_2022_M, percent name(graph11, replace) ///

histogram pat_eur_20_M, percent name(graph12, replace) /// 
	   
graph combine graph9 graph10 graph11 graph12, col(2)

graph export "/Users/ruisilva/Library/CloudStorage/OneDrive-Pessoal/Área de Trabalho/Trabalho_MQ/WD/hist_trimm.pdf", as(pdf) name("Graph") replace


** Create table of descriptive statistics

summarize number_of_employees_2022 total_revenues_eur_2022_M total_assets_eur_2022_M pat_eur_20_M, detail


** Create variables to calculate discretionary accruals and winsorizing at 1% and 99%

** Winsorizing the variables at 1% and 9%

** Install winsor2 package

*** ssc install winsor2

** 1 - Total accruals

gen total_accruals = (pat_eur_2022 - cfo_eur_2022)/total_assets_eur_2021

label variable total_accruals "Total accruals 2022 scaled by total assets"

winsor2 total_accruals, cuts(1 99)

** 2 - Scaled constant

winsor2 total_assets_eur_2021, cuts(1 99)

gen scaled_const = 1/total_assets_eur_2021_w

** 3 - Change in revenue

winsor2 total_revenues_eur_2022, cuts(1 99)

winsor2 total_revenues_eur_2021, cuts(1 99)

gen d_revenue = (total_revenues_eur_2022_w - total_revenues_eur_2021_w)

** 4 - Change in accounts receivable

winsor2 accounts_receivable_eur_2022, cuts(1 99)

winsor2 accounts_receivable_eur_2021, cuts(1 99)

gen d_accounts_receivable = (accounts_receivable_eur_2022_w - accounts_receivable_eur_2021_w)

** 5 - Generate scaled (d_rev - d_ar)

gen scaled_d_rev_d_ar = (d_revenue - d_accounts_receivable)/total_assets_eur_2021_w

** 6 - scaled_PPE

winsor2 ppe_eur_2022, cuts(1 99)

gen scaled_PPE = ppe_eur_2022_w/total_assets_eur_2021_w

** 7 - ROA

winsor2 net_profit_eur_2022, cuts(1 99)

gen ROA = net_profit_eur_2022_w/total_assets_eur_2021_w

** Correlation matrix

correlate total_accruals_w scaled_d_rev_d_ar scaled_PPE ROA

** Running regression

regress total_accruals_w scaled_const scaled_d_rev_d_ar scaled_PPE ROA

** Saving residuals

predict residuals, residuals

scatter residuals obs, name(graph10, replace) ///

** Diagnostics


* 1. Check for Heteroscedasticity

estat hettest
estat imtest, white


* 2. Check for Multicollinearity

estat vif

* 3. Check for Influential Observations

* Calculate Cook's Distance
predict cooksd, cooksd

* Define the number of predictors (including the constant term)
local num_predictors = 5  /* Adjust based on the number of predictors in your model */

* Identify influential observations using Cook's Distance
summarize
gen high_cooksd = cooksd > (4 / (_N - `num_predictors' - 1))
list if high_cooksd

* Calculate leverage values
predict leverage, leverage

* Identify influential observations using leverage values
gen high_leverage = leverage > (2 * (`num_predictors' + 1) / _N)
list if high_leverage

* 4. Check for Normality of Residuals
histogram residuals, normal
qnorm residuals
sktest residuals

* 5. Check for Model Specification Errors
estat ovtest

** Residuals (Discretionary accruals) analysis














