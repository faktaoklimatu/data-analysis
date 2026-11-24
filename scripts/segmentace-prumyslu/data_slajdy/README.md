# Data pro slajdy – Segmentace průmyslu

Tabulky v této složce stačí k nakreslení všech grafů prezentace *Co rozhoduje o prosperitě českého průmyslu?*
Jsou to malé agregáty za obory, zaokrouhlené pro grafy. Čísla z nich **nepřepisujte ručně do grafů ani textů**.
Když se změní data, vygenerují se znovu (viz [Jak data obnovit](#jak-data-obnovit)).

- Formát: CSV, UTF-8, oddělovač čárka, desetinná tečka.
- Čísla slajdů odpovídají PDF `CZ segmentace průmyslu 2026.pdf` (29 stran).
- Výpočty ke každému slajdu (zdroj → kód → výsledek):
  [kontrolní notebook](https://raw.githack.com/faktaoklimatu/data-analysis/segmentace-prumyslu/scripts/segmentace-prumyslu/notebook/kontrola_vypoctu.html).
- Ukázková implementace všech grafů v d3 (webová verze decku): `web-cz`, soubor `assets-local/js/segmentace-prumyslu.js`. Je jen lokálně u Jakuba, na vyžádání.

## Společné sloupce

| Sloupec | Význam |
|---|---|
| `nace` | kód oboru CZ-NACE (`C10-12` potraviny, `C24` hutě…; `C` = zpracovatelský průmysl celkem) |
| `obor` | český název oboru pro popisky |
| `skupina` | barva v grafech: `export` = exportní jádro (C26–C30, modrá `#3a87c8`), `energie` = energeticky nejnáročnější (C17, C20, C23, C24, korálová `#f06a4e`), `ostatni` (šedá `#b9b9b9`), `celek` = průmysl celkem |

Hodnoty `%` jsou v procentech (15.5 = 15,5 %). Prázdná buňka = obor nemá data (např. nemá zařízení v EU ETS).

## Soubory po slajdech

| Str. | Soubor | Sloupce | Poznámka pod graf |
|---|---|---|---|
| 5, 6 | `obory_2025.csv` | `podil_hph` – podíl na hrubé přidané hodnotě průmyslu 2025 (%), `pracujici_tis` – pracující (tis. osob) | Eurostat nama_10_a64, nama_10_a64_e (2025, předběžně). Bez rafinerií. |
| 7, 20 | `vyroba_index.csv` | `zeme` (CZ, DE), `rok` 2015–2025, `index` – objem výroby, 2015 = 100 | Eurostat sts_inpr_a, očištěno o pracovní dny. Potraviny = C10–12, nábytek = C31+C32 (váhy HPH 2021). Aktuálně Česko roste rychleji v 16 z 18 oborů (výjimky hutě a ostatní doprava). |
| 10 | `naklady_energie_prace.csv` | `energie_pct`, `prace_pct` – nákupy energie a náklady práce v % celkových nákladů (průměr 2024–25), `hph_mld_kc` – velikost bubliny | ČSÚ, tabulky dodávek a užití 2024–25. Chemie vč. rafinerií Litvínov a Kralupy (ORLEN Unipetrol); energie chemie 11–20 % podle zacházení s ropnými produkty. Čáry = medián oborů (bez řádku `C`). |
| 11 | `energie_narocnost.csv` | `tj_na_mil_eur` – TJ energie na mil. € HPH (2023), `hlavni_palivo`, `hlavni_podil` (%) | Čisté užití energie pro energetické účely (Eurostat env_ac_pefa04): bez surovin pro chemii a bez energie vyrobené v oboru. Chemie vč. rafinerií. |
| 12 | `energie_skladba.csv` | `palivo`, `podil` – % hrubého užití energie oboru (2023) | Eurostat env_ac_pefasu; bez nafty jako suroviny pro chemii. Délka pruhu náročnosti z `energie_narocnost.csv`. |
| 15, 16 | `povolenky_zdarma.csv` | `sektor`, `zdarma_mt`, `emise_mt` (Mt CO₂), `podil_zdarma` (%) | EU Union Registry 2025, průmyslová zařízení v ČR. Ocel = C24; cement = výroba slínku a vápna; sklo a keramika = zbytek C23; chemie vč. rafinerií (proto 52 %, ne 46 %). |
| 17 | `naklady_ets.csv` | `podil_nakladu` – podíl oboru na nákladech průmyslu 2024; `energie` – nákupy energie; `nepr_ets` – nepřímé náklady ETS; `prime_ets` – přímé čisté (netto); `prime_ets_nejlepsi`, `prime_ets_deficity` – varianty; vše v % celkových nákladů | Celkové náklady = mezispotřeba + náhrady zaměstnancům (ČSÚ SUT; energie 2024–25, ETS 2024). Nepřímé = elektřina 2023 × 0,85 t/MWh × 65 €/t, **horní odhad**. Přímé = (emise − povolenky zdarma) × 65 €/t, **netto** (přebytky snižují náklad). — = obor bez zařízení v ETS. |
| 20 | `karta_export.csv` | lišta exportního jádra: `energie`, `prime_ets` (%), `vyroba` (změna 2015 → 2025, %) | jako str. 7, 10, 17 |
| 20 | `dovoz_aut_cina.csv` | `dovoz_mld_eur` – dovoz osobních aut (HS 8703) z Číny do EU27, mld. € | Eurostat Comext DS-059341 |
| 20 | `mzdy_produktivita.csv` | `podil_prace_hph` – náhrady zaměstnancům v % HPH (**hlavní ukazatel karty 3**); `naklady_prace`, `hph_na_prac` – indexy 2015 = 100 (pro srovnání) | Eurostat nama_10_a64. Auta 41 → 52 %, stroje 58 → 69 %. Nahrazuje původní „mzdy vs. výroba na pracujícího“ (nominální vs. objemová veličina se nedaly srovnat). |
| 21–23 | `karty_oboru.csv` | lišta oborů: `vyroba` (%), `energie` (% nákladů), `prime_ets` (% nákladů), `prime_pozn`, `zdarma` (%) | U hutí nejlepší odhad přímých nákladů (Energetika Třinec 86,5 %), u chemie horní odhad. |
| 22 | `hute_zavody.csv` | `zavod` (Ostrava, Třinec, ostatní), `rok`, `emise_kt`, `zdarma_kt` | EU Union Registry. Ostrava = Liberty + TAMEH, Třinec = TŽ + Energetika Třinec. |
| 23 | – | rozklad chemie: skupina ORLEN Unipetrol = 72 % emisí chemie; povolenky = 2,1 % nákladů firmy (2024) | registr EU ETS; výroční zpráva ORLEN Unipetrol 2025. Výpočet v notebooku u str. 23. |
| 26, 28 | `obchod_2024.csv` | `penetrace`, `z_eu`, `mimo_eu` – dovozní penetrace a její rozdělení (%); `vyvoz_mimo_ets`, `vyvoz_uk` – % produkce oboru; `vyvoz_mimo_ets_mld` – objem (mld. €); `cbam` – barva str. 28 (`cely`, `cast`, `odberatel`, `ostatni`) | Eurostat FIGARO 2024. Penetrace = dovoz / (produkce − vývoz + dovoz). Mimo oblast EU ETS = mimo EU, NO, IS, LI, CH. Na str. 28 vynechat tisk (C18) a rafinerie (C19). |
| 26, 27 | `skupiny_oboru.csv` | obory se sloučením dřevo + papír (`C16_17`) a rafinerie + chemie (`C19_20`); `rok` 2015 a 2024; `penetrace`, `z_eu`, `mimo_eu` (%); `tj_na_mil_eur`; `hph_meur` – velikost bubliny | Str. 26 bere dřevo + papír odsud, ostatní obory z `obchod_2024.csv`. Str. 27: prahy 10 TJ / mil. € a 50 %; energie 2015 a 2023 (2024 nevyšlo). |

Snímky bez dat (1–4, 8, 9, 13, 14, 18, 19, 24, 25, 29) mají texty v PDF. Jediné číslo v nich, „náklady ETS průmyslu zhruba X % nákladů“
na str. 24, je součet `nepr_ets` + `prime_ets` pro `nace = C` v `naklady_ets.csv` (teď 0,7 %).

## Co se oproti PDF změnilo

- Chemie zahrnuje rafinerie Litvínov a Kralupy (jako ČSÚ): povolenky zdarma 52 % místo 46 %, přímý náklad ETS 1,7 % místo 1,0 %.
- Energetická náročnost (str. 11, 27) je jen energie pro energetické účely: hutě 63, chemie 17, papír 16 TJ / mil. € (dřív 113 / 51 / 39).
- Str. 17: všechny % jsou ze stejného jmenovatele (SUT ČSÚ).
- Str. 20, karta 3: podíl práce na HPH místo mezd vs. objemu výroby.
- Eurostat průběžně reviduje data: str. 7 je teď 16 z 18 oborů (dřív 17), dovoz čínských aut 13,9 mld. € (dřív 13,8).

## Jak data obnovit

Ve složce `scripts/segmentace-prumyslu` (R ≥ 4.2):

```
Rscript R/run_all.R                  # spočítá vše z uložených dat a přepíše tuto složku
FOK_REFRESH=1 Rscript R/run_all.R    # nejdřív znovu stáhne všechna data
```

Kdy byla data naposledy stažena a aktualizována u zdroje: `out/stazena_data.csv`. Otázky: Jakub Komárek.
