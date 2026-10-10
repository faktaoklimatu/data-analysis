# Residential rooftop solar curve for Czechia (2025)

Builds an hourly production curve (MW) of residential rooftop solar PV in
Czechia in 2025: PECD 4.2 capacity factors, scaled by the installed capacity
of PV plants up to 10 kW and then by the official yearly production.

## Getting the PECD data

The script downloads the data itself from the Copernicus Climate Data Store
(dataset `sis-energy-pecd`, PECD 4.2, ERA5 reanalysis, NUTS0, technology 61 =
residential rooftop PV).

1. Register at <https://cds.climate.copernicus.eu> and accept the dataset's
   licence on its page (otherwise the request is rejected).
2. Save your API credentials to `~/.cdsapirc`:
   ```
   url: https://cds.climate.copernicus.eu/api
   key: <your-personal-access-token>
   ```
3. Install `cdsapi`, `pandas`, `numpy` (and `xarray` + `netcdf4`, only needed
   if the data comes as NetCDF).

The request takes several minutes. The result (one CSV, wide format: `Date`
plus one capacity factor column per country) is extracted to `temp/pecd-pv-2025/`
(gitignored). Rerun with `--skip-download` to reuse it.

## Usage

```bash
python scripts/solar-rooftop-cz/build_rooftop_solar_curve.py
python scripts/solar-rooftop-cz/build_rooftop_solar_curve.py --skip-download
```

Run from the repo root (paths are relative). Output:
`outputs/output-rooftop-solar-cz-2025-hourly.csv` (gitignored), with columns
`time_cet` (hour-beginning, fixed UTC+1 without summer time), `time_utc`, `capacity_factor`, `capacity_mw`,
`production_unscaled_mw` and `production_mw`.

## Method

- **Capacity factor.** PECD capacity factors are MW per MWp of module peak
  **DC** capacity. The model includes temperature, reflection and inverter
  efficiency losses but no inverter clipping or degradation. Residential
  rooftops are modelled as south-facing, with tilt depending on latitude.
- **Installed capacity.** Official year-end capacity of plants up to 10 kW
  (1361.6 MW at the end of 2024, 1516.2 MW at the end of 2025), interpolated
  linearly through the year. The official "MWe" may not be the same unit as
  MWp; this is not verified.
- **Timestamps.** The PECD timestamps are not documented. Comparison with solar
  geometry shows they are hour-beginning in fixed Central European Time (UTC+1,
  no summer time): read as UTC, the values lag the sun by one hour in winter
  and summer alike, while read as UTC+1 the best-fit offset is 0 in all
  seasons. The script prints this check, treats the labels as UTC+1 (`PECD_TZ`)
  and writes both `time_cet` and `time_utc`. The output covers the CET year
  2025 (8760 hours), i.e. it starts at 2024-12-31 23:00 UTC.
- **Scaling.** The whole curve is scaled so its annual total equals the
  official gross production of plants up to 10 kW (1 386 466.6 MWh,
  ERÚ yearly statistics, table 5.6). The unscaled model overshoots it by
  about 8 % (1043 vs 964 kWh/kWp). Scaling is crude: real fleets differ in
  orientation, tilt and losses, which changes the shape of the curve too.
- The curve is total production including self-consumption (only about 38 %
  of it was delivered to the grid), not grid feed-in.
