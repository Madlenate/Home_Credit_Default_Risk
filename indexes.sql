-- Secondary indexes for the common join paths (PK columns are already indexed).
-- Created after the bulk load by load_db.py; safe to re-run.
CREATE INDEX IF NOT EXISTS ix_application_dataset       ON application (dataset);
CREATE INDEX IF NOT EXISTS ix_bureau_curr               ON bureau (SK_ID_CURR);
CREATE INDEX IF NOT EXISTS ix_previous_application_curr ON previous_application (SK_ID_CURR);
CREATE INDEX IF NOT EXISTS ix_pos_cash_balance_curr     ON pos_cash_balance (SK_ID_CURR);
CREATE INDEX IF NOT EXISTS ix_credit_card_balance_curr  ON credit_card_balance (SK_ID_CURR);
CREATE INDEX IF NOT EXISTS ix_installments_curr         ON installments_payments (SK_ID_CURR);
CREATE INDEX IF NOT EXISTS ix_installments_prev         ON installments_payments (SK_ID_PREV, NUM_INSTALMENT_NUMBER);
