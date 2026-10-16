#!/usr/bin/env python
"""Download the annual Czech GDP time series in nominal CZK from ČSÚ DataStat.

Run it with no arguments; everything is configured by the constants below.

    python fetch_gdp.py

Writes two CSVs: the full tidy table, one row per indicator x year, with the value in
millions of CZK at current (nominal) prices, covering every year DataStat publishes —
currently 1990 to 2025 — and a minimal `year,value_mil_czk` version of the
MINIMAL_INDICATOR series under MINIMAL_DIR for the d3 dashboard to load directly.

Unlike STAZO, DataStat has a real JSON/CSV API, documented at
https://csu.gov.cz/zakladni-informace-pro-pouziti-api-datastatu

The data comes from dataset NUC06R, "Hlavní souhrnné ukazatele HDP - roční údaje",
which is what the DataStat page data.csu.gov.cz/datastat/data/VYBER/NUC06RT01 presents.
This script queries the dataset rather than that predefined selection, because the
selection pins its list of years manually (1990-2025 today) whereas an empty year filter
on the dataset picks up new years by itself. `verzeSady` is likewise left off so the API
serves the current dataset version.

Other indicators available in the same dataset, should you want them — add the code to
INDICATORS below:

    9988S11   real GDP growth, % (previous year = 100)
    10032S01  GDP per capita, CZK, current prices
    9992BC    gross value added, mil. CZK, current prices
    10000DOM  household final consumption expenditure, mil. CZK, current prices
    9991BC    gross fixed capital formation, mil. CZK, current prices
    9991OI    gross fixed capital formation, % volume index
    9993C     compensation of employees, mil. CZK
"""
import csv
import io
import sys
from pathlib import Path

import requests

API = "https://data.csu.gov.cz/api"

# "Hlavní souhrnné ukazatele HDP - roční údaje".
DATASET = "NUC06R"

# Indicator code -> (column name used in the output, unit).
INDICATORS = {
    "9988S03": ("gdp", "mil. CZK, current prices"),
}

# The one indicator the dashboard file carries. It holds a single series, so it needs no
# code column; add indicators to INDICATORS above and they land in the full CSV only.
MINIMAL_INDICATOR = "9988S03"

# Dimension items to pin. Uz012 is the territory dimension (CZ = Czechia as a whole),
# NACEHDP the industry breakdown, whose "0" item is the all-industry total.
AREA = "CZ"
INDUSTRY_TOTAL = "0"

# Every output name contains "output-", which the repository's .gitignore excludes.
OUTPUT_PATH = Path("output-czso-gdp-annual.csv")

# Stripped-down copies for the d3 dashboard: only the columns a chart needs, so the
# browser does not download labels and notes it will never draw.
MINIMAL_DIR = Path("output-dashboard")
MINIMAL_PATH = MINIMAL_DIR / "gdp.csv"

FIELDNAMES = ["indicator", "code", "label", "year", "value", "unit", "note"]
MINIMAL_FIELDNAMES = ["year", "value_mil_czk"]


def log(message: str) -> None:
    print(message, file=sys.stderr)


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def fetch_dataset_info(session: requests.Session) -> dict[str, str]:
    """Return the dataset's indicator code -> official name, and check our codes exist."""
    resp = session.get(f"{API}/katalog/v1/sady/{DATASET}", timeout=60)
    resp.raise_for_status()
    info = resp.json()
    names = {u["kod"]: u["nazev"] for u in info.get("ukazatele", [])}

    missing = set(INDICATORS) - names.keys()
    if missing:
        raise RuntimeError(
            f"Indicator(s) {sorted(missing)} are no longer in dataset {DATASET}. "
            f"Available: {sorted(names)}"
        )
    log(f"{DATASET} version {info.get('verze')} ({info.get('nazev')})")
    return names


def fetch_data(session: requests.Session) -> bytes:
    """POST the query and return the result as CSV."""
    query = {
        # For CSV it does not matter which of the three lists a dimension goes into.
        "sloupce": [
            {
                "kodDimenze": "IndicatorType",
                "filtr": [{"zobrazitPolozky": list(INDICATORS)}],
            },
            # An empty filter means every item, so new years need no code change.
            {"kodDimenze": "CasR", "filtr": []},
            {"kodDimenze": "Uz012", "filtr": [{"zobrazitPolozky": [AREA]}]},
            {
                "kodDimenze": "NACEHDP",
                "filtr": [{"zobrazitPolozky": [INDUSTRY_TOTAL]}],
            },
        ],
        "radky": [],
        "filtryTabulky": [],
    }
    resp = session.post(
        f"{API}/dotaz/v1/data/sady/{DATASET}/vlastni",
        params={"format": "CSV", "kodZvlast": "true"},
        json=query,
        timeout=120,
    )
    resp.raise_for_status()
    return resp.content


def to_number(raw: str) -> float | None:
    text = raw.strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def parse_csv(raw: bytes, names: dict[str, str]) -> list[dict]:
    """Turn the DataStat CSV into tidy records, one per indicator and year."""
    rows = list(csv.DictReader(io.StringIO(raw.decode("utf-8-sig"))))
    if not rows:
        return []

    # kodZvlast=true adds a code column beside each label column; we key off the codes.
    required = {"IndicatorType", "CasR", "Hodnota"} - rows[0].keys()
    if required:
        raise RuntimeError(f"Unexpected DataStat CSV layout, missing {required}")

    records = []
    for row in rows:
        code = row["IndicatorType"].strip()
        if code not in INDICATORS:
            continue
        name, unit = INDICATORS[code]
        records.append(
            {
                "indicator": name,
                "code": code,
                "label": names.get(code, ""),
                "year": int(row["CasR"].strip()),
                "value": to_number(row["Hodnota"]),
                "unit": unit,
                "note": (row.get("POZNAMKA_TEXT") or "").strip(),
            }
        )
    records.sort(key=lambda r: (r["indicator"], r["year"]))
    return records


def main() -> int:
    session = requests.Session()
    session.headers["User-Agent"] = "faktaoklimatu-data-analysis (+faktaoklimatu.cz)"
    session.headers["Accept-Language"] = "cs"

    names = fetch_dataset_info(session)
    records = parse_csv(fetch_data(session), names)
    if not records:
        log("No data returned")
        return 1

    write_csv(OUTPUT_PATH, records, FIELDNAMES)

    # One indicator only, so the series needs no code column. A year with no value is
    # nothing for a chart to draw, so leave it out.
    minimal = [
        {"year": r["year"], "value_mil_czk": r["value"]}
        for r in records
        if r["code"] == MINIMAL_INDICATOR and r["value"] is not None
    ]
    write_csv(MINIMAL_PATH, minimal, MINIMAL_FIELDNAMES)

    years = [r["year"] for r in records]
    log(f"Wrote {len(records)} rows to {OUTPUT_PATH} ({min(years)}-{max(years)})")
    log(f"Wrote {len(minimal)} rows to {MINIMAL_PATH}")
    for name, _ in INDICATORS.values():
        series = [r for r in records if r["indicator"] == name]
        missing = [r["year"] for r in series if r["value"] is None]
        gaps = f", no value for {missing}" if missing else ""
        log(f"  {name}: {len(series)} years{gaps}")

    # The dashboard file has no code column, so anything but MINIMAL_INDICATOR would be
    # indistinguishable in it and is left out. Say so rather than dropping it quietly.
    other = [r for r in records if r["code"] != MINIMAL_INDICATOR]
    if other:
        codes = ", ".join(sorted({r["code"] for r in other}))
        log(
            f"Warning: {MINIMAL_PATH} carries only {MINIMAL_INDICATOR}; left out "
            f"{len(other)} rows of {codes}. Point MINIMAL_INDICATOR at the series "
            "the dashboard needs, or give the others their own file."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
