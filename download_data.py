import shutil
import zipfile
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / ".env")

import kagglehub  # noqa: E402  (must import after the token is in the environment)

RAW_DIR = Path(__file__).parent / "data" / "raw"


def main() -> None:
    path = Path(kagglehub.competition_download("home-credit-default-risk"))
    print("Kaggle cache:", path)

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for src in path.rglob("*"):
        if src.suffix == ".zip":
            with zipfile.ZipFile(src) as zf:
                zf.extractall(RAW_DIR)
        elif src.is_file():
            shutil.copy2(src, RAW_DIR / src.name)

    for f in sorted(RAW_DIR.glob("*.csv")):
        print(f"{f.name:45s} {f.stat().st_size / 1e6:8.1f} MB")


if __name__ == "__main__":
    main()