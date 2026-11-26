# Data pro slajdy – Segmentace průmyslu

Tabulky v této složce stačí k nakreslení všech grafů prezentace *Ohrožují ceny energií a povolenek český průmysl?*
Jsou to malé agregáty za obory, zaokrouhlené pro grafy. Čísla z nich **nepřepisujte ručně do grafů ani textů**.
Když se změní data, vygenerují se znovu (viz [Jak data obnovit](#jak-data-obnovit)).

- Formát: CSV, UTF-8, oddělovač čárka, desetinná tečka.
- Čísla snímků (S1–S25) odpovídají `Průmysl – Slidedeck v1`.
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

## Soubory po snímcích

| Snímek | Soubor | Sloupce | Poznámka pod graf |
|---|---|---|---|
| S3 | – | souhrnná čísla: v kolika oborech roste Česko rychleji (`vyroba_index.csv`), kolik oborů má energii pod 5 % (`naklady_energie_prace.csv`), náklady ETS průmyslu = `nepr_ets` + `prime_ets` pro `nace = C` (`naklady_ets.csv`), 72 % (`povolenky_zdarma.csv`) | Výpočet v notebooku u S3. |
| S5 | `prumysl_kpi.csv` | `podil_hph_cr_pct` – podíl 18 oborů na HPH Česka (%), `pracujici_tis`, `zamestnanci_tis` | Eurostat nama_10_a64, nama_10_a64_e (2025). Pracující = zaměstnanci + podnikatelé. |
| S6, S7 | `obory_2025.csv` | `podil_hph` – podíl na hrubé přidané hodnotě průmyslu 2025 (%), `pracujici_tis` – pracující (tis. osob) | Eurostat nama_10_a64, nama_10_a64_e (2025, předběžně). Bez rafinerií. |
| S8 | `vyroba_zmena.csv` | `zmena_pct` – změna objemu výroby v Česku 2015 → 2025 (%) | Eurostat sts_inpr_a. Potraviny a nábytek = vážený průměr podoborů. |
| S9, S19 | `vyroba_index.csv` | `zeme` (CZ, DE), `rok` 2015–2025, `index` – objem výroby, 2015 = 100 | Eurostat sts_inpr_a, očištěno o pracovní dny. Potraviny = C10–12, nábytek = C31+C32 (váhy HPH 2021). |
| S11 | `naklady_energie_prace.csv` | `energie_pct`, `prace_pct` – nákupy energie a náklady práce v % celkových nákladů (průměr 2024–25), `hph_mld_kc` – velikost bubliny | ČSÚ, tabulky dodávek a užití 2024–25. Chemie vč. rafinerií Litvínov a Kralupy (ORLEN Unipetrol); energie chemie 11–20 % podle zacházení s ropnými produkty. Čáry = medián oborů (bez řádku `C`). |
| S12 | `energie_narocnost.csv` | `tj_na_mil_eur` – TJ energie na mil. € HPH (2023), `hlavni_palivo`, `hlavni_podil` (%) | Čisté užití energie pro energetické účely (Eurostat env_ac_pefa04): bez surovin pro chemii a bez energie vyrobené v oboru – hutě 63, chemie 17, papír 16 TJ / mil. €. |
| S13 | `energie_skladba_6.csv` | `radek` (6 nejnáročnějších oborů + `ostatni`), `zdroj` (7 skupin), `podil` (%) | Eurostat env_ac_pefasu (2023). Užití energie bez surovin pro chemii (vč. vstupů do koksoven a vysokých pecí); ostatní obory jako průměr vážený spotřebou. |
| S15, S16 | `povolenky_zdarma.csv` | `sektor`, `zdarma_mt`, `emise_mt` (Mt CO₂), `podil_zdarma` (%) | EU Union Registry 2025, průmyslová zařízení v ČR. Ocel = C24; cement = výroba slínku a vápna; sklo a keramika = zbytek C23; chemie vč. rafinerií (viz Známé problémy). |
| S17 | `naklady_ets.csv` | `podil_nakladu` – podíl oboru na nákladech průmyslu 2024; `energie` – nákupy energie; `nepr_ets` – nepřímé náklady ETS (elektřina ze sítě, **po kompenzaci**); `nepr_ets_pred_kompenzaci`, `nepr_ets_vc_vlastni` – varianty; `prime_ets` – přímé čisté (netto); `prime_ets_nejlepsi`, `prime_ets_deficity` – varianty; vše v % celkových nákladů | Celkové náklady = mezispotřeba + náhrady zaměstnancům (ČSÚ SUT; energie 2024–25, ETS 2024). Nepřímé = elektřina **ze sítě** 2023 × 0,85 t/MWh × 65 €/t **minus kompenzace** vyplacená za rok 2024 (MPO); horní odhad (maximální emisní faktor). Vysvětlení v `docs/neprime_naklady_ets.md`. Přímé = (emise − povolenky zdarma) × 65 €/t, **netto** (přebytky snižují náklad). — = obor bez zařízení v ETS. |
| S19 | `karta_export.csv` | lišta exportního jádra: `energie`, `prime_ets` (%), `vyroba` (změna 2015 → 2025, %) | jako S9, S11, S17 |
| S19 | `dovoz_aut_cina.csv` | `dovoz_mld_eur` – dovoz osobních aut (HS 8703) z Číny do EU27, mld. € | Eurostat Comext DS-059341 |
| S19 | `mzdy_produktivita.csv` | `podil_prace_hph` – náhrady zaměstnancům v % HPH; `naklady_prace`, `hph_na_prac` – indexy 2015 = 100 | Eurostat nama_10_a64. Ukazatel karty 3 je podíl práce na HPH (obojí v běžných cenách, ze stejného zdroje). |
| S20–S22 | `karty_oboru.csv` | lišta oborů: `vyroba` (%), `energie` (% nákladů), `prime_ets` (% nákladů), `prime_pozn`, `zdarma` (%) | U hutí nejlepší odhad přímých nákladů (Energetika Třinec 86,5 %), u chemie horní odhad. |
| S21 | `hute_zavody.csv` | `zavod` (Ostrava, Třinec, ostatní), `rok`, `emise_kt`, `zdarma_kt` | EU Union Registry. Ostrava = Liberty + TAMEH, Třinec = TŽ + Energetika Třinec. |
| S22 | – | rozklad chemie: skupina ORLEN Unipetrol = 72 % emisí chemie; povolenky = 2,1 % nákladů firmy (2024) | registr EU ETS; výroční zpráva ORLEN Unipetrol 2025. Výpočet v notebooku u S22. |
| S23 | `naklady_energie_prace.csv` | sloupec Energie v tabulce segmentů (rozpětí za skupiny oborů) | Výpočet v notebooku u S23. Ostatní sloupce jsou pracovní návrh autorů. |
| S25 | `energie_skladba.csv` + `energie_narocnost.csv` | `palivo`, `podil` – % hrubého užití energie všech 18 oborů (2023) | Eurostat env_ac_pefasu; bez nafty jako suroviny. Délka pruhu náročnosti z `energie_narocnost.csv`. |
| Německo (bez čísla) | `nemecko_vyroba.csv`, `nemecko_vyvoz.csv` | výroba: `zeme`, `ctvrtleti`, `index` (2022 = 100). Vývoz: `skupina_zbozi` (Celkem, Auta a díly, Stroje, Elektro, Železo a ocel, Chemie a plasty), `obdobi` (stejné měsíce každého roku, např. 1–8/2026), `vyvoz_cz_index` – vývoz CZ→DE ve stálých cenách, `dovoz_de_index` – celý dovoz Německa ve stálých cenách (oba 2022 = 100), `podil_cz_pct` – podíl ČR na dovozu Německa | Eurostat sts_inpr_m (zprac. průmysl, sezónně očištěno); Comext DS-045409 (dovoz DE z CZ a ze světa), deflováno indexem dovozních cen DE ze zemí EU (sts_inpi_m). Podíl v běžných cenách. |

Snímky bez grafů (S1, S2, S4, S10, S14, S18, S24) mají texty v decku. Číslo o nákladech na povolenky na S24
je stejné jako na S3.

**Doplňkově (v decku v1 není):** `obchod_2024.csv` a `skupiny_oboru.csv` – dovozní penetrace a vývoz mimo oblast
EU ETS z Eurostat FIGARO 2024 (a 2015). Popis v notebooku, sekce D1–D3.

## Známé problémy

- **Rafinerie vs. chemie.** ČSÚ řadí podnik ORLEN Unipetrol RPA podle hlavní činnosti celý do chemie (C20),
  i s rafineriemi Litvínov a Kralupy; obor rafinerie (C19) má proto v národních účtech skoro nulovou přidanou hodnotu.
  Registr EU ETS ale vede rafinerie jako samostatná zařízení. Aby čitatel i jmenovatel seděly, jsou rafinerie
  ve všech datech v chemii (C20). „Chemie“ tak znamená chemii včetně rafinerií a z velké části skupinu ORLEN Unipetrol
  (72 % emisí chemie). Oddělit náklady rafinerií od zbytku chemie z veřejných dat čistě nejde. Na slajdech s chemií
  proto uvádět „vč. rafinerií Litvínov a Kralupy (ORLEN Unipetrol)“.

## Jak data obnovit

Ve složce `scripts/segmentace-prumyslu` (R ≥ 4.2):

```
Rscript R/run_all.R                  # spočítá vše z uložených dat a přepíše tuto složku
FOK_REFRESH=1 Rscript R/run_all.R    # nejdřív znovu stáhne všechna data
```

Kdy byla data naposledy stažena a aktualizována u zdroje: `out/stazena_data.csv`. Otázky: Jakub Komárek.
