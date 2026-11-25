# 13_data_web.R – agregovaná data pro grafy na webu (série ETS2 a domácnosti, repozitář web-cz)
# Výstup: WEB_DIR/_data/ets2/*.csv – jen agregáty (archetypy, pravidla, roky), nikdy data za domácnosti.
# Vstupy: výstupy 03, 09 a 11 (output/), Eurostat API (nrg_bal_c, nrg_bal_peh, nrg_pc_202) – potřebuje internet.
#
#   spotreba_domacnosti.csv  graf spotřeby energie domácností podle přímých toků (text I)
#   soky.csv                 graf „Fosilní šoky stály domácnosti víc, než by stálo ETS2“ (text I)
#   zranitelne.csv           graf „Nejvíc zranitelných je v domech na plyn…“ (text I)
#   kompenzace.csv           graf srovnání pravidel přímé platby (text II, podle ETS2_kompenzace_navrh_v3.md, tab. 5.1)
#   skupiny.csv              čtverečkový graf velikosti skupin a podílu zranitelných (text I)
#   tc_ceny.csv              prodej tepelných čerpadel a ceny plynu a elektřiny (text I)
#   energie_kaskada.csv      primární, konečná a užitečná energie domácností (prototyp, text I)
#   emise_domacnosti.csv     emise CO2 ze spotřeby energie domácností podle zdroje (prototyp, text I)
#   financovani.csv          kolik by přišlo z fondu a kolik by stála pomoc (text II)

if (!exists("WEB_DIR")) source("00_setup.R")
web <- file.path(WEB_DIR, "_data", "ets2")
zaokr <- function(x, d = 0) floor(x * 10^d + 0.5) / 10^d   # běžné zaokrouhlení (R round() zaokrouhluje 0,5 k sudé)
dir.create(web, showWarnings = FALSE, recursive = TRUE)
eurostat <- function(tab, klic, od = 2005) {
  url <- sprintf("https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/%s/%s?format=SDMX-CSV&startPeriod=%s", tab, klic, od)
  read_csv(url, show_col_types = FALSE, col_types = cols(.default = "c")) |>
    mutate(rok = TIME_PERIOD, hodnota = as.numeric(OBS_VALUE))
}

# ---------------------------------------------------------------------------------------------
# 1. Spotřeba energie domácností podle toho, co do domácnosti přiteklo, PJ (2005–2024)
#    Eurostat nrg_bal_c, konečná spotřeba domácností FC_OTH_HH_E. Graf ukazuje přímé toky: paliva
#    spálená v domácnosti, okolní teplo tepelných čerpadel, elektřinu (E7000) a teplo ze sítě (H8000).
#    Rozpočet elektřiny a tepla podle skladby hrubé výroby (nrg_bal_peh, GEP a GHP; bez dovozu
#    a vývozu, přiblížení) se počítá jen pro kontrolu podílu fosilních paliv v textu.
#    Sloupec tc = okolní teplo tepelných čerpadel + solární teplo z kolektorů (obojí bez povolenek);
#    elektřina pro tepelná čerpadla je v elektřině (Eurostat ji nevykazuje zvlášť).
#    Teplo ze sítě je rozdělené na zdroje v ETS1 a v ETS2 podle podílu bytů na teple ze zdroje v ETS2
#    (asi 380 tis. z SILC, 09_silc_teplo_ets1.csv); podíl je stejný pro všechny roky a předpokládá
#    stejnou spotřebu tepla na byt (přiblížení).
# ---------------------------------------------------------------------------------------------
hh <- eurostat("nrg_bal_c", "A.FC_OTH_HH_E..TJ.CZ") |> select(rok, siec, hodnota)
F_TEPLO_ETS2 <- with(read_csv(file.path(OUT_DIR, "09_silc_teplo_ets1.csv"), show_col_types = FALSE),
                     domacnosti_teplo_ets2_tis / domacnosti_teplo_celkem_tis)
el <- eurostat("nrg_bal_peh", "A.GEP..GWH.CZ")      |> select(rok, siec, hodnota)
ht <- eurostat("nrg_bal_peh", "A.GHP..TJ.CZ")       |> select(rok, siec, hodnota)

UHLI  <- c("C0000X0350-0370", "C0350-0370", "P1000", "S2000")
FOSIL <- c("G3000", "O4000XBIO", "W6100_6220")          # plyn, ropné produkty, neobnovitelný odpad
OZE_E <- c("RA100", "RA200", "RA300", "RA410", "RA420", "RA500")   # voda, geotermální, vítr, slunce, příliv
v <- function(d, kody) d |> filter(siec %in% kody) |> group_by(rok) |> summarise(x = sum(hodnota, na.rm = TRUE))
podily <- function(d) {
  tot <- d |> filter(siec == "TOTAL") |> select(rok, tot = hodnota)
  tot |> left_join(v(d, UHLI) |> rename(u = x), by = "rok") |>
    left_join(v(d, FOSIL) |> rename(f = x), by = "rok") |>
    left_join(v(d, OZE_E) |> rename(o = x), by = "rok") |>
    transmute(rok, p_uhli = u / tot, p_fosil = f / tot, p_oze = o / tot)
}
pe <- podily(el); ph <- podily(ht)
spotreba <- v(hh, "TOTAL") |> rename(total = x) |>
  left_join(v(hh, UHLI) |> rename(uhli_d = x), by = "rok") |>
  left_join(v(hh, FOSIL) |> rename(fosil_d = x), by = "rok") |>
  left_join(v(hh, "R5110-5150_W6000RI") |> rename(drevo = x), by = "rok") |>
  left_join(v(hh, "RA600") |> rename(tc = x), by = "rok") |>
  left_join(v(hh, "RA410") |> rename(solar = x), by = "rok") |>
  left_join(v(hh, "E7000") |> rename(elektrina = x), by = "rok") |>
  left_join(v(hh, "H8000") |> rename(teplo = x), by = "rok") |>
  left_join(pe |> rename_with(~ paste0(.x, "_e"), -rok), by = "rok") |>
  left_join(ph |> rename_with(~ paste0(.x, "_h"), -rok), by = "rok") |>
  mutate(across(everything(), ~ ifelse(is.na(.x), 0, .x))) |>
  mutate(fosil_rozp = uhli_d + fosil_d + elektrina * (p_uhli_e + p_fosil_e) + teplo * (p_uhli_h + p_fosil_h)) |>
  transmute(rok,
            uhli   = uhli_d,
            plyn   = fosil_d,                      # plyn, ropné produkty, neobnovitelný odpad
            teplo_ets1 = teplo * (1 - F_TEPLO_ETS2),
            teplo_ets2 = teplo * F_TEPLO_ETS2,
            elektrina,
            tc     = tc + solar,                   # okolní teplo tepelných čerpadel (RA600) a solární kolektory (RA410)
            # dřevo a zbytek: bioplyn, biopaliva, obnovitelný odpad
            drevo  = total - uhli_d - fosil_d - teplo - elektrina - tc,
            celkem = total,
            fosil_rozp) |>
  mutate(across(-rok, ~ .x / 1000)) |>             # TJ -> PJ
  filter(rok >= 2005) |> arrange(rok)
stopifnot(all(spotreba$drevo >= 0))
pr <- function(x) round(100 * x)
with(spotreba, {
  i <- c(1, length(rok))
  cat("Přímo spálená fosilní paliva (PJ):", round(uhli + plyn, 1)[i], "| změna", pr((uhli + plyn)[i[2]] / (uhli + plyn)[1] - 1), "%\n")
  cat("Podíl fosilních paliv vč. rozpočtené elektřiny a tepla:", pr(fosil_rozp / celkem)[i], "% (", rok[i], ")\n")
})
spotreba <- spotreba |> select(-fosil_rozp) |> mutate(across(-rok, ~ zaokr(.x, 1)))
cat("Podíl tepla ze sítě ze zdrojů v ETS2:", round(100 * F_TEPLO_ETS2, 1), "%\n")
cat("Spotřeba domácností (PJ):\n"); print(as.data.frame(spotreba[c(1, nrow(spotreba)), ]))
write_csv(spotreba, file.path(web, "spotreba_domacnosti.csv"))

# ---------------------------------------------------------------------------------------------
# 2. Fosilní šoky vs. ETS2 pro typovou domácnost (RD na plyn s autem na benzín), Kč měsíčně
# ---------------------------------------------------------------------------------------------
typ <- read_csv(file.path(OUT_DIR, "03_typove_domacnosti.csv"), show_col_types = FALSE) |>
  filter(typ == "RD plyn", grepl("^A_", scenar))
plyn_kwh <- typ$spotreba * 10.6                     # m3 -> kWh (spalné teplo, jako ve vyúčtování)
# Realizovaná cena plynu pro domácnosti v pásmu D2 (20–199 GJ) vč. daní, průměr pololetí
cena <- eurostat("nrg_pc_202", "S.G3000.GJ20-199.KWH.I_TAX.NAC.CZ", "2021-S1") |>
  mutate(r = substr(rok, 1, 4)) |> group_by(r) |> summarise(kc_kwh = mean(hodnota, na.rm = TRUE))
c21 <- cena$kc_kwh[cena$r == "2021"]; c23 <- cena$kc_kwh[cena$r == "2023"]
BENZIN_ZDRAZENI_KC_L <- 10    # zdražení benzínu 2025 -> 2026 po uzavření Hormuzského průlivu, Kč/l (zdroj doplnit do inputs.csv)
# Auto: typická domácnost s autem z mikrosimulace (medián zdražení PHM, 09_phm_rozptyl.csv), litry dopočtené
# zdražením benzínu ve scénáři A (09_phm_zdrazeni.csv), aby graf seděl s textem o dopravě (25. 11. 2026)
auto_ets2 <- read_csv(file.path(OUT_DIR, "09_phm_rozptyl.csv"), show_col_types = FALSE) |>
  filter(skupina == "všechny domácnosti") |> pull(P50)
auto_l <- auto_ets2 * 12 / (read_csv(file.path(OUT_DIR, "09_phm_zdrazeni.csv"), show_col_types = FALSE) |>
  filter(scenar == "A", palivo == "benzín") |> pull(kc_na_litr))
soky <- tibble(
  polozka = c("RD na plyn: zdražení 2021→23", "RD na plyn: ETS2", "Auto: zdražení 2025→26", "Auto: ETS2"),
  druh    = c("sok", "ets2", "sok", "ets2"),
  kc_mesic = round(c(plyn_kwh * (c23 - c21) / 12, typ$vytapeni_kc_mesic,
                     auto_l * BENZIN_ZDRAZENI_KC_L / 12, auto_ets2)))
cat("Ceny plynu D2 (Kč/kWh): 2021", round(c21, 2), "| 2023", round(c23, 2), "\n"); print(soky)
write_csv(soky, file.path(web, "soky.csv"))

# ---------------------------------------------------------------------------------------------
# 3. Zranitelné domácnosti podle archetypu (scénář A); počty zaokrouhlené na 5 tis., náklad na 10 Kč
# ---------------------------------------------------------------------------------------------
zr <- read_csv(file.path(OUT_DIR, "09_silc_zranitelne_archetyp.csv"), show_col_types = FALSE) |>
  filter(archetyp != "celkem") |>
  left_join(read_csv(file.path(OUT_DIR, "09_silc_archetypy.csv"), show_col_types = FALSE) |>
              select(archetyp, zranitelne_tis_ci95), by = "archetyp") |>
  transmute(archetyp,
            popisek = recode(archetyp, "RD plyn" = "RD na plyn", "RD uhlí" = "RD na uhlí", "byt plyn" = "Byt na plyn",
                             "byt teplo (zdroj v ETS2)" = "Byt na teple (ETS2)", "ostatní" = "Ostatní"),
            zranitelne_tis = zaokr(zranitelne_tis / 5) * 5,
            interval_tis = zranitelne_tis_ci95,
            ets2_kc_mesic = zaokr(A_ets2_kc_mesic / 10) * 10,
            ets2_pct_prijmu = zaokr(A_ets2_pct_prijmu, 1))
print(zr); write_csv(zr, file.path(web, "zranitelne.csv"))

# ---------------------------------------------------------------------------------------------
# 4. Pravidla přímé platby (scénář A), tabulka 5.1 v ETS2_kompenzace_navrh_v3.md
# ---------------------------------------------------------------------------------------------
PRAVIDLA <- c(plosne = "Všem domácnostem", davky_bydleni = "Příjemcům dávek na bydlení",
              paq_balik = "Návrh PAQ a CVF",
              pal_vlastni_teplo = "Náš návrh (teplo jen z ETS2)",
              pal_vlastni_teplo_vse = "Náš návrh (teplo z ETS2 i ETS1)")
# náklad za celé období 2028–2032: naše pravidla klesají v čase (100, 100, 75, 50, 25 %), ostatní plných pět let
LET_PLNE <- c(pal_vlastni_teplo = 3.5, pal_vlastni_teplo_vse = 3.5)
komp <- read_csv(file.path(OUT_DIR, "11_kompenzace_nastroje.csv"), show_col_types = FALSE) |>
  filter(scenar == "A", pravidlo %in% names(PRAVIDLA)) |>
  transmute(pravidlo, popisek = PRAVIDLA[pravidlo],
            naklad_mld = zaokr(naklad_mld, 1),
            naklad_obdobi_mld = zaokr(naklad_mld * ifelse(pravidlo %in% names(LET_PLNE), LET_PLNE[pravidlo], 5), 1),
            k_zranitelnym_pct = zaokr(podil_k_zranit),
            nedostalo_pct = zaokr(100 - pokryti_zranit),
            vyrovnano_pct = zaokr(vyrovnano_zranit),
            # průměr za 2028–2032 (stejné zdražení každý rok; naše pravidla v čase klesají)
            vyrovnano_obdobi_pct = zaokr(vyrovnano_zranit * ifelse(pravidlo %in% names(LET_PLNE), LET_PLNE[pravidlo], 5) / 5),
            # poslední rok 2032: naše pravidla na 25 % plné výše
            vyrovnano_2032_pct = zaokr(vyrovnano_zranit * ifelse(pravidlo %in% names(LET_PLNE), 0.25, 1))) |>
  arrange(match(pravidlo, names(PRAVIDLA)))
print(komp); write_csv(komp, file.path(web, "kompenzace.csv"))

# ---------------------------------------------------------------------------------------------
# 5. Velikost skupin domácností a kolik z nich je zranitelných (čtverečkový graf, text I)
#    Byty na teple jen v rozsahu domácností napojených na zdroj v ETS2 (asi 380 tis.).
# ---------------------------------------------------------------------------------------------
skup <- read_csv(file.path(OUT_DIR, "09_silc_archetypy.csv"), show_col_types = FALSE) |>
  transmute(archetyp,
            popisek = recode(archetyp, "RD plyn" = "Rodinné domy na plyn", "RD uhlí" = "Rodinné domy na uhlí",
                             "byt plyn" = "Byty s plynovým kotlem", "byt teplo (zdroj v ETS2)" = "Byty na teple ze zdroje v ETS2",
                             "byt teplo (zdroj v ETS1)" = "Byty na teple ze zdroje v ETS1",
                             "ostatní" = "Ostatní (elektřina, tepelné čerpadlo, dřevo aj.)"),
            domacnosti_tis = zaokr(domacnosti_v_ets2_tis),
            zranitelne_tis = zaokr(zranitelne_tis_ets2),
            podil_zranitelnych_pct = zaokr(100 * zranitelne_tis_ets2 / domacnosti_v_ets2_tis)) |>
  arrange(match(archetyp, c("RD uhlí", "RD plyn", "byt plyn", "byt teplo (zdroj v ETS2)", "ostatní")))
# „ostatní“ rozložené podle paliva (09_silc_ostatni.csv); archetypy se tím nemění
ost <- read_csv(file.path(OUT_DIR, "09_silc_ostatni.csv"), show_col_types = FALSE) |>
  transmute(archetyp = paste0("ostatní: ", ostatni_detail),
            popisek = recode(ostatni_detail,
                             "RD dřevo a biomasa" = "Rodinné domy na dřevo",
                             "RD tepelné čerpadlo" = "Rodinné domy na TČ",
                             "RD elektřina" = "Rodinné domy na elektřinu",
                             "byt elektřina" = "Byty na elektřinu",
                             "ostatní (solární a FVE, byty na dřevo nebo uhlí, dálkové teplo v RD, jiné)" = "Ostatní"),
            domacnosti_tis = zaokr(domacnosti_tis), zranitelne_tis = zaokr(zranitelne_tis),
            podil_zranitelnych_pct = zaokr(pct_zranitelne)) |>
  arrange(popisek)
# B9 (25. 11. 2026): malé buňky – počet zranitelných se nezveřejňuje, pokud za ním je méně než 30 domácností ve vzorku
N_MIN <- 30
n_zr <- read_csv(file.path(OUT_DIR, "09_e4_ostatni_zranitelne.csv"), show_col_types = FALSE) |>
  transmute(archetyp = paste0("ostatní: ", ostatni_detail), n_zr = n_vzorek)
ost <- ost |> left_join(n_zr, by = "archetyp") |>
  mutate(potlaceno = is.na(n_zr) | n_zr < N_MIN,
         zranitelne_tis = ifelse(potlaceno, NA_real_, zranitelne_tis),
         podil_zranitelnych_pct = ifelse(potlaceno, NA_real_, podil_zranitelnych_pct)) |>
  select(-n_zr, -potlaceno)
cat("B9: skupiny „ostatní“ s potlačeným počtem zranitelných (n < ", N_MIN, "):", sum(is.na(ost$zranitelne_tis)), "\n")
ets1 <- read_csv(file.path(OUT_DIR, "09_silc_teplo_ets1.csv"), show_col_types = FALSE) |>
  transmute(archetyp = "byt teplo (zdroj v ETS1)", popisek = "Byty na teple ze zdroje v ETS1",
            domacnosti_tis = zaokr(domacnosti_teplo_ets1_tis), zranitelne_tis = NA_real_, podil_zranitelnych_pct = NA_real_)
# pořadí v grafu: od největší skupiny po nejmenší, „Jiné“ na konci
# od B3 (25. 11. 2026) jsou byty na teple z ETS1 samostatný archetyp v 09 (i se zranitelnými kvůli plynu) -> ets1 se nepřidává
skup <- bind_rows(skup |> filter(archetyp != "ostatní"), ost) |>
  arrange(popisek == "Ostatní", desc(domacnosti_tis))
cat("Domácností v grafu celkem:", sum(skup$domacnosti_tis), "tis.\n")
print(skup); write_csv(skup, file.path(web, "skupiny.csv"))
# ---------------------------------------------------------------------------------------------
# 6. Dodávky tepelných čerpadel na český trh a ceny plynu a elektřiny pro domácnosti (2010–2025)
#    Tepelná čerpadla: MPO, Dodávka tepelných čerpadel na trh v ČR v roce 2025 (duben 2026), tabulka
#    „Odhad dodávky tepelných čerpadel určených především k vytápění“, přepsáno do
#    ../data/mpo/tepelna_cerpadla_dodavky.csv (MPO nevydává strojově čitelný soubor):
#    https://mpo.gov.cz/assets/cz/energetika/statistika/obnovitelne-zdroje-energie/2026/4/Tepelna-cerpadla-2010-2025.pdf
#    Bez TČ vzduch-vzduch; MPO nerozlišuje domácnosti a firmy. V roce 2022 dává součet typů o 1 ks víc
#    než sloupec Celkem (zaokrouhlení v odhadu MPO), používá se Celkem.
#    Ceny: Eurostat nrg_pc_202 (plyn, 20–199 GJ) a nrg_pc_204 (elektřina, 2 500–4 999 kWh),
#    Kč/kWh vč. daní, roční průměr dvou pololetí.
# ---------------------------------------------------------------------------------------------
tc <- read_csv(file.path("..", "data", "mpo", "tepelna_cerpadla_dodavky.csv"), show_col_types = FALSE) |>
  select(rok, tc_ks = celkem)
rocne <- function(d, nazev) d |> mutate(rok = as.integer(substr(rok, 1, 4))) |> group_by(rok) |>
  summarise(n = n(), x = mean(hodnota)) |> filter(n == 2) |> select(rok, !!nazev := x)
plyn_c <- rocne(eurostat("nrg_pc_202", "S.G3000.GJ20-199.KWH.I_TAX.NAC.CZ", "2007-S1"), "plyn_kc_kwh")
elek_c <- rocne(eurostat("nrg_pc_204", "S.E7000.KWH2500-4999.KWH.I_TAX.NAC.CZ", "2007-S1"), "elektrina_kc_kwh")
tc_ceny <- tc |> left_join(plyn_c, by = "rok") |> left_join(elek_c, by = "rok") |>
  mutate(across(c(plyn_kc_kwh, elektrina_kc_kwh), ~ zaokr(.x, 2)))
stopifnot(!anyNA(tc_ceny))
print(as.data.frame(tc_ceny)); write_csv(tc_ceny, file.path(web, "tc_ceny.csv"))
# ---------------------------------------------------------------------------------------------
# 7. Primární, konečná a užitečná energie domácností podle zdroje, PJ (prototyp)
#    Konečná = sekce 1. Primární: elektřina a teplo ze sítě × kolik primární energie stojí 1 PJ dodaný
#    spotřebitelům v daném roce (nrg_bal_c: vstupy do elektráren a tepláren, výstupy, vlastní spotřeba
#    energetiky NRG_E a ztráty v sítích DL). Metoda Eurostatu (fyzikální energetický obsah): jádro jako
#    teplo z reaktoru (účinnost ~33 %), voda, vítr a slunce se 100 %. Vstupy do kogenerace rozdělené na
#    elektřinu a teplo podle podílu výstupů. Dovoz a vývoz elektřiny se nezohledňuje (domácí průměr).
#    Paliva spálená v domácnosti, dřevo, okolní a solární teplo: primární = konečná (těžba a doprava
#    paliv nejsou v bilanci ČR).
#    Užitečná: konečná × účinnost spotřebiče. Uhlí a plyn podle 12_cena_tepla.R (starý kotel na uhlí
#    55–65 %, starší plynový kotel 85 %); dřevo a teplo ze sítě jsou předpoklady prototypu. Elektřina 100 %:
#    její užitek ve spotřebičích se neodlišuje; okolní teplo TČ se počítá celé (elektřina, která TČ pohání,
#    je ve vrstvě elektřina). Účinnosti jsou stejné pro všechny roky.
# ---------------------------------------------------------------------------------------------
UCINNOST <- c(uhli = 0.60, plyn = 0.85, drevo = 0.65, teplo = 0.95, elektrina = 1, tc = 1)
bal <- eurostat("nrg_bal_c", "A..TOTAL+E7000+H8000.TJ.CZ") |> select(rok, nrg_bal, siec, hodnota) |>
  mutate(rok = as.integer(rok), hodnota = coalesce(hodnota, 0))
b <- function(kody, s = "TOTAL") bal |> filter(nrg_bal %in% kody, siec == s) |> group_by(rok) |> summarise(x = sum(hodnota))
fak <- b(c("TI_EHG_MAPE_E", "TI_EHG_APE_E")) |> rename(ti_e = x) |>
  left_join(b(c("TI_EHG_MAPCHP_E", "TI_EHG_APCHP_E")) |> rename(ti_chp = x), by = "rok") |>
  left_join(b(c("TI_EHG_MAPH_E", "TI_EHG_APH_E")) |> rename(ti_h = x), by = "rok") |>
  left_join(b(c("TO_EHG_MAPE", "TO_EHG_APE"), "E7000") |> rename(to_e = x), by = "rok") |>
  left_join(b(c("TO_EHG_MAPCHP", "TO_EHG_APCHP"), "E7000") |> rename(to_chp_e = x), by = "rok") |>
  left_join(b(c("TO_EHG_MAPCHP", "TO_EHG_APCHP"), "H8000") |> rename(to_chp_h = x), by = "rok") |>
  left_join(b(c("TO_EHG_MAPH", "TO_EHG_APH"), "H8000") |> rename(to_h = x), by = "rok") |>
  left_join(b(c("NRG_E", "DL"), "E7000") |> rename(ztr_e = x), by = "rok") |>
  left_join(b(c("NRG_E", "DL"), "H8000") |> rename(ztr_h = x), by = "rok") |>
  mutate(chp_e = to_chp_e / (to_chp_e + to_chp_h),
         f_elektrina = (ti_e + ti_chp * chp_e) / (to_e + to_chp_e - ztr_e),
         f_teplo     = (ti_h + ti_chp * (1 - chp_e)) / (to_h + to_chp_h - ztr_h)) |>
  select(rok, f_elektrina, f_teplo)
stopifnot(all(fak$f_elektrina > 1), all(fak$f_teplo > 1))
cat("Primární energie na 1 PJ dodaný (elektřina, teplo):\n"); print(as.data.frame(fak |> filter(rok %in% c(2005, 2024)) |> mutate(across(-rok, ~ round(.x, 2)))))
kaskada <- read_csv(file.path(web, "spotreba_domacnosti.csv"), show_col_types = FALSE) |>
  mutate(teplo = teplo_ets1 + teplo_ets2) |> select(rok, all_of(names(UCINNOST))) |>
  pivot_longer(-rok, names_to = "zdroj", values_to = "konecna_pj") |>
  left_join(fak, by = "rok") |>
  mutate(primarni_pj = konecna_pj * case_when(zdroj == "elektrina" ~ f_elektrina, zdroj == "teplo" ~ f_teplo, TRUE ~ 1),
         uzitecna_pj = konecna_pj * UCINNOST[zdroj]) |>
  select(rok, zdroj, primarni_pj, konecna_pj, uzitecna_pj) |>
  mutate(across(ends_with("_pj"), ~ zaokr(.x, 1)))
stopifnot(!anyNA(kaskada))
print(as.data.frame(kaskada |> filter(rok %in% c(2005, 2024)) |> group_by(rok) |> summarise(across(ends_with("_pj"), sum))))
write_csv(kaskada, file.path(web, "energie_kaskada.csv"))
# ---------------------------------------------------------------------------------------------
# 8. Emise CO2 ze spotřeby energie domácností podle zdroje, Mt CO2 (prototyp)
#    Paliva spálená v domácnosti: spotřeba (nrg_bal_c FC_OTH_HH_E) × emisní faktor paliva.
#    Elektřina a teplo ze sítě: emise z fosilních paliv vstupujících do elektráren, kogenerace a výtopen
#    (TI_EHG_*), kogenerace rozdělená podle podílu výstupů, děleno energií dodanou spotřebitelům
#    (jako v sekci 7), × spotřeba domácností. Dovoz a vývoz elektřiny se nezohledňuje.
#    Dřevo, bioplyn, okolní a solární teplo: 0 (CO2 z biomasy se podle pravidel IPCC do emisí nezapočítává).
#    Emisní faktory t CO2/TJ: hnědé a černé uhlí, plyn, brikety, koks a topný olej ČHMÚ (../inputs.csv);
#    ostatní IPCC 2006 Guidelines, sv. 2, tab. 1.4 (výchozí hodnoty).
# ---------------------------------------------------------------------------------------------
EF <- c(C0110 = 98.3, C0121 = 94.6, C0129 = 94.04, C0210 = 96.1, C0220 = 99.05, C0311 = 107.0, C0312 = 107.0,
        C0320 = 97.5, C0330 = 97.5, C0340 = 80.7, C0350 = 44.4, C0360 = 44.4, C0371 = 260, C0379 = 182,
        P1100 = 106, P1200 = 106, S2000 = 107, G3000 = 55.61, O4000XBIO = 74.1, W6100 = 143, W6220 = 91.7)
TI_E <- c("TI_EHG_MAPE_E", "TI_EHG_APE_E"); TI_C <- c("TI_EHG_MAPCHP_E", "TI_EHG_APCHP_E"); TI_H <- c("TI_EHG_MAPH_E", "TI_EHG_APH_E")
pal <- eurostat("nrg_bal_c", paste0("A.", paste(c(TI_E, TI_C, TI_H, "FC_OTH_HH_E"), collapse = "+"), ".",
                                   paste(c(names(EF), "C0000X0350-0370", "C0350-0370"), collapse = "+"), ".TJ.CZ")) |>
  mutate(rok = as.integer(rok), hodnota = coalesce(hodnota, 0))
# kontrola: listové kódy uhlí a vyrobených plynů dávají dohromady souhrnné kódy
kontrola <- pal |> group_by(rok, nrg_bal) |>
  summarise(listy = sum(hodnota[grepl("^C0", siec) & siec %in% names(EF)]),
            souhrn = sum(hodnota[siec %in% c("C0000X0350-0370", "C0350-0370")]), .groups = "drop")
stopifnot(all(abs(kontrola$listy - kontrola$souhrn) <= pmax(1, 0.01 * kontrola$souhrn)))
em <- function(kody) pal |> filter(nrg_bal %in% kody, siec %in% names(EF)) |>
  group_by(rok) |> summarise(x = sum(hodnota * EF[siec]) / 1e6)          # TJ × t/TJ -> Mt
vystup <- function(kody, s) b(kody, s) |> select(rok, x)
emise <- em(TI_E) |> rename(em_e = x) |>
  left_join(em(TI_C) |> rename(em_c = x), by = "rok") |> left_join(em(TI_H) |> rename(em_h = x), by = "rok") |>
  left_join(vystup(c("TO_EHG_MAPE", "TO_EHG_APE"), "E7000") |> rename(to_e = x), by = "rok") |>
  left_join(vystup(c("TO_EHG_MAPCHP", "TO_EHG_APCHP"), "E7000") |> rename(to_chp_e = x), by = "rok") |>
  left_join(vystup(c("TO_EHG_MAPCHP", "TO_EHG_APCHP"), "H8000") |> rename(to_chp_h = x), by = "rok") |>
  left_join(vystup(c("TO_EHG_MAPH", "TO_EHG_APH"), "H8000") |> rename(to_h = x), by = "rok") |>
  left_join(vystup(c("NRG_E", "DL"), "E7000") |> rename(ztr_e = x), by = "rok") |>
  left_join(vystup(c("NRG_E", "DL"), "H8000") |> rename(ztr_h = x), by = "rok") |>
  mutate(chp_e = to_chp_e / (to_chp_e + to_chp_h),
         i_el    = (em_e + em_c * chp_e) / (to_e + to_chp_e - ztr_e),          # Mt CO2 na TJ dodané elektřiny
         i_teplo = (em_h + em_c * (1 - chp_e)) / (to_h + to_chp_h - ztr_h)) |>
  select(rok, i_el, i_teplo) |>
  left_join(em("FC_OTH_HH_E") |> rename(prime = x), by = "rok") |>
  left_join(pal |> filter(nrg_bal == "FC_OTH_HH_E", siec %in% setdiff(names(EF), c("G3000", "O4000XBIO"))) |>
              group_by(rok) |> summarise(uhli = sum(hodnota * EF[siec]) / 1e6), by = "rok") |>
  left_join(hh |> filter(siec %in% c("E7000", "H8000")) |> mutate(rok = as.integer(rok)) |>
              select(rok, siec, hodnota) |> pivot_wider(names_from = siec, values_from = hodnota), by = "rok") |>
  transmute(rok, uhli, plyn = prime - uhli, teplo = H8000 * i_teplo, elektrina = E7000 * i_el,
            g_kwh_el = 3.6e6 * i_el, g_kwh_teplo = 3.6e6 * i_teplo) |>      # Mt/TJ -> g/kWh (kontrola)
  mutate(celkem = uhli + plyn + teplo + elektrina) |>
  filter(rok >= 2005) |> arrange(rok)
stopifnot(!anyNA(emise))
cat("Emise CO2 domácností (Mt) a intenzita dodané elektřiny a tepla (g CO2/kWh):\n")
print(as.data.frame(emise[c(1, nrow(emise)), ] |> mutate(across(-rok, ~ round(.x, 2)))))
emise <- emise |> select(-starts_with("g_kwh")) |> mutate(across(-rok, ~ zaokr(.x, 2)))
write_csv(emise, file.path(web, "emise_domacnosti.csv"))

# ---------------------------------------------------------------------------------------------
# 9. Financování pomoci, mld. Kč ročně (graf v textu II, odstavec „Peníze by byly“)
#    Sociální klimatický fond: SKF_MLD (asi 50 mld. Kč) za roky 2026–2032 včetně národního podílu (¼), tedy průměr za 7 let;
#    přímá podpora nejvýš 37,5 % (nařízení (EU) 2023/955, čl. 8). Jiné období než náklady (ty jsou za rok 2028).
#    Cílená platba: pravidlo pal_vlastni_teplo, scénář A (11_kompenzace_nastroje.csv).
#    Výměna zdrojů: zranitelné RD na uhlí × 300–400 tis. Kč, rozloženo do let 2028–2032; průvodci: 300 × 0,8 mil. Kč.
#    Cena výměny a průvodců jsou předpoklady studie (pdf/ets2_studie_v2.html, tabulka nástrojů).
# ---------------------------------------------------------------------------------------------
# Sociální klimatický fond pro Česko: maximální alokace z EU podle přílohy II nařízení 2023/955 (plný fond 65 mld. €;
# snížení na 54,6 mld. € platí jen při odkladu podle čl. 30k směrnice, ETS2 se ale odložilo nařízením 2026/667, které
# z čl. 30k přebírá jen body a)–e) odst. 2). K evropským penězům povinná národní čtvrtina (EU = 75 % plánu). Změna 23. 11. 2026.
if (!exists("p")) source("02_parametry.R")
SKF_EU_EUR <- 1562617717
# průběh přímé platby 2028–2032: dva roky plná, pak pokles o čtvrtinu ročně, po roce 2032 konec (rozhodnutí 23. 11. 2026)
PRUBEH <- c(1, 1, 0.75, 0.5, 0.25)
SKF_MLD <- SKF_EU_EUR * p$FX / 0.75 / 1e9; SKF_LET <- 7; SKF_PRIME <- 0.375
VYMENA_KC <- c(300e3, 400e3); VYMENA_LET <- 5; PRUVODCI <- 300; PRUVODCE_KC <- 0.8e6
rd_uhli_zr <- read_csv(file.path(OUT_DIR, "09_silc_archetypy.csv"), show_col_types = FALSE) |>
  filter(archetyp == "RD uhlí") |> pull(zranitelne_tis)
cilena <- read_csv(file.path(OUT_DIR, "11_kompenzace_nastroje.csv"), show_col_types = FALSE) |>
  filter(scenar == "A", pravidlo == "pal_vlastni_teplo") |> pull(naklad_mld)
vymena <- rd_uhli_zr * 1e3 * VYMENA_KC / VYMENA_LET / 1e9
skf <- SKF_MLD / SKF_LET
pruvodci <- PRUVODCI * PRUVODCE_KC / 1e9
# pohled „obdobi“: fond za celé období 2026–2032, opatření za léta ETS2 v období fondu (2028–2032, VYMENA_LET);
# platba s postupným snižováním (PRUBEH), stejně v řádcích pomoc/cilena i platba/celkem
financovani <- tribble(
  ~pohled,  ~radek,     ~segment,     ~mld,                      ~mld_max,
  "rok",    "fond",     "prime",      skf * SKF_PRIME,           NA,
  "rok",    "fond",     "investice",  skf * (1 - SKF_PRIME),     NA,
  "rok",    "pomoc",    "cilena",     cilena,                    NA,
  "rok",    "pomoc",    "pruvodci",   pruvodci,                  NA,
  "rok",    "pomoc",    "vymena",     vymena[1],                 vymena[2],
  "obdobi", "fond",     "celkem",     SKF_MLD,                   NA,
  "obdobi", "fond",     "prime",      SKF_MLD * SKF_PRIME,       NA,
  "obdobi", "fond",     "investice",  SKF_MLD * (1 - SKF_PRIME), NA,
  "obdobi", "pomoc",    "cilena",     cilena * sum(PRUBEH),      NA,   # s postupným poklesem (B8, 25. 11. 2026), stejně jako „platba celkem“
  "obdobi", "pomoc",    "vymena",     vymena[1] * VYMENA_LET,    vymena[2] * VYMENA_LET,
  "obdobi", "pomoc",    "pruvodci",   pruvodci * VYMENA_LET,     NA,
  # návrh Sociálního klimatického plánu MŽP podle PwC pro MŽP (říjen 2025, s. 2): fond 52,0 mld. Kč (jejich kurz), bez přímých plateb;
  # přepočteno poměrem na náš fond (stejná eura, kurz ČNB)
  "obdobi", "skp_mzp",  "budovy",     SKF_MLD * 40.8 / 52.0,     NA,
  "obdobi", "skp_mzp",  "doprava",    SKF_MLD * 10.0 / 52.0,     NA,
  "obdobi", "skp_mzp",  "technicka",  SKF_MLD * 1.2 / 52.0,      NA,
  # náš návrh: plán rozšířený o přímé platby (investice jako MŽP), navýšení platí stát z výnosů z povolenek
  "obdobi", "platba",   "celkem",     cilena * sum(PRUBEH),      NA,
  "obdobi", "plan",     "celkem",     SKF_MLD + cilena * sum(PRUBEH), NA,
  "obdobi", "plan",     "eu",         SKF_MLD * 0.75,            NA,
  "obdobi", "plan",     "stat",       SKF_MLD * 0.25 + cilena * sum(PRUBEH), NA,
  "obdobi", "plan",     "podil_prime_pct", 100 * cilena * sum(PRUBEH) / (SKF_MLD + cilena * sum(PRUBEH)), NA,
  "2028",   "platba",   "rok",        cilena * PRUBEH[1],        NA,
  "2029",   "platba",   "rok",        cilena * PRUBEH[2],        NA,
  "2030",   "platba",   "rok",        cilena * PRUBEH[3],        NA,
  "2031",   "platba",   "rok",        cilena * PRUBEH[4],        NA,
  "2032",   "platba",   "rok",        cilena * PRUBEH[5],        NA) |>
  mutate(across(c(mld, mld_max), ~ zaokr(.x, 2)))
stopifnot(length(cilena) == 1, length(rd_uhli_zr) == 1)
print(financovani); write_csv(financovani, file.path(web, "financovani.csv"))

# ---------------------------------------------------------------------------------------------
# 6. Tok peněz z povolenek ETS2 (Sankeyho diagram, text II), souhrn 2028–2032, mld. Kč; platby i výnos ze stropu dražeb (B2, 25. 11. 2026)
#    Platby = emise v sektorech ETS2 (inventura ČHMÚ přes Eurostat env_air_gge, poslední rok, drženo stejně)
#    × cena povolenky ve scénáři A × kurz, bez DPH. Chybí menší průmyslové provozy (horní odhad jen za budovy a silnice).
#    Do fondu EU Česko přispívá podle podílu na emisích ETS2 v EU (2016–2018, čl. 30d odst. 5 směrnice),
#    zpět dostane 2,40 % fondu (příloha II nařízení 2023/955). Zbytek výnosu dostane Česko podle stejného podílu.
#    Zjednodušení: platby za 2028–2032 vs. fond za 2026–2032, rezerva tržní stability a přesun dražeb v čase pominuty.
# ---------------------------------------------------------------------------------------------
gge <- function(kod, geo, od, do) eurostat("env_air_gge", sprintf("A.THS_T.GHG.%s.%s", kod, geo), od) |>
  filter(as.integer(rok) <= do) |> mutate(kt = hodnota)
EM_KODY <- c(auta = "CRF1A3B1", lehka_uzitkova = "CRF1A3B2", tezka_nakladni = "CRF1A3B3", motocykly = "CRF1A3B4",
             sluzby = "CRF1A4A", domacnosti = "CRF1A4B")
em_cz <- bind_rows(lapply(names(EM_KODY), function(k) gge(EM_KODY[[k]], "CZ", 2015, 2100) |> mutate(sektor = k)))
EM_ROK <- max(as.integer(em_cz$rok))
em <- em_cz |> filter(as.integer(rok) == EM_ROK) |> select(sektor, kt)
podil_ref <- sapply(c("CZ", "EU27_2020"), function(g) sum(sapply(c("CRF1A3B", "CRF1A4A", "CRF1A4B"),
  function(k) mean(gge(k, g, 2016, 2018)$kt))))
PODIL_CZ_ETS2 <- podil_ref[["CZ"]] / podil_ref[["EU27_2020"]]
KC_T <- p$SCEN[["A_hranice_45EUR2020"]] * p$FX
ROKY <- 2028:2032
faktor <- function(trend) sum((1 + trend)^(ROKY - EM_ROK)) * (1 + p$EM_REAKCE_ETS2)   # součet za 5 let, v násobcích roku EM_ROK
TREND_SEKTOR <- c(auta = "doprava", lehka_uzitkova = "doprava", tezka_nakladni = "doprava", motocykly = "doprava",
                  sluzby = "budovy", domacnosti = "budovy")
pl <- setNames(em$kt * 1e3 * KC_T / 1e9 * sapply(em$sektor, function(k) faktor(p$EM_TREND[[TREND_SEKTOR[[k]]]])), em$sektor)
cat("Emise ETS2 v ČR: ", EM_ROK, round(sum(em$kt) / 1e3, 1), "Mt, průměr 2028–2032",
    round(sum(pl) / 5 * 1e9 / KC_T / 1e6, 1), "Mt\n")
platby <- c(domacnosti_vytapeni = pl[["domacnosti"]], auta = pl[["auta"]] + pl[["motocykly"]],
            nakladni = pl[["lehka_uzitkova"]] + pl[["tezka_nakladni"]], sluzby = pl[["sluzby"]])
celkem <- sum(platby)
fond_eu <- SKF_MLD * 0.75                                   # z EU pro Česko
# B2 (25. 11. 2026, ověřeno ve směrnici 2003/87/ES, konsolidace 1. 3. 2024, a nařízení 2026/667): výnos státu ze STROPU dražeb.
# Strop od 2028 (čl. 30c odst. 2): lineárně od roku 2025 z průměru vykázaných emisí 2024–2026, pokles 5,38 % ročně.
# Vykázané emise 2024–2026 zatím nejsou -> hodnotu 2025 bereme z trajektorie čl. 30c odst. 1 (výchozí 2024, pokles 5,10 %,
# strop 2027 = 1 036 288 784, rozhodnutí 2024/2951). Kdyby emise byly o víc než 2 % vyšší, faktor se upraví (příloha IIIa).
# Vše se draží (čl. 30d odst. 1). Front-loading 130 % v prvním roce se po odkladu odečte v letech 2030–2032 (čl. 30k odst. 2 c),
# nařízení 2026/667 čl. 2) -> za 2028–2032 nula. 600 mil. povolenek v rezervě je navíc ke stropu (čl. 30d odst. 2) -> pominuto.
# Sociální klimatický fond z dražeb ETS2 dostane nejvýš roční stropy čl. 30d odst. 4 (2028–2032: 10,5 + 10,3 + 10,1 + 9,8 + 9,4 mld. €).
# Zbytek se rozdělí státům podle podílu na referenčních emisích 2016–2018 (čl. 30d odst. 5; Česko PODIL_CZ_ETS2).
STROP_2027 <- 1036288784; LRF_1 <- 0.0510; LRF_2 <- 0.0538
STROP_VYCHOZI_2024 <- STROP_2027 / (1 - 3 * LRF_1)
HODNOTA_2025 <- STROP_VYCHOZI_2024 * (1 - LRF_1)
strop <- HODNOTA_2025 * (1 - LRF_2 * (ROKY - 2025))
SKF_Z_ETS2_EUR <- sum(c(10.5, 10.3, 10.1, 9.8, 9.4)) * 1e9
vynos_eu <- sum(strop) * KC_T / 1e9                          # mld. Kč za 2028–2032
skf_z_ets2 <- SKF_Z_ETS2_EUR * p$FX / 1e9
do_fondu <- skf_z_ets2 * PODIL_CZ_ETS2                      # podíl povolenek „připadajících“ na Česko, které jdou do fondu
rozpocet <- (vynos_eu - skf_z_ets2) * PODIL_CZ_ETS2        # výnos českého státního rozpočtu z dražeb
nad_strop <- celkem - do_fondu - rozpocet                   # platby z emisí nad český podíl stropu (jen kontrola)
# Rozhodnutí 25. 11. 2026: platby odběratelů počítat ze stropu („podle lístků“), aby seděly s výnosem. Emise podle našeho
# odhadu jsou nad podílem stropu -> v reálném trhu by vzrostla cena nebo by emise klesly rychleji; zaplaceno je tolik, kolik
# se vydraží. Platby = český podíl stropu × cena, rozdělené mezi sektory podle odhadu emisí.
celkem_emise <- celkem
platby <- platby * (do_fondu + rozpocet) / celkem
celkem <- sum(platby)
cat("B2: strop ETS2 2028–2032", round(sum(strop) / 1e6), "mil. povolenek (", paste(round(strop / 1e6), collapse = ", "),
    ") | výnos EU", round(vynos_eu), "mld. Kč | do fondu (CZ podíl)", round(do_fondu), "| rozpočet ČR", round(rozpocet),
    "| platby odběratelů", round(celkem), "| rozdíl nad stropem", round(nad_strop), "(platby z emisí", round(celkem_emise), ")\n")
plan_stat <- SKF_MLD * 0.25 + cilena * sum(PRUBEH)
# citlivost: tempo podle projekcí ČHMÚ (WEM)
pl_wem <- setNames(em$kt * 1e3 * KC_T / 1e9 * sapply(em$sektor, function(k) faktor(p$EM_TREND_WEM[[TREND_SEKTOR[[k]]]])), em$sektor)
cat("Citlivost WEM: platby", round(sum(pl_wem)), "mld. Kč vs. hlavní", round(sum(pl)), "\n")
# přímé platby a investice plánu se platí z fondu a ze státního rozpočtu poměrně (plán je jeden celek)
inv <- SKF_MLD; pp <- cilena * sum(PRUBEH); podil_eu <- fond_eu / (inv + pp)
tok <- tribble(
  ~zdroj,                         ~cil,                         ~mld,
  "Vytápění domácností",          "Povolenky ETS2",             platby[["domacnosti_vytapeni"]],
  "Osobní auta",                  "Povolenky ETS2",             platby[["auta"]],
  "Nákladní doprava",             "Povolenky ETS2",             platby[["nakladni"]],
  "Vytápění služeb a úřadů",      "Povolenky ETS2",             platby[["sluzby"]],
  "Povolenky ETS2",               "Sociální klimatický fond",   do_fondu,
  "Povolenky ETS2",               "Státní rozpočet (jen klima a sociální)",            rozpocet,
  "Sociální klimatický fond",     "Investice z plánu",          inv * podil_eu,
  "Sociální klimatický fond",     "Přímé platby",               pp * podil_eu,
  "Státní rozpočet (jen klima a sociální)",              "Investice z plánu",          inv * (1 - podil_eu),
  "Státní rozpočet (jen klima a sociální)",              "Přímé platby",               pp * (1 - podil_eu),
  "Státní rozpočet (jen klima a sociální)",              "Další klimatická a sociální opatření",             rozpocet - plan_stat) |>
  bind_rows(tibble(zdroj = "citlivost", cil = "platby_wem", mld = sum(pl_wem))) |>
  mutate(mld = zaokr(mld, 1))
cat("Tok peněz: emise", EM_ROK, "| podíl ČR na emisích ETS2 v EU", round(100 * PODIL_CZ_ETS2, 2), "% | platby celkem",
    round(celkem), "mld. Kč za 5 let\n")
print(tok); write_csv(tok, file.path(web, "tok_penez.csv"))
cat("Uloženo do", web, "\n")
