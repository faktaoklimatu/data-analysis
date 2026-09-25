#!/usr/bin/env python
"""Regenerate ets-installations-overview.csv: one row per installation, with
the ministry (OPOK) permit id/company/address and the current EUTL data's
verified-emissions year range and sector classification."""
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from process_verified_emissions import (  # noqa: E402
    GROUP_LABELS,
    OPOK_PATH,
    SECTOR_GROUP,
    build_installation_years,
)

INSTALLATIONS_OVERVIEW_PATH = Path("outputs/ets-dashboard/ets-installations-overview.csv")

# Internal column name -> output header, in the order the CSV should have.
OUTPUT_COLUMNS = {
    "installation_id": "Installation ID",
    "installation_name": "Installation Name",
    "operator_name_moe": "Operator Name (MoE)",
    "installation_address": "Installation Address",
    "first_verified_emissions_year": "First Verified Emissions Year",
    "last_verified_emissions_year": "Last Verified Emissions Year",
    "main_activity_code": "Main Activity Code",
    "main_activity_name": "Main Activity Name",
}


def main() -> None:
    # One row per Czech installation per year, with emissions/allocation
    # data and the manual-overrides sheet already merged in.
    long_df = build_installation_years()

    per_install = long_df.groupby("INSTALLATION_IDENTIFIER").agg(
        installation_name=("INSTALLATION_NAME", "first"),
        permit_identifier=("PERMIT_IDENTIFIER", "first"),
        first_verified_emissions_year=("PERIOD_YEAR", "min"),
        last_verified_emissions_year=("PERIOD_YEAR", "max"),
        main_activity_code=("MAIN_ACTIVITY_TYPE_CODE", "first"),
    ).reset_index(drop=True)

    per_install["main_activity_name"] = per_install["main_activity_code"].map(
        lambda code: GROUP_LABELS[SECTOR_GROUP.get(code, "other")]
    )
    per_install["installation_id"] = per_install["permit_identifier"].str.extract(r"^(CZ-\d+)")[0]

    opok = pd.read_excel(OPOK_PATH, sheet_name="ETS1_20260209")
    opok = opok.rename(columns={
        "ID zařízení:": "installation_id",
        "Název provozovatele:": "operator_name_moe",
        "Adresa zařízení": "installation_address",
    })[["installation_id", "operator_name_moe", "installation_address"]]

    merged = per_install.merge(opok, on="installation_id", how="left")
    merged = merged.rename(columns=OUTPUT_COLUMNS)[list(OUTPUT_COLUMNS.values())]
    merged.to_csv(INSTALLATIONS_OVERVIEW_PATH, index=False)

    print(f"{len(merged)} installations, {merged['Operator Name (MoE)'].notna().sum()} matched in OPOK")


if __name__ == "__main__":
    main()
