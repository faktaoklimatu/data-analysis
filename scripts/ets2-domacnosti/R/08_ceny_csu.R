# 08_ceny_csu.R – ceny energií a paliv pro rok 2026 z dat ČSÚ (soubory stáhne 00_stahni_csu.R)
# Výstup: output/08_ceny.csv. Hodnoty se ručně přepisují do 02_parametry.R (p$CENA) a ../inputs.csv.
#  plyn, elektřina: ČSÚ DataStat CEN0101IT01 / CEN0101KT01 – průměrná ceníková cena pro domácnosti, pásmo Celkem, poslední pololetí
#  benzín, nafta, LPG: ČSÚ týdenní šetření cen PHM – průměr posledních 52 týdnů (ceny v roce 2026 silně kolísají)
#  hnědé uhlí: ceníky uhelných skladů 2026 (ČSÚ cenu nezveřejňuje); ENERGO 2021 × HICP jen kontrola
#  dálkové teplo: ERÚ 2024 (malé plynové zdroje) × HICP; černé uhlí (jen citlivost): ENERGO 2021 × HICP
#     × index spotřebitelských cen 2025/2021 (HICP ČR – tuhá paliva CP0454, teplo CP0455; Eurostat prc_hicp_aind,
#     data ČSÚ). Až bude stažen CEN0101ET03 (CPI COICOP 2018 měsíčně), lze index nahradit posledním měsícem.
source("00_setup.R")
CENY_DIR <- file.path(CSU_DIR, "ceny")
posl <- function(vzor) { f <- sort(list.files(CENY_DIR, pattern = vzor, full.names = TRUE)); f[length(f)] }

# --- plyn a elektřina ---
pol_klic <- function(x) as.numeric(sub(".*(\\d{4})$", "\\1", x)) * 10 + as.numeric(substr(x, 1, 1))
energie <- function(f, nosic) read_csv(f, show_col_types = FALSE) %>%
  filter(`Pásmo spotřeby` == "Celkem") %>% mutate(k = pol_klic(Pololetí)) %>% arrange(k) %>%
  summarise(nosic = nosic, obdobi = last(Pololetí), kc_kwh = last(Hodnota) / 1000,
            kc_kwh_2021 = mean(Hodnota[k %/% 10 == 2021]) / 1000)
plyn <- energie(posl("^CEN0101I_.*\\.csv$"), "plyn")
elek <- energie(posl("^CEN0101K_.*\\.csv$"), "elektřina")

# --- pohonné hmoty: posledních 52 týdnů ---
phm <- read_csv(posl("^ceny_phm_tydenni_.*\\.csv$"), show_col_types = FALSE)
tydny <- tail(sort(unique(phm$obdobi)), 52)
phm_p <- phm %>% filter(obdobi %in% tydny) %>% group_by(polozka_txt) %>%
  summarise(kc = mean(hodnota), od = min(obdobi), do = max(obdobi))
kc_phm <- function(vzor) phm_p$kc[grepl(vzor, phm_p$polozka_txt)]

# --- uhlí a teplo: ENERGO 2021 × index ---
d <- load_energo(); w <- d$Vahy
cena21 <- function(kc, mn) { r <- kc / mn; r[!is.finite(r)] <- NA; wq(r, w) }
hnede21 <- cena21(d$EPSPOTREBATPKC_01, d$EPTPMNOZSTVI_01)
cerne21 <- cena21(d$EPSPOTREBATPKC_02, d$EPTPMNOZSTVI_02)
teplo21 <- cena21(d$EPSPOTRVYTTABKC_01, d$EPSPOTRVYTTABGJ_01)
IDX_TUHA  <- 198.9 / 114.3   # HICP ČR CP0454 2025/2021
# Hnědé uhlí: ČSÚ průměrnou spotřebitelskou cenu uhlí nezveřejňuje -> aktuální ceníky uhelných skladů (vč. DPH, bez dopravy):
#   https://kb-uhli.cz/cenik/ (Bílina kostka 674, ořech 1 684, ořech 2 694 Kč/q), https://www.uhli-janmaria.cz/cenik (ořech 2 670 Kč/q)
CENA_UHLI_Q_CENIK <- mean(c(674, 684, 694, 670))   # 680 Kč/q, říjen 2026; ENERGO 2021 × HICP jen jako kontrola
IDX_TEPLO <- 183.7 / 102.8   # HICP ČR CP0455 2025/2021
# Dálkové teplo: ERÚ, Výsledné ceny tepelné energie v ČR 2024 (https://eru.gov.cz/vysledne-ceny-tepelne-energie-v-cr-2024),
# CSV z PDF: ../data/eru/eru_teplo_2024.csv (eru_pdf_na_csv.py). Archetyp „zdroj v ETS2“ = lokality do 20 MWt, plyn >= 50 %.
eru <- read_csv(file.path("..", "data", "eru", "eru_teplo_2024.csv"), show_col_types = FALSE) %>%
  filter(vykon_mwt <= 20, coalesce(plyn_pct, 0) >= 50)
urovne <- c("primarni_rozvod", "cvs", "blokova_kotelna", "sekundarni_rozvody", "domovni_predavaci_stanice", "domovni_kotelna")
TEPLO_ERU_2024 <- sum(sapply(urovne, function(u) sum(eru[[paste0(u, "_cena_kc_gj")]] * eru[[paste0(u, "_mnozstvi_gj")]], na.rm = TRUE))) /
  sum(sapply(urovne, function(u) sum(eru[[paste0(u, "_mnozstvi_gj")]][!is.na(eru[[paste0(u, "_cena_kc_gj")]])], na.rm = TRUE)))
IDX_TEPLO_25_24 <- 183.7 / 177.7   # HICP ČR CP0455 2025/2024

ceny <- tribble(
  ~parametr,       ~hodnota,                                   ~jednotka, ~zdroj,
  "plyn_kc_kwh",   plyn$kc_kwh,                                "Kč/kWh",  paste("ČSÚ CEN0101IT01, Celkem,", plyn$obdobi),
  "elektrina_kc_kwh", elek$kc_kwh,                             "Kč/kWh",  paste("ČSÚ CEN0101KT01, Celkem,", elek$obdobi),
  "INDEX_ELEKTRINA", elek$kc_kwh / elek$kc_kwh_2021,           "poměr",   "ČSÚ CEN0101KT01: poslední pololetí / průměr 2021",
  "benzin_kc_l",   kc_phm("Natural 95"),                       "Kč/l",    paste("ČSÚ týdenní ceny PHM, průměr", tydny[1], "–", tail(tydny, 1)),
  "nafta_kc_l",    kc_phm("nafta"),                            "Kč/l",    "dtto",
  "lpg_kc_kg",     kc_phm("LPG") / 0.51,                       "Kč/kg",   "dtto, 0,51 kg/l",
  "hnede_kc_q",    CENA_UHLI_Q_CENIK,                          "Kč/q",    "ceníky uhelných skladů, Bílina kostka/ořech 1/ořech 2, říjen 2026 (kb-uhli.cz, uhli-janmaria.cz); ČSÚ cenu uhlí nezveřejňuje",
  "hnede_kc_q_kontrola_energo", hnede21 * IDX_TUHA,            "Kč/q",    sprintf("KONTROLA: ENERGO 2021 medián %.0f Kč/q × HICP tuhá paliva %.3f", hnede21, IDX_TUHA),
  "cerne_kc_q",    cerne21 * IDX_TUHA,                         "Kč/q",    sprintf("ENERGO 2021 medián %.0f Kč/q × HICP tuhá paliva %.3f", cerne21, IDX_TUHA),
  "teplo_kc_gj",   TEPLO_ERU_2024 * IDX_TEPLO_25_24,             "Kč/GJ",   sprintf("ERÚ 2024, lokality do 20 MWt s plynem >= 50 %%, koncové úrovně, vč. DPH: %.0f Kč/GJ × HICP teplo 2025/2024 %.3f", TEPLO_ERU_2024, IDX_TEPLO_25_24),
  "teplo_kc_gj_kontrola_energo", teplo21 * IDX_TEPLO,          "Kč/GJ",   sprintf("KONTROLA: ENERGO 2021 medián %.0f Kč/GJ × HICP teplo %.3f", teplo21, IDX_TEPLO)) %>%
  mutate(hodnota = round(hodnota, 3))
write_csv(ceny, file.path(OUT_DIR, "08_ceny.csv"))
print(ceny, width = 200)
