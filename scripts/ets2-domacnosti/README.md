# ETS2 a domácnosti – výpočty v R

Fakta o klimatu · 2026

Kód k sérii textů o dopadu ETS2 (povolenky na paliva pro budovy a silniční dopravu) na české domácnosti
a o přímých platbách ze Sociálního klimatického fondu. Texty a grafy jsou v repozitáři `web-cz`
(větev `preview-socialni-klimaticka-politika`), agregovaná data ke grafům v `web-cz/_data/ets2/`.

Jak se co počítá: [`METODIKA.md`](METODIKA.md). Vstupní parametry se zdroji: [`inputs.csv`](inputs.csv).

## Co je v repozitáři a co ne

- **Je:** skripty (`R/`), veřejná data (`data/`), metodika.
- **Není:** mikrodata ČSÚ (EU-SILC, Statistika rodinných účtů, ENERGO 2021) ani nic, z čeho by šla odvodit.
  Leží lokálně mimo repozitář (výchozí `~/Documents/ČSÚ`, jinak proměnná `ETS2_CSU_DIR`).
- **Není ani `R/output/`** (v `.gitignore`). Výstupy zůstávají na sdíleném disku projektu;
  část jich je jen kontrolních a jeden (`04_mikro_domacnosti.csv`) je na úrovni domácností.

## Spuštění

Pracovní adresář = `R/`.

```sh
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 Rscript --no-init-file -e 'source("run_all.R", encoding="UTF-8")'
```

Proměnné prostředí:

| Proměnná | Výchozí | K čemu |
|---|---|---|
| `ETS2_CSU_DIR` | `~/Documents/ČSÚ` | mikrodata a stažené ceny ČSÚ (`ceny/`, `SRU/`, `MF_SILC 2015-2024/`, `ENERGO_2021_data.xlsx`) |
| `ETS2_WEB_DIR` | `~/GitHub/web-cz-ets2` | checkout `web-cz`, kam `10` a `13` zapisují agregáty pro web |
| `ETS2_OUT` | `output` | složka výstupů (citlivosti např. `output/c1_bilance`) |
| `ETS2_KALIBRACE` | zapnuto | kalibrace plynu a uhlí na energetickou bilanci (C1) |
| `ETS2_KAL_ROKY` | `2023,2024` | roky bilance pro kalibraci uhlí; se SILC 2025 přepnout na `2024,2025` |
| `ETS2_KAL_ROKY_PLYN` | `2024,2025` | roky bilance pro kalibraci plynu (Eurostat + ERÚ) |

`00_setup.R` zastaví běh, pokud `ETS2_WEB_DIR` není na větvi `preview-socialni-klimaticka-politika`,
aby se agregáty nezapsaly do cizí větve. Ceny ČSÚ se při prvním běhu stáhnou (`00_stahni_csu.R`),
`13_data_web.R` potřebuje internet (API Eurostatu).

Balíčky: `dplyr, tidyr, readr, readxl, jsonlite, sf` (základní doinstaluje `00_setup.R`).

## Skripty

| Skript | Co dělá |
|---|---|
| `00_setup.R` | balíčky, cesty, společné funkce (vážené kvantily) |
| `00_stahni_csu.R` | stažení cen energií a PHM z API ČSÚ |
| `01_csu_typove.R`, `03_typove_domacnosti.R`, `05_citlivost.R` | typové domácnosti z publikovaných tabulek ČSÚ ENERGO 2021 |
| `02_parametry.R` | parametry pro rok 2028 (cena povolenky, kurz, emisní faktory) |
| `04_mikrosimulace.R`, `06_kontrola_mikrodata_typove.R`, `07_zranitelne.R` | starší mikrosimulace z ENERGO 2021, dnes jen kontrola |
| `08_ceny_csu.R`, `08a_sru_diagnostika.R` | ceny roku šetření; diagnostika SRÚ proti SILC |
| `09_silc_archetypy.R` | **hlavní výpočet:** archetypy ze SILC 2024 + PHM ze SRÚ, kalibrace na bilanci, zranitelné domácnosti, energetická chudoba (2M) |
| `10_mapa_orp.R` | mapa ORP (ukazatel MF + SLDB 2021) |
| `11_kompenzace_nastroje.R` | pravidla přímé platby a jejich srovnání (vč. návrhu PAQ a CVF) |
| `12_cena_tepla.R` | orientační cena tepla podle zdroje |
| `13_data_web.R` | agregáty pro grafy na webu (tok peněz, financování, skupiny) |

## Veřejná data (`data/`)

| Soubor | Zdroj |
|---|---|
| `csu_energo_2021/` | ČSÚ, ENERGO 2021, publikované tabulky (15018922) |
| `csu_sldb/` | ČSÚ, SLDB 2021, podíly energonositelů podle ORP |
| `eru/eru_teplo_2024.csv` | ERÚ, výsledné ceny tepelné energie 2024 (převod z PDF: `eru_pdf_na_csv.py`) |
| `mf/` | MF ČR, mikroregionální ukazatel energetické chudoby (ORP) |
| `mpo/` | MPO, dodávky tepelných čerpadel |
| `eurostat_kalibrace.csv` | Eurostat `nrg_bal_c`, `nrg_chdd_a` (cache pro kalibraci C1) |

## Malé buňky

Výstupy pro web potlačují skupiny s méně než 30 domácnostmi ve vzorku. Některé mezivýpočty
(podíl uhlí ze SRÚ) stojí na zhruba 90 domácnostech na skupinu; čti je jako orientační.
