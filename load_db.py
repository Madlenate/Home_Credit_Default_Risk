"""Build home_credit.db (SQLite) from the CSVs in data/raw using schema.sql.

DuckDB parses the CSVs and bulk-inserts through its sqlite extension, which is
far faster than row-by-row inserts from Python. Run download_data.py first.

    python load_db.py            # builds ./home_credit.db (replaces it if present)
"""
import sqlite3
import time
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).parent
RAW = ROOT / "data" / "raw"
DB_PATH = ROOT / "home_credit.db"

APP_SPLITS = ["applicant_profile", "applicant_housing", "applicant_social_circle",
              "application_documents", "applicant_bureau_enquiries"]

# sqlite table -> source CSV, for the tables that map 1:1 onto a file
DIRECT = {
    "bureau": "bureau",
    "bureau_balance": "bureau_balance",
    "previous_application": "previous_application",
    "pos_cash_balance": "POS_CASH_balance",
    "credit_card_balance": "credit_card_balance",
    "installments_payments": "installments_payments",
}


def csv(name: str) -> str:
    # EMERGENCYSTATE_MODE holds 'Yes'/'No'; keep it as text instead of DuckDB's boolean guess.
    types = ", types={'EMERGENCYSTATE_MODE': 'VARCHAR'}" if name.startswith("application") else ""
    return f"read_csv('{(RAW / f'{name}.csv').as_posix()}', header=true, sample_size=-1{types})"


def columns(sq: sqlite3.Connection, table: str) -> list[str]:
    return [r[1] for r in sq.execute(f"PRAGMA table_info({table})")]


def primary_key(sq: sqlite3.Connection, table: str) -> list[str]:
    rows = sorted((r[5], r[1]) for r in sq.execute(f"PRAGMA table_info({table})") if r[5])
    return [name for _, name in rows]


def load_column_description(sq: sqlite3.Connection) -> None:
    # The file mixes encodings, which DuckDB's strict reader rejects.
    df = pd.read_csv(RAW / "HomeCredit_columns_description.csv", encoding="cp1252", index_col=0)
    sq.executemany("INSERT INTO column_description VALUES (?, ?, ?, ?)",
                   df[["Table", "Row", "Description", "Special"]].itertuples(index=False))
    sq.commit()
    print(f"{'column_description':28s} {len(df):>12,} rows")


def main() -> None:
    DB_PATH.unlink(missing_ok=True)
    sq = sqlite3.connect(DB_PATH)
    sq.executescript((ROOT / "schema.sql").read_text())
    sq.close()

    sq = sqlite3.connect(DB_PATH)
    dk = duckdb.connect()
    dk.execute("INSTALL sqlite; LOAD sqlite; SET preserve_insertion_order = false")
    dk.execute(f"ATTACH '{DB_PATH.as_posix()}' AS db (TYPE sqlite)")
    dk.execute(f"""
        CREATE TEMP TABLE app AS
        SELECT 'train' AS dataset, * FROM {csv('application_train')}
        UNION ALL BY NAME
        SELECT 'test'  AS dataset, * FROM {csv('application_test')}
    """)

    def load(table: str, source: str, cols: list[str] | None = None) -> None:
        t0 = time.time()
        cols = cols or columns(sq, table)
        col_list = ", ".join(f'"{c}"' for c in cols)
        # Inserting in primary-key order keeps SQLite's B-tree appends sequential;
        # unordered inserts into the WITHOUT ROWID tables are many times slower.
        pk = [c for c in primary_key(sq, table) if c != "id"]
        order = f" ORDER BY {', '.join(pk)}" if pk else ""
        dk.execute(f"INSERT INTO db.{table} ({col_list}) SELECT {col_list} FROM {source}{order}")
        n = sq.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
        print(f"{table:28s} {n:>12,} rows  {time.time() - t0:6.1f}s", flush=True)

    load("application", "app")
    for t in APP_SPLITS:
        load(t, "app")
    for t, f in DIRECT.items():
        # installments_payments.id is a surrogate key SQLite assigns itself
        cols = [c for c in columns(sq, t) if c != "id"]
        load(t, csv(f), cols)

    dk.close()
    load_column_description(sq)

    print("building indexes ...", flush=True)
    sq.executescript((ROOT / "indexes.sql").read_text())

    # DuckDB's writer does not enforce SQLite FKs, so verify them here.
    bad = sq.execute("PRAGMA foreign_key_check").fetchall()
    print("foreign key violations:", len(bad))
    sq.execute("ANALYZE")
    sq.commit()
    sq.close()
    print(f"done: {DB_PATH} ({DB_PATH.stat().st_size / 1e9:.2f} GB)")


if __name__ == "__main__":
    main()
