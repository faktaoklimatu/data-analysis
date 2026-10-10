#!/usr/bin/env python
"""Hourly production curve (MW) of residential rooftop solar PV in Czechia
in 2025: PECD 4.2 (ERA5 reanalysis) capacity factors for the "rooftop
residential" typology, scaled by the installed capacity of PV plants up to
10 kW (ERÚ / OTE yearly statistics, table 5.6), then compared with the
official yearly production.

Usage (from the repo root; needs ~/.cdsapirc for the download step):
    python scripts/solar-rooftop-cz/build_rooftop_solar_curve.py
    python scripts/solar-rooftop-cz/build_rooftop_solar_curve.py --skip-download
"""
import argparse
import sys
import zipfile
from pathlib import Path

import numpy as np
import pandas as pd

YEAR = 2025
COUNTRY = "CZ"

RAW_DIR = Path("temp/pecd-pv-2025")
OUTPUT_CSV_PATH = Path("outputs/output-rooftop-solar-cz-2025-hourly.csv")

# PECD 4.2 splits PV into typologies; technology 61 is residential rooftop.
TECHNOLOGY = "61"

# Czech centroid, for the solar-geometry check of the time convention.
CZ_LAT, CZ_LON = 49.8, 15.5

# The PECD timestamps are not documented, but the data lag the sun by about
# one hour relative to hour-beginning UTC labels (see check_time_alignment()),
# in winter and summer alike, so it is not a daylight-saving effect. This fits
# ERA5-style hour-ending labels (or a fixed UTC+1) -- both mean that the value
# labelled t describes the hour [t - 1 h, t). We relabel to hour-beginning UTC.
LABEL_SHIFT_HOURS = 1

# Official statistics, table 5.6 "Fotovoltaické elektrárny", row "do 10 kW
# včetně". Capacities are year-end values; within the year the installed
# capacity is assumed to grow linearly between them.
CAPACITY_START_MW = 1361.6  # end of 2024
CAPACITY_END_MW = 1516.2  # end of 2025
GROSS_PRODUCTION_MWH = 1_386_466.6
NET_PRODUCTION_MWH = 1_386_388.6
GRID_DELIVERY_MWH = 524_013.1


def download(raw_dir: Path) -> None:
    import cdsapi  # imported lazily so --skip-download needs no credentials

    raw_dir.mkdir(parents=True, exist_ok=True)
    request = {
        "pecd_version": "pecd4_2",
        "temporal_period": ["historical"],
        "origin": ["era5_reanalysis"],
        "variable": ["solar_photovoltaic_generation_capacity_factor"],
        "technology": [TECHNOLOGY],
        "spatial_resolution": ["nuts_0"],
        "year": [str(YEAR)],
        "file_version": ["fv1"],
    }
    target = cdsapi.Client().retrieve("sis-energy-pecd", request).download()
    target = Path(target)
    if zipfile.is_zipfile(target):
        with zipfile.ZipFile(target) as z:
            z.extractall(raw_dir)
        target.unlink()
    else:
        target.replace(raw_dir / target.name)


def find_residential_file(raw_dir: Path, technology: str | None) -> Path:
    files = sorted(p for p in raw_dir.rglob("*") if p.suffix in (".csv", ".nc"))
    if not files:
        sys.exit(f"No CSV/NetCDF files found in {raw_dir}")
    print("Downloaded files:")
    for f in files:
        print("  ", f.relative_to(raw_dir))
    hits = [f for f in files if technology in f.name]
    if len(hits) != 1:
        sys.exit(
            f"Expected exactly one file for technology {technology}, got "
            f"{[h.name for h in hits]}. Check the file names above and rerun "
            "with --technology <unique substring of the file name>."
        )
    return hits[0]


def read_capacity_factors(path: Path) -> pd.Series:
    """Hourly capacity factor (MW per MWp) for COUNTRY, indexed by UTC time."""
    if path.suffix == ".nc":
        import xarray as xr

        ds = xr.open_dataset(path)
        print(ds)
        var = next(v for v in ds.data_vars if ds[v].ndim >= 1)
        da = ds[var]
        for dim in da.dims:
            if dim != "time" and da.sizes[dim] > 1:
                da = da.sel({dim: COUNTRY})
        s = da.squeeze(drop=True).to_series()
    else:
        # Wide format: a "Date" column and one capacity factor column per country.
        df = pd.read_csv(path, comment="#", index_col="Date", parse_dates=True)
        s = df[COUNTRY]
    s.index = pd.DatetimeIndex(s.index)
    if s.index.tz is None:
        s.index = s.index.tz_localize("UTC")  # PECD timestamps are UTC
    s = s[s.index.year == YEAR].sort_index()
    return s.rename("capacity_factor")


def cos_zenith(times: pd.DatetimeIndex) -> np.ndarray:
    """Cosine of the solar zenith angle at CZ_LAT/CZ_LON (NOAA approximation)."""
    day = times.dayofyear + (times.hour + times.minute / 60) / 24
    g = 2 * np.pi / 365 * (day - 1)
    decl = (0.006918 - 0.399912 * np.cos(g) + 0.070257 * np.sin(g)
            - 0.006758 * np.cos(2 * g) + 0.000907 * np.sin(2 * g)
            - 0.002697 * np.cos(3 * g) + 0.00148 * np.sin(3 * g))
    eot = 229.18 * (0.000075 + 0.001868 * np.cos(g) - 0.032077 * np.sin(g)
                    - 0.014615 * np.cos(2 * g) - 0.040849 * np.sin(2 * g))
    hour_angle = np.radians((times.hour * 60 + times.minute + eot + 4 * CZ_LON) / 4 - 180)
    lat = np.radians(CZ_LAT)
    return np.sin(lat) * np.sin(decl) + np.cos(lat) * np.cos(decl) * np.cos(hour_angle)


def check_time_alignment(cf: pd.Series) -> None:
    """Correlate hourly CF with the hourly mean of clipped cos(zenith), with the
    sun evaluated at the given offset from the (assumed hour-beginning UTC)
    label. The best offset reveals the time convention of the data."""
    print("\nTime alignment (offset of the sun's hour window vs label; "
          "-1 h means label = end of hour):")
    for name, months in [("year", range(1, 13)), ("Nov-Feb", [11, 12, 1, 2]), ("May-Aug", [5, 6, 7, 8])]:
        mask = cf.index.month.isin(list(months))
        corr = {}
        for offset in (-2, -1.5, -1, -0.5, 0, 0.5, 1):
            sun = sum(
                np.clip(cos_zenith(cf.index + pd.Timedelta(hours=offset, minutes=m + 5)), 0, None)
                for m in range(0, 60, 10)
            ) / 6
            corr[offset] = np.corrcoef(cf[mask], sun[mask])[0, 1]
        best = max(corr, key=corr.get)
        print(f"  {name:8s} best offset {best:+.1f} h (r={corr[best]:.3f}; "
              f"r at 0 h = {corr[0]:.3f})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--skip-download", action="store_true")
    parser.add_argument("--technology", default=TECHNOLOGY, help="technology code or file name substring")
    parser.add_argument("--raw-dir", type=Path, default=RAW_DIR)
    args = parser.parse_args()

    if not args.skip_download:
        download(args.raw_dir)
    cf = read_capacity_factors(find_residential_file(args.raw_dir, args.technology))

    expected_hours = 8760
    if len(cf) != expected_hours or cf.index.has_duplicates:
        sys.exit(f"Expected {expected_hours} unique hourly values, got {len(cf)}")
    if not cf.between(0, 1.2).all():
        sys.exit("Capacity factors outside [0, 1.2] -- check units")

    check_time_alignment(cf)
    if LABEL_SHIFT_HOURS:
        # Relabel to hour-beginning UTC; the last hour of the year is night.
        cf = cf.shift(-LABEL_SHIFT_HOURS, freq="h").reindex(cf.index, fill_value=0.0)
        print(f"\nShifted labels by -{LABEL_SHIFT_HOURS} h (last hour of year set to 0)")
    out = pd.DataFrame({"capacity_factor": cf})
    # Capacity at the middle of each hour, linear from start to end of year.
    year_start = pd.Timestamp(f"{YEAR}-01-01", tz="UTC")
    year_end = pd.Timestamp(f"{YEAR + 1}-01-01", tz="UTC")
    year_fraction = (out.index + pd.Timedelta(minutes=30) - year_start) / (year_end - year_start)
    out["capacity_mw"] = CAPACITY_START_MW + (CAPACITY_END_MW - CAPACITY_START_MW) * year_fraction
    out["production_unscaled_mw"] = out["capacity_factor"] * out["capacity_mw"]
    # Scale the whole curve so that the annual total equals the official gross
    # production. Crude (real fleets differ in orientation, tilt, losses, which
    # also change the shape), but good enough for our purposes.
    scale = GROSS_PRODUCTION_MWH / out["production_unscaled_mw"].sum()
    out["production_mw"] = out["production_unscaled_mw"] * scale
    out.insert(0, "time_cz", out.index.tz_convert("Europe/Prague").strftime("%Y-%m-%d %H:%M"))
    OUTPUT_CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.index.name = "time_utc"
    out.to_csv(OUTPUT_CSV_PATH, float_format="%.4f")

    modelled = out["production_unscaled_mw"].sum()  # hourly MW == MWh per hour
    print(f"\nWrote {OUTPUT_CSV_PATH}")
    mean_capacity = out["capacity_mw"].mean()
    print(f"Mean installed capacity (linear): {mean_capacity:.1f} MW")
    print(f"Mean capacity factor (modelled): {cf.mean():.3f} "
          f"-> {cf.mean() * 8760:.0f} kWh/kWp")
    print(f"Official yield (gross / mean capacity): "
          f"{GROSS_PRODUCTION_MWH / mean_capacity:.0f} kWh/kWp")
    print(f"Modelled production: {modelled / 1e6:.3f} TWh")
    print(f"Official gross:      {GROSS_PRODUCTION_MWH / 1e6:.3f} TWh "
          f"(net {NET_PRODUCTION_MWH / 1e6:.3f}, grid delivery {GRID_DELIVERY_MWH / 1e6:.3f})")
    print(f"Modelled / official gross: {modelled / GROSS_PRODUCTION_MWH:.1%}")
    print(f"Applied scale factor: {scale:.4f} -> scaled total "
          f"{out['production_mw'].sum() / 1e6:.3f} TWh, "
          f"peak {out['production_mw'].max():.0f} MW")


if __name__ == "__main__":
    main()
