#!/usr/bin/env python
"""Download Czech crude oil and natural gas imports from ČSÚ STAZO.

    python fetch_stazo.py

Writes output-dashboard/imports-monthly.csv and imports-annual.csv: one row per period x
commodity x country of origin, with net mass in kg and statistical value in millions of
CZK, from FIRST_YEAR to the latest period ČSÚ has published. Both files are fetched as
separate queries, not derived from each other (see the suppression note below).

STAZO ("Pohyb zboží přes hranice", https://apl.czso.cz/pll/stazo/STAZO.STAZO) has no
public API, so this drives its query form: one POST returns an HTML page holding an
opaque `vektor` query handle, a second POST sends that handle to the CSV export.

Suppressed cells. ČSÚ hides cells that would disclose an individual importer, per query.
A query with no country dimension (`skup_zeme=0`) is never suppressed, so each year is
fetched twice: by country and as a country-free total. Where one origin of a period is
hidden, total minus the disclosed countries *is* its figure and it is filled in. Where
two or more are hidden the remainder cannot be split and becomes one `_RESIDUAL` row
(not a country: exclude it when ranking origins, include it in totals). Either way each
file sums to the official total.

Two deliberate choices that look simplifiable but must not be changed:

* Goods are fetched at the 4-digit HS level (2709 crude oil, 2711 natural gas incl. a few
  percent LPG). At the 8-digit CN level ČSÚ hides the country breakdown for gas in almost
  every month of 2004-2016.
* One query per year per aggregation. Suppression covers the whole selected period at
  once, so one 1999-2026 query hides far more than 28 yearly ones.

Known gap: for 2006-2008 ČSÚ publishes no net mass at any aggregated level, so mass_kg is
empty for those years; CZK values are complete.
"""
import csv
import io
import re
import sys
import time
from collections import defaultdict

from common import log, new_session, with_retries, write_csv

# Monthly data starts in January 1999.
FIRST_YEAR = 1999

# The goods to fetch: 4-digit HS codes mapped to the label used in the output.
HS_CODES = {"2709": "crude_oil", "2711": "natural_gas"}

REQUEST_DELAY = 1.0  # be polite to a slow public application

BASE_URL = "https://apl.czso.cz/pll/stazo/"
FORM_URL = BASE_URL + "STAZO.STAZO"
QUERY_URL = BASE_URL + "!PRESSO.STAZO.PRIPRAV_ZOBRAZ"
EXPORT_URL = BASE_URL + "PRESSO.STAZO.NOVE_VOLANI"

# STAZO marks cells it cannot disclose with an asterisk.
CONFIDENTIAL = "*"
RESIDUAL_CODE = "_RESIDUAL"

# Form fields that never change. Names mirror the HTML form, hence the Czech.
FORM_FIXED = {
    "mesic_od": "01",
    "typ_vyst": "1",  # absolute values, not shares or year-on-year indices
    "mena": "CZK",
    "zaokrouhlit": "T",  # value in thousands; converted to millions on writing
    "dov_vyv": "d",  # imports
    "omez": "99999",  # row limit
    "tab": "A",
    "razeni1": "x",
    "smer1": " ",
    "razeni2": "x",
    "smer2": " ",
    "razeni3": "x",
    "smer3": " ",
    "nomen": "14",  # 4-digit Harmonised System
    "ur_nomen": "14",
    "kod_zbozi": ",".join(HS_CODES),
    "n_kod_zbozi": ",".join(HS_CODES),
    "kod_zeme": "",  # empty = all countries
    "n_kod_zeme": "",
    "jazyk": "CS",
    "par": "D",
    "email": "",
    "jmdot": "",
    "popdot": "",
    "graf": "N",
}

# Output columns; the annual file has no month.
COLUMNS = ["commodity", "year", "month", "country_code", "mass_kg", "value_mil_czk"]


def fetch_latest_period(session) -> str:
    """Return the most recent period STAZO holds data for, as YYYYMM."""
    resp = session.get(FORM_URL, timeout=60)
    resp.raise_for_status()
    match = re.search(
        r'NAME="max_obd"\s+VALUE="(\d{6})"|VALUE="(\d{6})"\s+NAME="max_obd"',
        resp.text,
        re.IGNORECASE,
    )
    if match is None:
        raise RuntimeError("Could not read the latest available period from STAZO")
    return match[1] or match[2]


def fetch_year_csv(session, year: int, last_month: int, monthly: bool, by_country: bool, latest: str) -> bytes:
    """Run one query (one year, one aggregation) and return its CSV export."""
    form = {
        **FORM_FIXED,
        "rok_od": str(year),
        "rok_do": str(year),
        "mesic_do": f"{last_month:02d}",
        "seskup": "M" if monthly else "A",  # by months / by years
        "max_obd": latest,
        # skup_zeme 1 = break down by country, 0 = no country dimension at all.
        "skup_zeme": "1" if by_country else "0",
        "vyber_zemi": "1" if by_country else "0",
    }
    if by_country:
        form["zb_zem"] = "3"  # order: by goods, then by country

    resp = session.post(QUERY_URL, data=form, timeout=600)
    resp.raise_for_status()
    page = resp.content.decode("utf-8", errors="replace")

    # A query matching nothing still yields a handle, so a missing one means the form
    # was rejected or the application changed.
    handle = re.search(r'document\.posli\.vektor\.value="([^"]*)"', page)
    if handle is None:
        raise RuntimeError("STAZO returned no query handle; the application may have changed")
    handle_sums = re.search(r'document\.posli\.vektor_souc\.value="([^"]*)"', page)

    export = session.post(
        EXPORT_URL,
        data={
            "vektor": handle[1],
            "vektor_souc": handle_sums[1] if handle_sums else "",
            "nomen": "",
            "kody_zemi": "",
            # The goods filter must be repeated; without it STAZO exports every CN8
            # code for the period, a 20 MB download.
            "kody_zbozi": ",".join(HS_CODES),
            "order_by": ",kod_zbozi,kod_zeme",
            "typ_vystupu": "C",  # C = CSV
            "zb_ze": "cx",
        },
        timeout=600,
    )
    export.raise_for_status()
    return export.content


def to_number(raw: str) -> float | None:
    text = raw.strip().replace("\xa0", "").replace(" ", "")
    if not text or text == CONFIDENTIAL:
        return None
    try:
        return float(text.replace(",", "."))
    except ValueError:
        return None


def parse_period(raw: str) -> tuple[int, int | None] | None:
    """Parse a STAZO period label: "01/2024" when monthly, "2024" when annual."""
    monthly = re.fullmatch(r"(\d{1,2})/(\d{4})", raw)
    if monthly:
        return int(monthly[2]), int(monthly[1])
    return (int(raw), None) if re.fullmatch(r"\d{4}", raw) else None


def parse_csv(raw: bytes) -> list[dict]:
    """Turn one STAZO CSV export into records; value is kept in thousands (`value_k`)."""
    rows = list(csv.reader(io.StringIO(raw.decode("utf-8-sig")), delimiter=";"))
    if len(rows) < 2:
        return []

    # Find columns by their Czech labels: the layout varies (no net mass column for
    # 2006-2008, no country column in the country-free totals).
    labels = {
        "period": "Období",
        "code": "Kód zboží",
        "country_code": "Kód země",
        "mass": "Netto",
        "value": "hodnota",
    }
    header = rows[0]
    columns = {
        key: i
        for i, cell in enumerate(header)
        for key, label in labels.items()
        if label in cell
    }
    missing = {"period", "code", "value"} - columns.keys()
    if missing:
        raise RuntimeError(f"Unexpected STAZO CSV layout, missing {missing}: {header}")
    if "tis" not in header[columns["value"]]:
        raise RuntimeError(f"Value column is not in thousands: {header[columns['value']]}")

    def cell(row, key):
        return row[columns[key]].strip() if key in columns else ""

    records = []
    for row in rows[1:]:
        if len(row) <= max(columns.values()):
            continue
        period = parse_period(cell(row, "period"))
        if period is None:
            continue
        raw_mass, raw_value = cell(row, "mass"), cell(row, "value")
        records.append(
            {
                "commodity": HS_CODES.get(cell(row, "code"), cell(row, "code")),
                "year": period[0],
                "month": period[1],
                "country_code": cell(row, "country_code"),
                "mass_kg": to_number(raw_mass),
                "value_k": to_number(raw_value),
                # STAZO blanks out every measure of a cell it cannot disclose.
                "confidential": CONFIDENTIAL in (raw_mass, raw_value),
            }
        )
    return records


def fetch_series(session, monthly: bool, by_country: bool, latest: str) -> list[dict]:
    """Fetch every year for one aggregation, one query per year."""
    latest_year, latest_month = int(latest[:4]), int(latest[4:])
    records = []
    for year in range(FIRST_YEAR, latest_year + 1):
        last_month = latest_month if year == latest_year else 12
        raw = with_retries(
            str(year),
            lambda: fetch_year_csv(session, year, last_month, monthly, by_country, latest),
        )
        rows = parse_csv(raw)
        hidden = sum(r["confidential"] for r in rows)
        log(f"  {year}: {len(rows)} rows" + (f" ({hidden} confidential)" if hidden else ""))
        records.extend(rows)
        time.sleep(REQUEST_DELAY)
    return records


def reconcile(rows: list[dict], totals: list[dict]) -> list[dict]:
    """Fill or account for suppressed cells using the country-free totals."""
    total_of = {(t["commodity"], t["year"], t["month"]): t for t in totals}
    groups = defaultdict(list)
    for row in rows:
        groups[(row["commodity"], row["year"], row["month"])].append(row)

    residual_rows = []
    for key, group in groups.items():
        hidden = [r for r in group if r["confidential"]]
        total = total_of.get(key)
        if not hidden or total is None:
            continue

        # What the total holds beyond the disclosed countries (None if it has no mass).
        remainder = {
            field: None
            if total[field] is None
            else total[field] - sum(r[field] or 0 for r in group)
            for field in ("mass_kg", "value_k")
        }
        if not any((v or 0) > 0 for v in remainder.values()):
            continue

        if len(hidden) == 1:
            hidden[0].update(remainder)  # the remainder belongs to that one origin
        else:
            residual_rows.append(
                {**hidden[0], **remainder, "country_code": RESIDUAL_CODE, "confidential": False}
            )

    log(f"  {len(residual_rows)} residual rows")
    return rows + residual_rows


def write_outputs(name: str, rows: list[dict], monthly: bool) -> None:
    rows.sort(key=lambda r: (r["commodity"], r["year"], r["month"] or 0, r["country_code"]))
    for row in rows:
        # Thousands are whole numbers, so millions are exact to 3 places.
        row["value_mil_czk"] = None if row["value_k"] is None else round(row["value_k"] / 1000, 3)
    # A row with neither measure is a suppressed cell that subtraction could not
    # attribute to one origin; there is nothing to draw, and its volume is still in the
    # _RESIDUAL row of the same period.
    rows = [r for r in rows if r["mass_kg"] is not None or r["value_mil_czk"] is not None]
    write_csv(name, rows, [c for c in COLUMNS if monthly or c != "month"])

    massless = sorted({r["year"] for r in rows} - {r["year"] for r in rows if r["mass_kg"] is not None})
    if massless:
        log(f"Note: no net mass for {massless} (ČSÚ publishes none); CZK values are complete.")


def main() -> int:
    session = new_session()
    session.headers["Referer"] = FORM_URL

    latest = fetch_latest_period(session)
    log(f"STAZO holds data up to {latest[:4]}-{latest[4:]}")

    for monthly in (True, False):
        label = "monthly" if monthly else "annual"
        log(f"{label}, by country")
        by_country = fetch_series(session, monthly, True, latest)
        log(f"{label}, country-free totals")
        totals = fetch_series(session, monthly, False, latest)
        write_outputs(f"imports-{label}.csv", reconcile(by_country, totals), monthly)
    return 0


if __name__ == "__main__":
    sys.exit(main())
