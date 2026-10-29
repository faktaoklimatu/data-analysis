#!/usr/bin/env python
"""Download yearly budgets of MŠMT and SFDI from the state treasury's MONITOR open data.

Run it with no arguments; everything is configured by the constants below.

    python fetch_budgets.py

Writes a full CSV with three budget measures per institution and year, plus one minimal
`year,total_mld_czk` CSV per institution under MINIMAL_DIR for the d3 dashboard.

"Total" is total expenditure ("Výdaje celkem"): for MŠMT (Ministerstvo školství,
mládeže a tělovýchovy) that of state budget chapter 333, for SFDI (Státní fond
dopravní infrastruktury) that of the fund, which is chapter 506 in the statements.
All amounts are nominal. The three measures are

    approved        the budget as enacted at the start of the year (schválený rozpočet)
    after_changes   the budget after in-year changes (rozpočet po změnách)
    actual          what was actually spent (skutečnost)

BUDGET_MEASURE picks the one the dashboard files carry. The default is the approved
budget because it is the headline figure people quote and, unlike the other two, it is
already known for the current year.

Source: MONITOR Státní pokladny, https://monitor.statnipokladna.gov.cz, the open data
of the Ministry of Finance. One zipped extract of CSVs is published per year-end (and per
month for the running year), in two families, both available from 2015:

    FinOSS   FIN 1-12 OSS, state budget chapters (MŠMT)
    FinSF    FIN 1-12 SF, state funds (SFDI)

The extracts are located through the MONITOR catalogue, so new releases are picked up
by themselves: for the running year the script takes the latest month published.

Three things about the data are easy to get wrong:

* The FinOSS extract is a ledger of monthly postings, not a year-to-date statement.
  The opening budget sits in the first fiscal period and later periods hold only changes
  and spending, so a year is the sum of its periods.
* Negative amounts carry the sign at the end ("354240.45-").
* Chapter 333 consists of several organisations, so its total is a sum over all of them.

The download is about 100 MB, nearly all of it the FinOSS extracts.
"""
import csv
import io
import re
import sys
import time
import zipfile
from collections import defaultdict
from pathlib import Path

import requests

# The open data goes back to 2015 for these statements (and to 2010 for the older
# FIN 2-04 U, which this script does not read).
FIRST_YEAR = 2017

# What total_mld_czk means in the dashboard files: a key of MEASURES below.
BUDGET_MEASURE = "approved"

# Every output name contains "output-", which the repository's .gitignore excludes.
OUTPUT_PATH = Path("output-monitor-budgets.csv")
MINIMAL_DIR = Path("output-dashboard")

# Institution -> (budget chapter, MONITOR dataset family). The dashboard file is
# MINIMAL_DIR / f"{institution}.csv".
INSTITUTIONS = {
    "msmt": ("0333", "FinOSS"),
    "sfdi": ("0506", "FinSF"),
}

# Measure -> column of the extracts that holds it.
MEASURES = {
    "approved": "ZU_ROZSCH",
    "after_changes": "ZU_ROZPZM",
    "actual": "ZU_ROZKZ",
}

# The FinSF table that holds total expenditure per fund, and its row ("Výdaje celkem"),
# which is the sum of classes 5 and 6 below.
STATEMENT_TABLE = "FINSF02"
TOTAL_EXPENDITURE_ITEM = "3060"

# Budget item classes that make up expenditure: 5 current ("Běžné výdaje"), 6 capital
# ("Kapitálové výdaje"). Used for the FinOSS ledger, which has no ready-made total.
EXPENDITURE_CLASSES = ("5", "6")

# Be polite to a public service.
REQUEST_DELAY = 1.0
RETRIES = 3

BASE_URL = "https://monitor.statnipokladna.gov.cz"
CATALOGUE_URL = BASE_URL + "/api/opendata/monitor"
EXTRACT_URL = BASE_URL + "/data/extrakty/csv"

FIELDNAMES = [
    "institution",
    "year",
    "through_month",
    *(f"{measure}_mld_czk" for measure in MEASURES),
]


def log(message: str) -> None:
    print(message, file=sys.stderr)


def to_number(raw: str) -> float:
    """Parse an amount; a trailing minus (SAP style) means negative, blank means zero."""
    text = raw.strip()
    if not text:
        return 0.0
    return -float(text[:-1]) if text.endswith("-") else float(text)


def list_extracts(session: requests.Session) -> dict[tuple[str, int], str]:
    """Return the name of the latest published extract per (family, year)."""
    resp = session.get(
        CATALOGUE_URL, headers={"Accept": "application/ld+json"}, timeout=60
    )
    resp.raise_for_status()

    latest: dict[tuple[str, int], tuple[int, str]] = {}
    for iri in resp.json()["datová_sada"]:
        match = re.fullmatch(
            r".*/(FinOSS|FinSF)/((\d{4})_(\d{2})_Data_CSUIS_\w+)", iri
        )
        if match is None:
            continue
        family, name, year, month = match[1], match[2], int(match[3]), int(match[4])
        key = (family, year)
        if key not in latest or month > latest[key][0]:
            latest[key] = (month, name)
    if not latest:
        raise RuntimeError("No extracts in the MONITOR catalogue; it may have changed")
    return {key: name for key, (_, name) in latest.items()}


def fetch_extract(session: requests.Session, family: str, name: str) -> zipfile.ZipFile:
    url = f"{EXTRACT_URL}/{family}/{name}.zip"
    for attempt in range(1, RETRIES + 1):
        try:
            resp = session.get(url, timeout=900)
            resp.raise_for_status()
            return zipfile.ZipFile(io.BytesIO(resp.content))
        except (requests.RequestException, zipfile.BadZipFile) as exc:
            log(f"  {name}: attempt {attempt}/{RETRIES} failed ({exc})")
            if attempt == RETRIES:
                raise
            time.sleep(2**attempt)
    raise AssertionError("unreachable")


def open_table(archive: zipfile.ZipFile, prefix: str):
    """Open a CSV of the archive; return its row reader and a column name -> index map.

    Column order and quoting differ between years, but every header ends in
    ":COLUMN_NAME", which is stable, so columns are looked up by that.
    """
    name = next((n for n in archive.namelist() if n.startswith(prefix)), None)
    if name is None:
        raise RuntimeError(f"No {prefix}* table in {archive.namelist()}")
    text = io.TextIOWrapper(archive.open(name), encoding="utf-8-sig", newline="")
    reader = csv.reader(text, delimiter=";")
    header = next(reader)
    return reader, {cell.rsplit(":", 1)[-1]: i for i, cell in enumerate(header)}


def statement_totals(archive: zipfile.ZipFile, chapter: str):
    """Total expenditure of a fund from its FIN 1-12 SF statement."""
    reader, col = open_table(archive, STATEMENT_TABLE)
    totals = dict.fromkeys(MEASURES, 0.0)
    periods = set()
    for row in reader:
        if len(row) <= max(col.values()):
            continue
        if row[col["0FM_AREA"]] != chapter:
            continue
        if row[col["ZC_POLVYK"]] != TOTAL_EXPENDITURE_ITEM:
            continue
        periods.add(row[col["0FISCPER"]])
        for measure, field in MEASURES.items():
            totals[measure] += to_number(row[col[field]])
    return totals, periods


def ledger_totals(archive: zipfile.ZipFile, chapter: str):
    """Total expenditure of a chapter from the FinOSS ledger of monthly postings."""
    reader, col = open_table(archive, "MIS-RIS_")
    totals = dict.fromkeys(MEASURES, 0.0)
    periods = set()
    for row in reader:
        if len(row) <= max(col.values()):
            continue
        if row[col["0FM_AREA"]] != chapter:
            continue
        if row[col["ZCMMT_ITM"]][:1] not in EXPENDITURE_CLASSES:
            continue
        periods.add(row[col["0FISCPER"]])
        for measure, field in MEASURES.items():
            totals[measure] += to_number(row[col[field]])
    return totals, periods


def build_records(session: requests.Session) -> list[dict]:
    extracts = list_extracts(session)
    last_year = max(year for _, year in extracts)
    log(f"MONITOR holds extracts up to {last_year}")

    records = []
    for year in range(FIRST_YEAR, last_year + 1):
        by_family = defaultdict(list)
        for institution in INSTITUTIONS:
            by_family[INSTITUTIONS[institution][1]].append(institution)

        for family, institutions in by_family.items():
            name = extracts.get((family, year))
            if name is None:
                log(f"  {year}: no {family} extract, skipped for {institutions}")
                continue

            started = time.time()
            archive = fetch_extract(session, family, name)
            for institution in institutions:
                chapter = INSTITUTIONS[institution][0]
                if family == "FinOSS":
                    totals, periods = ledger_totals(archive, chapter)
                else:
                    totals, periods = statement_totals(archive, chapter)
                if not periods:
                    raise RuntimeError(f"{name}: nothing for chapter {chapter}")

                # Fiscal periods look like 2025012; the last three digits are the month.
                month = min(int(max(periods)[-3:]), 12)
                records.append(
                    {
                        "institution": institution,
                        "year": year,
                        "through_month": month,
                        **{f"{m}_mld_czk": round(v / 1e9, 3) for m, v in totals.items()},
                    }
                )
                log(
                    f"  {year} {institution}: approved "
                    f"{records[-1]['approved_mld_czk']:.3f} bn ({name}, "
                    f"{time.time() - started:.0f} s)"
                )
            time.sleep(REQUEST_DELAY)
    return records


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    if BUDGET_MEASURE not in MEASURES:
        raise SystemExit(f"BUDGET_MEASURE must be one of {sorted(MEASURES)}")

    session = requests.Session()
    session.headers["User-Agent"] = "faktaoklimatu-data-analysis (+faktaoklimatu.cz)"

    records = build_records(session)
    if not records:
        log("No data returned")
        return 1
    records.sort(key=lambda r: (r["institution"], r["year"]))
    write_csv(OUTPUT_PATH, records, FIELDNAMES)
    log(f"Wrote {len(records)} rows to {OUTPUT_PATH}")

    for institution in INSTITUTIONS:
        rows = [r for r in records if r["institution"] == institution]
        # The approved budget of a running year is final. What was changed or spent is
        # not, and a year-to-date figure drawn next to full years would mislead.
        partial = [r["year"] for r in rows if r["through_month"] < 12]
        if BUDGET_MEASURE != "approved":
            rows = [r for r in rows if r["through_month"] == 12]
            if partial:
                log(f"  {institution}: left out {partial}; {BUDGET_MEASURE} not final")
        minimal = [
            {"year": r["year"], "total_mld_czk": r[f"{BUDGET_MEASURE}_mld_czk"]}
            for r in rows
        ]
        path = MINIMAL_DIR / f"{institution}.csv"
        write_csv(path, minimal, ["year", "total_mld_czk"])
        years = [r["year"] for r in minimal]
        log(f"Wrote {len(minimal)} rows to {path} ({min(years)}-{max(years)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
