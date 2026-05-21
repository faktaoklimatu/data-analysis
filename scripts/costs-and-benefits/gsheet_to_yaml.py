#!/usr/bin/env python
"""Read costs-and-benefits measure data from a published Google Sheet and emit YAML.

Usage:
    python gsheet_to_yaml.py [spreadsheet_id]

Outputs a YAML dict with keys buildings_measures and transport_measures,
each a flat list of records.

The spreadsheet must be published to the web (File → Share → Publish to web).
"""
import argparse
import logging
import math
import sys
from io import StringIO
from typing import Any

import pandas as pd
import requests
import yaml

SPREADSHEET_ID = "1tnhFlX23FLM-zTSi0sgqf3u2vdPSAWoGQmVF7DMuoRM"

# Sheet GIDs
SHEET_BUILDINGS = 1550692551
SHEET_TRANSPORT = 1298113092
SHEET_FUEL_FACTORS = 290409297
SHEET_CARBON_COST = 1410388641
SHEET_DISCOUNT_RATE = 1688519708
SHEET_FUEL_SCENARIOS = 51297067
SHEET_ELECTRICITY_TARIFFS = 804935784


def fetch_sheet(spreadsheet_id: str, gid: int) -> StringIO:
    url = (
        f"https://docs.google.com/spreadsheets/d/{spreadsheet_id}"
        f"/export?format=csv&gid={gid}"
    )
    logger = logging.getLogger()
    logger.debug(f"Fetching gid={gid} from {url}")
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    return StringIO(resp.content.decode("utf-8"))


def _clean_value(v: Any, error_default: Any = None) -> Any:
    """Return error_default for NaN, pd.NA, and formula errors; pass through otherwise."""
    if v is pd.NA:
        return error_default
    if isinstance(v, float) and math.isnan(v):
        return error_default
    if isinstance(v, str) and v.startswith("#"):
        return error_default
    return v


def _parse_number(v: Any) -> Any:
    """Parse comma-thousands-formatted numbers like '85,000' → 85000."""
    if not isinstance(v, str):
        return v
    stripped = v.replace(",", "")
    try:
        as_int = int(stripped)
        return as_int
    except ValueError:
        pass
    try:
        return float(stripped)
    except ValueError:
        return v


STRING_COLS = {
    "Building_category",
    "Transport_category",
    "Measure_name",
    "Fuel",
    "Measure_baseline",
    "Note",
}

NUMERIC_COLS = {
    "Dwellings",
    "Demand_heat_building_MWh",
    "Demand_electricity_MWh",
    "Capacity_kW",
    "Efficiency",
    "Demand_heat_measure_MWh",
    "Demand_electricity_measure_MWh",
    "Lifetime",
    "Energy_savings",
    "Electricity_savings",
    "CAPEX_technology_CZK",
    "CAPEX_installation_CZK",
    "CAPEX_preparation_CZK",
    "OPEX_maintenance_CZK",
    "Emissions_embedded_kg",
    "Emissions_operational",
    "Demand_energy_per_100km",
    "Mileage",
    "CAPEX_CZK",
    "OPEX_insurance_CZK",
    "OPEX_repairs_CZK",
    "Emissions_direct",
    "Emissions_indirect",
    "Measure_baseline_id",
}


def _lowercase_keys(obj: Any) -> Any:
    """Recursively lowercase all dict keys."""
    if isinstance(obj, dict):
        return {k.lower(): _lowercase_keys(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_lowercase_keys(item) for item in obj]
    return obj


def read_simple_sheet(spreadsheet_id: str, gid: int, skiprows: int) -> list[dict]:
    """Read a small lookup table into a flat list of dicts, parsing all numeric values."""
    csv = fetch_sheet(spreadsheet_id, gid)
    df = pd.read_csv(csv, skiprows=skiprows)
    df = df.loc[:, ~df.columns.str.startswith("Unnamed")]
    records = []
    for _, row in df.iterrows():
        record = {}
        for col, val in row.items():
            cleaned = _clean_value(val)
            if cleaned is not None:
                record[col] = _parse_number(cleaned)
        records.append(record)
    return records


def read_fuel_scenarios(spreadsheet_id: str) -> list[dict]:
    """Parse the wide fuel-price table into a list of {scenario, prices} dicts."""
    csv = fetch_sheet(spreadsheet_id, SHEET_FUEL_SCENARIOS)
    # Skip unit row; row 0 = scenario labels, row 1 = column names, row 2+ = data
    df = pd.read_csv(csv, header=None, skiprows=1)

    # Find where each scenario block starts by scanning for non-empty labels in row 0.
    # This handles blocks of different widths (e.g. one scenario has an extra column).
    scenario_starts: list[tuple[int, str]] = [
        (col, str(val))
        for col, val in enumerate(df.iloc[0])
        if col >= 2 and str(val) not in ("nan", "")
    ]
    shared_cols = list(df.iloc[1, :2])  # Year_Calendar, Year_Investment
    data_rows = df.iloc[2:].reset_index(drop=True)

    # Collect year rows per scenario, merging multiple column blocks with the same name.
    scenario_order: list[str] = []
    scenario_rows: dict[str, list[dict]] = {}

    for i, (col_start, scenario) in enumerate(scenario_starts):
        col_end = scenario_starts[i + 1][0] if i + 1 < len(scenario_starts) else len(df.columns)
        fuel_cols = list(df.iloc[1, col_start:col_end])

        if scenario not in scenario_rows:
            scenario_order.append(scenario)
            scenario_rows[scenario] = [
                {shared_cols[0]: int(row[0]), shared_cols[1]: int(row[1])}
                for _, row in data_rows.iterrows()
            ]

        for row_idx, (_, row) in enumerate(data_rows.iterrows()):
            for j, col in enumerate(fuel_cols):
                val = _clean_value(row[col_start + j])
                if val is not None:
                    scenario_rows[scenario][row_idx][col] = _parse_number(val)

    return [{"scenario": s, "prices": scenario_rows[s]} for s in scenario_order]


def read_sheet(spreadsheet_id: str, gid: int) -> pd.DataFrame:
    csv = fetch_sheet(spreadsheet_id, gid)
    df = pd.read_csv(csv, skiprows=2)

    for col in NUMERIC_COLS:
        if col in df.columns:
            df[col] = df[col].apply(lambda v: _clean_value(v, 0)).apply(_parse_number)

    return df


def assign_ids_and_resolve_baselines(
    df_buildings: pd.DataFrame, df_transport: pd.DataFrame
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Add a unique int 'id' to each row (across both tables) and replace
    Measure_baseline name strings with the id of the referenced measure."""
    df_buildings = df_buildings.copy()
    df_transport = df_transport.copy()

    n = len(df_buildings)
    df_buildings.insert(0, "id", range(1, n + 1))
    df_transport.insert(0, "id", range(n + 1, n + len(df_transport) + 1))

    # Build lookup: (category_value, measure_name) → id
    lookup: dict[tuple[str, str], int] = {}
    for _, row in df_buildings.iterrows():
        lookup[(row["Building_category"], row["Measure_name"])] = row["id"]
    for _, row in df_transport.iterrows():
        lookup[(row["Transport_category"], row["Measure_name"])] = row["id"]

    for df, cat_col in [(df_buildings, "Building_category"), (df_transport, "Transport_category")]:
        baseline_ids = {}
        for idx, row in df.iterrows():
            baseline = row.get("Measure_baseline")
            if pd.isna(baseline) or str(baseline).startswith("#"):
                continue
            key = (row[cat_col], baseline)
            if key not in lookup:
                raise ValueError(
                    f"Baseline '{baseline}' not found in category '{row[cat_col]}'"
                    f" (referenced by measure '{row['Measure_name']}')"
                )
            baseline_ids[idx] = lookup[key]
        df["Measure_baseline_id"] = pd.Series(baseline_ids, dtype="Int64")

    return df_buildings, df_transport


KEEP_COLS = STRING_COLS | NUMERIC_COLS | {"id"}


def df_to_yaml_list(df: pd.DataFrame) -> list[dict]:
    records = []
    for _, row in df.iterrows():
        record = {}
        for col, val in row.items():
            if col not in KEEP_COLS:
                continue
            cleaned = _clean_value(val)
            if cleaned is not None:
                record[col] = cleaned
        records.append(record)
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "spreadsheet_id",
        nargs="?",
        default=SPREADSHEET_ID,
        help="Google Sheets spreadsheet ID",
    )
    args = parser.parse_args()

    logging.basicConfig(
        format="%(levelname)s [%(asctime)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        level=logging.DEBUG,
        stream=sys.stderr,
    )

    logger = logging.getLogger()
    sid = args.spreadsheet_id

    logger.info("Reading buildings measures from GSheet...")
    df_buildings = read_sheet(sid, SHEET_BUILDINGS)

    logger.info("Reading transport measures from GSheet...")
    df_transport = read_sheet(sid, SHEET_TRANSPORT)

    logger.info("Assigning IDs and resolving baselines...")
    df_buildings, df_transport = assign_ids_and_resolve_baselines(df_buildings, df_transport)

    logger.info("Reading lookup tables from GSheet...")
    fuel_factors = read_simple_sheet(sid, SHEET_FUEL_FACTORS, skiprows=3)
    carbon_costs = read_simple_sheet(sid, SHEET_CARBON_COST, skiprows=1)
    discount_rates = read_simple_sheet(sid, SHEET_DISCOUNT_RATE, skiprows=1)
    electricity_tariffs = read_simple_sheet(sid, SHEET_ELECTRICITY_TARIFFS, skiprows=1)
    fuel_scenarios = read_fuel_scenarios(sid)

    logger.info("Exporting YAML...")
    result = {
        "buildings_measures": df_to_yaml_list(df_buildings),
        "transport_measures": df_to_yaml_list(df_transport),
        "fuel_emission_factors": fuel_factors,
        "carbon_cost_scenarios": carbon_costs,
        "discount_rate_scenarios": discount_rates,
        "electricity_price_scenarios": electricity_tariffs,
        "fuel_scenarios": fuel_scenarios,
    }
    yaml.dump(_lowercase_keys(result), sys.stdout, allow_unicode=True, sort_keys=False, width=math.inf)
    logger.info("Finished")


if __name__ == "__main__":
    main()
