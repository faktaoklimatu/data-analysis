# Hourly household electricity consumption in Czechia (2025)

Estimates the hourly electricity consumption (MW) of Czech households (the sum
of all D tariffs) in 2025 from OTE's recalculated typical delivery profiles
(TDD) and the ERÚ tariff statistics.

## Getting the data

- **TDD profiles.** The script downloads the OTE file itself (about 4.7 MB):
  <https://www.ote-cr.cz/attachments/29/2025/Prepoctene_TDD_15MIN_2025_CZ.zip>
  (page: <https://www.ote-cr.cz/cs/statistika/typove-diagramy-dodavek-elektriny/prepoctene-tdd>).
  It contains `Prepoctene_TDD_2025_CZ.xlsx` with 15-minute relative values of
  the 8 TDD classes (class 5 per region), recalculated to the actual weather
  of 2025. It is extracted to `temp/ote-tdd-2025/` (gitignored); use
  `--skip-download` to reuse it.
- **Tariff statistics.** Hardcoded in the script from the ERÚ yearly report on
  the operation of the electricity system 2025
  (<https://eru.gov.cz/sites/default/files/obsah/prilohy/eruelektro2025.pdf>),
  table 10.6, billed consumption of the D tariffs (group MOO) in MWh.

Requires `pandas` and `openpyxl`.

## Usage

```bash
python scripts/household-electricity-cz/estimate_household_consumption.py
python scripts/household-electricity-cz/estimate_household_consumption.py --skip-download
```

Run from the repo root. Output:
`outputs/output-household-electricity-cz-2025-hourly.csv` (gitignored), 8760
rows, columns `time_cet` (hour-beginning, fixed UTC+1 without summer time, the
same convention as `scripts/solar-rooftop-cz`), `time_utc`, `tdd4_mw` ...
`tdd7_mw` (per TDD class) and `consumption_mw` (their sum).

## Method

1. **Classes.** Annex 6 of decree 408/2015 Sb. assigns the D tariffs to TDD
   classes: 4 = D01d, D02d, D61d (no thermal use of electricity); 5 = D25d,
   D26d, D27d (accumulation heating); 6 = D35d (hybrid heating); 7 = D45d,
   D57d (direct heating) and D56d (heat pump). The mapping is in
   `TARIFF_TDD_CLASS`.
2. **Annual consumption per class** = sum of billed consumption of its tariffs
   (15.708 TWh in total, the "MOO" row).
3. **Profile.** Each class profile is normalised to a unit annual sum and
   multiplied by the class consumption. Class 5, published for 8 regions, is
   the equal-weighted mean of the normalised regional profiles
   (`TDD5_REGION_WEIGHTS`). Individual regional profiles differ from the mean
   by 11-26 % in hourly values, so the weights matter somewhat for this class
   (a quarter of the consumption), but there are no per-region tariff
   statistics to base them on.
4. **Hourly values.** The OTE days are in Czech local time (92 and 100
   quarter-hours on 30 March and 26 October); timestamps are built from
   elapsed time, converted to fixed CET, and the four quarter-hours of each
   hour are summed (MWh in an hour = mean MW), giving 8760 hours.

## Caveats

- The ERÚ tariff statistics cover only the three largest regional distribution
  systems and report electricity billed in documents issued in 2025, not
  consumption in the calendar year, so the annual total (15.7 TWh) is an
  approximation.
- The TDD profiles describe electricity supplied through the grid. Household
  consumption covered by own rooftop PV (self-consumption) is not included,
  so combine this with the gross rooftop PV curve with care.
- TDD profiles are statistical profiles of the class, smoother than the real
  aggregate load.
