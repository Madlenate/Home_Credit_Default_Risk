from pathlib import Path

import pandas as pd
import streamlit as st

PROJECT_ROOT = Path(__file__).resolve().parents[2]
PROCESSED = PROJECT_ROOT / "data" / "processed"


@st.cache_data
def load_parquet(name: str, columns: list[str] | None = None) -> pd.DataFrame:
    """Load a processed parquet file, optionally only selected columns."""
    return pd.read_parquet(PROCESSED / name, columns=columns)
