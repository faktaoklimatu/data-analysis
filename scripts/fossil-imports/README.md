# Czech fossil fuel imports and GDP, from ČSÚ

Two independent scripts:

| Script | Source | Output |
| --- | --- | --- |
| `fetch_stazo.py` | STAZO (Pohyb zboží přes hranice) | gas and crude oil imports by month/year and country |
| `fetch_gdp.py` | DataStat | annual GDP in nominal CZK |

`fetch_gdp.py` exists mainly so import values can be put in proportion — for
example, natural gas imports were 3.3 % of GDP during the 2022 price spike
against 0.5-1.3 % in a normal year. It is a short, unremarkable script because
DataStat has a real API; almost all the complexity below is about STAZO, which
does not.

Both scripts need only **requests**, take no arguments, and are configured by
constants at the top of the file.

## `fetch_stazo.py` — fossil fuel imports

Downloads Czech natural gas and crude oil import data from the ČSÚ database
**Pohyb zboží přes hranice (PZpH)**, published through the STAZO application at
<https://apl.czso.cz/pll/stazo/STAZO.STAZO>.

Output is two tidy CSVs with net mass in **kg** and statistical value in
**millions of CZK**, broken down by country of origin — one monthly, one annual.
Cells that ČSÚ suppresses for confidentiality are recovered by subtraction
against the country-free total, so both files sum to the official figures.

### Usage

```bash
python fetch_stazo.py
```

No arguments. Everything is configured by the constants at the top of the file:

| Constant | Default | Meaning |
| --- | --- | --- |
| `FIRST_YEAR` | `1999` | earliest year to fetch; the end is whatever ČSÚ has published |
| `OUTPUTS` | monthly + annual CSV | period aggregation to fetch, and where to write each |
| `HS_CODES` | `2709`, `2711` | goods to fetch, mapped to output labels |
| `CURRENCY` | `CZK` | also accepts `EUR` or `USD` |
| `REQUEST_DELAY` | `1.0` | seconds between requests |

The run is 112 request pairs and takes about 2.5 minutes — each year is fetched
twice per aggregation, once by country and once as a country-free total. It
always fetches imports; changing that means editing `query_form`, where every
STAZO form field is set explicitly with a comment.

### The two output files

| File | Rows | Rows with no value |
| --- | --- | --- |
| `czso_stazo_imports_monthly.csv` | 8504 | 63 |
| `czso_stazo_imports_annual.csv` | 1155 | **0** |

They are fetched as separate queries, not derived from one another. Use monthly
for shape within a year, annual for levels and shares. The annual file has no
`month` column.

### What is fetched

Two codes at the 4-digit Harmonised System level, always both:

| Code | Contents |
| --- | --- |
| HS 2709 | crude petroleum oils, including natural gas condensates |
| HS 2711 | natural gas and other gaseous hydrocarbons |

Note that HS 2711 also covers LPG (propane, butane) and similar gases, so it is
slightly broader than natural gas alone — historically a few percent of the
mass. Separating them requires the 8-digit CN level, which is not usable here;
see the next section.

### Why the 4-digit level

ČSÚ suppresses cells that would disclose an individual importer. At the 8-digit
CN level (27111100 LNG, 27112100 gaseous gas) this wipes out the country
breakdown for natural gas for **almost every month from 2004 to 2016** — around
40 % of all rows. Aggregating to 4 digits puts enough importers in each cell
that only 1.9 % of rows are suppressed before recovery, and the Russian share of
gas imports in 2004-2016 comes through intact at 73-97 %. It also keeps the
suppression sparse enough that the subtraction described below can attribute
almost all of what remains to a named country.

The trade-off is the loss of two things the CN8 tables offer: the LNG / pipeline
split, and the supplementary unit, which for natural gas is terajoules and is
the most convenient figure for energy analysis. If you need either, query CN8
separately and accept the 2004-2016 gap.

A second reason to keep queries narrow: suppression is applied to the **whole
selected period at once**. Requesting 1999-2026 in a single query masks far more
than requesting each year on its own. The script therefore queries one year at a
time, for each aggregation separately — do not "optimise" either into one big
request, and do not derive the annual file from the monthly one.

### Output columns

`commodity` (`crude_oil` / `natural_gas`), `code`, `code_label`, `period`
(`2024-01` monthly, `2024` annual), `year`, `month` (monthly file only),
`country_code`, `country_name`, `mass_kg`, `value_mil_czk`, `confidential`,
`derived`.

`confidential` marks a cell ČSÚ suppressed; `derived` marks a value this script
reconstructed by subtraction. A row can be both — that is the recovered case.

Read the file with `dtype={"code": str}` so that goods codes stay strings.

### How suppressed cells are recovered

ČSÚ suppresses a cell when it would disclose an individual importer, and the
decision is made **per query**. A query with no country dimension at all
(`skup_zeme=0`) has nothing to disclose, so it is never suppressed. The script
fetches that total alongside the country breakdown, and the difference between
the total and the sum of the disclosed countries is exactly the hidden amount.

Where a period has **exactly one** suppressed origin, that difference *is* that
origin's figure, so it is filled in and flagged `derived = True`. This recovers
all 9 suppressed cells in the annual file and 98 of 127 in the monthly one. For
natural gas it is a large correction, and the recovered flow is always Norway:

| Year | Gas, before | Gas, recovered | Added |
| --- | --- | --- | --- |
| 2011 | 7.36 Mt | 9.17 Mt | 20 % |
| 2012 | 5.96 Mt | 7.97 Mt | 25 % |
| 2013 | 6.87 Mt | 8.96 Mt | 23 % |
| 2014 | 5.50 Mt | 6.29 Mt | 13 % |
| 2016 | 6.55 Mt | 7.63 Mt | 14 % |
| 2019 | 7.15 Mt | 7.69 Mt |  7 % |

Where **two or more** origins are suppressed in the same period the remainder
cannot be split between them. Those rows keep empty values, and the unattributed
remainder is emitted as one extra row with `country_code = "_RESIDUAL"`. This
happens in 29 monthly periods (mostly 2004-2005 gas) and never in the annual
file.

Either way the file sums to the official total. This was verified cell by cell
against the country-free totals: the largest disagreement anywhere is 2 kg of
mass and 4 thousand CZK of value, which is ČSÚ's own per-cell rounding to whole
thousands and is present in cells with no suppression at all.

Two consequences for use:

* **Do not filter out `confidential = True` rows.** In the annual file all of
  them now carry recovered values.
* **`_RESIDUAL` is not a country.** Exclude it when ranking origins; include it
  when computing totals.

### Caveats worth knowing before using the data

**No net mass for 2006-2008.** ČSÚ publishes no `Netto (kg)` column in its
aggregated tables for those three years — at any level (HS2, HS4, HS6) and for
every commodity, not just these two. Only the 8-digit CN tables have mass there.
`mass_kg` is therefore empty for those years in both files, and cannot be
recovered by subtraction either, since the country-free totals lack it too.
Values in CZK are complete. The script says so at the end of the run.

**Residual confidentiality.** After recovery, only the monthly file still has
gaps: 63 rows in 29 periods where several origins are suppressed together. Their
combined volume is present in the `_RESIDUAL` row for the same period, so totals
are right; only the split between those particular origins is unknown. The
annual file has no gaps at all.

**Group by `country_code`, not `country_name`.** Names are given as of each
period and change over time — `RU` is "Rusko" up to 2012 and "Ruská federace"
from 2013. Five of 78 country codes have more than one name in the series.

**Countries.** `QU` and `QV` ("Země a území neuváděné") are the residual
not-specified categories and carry real volume — up to 13 % of gas value in
2016 and about 30 % of gas mass in 2025. Czechia itself cannot appear, since the
flows are always relative to ČR. Country of origin here is the statistical
partner country, which for pipeline gas and oil reflects the contractual
counterpart rather than the geological origin.

**Revisions.** ČSÚ revises recent months, and the most recent month or two is
preliminary. Re-download rather than assuming an old CSV is still current.

### How it works

STAZO has no public API, and the SDMX and JSON endpoints referenced in its page
source are not reachable. The script drives the query form instead:

1. `POST !PRESSO.STAZO.PRIPRAV_ZOBRAZ` with the form fields (`par=D`) returns an
   HTML result page containing an opaque query handle in `vektor`.
2. `POST PRESSO.STAZO.NOVE_VOLANI` with that handle and `typ_vystupu=C` returns
   the result as a semicolon-delimited, BOM-prefixed UTF-8 CSV.

The goods filter must be repeated in step 2 as `kody_zbozi`; leaving it empty
makes STAZO export every CN8 code for the period, which is a 20 MB download.

The column layout of the CSV varies between queries — the mass column is simply
absent for 2006-2008 — so the parser maps columns by their Czech header labels
rather than by position.

## `fetch_gdp.py` — annual GDP in nominal CZK

```bash
python fetch_gdp.py
```

No arguments; one request pair, instant. Writes `czso_gdp_annual.csv` with one
row per indicator and year:

`indicator`, `code`, `label`, `year`, `value`, `unit`, `note`

By default a single indicator, `9988S03` — gross domestic product in **millions
of CZK at current (nominal) prices**, currently 1990 to 2025.

### Source

DataStat, which unlike STAZO has a documented JSON/CSV API:
<https://csu.gov.cz/zakladni-informace-pro-pouziti-api-datastatu>

The data is dataset **NUC06R** ("Hlavní souhrnné ukazatele HDP - roční údaje"),
the same data behind the DataStat page
[VYBER/NUC06RT01](https://data.csu.gov.cz/datastat/data/VYBER/NUC06RT01).

The script queries the *dataset* rather than that predefined selection, because
the selection pins its list of years manually — 1990-2025 as of writing — while
an empty year filter on the dataset picks up new years on its own. `verzeSady`
is likewise omitted so the API serves the current dataset version. The territory
dimension is pinned to `CZ` and the industry dimension to its `0` (Celkem)
total, so the figure is national and all-industry.

Before querying, the script reads the dataset catalogue and fails with a clear
message if an indicator code has disappeared, rather than silently writing an
empty file.

### Other indicators in the same dataset

Add the code to `INDICATORS` at the top of the script to include it:

| Code | Indicator |
| --- | --- |
| `9988S11` | real GDP growth, % (previous year = 100) |
| `10032S01` | GDP per capita, CZK, current prices |
| `9992BC` | gross value added, mil. CZK, current prices |
| `10000DOM` | household final consumption expenditure, mil. CZK, current prices |
| `9991BC` | gross fixed capital formation, mil. CZK, current prices |
| `9991OI` | gross fixed capital formation, % volume index |
| `9993C` | compensation of employees, mil. CZK |

Not every indicator covers every year — GDP per capita starts later than GDP
itself, and the script reports which years came back empty.

### Caveat

National accounts are revised. These are current-vintage figures, so a series
downloaded today will differ slightly from one downloaded a year ago, including
for years long past. Re-download rather than mixing vintages, and do not compare
against older published tables without checking.
