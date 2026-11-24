# Segmentace průmyslu – výpočty v R

Fakta o klimatu · Jakub Komárek · 2026

Kód k prezentaci „Co rozhoduje o prosperitě českého průmyslu?“ (`CZ segmentace průmyslu 2026.pdf`).
Cíl: **každé číslo ze slajdů se počítá z kódu ze surových dat**, bez excelů. Výpočetní excel
(`CZ_ETS_prumysl_data_v25.xlsx`) slouží jen ke kontrole výsledků.

## Spuštění
Pracovní adresář = tato složka.

```r
source("R/run_all.R")   # nebo: Rscript R/run_all.R
```

- Při prvním spuštění se stáhnou data Eurostatu (API JSON-stat) do `data/eurostat/`
  a registr EU ETS (8 MB) do `data/raw/`. Obě složky nejsou v gitu.
- Výsledky jsou v `out/` (CSV, verzované v gitu – změna čísla je vidět v diffu).
- Výpis běhu včetně chyb: `out/run_log.txt`.
- Slovenský index výroby (ŠÚ SR, DATAcube pm0040ms) se zatím ukládá ručně do
  `data/eurostat/sk_prod.csv` (vzor v `tests/fixtures/sk_prod.csv`).

Balíčky: `readxl, dplyr, tidyr, readr, jsonlite, stringr` (doinstaluje `R/00_setup.R`).

## Kontrola proti prezentaci
```r
source("tests/test_against_deck.R")
```
Pro každé číslo vypíše `výpočet (prezentace) OK/CHYBA`. S testovacími daty bez stahování:
`FOK_EUROSTAT_DIR=tests/fixtures Rscript tests/test_against_deck.R`.

## Zdroje dat
Seznam všech zdrojů po slajdech je v [`data_catalog.csv`](data_catalog.csv)
(slajd, zdroj, dataset, filtr, odkaz, způsob získání, skript, stav).

## Skripty
| Skript | Co dělá | Slajdy (PDF 2026) |
|---|---|---|
| `00_setup.R` | balíčky, cesty, ceny povolenek (DEHSt), emisní faktor 0,85 t/MWh | – |
| `funkce.R` | sdílené funkce (`sts_composite`) | – |
| `01_download_eurostat.R` | stažení dat z API Eurostatu (`es_get`, `es_save`) | – |
| `02_registry.R` | zařízení EU ETS v ČR → obor (NACE) a kraj | 15, 16 |
| `03_ets_costs.R` | přímé a nepřímé náklady ETS, nákupy energie (2024) | 17 |
| `04_intensity.R` | emisní náročnost vs. změna výroby | – |
| `05_regions.R` | emisní expozice krajů | – |
| `06`, `07`, `09` | ceny elektřiny a plynu pro průmysl | – |
| `08_production_annual.R` | roční index výroby, Česko vs. Německo | 7 |
| `10_io_metals.R` | podíl kovů (CPA 24) na produkci oborů, IO 2020 | 21–23 |

Plánované: `11_hph_zamestnanost.R` (5, 6, 20), `12_energie_pefa.R` (11, 12),
`13_sut_csu.R` (10, 17, 21–23), `14_figaro.R` (26–28).

Ruční převodníky jsou v `data/manual/` (kód činnosti → obor, průmyslové spalovací zdroje → obor,
zařízení → kraj, odečet vlastní elektřiny). Jsou to úsudky autora.

Skripty jsou v UTF-8; ve Windows použijte R ≥ 4.2.
