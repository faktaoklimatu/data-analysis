"""Helpers shared by the fetch scripts."""
import csv
import sys
import time
from pathlib import Path

import requests

# Relative to the current directory, so run the scripts from this folder. The name
# contains "output-", which the repository's .gitignore excludes.
OUTPUT_DIR = Path("output-dashboard")

RETRIES = 3


def log(message: str) -> None:
    print(message, file=sys.stderr)


def new_session() -> requests.Session:
    session = requests.Session()
    session.headers["User-Agent"] = "faktaoklimatu-data-analysis (+faktaoklimatu.cz)"
    return session


def with_retries(label: str, fetch):
    """Call fetch() up to RETRIES times with exponential backoff, then re-raise."""
    for attempt in range(1, RETRIES + 1):
        try:
            return fetch()
        except Exception as exc:  # any failed download or parse is worth a retry
            log(f"  {label}: attempt {attempt}/{RETRIES} failed ({exc})")
            if attempt == RETRIES:
                raise
            time.sleep(2**attempt)


def write_csv(name: str, rows: list[dict], fields: list[str]) -> None:
    path = OUTPUT_DIR / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    log(f"Wrote {len(rows)} rows to {path}")
