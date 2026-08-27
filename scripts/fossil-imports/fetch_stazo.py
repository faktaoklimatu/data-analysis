#!/usr/bin/env python
"""Download Czech natural gas and crude oil import data from the ČSÚ STAZO database.

Run it with no arguments; everything is configured by the constants below.

    python fetch_stazo.py

Writes two tidy CSVs, one monthly and one annual, each with one row per period x
commodity x country of origin, net mass in kg and statistical value in millions of CZK,
from FIRST_YEAR to the latest period ČSÚ has published.

Both files are produced because ČSÚ suppresses cells that would disclose an individual
importer, and it does so per query. The annual figures are therefore not merely the sum
of the monthly ones: they include flows the monthly breakdown has to hide. Use the
monthly file for shape within a year and the annual file for levels and shares.

Suppressed cells are recovered by subtraction. Each year is fetched twice per
aggregation: once broken down by country, once with no country dimension at all
(`skup_zeme=0`), which STAZO never suppresses. The difference between the total and the
sum of the disclosed countries is the hidden amount. Where a period has exactly one
suppressed origin the difference *is* that origin's figure, and it is filled in with
`derived=True`; that recovers every suppressed cell in the annual file and most of them
in the monthly one. Where two or more origins are suppressed at once the remainder
cannot be split between them, so it is emitted as a single `_RESIDUAL` row instead.
Either way each file sums to the true total.

STAZO ("Pohyb zboží přes hranice", https://apl.czso.cz/pll/stazo/STAZO.STAZO) has no
public API, so this drives its query form: one POST returns an HTML page holding an
opaque `vektor` query handle, a second POST sends that handle to the CSV export.

Two deliberate choices that look like they could be simplified but must not be:

* Goods are fetched at the 4-digit HS level. At the 8-digit CN level ČSÚ suppresses the
  country breakdown for natural gas for almost every month from 2004 to 2016 to avoid
  disclosing individual importers.
* One query per year per aggregation. Suppression is applied to the whole selected
  period at once, so a single 1999-2026 query hides far more than 28 yearly ones do.

Known gap: for 2006-2008 ČSÚ publishes no net mass at any aggregated level, for any
commodity, in either aggregation. mass_kg is empty for those years; CZK values are not.
"""
import csv
import io
import re
import sys
import time
from pathlib import Path

import requests

# Monthly data starts in January 1999; 1993-1998 is only available on request from ČSÚ.
FIRST_YEAR = 1999

# Output file per period aggregation, keyed by the STAZO `seskup` code.
OUTPUTS = {
    "M": Path("czso_stazo_imports_monthly.csv"),
    "A": Path("czso_stazo_imports_annual.csv"),
}

# The goods to fetch, as 4-digit HS codes mapped to the label used in the output.
# HS 2711 covers natural gas plus other gaseous hydrocarbons such as LPG.
HS_CODES = {"2709": "crude_oil", "2711": "natural_gas"}

CURRENCY = "CZK"  # CZK, EUR or USD

# Be polite to a slow public application.
REQUEST_DELAY = 1.0
RETRIES = 3

BASE_URL = "https://apl.czso.cz/pll/stazo/"
FORM_URL = BASE_URL + "STAZO.STAZO"
QUERY_URL = BASE_URL + "!PRESSO.STAZO.PRIPRAV_ZOBRAZ"
EXPORT_URL = BASE_URL + "PRESSO.STAZO.NOVE_VOLANI"

# STAZO marks cells it cannot disclose with an asterisk ("Individuální hodnota").
CONFIDENTIAL_MARKER = "*"

VALUE_FIELD = f"value_mil_{CURRENCY.lower()}"

# Value is carried internally in thousands, as STAZO reports it, so that residuals are
# computed on exact integers and converted to millions only on writing.
VALUE_K = "_value_k"

# Synthetic origin used when a remainder cannot be attributed to a single country.
RESIDUAL_CODE = "_RESIDUAL"


def log(message: str) -> None:
    print(message, file=sys.stderr)


def fetch_latest_period(session: requests.Session) -> str:
    """Return the most recent period STAZO holds data for, as YYYYMM."""
    resp = session.get(FORM_URL, timeout=60)
    resp.raise_for_status()
    match = re.search(r'NAME="max_obd"\s+VALUE="(\d{6})"', resp.text, re.IGNORECASE)
    if match is None:
        match = re.search(r'VALUE="(\d{6})"\s+NAME="max_obd"', resp.text, re.IGNORECASE)
    if match is None:
        raise RuntimeError("Could not read the latest available period from STAZO")
    return match.group(1)


def query_form(
    year: int, month_to: int, seskup: str, latest: str, by_country: bool
) -> dict[str, str]:
    """Build the STAZO query form. Field names mirror the HTML form, hence the Czech."""
    codes = ",".join(HS_CODES)
    form = {
        "mesic_od": "01",
        "rok_od": str(year),
        "mesic_do": f"{month_to:02d}",
        "rok_do": str(year),
        "seskup": seskup,  # M = by months, A = by years
        "typ_vyst": "1",  # absolute values, not shares or year-on-year indices
        "mena": CURRENCY,
        "zaokrouhlit": "T",  # value in thousands; converted to millions on parsing
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
        "kod_zbozi": codes,
        "n_kod_zbozi": codes,
        # skup_zeme 1 = break down by country, 0 = no country dimension at all. The
        # country-free totals are never suppressed, which is what makes them useful.
        "skup_zeme": "1" if by_country else "0",
        "vyber_zemi": "1" if by_country else "0",
        "kod_zeme": "",  # empty = all countries
        "n_kod_zeme": "",
        "jazyk": "CS",
        "par": "D",
        "max_obd": latest,
        "email": "",
        "jmdot": "",
        "popdot": "",
        "graf": "N",
    }
    if by_country:
        form["zb_zem"] = "3"  # order: by goods, then by country
    return form


def fetch_year_csv(session: requests.Session, form: dict[str, str]) -> bytes:
    """Run one query and return the CSV export of its result table."""
    resp = session.post(QUERY_URL, data=form, timeout=600)
    resp.raise_for_status()
    page = resp.content.decode("utf-8", errors="replace")

    # A query matching nothing still yields a handle and a header-only table, so a
    # missing handle means the form was rejected or the application changed.
    handle = re.search(r'document\.posli\.vektor\.value="([^"]*)"', page)
    if handle is None:
        raise RuntimeError(
            "STAZO returned no query handle; the application may have changed"
        )
    handle_sums = re.search(r'document\.posli\.vektor_souc\.value="([^"]*)"', page)

    export = session.post(
        EXPORT_URL,
        data={
            "vektor": handle.group(1),
            "vektor_souc": handle_sums.group(1) if handle_sums else "",
            "nomen": "",
            "kody_zemi": "",
            # The goods filter must be repeated here; without it STAZO exports every
            # CN8 code for the period, which is a 20 MB download.
            "kody_zbozi": ",".join(HS_CODES),
            "order_by": ",kod_zbozi,kod_zeme",
            "typ_vystupu": "C",  # C = CSV, E = Excel, T = HTML table
            "zb_ze": "cx",
        },
        timeout=600,
    )
    export.raise_for_status()
    return export.content


def map_columns(header: list[str]) -> dict[str, int]:
    """Locate columns by their Czech labels.

    The layout is not fixed: the net mass column is absent altogether from the
    aggregated tables for 2006-2008, so it has to be discovered, not assumed.
    """
    labels = {
        "period": "Období",
        "code": "Kód zboží",
        "code_label": "Název zboží",
        "country_code": "Kód země",
        "country_name": "Název země",
        "mass": "Netto",
        "value": "hodnota",
    }
    columns = {}
    for index, header_cell in enumerate(header):
        text = header_cell.strip().strip('"')
        for key, label in labels.items():
            if label in text:
                columns[key] = index
    return columns


def cell(row: list[str], columns: dict[str, int], key: str) -> str:
    index = columns.get(key)
    return row[index].strip() if index is not None else ""


def to_number(raw: str) -> float | None:
    text = raw.strip().replace("\xa0", "").replace(" ", "")
    if not text or text == CONFIDENTIAL_MARKER:
        return None
    try:
        return float(text.replace(",", "."))
    except ValueError:
        return None


def parse_period(raw: str) -> tuple[int, int | None] | None:
    """Parse a STAZO period label: "01/2024" when monthly, "2024" when annual."""
    monthly = re.fullmatch(r"(\d{1,2})/(\d{4})", raw)
    if monthly:
        return int(monthly.group(2)), int(monthly.group(1))
    annual = re.fullmatch(r"\d{4}", raw)
    if annual:
        return int(raw), None
    return None


def parse_csv(raw: bytes) -> list[dict]:
    """Turn one STAZO CSV export into tidy records."""
    rows = list(csv.reader(io.StringIO(raw.decode("utf-8-sig")), delimiter=";"))
    if len(rows) < 2:
        return []

    header, body = rows[0], rows[1:]
    columns = map_columns(header)
    # country_code is absent by design in the country-free totals query.
    required = {"period", "code", "value"} - columns.keys()
    if required:
        raise RuntimeError(f"Unexpected STAZO CSV layout, missing {required}: {header}")
    value_header = header[columns["value"]]
    if "tis" not in value_header:
        raise RuntimeError(f"Value column is not in thousands: {value_header}")

    width = max(columns.values()) + 1
    records = []
    for row in body:
        if len(row) < width:
            continue
        period = parse_period(cell(row, columns, "period"))
        if period is None:
            continue
        year, month = period
        code = cell(row, columns, "code")
        raw_mass = cell(row, columns, "mass")
        raw_value = cell(row, columns, "value")
        value = to_number(raw_value)
        records.append(
            {
                "commodity": HS_CODES.get(code, code),
                "code": code,
                "code_label": cell(row, columns, "code_label"),
                "period": str(year) if month is None else f"{year}-{month:02d}",
                "year": year,
                "month": month,
                "country_code": cell(row, columns, "country_code"),
                "country_name": cell(row, columns, "country_name"),
                "mass_kg": to_number(raw_mass),
                VALUE_K: value,
                # STAZO blanks out every measure of a cell it cannot disclose.
                "confidential": CONFIDENTIAL_MARKER in {raw_mass, raw_value},
            }
        )
    return records


def fetch_series(
    session: requests.Session, seskup: str, latest: str, by_country: bool
) -> list[dict]:
    """Fetch every year for one period aggregation, one query per year."""
    latest_year, latest_month = int(latest[:4]), int(latest[4:])
    records = []
    for year in range(FIRST_YEAR, latest_year + 1):
        month_to = latest_month if year == latest_year else 12
        form = query_form(year, month_to, seskup, latest, by_country)

        for attempt in range(1, RETRIES + 1):
            try:
                raw = fetch_year_csv(session, form)
                break
            except (requests.RequestException, RuntimeError) as exc:
                log(f"  {year}: attempt {attempt}/{RETRIES} failed ({exc})")
                if attempt == RETRIES:
                    raise
                time.sleep(2**attempt)

        rows = parse_csv(raw)
        hidden = sum(1 for r in rows if r["confidential"])
        suffix = f" ({hidden} confidential)" if hidden else ""
        log(f"  {year}: {len(rows)} rows{suffix}")
        records.extend(rows)
        time.sleep(REQUEST_DELAY)
    return records


def reconcile(rows: list[dict], totals: list[dict]) -> list[dict]:
    """Fill or account for suppressed cells using the country-free totals.

    Returns rows plus any _RESIDUAL rows needed to make the series sum to the total.
    """
    total_by_key = {(t["period"], t["code"]): t for t in totals}
    groups: dict[tuple[str, str], list[dict]] = {}
    for row in rows:
        groups.setdefault((row["period"], row["code"]), []).append(row)

    residual_rows = []
    filled = 0
    for key, group in sorted(groups.items()):
        hidden = [r for r in group if r["confidential"]]
        total = total_by_key.get(key)
        if not hidden or total is None:
            continue

        # Only meaningful where something is actually suppressed; elsewhere the
        # difference would be nothing but per-cell rounding to whole thousands.
        residual = {}
        for field in ("mass_kg", VALUE_K):
            if total[field] is None:
                residual[field] = None
            else:
                disclosed = sum(r[field] or 0 for r in group)
                residual[field] = total[field] - disclosed
        if not any((residual[f] or 0) > 0 for f in ("mass_kg", VALUE_K)):
            continue

        if len(hidden) == 1:
            # The remainder belongs to the single suppressed origin, so name it.
            hidden[0].update(residual)
            hidden[0]["derived"] = True
            filled += 1
        else:
            template = hidden[0]
            residual_rows.append(
                {
                    **template,
                    "country_code": RESIDUAL_CODE,
                    "country_name": f"Residual of {len(hidden)} suppressed origins",
                    **residual,
                    "confidential": False,
                    "derived": True,
                }
            )

    log(f"  recovered {filled} suppressed cells; {len(residual_rows)} residual rows")
    return rows + residual_rows


def write_csv(path: Path, records: list[dict], monthly: bool) -> None:
    fields = [
        "commodity",
        "code",
        "code_label",
        "period",
        "year",
        *(["month"] if monthly else []),
        "country_code",
        "country_name",
        "mass_kg",
        VALUE_FIELD,
        "confidential",
        "derived",
    ]
    records.sort(key=lambda r: (r["commodity"], r["period"], r["country_code"]))
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for record in records:
            thousands = record[VALUE_K]
            writer.writerow(
                {
                    **record,
                    # Thousands are whole numbers, so millions are exact to 3 places.
                    VALUE_FIELD: (
                        None if thousands is None else round(thousands / 1000, 3)
                    ),
                    "derived": record.get("derived", False),
                }
            )

    still_hidden = sum(1 for r in records if r[VALUE_K] is None)
    log(f"Wrote {len(records)} rows to {path} ({still_hidden} with no value)")


def main() -> int:
    session = requests.Session()
    session.headers["User-Agent"] = "faktaoklimatu-data-analysis (+faktaoklimatu.cz)"
    session.headers["Referer"] = FORM_URL

    latest = fetch_latest_period(session)
    log(f"STAZO holds data up to {latest[:4]}-{latest[4:]}")

    massless: set[int] = set()
    for seskup, path in OUTPUTS.items():
        label = "monthly" if seskup == "M" else "annual"
        log(f"{label} aggregation, by country")
        by_country = fetch_series(session, seskup, latest, by_country=True)
        log(f"{label} aggregation, country-free totals")
        totals = fetch_series(session, seskup, latest, by_country=False)
        records = reconcile(by_country, totals)
        write_csv(path, records, monthly=seskup == "M")
        with_mass = {r["year"] for r in records if r["mass_kg"] is not None}
        massless |= {r["year"] for r in records} - with_mass

    if massless:
        years = ", ".join(str(y) for y in sorted(massless))
        log(
            f"Note: mass_kg is empty for {years} - ČSÚ publishes no net mass in its "
            "aggregated tables for those years. Values in CZK are complete."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
