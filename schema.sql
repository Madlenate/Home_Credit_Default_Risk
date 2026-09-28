-- =====================================================================
-- Home Credit Default Risk -- SQLite schema
-- Source: https://www.kaggle.com/competitions/home-credit-default-risk
--
-- Entity overview
--   application              1 row per current loan application (train + test)
--     |- applicant_profile, applicant_housing, applicant_social_circle,
--     |  application_documents, applicant_bureau_enquiries      (1:1 splits)
--     |- bureau                other institutions' credits (Credit Bureau)
--     |    '- bureau_balance   monthly status per bureau credit
--     |- previous_application  earlier Home Credit applications
--     |- pos_cash_balance      monthly, per previous POS / cash loan
--     |- credit_card_balance   monthly, per previous credit card
--     '- installments_payments one row per installment payment
--
-- Integrity notes (verified against the data when this schema was designed):
--   * Every SK_ID_CURR in every child table exists in application -> FK enforced.
--   * 43,041 SK_ID_BUREAU values in bureau_balance (3.1M rows) have no bureau
--     row, and ~2.7M rows across pos_cash / credit_card / installments point
--     at SK_ID_PREV values absent from previous_application. Those links are
--     indexed but NOT declared as foreign keys so no source rows are dropped.
--   * installments_payments has no natural key (one installment can be paid
--     in several parts), so it gets a surrogate id.
--   * DAYS_* / MONTHS_* are negative offsets relative to the current
--     application date, as in the source data.
-- =====================================================================

PRAGMA foreign_keys = ON;

-- Current application: the loan being scored. TARGET is 1 = payment
-- difficulties, 0 = otherwise, NULL for the Kaggle test set.
CREATE TABLE application (
    SK_ID_CURR  INTEGER PRIMARY KEY,
    dataset     TEXT    NOT NULL CHECK (dataset IN ('train', 'test')),
    TARGET      INTEGER CHECK (TARGET IN (0, 1)),
    NAME_CONTRACT_TYPE          TEXT,
    AMT_INCOME_TOTAL            REAL,
    AMT_CREDIT                  REAL,
    AMT_ANNUITY                 REAL,
    AMT_GOODS_PRICE             REAL,
    NAME_TYPE_SUITE             TEXT,
    WEEKDAY_APPR_PROCESS_START  TEXT,
    HOUR_APPR_PROCESS_START     INTEGER,
    EXT_SOURCE_1                REAL,
    EXT_SOURCE_2                REAL,
    EXT_SOURCE_3                REAL,
    CHECK ((dataset = 'train') = (TARGET IS NOT NULL))
);

-- Demographics, employment, contact flags and region info of the client.
CREATE TABLE applicant_profile (
    SK_ID_CURR  INTEGER PRIMARY KEY REFERENCES application (SK_ID_CURR) ON DELETE CASCADE,
    CODE_GENDER                  TEXT,
    FLAG_OWN_CAR                 TEXT,
    FLAG_OWN_REALTY              TEXT,
    CNT_CHILDREN                 INTEGER,
    NAME_INCOME_TYPE             TEXT,
    NAME_EDUCATION_TYPE          TEXT,
    NAME_FAMILY_STATUS           TEXT,
    NAME_HOUSING_TYPE            TEXT,
    REGION_POPULATION_RELATIVE   REAL,
    DAYS_BIRTH                   INTEGER,
    DAYS_EMPLOYED                INTEGER,
    DAYS_REGISTRATION            REAL,
    DAYS_ID_PUBLISH              INTEGER,
    OWN_CAR_AGE                  REAL,
    FLAG_MOBIL                   INTEGER,
    FLAG_EMP_PHONE               INTEGER,
    FLAG_WORK_PHONE              INTEGER,
    FLAG_CONT_MOBILE             INTEGER,
    FLAG_PHONE                   INTEGER,
    FLAG_EMAIL                   INTEGER,
    OCCUPATION_TYPE              TEXT,
    CNT_FAM_MEMBERS              REAL,
    REGION_RATING_CLIENT         INTEGER,
    REGION_RATING_CLIENT_W_CITY  INTEGER,
    REG_REGION_NOT_LIVE_REGION   INTEGER,
    REG_REGION_NOT_WORK_REGION   INTEGER,
    LIVE_REGION_NOT_WORK_REGION  INTEGER,
    REG_CITY_NOT_LIVE_CITY       INTEGER,
    REG_CITY_NOT_WORK_CITY       INTEGER,
    LIVE_CITY_NOT_WORK_CITY      INTEGER,
    ORGANIZATION_TYPE            TEXT,
    DAYS_LAST_PHONE_CHANGE       REAL
);

-- Normalized statistics about the building the client lives in (AVG / MODE / MEDI).
CREATE TABLE applicant_housing (
    SK_ID_CURR  INTEGER PRIMARY KEY REFERENCES application (SK_ID_CURR) ON DELETE CASCADE,
    APARTMENTS_AVG                REAL,
    BASEMENTAREA_AVG              REAL,
    YEARS_BEGINEXPLUATATION_AVG   REAL,
    YEARS_BUILD_AVG               REAL,
    COMMONAREA_AVG                REAL,
    ELEVATORS_AVG                 REAL,
    ENTRANCES_AVG                 REAL,
    FLOORSMAX_AVG                 REAL,
    FLOORSMIN_AVG                 REAL,
    LANDAREA_AVG                  REAL,
    LIVINGAPARTMENTS_AVG          REAL,
    LIVINGAREA_AVG                REAL,
    NONLIVINGAPARTMENTS_AVG       REAL,
    NONLIVINGAREA_AVG             REAL,
    APARTMENTS_MODE               REAL,
    BASEMENTAREA_MODE             REAL,
    YEARS_BEGINEXPLUATATION_MODE  REAL,
    YEARS_BUILD_MODE              REAL,
    COMMONAREA_MODE               REAL,
    ELEVATORS_MODE                REAL,
    ENTRANCES_MODE                REAL,
    FLOORSMAX_MODE                REAL,
    FLOORSMIN_MODE                REAL,
    LANDAREA_MODE                 REAL,
    LIVINGAPARTMENTS_MODE         REAL,
    LIVINGAREA_MODE               REAL,
    NONLIVINGAPARTMENTS_MODE      REAL,
    NONLIVINGAREA_MODE            REAL,
    APARTMENTS_MEDI               REAL,
    BASEMENTAREA_MEDI             REAL,
    YEARS_BEGINEXPLUATATION_MEDI  REAL,
    YEARS_BUILD_MEDI              REAL,
    COMMONAREA_MEDI               REAL,
    ELEVATORS_MEDI                REAL,
    ENTRANCES_MEDI                REAL,
    FLOORSMAX_MEDI                REAL,
    FLOORSMIN_MEDI                REAL,
    LANDAREA_MEDI                 REAL,
    LIVINGAPARTMENTS_MEDI         REAL,
    LIVINGAREA_MEDI               REAL,
    NONLIVINGAPARTMENTS_MEDI      REAL,
    NONLIVINGAREA_MEDI            REAL,
    FONDKAPREMONT_MODE            TEXT,
    HOUSETYPE_MODE                TEXT,
    TOTALAREA_MODE                REAL,
    WALLSMATERIAL_MODE            TEXT,
    EMERGENCYSTATE_MODE           TEXT
);

-- Observed / defaulted counts in the client's social surroundings (30 and 60 DPD).
CREATE TABLE applicant_social_circle (
    SK_ID_CURR  INTEGER PRIMARY KEY REFERENCES application (SK_ID_CURR) ON DELETE CASCADE,
    OBS_30_CNT_SOCIAL_CIRCLE  REAL,
    DEF_30_CNT_SOCIAL_CIRCLE  REAL,
    OBS_60_CNT_SOCIAL_CIRCLE  REAL,
    DEF_60_CNT_SOCIAL_CIRCLE  REAL
);

-- Whether the client provided document N (1 = yes).
CREATE TABLE application_documents (
    SK_ID_CURR  INTEGER PRIMARY KEY REFERENCES application (SK_ID_CURR) ON DELETE CASCADE,
    FLAG_DOCUMENT_2   INTEGER,
    FLAG_DOCUMENT_3   INTEGER,
    FLAG_DOCUMENT_4   INTEGER,
    FLAG_DOCUMENT_5   INTEGER,
    FLAG_DOCUMENT_6   INTEGER,
    FLAG_DOCUMENT_7   INTEGER,
    FLAG_DOCUMENT_8   INTEGER,
    FLAG_DOCUMENT_9   INTEGER,
    FLAG_DOCUMENT_10  INTEGER,
    FLAG_DOCUMENT_11  INTEGER,
    FLAG_DOCUMENT_12  INTEGER,
    FLAG_DOCUMENT_13  INTEGER,
    FLAG_DOCUMENT_14  INTEGER,
    FLAG_DOCUMENT_15  INTEGER,
    FLAG_DOCUMENT_16  INTEGER,
    FLAG_DOCUMENT_17  INTEGER,
    FLAG_DOCUMENT_18  INTEGER,
    FLAG_DOCUMENT_19  INTEGER,
    FLAG_DOCUMENT_20  INTEGER,
    FLAG_DOCUMENT_21  INTEGER
);

-- Number of Credit Bureau enquiries in each window before the application.
CREATE TABLE applicant_bureau_enquiries (
    SK_ID_CURR  INTEGER PRIMARY KEY REFERENCES application (SK_ID_CURR) ON DELETE CASCADE,
    AMT_REQ_CREDIT_BUREAU_HOUR  REAL,
    AMT_REQ_CREDIT_BUREAU_DAY   REAL,
    AMT_REQ_CREDIT_BUREAU_WEEK  REAL,
    AMT_REQ_CREDIT_BUREAU_MON   REAL,
    AMT_REQ_CREDIT_BUREAU_QRT   REAL,
    AMT_REQ_CREDIT_BUREAU_YEAR  REAL
);

-- Client's previous credits at other institutions, as reported to the Credit Bureau.
CREATE TABLE bureau (
    SK_ID_BUREAU  INTEGER PRIMARY KEY,
    SK_ID_CURR    INTEGER NOT NULL REFERENCES application (SK_ID_CURR),
    CREDIT_ACTIVE           TEXT,
    CREDIT_CURRENCY         TEXT,
    DAYS_CREDIT             INTEGER,
    CREDIT_DAY_OVERDUE      INTEGER,
    DAYS_CREDIT_ENDDATE     REAL,
    DAYS_ENDDATE_FACT       REAL,
    AMT_CREDIT_MAX_OVERDUE  REAL,
    CNT_CREDIT_PROLONG      INTEGER,
    AMT_CREDIT_SUM          REAL,
    AMT_CREDIT_SUM_DEBT     REAL,
    AMT_CREDIT_SUM_LIMIT    REAL,
    AMT_CREDIT_SUM_OVERDUE  REAL,
    CREDIT_TYPE             TEXT,
    DAYS_CREDIT_UPDATE      INTEGER,
    AMT_ANNUITY             REAL
);

-- Monthly status of each Credit Bureau credit. SK_ID_BUREAU is not a declared FK (see header).
CREATE TABLE bureau_balance (
    SK_ID_BUREAU    INTEGER,
    MONTHS_BALANCE  INTEGER,
    STATUS          TEXT,
    PRIMARY KEY (SK_ID_BUREAU, MONTHS_BALANCE)
) WITHOUT ROWID;

-- Previous Home Credit applications of clients who have a current application.
CREATE TABLE previous_application (
    SK_ID_PREV  INTEGER PRIMARY KEY,
    SK_ID_CURR  INTEGER NOT NULL REFERENCES application (SK_ID_CURR),
    NAME_CONTRACT_TYPE           TEXT,
    AMT_ANNUITY                  REAL,
    AMT_APPLICATION              REAL,
    AMT_CREDIT                   REAL,
    AMT_DOWN_PAYMENT             REAL,
    AMT_GOODS_PRICE              REAL,
    WEEKDAY_APPR_PROCESS_START   TEXT,
    HOUR_APPR_PROCESS_START      INTEGER,
    FLAG_LAST_APPL_PER_CONTRACT  TEXT,
    NFLAG_LAST_APPL_IN_DAY       INTEGER,
    RATE_DOWN_PAYMENT            REAL,
    RATE_INTEREST_PRIMARY        REAL,
    RATE_INTEREST_PRIVILEGED     REAL,
    NAME_CASH_LOAN_PURPOSE       TEXT,
    NAME_CONTRACT_STATUS         TEXT,
    DAYS_DECISION                INTEGER,
    NAME_PAYMENT_TYPE            TEXT,
    CODE_REJECT_REASON           TEXT,
    NAME_TYPE_SUITE              TEXT,
    NAME_CLIENT_TYPE             TEXT,
    NAME_GOODS_CATEGORY          TEXT,
    NAME_PORTFOLIO               TEXT,
    NAME_PRODUCT_TYPE            TEXT,
    CHANNEL_TYPE                 TEXT,
    SELLERPLACE_AREA             INTEGER,
    NAME_SELLER_INDUSTRY         TEXT,
    CNT_PAYMENT                  REAL,
    NAME_YIELD_GROUP             TEXT,
    PRODUCT_COMBINATION          TEXT,
    DAYS_FIRST_DRAWING           REAL,
    DAYS_FIRST_DUE               REAL,
    DAYS_LAST_DUE_1ST_VERSION    REAL,
    DAYS_LAST_DUE                REAL,
    DAYS_TERMINATION             REAL,
    NFLAG_INSURED_ON_APPROVAL    REAL
);

-- Monthly snapshots of previous POS (point of sale) and cash loans. SK_ID_PREV is not a declared FK (see header).
CREATE TABLE pos_cash_balance (
    SK_ID_PREV             INTEGER,
    SK_ID_CURR             INTEGER,
    MONTHS_BALANCE         INTEGER,
    CNT_INSTALMENT         REAL,
    CNT_INSTALMENT_FUTURE  REAL,
    NAME_CONTRACT_STATUS   TEXT,
    SK_DPD                 INTEGER,
    SK_DPD_DEF             INTEGER,
    PRIMARY KEY (SK_ID_PREV, MONTHS_BALANCE),
    FOREIGN KEY (SK_ID_CURR) REFERENCES application (SK_ID_CURR)
) WITHOUT ROWID;

-- Monthly snapshots of previous credit cards. SK_ID_PREV is not a declared FK (see header).
CREATE TABLE credit_card_balance (
    SK_ID_PREV                  INTEGER,
    SK_ID_CURR                  INTEGER,
    MONTHS_BALANCE              INTEGER,
    AMT_BALANCE                 REAL,
    AMT_CREDIT_LIMIT_ACTUAL     INTEGER,
    AMT_DRAWINGS_ATM_CURRENT    REAL,
    AMT_DRAWINGS_CURRENT        REAL,
    AMT_DRAWINGS_OTHER_CURRENT  REAL,
    AMT_DRAWINGS_POS_CURRENT    REAL,
    AMT_INST_MIN_REGULARITY     REAL,
    AMT_PAYMENT_CURRENT         REAL,
    AMT_PAYMENT_TOTAL_CURRENT   REAL,
    AMT_RECEIVABLE_PRINCIPAL    REAL,
    AMT_RECIVABLE               REAL,
    AMT_TOTAL_RECEIVABLE        REAL,
    CNT_DRAWINGS_ATM_CURRENT    REAL,
    CNT_DRAWINGS_CURRENT        INTEGER,
    CNT_DRAWINGS_OTHER_CURRENT  REAL,
    CNT_DRAWINGS_POS_CURRENT    REAL,
    CNT_INSTALMENT_MATURE_CUM   REAL,
    NAME_CONTRACT_STATUS        TEXT,
    SK_DPD                      INTEGER,
    SK_DPD_DEF                  INTEGER,
    PRIMARY KEY (SK_ID_PREV, MONTHS_BALANCE),
    FOREIGN KEY (SK_ID_CURR) REFERENCES application (SK_ID_CURR)
) WITHOUT ROWID;

-- Repayment history for previous Home Credit credits: one row per payment.
-- SK_ID_PREV is not a declared FK (see header).
CREATE TABLE installments_payments (
    id  INTEGER PRIMARY KEY,
    SK_ID_PREV              INTEGER,
    SK_ID_CURR              INTEGER,
    NUM_INSTALMENT_VERSION  REAL,
    NUM_INSTALMENT_NUMBER   INTEGER,
    DAYS_INSTALMENT         REAL,
    DAYS_ENTRY_PAYMENT      REAL,
    AMT_INSTALMENT          REAL,
    AMT_PAYMENT             REAL,
    FOREIGN KEY (SK_ID_CURR) REFERENCES application (SK_ID_CURR)
);

-- Data dictionary shipped with the competition (HomeCredit_columns_description.csv).
CREATE TABLE column_description (
    source_table  TEXT NOT NULL,
    column_name   TEXT NOT NULL,
    description   TEXT,
    special       TEXT,
    PRIMARY KEY (source_table, column_name)
);

-- Original application_{train|test}.csv layout in one wide row, for modelling.
CREATE VIEW v_application_full AS
SELECT
    a.SK_ID_CURR,
    a.dataset,
    a.TARGET,
    a.NAME_CONTRACT_TYPE,
    p.CODE_GENDER,
    p.FLAG_OWN_CAR,
    p.FLAG_OWN_REALTY,
    p.CNT_CHILDREN,
    a.AMT_INCOME_TOTAL,
    a.AMT_CREDIT,
    a.AMT_ANNUITY,
    a.AMT_GOODS_PRICE,
    a.NAME_TYPE_SUITE,
    p.NAME_INCOME_TYPE,
    p.NAME_EDUCATION_TYPE,
    p.NAME_FAMILY_STATUS,
    p.NAME_HOUSING_TYPE,
    p.REGION_POPULATION_RELATIVE,
    p.DAYS_BIRTH,
    p.DAYS_EMPLOYED,
    p.DAYS_REGISTRATION,
    p.DAYS_ID_PUBLISH,
    p.OWN_CAR_AGE,
    p.FLAG_MOBIL,
    p.FLAG_EMP_PHONE,
    p.FLAG_WORK_PHONE,
    p.FLAG_CONT_MOBILE,
    p.FLAG_PHONE,
    p.FLAG_EMAIL,
    p.OCCUPATION_TYPE,
    p.CNT_FAM_MEMBERS,
    p.REGION_RATING_CLIENT,
    p.REGION_RATING_CLIENT_W_CITY,
    a.WEEKDAY_APPR_PROCESS_START,
    a.HOUR_APPR_PROCESS_START,
    p.REG_REGION_NOT_LIVE_REGION,
    p.REG_REGION_NOT_WORK_REGION,
    p.LIVE_REGION_NOT_WORK_REGION,
    p.REG_CITY_NOT_LIVE_CITY,
    p.REG_CITY_NOT_WORK_CITY,
    p.LIVE_CITY_NOT_WORK_CITY,
    p.ORGANIZATION_TYPE,
    a.EXT_SOURCE_1,
    a.EXT_SOURCE_2,
    a.EXT_SOURCE_3,
    h.APARTMENTS_AVG,
    h.BASEMENTAREA_AVG,
    h.YEARS_BEGINEXPLUATATION_AVG,
    h.YEARS_BUILD_AVG,
    h.COMMONAREA_AVG,
    h.ELEVATORS_AVG,
    h.ENTRANCES_AVG,
    h.FLOORSMAX_AVG,
    h.FLOORSMIN_AVG,
    h.LANDAREA_AVG,
    h.LIVINGAPARTMENTS_AVG,
    h.LIVINGAREA_AVG,
    h.NONLIVINGAPARTMENTS_AVG,
    h.NONLIVINGAREA_AVG,
    h.APARTMENTS_MODE,
    h.BASEMENTAREA_MODE,
    h.YEARS_BEGINEXPLUATATION_MODE,
    h.YEARS_BUILD_MODE,
    h.COMMONAREA_MODE,
    h.ELEVATORS_MODE,
    h.ENTRANCES_MODE,
    h.FLOORSMAX_MODE,
    h.FLOORSMIN_MODE,
    h.LANDAREA_MODE,
    h.LIVINGAPARTMENTS_MODE,
    h.LIVINGAREA_MODE,
    h.NONLIVINGAPARTMENTS_MODE,
    h.NONLIVINGAREA_MODE,
    h.APARTMENTS_MEDI,
    h.BASEMENTAREA_MEDI,
    h.YEARS_BEGINEXPLUATATION_MEDI,
    h.YEARS_BUILD_MEDI,
    h.COMMONAREA_MEDI,
    h.ELEVATORS_MEDI,
    h.ENTRANCES_MEDI,
    h.FLOORSMAX_MEDI,
    h.FLOORSMIN_MEDI,
    h.LANDAREA_MEDI,
    h.LIVINGAPARTMENTS_MEDI,
    h.LIVINGAREA_MEDI,
    h.NONLIVINGAPARTMENTS_MEDI,
    h.NONLIVINGAREA_MEDI,
    h.FONDKAPREMONT_MODE,
    h.HOUSETYPE_MODE,
    h.TOTALAREA_MODE,
    h.WALLSMATERIAL_MODE,
    h.EMERGENCYSTATE_MODE,
    s.OBS_30_CNT_SOCIAL_CIRCLE,
    s.DEF_30_CNT_SOCIAL_CIRCLE,
    s.OBS_60_CNT_SOCIAL_CIRCLE,
    s.DEF_60_CNT_SOCIAL_CIRCLE,
    p.DAYS_LAST_PHONE_CHANGE,
    d.FLAG_DOCUMENT_2,
    d.FLAG_DOCUMENT_3,
    d.FLAG_DOCUMENT_4,
    d.FLAG_DOCUMENT_5,
    d.FLAG_DOCUMENT_6,
    d.FLAG_DOCUMENT_7,
    d.FLAG_DOCUMENT_8,
    d.FLAG_DOCUMENT_9,
    d.FLAG_DOCUMENT_10,
    d.FLAG_DOCUMENT_11,
    d.FLAG_DOCUMENT_12,
    d.FLAG_DOCUMENT_13,
    d.FLAG_DOCUMENT_14,
    d.FLAG_DOCUMENT_15,
    d.FLAG_DOCUMENT_16,
    d.FLAG_DOCUMENT_17,
    d.FLAG_DOCUMENT_18,
    d.FLAG_DOCUMENT_19,
    d.FLAG_DOCUMENT_20,
    d.FLAG_DOCUMENT_21,
    e.AMT_REQ_CREDIT_BUREAU_HOUR,
    e.AMT_REQ_CREDIT_BUREAU_DAY,
    e.AMT_REQ_CREDIT_BUREAU_WEEK,
    e.AMT_REQ_CREDIT_BUREAU_MON,
    e.AMT_REQ_CREDIT_BUREAU_QRT,
    e.AMT_REQ_CREDIT_BUREAU_YEAR
FROM application a
JOIN applicant_profile          p USING (SK_ID_CURR)
JOIN applicant_housing          h USING (SK_ID_CURR)
JOIN applicant_social_circle    s USING (SK_ID_CURR)
JOIN application_documents      d USING (SK_ID_CURR)
JOIN applicant_bureau_enquiries e USING (SK_ID_CURR);
