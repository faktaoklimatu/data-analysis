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
    transform,
)

INSTALLATIONS_OVERVIEW_PATH = Path("data/EUA/ets-installations-overview.csv")


def main() -> None:
    long_df = transform()

    per_install = long_df.groupby("INSTALLATION_IDENTIFIER").agg(
        installation_name=("INSTALLATION_NAME", "first"),
        installation_name_clean=("INSTALLATION_NAME_CLEAN", "first"),
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
        "Název provozovatele:": "company_name_moe",
        "Adresa zařízení": "installation_address",
    })[["installation_id", "company_name_moe", "installation_address"]]

    merged = per_install.merge(opok, on="installation_id", how="left")

    merged = merged.rename(columns={
        "installation_id": "Installation ID",
        "installation_name": "Installation Name",
        "installation_name_clean": "Installation Name (Clean)",
        "company_name_moe": "Company Name (MoE)",
        "installation_address": "Installation Address",
        "first_verified_emissions_year": "First Verified Emissions Year",
        "last_verified_emissions_year": "Last Verified Emissions Year",
        "main_activity_code": "Main Activity Code",
        "main_activity_name": "Main Activity Name",
    })

    column_order = [
        "Installation ID",
        "Installation Name",
        "Installation Name (Clean)",
        "Company Name (MoE)",
        "Installation Address",
        "First Verified Emissions Year",
        "Last Verified Emissions Year",
        "Main Activity Code",
        "Main Activity Name",
    ]
    merged[column_order].to_csv(INSTALLATIONS_OVERVIEW_PATH, index=False)

    cleaned = (merged["Installation Name (Clean)"] != merged["Installation Name"]).sum()
    print(f"{len(merged)} installations, {merged['Company Name (MoE)'].notna().sum()} matched in OPOK, "
          f"{cleaned} names cleaned up")


if __name__ == "__main__":
    main()
