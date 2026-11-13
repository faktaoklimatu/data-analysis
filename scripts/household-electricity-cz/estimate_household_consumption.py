#!/usr/bin/env python
"""Estimate of the hourly electricity consumption (MW) of Czech households
(all D tariffs) in 2025.

OTE publishes recalculated typical delivery profiles (TDD, "přepočtené TDD",
15-minute relative values recalculated to actual weather) for 8 customer
classes. Households fall into classes 4-7 (annex 6 of decree 408/2015 Sb.).
Each class profile is scaled so that its annual sum equals the billed
consumption of the D tariffs in that class, taken from the ERÚ yearly report
(tariff statistics). The classes are then summed.

Usage (from the repo root):
    python scripts/household-electricity-cz/estimate_household_consumption.py
    python scripts/household-electricity-cz/estimate_household_consumption.py --skip-download
"""
import argparse
import sys
import urllib.request
import zipfile
from pathlib import Path

import pandas as pd

YEAR = 2025
TDD_URL = "https://www.ote-cr.cz/attachments/29/2025/Prepoctene_TDD_15MIN_2025_CZ.zip"
RAW_DIR = Path("temp/ote-tdd-2025")
TDD_FILE = "Prepoctene_TDD_2025_CZ.xlsx"
OUTPUT_CSV_PATH = Path("outputs/output-household-electricity-cz-2025-hourly.csv")

# The OTE file has days in Czech local time (92 / 100 periods on the days of
# summer time shifts). The output uses fixed CET (UTC+1, no summer time) like
# the rooftop solar curve in scripts/solar-rooftop-cz; "Etc/GMT-1" is UTC+1
# (the sign is inverted in the tz database).
LOCAL_TZ = "Europe/Prague"
CET_TZ = "Etc/GMT-1"

# Tariff statistics 2025, ERÚ yearly report 2025, table 10.6, group "Maloodběr
# obyvatelstvo (MOO)": total billed consumption in MWh. NOTE: covers only the
# three largest regional distribution systems and the electricity billed in
# documents issued in 2025, so it differs from consumption in other statistics.
TARIFF_CONSUMPTION_MWH = {
    "D01d": 536_108,
    "D02d": 4_557_726,
    "D25d": 3_504_118,
    "D26d": 340_267,
    "D27d": 14_189,
    "D35d": 61_539,
    "D45d": 2_981_328,
    "D56d": 600_766,
    "D57d": 3_105_144,
    "D61d": 6_781,
}
TARIFF_CONSUMPTION_TOTAL_MWH = 15_707_966  # "MOO" row, for checking the above

# Annex 6 of decree 408/2015 Sb., customer category D.
TARIFF_TDD_CLASS = {
    "D01d": 4, "D02d": 4, "D61d": 4,  # without thermal use of electricity
    "D25d": 5, "D26d": 5, "D27d": 5,  # accumulation heating
    "D35d": 6,  # hybrid heating
    "D45d": 7, "D57d": 7,  # direct heating
    "D56d": 7,  # heat pump
}
# TDD class 5 is published separately for 8 regions; the regional profiles are
# normalised to unit annual sum and averaged with these weights (None = equal).
# There are no per-region tariff statistics, so equal weights are an assumption.
TDD5_REGION_WEIGHTS = None


def download(raw_dir: Path) -> None:
    raw_dir.mkdir(parents=True, exist_ok=True)
    zip_path = raw_dir / Path(TDD_URL).name
    print(f"Downloading {TDD_URL}")
    urllib.request.urlretrieve(TDD_URL, zip_path)
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(raw_dir)
    zip_path.unlink()


def read_tdd(path: Path) -> pd.DataFrame:
    """15-minute relative values, columns "TDD<class> <region>", indexed by CET time."""
    df = pd.read_excel(path, header=4, skiprows=[5])
    df.columns = [str(c).replace("\n", " ") for c in df.columns]
    # Local midnight plus elapsed 15-minute periods (so the 92/100 period
    # days of summer time shifts come out right).
    start = pd.to_datetime(df["Den"]).dt.tz_localize(LOCAL_TZ)
    time = (start + pd.to_timedelta((df["Perioda"] - 1) * 15, unit="min")).dt.tz_convert(CET_TZ)
    df = df.drop(columns=["Den", "Perioda", "Časový interval"]).set_index(pd.DatetimeIndex(time))
    if df.isna().any().any():
        sys.exit("Missing values in the TDD file")
    steps = df.index.to_series().diff().dropna().unique()
    expected = pd.date_range(f"{YEAR}-01-01", f"{YEAR + 1}-01-01", freq="15min", inclusive="left", tz=CET_TZ)
    if len(steps) != 1 or not df.index.equals(expected):
        sys.exit("TDD timestamps are not one complete CET year of 15-minute values")
    return df


def class_profile(tdd: pd.DataFrame, tdd_class: int) -> pd.Series:
    """Share of the annual consumption in each 15 minutes (sums to 1)."""
    columns = [c for c in tdd.columns if c.startswith(f"TDD{tdd_class} ")]
    if not columns:
        sys.exit(f"No columns for TDD{tdd_class}")
    shares = tdd[columns] / tdd[columns].sum()
    weights = TDD5_REGION_WEIGHTS if tdd_class == 5 else None
    if weights is None:
        return shares.mean(axis=1)
    return (shares * pd.Series(weights)[[c.removeprefix(f"TDD{tdd_class} ") for c in columns]].values).sum(axis=1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-download", action="store_true")
    parser.add_argument("--raw-dir", type=Path, default=RAW_DIR)
    args = parser.parse_args()

    if sum(TARIFF_CONSUMPTION_MWH.values()) != TARIFF_CONSUMPTION_TOTAL_MWH:
        sys.exit("Tariff consumption does not add up to the MOO total")
    if not args.skip_download:
        download(args.raw_dir)
    tdd = read_tdd(args.raw_dir / TDD_FILE)

    class_consumption_mwh = (
        pd.Series(TARIFF_CONSUMPTION_MWH).groupby(TARIFF_TDD_CLASS).sum()
    )
    out = pd.DataFrame(index=tdd.index.floor("h").unique())
    for tdd_class, annual_mwh in class_consumption_mwh.items():
        quarter_mwh = class_profile(tdd, tdd_class) * annual_mwh
        # MWh in the four quarters of an hour == mean MW over that hour.
        out[f"tdd{tdd_class}_mw"] = quarter_mwh.groupby(tdd.index.floor("h")).sum()
    out["consumption_mw"] = out.sum(axis=1)
    if len(out) != 8760:
        sys.exit(f"Expected 8760 hours, got {len(out)}")
    if abs(out["consumption_mw"].sum() - TARIFF_CONSUMPTION_TOTAL_MWH) > 1:
        sys.exit("Hourly profile does not sum to the annual consumption")

    out.insert(0, "time_utc", out.index.tz_convert("UTC").strftime("%Y-%m-%d %H:%M"))
    out.index = out.index.strftime("%Y-%m-%d %H:%M").rename("time_cet")
    OUTPUT_CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUTPUT_CSV_PATH, float_format="%.2f")

    mw = out["consumption_mw"]
    print(f"\nWrote {OUTPUT_CSV_PATH}")
    print("Annual consumption by TDD class [TWh]:")
    for tdd_class, annual_mwh in class_consumption_mwh.items():
        tariffs = ", ".join(t for t, c in TARIFF_TDD_CLASS.items() if c == tdd_class)
        print(f"  TDD{tdd_class} ({tariffs}): {annual_mwh / 1e6:.3f}")
    print(f"  total: {mw.sum() / 1e6:.3f}")
    print(f"Mean {mw.mean():.0f} MW, min {mw.min():.0f} MW ({mw.idxmin()}), "
          f"max {mw.max():.0f} MW ({mw.idxmax()})")
    months = pd.DatetimeIndex(out.index).month
    print(f"Mean MW: Dec-Feb {mw[months.isin([12, 1, 2])].mean():.0f}, "
          f"Jun-Aug {mw[months.isin([6, 7, 8])].mean():.0f}")


if __name__ == "__main__":
    main()
