# ETS1 dashboard data pipeline

Transforms the EUTL verified-emissions export into the data the ETS1
dashboard (faktaoklimatu.cz/studie/2026-interaktivni-prehled-ets) needs: a flat per-installation-per-year CSV, and
a compact pre-aggregated YAML the dashboard page loads directly.

## Scripts

- **`process_verified_emissions.py`** — the main pipeline. `build_installation_years()`
  reads the raw EUTL export, unpivots it into one row per installation per
  year, filters it down to real Czech industrial installations, and merges
  in hand-curated columns from a live Google Sheet. Produces
  `outputs/ets-dashboard/ETS-data.csv` and `ets-dashboard.yaml`.

- **`update_installations_overview.py`** — reuses `build_installation_years()` to
  regenerate `ets-installations-overview.csv`, a one-row-per-installation
  reference sheet (with MoE operator name/address, OPOK file). Its columns get copied
  into the "Přehled instalací" Google Sheet, hand-annotated there, and read
  back by `build_installation_years()` on its next run.

## Usage

```bash
python scripts/dashboard-ets1/process_verified_emissions.py
python scripts/dashboard-ets1/update_installations_overview.py
```

Run from the repo root (paths are relative). The scripts don't depend on
each other's output — both just call `build_installation_years()` independently — so
either can be run alone; in practice run both whenever the source data or
the Google Sheet has changed.

To use a new EUTL or OPOK export, drop the new `.xlsx` into `data/EUA/`,
update `INPUT_PATH`/`OPOK_PATH` if the filename changed, and extend `YEARS`
if needed. The Google Sheet is fetched live over HTTP every run.

## Dependencies

pandas, openpyxl, PyYAML

## Key logic

- **Filtering**: Czech registry only; drops aircraft/maritime operators, the
  ETS2 placeholder account, and installation-years with no reported
  emissions (`-1` / `"Excluded"`).
- **Activity classification**: `SECTOR_GROUP` collapses ~38 raw EU ETS
  activity codes (Phase I and later phases use different, overlapping
  ranges for the same activity) into ~11 broad sectors for the dashboard.
  Three installations get a manual code override (`ACTIVITY_CODE_OVERRIDES`)
  for source misclassifications. `REAL_ACTIVITY` (from the sheet) is a
  separate, more specific hand-curated description, additive to this.
- **Names**: `INSTALLATION_NAME_CLEAN` / `OPERATOR_NAME_CLEAN` come from the
  sheet, falling back to the raw name when not yet curated. `OWNER_ASSIGNED`
  is a separately curated parent/group company.
- **Allocation**: `FREE_ALLOCATION` sums `ALLOCATION` + `ALLOCATION_RESERVE`
  + `ALLOCATION_TRANSITIONAL`, treating missing or not-yet-existing
  (pre-2013) values as `0`.
- **The Google Sheet**: fetched by `load_manual_overrides()`, matched by
  `Installation ID` (the `CZ-XXXX` permit prefix). Handles an optional note
  row above the header, since people edit it by hand; missing or
  unreachable columns degrade to blank rather than failing the run.
