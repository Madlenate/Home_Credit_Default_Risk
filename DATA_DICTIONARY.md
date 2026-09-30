# Home Credit Default Risk: Data Dictionary

Every column in `home_credit.db`, with the official Kaggle description, where it lives in the
database, how much is missing, and what the values actually look like. Generated from the data
(train + test combined for the application tables).

Source: <https://www.kaggle.com/competitions/home-credit-default-risk/data>

## Conventions that apply everywhere

- **`SK_ID_*` columns are IDs** (anonymised / hashed), not numbers to model on.
- **`DAYS_*` are days relative to the current application date**, so they are negative for the past
  (`DAYS_BIRTH = -12000` means about 33 years old). Divide by -365 for years.
- **`MONTHS_BALANCE`** is the month relative to the application: -1 = most recent month, -2 = the one before, and so on.
- **`365243`** in any `DAYS_*` column is a placeholder meaning *no date / not applicable*, not a real value.
- **`AMT_*` are money amounts**, **`CNT_*` are counts**, **`FLAG_*` / `NFLAG_*` / `REG_*` / `LIVE_*` are 0/1 or Y/N indicators**.
- **`XNA` = not available, `XAP` = not applicable** in categorical columns.
- **"normalized"** (in the *Special* notes) means Home Credit rescaled the values before release, so absolute levels are not meaningful.
- **DPD** = days past due. **Annuity** = the regular installment amount.

## Table overview

| Table | One row per... | Rows | Key |
|---|---|---:|---|
| `application` | current loan application | 356,255 | `SK_ID_CURR` |
| `bureau` | Credit Bureau credit (other lenders) | 1,716,428 | `SK_ID_BUREAU` |
| `bureau_balance` | Credit Bureau credit per month | 27,299,925 | `(SK_ID_BUREAU, MONTHS_BALANCE)` |
| `previous_application` | previous Home Credit application | 1,670,214 | `SK_ID_PREV` |
| `pos_cash_balance` | previous POS / cash loan per month | 10,001,358 | `(SK_ID_PREV, MONTHS_BALANCE)` |
| `credit_card_balance` | previous credit card per month | 3,840,312 | `(SK_ID_PREV, MONTHS_BALANCE)` |
| `installments_payments` | installment payment (or missed installment) | 13,605,401 | `id` (surrogate) |

---

## `application`  (source: `application_{train|test}.csv`)

One row per **current** loan application: the loan being scored. Train and test are stored together.

- **Rows:** 356,255
- **Key:** `SK_ID_CURR`
- In the database the columns are split across six 1:1 tables (shown in the *DB table* column); the view `v_application_full` puts them back together in the original layout.

| Column | DB table | Type | Missing | Values / range | Description |
|---|---|---|---:|---|---|
| `SK_ID_CURR` | `application` | integer | 0% | ID | ID of loan in our sample. Primary key of the current application. Joins every table to `application`. |
| `dataset` | `application` | text | 0% | 2 values: train (86%); test (14%) | Added in this database: `train` (from application_train.csv) or `test` (application_test.csv). |
| `TARGET` | `application` | integer | 13.7% | values: 0 (91.9%); 1 (8.1%), train only | **The label to predict.** 1 = client had payment difficulties (late >X days on at least one of the first Y installments), 0 = all other cases. About 8.1% of train rows are 1. NULL for the test set. |
| `NAME_CONTRACT_TYPE` | `application` | text | 0% | 2 values: Cash loans (92%); Revolving loans (8%) | Identification if loan is cash or revolving. |
| `CODE_GENDER` | `applicant_profile` | text | 0% | 3 values: F (66%); M (34%); XNA (<1%) | Gender of the client. Four rows have 'XNA' (unknown). |
| `FLAG_OWN_CAR` | `applicant_profile` | text | 0% | 2 values: N (66%); Y (34%) | Flag if the client owns a car. |
| `FLAG_OWN_REALTY` | `applicant_profile` | text | 0% | 2 values: Y (69%); N (31%) | Flag if client owns a house or flat. |
| `CNT_CHILDREN` | `applicant_profile` | integer | 0% | min 0 / median 0 / max 20 | Number of children the client has. |
| `AMT_INCOME_TOTAL` | `application` | decimal | 0% | min 25,650 / median 153,000 / max 117,000,000 | Income of the client. Heavily right-skewed; the maximum (117,000,000) is an outlier. Consider log-transforming or capping. |
| `AMT_CREDIT` | `application` | decimal | 0% | min 45,000 / median 500,211 / max 4,050,000 | Credit amount of the loan. |
| `AMT_ANNUITY` | `application` | decimal | <0.1% | min 1,616 / median 25,078 / max 258,026 | Loan annuity. |
| `AMT_GOODS_PRICE` | `application` | decimal | 0.1% | min 40,500 / median 450,000 / max 4,050,000 | For consumer loans it is the price of the goods for which the loan is given. |
| `NAME_TYPE_SUITE` | `application` | text | 0.6% | 7 values: Unaccompanied (81%); Family (13%); Spouse, partner (4%); Children (1%); Other_B (1%); Other_A (<1%); Group of people (<1%) | Who was accompanying client when he was applying for the loan. |
| `NAME_INCOME_TYPE` | `applicant_profile` | text | 0% | 8 values: Working (51%); Commercial associate (23%); Pensioner (18%); State servant (7%); Unemployed (<1%); Student (<1%); Businessman (<1%); Maternity leave (<1%) | Clients income type (businessman, working, maternity leave,…). |
| `NAME_EDUCATION_TYPE` | `applicant_profile` | text | 0% | 5 values: Secondary / secondary special (71%); Higher education (25%); Incomplete higher (3%); Lower secondary (1%); Academic degree (<1%) | Level of highest education the client achieved. |
| `NAME_FAMILY_STATUS` | `applicant_profile` | text | 0% | 6 values: Married (64%); Single / not married (15%); Civil marriage (10%); Separated (6%); Widow (5%); Unknown (<1%) | Family status of the client. |
| `NAME_HOUSING_TYPE` | `applicant_profile` | text | 0% | 6 values: House / apartment (89%); With parents (5%); Municipal apartment (4%); Rented apartment (2%); Office apartment (1%); Co-op apartment (<1%) | What is the housing situation of the client (renting, living with parents, ...). |
| `REGION_POPULATION_RELATIVE` | `applicant_profile` | decimal | 0% | min 0.000253 / median 0.01885 / max 0.07251 | Normalized population of region where client lives (higher number means the client lives in more populated region). *[normalized]* |
| `DAYS_BIRTH` | `applicant_profile` | integer | 0% | min -25,229 / median -15,755 / max -7,338 | Client's age in days at the time of application. *[time only relative to the application]* Age in days, negative. Age in years = DAYS_BIRTH / -365. |
| `DAYS_EMPLOYED` | `applicant_profile` | integer | 0% | min -17,912 / median -1,224 / max 365,243 | How many days before the application the person started current employment. *[time only relative to the application]* **Placeholder value:** 365243 (about 1,000 years) appears for 64,648 applicants, exactly the rows with ORGANIZATION_TYPE = 'XNA' (pensioners / unemployed). Treat it as missing, and consider a 'not employed' flag. |
| `DAYS_REGISTRATION` | `applicant_profile` | decimal | 0% | min -24,672 / median -4,502 / max 0 | How many days before the application did client change his registration. *[time only relative to the application]* |
| `DAYS_ID_PUBLISH` | `applicant_profile` | integer | 0% | min -7,197 / median -3,252 / max 0 | How many days before the application did client change the identity document with which he applied for the loan. *[time only relative to the application]* |
| `OWN_CAR_AGE` | `applicant_profile` | decimal | 66.0% | min 0 / median 9 / max 91 | Age of client's car. Missing when the client has no car (FLAG_OWN_CAR = 'N'). |
| `FLAG_MOBIL` | `applicant_profile` | integer | 0% | 0/1 flag; 100.0% are 1 | Did client provide mobile phone (1=YES, 0=NO). |
| `FLAG_EMP_PHONE` | `applicant_profile` | integer | 0% | 0/1 flag; 81.8% are 1 | Did client provide work phone (1=YES, 0=NO). |
| `FLAG_WORK_PHONE` | `applicant_profile` | integer | 0% | 0/1 flag; 20.0% are 1 | Did client provide home phone (1=YES, 0=NO). |
| `FLAG_CONT_MOBILE` | `applicant_profile` | integer | 0% | 0/1 flag; 99.8% are 1 | Was mobile phone reachable (1=YES, 0=NO). |
| `FLAG_PHONE` | `applicant_profile` | integer | 0% | 0/1 flag; 27.9% are 1 | Did client provide home phone (1=YES, 0=NO). |
| `FLAG_EMAIL` | `applicant_profile` | integer | 0% | 0/1 flag; 7.1% are 1 | Did client provide email (1=YES, 0=NO). |
| `OCCUPATION_TYPE` | `applicant_profile` | text | 31.4% | 18 values: Laborers (26%); Sales staff (15%); Core staff (13%); Managers (10%); Drivers (9%); High skill tech staff (5%); Accountants (5%); Medicine staff (4%); Security staff (3%); Cooking staff (3%); Cleaning staff (2%); Private service staff (1%) ... | What kind of occupation does the client have. |
| `CNT_FAM_MEMBERS` | `applicant_profile` | decimal | <0.1% | min 1 / median 2 / max 21 | How many family members does client have. |
| `REGION_RATING_CLIENT` | `applicant_profile` | integer | 0% | values: 1 (11%); 2 (74%); 3 (16%) | Our rating of the region where client lives (1,2,3). |
| `REGION_RATING_CLIENT_W_CITY` | `applicant_profile` | integer | 0% | values: -1 (<1%); 1 (11%); 2 (74%); 3 (14%) | Our rating of the region where client lives with taking city into account (1,2,3). |
| `WEEKDAY_APPR_PROCESS_START` | `application` | text | 0% | 7 values: TUESDAY (18%); WEDNESDAY (17%); MONDAY (17%); THURSDAY (17%); FRIDAY (16%); SATURDAY (11%); SUNDAY (5%) | On which day of the week did the client apply for the loan. |
| `HOUR_APPR_PROCESS_START` | `application` | integer | 0% | min 0 / median 12 / max 23 | Approximately at what hour did the client apply for the loan. *[rounded]* |
| `REG_REGION_NOT_LIVE_REGION` | `applicant_profile` | integer | 0% | 0/1 flag; 1.6% are 1 | Flag if client's permanent address does not match contact address (1=different, 0=same, at region level). |
| `REG_REGION_NOT_WORK_REGION` | `applicant_profile` | integer | 0% | 0/1 flag; 5.1% are 1 | Flag if client's permanent address does not match work address (1=different, 0=same, at region level). |
| `LIVE_REGION_NOT_WORK_REGION` | `applicant_profile` | integer | 0% | 0/1 flag; 4.1% are 1 | Flag if client's contact address does not match work address (1=different, 0=same, at region level). |
| `REG_CITY_NOT_LIVE_CITY` | `applicant_profile` | integer | 0% | 0/1 flag; 7.8% are 1 | Flag if client's permanent address does not match contact address (1=different, 0=same, at city level). |
| `REG_CITY_NOT_WORK_CITY` | `applicant_profile` | integer | 0% | 0/1 flag; 23.0% are 1 | Flag if client's permanent address does not match work address (1=different, 0=same, at city level). |
| `LIVE_CITY_NOT_WORK_CITY` | `applicant_profile` | integer | 0% | 0/1 flag; 17.9% are 1 | Flag if client's contact address does not match work address (1=different, 0=same, at city level). |
| `ORGANIZATION_TYPE` | `applicant_profile` | text | 0% | 58 values: Business Entity Type 3 (22%); XNA (18%); Self-employed (12%); Other (5%); Medicine (4%); Business Entity Type 2 (3%); Government (3%); School (3%); Trade: type 7 (3%); Kindergarten (2%); Construction (2%); Business Entity Type 1 (2%) ... | Type of organization where client works. 'XNA' = no employer (the same rows as DAYS_EMPLOYED = 365243). |
| `EXT_SOURCE_1` | `application` | decimal | 54.4% | min 0.01346 / median 0.5062 / max 0.9627 | Normalized score from external data source. *[normalized]* Anonymised external credit score (0-1, higher = lower risk). The three EXT_SOURCE columns are typically the strongest single predictors of TARGET. |
| `EXT_SOURCE_2` | `application` | decimal | 0.2% | min 8.174e-08 / median 0.5648 / max 0.855 | Normalized score from external data source. *[normalized]* See EXT_SOURCE_1. |
| `EXT_SOURCE_3` | `application` | decimal | 19.5% | min 0.0005273 / median 0.5335 / max 0.896 | Normalized score from external data source. *[normalized]* See EXT_SOURCE_1. |
| `APARTMENTS_AVG` | `applicant_housing` | decimal | 50.5% | min 0 / median 0.088 / max 1 | Building where the client lives: apartment size, average (normalized). *[normalized]* |
| `BASEMENTAREA_AVG` | `applicant_housing` | decimal | 58.3% | min 0 / median 0.0765 / max 1 | Building where the client lives: basement area, average (normalized). *[normalized]* |
| `YEARS_BEGINEXPLUATATION_AVG` | `applicant_housing` | decimal | 48.5% | min 0 / median 0.9816 / max 1 | Building where the client lives: years since the building came into use ('exploitation' = use), average (normalized). *[normalized]* |
| `YEARS_BUILD_AVG` | `applicant_housing` | decimal | 66.3% | min 0 / median 0.7552 / max 1 | Building where the client lives: age of the building, average (normalized). *[normalized]* |
| `COMMONAREA_AVG` | `applicant_housing` | decimal | 69.7% | min 0 / median 0.0213 / max 1 | Building where the client lives: common area, average (normalized). *[normalized]* |
| `ELEVATORS_AVG` | `applicant_housing` | decimal | 53.1% | min 0 / median 0 / max 1 | Building where the client lives: number of elevators, average (normalized). *[normalized]* |
| `ENTRANCES_AVG` | `applicant_housing` | decimal | 50.1% | min 0 / median 0.1379 / max 1 | Building where the client lives: number of entrances, average (normalized). *[normalized]* |
| `FLOORSMAX_AVG` | `applicant_housing` | decimal | 49.5% | min 0 / median 0.1667 / max 1 | Building where the client lives: maximum number of floors, average (normalized). *[normalized]* |
| `FLOORSMIN_AVG` | `applicant_housing` | decimal | 67.7% | min 0 / median 0.2083 / max 1 | Building where the client lives: minimum number of floors, average (normalized). *[normalized]* |
| `LANDAREA_AVG` | `applicant_housing` | decimal | 59.2% | min 0 / median 0.0482 / max 1 | Building where the client lives: land area, average (normalized). *[normalized]* |
| `LIVINGAPARTMENTS_AVG` | `applicant_housing` | decimal | 68.2% | min 0 / median 0.0756 / max 1 | Building where the client lives: living apartments, average (normalized). *[normalized]* |
| `LIVINGAREA_AVG` | `applicant_housing` | decimal | 49.9% | min 0 / median 0.0749 / max 1 | Building where the client lives: living area, average (normalized). *[normalized]* |
| `NONLIVINGAPARTMENTS_AVG` | `applicant_housing` | decimal | 69.3% | min 0 / median 0 / max 1 | Building where the client lives: non-living apartments, average (normalized). *[normalized]* |
| `NONLIVINGAREA_AVG` | `applicant_housing` | decimal | 55.0% | min 0 / median 0.0036 / max 1 | Building where the client lives: non-living area, average (normalized). *[normalized]* |
| `APARTMENTS_MODE` | `applicant_housing` | decimal | 50.5% | min 0 / median 0.084 / max 1 | Building where the client lives: apartment size, mode (most common value) (normalized). *[normalized]* |
| `BASEMENTAREA_MODE` | `applicant_housing` | decimal | 58.3% | min 0 / median 0.0749 / max 1 | Building where the client lives: basement area, mode (most common value) (normalized). *[normalized]* |
| `YEARS_BEGINEXPLUATATION_MODE` | `applicant_housing` | decimal | 48.5% | min 0 / median 0.9816 / max 1 | Building where the client lives: years since the building came into use ('exploitation' = use), mode (most common value) (normalized). *[normalized]* |
| `YEARS_BUILD_MODE` | `applicant_housing` | decimal | 66.3% | min 0 / median 0.7648 / max 1 | Building where the client lives: age of the building, mode (most common value) (normalized). *[normalized]* |
| `COMMONAREA_MODE` | `applicant_housing` | decimal | 69.7% | min 0 / median 0.0192 / max 1 | Building where the client lives: common area, mode (most common value) (normalized). *[normalized]* |
| `ELEVATORS_MODE` | `applicant_housing` | decimal | 53.1% | min 0 / median 0 / max 1 | Building where the client lives: number of elevators, mode (most common value) (normalized). *[normalized]* |
| `ENTRANCES_MODE` | `applicant_housing` | decimal | 50.1% | min 0 / median 0.1379 / max 1 | Building where the client lives: number of entrances, mode (most common value) (normalized). *[normalized]* |
| `FLOORSMAX_MODE` | `applicant_housing` | decimal | 49.5% | min 0 / median 0.1667 / max 1 | Building where the client lives: maximum number of floors, mode (most common value) (normalized). *[normalized]* |
| `FLOORSMIN_MODE` | `applicant_housing` | decimal | 67.7% | min 0 / median 0.2083 / max 1 | Building where the client lives: minimum number of floors, mode (most common value) (normalized). *[normalized]* |
| `LANDAREA_MODE` | `applicant_housing` | decimal | 59.2% | min 0 / median 0.0459 / max 1 | Building where the client lives: land area, mode (most common value) (normalized). *[normalized]* |
| `LIVINGAPARTMENTS_MODE` | `applicant_housing` | decimal | 68.2% | min 0 / median 0.0771 / max 1 | Building where the client lives: living apartments, mode (most common value) (normalized). *[normalized]* |
| `LIVINGAREA_MODE` | `applicant_housing` | decimal | 49.9% | min 0 / median 0.0733 / max 1 | Building where the client lives: living area, mode (most common value) (normalized). *[normalized]* |
| `NONLIVINGAPARTMENTS_MODE` | `applicant_housing` | decimal | 69.3% | min 0 / median 0 / max 1 | Building where the client lives: non-living apartments, mode (most common value) (normalized). *[normalized]* |
| `NONLIVINGAREA_MODE` | `applicant_housing` | decimal | 55.0% | min 0 / median 0.0011 / max 1 | Building where the client lives: non-living area, mode (most common value) (normalized). *[normalized]* |
| `APARTMENTS_MEDI` | `applicant_housing` | decimal | 50.5% | min 0 / median 0.0874 / max 1 | Building where the client lives: apartment size, median (normalized). *[normalized]* |
| `BASEMENTAREA_MEDI` | `applicant_housing` | decimal | 58.3% | min 0 / median 0.0761 / max 1 | Building where the client lives: basement area, median (normalized). *[normalized]* |
| `YEARS_BEGINEXPLUATATION_MEDI` | `applicant_housing` | decimal | 48.5% | min 0 / median 0.9816 / max 1 | Building where the client lives: years since the building came into use ('exploitation' = use), median (normalized). *[normalized]* |
| `YEARS_BUILD_MEDI` | `applicant_housing` | decimal | 66.3% | min 0 / median 0.7585 / max 1 | Building where the client lives: age of the building, median (normalized). *[normalized]* |
| `COMMONAREA_MEDI` | `applicant_housing` | decimal | 69.7% | min 0 / median 0.021 / max 1 | Building where the client lives: common area, median (normalized). *[normalized]* |
| `ELEVATORS_MEDI` | `applicant_housing` | decimal | 53.1% | min 0 / median 0 / max 1 | Building where the client lives: number of elevators, median (normalized). *[normalized]* |
| `ENTRANCES_MEDI` | `applicant_housing` | decimal | 50.1% | min 0 / median 0.1379 / max 1 | Building where the client lives: number of entrances, median (normalized). *[normalized]* |
| `FLOORSMAX_MEDI` | `applicant_housing` | decimal | 49.5% | min 0 / median 0.1667 / max 1 | Building where the client lives: maximum number of floors, median (normalized). *[normalized]* |
| `FLOORSMIN_MEDI` | `applicant_housing` | decimal | 67.7% | min 0 / median 0.2083 / max 1 | Building where the client lives: minimum number of floors, median (normalized). *[normalized]* |
| `LANDAREA_MEDI` | `applicant_housing` | decimal | 59.2% | min 0 / median 0.0487 / max 1 | Building where the client lives: land area, median (normalized). *[normalized]* |
| `LIVINGAPARTMENTS_MEDI` | `applicant_housing` | decimal | 68.2% | min 0 / median 0.077 / max 1 | Building where the client lives: living apartments, median (normalized). *[normalized]* |
| `LIVINGAREA_MEDI` | `applicant_housing` | decimal | 49.9% | min 0 / median 0.0754 / max 1 | Building where the client lives: living area, median (normalized). *[normalized]* |
| `NONLIVINGAPARTMENTS_MEDI` | `applicant_housing` | decimal | 69.3% | min 0 / median 0 / max 1 | Building where the client lives: non-living apartments, median (normalized). *[normalized]* |
| `NONLIVINGAREA_MEDI` | `applicant_housing` | decimal | 55.0% | min 0 / median 0.0031 / max 1 | Building where the client lives: non-living area, median (normalized). *[normalized]* |
| `FONDKAPREMONT_MODE` | `applicant_housing` | text | 68.2% | 4 values: reg oper account (76%); reg oper spec account (12%); not specified (6%); org spec account (6%) | Building where the client lives: capital-repair fund type (from Russian 'fond kapremonta'), mode (most common value) (normalized). *[normalized]* |
| `HOUSETYPE_MODE` | `applicant_housing` | text | 49.9% | 3 values: block of flats (98%); specific housing (1%); terraced house (1%) | Building where the client lives: house type, mode (most common value) (normalized). *[normalized]* |
| `TOTALAREA_MODE` | `applicant_housing` | decimal | 48.0% | min 0 / median 0.069 / max 1 | Building where the client lives: total area, mode (most common value) (normalized). *[normalized]* |
| `WALLSMATERIAL_MODE` | `applicant_housing` | text | 50.6% | 7 values: Panel (44%); Stone, brick (43%); Block (6%); Wooden (3%); Mixed (2%); Monolithic (1%); Others (1%) | Building where the client lives: wall material, mode (most common value) (normalized). *[normalized]* |
| `EMERGENCYSTATE_MODE` | `applicant_housing` | text | 47.1% | 2 values: No (99%); Yes (1%) | Building where the client lives: whether the building is in emergency state, mode (most common value) (normalized). *[normalized]* |
| `OBS_30_CNT_SOCIAL_CIRCLE` | `applicant_social_circle` | decimal | 0.3% | min 0 / median 0 / max 354 | How many observation of client's social surroundings with observable 30 DPD (days past due) default. |
| `DEF_30_CNT_SOCIAL_CIRCLE` | `applicant_social_circle` | decimal | 0.3% | values: 0 (89%); 1 (9%); 2 (2%); 3 (<1%); 4 (<1%); 5 (<1%); 6 (<1%); 7 (<1%); 8 (<1%); 34 (<1%) | How many observation of client's social surroundings defaulted on 30 DPD (days past due). |
| `OBS_60_CNT_SOCIAL_CIRCLE` | `applicant_social_circle` | decimal | 0.3% | min 0 / median 0 / max 351 | How many observation of client's social surroundings with observable 60 DPD (days past due) default. |
| `DEF_60_CNT_SOCIAL_CIRCLE` | `applicant_social_circle` | decimal | 0.3% | values: 0 (92%); 1 (7%); 2 (1%); 3 (<1%); 4 (<1%); 5 (<1%); 6 (<1%); 7 (<1%); 24 (<1%) | How many observation of client's social surroundings defaulted on 60 (days past due) DPD. |
| `DAYS_LAST_PHONE_CHANGE` | `applicant_profile` | decimal | <0.1% | min -4,361 / median -771 / max 0 | How many days before application did client change phone. |
| `FLAG_DOCUMENT_2` | `application_documents` | integer | 0% | 0/1 flag; 0.0% are 1 | Did client provide document 2. |
| `FLAG_DOCUMENT_3` | `application_documents` | integer | 0% | 0/1 flag; 72.1% are 1 | Did client provide document 3. |
| `FLAG_DOCUMENT_4` | `application_documents` | integer | 0% | 0/1 flag; 0.0% are 1 | Did client provide document 4. |
| `FLAG_DOCUMENT_5` | `application_documents` | integer | 0% | 0/1 flag; 1.5% are 1 | Did client provide document 5. |
| `FLAG_DOCUMENT_6` | `application_documents` | integer | 0% | 0/1 flag; 8.8% are 1 | Did client provide document 6. |
| `FLAG_DOCUMENT_7` | `application_documents` | integer | 0% | 0/1 flag; 0.0% are 1 | Did client provide document 7. |
| `FLAG_DOCUMENT_8` | `application_documents` | integer | 0% | 0/1 flag; 8.2% are 1 | Did client provide document 8. |
| `FLAG_DOCUMENT_9` | `application_documents` | integer | 0% | 0/1 flag; 0.4% are 1 | Did client provide document 9. |
| `FLAG_DOCUMENT_10` | `application_documents` | integer | 0% | 0/1 flag; 0.0% are 1 | Did client provide document 10. |
| `FLAG_DOCUMENT_11` | `application_documents` | integer | 0% | 0/1 flag; 0.4% are 1 | Did client provide document 11. |
| `FLAG_DOCUMENT_12` | `application_documents` | integer | 0% | 0/1 flag; 0.0% are 1 | Did client provide document 12. |
| `FLAG_DOCUMENT_13` | `application_documents` | integer | 0% | 0/1 flag; 0.3% are 1 | Did client provide document 13. |
| `FLAG_DOCUMENT_14` | `application_documents` | integer | 0% | 0/1 flag; 0.3% are 1 | Did client provide document 14. |
| `FLAG_DOCUMENT_15` | `application_documents` | integer | 0% | 0/1 flag; 0.1% are 1 | Did client provide document 15. |
| `FLAG_DOCUMENT_16` | `application_documents` | integer | 0% | 0/1 flag; 0.9% are 1 | Did client provide document 16. |
| `FLAG_DOCUMENT_17` | `application_documents` | integer | 0% | 0/1 flag; 0.0% are 1 | Did client provide document 17. |
| `FLAG_DOCUMENT_18` | `application_documents` | integer | 0% | 0/1 flag; 0.7% are 1 | Did client provide document 18. |
| `FLAG_DOCUMENT_19` | `application_documents` | integer | 0% | 0/1 flag; 0.1% are 1 | Did client provide document 19. |
| `FLAG_DOCUMENT_20` | `application_documents` | integer | 0% | 0/1 flag; 0.0% are 1 | Did client provide document 20. |
| `FLAG_DOCUMENT_21` | `application_documents` | integer | 0% | 0/1 flag; 0.0% are 1 | Did client provide document 21. |
| `AMT_REQ_CREDIT_BUREAU_HOUR` | `applicant_bureau_enquiries` | decimal | 13.4% | values: 0 (99%); 1 (1%); 2 (<1%); 3 (<1%); 4 (<1%) | Number of enquiries to Credit Bureau about the client one hour before application. |
| `AMT_REQ_CREDIT_BUREAU_DAY` | `applicant_bureau_enquiries` | decimal | 13.4% | values: 0 (99%); 1 (<1%); 2 (<1%); 3 (<1%); 4 (<1%); 5 (<1%); 6 (<1%); 8 (<1%); 9 (<1%) | Number of enquiries to Credit Bureau about the client one day before application (excluding one hour before application). |
| `AMT_REQ_CREDIT_BUREAU_WEEK` | `applicant_bureau_enquiries` | decimal | 13.4% | values: 0 (97%); 1 (3%); 2 (<1%); 3 (<1%); 4 (<1%); 5 (<1%); 6 (<1%); 7 (<1%); 8 (<1%) | Number of enquiries to Credit Bureau about the client one week before application (excluding one day before application). |
| `AMT_REQ_CREDIT_BUREAU_MON` | `applicant_bureau_enquiries` | decimal | 13.4% | min 0 / median 0 / max 27 | Number of enquiries to Credit Bureau about the client one month before application (excluding one week before application). |
| `AMT_REQ_CREDIT_BUREAU_QRT` | `applicant_bureau_enquiries` | decimal | 13.4% | values: 0 (77%); 1 (16%); 2 (6%); 3 (1%); 4 (<1%); 5 (<1%); 6 (<1%); 7 (<1%); 8 (<1%); 19 (<1%); 261 (<1%) | Number of enquiries to Credit Bureau about the client 3 month before application (excluding one month before application). |
| `AMT_REQ_CREDIT_BUREAU_YEAR` | `applicant_bureau_enquiries` | decimal | 13.4% | min 0 / median 1 / max 25 | Number of enquiries to Credit Bureau about the client one day year (excluding last 3 months before application). |

---

## `bureau`  (source: `bureau.csv`)

All of the client's previous credits at **other** financial institutions, as reported to the Credit Bureau. One row per credit; a client can have many.

- **Rows:** 1,716,428
- **Key:** `SK_ID_BUREAU`; joins to `application` on `SK_ID_CURR`

| Column | Type | Missing | Values / range | Description |
|---|---|---:|---|---|
| `SK_ID_CURR` | integer | 0% | ID | ID of loan in our sample - one loan in our sample can have 0,1,2 or more related previous credits in credit bureau. *[hashed]* Primary key of the current application. Joins every table to `application`. |
| `SK_ID_BUREAU` | integer | 0% | ID | Recoded ID of previous Credit Bureau credit related to our loan (unique coding for each loan application). *[hashed]* Primary key of a Credit Bureau credit. Joins bureau to bureau_balance (3.1M bureau_balance rows have no matching bureau row). |
| `CREDIT_ACTIVE` | text | 0% | 4 values: Closed (63%); Active (37%); Sold (<1%); Bad debt (<1%) | Status of the Credit Bureau (CB) reported credits. |
| `CREDIT_CURRENCY` | text | 0% | 4 values: currency 1 (100%); currency 2 (<1%); currency 3 (<1%); currency 4 (<1%) | Recoded currency of the Credit Bureau credit. *[recoded]* Anonymised; 99.9% is 'currency 1'. |
| `DAYS_CREDIT` | integer | 0% | min -2,922 / median -987 / max 0 | How many days before current application did client apply for Credit Bureau credit. *[time only relative to the application]* |
| `CREDIT_DAY_OVERDUE` | integer | 0% | min 0 / median 0 / max 2,792 | Number of days past due on CB credit at the time of application for related loan in our sample. |
| `DAYS_CREDIT_ENDDATE` | decimal | 6.1% | min -42,060 / median -330 / max 31,199 | Remaining duration of CB credit (in days) at the time of application in Home Credit. *[time only relative to the application]* Positive = credit ends in the future. Contains implausible extremes (about -42,000 days). |
| `DAYS_ENDDATE_FACT` | decimal | 36.9% | min -42,023 / median -897 / max 0 | Days since CB credit ended at the time of application in Home Credit (only for closed credit). *[time only relative to the application]* |
| `AMT_CREDIT_MAX_OVERDUE` | decimal | 65.5% | min 0 / median 0 / max 115,987,185 | Maximal amount overdue on the Credit Bureau credit so far (at application date of loan in our sample). |
| `CNT_CREDIT_PROLONG` | integer | 0% | values: 0 (99%); 1 (<1%); 2 (<1%); 3 (<1%); 4 (<1%); 5 (<1%); 6 (<1%); 7 (<1%); 8 (<1%); 9 (<1%) | How many times was the Credit Bureau credit prolonged. |
| `AMT_CREDIT_SUM` | decimal | <0.1% | min 0 / median 125,518 / max 585,000,000 | Current credit amount for the Credit Bureau credit. |
| `AMT_CREDIT_SUM_DEBT` | decimal | 15.0% | min -4,705,600 / median 0 / max 170,100,000 | Current debt on Credit Bureau credit. |
| `AMT_CREDIT_SUM_LIMIT` | decimal | 34.5% | min -586,406 / median 0 / max 4,705,600 | Current credit limit of credit card reported in Credit Bureau. |
| `AMT_CREDIT_SUM_OVERDUE` | decimal | 0% | min 0 / median 0 / max 3,756,681 | Current amount overdue on Credit Bureau credit. |
| `CREDIT_TYPE` | text | 0% | 15 values: Consumer credit (73%); Credit card (23%); Car loan (2%); Mortgage (1%); Microloan (1%); Loan for business development (<1%); Another type of loan (<1%); Unknown type of loan (<1%); Loan for working capital replenishment (<1%); Cash loan (non-earmarked) (<1%); Real estate loan (<1%); Loan for the purchase of equipment (<1%) ... | Type of Credit Bureau credit (Car, cash,...). |
| `DAYS_CREDIT_UPDATE` | integer | 0% | min -41,947 / median -395 / max 372 | How many days before loan application did last information about the Credit Bureau credit come. *[time only relative to the application]* |
| `AMT_ANNUITY` | decimal | 71.5% | min 0 / median 0 / max 118,453,424 | Annuity of the Credit Bureau credit. |

---

## `bureau_balance`  (source: `bureau_balance.csv`)

Monthly history of each Credit Bureau credit. One row per credit per month.

- **Rows:** 27,299,925
- **Key:** `(SK_ID_BUREAU, MONTHS_BALANCE)`; joins to `bureau` on `SK_ID_BUREAU`

| Column | Type | Missing | Values / range | Description |
|---|---|---:|---|---|
| `SK_ID_BUREAU` | integer | 0% | ID | Recoded ID of Credit Bureau credit (unique coding for each application) - use this to join to CREDIT_BUREAU table. *[hashed]* Primary key of a Credit Bureau credit. Joins bureau to bureau_balance (3.1M bureau_balance rows have no matching bureau row). |
| `MONTHS_BALANCE` | integer | 0% | min -96 / median -25 / max 0 | Month of balance relative to application date (-1 means the freshest balance date). *[time only relative to the application]* |
| `STATUS` | text | 0% | 8 values: C (50%); 0 (27%); X (21%); 1 (1%); 5 (<1%); 2 (<1%); 3 (<1%); 4 (<1%) | 0 = no days past due (DPD); 1 = 1-30 DPD; 2 = 31-60; 3 = 61-90; 4 = 91-120; 5 = 120+ DPD or sold / written off; C = closed; X = status unknown. |

---

## `previous_application`  (source: `previous_application.csv`)

All **previous Home Credit** applications of clients who have a current application. One row per previous application.

- **Rows:** 1,670,214
- **Key:** `SK_ID_PREV`; joins to `application` on `SK_ID_CURR`
- Categorical values 'XNA' = not available and 'XAP' = not applicable.

| Column | Type | Missing | Values / range | Description |
|---|---|---:|---|---|
| `SK_ID_PREV` | integer | 0% | ID | ID of previous credit in Home credit related to loan in our sample. (One loan in our sample can have 0,1,2 or more previous loan applications in Home Credit, previous application could, but not necessarily have to lead to credit). *[hashed]* ID of a previous Home Credit loan. Joins previous_application to pos_cash_balance, credit_card_balance and installments_payments (some IDs in those tables have no previous_application row). |
| `SK_ID_CURR` | integer | 0% | ID | ID of loan in our sample. *[hashed]* Primary key of the current application. Joins every table to `application`. |
| `NAME_CONTRACT_TYPE` | text | 0% | 4 values: Cash loans (45%); Consumer loans (44%); Revolving loans (12%); XNA (<1%) | Contract product type (Cash loan, consumer loan [POS] ,...) of the previous application. |
| `AMT_ANNUITY` | decimal | 22.3% | min 0 / median 11,250 / max 418,058 | Annuity of previous application. |
| `AMT_APPLICATION` | decimal | 0% | min 0 / median 71,046 / max 6,905,160 | For how much credit did client ask on the previous application. |
| `AMT_CREDIT` | decimal | <0.1% | min 0 / median 80,541 / max 6,905,160 | Final credit amount on the previous application. This differs from AMT_APPLICATION in a way that the AMT_APPLICATION is the amount for which the client initially applied for, but during our approval process he could have received different amount - AMT_CREDIT. 0 for 336,768 rows (mostly refused / cancelled applications). |
| `AMT_DOWN_PAYMENT` | decimal | 53.6% | min -0.9 / median 1,638 / max 3,060,045 | Down payment on the previous application. |
| `AMT_GOODS_PRICE` | decimal | 23.1% | min 0 / median 112,320 / max 6,905,160 | Goods price of good that client asked for (if applicable) on the previous application. |
| `WEEKDAY_APPR_PROCESS_START` | text | 0% | 7 values: TUESDAY (15%); WEDNESDAY (15%); MONDAY (15%); FRIDAY (15%); THURSDAY (15%); SATURDAY (14%); SUNDAY (10%) | On which day of the week did the client apply for previous application. |
| `HOUR_APPR_PROCESS_START` | integer | 0% | min 0 / median 12 / max 23 | Approximately at what day hour did the client apply for the previous application. *[rounded]* |
| `FLAG_LAST_APPL_PER_CONTRACT` | text | 0% | 2 values: Y (99%); N (1%) | Flag if it was last application for the previous contract. Sometimes by mistake of client or our clerk there could be more applications for one single contract. |
| `NFLAG_LAST_APPL_IN_DAY` | integer | 0% | 0/1 flag; 99.6% are 1 | Flag if the application was the last application per day of the client. Sometimes clients apply for more applications a day. Rarely it could also be error in our system that one application is in the database twice. |
| `RATE_DOWN_PAYMENT` | decimal | 53.6% | min -1.498e-05 / median 0.05161 / max 1 | Down payment rate normalized on previous credit. *[normalized]* |
| `RATE_INTEREST_PRIMARY` | decimal | 99.6% | min 0.03478 / median 0.1891 / max 1 | Interest rate normalized on previous credit. *[normalized]* |
| `RATE_INTEREST_PRIVILEGED` | decimal | 99.6% | min 0.3732 / median 0.8351 / max 1 | Interest rate normalized on previous credit. *[normalized]* |
| `NAME_CASH_LOAN_PURPOSE` | text | 0% | 25 values: XAP (55%); XNA (41%); Repairs (1%); Other (1%); Urgent needs (1%); Buying a used car (<1%); Building a house or an annex (<1%); Everyday expenses (<1%); Medicine (<1%); Payments on other loans (<1%); Education (<1%); Journey (<1%) ... | Purpose of the cash loan. |
| `NAME_CONTRACT_STATUS` | text | 0% | 4 values: Approved (62%); Canceled (19%); Refused (17%); Unused offer (2%) | Contract status (approved, cancelled, ...) of previous application. Outcome of the previous application: Approved, Refused, Canceled, or Unused offer. |
| `DAYS_DECISION` | integer | 0% | min -2,922 / median -581 / max -1 | Relative to current application when was the decision about previous application made. *[time only relative to the application]* |
| `NAME_PAYMENT_TYPE` | text | 0% | 4 values: Cash through the bank (62%); XNA (38%); Non-cash from your account (<1%); Cashless from the account of the employer (<1%) | Payment method that client chose to pay for the previous application. |
| `CODE_REJECT_REASON` | text | 0% | 9 values: XAP (81%); HC (10%); LIMIT (3%); SCO (2%); CLIENT (2%); SCOFR (1%); XNA (<1%); VERIF (<1%); SYSTEM (<1%) | Why was the previous application rejected. |
| `NAME_TYPE_SUITE` | text | 49.1% | 7 values: Unaccompanied (60%); Family (25%); Spouse, partner (8%); Children (4%); Other_B (2%); Other_A (1%); Group of people (<1%) | Who accompanied client when applying for the previous application. |
| `NAME_CLIENT_TYPE` | text | 0% | 4 values: Repeater (74%); New (18%); Refreshed (8%); XNA (<1%) | Was the client old or new client when applying for the previous application. |
| `NAME_GOODS_CATEGORY` | text | 0% | 28 values: XNA (57%); Mobile (13%); Consumer Electronics (7%); Computers (6%); Audio/Video (6%); Furniture (3%); Photo / Cinema Equipment (1%); Construction Materials (1%); Clothing and Accessories (1%); Auto Accessories (<1%); Jewelry (<1%); Homewares (<1%) ... | What kind of goods did the client apply for in the previous application. |
| `NAME_PORTFOLIO` | text | 0% | 5 values: POS (41%); Cash (28%); XNA (22%); Cards (9%); Cars (<1%) | Was the previous application for CASH, POS, CAR, …. |
| `NAME_PRODUCT_TYPE` | text | 0% | 3 values: XNA (64%); x-sell (27%); walk-in (9%) | Was the previous application x-sell o walk-in. |
| `CHANNEL_TYPE` | text | 0% | 8 values: Credit and cash offices (43%); Country-wide (30%); Stone (13%); Regional / Local (6%); Contact center (4%); AP+ (Cash loan) (3%); Channel of corporate sales (<1%); Car dealer (<1%) | Through which channel we acquired the client on the previous application. |
| `SELLERPLACE_AREA` | integer | 0% | min -1 / median 3 / max 4,000,000 | Selling area of seller place of the previous application. -1 appears to mean unknown (762,675 rows). |
| `NAME_SELLER_INDUSTRY` | text | 0% | 11 values: XNA (51%); Consumer electronics (24%); Connectivity (17%); Furniture (3%); Construction (2%); Clothing (1%); Industry (1%); Auto technology (<1%); Jewelry (<1%); MLM partners (<1%); Tourism (<1%) | The industry of the seller. |
| `CNT_PAYMENT` | decimal | 22.3% | min 0 / median 12 / max 84 | Term of previous credit at application of the previous application. |
| `NAME_YIELD_GROUP` | text | 0% | 5 values: XNA (31%); middle (23%); high (21%); low_normal (19%); low_action (6%) | Grouped interest rate into small medium and high of the previous application. *[grouped]* |
| `PRODUCT_COMBINATION` | text | <0.1% | 17 values: Cash (17%); POS household with interest (16%); POS mobile with interest (13%); Cash X-Sell: middle (9%); Cash X-Sell: low (8%); Card Street (7%); POS industry with interest (6%); POS household without interest (5%); Card X-Sell (5%); Cash Street: high (4%); Cash X-Sell: high (4%); Cash Street: middle (2%) ... | Detailed product combination of the previous application. |
| `DAYS_FIRST_DRAWING` | decimal | 40.3% | min -2,922 / median 365,243 / max 365,243 | Relative to application date of current application when was the first disbursement of the previous application. *[time only relative to the application]* **Placeholder value:** 365243 = no date / not applicable; true for 934,444 of 997,149 non-null values. |
| `DAYS_FIRST_DUE` | decimal | 40.3% | min -2,892 / median -831 / max 365,243 | Relative to application date of current application when was the first due supposed to be of the previous application. *[time only relative to the application]* **Placeholder value:** 365243 = no date (40,645 rows). |
| `DAYS_LAST_DUE_1ST_VERSION` | decimal | 40.3% | min -2,801 / median -361 / max 365,243 | Relative to application date of current application when was the first due of the previous application. *[time only relative to the application]* **Placeholder value:** 365243 = no date (93,864 rows). |
| `DAYS_LAST_DUE` | decimal | 40.3% | min -2,889 / median -537 / max 365,243 | Relative to application date of current application when was the last due date of the previous application. *[time only relative to the application]* **Placeholder value:** 365243 = no date (211,221 rows). |
| `DAYS_TERMINATION` | decimal | 40.3% | min -2,874 / median -499 / max 365,243 | Relative to application date of current application when was the expected termination of the previous application. *[time only relative to the application]* **Placeholder value:** 365243 = no date / not yet terminated (225,913 rows). |
| `NFLAG_INSURED_ON_APPROVAL` | decimal | 40.3% | 0/1 flag; 33.3% are 1 | Did the client requested insurance during the previous application. |

---

## `pos_cash_balance`  (source: `POS_CASH_balance.csv`)

Monthly snapshots of previous POS (point-of-sale, i.e. store financing) and cash loans at Home Credit.

- **Rows:** 10,001,358
- **Key:** `(SK_ID_PREV, MONTHS_BALANCE)`; joins on `SK_ID_PREV` / `SK_ID_CURR`

| Column | Type | Missing | Values / range | Description |
|---|---|---:|---|---|
| `SK_ID_PREV` | integer | 0% | ID | ID of previous credit in Home Credit related to loan in our sample. (One loan in our sample can have 0,1,2 or more previous loans in Home Credit). ID of a previous Home Credit loan. Joins previous_application to pos_cash_balance, credit_card_balance and installments_payments (some IDs in those tables have no previous_application row). |
| `SK_ID_CURR` | integer | 0% | ID | ID of loan in our sample. Primary key of the current application. Joins every table to `application`. |
| `MONTHS_BALANCE` | integer | 0% | min -96 / median -28 / max -1 | Month of balance relative to application date (-1 means the information to the freshest monthly snapshot, 0 means the information at application - often it will be the same as -1 as many banks are not updating the information to Credit Bureau regularly ). *[time only relative to the application]* |
| `CNT_INSTALMENT` | decimal | 0.3% | min 1 / median 12 / max 92 | Term of previous credit (can change over time). |
| `CNT_INSTALMENT_FUTURE` | decimal | 0.3% | min 0 / median 7 / max 85 | Installments left to pay on the previous credit. |
| `NAME_CONTRACT_STATUS` | text | 0% | 9 values: Active (91%); Completed (7%); Signed (1%); Demand (<1%); Returned to the store (<1%); Approved (<1%); Amortized debt (<1%); Canceled (<1%); XNA (<1%) | Contract status during the month. |
| `SK_DPD` | integer | 0% | min 0 / median 0 / max 4,231 | DPD (days past due) during the month of previous credit. |
| `SK_DPD_DEF` | integer | 0% | min 0 / median 0 / max 3,595 | DPD during the month with tolerance (debts with low loan amounts are ignored) of the previous credit. |

---

## `credit_card_balance`  (source: `credit_card_balance.csv`)

Monthly snapshots of previous Home Credit credit cards.

- **Rows:** 3,840,312
- **Key:** `(SK_ID_PREV, MONTHS_BALANCE)`; joins on `SK_ID_PREV` / `SK_ID_CURR`

| Column | Type | Missing | Values / range | Description |
|---|---|---:|---|---|
| `SK_ID_PREV` | integer | 0% | ID | ID of previous credit in Home credit related to loan in our sample. (One loan in our sample can have 0,1,2 or more previous loans in Home Credit). *[hashed]* ID of a previous Home Credit loan. Joins previous_application to pos_cash_balance, credit_card_balance and installments_payments (some IDs in those tables have no previous_application row). |
| `SK_ID_CURR` | integer | 0% | ID | ID of loan in our sample. *[hashed]* Primary key of the current application. Joins every table to `application`. |
| `MONTHS_BALANCE` | integer | 0% | min -96 / median -28 / max -1 | Month of balance relative to application date (-1 means the freshest balance date). *[time only relative to the application]* |
| `AMT_BALANCE` | decimal | 0% | min -420,250 / median 0 / max 1,505,902 | Balance during the month of previous credit. |
| `AMT_CREDIT_LIMIT_ACTUAL` | integer | 0% | min 0 / median 112,500 / max 1,350,000 | Credit card limit during the month of the previous credit. |
| `AMT_DRAWINGS_ATM_CURRENT` | decimal | 19.5% | min -6,827 / median 0 / max 2,115,000 | Amount drawing at ATM during the month of the previous credit. |
| `AMT_DRAWINGS_CURRENT` | decimal | 0% | min -6,212 / median 0 / max 2,287,098 | Amount drawing during the month of the previous credit. |
| `AMT_DRAWINGS_OTHER_CURRENT` | decimal | 19.5% | min 0 / median 0 / max 1,529,847 | Amount of other drawings during the month of the previous credit. |
| `AMT_DRAWINGS_POS_CURRENT` | decimal | 19.5% | min 0 / median 0 / max 2,239,274 | Amount drawing or buying goods during the month of the previous credit. |
| `AMT_INST_MIN_REGULARITY` | decimal | 7.9% | min 0 / median 0 / max 202,882 | Minimal installment for this month of the previous credit. |
| `AMT_PAYMENT_CURRENT` | decimal | 20.0% | min 0 / median 2,703 / max 4,289,207 | How much did the client pay during the month on the previous credit. |
| `AMT_PAYMENT_TOTAL_CURRENT` | decimal | 0% | min 0 / median 0 / max 4,278,316 | How much did the client pay during the month in total on the previous credit. |
| `AMT_RECEIVABLE_PRINCIPAL` | decimal | 0% | min -423,306 / median 0 / max 1,472,317 | Amount receivable for principal on the previous credit. |
| `AMT_RECIVABLE` | decimal | 0% | min -420,250 / median 0 / max 1,493,338 | Amount receivable on the previous credit. |
| `AMT_TOTAL_RECEIVABLE` | decimal | 0% | min -420,250 / median 0 / max 1,493,338 | Total amount receivable on the previous credit. |
| `CNT_DRAWINGS_ATM_CURRENT` | decimal | 19.5% | min 0 / median 0 / max 51 | Number of drawings at ATM during this month on the previous credit. |
| `CNT_DRAWINGS_CURRENT` | integer | 0% | min 0 / median 0 / max 165 | Number of drawings during this month on the previous credit. |
| `CNT_DRAWINGS_OTHER_CURRENT` | decimal | 19.5% | values: 0 (100%); 1 (<1%); 2 (<1%); 3 (<1%); 4 (<1%); 5 (<1%); 6 (<1%); 7 (<1%); 8 (<1%); 10 (<1%); 12 (<1%) | Number of other drawings during this month on the previous credit. |
| `CNT_DRAWINGS_POS_CURRENT` | decimal | 19.5% | min 0 / median 0 / max 165 | Number of drawings for goods during this month on the previous credit. |
| `CNT_INSTALMENT_MATURE_CUM` | decimal | 7.9% | min 0 / median 15 / max 120 | Number of paid installments on the previous credit. |
| `NAME_CONTRACT_STATUS` | text | 0% | 7 values: Active (96%); Completed (3%); Signed (<1%); Demand (<1%); Sent proposal (<1%); Refused (<1%); Approved (<1%) | Contract status (active signed,...) on the previous credit. |
| `SK_DPD` | integer | 0% | min 0 / median 0 / max 3,260 | DPD (Days past due) during the month on the previous credit. |
| `SK_DPD_DEF` | integer | 0% | min 0 / median 0 / max 3,260 | DPD (Days past due) during the month with tolerance (debts with low loan amounts are ignored) of the previous credit. |

---

## `installments_payments`  (source: `installments_payments.csv`)

Repayment history of previous Home Credit loans: one row per payment made, plus one row per missed installment.

- **Rows:** 13,605,401
- **Key:** `id` (surrogate); joins on `SK_ID_PREV` / `SK_ID_CURR`
- Late payment: DAYS_ENTRY_PAYMENT > DAYS_INSTALMENT. Underpayment: AMT_PAYMENT < AMT_INSTALMENT.

| Column | Type | Missing | Values / range | Description |
|---|---|---:|---|---|
| `id` | integer | 0% | 1 ... n | Added in this database: surrogate primary key (the source file has no unique key, because one installment can be paid in several parts). |
| `SK_ID_PREV` | integer | 0% | ID | ID of previous credit in Home credit related to loan in our sample. (One loan in our sample can have 0,1,2 or more previous loans in Home Credit). *[hashed]* ID of a previous Home Credit loan. Joins previous_application to pos_cash_balance, credit_card_balance and installments_payments (some IDs in those tables have no previous_application row). |
| `SK_ID_CURR` | integer | 0% | ID | ID of loan in our sample. *[hashed]* Primary key of the current application. Joins every table to `application`. |
| `NUM_INSTALMENT_VERSION` | decimal | 0% | min 0 / median 1 / max 178 | Version of installment calendar (0 is for credit card) of previous credit. Change of installment version from month to month signifies that some parameter of payment calendar has changed. |
| `NUM_INSTALMENT_NUMBER` | integer | 0% | min 1 / median 8 / max 277 | On which installment we observe payment. |
| `DAYS_INSTALMENT` | decimal | 0% | min -2,922 / median -818 / max -1 | When the installment of previous credit was supposed to be paid (relative to application date of current loan). *[time only relative to the application]* |
| `DAYS_ENTRY_PAYMENT` | decimal | <0.1% | min -4,921 / median -827 / max -1 | When was the installments of previous credit paid actually (relative to application date of current loan). *[time only relative to the application]* |
| `AMT_INSTALMENT` | decimal | 0% | min 0 / median 8,884 / max 3,771,488 | What was the prescribed installment amount of previous credit on this installment. |
| `AMT_PAYMENT` | decimal | <0.1% | min 0 / median 8,126 / max 3,771,488 | What the client actually paid on previous credit on this installment. |
