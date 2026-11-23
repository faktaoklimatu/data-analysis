#!/usr/bin/env python
"""Download yearly approved budgets of MŠMT and SFDI from MONITOR Státní pokladny.

    python fetch_budgets.py

Writes output-dashboard/msmt.csv and sfdi.csv (`year,total_mld_czk`): the *approved*
total expenditure ("Výdaje celkem") in nominal billions of CZK, for MŠMT (state budget
chapter 333) and SFDI (the transport infrastructure fund, chapter 506). The approved
budget is the figure people quote, and it is final for the running year too.

Source: https://monitor.statnipokladna.gov.cz, the Ministry of Finance's open data. One
zipped extract of CSVs is published per year-end (and per month for the running year);
the MONITOR catalogue lists them, so the script takes the latest one of each year and
picks up new releases by itself. About 100 MB is downloaded per run.

Traps in the data, all handled below:

* The FinOSS extract (state budget chapters) is a ledger of monthly postings, not a
  year-to-date statement: the opening budget sits in the first fiscal period and later
  periods hold only changes and spending. A year is the *sum* of its periods.
* Negative amounts carry the sign at the end ("354240.45-").
* Column order and quoting change between years, but every header ends in
  ":COLUMN_NAME", so columns are found by that suffix.
"""
import csv
import io
import re
import sys
import time
import zipfile

from common import log, new_session, with_retries, write_csv

FIRST_YEAR = 2017

# Institution -> (budget chapter, MONITOR dataset family). FinOSS = FIN 1-12 OSS (state
# budget chapters), FinSF = FIN 1-12 SF (state funds).
INSTITUTIONS = {
    "msmt": ("0333", "FinOSS"),
    "sfdi": ("0506", "FinSF"),
}

# Column of the extracts holding the approved budget (schválený rozpočet).
APPROVED = "ZU_ROZSCH"

# How to find total expenditure in each family: (table name prefix, item column, test on
# its value). FinSF has a ready-made total, item 3060 "Výdaje celkem"; the FinOSS ledger
# has not, so sum its item classes 5 (current) and 6 (capital expenditure).
TABLES = {
    "FinSF": ("FINSF02", "ZC_POLVYK", lambda item: item == "3060"),
    "FinOSS": ("MIS-RIS_", "ZCMMT_ITM", lambda item: item[:1] in ("5", "6")),
}

REQUEST_DELAY = 1.0  # be polite to a public service

BASE_URL = "https://monitor.statnipokladna.gov.cz"


def to_number(raw: str) -> float:
    """Parse an amount; a trailing minus (SAP style) means negative, blank means zero."""
    text = raw.strip()
    if not text:
        return 0.0
    return -float(text[:-1]) if text.endswith("-") else float(text)


def list_extracts(session) -> dict[tuple[str, int], str]:
    """Return the name of the latest published extract per (family, year)."""
    resp = session.get(
        f"{BASE_URL}/api/opendata/monitor",
        headers={"Accept": "application/ld+json"},
        timeout=60,
    )
    resp.raise_for_status()

    latest: dict[tuple[str, int], tuple[int, str]] = {}
    for iri in resp.json()["datová_sada"]:
        match = re.fullmatch(r".*/(FinOSS|FinSF)/((\d{4})_(\d{2})_Data_CSUIS_\w+)", iri)
        if match is None:
            continue
        family, name, year, month = match[1], match[2], int(match[3]), int(match[4])
        if (family, year) not in latest or month > latest[(family, year)][0]:
            latest[(family, year)] = (month, name)
    if not latest:
        raise RuntimeError("No extracts in the MONITOR catalogue; it may have changed")
    return {key: name for key, (_, name) in latest.items()}


def fetch_extract(session, family: str, name: str) -> zipfile.ZipFile:
    def fetch():
        url = f"{BASE_URL}/data/extrakty/csv/{family}/{name}.zip"
        resp = session.get(url, timeout=900)
        resp.raise_for_status()
        return zipfile.ZipFile(io.BytesIO(resp.content))

    return with_retries(name, fetch)


def approved_total(archive: zipfile.ZipFile, family: str, chapter: str) -> float:
    """Total approved expenditure of a chapter, in CZK."""
    prefix, item_column, is_expenditure = TABLES[family]
    table = next((n for n in archive.namelist() if n.startswith(prefix)), None)
    if table is None:
        raise RuntimeError(f"No {prefix}* table in {archive.namelist()}")
    reader = csv.reader(
        io.TextIOWrapper(archive.open(table), encoding="utf-8-sig", newline=""),
        delimiter=";",
    )
    col = {cell.rsplit(":", 1)[-1]: i for i, cell in enumerate(next(reader))}

    total, found = 0.0, False
    for row in reader:
        if len(row) <= max(col.values()):
            continue
        if row[col["0FM_AREA"]] == chapter and is_expenditure(row[col[item_column]]):
            total += to_number(row[col[APPROVED]])
            found = True
    if not found:
        raise RuntimeError(f"No expenditure for chapter {chapter} in {table}")
    return total


def main() -> int:
    session = new_session()
    extracts = list_extracts(session)
    last_year = max(year for _, year in extracts)
    log(f"MONITOR holds extracts up to {last_year}")

    budgets: dict[str, list[dict]] = {institution: [] for institution in INSTITUTIONS}
    for year in range(FIRST_YEAR, last_year + 1):
        for institution, (chapter, family) in INSTITUTIONS.items():
            name = extracts.get((family, year))
            if name is None:
                log(f"  {year}: no {family} extract, skipped for {institution}")
                continue
            archive = fetch_extract(session, family, name)
            total = round(approved_total(archive, family, chapter) / 1e9, 3)
            budgets[institution].append({"year": year, "total_mld_czk": total})
            log(f"  {year} {institution}: {total:.3f} bn ({name})")
            time.sleep(REQUEST_DELAY)

    for institution, rows in budgets.items():
        if not rows:
            log(f"No data for {institution}")
            return 1
        write_csv(f"{institution}.csv", rows, ["year", "total_mld_czk"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
