#!/usr/bin/env python
"""Download annual Czech GDP in nominal CZK from ČSÚ DataStat -> output-dashboard/gdp.csv.

    python fetch_gdp.py

DataStat has a real API (https://csu.gov.cz/zakladni-informace-pro-pouziti-api-datastatu).
The data is dataset NUC06R, "Hlavní souhrnné ukazatele HDP - roční údaje". We query the
dataset rather than the predefined DataStat selection because that pins its list of
years by hand, whereas an empty year filter picks up new years by itself; `verzeSady` is
left off so the API serves the current version.
"""
import csv
import io
import sys

from common import log, new_session, write_csv

API = "https://data.csu.gov.cz/api"
DATASET = "NUC06R"
# Gross domestic product, mil. CZK at current (nominal) prices.
INDICATOR = "9988S03"


def fetch_csv(session) -> str:
    query = {
        # For CSV it does not matter which of the lists a dimension goes into.
        "sloupce": [
            {"kodDimenze": "IndicatorType", "filtr": [{"zobrazitPolozky": [INDICATOR]}]},
            # An empty filter means every year, so new years need no code change.
            {"kodDimenze": "CasR", "filtr": []},
            # Czechia as a whole, all industries together.
            {"kodDimenze": "Uz012", "filtr": [{"zobrazitPolozky": ["CZ"]}]},
            {"kodDimenze": "NACEHDP", "filtr": [{"zobrazitPolozky": ["0"]}]},
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
    return resp.content.decode("utf-8-sig")


def main() -> int:
    session = new_session()
    session.headers["Accept-Language"] = "cs"
    rows = list(csv.DictReader(io.StringIO(fetch_csv(session))))
    if not rows:
        log("No data returned")
        return 1
    missing = {"CasR", "Hodnota"} - rows[0].keys()
    if missing:
        raise RuntimeError(f"Unexpected DataStat CSV layout, missing {missing}")

    # A year with no value is nothing for a chart to draw, so leave it out.
    gdp = sorted(
        (int(row["CasR"]), float(row["Hodnota"]))
        for row in rows
        if row["Hodnota"].strip()
    )
    write_csv(
        "gdp.csv",
        [{"year": year, "value_mil_czk": value} for year, value in gdp],
        ["year", "value_mil_czk"],
    )
    log(f"  years {gdp[0][0]}-{gdp[-1][0]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
