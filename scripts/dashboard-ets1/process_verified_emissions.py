#!/usr/bin/env python
"""Build the data the ETS1 dashboard (faktaoklimatu.cz) needs from the EUTL
verified emissions export (2008-2025): a flat per-installation-per-year CSV,
and a compact pre-aggregated YAML (installations, per-sector activity
groups, yearly records) that the dashboard page loads directly.
"""
import sys
from pathlib import Path

import pandas as pd
import yaml

# Bump the end year when updating the verified emissions file.
INPUT_PATH = Path("data/EUA/verified_emissions_2025_en.xlsx")
YEARS = range(2008, 2026)  # Note stop is exclusive in range. Must be end year+1.

OUTPUT_CSV_PATH = Path("outputs/ets-dashboard/ETS-data.csv")
OUTPUT_YAML_PATH = Path("outputs/ets-dashboard/output-ets-dashboard.yaml")

# "Přehled instalací" sheet of the live ETS dashboard Google Sheet.
MANUAL_OVERRIDES_SHEET_ID = "1DX6MGLeiKXbGsPxHH9HwjuK7qOFl27XdsFu5CzDWH1Y"
MANUAL_OVERRIDES_SHEET_GID = "814098780"
MANUAL_OVERRIDES_URL = (
    f"https://docs.google.com/spreadsheets/d/{MANUAL_OVERRIDES_SHEET_ID}/export"
    f"?format=csv&gid={MANUAL_OVERRIDES_SHEET_GID}"
)

MANUAL_OVERRIDE_COLUMNS = {
    "Installation Name (Clean)": "INSTALLATION_NAME_CLEAN",
    "Operator Name (Clean)": "OPERATOR_NAME_CLEAN",
    "Real Activity": "REAL_ACTIVITY",
    "Owner Assigned": "OWNER_ASSIGNED",
}

ID_COLUMNS = [
    "REGISTRY_CODE",
    "IDENTIFIER_IN_REG",
    "INSTALLATION_NAME",
    "INSTALLATION_IDENTIFIER",
    "PERMIT_IDENTIFIER",
    "MAIN_ACTIVITY_TYPE_CODE",
    "MAIN_ACTIVITY_TYPE_NAME",
    *MANUAL_OVERRIDE_COLUMNS.values(),
]

# Metrics to unpivot; not every metric exists for every year (RESERVE/TRANSITIONAL
# only exist from 2013 onward).
ALLOCATION_METRICS = ["ALLOCATION", "ALLOCATION_RESERVE", "ALLOCATION_TRANSITIONAL"]
METRICS = ALLOCATION_METRICS + ["VERIFIED_EMISSIONS"]

# Aircraft/maritime operator activity codes; these are airlines and shipping
# companies, not industrial plants, so they're dropped from the dataset.
AVIATION_MARITIME_CODES = [10, 50]

# Code 60 is a member-state ETS2 placeholder account (e.g. "ETS2 účet České
# republiky"), not a real installation, so it's dropped from the dataset too.
ETS2_PLACEHOLDER_CODES = [60]

# Manual overrides for installations misclassified as code 99 ("Other
# activity opted-in") in the source file; keyed by PERMIT_IDENTIFIER.
ACTIVITY_CODE_OVERRIDES = {
    "CZ-0457-13": 37,  # CS CABOT, spol. s r.o. -> Production of carbon black
    "CZ-0139-05": 20,  # Dřevozpracující družstvo - Kotelny družstva -> Combustion of fuels
    "CZ-0496-25": 34,  # Kalcinační jednotka Vřesová -> Production/processing of gypsum or plasterboard
}

# Raw EU ETS activity-type code -> broad sector group key.
SECTOR_GROUP = {
    1: "combustion", 20: "combustion",
    2: "refineries", 21: "refineries",
    4: "iron_steel", 5: "iron_steel", 22: "iron_steel", 23: "iron_steel",
    24: "iron_steel", 25: "iron_steel",
    26: "aluminium", 27: "aluminium", 28: "other_metals",
    6: "cement_lime", 29: "cement_lime", 30: "cement_lime",
    7: "glass", 31: "glass", 8: "other_minerals",
    32: "other_minerals", 33: "other_minerals", 34: "other_minerals",
    9: "pulp_paper", 35: "pulp_paper", 36: "pulp_paper",
    37: "chemicals", 38: "chemicals", 39: "chemicals", 40: "chemicals",
    41: "chemicals", 42: "chemicals", 43: "chemicals", 44: "chemicals",
    45: "other", 99: "other",
}

# This dict also encodes the order of groups in the output.
GROUP_LABELS = {
    "combustion": "Výroba elektřiny a tepla",
    "refineries": "Rafinace minerálních olejů",
    "iron_steel": "Železo a ocel",
    "aluminium": "Hliníku",
    "other_metals": "Ostatní kovy",
    "cement_lime": "Cement a vápno",
    "glass": "Sklo",
    "other_minerals": "Ostatní minerály (keramika, cihly, minerální vlna, sádra)",
    "pulp_paper": "Papír",
    "chemicals": "Chemikálie",
    "other": "Ostatní odvětví",
}

COUNTRY_NAME = "Česko"  # only CZ installations are kept, see build_installation_years()


def year_column(metric: str, year: int) -> str:
    if year == 2008 and metric == "ALLOCATION":
        return "ALLOCATION2008"  # inconsistent naming in the source file
    return f"{metric}_{year}"


def or_none(value):
    return None if pd.isna(value) else value


def get_sector_group_label(code) -> str:
    return GROUP_LABELS[SECTOR_GROUP.get(code, "other")]


def load_manual_overrides() -> pd.DataFrame | None:
    """Hand-curated columns from the live "Přehled instalací" Google Sheet,
    keyed by "Installation ID" (the "CZ-XXXX" prefix of PERMIT_IDENTIFIER).
    Returns None if the sheet can't be fetched (e.g. no network access, or
    the sheet's sharing settings changed), so the pipeline still runs with
    those columns simply left blank."""
    try:
        raw = pd.read_csv(MANUAL_OVERRIDES_URL, header=None)
    except (OSError, pd.errors.ParserError) as e:
        print(f"WARNING: couldn't load manual overrides sheet ({e}); leaving those columns blank.",
              file=sys.stderr)
        return None

    # The sheet may have a free-text note row above the real header (people
    # edit this sheet by hand), so find the header by content instead of by
    # a fixed row number.
    header_rows = raw.index[raw.iloc[:, 0] == "Installation ID"]
    if header_rows.empty:
        print("WARNING: couldn't find the \"Installation ID\" header row in the "
              "manual overrides sheet; leaving those columns blank.", file=sys.stderr)
        return None

    header_row = header_rows[0]
    edited = raw.iloc[header_row + 1:].reset_index(drop=True)
    edited.columns = raw.iloc[header_row]

    present = [col for col in MANUAL_OVERRIDE_COLUMNS if col in edited.columns]
    return edited[["Installation ID", *present]].rename(columns=MANUAL_OVERRIDE_COLUMNS)


def build_installation_years() -> pd.DataFrame:
    df = pd.read_excel(INPUT_PATH, sheet_name="data", header=2)
    df = df[df["REGISTRY_CODE"] == "CZ"]

    activity_codes = pd.read_excel(INPUT_PATH, sheet_name="activity codes")
    activity_names = activity_codes.set_index("code")["new descriptions aligned"]

    overridden_code = df["PERMIT_IDENTIFIER"].map(ACTIVITY_CODE_OVERRIDES)
    df["MAIN_ACTIVITY_TYPE_CODE"] = overridden_code.fillna(df["MAIN_ACTIVITY_TYPE_CODE"]).astype(int)
    df["MAIN_ACTIVITY_TYPE_NAME"] = df["MAIN_ACTIVITY_TYPE_CODE"].map(activity_names)

    df = df[~df["MAIN_ACTIVITY_TYPE_CODE"].isin(AVIATION_MARITIME_CODES + ETS2_PLACEHOLDER_CODES)]

    installation_id = df["PERMIT_IDENTIFIER"].str.extract(r"^(CZ-\d+)")[0]

    # Falls back to an empty frame if the sheet can't be fetched, so every
    # expected column still ends up in df (as all-blank) rather than the
    # merge being skipped.
    manual_overrides = load_manual_overrides()
    if manual_overrides is None:
        manual_overrides = pd.DataFrame(columns=["Installation ID", *MANUAL_OVERRIDE_COLUMNS.values()])
    df = df.merge(
        manual_overrides, how="left", left_on=installation_id, right_on="Installation ID"
    ).drop(columns="Installation ID")

    # Backfill any expected column the sheet doesn't have right now (e.g. a
    # column was temporarily removed/renamed in the sheet) so the pipeline
    # degrades to blank values instead of crashing later on.
    for column in MANUAL_OVERRIDE_COLUMNS.values():
        if column not in df.columns:
            df[column] = pd.NA

    # INSTALLATION_NAME_CLEAN drives the dashboard's installation name, so
    # it must never be blank; fall back to the raw name if the sheet has no
    # clean version yet for this installation (or couldn't be reached).
    df["INSTALLATION_NAME_CLEAN"] = df["INSTALLATION_NAME_CLEAN"].fillna(df["INSTALLATION_NAME"])

    year_frames = []
    for year in YEARS:
        frame = df[ID_COLUMNS].copy()
        frame["PERIOD_YEAR"] = year
        for metric in METRICS:
            col = year_column(metric, year)
            frame[metric] = df[col] if col in df.columns else pd.NA
        year_frames.append(frame)

    long_df = pd.concat(year_frames, ignore_index=True)

    # VERIFIED_EMISSIONS mixes the numeric -1 (missing) sentinel with the
    # literal string "Excluded"; normalize both to -1, then drop those rows.
    long_df["VERIFIED_EMISSIONS"] = pd.to_numeric(
        long_df["VERIFIED_EMISSIONS"].replace("Excluded", -1)
    )
    long_df = long_df[long_df["VERIFIED_EMISSIONS"] != -1]

    # -1 marks missing data and NaN marks a field that didn't exist yet for
    # that year (pre-2013); treat both as 0 so FREE_ALLOCATION is directly
    # comparable to VERIFIED_EMISSIONS.
    allocation_cols = long_df[ALLOCATION_METRICS].apply(pd.to_numeric)
    long_df["FREE_ALLOCATION"] = allocation_cols.replace(-1, 0).fillna(0).sum(axis=1)

    return long_df


def build_dashboard_data(df: pd.DataFrame) -> dict:
    """Aggregate the flat dataframe into the compact dashboard structure
    the ETS1 page loads directly (installations deduplicated, activity
    codes grouped into broad sectors)."""
    codes_in_data = df["MAIN_ACTIVITY_TYPE_CODE"].unique().tolist()
    unmapped_codes = [code for code in codes_in_data if code not in SECTOR_GROUP]
    if unmapped_codes:
        print(
            f"WARNING: unmapped MAIN_ACTIVITY_TYPE_CODE value(s) {unmapped_codes} "
            "-- add them to SECTOR_GROUP. Falling back to the \"other\" group for now.",
            file=sys.stderr,
        )

    group_index = {group: i for i, group in enumerate(GROUP_LABELS)}
    activities = [
        {"n": GROUP_LABELS[group], "short": GROUP_LABELS[group]}
        for group in GROUP_LABELS.keys()
    ]

    install_index: dict[int, int] = {}
    installs = []
    records = []

    for row in df.itertuples(index=False):
        act_i = group_index[SECTOR_GROUP.get(row.MAIN_ACTIVITY_TYPE_CODE, "other")]

        inst_i = install_index.get(row.INSTALLATION_IDENTIFIER)
        if inst_i is None:
            installs.append({
                "n": row.INSTALLATION_NAME_CLEAN,
                "c": row.REGISTRY_CODE,
                "act": act_i,
                "own": or_none(row.OWNER_ASSIGNED),
                "operator": or_none(row.OPERATOR_NAME_CLEAN),
                "ra": or_none(row.REAL_ACTIVITY),
            })
            inst_i = install_index[row.INSTALLATION_IDENTIFIER] = len(installs) - 1

        emissions = None if pd.isna(row.VERIFIED_EMISSIONS) else round(row.VERIFIED_EMISSIONS)
        allocation = 0 if pd.isna(row.FREE_ALLOCATION) else round(row.FREE_ALLOCATION)
        records.append([inst_i, int(row.PERIOD_YEAR), emissions, allocation])

    countries = [{"c": "CZ", "n": COUNTRY_NAME}]

    return {
        "countries": countries,
        "activities": activities,
        "installs": installs,
        "records": records,
        "year_min": int(df["PERIOD_YEAR"].min()),
        "year_max": int(df["PERIOD_YEAR"].max()),
    }


def build_csv_export(long_df: pd.DataFrame) -> pd.DataFrame:
    """ETS-data.csv's own column order: identifiers, then raw names, then
    the names/company derived from them, then activity classification,
    then the yearly emissions/allocation time series. Also renames the
    allocation breakdown so the "a+b+c" sum relationship is visible in the
    headers."""
    csv_df = long_df.rename(columns={
        "ALLOCATION": "a_ALLOCATION",
        "ALLOCATION_RESERVE": "b_ALLOCATION_RESERVE",
        "ALLOCATION_TRANSITIONAL": "c_ALLOCATION_TRANSITIONAL",
        "FREE_ALLOCATION": "FREE_ALLOCATION (a+b+c)",
    })

    column_order = [
        "REGISTRY_CODE", "INSTALLATION_IDENTIFIER", "PERMIT_IDENTIFIER",
        "INSTALLATION_NAME", "IDENTIFIER_IN_REG",
        "INSTALLATION_NAME_CLEAN", "OPERATOR_NAME_CLEAN", "OWNER_ASSIGNED",
        "MAIN_ACTIVITY_TYPE_CODE", "MAIN_ACTIVITY_TYPE_NAME", "REAL_ACTIVITY",
        "PERIOD_YEAR", "VERIFIED_EMISSIONS", "FREE_ALLOCATION (a+b+c)",
        "a_ALLOCATION", "b_ALLOCATION_RESERVE", "c_ALLOCATION_TRANSITIONAL",
    ]
    return csv_df[column_order]


def main() -> None:
    long_df = build_installation_years()
    build_csv_export(long_df).to_csv(OUTPUT_CSV_PATH, index=False)

    dashboard_data = build_dashboard_data(long_df)
    with OUTPUT_YAML_PATH.open("w", encoding="utf-8") as f:
        yaml.dump(dashboard_data, f, allow_unicode=True, sort_keys=False)

    print(
        f"{len(dashboard_data['installs'])} installations, "
        f"{len(dashboard_data['records'])} records, "
        f"{len(dashboard_data['countries'])} countries"
    )


if __name__ == "__main__":
    main()
