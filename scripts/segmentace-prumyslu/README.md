# Segmentace průmyslu – výpočty v R

Fakta o klimatu · Jakub Komárek · 2026

Kód k prezentaci „Co rozhoduje o prosperitě českého průmyslu?“ (`Průmysl – Slidedeck v1`, snímky S1–S25).
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

Balíčky: `readxl, dplyr, tidyr, readr, jsonlite, stringr` (doinstaluje `R/00_setup.R`).

## Testy
`tests/test_parser.R` – převod odpovědi API Eurostatu na tabulku (uložená skutečná odpověď v `tests/fixtures`).
Kontrola výpočtů je v notebooku níže; s prezentací se nic neporovnává – prezentace je výstup.

## Kontrolní notebook
`notebook/kontrola_vypoctu.qmd` – po slajdech: obrázek slajdu, data (zdroj), kód a výsledek.
Obrázky slajdů (`notebook/slajdy/sNN.png`) nejsou v gitu, kopírují se ze sdíleného disku projektu.
Kde to jde, přepočítá výsledek přímo ze surových dat a porovná ho s výstupem skriptu
(sloupec `shoda`). Neporovnává se slajdy – prezentace je výstup. Po `run_all.R` vyrenderujte
v Positronu (Render) nebo `quarto render notebook/kontrola_vypoctu.qmd`.

## Zdroje dat
Seznam všech zdrojů po slajdech je v [`data_catalog.csv`](data_catalog.csv)
(slajd, zdroj, dataset, filtr, odkaz, způsob získání, skript, stav).

## Skripty
| Skript | Co dělá | Snímky (deck v1) |
|---|---|---|
| `00_setup.R` | balíčky, cesty, ceny povolenek (DEHSt), emisní faktor 0,85 t/MWh | – |
| `funkce.R` | sdílené funkce (`sts_composite`) | – |
| `01_download_eurostat.R` | stažení dat z API Eurostatu (`es_get`, `es_save`) | – |
| `02_registry.R` | zařízení EU ETS v ČR → obor (NACE) a kraj | S15, S16 |
| `03_ets_costs.R` | přímé a nepřímé náklady ETS v % nákladů (2024), hutě podle závodů | S17, S21 |
| `08_production_annual.R` | roční index výroby, Česko vs. Německo | S9 |
| `11_hph_zamestnanost.R` | HPH a pracující 2025; náklady práce a výroba na pracujícího; dovoz aut z Číny (Comext) | S5–S7, S19 |
| `12_energie_pefa.R` | energetická náročnost (TJ / mil. € HPH) a skladba paliv, PEFA 2023 | S12, S13, S25 |
| `13_sut_csu.R` | nákupy energie a náklady práce v % nákladů, SUT ČSÚ 2024 + 2025 | S11, S17, S19–S23 |
| `14_figaro.R` | dovozní penetrace, vývoz mimo EU ETS, čtyři skupiny oborů (FIGARO 2015, 2024) | doplňkové D1–D3 (v decku v1 nejsou) |
| `15_export_web.R` | data pro webovou prezentaci do `web-cz/_data/segmentace_prumyslu/` | web |

Ruční převodníky jsou v `data/manual/` (kód činnosti → obor, průmyslové spalovací zdroje → obor,
zařízení → kraj, odečet vlastní elektřiny, kompenzace nepřímých nákladů). Jsou to úsudky autora.

Skripty jsou v UTF-8; ve Windows použijte R ≥ 4.2.

## Poznámky ke slajdům (dohodnuto)
- **Chemie (C20) = vč. rafinerií Litvínov a Kralupy** (ORLEN Unipetrol RPA), jak ji vede ČSÚ – poznámka na S11, S12, S17.
- **S17:** přímý náklad ETS je netto (přebytky povolenek snižují náklad, lze je prodat); nepřímý je horní odhad
  (0,85 t/MWh, plné promítnutí ceny, elektřina 2023). Jmenovatel = celkové náklady 2024 ze SUT ČSÚ.
- **S19, karta 3:** podíl náhrad zaměstnancům na HPH (auta 41 → 52 %, stroje 58 → 69 %, 2015 → 2025).
- **S11 / S22:** energie chemie 11–20 % nákladů podle zacházení s ropnými produkty (citlivost v notebooku).
- **S22:** skupina ORLEN Unipetrol = 72 % emisí chemie; povolenky 2,1 % nákladů firmy (výroční zpráva 2025, údaj 2024).
