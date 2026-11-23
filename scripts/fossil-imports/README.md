# Czech fossil fuel imports, GDP and public budgets

Data for the web dashboard "Dovoz ropy a zemního plynu do ČR". Three independent
scripts, each run with no arguments from this folder (they write relative to the current
directory). They need only `requests`; the details of each source, its traps and its
design choices are in the docstring at the top of the script.

| Script | Source | Writes to `output-dashboard/` |
| --- | --- | --- |
| `fetch_stazo.py` | ČSÚ STAZO (Pohyb zboží přes hranice), ~2.5 min | `imports-monthly.csv`, `imports-annual.csv` |
| `fetch_gdp.py` | ČSÚ DataStat | `gdp.csv` |
| `fetch_budgets.py` | MF MONITOR Státní pokladny, ~1 min, ~100 MB | `msmt.csv`, `sfdi.csv` |

`common.py` holds the helpers they share. Output names contain `output-`, which the
repository's `.gitignore` excludes, so nothing generated is committed. The dashboard
loads these files straight from web-cz (`assets-local/files/dovoz-fosilnich-paliv/`),
where they are copied by the AI pipeline `dashboard-dovoz-fosilnich-paliv` in
ai-pipelines.

## Output files

| File | Columns | Meaning |
| --- | --- | --- |
| `imports-monthly.csv` | `commodity`, `year`, `month`, `country_code`, `mass_kg`, `value_mil_czk` | imports of `crude_oil` (HS 2709) and `natural_gas` (HS 2711) by country of origin |
| `imports-annual.csv` | the same without `month` | |
| `gdp.csv` | `year`, `value_mil_czk` | nominal GDP |
| `msmt.csv`, `sfdi.csv` | `year`, `total_mld_czk` | *approved* total expenditure in nominal bn CZK: MŠMT (chapter 333) and SFDI (transport infrastructure fund); the last row is the running year's plan |

Rows with neither `mass_kg` nor `value_mil_czk` are left out, and empty values are
possible in the numeric columns; read them as missing, not zero.

## Things to handle when using the import files

* **`_RESIDUAL` is not a country.** ČSÚ suppresses cells that would disclose a single
  importer. The scripts recover them by subtraction against country-free totals; where
  several origins of one period are hidden together, their sum is one `_RESIDUAL` row.
  Exclude it when ranking origins, include it in totals. Do not filter out anything else.
* **`mass_kg` is empty for 2006-2008**: ČSÚ publishes no net mass for those years. Chart
  value rather than mass if the series must be continuous.
* **Group by `country_code`, not by name** (names change over time, e.g. Rusko / Ruská
  federace). `QU` and `QV` are ČSÚ's "not specified" origins and carry real volume, up to
  about 30 % of gas mass in 2025. Origin is the statistical partner country, which for
  pipeline gas and oil is the contractual counterpart, not the geological origin.
* **HS 2711 also covers LPG**, a few percent of the mass, so it is slightly broader than
  natural gas.
* **Revisions.** ČSÚ revises the latest months (and national accounts revise GDP back in
  time), so re-download rather than mixing vintages. A part year is just that: the annual
  row of the running year grows with every month.

Budgets are nominal, so growth over the years is partly inflation. MŠMT's figure is the
whole chapter, including transfers to regions for regional schools (about three quarters
of it) and to universities. SFDI's is expenditure, not revenue.
