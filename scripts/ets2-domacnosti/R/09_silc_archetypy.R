# 09_silc_archetypy.R – dopad ETS2 na archetypy domácností ze SILC (bydlení) a SRÚ (PHM)
#
# Proč: ENERGO 2021 má dobré fyzické spotřeby, ale u 74 % domácností jen pásmo příjmu (střed intervalu),
# což rozbíjí podíl výdajů na příjmu a pořadí v decilech (viz 08a_sru_diagnostika). SILC má u téže
# domácnosti příjem, způsob vytápění (VYTAPENI, ZDROJ_ENER – stejně jako SRÚ) a měsíční náklady na
# energie v bydlení (ELEKTR, PLYN, UT, PALIVA), ve vzorku ~8 500 domácností (RD na uhlí ~470).
#
# Postup
#  1) Archetypy (SILC): RD uhlí = RD & ZDROJ_ENER 3; RD plyn = RD & ZDROJ_ENER 2; byt plyn = BD & ZDROJ_ENER 2;
#     byt teplo = BD & VYTAPENI 1 (dálkové topení, bloková nebo domovní kotelna); ostatní.
#  2) Výdaje roku šetření (náklady na bydlení Kč/měs × 12) -> množství / emise:
#     - plyn: Kč / realizovaná cena plynu pro domácnosti v pásmu spotřeby (Eurostat nrg_pc_202, vč. stálých
#       plateb rozpočítaných na kWh a všech daní). Nejdřív pásmo D2, pod 5,56 MWh přepočet cenou D1, nad 55,6 MWh D3.
#     - PALIVA (tuhá a kapalná): podíl uhlí z SRÚ (COICOP 4541) × výdaj / cena uhlí (ceníky 2026) -> q -> emise;
#       podíl uhlí podle skupiny RD uhlí / RD plyn / RD ostatní / BD (SILC má v PALIVA uhlí i dřevo dohromady).
#     - UT (ústřední topení, teplá voda): GJ = Kč / cena tepla – má být ERÚ (CENA_TEPLA_ERU_KC_GJ); dočasně ENERGO 2021 × HICP CP0455;
#     ENERGO 2021 (mikrodata) slouží jen jako KONTROLA (výstup 09_kontrola_energo_*), ne jako vstup.
#       archetyp „zdroj tepla v ETS2“ = plný dopad u všech, bez odhadu podílu soustav (jako R/07).
#     - PHM: SILC výdaje na PHM nemá -> hot-deck z SRÚ (deníky 2022 přeceněné ČSÚ na ceny 2023 + 2023):
#       domácnost s autem dostane litry náhodného dárce s autem ze stejné buňky RD/BD × kvintil příjmu na osobu
#       (pravděpodobnost úměrná váze). Litry = Kč / roční průměr týdenních cen PHM ČSÚ.
#  3) Náklad ETS2 2028 (scénáře A, B z 02_parametry.R) a výdaje na energie v cenách 2028:
#     plyn = množství × cena pásma 2026-S1 × CENY_2026_NA_2028; tuhá paliva a teplo × HICP 2025/rok × CENY_2026_NA_2028;
#     elektřina × (ČSÚ CEN0101KT01 1. pol. 2026 / průměr roku šetření) × CENY_2026_NA_2028; PHM = litry × p$CENA.
#  4) Příjem 2028 = CP_PRIJ (za rok před šetřením) × růst průměrné mzdy do 2025 × předpoklad 2026–2028 (jako p$UPRATE).
#  5) Ohrožení energetickou chudobou (2M) před ETS2 a po ETS2 (práh přepočtený z rozdělení po ETS2).
#     ZRANITELNÉ DOMÁCNOSTI (rozhodnutí 21. 10. 2026; nahrazuje „dvojí zátěž“):
#     spodní dvě pětiny příjmů (1.–4. decil) A 2M po ETS2 A náklad ETS2 aspoň 1 % čistého příjmu.
#     Citlivost: dvojí zátěž s horní čtvrtinou nárůstu (P75). Nárůst nad 2× medián zůstává jako ukazatel.
#     Interval spolehlivosti podílu: bootstrap po domácnostech uvnitř archetypu (prahy pevné).
#
# Data a zdroje
#  - ČSÚ, EU-SILC (verze MF), Hextzp24.csv; číselník Zp24_ext.pdf (Documents/ČSÚ/MF_SILC 2015-2024/Zp2024.zip)
#  - ČSÚ, Statistika rodinných účtů 2023 (Ru2023e.csv, Ru2023d.csv; číselník Ru2023ext.pdf) https://csu.gov.cz/rodinne_ucty
#  - ČSÚ, ENERGO 2021 mikrodata (load_energo() v 00_setup.R) https://csu.gov.cz/energo-2021
#  - Eurostat nrg_pc_202, CZ, I_TAX, NAC, KWH: https://ec.europa.eu/eurostat/databrowser/view/nrg_pc_202/default/table
#    (metadata ČR: od 2023 realizované ceny = tržby / MWh) https://ec.europa.eu/eurostat/cache/metadata/EN/nrg_pc_202_sims_cz.htm
#  - Eurostat prc_hicp_aind, CZ, CP0454 a CP0455 https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_aind/default/table
#  - ČSÚ CEN0101KT01 (elektřina) a týdenní ceny PHM – soubory ve Documents/ČSÚ/ceny (00_stahni_csu.R)
#  - ČSÚ, průměrná mzda 2023 43 341 Kč https://csu.gov.cz/rychle-informace/prumerne-mzdy-4-ctvrtleti-2023
#
# Spuštění: z ETS2/R. Výstupy: output/09_*.csv a output/09_silc_kontrola.txt

source("00_setup.R"); source("02_parametry.R")
set.seed(2028)

SRU_DIR  <- file.path(CSU_DIR, "SRU")
CENY_DIR <- file.path(CSU_DIR, "ceny")
# ===================== ROKY – JEDINÉ MÍSTO, KTERÉ SE MĚNÍ S NOVÝMI DATY =====================
# Konzistence let (viz METODIKA.md, „Konzistence let“):
#  - náklady na bydlení v SILC_ROK jsou v cenách roku šetření -> převod Kč -> množství cenami roku SILC_ROK
#    (plyn Eurostat obě pololetí, uhlí ceník × HICP, teplo ERÚ, elektřina ČSÚ);
#  - CP_PRIJ v SILC_ROK je příjem za SILC_ROK - 1 -> přepočet mzdovým indexem z roku SILC_ROK - 1;
#  - PHM ze SRÚ v cenách SRU_ROK -> převod na litry cenami PHM roku SRU_ROK; podíl uhlí v PALIVA ze stejného SRÚ;
#  - vše se pak přeceňuje do 2028 (ceny i příjmy), takže čitatel i jmenovatel jsou ve stejném roce.
# Chybí-li vstup pro zvolený rok, skript se zastaví a řekne, co doplnit (žádné tiché náhrady).
SILC_ROK <- 2024          # ročník SILC (nový SILC: přepsat, doplnit vstupy níže podle hlášek)
SRU_ROK  <- 2023          # ročník souboru SRÚ (nové SRÚ 2024: přepsat)
SILC_DIR <- list.files(CSU_DIR, pattern = "SILC", full.names = TRUE, include.dirs = TRUE)
SILC_DIR <- SILC_DIR[dir.exists(SILC_DIR)][1]   # složka se ZIPy/CSV SILC (dnes "MF_SILC 2015-2024")
ERU_DIR  <- file.path("..", "data", "eru")      # CSV z PDF ERÚ (eru_teplo_<rok>.csv), převod skriptem eru_pdf_na_csv.py
# rok ERÚ pro rozložení tepla ze zdrojů v ETS2 po krajích: rok SILC, jinak předchozí (strukturu zdrojů, ne ceny)
ERU_ROK_TEPLO <- if (file.exists(file.path(ERU_DIR, paste0("eru_teplo_", SILC_ROK, ".csv")))) SILC_ROK else SILC_ROK - 1
B_BOOT   <- 500
# Byty na dálkovém teple ze zdroje v ETS2: počet domácností na malých teplárnách a kotelnách mimo ETS1
# (Fakta o klimatu, Dashboard tepláren / studie Odchod tepláren od uhlí, verze 2026-08-29:
#  https://faktaoklimatu.cz/studie/2026-odchod-teplaren-od-uhli). Bez domovních plynových kotelen -> spíš dolní odhad.
N_TEPLO_ETS2_TIS <- 380
TEPLO <- "byt teplo (zdroj v ETS2)"
TEPLO_ETS1 <- "byt teplo (zdroj v ETS1)"   # od B3: ETS2 jim teplo nezdraží, ale platí ETS2 za plyn (vaření, ohřev vody)

# ---------- ceny a indexy ----------
# Plyn, Kč/kWh vč. daní, realizované ceny podle pásma (Eurostat nrg_pc_202; D1 < 20 GJ, D2 20–199 GJ, D3 >= 200 GJ)
CENY_PLYN <- tribble(
  ~obdobi,   ~D1,    ~D2,    ~D3,
  "2023-S1", 3.6048, 2.6960, 2.5423,
  "2023-S2", 4.1655, 2.7373, 2.3578,
  "2024-S1", 4.4412, 2.7129, 2.2946,
  "2024-S2", 4.6566, 2.5954, 2.1511,
  "2025-S1", 4.4695, 2.4171, 1.9998,
  "2025-S2", 4.7821, 2.3423, 1.9459,
  "2026-S1", 4.4355, 2.1917, 1.8324)
HRANICE_D1 <- 20 / 3.6e-3     # 20 GJ v kWh (5 556)
HRANICE_D3 <- 200 / 3.6e-3    # 200 GJ v kWh (55 556)
plyn_rok <- CENY_PLYN %>% filter(substr(obdobi, 1, 4) == as.character(SILC_ROK)) %>%
  summarise(across(c(D1, D2, D3), mean)) %>% unlist()
plyn_2026 <- CENY_PLYN %>% filter(obdobi == "2026-S1") %>% select(D1, D2, D3) %>% unlist()
pasmo <- function(kwh) ifelse(kwh < HRANICE_D1, "D1", ifelse(kwh < HRANICE_D3, "D2", "D3"))
kwh_z_kc <- function(kc, c) {              # c = pojmenovaný vektor cen D1, D2, D3
  q1 <- kc / c[["D1"]]; q2 <- kc / c[["D2"]]; q3 <- kc / c[["D3"]]
  ifelse(q1 < HRANICE_D1, q1,
         ifelse(q2 < HRANICE_D1, HRANICE_D1,          # mezera mezi pásmy: domácnost na hranici
                ifelse(q2 < HRANICE_D3, q2, pmax(q3, HRANICE_D3))))
}

# HICP ČR (2015 = 100), roční průměr
IDX_TUHA  <- c(`2021` = 114.3, `2022` = 161.0, `2023` = 202.9, `2024` = 198.5, `2025` = 198.9)   # CP0454
IDX_TEPLO <- c(`2021` = 102.8, `2022` = 123.0, `2023` = 168.7, `2024` = 177.7, `2025` = 183.7)   # CP0455
# Hnědé uhlí: ČSÚ průměrnou spotřebitelskou cenu uhlí v Kč/q už nezveřejňuje (DataStat má průměrné ceny jen potravin a PHM).
# Kotva = aktuální ceníky uhelných skladů, hnědé uhlí Bílina (kostka, ořech 1, ořech 2), vč. DPH, bez dopravy, říjen 2026:
#   https://kb-uhli.cz/cenik/ (674, 684, 694 Kč/q), https://www.uhli-janmaria.cz/cenik (670 Kč/q) -> průměr 680 Kč/q.
# Na rok šetření SILC přepočteno HICP CP0454 (2026 ~ 2025). Kontrola: ENERGO 2021 medián 400 Kč/q × HICP = 695 Kč/q (2024).
CENA_UHLI_Q_2026 <- 680
# Průměrná hrubá měsíční mzda ČSÚ (pro přepočet příjmů SILC na 2028); nový SILC_ROK potřebuje rok SILC_ROK - 1:
# 2023: https://csu.gov.cz/rychle-informace/prumerne-mzdy-4-ctvrtleti-2023
MZDA <- c(`2021` = 37839, `2023` = 43341)    # ČSÚ, průměrná hrubá měsíční mzda
r <- as.character(SILC_ROK)

# ---------- kontrola, že pro zvolené roky existují všechny vstupy ----------
chybi <- character()
over <- function(ok, co) if (!isTRUE(ok)) chybi <<- c(chybi, co)
over(sum(substr(CENY_PLYN$obdobi, 1, 4) == r) == 2,
     paste0("ceny plynu Eurostat nrg_pc_202 pro obě pololetí ", r, " (CENY_PLYN)"))
over(!is.na(IDX_TUHA[r]) && !is.na(IDX_TEPLO[r]), paste0("HICP CP0454 a CP0455 za rok ", r, " (IDX_TUHA, IDX_TEPLO)"))
over(!is.na(MZDA[as.character(SILC_ROK - 1)]),
     paste0("průměrná mzda ČSÚ za rok ", SILC_ROK - 1, " (MZDA) – příjem v SILC ", r, " je za ", SILC_ROK - 1))
over(file.exists(file.path(ERU_DIR, paste0("eru_teplo_", r, ".csv"))) ||
       file.exists(file.path(ERU_DIR, paste0("eru_teplo_", SILC_ROK - 1, ".csv"))),
     paste0("ceny tepla ERÚ ", r, " (PDF -> eru_pdf_na_csv.py -> ", ERU_DIR, "/eru_teplo_", r, ".csv)"))
if (length(chybi)) stop("Pro SILC_ROK = ", r, " / SRU_ROK = ", SRU_ROK, " chybí vstupy:\n - ", paste(chybi, collapse = "\n - "))

# ---------- dálkové teplo: ERÚ, Výsledné ceny tepelné energie v ČR (vč. DPH) ----------
# Archetyp „zdroj v ETS2“ = malé zdroje mimo ETS1 -> cenové lokality s instalovaným výkonem do 20 MWt a plynem >= 50 %;
# vážený průměr cen koncových úrovní dodávky (primární rozvod, CVS, bloková kotelna, sekundární rozvody,
# domovní předávací stanice, domovní kotelna). Celostátní průměr jen pro kontrolu.
# https://eru.gov.cz/vysledne-ceny-tepelne-energie-v-cr-2024
ERU_KONCOVE <- c("primarni_rozvod", "cvs", "blokova_kotelna", "sekundarni_rozvody", "domovni_predavaci_stanice", "domovni_kotelna")
eru_cena <- function(rok, maly_plyn = TRUE) {
  e0 <- read_csv(file.path(ERU_DIR, paste0("eru_teplo_", rok, ".csv")), show_col_types = FALSE)
  if (maly_plyn) e0 <- filter(e0, vykon_mwt <= 20, coalesce(plyn_pct, 0) >= 50)
  kc <- 0; gj <- 0
  for (u in ERU_KONCOVE) {
    c0 <- e0[[paste0(u, "_cena_kc_gj")]]; q0 <- coalesce(e0[[paste0(u, "_mnozstvi_gj")]], 0)
    kc <- kc + sum(c0 * q0, na.rm = TRUE); gj <- gj + sum(q0[!is.na(c0)])
  }
  kc / gj
}
ERU_ROK <- if (file.exists(file.path(ERU_DIR, paste0("eru_teplo_", r, ".csv")))) SILC_ROK else SILC_ROK - 1
CENA_TEPLA_ERU_KC_GJ <- eru_cena(ERU_ROK) * IDX_TEPLO[[r]] / IDX_TEPLO[[as.character(ERU_ROK)]]   # = ERÚ, je-li rok k dispozici
CENA_TEPLA_ERU_CR    <- eru_cena(ERU_ROK, maly_plyn = FALSE) * IDX_TEPLO[[r]] / IDX_TEPLO[[as.character(ERU_ROK)]]

# Elektřina: ČSÚ CEN0101KT01, pásmo Celkem (jen pro přecenění výdajů do 2028; elektřina není v ETS2)
posl <- function(vzor) { f <- sort(list.files(CENY_DIR, pattern = vzor, full.names = TRUE)); f[length(f)] }
el <- read_csv(posl("^CEN0101K_.*\\.csv$"), show_col_types = FALSE) %>% filter(`Pásmo spotřeby` == "Celkem") %>%
  mutate(rok = as.numeric(sub(".*(\\d{4})$", "\\1", Pololetí)), pol = as.numeric(substr(Pololetí, 1, 1)))
el_rok  <- mean(el$Hodnota[el$rok == SILC_ROK])
el_posl <- el %>% arrange(rok, pol) %>% slice_tail(n = 1)
IDX_EL  <- el_posl$Hodnota / el_rok

# Příjmy: CP_PRIJ je za rok SILC_ROK - 1; přepočet na 2028 stejnou logikou jako p$UPRATE (z 2021)
UPRATE_PRIJ <- p$UPRATE * MZDA[["2021"]] / MZDA[[as.character(SILC_ROK - 1)]]

# PHM: roční průměr týdenních cen ČSÚ v roce SRU_ROK
phm <- read_csv(posl("^ceny_phm_tydenni_.*\\.csv$"), show_col_types = FALSE) %>%
  filter(substr(obdobi, 1, 4) == as.character(SRU_ROK)) %>% group_by(polozka_txt) %>% summarise(kc = mean(hodnota))
cena_phm <- c(nafta = phm$kc[grepl("nafta", phm$polozka_txt)],
              benzin = phm$kc[grepl("Natural 95", phm$polozka_txt)],
              lpg = phm$kc[grepl("LPG", phm$polozka_txt)])
LPG_KG_L <- 0.51

# ---------- ENERGO 2021: emise na korunu tuhých paliv a cena tepla ----------
if (ENERGO_OK) {
  d <- load_energo(); w <- d$Vahy
  n0 <- function(x) { x <- suppressWarnings(as.numeric(x)); ifelse(is.na(x) | x < 0, 0, x) }
  RDe <- d$EODUMTYP %in% c(1, 2)
  uhli_e <- is1(d$ERVYTAPENI_04) | is1(d$ERVYTAPENI_05); plyn_e <- is1(d$ERVYTAPENI_02)
  kc_uhli  <- n0(d$EPSPOTREBATPKC_01) + n0(d$EPSPOTREBATPKC_02) + n0(d$EPSPOTREBATPKC_03) + n0(d$EPSPOTREBATPKC_04)
  kc_drevo <- n0(d$EPSPOTREBATPKC_05) + n0(d$EPSPOTREBATPKC_06) + n0(d$EPSPOTREBATPKC_07)
  co2_uhli <- (n0(d$EPTPMNOZSTVI_01) / 10 * p$NCV[["hnede"]] * p$EF[["hnede"]] +
               n0(d$EPTPMNOZSTVI_02) / 10 * p$NCV[["cerne"]] * p$EF[["cerne"]] +
               n0(d$EPTPMNOZSTVI_03) / 10 * p$NCV[["koks"]] * p$EF[["koks"]] +
               n0(d$EPTPMNOZSTVI_04) / 10 * p$NCV[["brikety_uhelne"]] * p$EF[["brikety_uhelne"]]) / 1000   # t CO2
  ok_e <- (kc_uhli + kc_drevo > 0) & ((kc_uhli > 0) == (co2_uhli > 0))   # Kč i množství vyplněné konzistentně
  skup_e <- ifelse(RDe & uhli_e, "RD uhlí", ifelse(RDe & plyn_e, "RD plyn", ifelse(RDe, "RD ostatní", "BD")))
  T_NA_KC_2021 <- tibble(skup = skup_e, w = w, ok = ok_e, co2 = co2_uhli, kc = kc_uhli + kc_drevo, kcu = kc_uhli) %>%
    filter(ok) %>% group_by(skup) %>%
    summarise(n_energo = n(), podil_uhli_v_kc = sum(kcu * w) / sum(kc * w), t_co2_na_kc = sum(co2 * w) / sum(kc * w))
  cena21 <- function(kc, mn) { r <- suppressWarnings(as.numeric(kc) / as.numeric(mn)); r[!is.finite(r)] <- NA; wq(r, w) }
  TEPLO_KC_GJ_2021 <- cena21(d$EPSPOTRVYTTABKC_01, d$EPSPOTRVYTTABGJ_01)
  TEPLO_KONTROLA_ENERGO <- TEPLO_KC_GJ_2021 * IDX_TEPLO[[r]] / IDX_TEPLO[["2021"]]   # jen kontrola
  rm(d)
} else { T_NA_KC_2021 <- NULL; TEPLO_KONTROLA_ENERGO <- NA_real_ }
teplo_kc_gj_rok  <- CENA_TEPLA_ERU_KC_GJ
cena_uhli_q_rok  <- CENA_UHLI_Q_2026 * IDX_TUHA[[r]] / IDX_TUHA[["2025"]]

# ---------- čtení SILC a SRÚ ----------
num <- function(x) suppressWarnings(as.numeric(gsub(",", ".", x)))
cti <- function(f) read_delim(f, delim = ";", locale = locale(encoding = "windows-1250"),
                              col_types = cols(.default = "c"), show_col_types = FALSE)
cti_silc_h <- function(rok) {
  yy <- sprintf("%02d", rok %% 100); tmp <- file.path(tempdir(), paste0("silc", yy)); dir.create(tmp, showWarnings = FALSE)
  f <- list.files(SILC_DIR, pattern = paste0("^Hextzp", yy, "\\.csv$"), ignore.case = TRUE, full.names = TRUE, recursive = TRUE)
  if (length(f)) return(cti(f[1]))
  z <- list.files(SILC_DIR, pattern = paste0(rok, ".*\\.zip$"), ignore.case = TRUE, full.names = TRUE)
  csv <- grep(paste0("^Hextzp", yy, "\\.csv$"), unzip(z[1], list = TRUE)$Name, ignore.case = TRUE, value = TRUE)
  unzip(z[1], files = csv, exdir = tmp); cti(file.path(tmp, csv))
}
najdi_sru <- function(rok, typ) list.files(file.path(SRU_DIR, rok), pattern = paste0("^ru", rok, typ, "\\.csv$"),
                                           ignore.case = TRUE, full.names = TRUE)[1]

s <- cti_silc_h(SILC_ROK) %>%
  transmute(DOMAC_ID = num(DOMAC_ID), w = num(PKOEF), osoby = pmax(num(OSOB), 1), sj = num(SJ), DUM = num(DUM), KRAJ = num(KRAJ),
            VYTAPENI = num(VYTAPENI), ZDROJ_ENER = num(ZDROJ_ENER), auto = num(AUTO) == 1,
            prijem_rok = num(CP_PRIJ) * UPRATE_PRIJ,
            across(c(ELEKTR, PLYN, UT, PALIVA), ~ 12 * coalesce(num(.x), 0), .names = "kc_{tolower(.col)}")) %>%
  mutate(typ = case_when(DUM %in% 1:2 ~ "RD", DUM %in% 3:4 ~ "BD", TRUE ~ "jiný"),
         archetyp = case_when(typ == "RD" & ZDROJ_ENER %in% 3 ~ "RD uhlí",
                              typ == "RD" & ZDROJ_ENER %in% 2 ~ "RD plyn",
                              typ == "BD" & ZDROJ_ENER %in% 2 ~ "byt plyn",
                              typ == "BD" & VYTAPENI %in% 1  ~ "byt teplo (zdroj v ETS2)",
                              TRUE ~ "ostatní"),
         # rozpad skupiny „ostatní“ (jen pro popis, archetypy se nemění); ZDROJ_ENER: 1 elektřina, 4 dřevo a biopaliva,
         # 5 tepelné čerpadlo, 6 solární termický, 7 fotovoltaika, 8 jiné; u VYTAPENI 1 (dálkové teplo, kotelna) palivo chybí
         # rozdělení podle typu bydlení jako u archetypů; byty na dřevo (malá skupina) jsou v „jiné“
         ostatni_detail = case_when(archetyp != "ostatní" ~ NA_character_,
                                    typ == "RD" & ZDROJ_ENER %in% 4 ~ "RD dřevo a biomasa",
                                    typ == "RD" & ZDROJ_ENER %in% 5 ~ "RD tepelné čerpadlo",
                                    typ == "RD" & ZDROJ_ENER %in% 1 ~ "RD elektřina",
                                    typ == "BD" & ZDROJ_ENER %in% 1 ~ "byt elektřina",
                                    # byty na TČ v SILC prakticky nejsou (3 domácnosti), solární a FVE jen desítky
                                    TRUE ~ "ostatní (solární a FVE, byty na dřevo nebo uhlí, dálkové teplo v RD, jiné)"),
         skup_paliva = case_when(archetyp == "RD uhlí" ~ "RD uhlí", archetyp == "RD plyn" ~ "RD plyn",
                                 typ == "RD" ~ "RD ostatní", TRUE ~ "BD"))

# kvintil příjmu na osobu (odpovídá KVINTIL v SRÚ – Spearman 0,86 na spárovaných domácnostech, viz 09_silc_kontrola)
wcut <- function(x, w, k) { o <- order(x); cw <- cumsum(w[o]) / sum(w); g <- integer(length(x)); g[o] <- pmin(ceiling(cw * k), k); g }
ok_p <- !is.na(s$prijem_rok) & s$prijem_rok > 0
s$kvintil <- NA_integer_; s$kvintil[ok_p] <- wcut(s$prijem_rok[ok_p] / s$osoby[ok_p], s$w[ok_p], 5)
# decily ekvivalizovaného příjmu: spotřební jednotky podle původní škály OECD (SILC proměnná SJ: 1,0 / 0,7 / 0,5),
# která lépe sedí na české poměry než škála EU (EJ: 1,0 / 0,5 / 0,3); do 25. 11. 2026 odmocnina z počtu osob (C8)
if (any(is.na(s$sj[ok_p]) | s$sj[ok_p] <= 0)) stop("SILC: chybí spotřební jednotky SJ")
s$decil   <- NA_integer_; s$decil[ok_p]   <- wcut(s$prijem_rok[ok_p] / s$sj[ok_p], s$w[ok_p], 10)

# SRÚ: PHM na domácnost s autem
e  <- cti(najdi_sru(SRU_ROK, "e")) %>% transmute(DOMACID = num(DOMACID), PMES = num(PMES), PKOEFP = num(PKOEFP),
                                                 DUM = num(DUM), AUTO = num(AUTO), KVINTIL = num(KVINTIL))
dd_all <- cti(najdi_sru(SRU_ROK, "d")) %>% rename(COICOP = any_of(c("COOICOP", "COICOP"))) %>%
  transmute(DOMACID = num(DOMACID), COICOP = num(COICOP), CENACELK = num(CENACELK))
dd <- dd_all %>% filter(COICOP %in% c(7221, 7222, 7223))
# Podíl uhlí ve výdajích za tuhá a kapalná paliva podle skupiny (SRÚ, COICOP 4541 uhlí / 4530+4541+4542+4543+4549),
# protože SILC má v PALIVA uhlí i dřevo dohromady. Skupiny jako v SILC (VYTAPENI, ZDROJ_ENER mají stejné kódy).
e_vyt <- cti(najdi_sru(SRU_ROK, "e")) %>% transmute(DOMACID = num(DOMACID), DUM = num(DUM), ZDROJ_ENER = num(ZDROJ_ENER))
PODIL_UHLI_SRU <- dd_all %>% filter(COICOP %in% c(4530, 4541, 4542, 4543, 4549)) %>%
  left_join(select(e, DOMACID, PMES, PKOEFP), by = "DOMACID") %>% left_join(e_vyt, by = "DOMACID") %>%
  mutate(kc = CENACELK / PMES * 12,
         skup = case_when(DUM %in% 1:2 & ZDROJ_ENER %in% 3 ~ "RD uhlí", DUM %in% 1:2 & ZDROJ_ENER %in% 2 ~ "RD plyn",
                          DUM %in% 1:2 ~ "RD ostatní", TRUE ~ "BD")) %>%
  group_by(skup) %>% summarise(n_domacnosti_s_palivy = n_distinct(DOMACID),
                               podil_uhli_sru = sum(kc[COICOP == 4541] * PKOEFP[COICOP == 4541]) / sum(kc * PKOEFP), .groups = "drop") %>%
  # SRÚ podíl použít jen tam, kde je uhlí hlavním palivem (RD uhlí; byty s uhlím jsou v BD). U RD na plyn a ostatních RD
  # (hlavně dřevo) SRÚ podíl uhlí nadhodnocuje: jen ~90 domácností s nákupem, dřevo z vlastních zdrojů a nákupy mimo
  # deník chybí -> emise z tuhých paliv by vyšly 3,2 Mt (bilance ČSÚ 2020 ~2,6 Mt, ENERGO 2,5 Mt). Tam PALIVA = biomasa.
  mutate(podil_uhli = ifelse(skup %in% c("RD uhlí", "BD"), podil_uhli_sru, 0))
# PHM podle příjmu: podíl výdajů na PHM na všech výdajích domácnosti podle kvintilu příjmu na osobu (SRÚ)
phm_kvintily <- dd_all %>% left_join(select(e, DOMACID, PMES), by = "DOMACID") %>% mutate(kc = CENACELK / PMES * 12) %>%
  group_by(DOMACID) %>% summarise(vydani = sum(kc), phm = sum(kc[COICOP %in% c(7221, 7222, 7223)]), .groups = "drop") %>%
  right_join(e, by = "DOMACID") %>% mutate(across(c(vydani, phm), ~ coalesce(.x, 0)), auto = AUTO == 1)
phm_tab <- function(df) df %>% summarise(n_vzorek = n(), ma_auto_pct = 100 * sum(PKOEFP[auto]) / sum(PKOEFP),
  phm_kc_mesic = sum(phm * PKOEFP) / sum(PKOEFP) / 12,
  phm_podil_vydaju_pct = 100 * sum(phm * PKOEFP) / sum(vydani * PKOEFP),
  phm_podil_vydaju_s_autem_pct = 100 * sum((phm * PKOEFP)[auto]) / sum((vydani * PKOEFP)[auto]), .groups = "drop")
phm_kvintily <- bind_rows(phm_kvintily %>% group_by(kvintil = as.character(KVINTIL)) %>% phm_tab(),
                          phm_kvintily %>% phm_tab() %>% mutate(kvintil = "celkem")) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))
phm_hh <- dd %>% left_join(select(e, DOMACID, PMES), by = "DOMACID") %>% mutate(kc = CENACELK / PMES * 12) %>%
  group_by(DOMACID) %>% summarise(nafta_kc = sum(kc[COICOP == 7221]), benzin_kc = sum(kc[COICOP == 7222]),
                                  lpg_kc = sum(kc[COICOP == 7223]), .groups = "drop")
darci <- e %>% filter(AUTO == 1) %>% left_join(phm_hh, by = "DOMACID") %>%
  mutate(across(c(nafta_kc, benzin_kc, lpg_kc), ~ coalesce(.x, 0)),
         nafta_l = nafta_kc / cena_phm[["nafta"]], benzin_l = benzin_kc / cena_phm[["benzin"]], lpg_l = lpg_kc / cena_phm[["lpg"]],
         typ = ifelse(DUM %in% 1:2, "RD", "BD"))
s <- s %>% mutate(typ_phm = ifelse(typ == "RD", "RD", "BD"), benzin_l = 0, nafta_l = 0, lpg_l = 0)
for (tt in c("RD", "BD")) for (k in 1:5) {
  cil <- which(s$auto & s$typ_phm == tt & s$kvintil %in% k)
  dar <- darci %>% filter(typ == tt, KVINTIL == k)
  if (!length(cil) || !nrow(dar)) next
  i <- sample(nrow(dar), length(cil), replace = TRUE, prob = dar$PKOEFP)
  s$benzin_l[cil] <- dar$benzin_l[i]; s$nafta_l[cil] <- dar$nafta_l[i]; s$lpg_l[cil] <- dar$lpg_l[i]
}

# ---------- množství, emise, náklady ETS2 ----------
s <- s %>% left_join(select(PODIL_UHLI_SRU, skup_paliva = skup, podil_uhli), by = "skup_paliva") %>%
  mutate(
    plyn_kwh   = ifelse(kc_plyn > 0, kwh_z_kc(kc_plyn, plyn_rok), 0),
    uhli_q     = kc_paliva * podil_uhli / cena_uhli_q_rok,
    teplo_gj   = kc_ut / teplo_kc_gj_rok,
    co2_plyn   = plyn_kwh * 3.6e-3 * p$GAS_NCV_TO_GCV * p$EF[["plyn"]] / 1000,
    co2_paliva = uhli_q / 10 * p$NCV[["hnede"]] * p$EF[["hnede"]] / 1000,
    co2_teplo  = teplo_gj * p$DT_KG_PER_GJ / 1000,
    co2_phm    = (benzin_l * p$KG_L[["benzin"]] + nafta_l * p$KG_L[["nafta"]] +
                  lpg_l * LPG_KG_L / 1000 * p$NCV[["lpg"]] * p$EF[["lpg"]]) / 1000)
# --- C1 (25. 11. 2026, HLAVNÍ VARIANTA): kalibrace emisí z plynu a uhlí na národní bilanci, přepočtenou na zimu roku 2028 ---
# Mikrosimulace z výdajů SILC 2024 dává spotřebu z doby před krizí (plyn ~91 PJ, bilance 2021: 87 PJ); po krizi domácnosti
# topí méně (2023–2024: 61–62 PJ). Postup: (1) lineární trend denostupňů 2005–posl. rok (Eurostat nrg_chdd_a) -> odhad zimy 2028
# (oteplování započtené); (2) bilance domácností za KAL_ROKY (nrg_bal_c FC_OTH_HH_E, plyn G3000, uhlí C0000X0350-0370, výhřevnost)
# přepočtená na zimu 2028: na teplotě závisí ~75 % plynu (vytápění) a celé uhlí; (3) emise z plynu a uhlí škálované na tento cíl.
# Výdaje domácností zůstávají podle SILC. Se SILC 2025 přepnout ETS2_KAL_ROKY na "2024,2025". Vypnutí: ETS2_KALIBRACE=0.
KAL_ROKY <- as.integer(strsplit(Sys.getenv("ETS2_KAL_ROKY", "2023,2024"), ",")[[1]])          # uhlí (Eurostat)
KAL_ROKY_PLYN <- as.integer(strsplit(Sys.getenv("ETS2_KAL_ROKY_PLYN", "2024,2025"), ",")[[1]])  # plyn
# Plyn 2025 zatím není v Eurostatu: ERÚ, Roční zpráva o provozu plynárenské soustavy 2025 (eruplyn2025_1.pdf):
# celková spotřeba 78 935,9 GWh, domácnosti 26,4 % -> 20,84 TWh spalné = 75,0 PJ, x0,902 na výhřevnost = 67,7 PJ.
# Kontrola: ERÚ 2025 domácnosti +9,9 % -> 2024 ~61,5 PJ, Eurostat 2024 61,1 PJ (sedí).
PLYN_ERU_PJ <- c(`2025` = 78935.9 * 0.264 * 3.6 / 1000 * 0.902)
PODIL_PLYNU_NA_TEPLOTE <- 0.75
plyn_pj <- sum(s$plyn_kwh * 3.6e-3 * p$GAS_NCV_TO_GCV * s$w) / 1e6
uhli_pj <- sum(s$uhli_q / 10 * p$NCV[["hnede"]] * s$w) / 1e6
if (Sys.getenv("ETS2_KALIBRACE", "1") == "1") {
  cache <- file.path("../data/eurostat_kalibrace.csv")
  stahni <- function(tab, klic) {
    d <- read_csv(sprintf("https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/%s/%s?format=SDMX-CSV&startPeriod=2005", tab, klic),
                  show_col_types = FALSE, col_types = cols(.default = "c"))
    tibble(rok = as.integer(d$TIME_PERIOD), hodnota = as.numeric(d$OBS_VALUE), rada = if ("siec" %in% names(d)) d$siec else "HDD")
  }
  ez <- tryCatch(bind_rows(stahni("nrg_chdd_a", "A..HDD.CZ") |> mutate(rada = "HDD"),
                           stahni("nrg_bal_c", "A.FC_OTH_HH_E..TJ.CZ") |> filter(rada %in% c("G3000", "C0000X0350-0370"))),
                 error = function(e) NULL)
  if (!is.null(ez)) write_csv(ez, cache) else { cat("C1: Eurostat nedostupný, beru uložená data\n"); ez <- read_csv(cache, show_col_types = FALSE) }
  hdd <- ez |> filter(rada == "HDD", !is.na(hodnota))
  HDD_2028 <- predict(lm(hodnota ~ rok, data = hdd), newdata = data.frame(rok = 2028))
  hdd_r <- hdd$hodnota[match(KAL_ROKY, hdd$rok)]
  bal <- function(kod, roky) { v <- ez$hodnota[ez$rada == kod][match(roky, ez$rok[ez$rada == kod])] / 1000
    if (kod == "G3000") v[is.na(v) & as.character(roky) %in% names(PLYN_ERU_PJ)] <- PLYN_ERU_PJ[as.character(roky[is.na(v) & as.character(roky) %in% names(PLYN_ERU_PJ)])]
    v }
  hdd_p <- hdd$hodnota[match(KAL_ROKY_PLYN, hdd$rok)]
  if (anyNA(c(hdd_r, hdd_p, bal("G3000", KAL_ROKY_PLYN), bal("C0000X0350-0370", KAL_ROKY)))) stop("C1: chybí bilance nebo denostupně")
  plyn_cil <- mean(bal("G3000", KAL_ROKY_PLYN) * ((1 - PODIL_PLYNU_NA_TEPLOTE) + PODIL_PLYNU_NA_TEPLOTE * HDD_2028 / hdd_p))
  uhli_cil <- mean(bal("C0000X0350-0370", KAL_ROKY) * HDD_2028 / hdd_r)
  K_PLYN <- plyn_cil / plyn_pj; K_UHLI <- uhli_cil / uhli_pj
  # Plyn: SILC zaznamenává měsíční ZÁLOHU (pokyny tazatelům SILC 2024, B2 bod 7), po krizi nadsazenou -> škáluje se množství
  # i z něj odvozený výdaj (vydaje_plyn se počítá z plyn_kwh níže). Uhlí: SILC se ptá na skutečné roční výdaje -> výdaje
  # zůstávají, škáluje se jen množství pro emise (chyba je spíš v převodu cenou, viz C2).
  s$plyn_kwh <- s$plyn_kwh * K_PLYN; s$co2_plyn <- s$co2_plyn * K_PLYN; s$co2_paliva <- s$co2_paliva * K_UHLI
  kal <- tibble(ukazatel = c("roky_bilance_uhli", "hdd_trend_2028", paste0("hdd_", KAL_ROKY), "plyn_mikrosimulace_pj", "plyn_cil_pj",
                             "uhli_mikrosimulace_pj", "uhli_cil_pj", "faktor_plyn", "faktor_uhli"),
                hodnota = c(as.numeric(paste(KAL_ROKY, collapse = "")), HDD_2028, hdd_r, plyn_pj, plyn_cil, uhli_pj, uhli_cil, K_PLYN, K_UHLI)) |>
    bind_rows(tibble(ukazatel = c("roky_bilance_plyn", paste0("hdd_plyn_", KAL_ROKY_PLYN), paste0("plyn_bilance_pj_", KAL_ROKY_PLYN)),
                     hodnota = c(as.numeric(paste(KAL_ROKY_PLYN, collapse = "")), hdd_p, bal("G3000", KAL_ROKY_PLYN)))) |>
    mutate(hodnota = round(hodnota, 3))
  write_csv(kal, file.path(OUT_DIR, "09_c1_kalibrace.csv")); print(kal)
} else cat("C1: kalibrace vypnuta\n")
for (sc in c("A", "B")) {
  kc_t <- p$SCEN[[ifelse(sc == "A", "A_hranice_45EUR2020", "B_futures_Dec28")]] * p$FX
  s[[paste0(sc, "_vytapeni")]] <- (s$co2_plyn + s$co2_paliva) * kc_t * p$VAT[["std"]] + s$co2_teplo * kc_t * p$VAT[["teplo"]]
  s[[paste0(sc, "_phm")]]      <- s$co2_phm * kc_t * p$VAT[["std"]]
  s[[paste0(sc, "_teplo")]]    <- s$co2_teplo * kc_t * p$VAT[["teplo"]]
  s[[paste0(sc, "_plyn")]]     <- s$co2_plyn * kc_t * p$VAT[["std"]]
  s[[paste0(sc, "_uhli")]]     <- s$co2_paliva * kc_t * p$VAT[["std"]]
  s[[paste0(sc, "_celkem")]]   <- s[[paste0(sc, "_vytapeni")]] + s[[paste0(sc, "_phm")]]
}

# zdražení PHM na litr (scénář A a B) vůči cenám ČSÚ v 02_parametry.R
phm_zdrazeni <- bind_rows(lapply(c("A", "B"), function(sc) {
  kc_t <- p$SCEN[[ifelse(sc == "A", "A_hranice_45EUR2020", "B_futures_Dec28")]] * p$FX
  tibble(scenar = sc, palivo = c("benzín", "nafta"),
         kc_na_litr = c(p$KG_L[["benzin"]], p$KG_L[["nafta"]]) / 1000 * kc_t * p$VAT[["std"]],
         cena_kc_l = c(p$CENA[["benzin_kc_l"]], p$CENA[["nafta_kc_l"]]))
})) %>% mutate(zdrazeni_pct = 100 * kc_na_litr / cena_kc_l, across(where(is.numeric), ~ round(.x, 2)))

# váha pro počty, které závisí na ETS2: byty na teple jen v rozsahu domácností na zdrojích v ETS2.
# SILC neříká, ze kterého zdroje domácnost teplo bere. Váhu bytů na teple proto násobíme podílem tepla, které
# v jejich kraji dodávají zdroje v ETS2 (ERÚ: cenové lokality do 20 MWt, uhlí + plyn aspoň 50 %), a celek
# škálujeme na N_TEPLO_ETS2_TIS. Citlivost: TEPLO_VAHA_KRAJ <- FALSE = všechny byty na teple stejně (do 14. 11. 2026).
TEPLO_VAHA_KRAJ <- TRUE
KRAJ_SILC_ERU <- c(`11` = "A", `21` = "S", `31` = "C", `32` = "P", `41` = "K", `42` = "U", `51` = "L", `52` = "H",
                   `53` = "E", `61` = "J", `62` = "B", `71` = "M", `72` = "Z", `81` = "T")
# Pozor: vykon_mwt v ERÚ je výkon vlastních zdrojů držitele licence v lokalitě, ne zdroje, odkud teplo je.
# Lokalita, která dodá víc tepla, než její zdroje zvládnou (výkon x 3 000 h x 3,6 GJ/MWh), teplo nakupuje
# z velkého zdroje (typicky ETS1, např. Havířov z Dětmarovic) a za zdroj v ETS2 se nepočítá.
eru_kraj <- read_csv(file.path(ERU_DIR, paste0("eru_teplo_", ERU_ROK_TEPLO, ".csv")), show_col_types = FALSE) %>%
  mutate(gj = rowSums(across(ends_with("_mnozstvi_gj")), na.rm = TRUE),
         ets2 = !is.na(vykon_mwt) & vykon_mwt <= 20 & coalesce(uhli_pct, 0) + coalesce(plyn_pct, 0) >= 50 &
                gj <= vykon_mwt * 3.6 * 3000) %>%
  filter(kraj %in% KRAJ_SILC_ERU) %>%   # pár řádků PDF převodu nemá platný kód kraje
  group_by(kraj) %>% summarise(podil_ets2 = sum(gj[ets2]) / sum(gj), gj_tis = sum(gj) / 1000, .groups = "drop")
if (!all(KRAJ_SILC_ERU %in% eru_kraj$kraj)) stop("ERÚ: chybí kraj ", paste(setdiff(KRAJ_SILC_ERU, eru_kraj$kraj), collapse = ", "))
s$podil_tepla_ets2 <- eru_kraj$podil_ets2[match(KRAJ_SILC_ERU[as.character(s$KRAJ)], eru_kraj$kraj)]
if (any(s$archetyp == TEPLO & is.na(s$podil_tepla_ets2))) stop("Byt na teple bez kraje v ERÚ – zkontroluj KRAJ_SILC_ERU.")
vaha_teplo <- if (TEPLO_VAHA_KRAJ) s$w * s$podil_tepla_ets2 else s$w
k_teplo <- N_TEPLO_ETS2_TIS * 1000 / sum(vaha_teplo[s$archetyp == TEPLO])
# pravděpodobnost, že teplo ze sítě (výdaj ÚT) domácnosti pochází ze zdroje v ETS2: podíl v kraji × k_teplo
p_ut_ets2 <- (vaha_teplo / s$w) * k_teplo
if (any(p_ut_ets2[s$archetyp == TEPLO] > 1)) stop("Podíl bytu na teple v ETS2 vyšel > 1 – zkontroluj vážení podle krajů.")
p_ut_ets2 <- pmin(1, p_ut_ets2)
cat("\nPodíl tepla ze zdrojů v ETS2 podle krajů (ERÚ", ERU_ROK_TEPLO, "):\n")
print(eru_kraj %>% mutate(podil_ets2 = round(100 * podil_ets2, 1)) %>% arrange(desc(podil_ets2)), n = 20)

# ---------- B3 (25. 11. 2026): náklad ETS2 za teplo ze sítě jen tam, kde skutečně vzniká ----------
# Dřív dostaly fiktivní náklad ETS2 za teplo VŠECHNY domácnosti s výdajem za ÚT (i ~1,5 mil. bytů na teple z ETS1
# a domácnosti jiných archetypů s platbou za ÚT) a tento náklad vstupoval i do mediánu pro práh 2M po ETS2.
# Teď je každá domácnost s výdajem za ÚT rozdělena na dvě váhové varianty: zdroj v ETS2 (váha w * p, s nákladem
# za teplo) a zdroj v ETS1 (váha w * (1 - p), bez nákladu za teplo). Všechny další kroky (práh, zranitelnost,
# počty) pak počítají s touto směsí. Byty na teple v ETS1 zůstávají v archetypu TEPLO, rozlišuje je ut_ets2.
# POZNÁMKA PRO PŘÍŠTÍ KONTROLU (ověřeno v SILC 2024 a dokumentaci 25. 11. 2026, nález nezávislé kontroly zamítnut):
# Domácnosti na plyn (ZDROJ_ENER 2) s výdajem za ÚT (~113 tis.) NEMAJÍ domovní plynovou kotelnu jako hlavní zdroj.
# ZDROJ_ENER se ptá jen u VYTAPENI 2/3 (vlastní/etážové topení, lokální topidla); domovní/bloková kotelna je VYTAPENI 1
# a palivo u ní SILC nezjišťuje. UT = „ústřední vytápění a teplá voda“ ze zdroje mimo byt; tyto domácnosti platí
# i plnou zálohu na plyn (medián 24 tis. Kč/rok vs. 30 tis. bez UT), takže UT je spíš teplá voda / společný zdroj
# neznámého paliva. Proto i u nich krajská pravděpodobnost p_ut_ets2, ne 1. Citlivost „vždy ETS2“: ~+10 tis. zranitelných.
# Otevřené: k_teplo se kalibruje jen na archetyp TEPLO (380 tis.), ale p_ut_ets2 dostávají všechny domácnosti
# s ÚT → na zdroji v ETS2 je celkem ~419 tis. domácností (viz výpis B3 níže). Ponecháno (K2, 25. 11.): 380 tis. je
# jen z licencovaných zdrojů, nelicencované domovní kotelny na plyn chybí. Kalibrace na všechny s ÚT: 185 místo 187 tis.
rozdel <- s$kc_ut > 0 & p_ut_ets2 < 1
s_v2 <- s %>% mutate(ut_ets2 = kc_ut > 0, w = ifelse(rozdel, w * p_ut_ets2, w))
s_v1 <- s[rozdel, ] %>% mutate(ut_ets2 = FALSE, w = w * (1 - p_ut_ets2[rozdel]), co2_teplo = 0,
  A_vytapeni = A_vytapeni - A_teplo, B_vytapeni = B_vytapeni - B_teplo,
  A_celkem = A_celkem - A_teplo, B_celkem = B_celkem - B_teplo, A_teplo = 0, B_teplo = 0,
  archetyp = ifelse(archetyp == TEPLO, TEPLO_ETS1, archetyp))
cat("B3: domácností s výdajem za ÚT (tis.):", round(sum(s$w[s$kc_ut > 0]) / 1000), "| z toho na zdroji v ETS2:",
    round(sum(s_v2$w[s_v2$kc_ut > 0]) / 1000), "| v ETS1:", round(sum(s_v1$w) / 1000), "\n")
s <- bind_rows(s_v2, s_v1)
ok_p <- !is.na(s$prijem_rok) & s$prijem_rok > 0
s$w_ets2 <- s$w   # od B3 shodné s w (rozdělení ETS2/ETS1 je už ve variantách řádků); ponecháno kvůli návazným skriptům
s$f_teplo_ets2 <- ifelse(s$archetyp == TEPLO, as.numeric(s$ut_ets2), 0) # pro 11_kompenzace_nastroje.R

# výdaje na energie v cenách 2028 (stejný rok jako povolenka a příjmy)
cena_plyn_2026 <- function(kwh) ifelse(kwh <= 0, 0, plyn_2026[pasmo(kwh)])
s <- s %>% mutate(
  vydaje_plyn   = plyn_kwh * cena_plyn_2026(plyn_kwh) * p$CENY_2026_NA_2028,
  vydaje_paliva = kc_paliva * IDX_TUHA[["2025"]] / IDX_TUHA[[r]] * p$CENY_2026_NA_2028,
  vydaje_teplo  = kc_ut * IDX_TEPLO[["2025"]] / IDX_TEPLO[[r]] * p$CENY_2026_NA_2028,
  vydaje_elektrina = kc_elektr * IDX_EL * p$CENY_2026_NA_2028,
  vydaje_bydleni = vydaje_plyn + vydaje_paliva + vydaje_teplo + vydaje_elektrina,
  vydaje_phm = (benzin_l * p$CENA[["benzin_kc_l"]] + nafta_l * p$CENA[["nafta_kc_l"]] +
                lpg_l * LPG_KG_L * p$CENA[["lpg_kc_kg"]]) * p$CENY_2026_NA_2028,
  vydaje_energie = vydaje_bydleni + vydaje_phm,
  podil_bydleni_na_prijmu = 100 * vydaje_bydleni / prijem_rok,
  A_narust_pct = 100 * A_celkem / vydaje_energie,
  ut = kc_ut > 0)

# ---------- dvojí zátěž (definice R/07) ----------
wq0 <- function(x, w, q = 0.5) { ok <- !is.na(x) & !is.na(w); x <- x[ok]; w <- w[ok]
  o <- order(x); x <- x[o]; cw <- cumsum(w[o]) / sum(w); x[which(cw >= q)[1]] }
ok  <- ok_p & s$vydaje_energie > 0
M2  <- 2 * wq0(s$podil_bydleni_na_prijmu[ok], s$w[ok])
MED_NARUST <- wq0(s$A_narust_pct[ok & !s$ut], s$w[ok & !s$ut])
N2M <- 2 * MED_NARUST                      # práh nárůstu: 2× medián
P75 <- wq0(s$A_narust_pct[ok & !s$ut], s$w[ok & !s$ut], 0.75)   # citlivost (dřívější definice)
podil_po <- 100 * (s$vydaje_bydleni + s$A_vytapeni) / s$prijem_rok
M2_po <- 2 * wq0(podil_po[ok], s$w[ok])     # práh 2M přepočtený po ETS2 (relativní varianta)
s <- s %>% mutate(vysoky_podil = ok & podil_bydleni_na_prijmu > M2,
                  vysoky_narust = ok & A_narust_pct > N2M,
                  citlivost_dvoji_zatez_P75 = vysoky_podil & ok & A_narust_pct >= P75,
                  # zdražení HLAVNÍHO zdroje vytápění (25. 11. 2026; jen pro přímou platbu a popis, zranitelnost počítá celé vytápění): plyn u ZDROJ_ENER 2, uhlí u 3,
                  # teplo ze sítě jen u dálkového tepla ze zdroje v ETS2; elektřina, dřevo, TČ a vedlejší plyn (vaření, ohřev vody) = 0
                  A_hlavni = case_when(ZDROJ_ENER %in% 2 ~ A_plyn + ifelse(ut_ets2, A_teplo, 0),   # plyn i z domovní kotelny
                                       ZDROJ_ENER %in% 3 ~ A_uhli,
                                       VYTAPENI %in% 1 & ut_ets2 ~ A_teplo, TRUE ~ 0),
                  podil_ets2_na_prijmu = 100 * A_vytapeni / prijem_rok,   # zranitelnost: celé zdražení vytápění (vč. vedlejšího plynu), bez PHM
                  podil_ets2_hlavni_na_prijmu = 100 * A_hlavni / prijem_rok,   # jen hlavní zdroj (podle něj se řídí přímá platba)
                  podil_ets2_vc_phm_na_prijmu = 100 * A_celkem / prijem_rok,
                  # ohrožení 2M po zavedení ETS2 (HLAVNÍ VARIANTA): výdaje na bydlení + náklad ETS2 na vytápění,
                  # práh 2M přepočtený z rozdělení po ETS2 (2× nový medián)
                  vysoky_podil_po_ets2 = ok & podil_po > M2_po,
                  nove_2M = vysoky_podil_po_ets2 & !vysoky_podil,
                  vypadli_2M = vysoky_podil & !vysoky_podil_po_ets2,
                  # ZRANITELNÉ DOMÁCNOSTI (rozhodnutí 21. 10. 2026): spodní dvě pětiny příjmů (1.–4. decil ekvivalizovaného
                  # příjmu) A ohrožení energetickou chudobou (2M) po ETS2 (přepočtený práh) A zdražení vytápění kvůli ETS2 jim vezme aspoň 1 % čistého příjmu (bez PHM, od 23. 11. 2026)
                  zranitelne = ok & decil %in% 1:4 & vysoky_podil_po_ets2 & podil_ets2_na_prijmu >= 1,
                  # citlivost: práh 2M pevný na úrovni před ETS2
                  vysoky_podil_po_ets2_pevny = ok & podil_po > M2,
                  nove_2M_pevny = vysoky_podil_po_ets2_pevny & !vysoky_podil)


boot_ci <- function(x, w) {
  if (length(x) < 10) return(c(NA, NA))
  b <- replicate(B_BOOT, { i <- sample(length(x), replace = TRUE); 100 * sum(w[i][x[i]]) / sum(w[i]) })
  round(quantile(b, c(.025, .975)), 1)
}
souhrn <- function(df, ...) df %>% filter(ok_p[match(DOMAC_ID, s$DOMAC_ID)]) %>% group_by(...) %>% summarise(
  n_vzorek = n(), domacnosti_tis = sum(w) / 1000,
  prijem_kc_mesic = wmean(prijem_rok, w) / 12,
  vydaje_bydleni_kc_mesic = wmean(vydaje_bydleni, w) / 12, vydaje_phm_kc_mesic = wmean(vydaje_phm, w) / 12,
  plyn_mwh_rok = wmean(plyn_kwh, w) / 1000, teplo_gj_rok = wmean(teplo_gj, w), co2_paliva_t_rok = wmean(co2_paliva, w),
  benzin_nafta_l_rok = wmean(benzin_l + nafta_l, w),
  A_vytapeni_kc_mesic = wmean(A_vytapeni, w) / 12, A_phm_kc_mesic = wmean(A_phm, w) / 12,
  A_ets2_kc_mesic = wmean(A_celkem, w) / 12, B_ets2_kc_mesic = wmean(B_celkem, w) / 12,
  A_zdrazeni_vytapeni_pct = 100 * wmean(A_vytapeni, w) / wmean(vydaje_plyn + vydaje_paliva + vydaje_teplo, w),
  A_narust_vydaju_na_energie_pct = 100 * wmean(A_celkem, w) / wmean(vydaje_energie, w),
  podil_bydleni_na_prijmu_median_pct = wq0(podil_bydleni_na_prijmu, w),
  pct_nad_2M = 100 * sum(w[vysoky_podil]) / sum(w),
  pct_nejvyssi_narust = 100 * sum(w[vysoky_narust]) / sum(w),
  pct_zranitelne = 100 * sum(w[zranitelne]) / sum(w),
  pct_zranitelne_ci95 = paste(boot_ci(zranitelne, w), collapse = "–"),
  zranitelne_tis = sum(w[zranitelne]) / 1000,
  nad_2M_tis = sum(w[vysoky_podil]) / 1000, nejvyssi_narust_tis = sum(w[vysoky_narust]) / 1000,
  pct_nad_2M_po_ets2 = 100 * sum(w[vysoky_podil_po_ets2]) / sum(w), nad_2M_po_ets2_tis = sum(w[vysoky_podil_po_ets2]) / 1000,
  nove_2M_tis = sum(w[nove_2M]) / 1000, vypadli_2M_tis = sum(w[vypadli_2M]) / 1000,
  pct_nad_2M_po_ets2_pevny_prah = 100 * sum(w[vysoky_podil_po_ets2_pevny]) / sum(w), nove_2M_pevny_prah_tis = sum(w[nove_2M_pevny]) / 1000, .groups = "drop") %>%
  mutate(zranitelne_tis_ci95 = mapply(function(ci, n) paste(round(as.numeric(strsplit(ci, "–")[[1]]) * n / 100), collapse = "–"),
                                        pct_zranitelne_ci95, domacnosti_tis, USE.NAMES = FALSE)) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))

s_arch <- souhrn(s, archetyp) %>% arrange(desc(pct_zranitelne)) %>%
  mutate(domacnosti_v_ets2_tis = ifelse(archetyp == TEPLO, N_TEPLO_ETS2_TIS, domacnosti_tis),
         zranitelne_tis_ets2 = round(pct_zranitelne * domacnosti_v_ets2_tis / 100, 2),
         zranitelne_tis_ci95 = mapply(function(ci, n) paste(round(as.numeric(strsplit(ci, "–")[[1]]) * n / 100), collapse = "–"),
                                      pct_zranitelne_ci95, domacnosti_v_ets2_tis, USE.NAMES = FALSE),
         nove_2M_tis_ets2 = round(nove_2M_tis / domacnosti_tis * domacnosti_v_ets2_tis, 2))
if (TEPLO_VAHA_KRAJ) {
  teplo_ets2 <- souhrn(s %>% filter(archetyp == TEPLO) %>% mutate(w = w_ets2), archetyp) %>%
    mutate(domacnosti_v_ets2_tis = N_TEPLO_ETS2_TIS, zranitelne_tis_ets2 = round(zranitelne_tis, 2),
           nove_2M_tis_ets2 = round(nove_2M_tis, 2))
  cat("Byty na teple (zdroj v ETS2): zranitelných", round(teplo_ets2$zranitelne_tis, 1), "tis. s vahou podle krajů vs.",
      round(s_arch$zranitelne_tis_ets2[s_arch$archetyp == TEPLO], 1), "tis. bez ní (citlivost)\n")
  s_arch <- bind_rows(s_arch %>% filter(archetyp != TEPLO), teplo_ets2) %>% arrange(desc(pct_zranitelne))
}
s_ostatni <- souhrn(s %>% filter(archetyp == "ostatní"), ostatni_detail)
s_dec  <- souhrn(s, decil)
dz <- s %>% filter(zranitelne)
s_dz_dec  <- dz %>% group_by(decil) %>% summarise(podil_zranitelnych_pct = round(100 * sum(w_ets2) / sum(dz$w_ets2), 1))
s_dz_arch <- bind_rows(dz %>% group_by(archetyp), dz %>% mutate(archetyp = "celkem") %>% group_by(archetyp)) %>%
  summarise(zranitelne_tis = sum(w_ets2) / 1000, podil_zranitelnych_pct = 100 * sum(w_ets2) / sum(dz$w_ets2),
            prijem_kc_mesic = wmean(prijem_rok, w_ets2) / 12,
            A_ets2_kc_mesic = wmean(A_celkem, w_ets2) / 12, B_ets2_kc_mesic = wmean(B_celkem, w_ets2) / 12,
            A_ets2_pct_prijmu = 100 * sum(A_celkem * w_ets2) / sum(prijem_rok * w_ets2),
            A_vytapeni_kc_mesic = wmean(A_vytapeni, w_ets2) / 12,
            A_vytapeni_pct_prijmu = 100 * sum(A_vytapeni * w_ets2) / sum(prijem_rok * w_ets2),
            podil_energie_bydleni_po_ets2_median_pct = wq0(100 * (vydaje_bydleni + A_vytapeni) / prijem_rok, w_ets2),
            .groups = "drop") %>% mutate(across(where(is.numeric), ~ round(.x, 2)))
we <- s$w_ets2
prahy_ets2 <- tibble(ukazatel = c("byty_teplo_v_ets2_tis_FoK", "zranitelne_tis_teplo_jen_ets2", "zranitelne_v_1_4_decilu_pct_teplo_jen_ets2",
                                  "nejvyssi_narust_tis_teplo_jen_ets2", "nove_ohrozeni_2M_tis_teplo_jen_ets2",
                                  "nove_ohrozeni_2M_v_1_4_decilu_pct_teplo_jen_ets2", "citlivost_P75_prah_narustu_pct",
                                  "citlivost_P75_dvoji_zatez_tis_teplo_jen_ets2"),
                     hodnota = c(N_TEPLO_ETS2_TIS, sum(we[s$zranitelne]) / 1000,
                                 100 * sum(we[s$zranitelne & s$decil %in% 1:4]) / sum(we[s$zranitelne]),
                                 sum(we[s$vysoky_narust]) / 1000, sum(we[s$nove_2M]) / 1000,
                                 100 * sum(we[s$nove_2M & s$decil %in% 1:4]) / sum(we[s$nove_2M]),
                                 P75, sum(we[s$citlivost_dvoji_zatez_P75]) / 1000))
prahy <- tibble(ukazatel = c("SILC_rok", "prah_2M_podil_energie_bydleni_pct", "prah_narust_vydaju_2x_median_pct",
                             "ohrozeni_energetickou_chudobou_2M_tis", "prah_2M_po_ets2_pct", "ohrozeni_2M_po_ets2_tis", "nove_ohrozeni_2M_ets2_tis", "nove_ohrozeni_2M_bez_bytu_na_teple_tis",
                             "podil_novych_2M_v_1_4_decilu_pct", "podil_novych_2M_bez_bytu_na_teple_v_1_4_decilu_pct", "citlivost_pevny_prah_ohrozeni_2M_po_ets2_tis", "nejvyssi_narust_tis",
                             "zranitelne_tis", "zranitelne_pct_domacnosti", "podil_zranitelnych_v_1_4_decilu_pct", "zranitelne_energ_chude_uz_dnes_2M_tis", "zranitelne_nove_2M_tis",
                             "plyn_cena_D2_rok_kc_kwh", "uhli_kc_q_rok", "teplo_kc_gj_rok", "elektrina_index_2026_rok", "uprate_prijmu_na_2028"),
                hodnota = c(SILC_ROK, M2, N2M, sum(s$w[s$vysoky_podil]) / 1000, M2_po, sum(s$w[s$vysoky_podil_po_ets2]) / 1000, sum(s$w[s$nove_2M]) / 1000,
                            sum(s$w[s$nove_2M & s$archetyp != "byt teplo (zdroj v ETS2)"]) / 1000,
                            100 * sum(s$w[s$nove_2M & s$decil %in% 1:4]) / sum(s$w[s$nove_2M]),
                            with(s, 100 * sum(w[nove_2M & decil %in% 1:4 & archetyp != "byt teplo (zdroj v ETS2)"]) /
                                      sum(w[nove_2M & archetyp != "byt teplo (zdroj v ETS2)"])),
                            sum(s$w[s$vysoky_podil_po_ets2_pevny]) / 1000, sum(s$w[s$vysoky_narust]) / 1000, sum(dz$w) / 1000, 100 * sum(dz$w) / sum(s$w[ok]),
                            100 * sum(dz$w[dz$decil <= 4]) / sum(dz$w), sum(dz$w[dz$vysoky_podil]) / 1000, sum(dz$w[dz$nove_2M]) / 1000,
                            plyn_rok[["D2"]], cena_uhli_q_rok, teplo_kc_gj_rok, IDX_EL, UPRATE_PRIJ)) %>% mutate(hodnota = round(hodnota, 3))

# srovnání s ENERGO (R/07)
energo <- tryCatch(read_csv(file.path(OUT_DIR, "07_skupiny.csv"), show_col_types = FALSE), error = function(e) NULL)
srovnani <- NULL
if (!is.null(energo)) {
  mapa <- c("RD uhlí" = "RD uhlí", "RD plyn" = "RD plyn", "byt plyn" = "BJ plyn",
            "byt teplo (zdroj v ETS2)" = "BJ dálkové teplo (zdroj v ETS2)")
  srovnani <- s_arch %>% filter(archetyp %in% names(mapa)) %>% mutate(skupina = mapa[archetyp]) %>%
    select(archetyp, skupina, SILC_domacnosti_tis = domacnosti_tis, SILC_vydaje_energie_kc_mesic = vydaje_bydleni_kc_mesic,
           SILC_A_ets2_kc_mesic = A_ets2_kc_mesic, SILC_narust_pct = A_narust_vydaju_na_energie_pct,
           SILC_pct_nad_2M = pct_nad_2M, SILC_pct_zranitelne = pct_zranitelne, SILC_ci95 = pct_zranitelne_ci95) %>%
    left_join(energo %>% select(skupina, ENERGO_domacnosti_tis = domacnosti_tis, ENERGO_vydaje_bydleni_kc_mesic = vydaje_bydleni_kc_mesic,
                                ENERGO_A_ets2_kc_mesic = A_ets2_kc_mesic, ENERGO_narust_pct = A_narust_vydaju_na_energie_pct,
                                ENERGO_pct_nad_2M = pct_nad_2M, ENERGO_pct_dvoji_zatez_P75 = pct_dvoji_zatez), by = "skupina")
}

write_csv(s_arch, file.path(OUT_DIR, "09_silc_archetypy.csv"))
write_csv(s_ostatni, file.path(OUT_DIR, "09_silc_ostatni.csv"))
# byty na teple mimo ETS2 (zdroje v ETS1): topení jim ETS2 nezdraží, zranitelnost se u nich neposuzuje
write_csv(tibble(domacnosti_teplo_celkem_tis = round(sum(s$w[s$archetyp %in% c(TEPLO, TEPLO_ETS1) & ok_p]) / 1000, 1),
                 domacnosti_teplo_ets2_tis = N_TEPLO_ETS2_TIS) %>%
            mutate(domacnosti_teplo_ets1_tis = domacnosti_teplo_celkem_tis - domacnosti_teplo_ets2_tis),
          file.path(OUT_DIR, "09_silc_teplo_ets1.csv"))
write_csv(s_dec, file.path(OUT_DIR, "09_silc_decily.csv"))
write_csv(s_dz_dec, file.path(OUT_DIR, "09_silc_zranitelne_decil.csv"))
write_csv(s_dz_arch, file.path(OUT_DIR, "09_silc_zranitelne_archetyp.csv"))
# 95% interval celkového počtu zranitelných (bootstrap, váha w_ets2)
ci_z <- boot_ci(s$zranitelne & ok_p, we) * sum(we) / 100 / 1000
prahy_ets2 <- bind_rows(prahy_ets2, tibble(ukazatel = c("zranitelne_tis_teplo_jen_ets2_ci95_dolni", "zranitelne_tis_teplo_jen_ets2_ci95_horni"),
                                           hodnota = as.numeric(ci_z)))
prahy <- bind_rows(prahy, prahy_ets2 %>% mutate(hodnota = round(hodnota, 3)))
write_csv(prahy, file.path(OUT_DIR, "09_silc_prahy.csv"))
write_csv(phm_kvintily, file.path(OUT_DIR, "09_sru_phm_kvintily.csv"))
write_csv(phm_zdrazeni, file.path(OUT_DIR, "09_phm_zdrazeni.csv"))
write_csv(PODIL_UHLI_SRU %>% mutate(podil_uhli = round(podil_uhli, 3)), file.path(OUT_DIR, "09_sru_podil_uhli.csv"))
if (!is.null(T_NA_KC_2021)) write_csv(T_NA_KC_2021 %>% mutate(across(where(is.numeric), ~ signif(.x, 4))), file.path(OUT_DIR, "09_kontrola_energo_co2_na_kc_paliv.csv"))
if (!is.null(srovnani)) write_csv(srovnani, file.path(OUT_DIR, "09_srovnani_energo.csv"))

# ---------- kontroly (QA) ----------
K <- file.path(OUT_DIR, "09_silc_kontrola.txt"); sink(K, split = TRUE)
cat("09 – kontroly | vytvořeno", format(Sys.time()), "\n\n")
cat("SILC", SILC_ROK, ": domácností", nrow(s), "| bez příjmu (váženě)", round(100 * sum(s$w[!ok_p]) / sum(s$w), 2), "%\n")
cat("Ceny roku šetření: plyn D1/D2/D3", round(plyn_rok, 3), "Kč/kWh | uhlí", round(cena_uhli_q_rok), "Kč/q (ceníky 2026 × HICP)",
    "| teplo", round(teplo_kc_gj_rok), "Kč/GJ (ERÚ", ERU_ROK, "malé plynové zdroje do 20 MWt; celá ČR", round(CENA_TEPLA_ERU_CR),
    "; kontrola ENERGO × HICP", round(TEPLO_KONTROLA_ENERGO), ")",
    "| PHM", SRU_ROK, round(cena_phm, 2), "\n")
cat("\nPodíl uhlí ve výdajích za tuhá a kapalná paliva (SRÚ):\n"); print(PODIL_UHLI_SRU)
cat("\nROKY VSTUPŮ (musí sedět s rokem výdajů):\n")
print(tibble(vstup = c("výdaje na bydlení (SILC)", "příjem CP_PRIJ (SILC)", "ceny plynu (Eurostat)", "cena uhlí (ceník × HICP)",
                       "cena tepla (ERÚ)", "elektřina (ČSÚ)", "výdaje PHM a podíl uhlí (SRÚ)", "ceny PHM (ČSÚ)", "cílový rok"),
             rok = c(SILC_ROK, SILC_ROK - 1, SILC_ROK, SILC_ROK, ERU_ROK, SILC_ROK, SRU_ROK, SRU_ROK, 2028)))
if (ERU_ROK != SILC_ROK) cat("POZOR: ceny tepla ERÚ za", SILC_ROK, "zatím nejsou, použit rok", ERU_ROK, "× HICP CP0455.\n")
cat("Domácnosti s plynem podle pásma (váženě, %):\n"); print(round(100 * prop.table(tapply(s$w[s$plyn_kwh > 0], pasmo(s$plyn_kwh[s$plyn_kwh > 0]), sum)), 1))
if (!is.null(T_NA_KC_2021)) { cat("\nKONTROLA ENERGO 2021 – podíl uhlí a emise na 1 000 Kč tuhých paliv (ceny 2021):\n"); print(T_NA_KC_2021 %>% mutate(t_na_1000kc = 1000 * t_co2_na_kc)) }
cat("\nAgregáty (celá populace, SILC):\n")
cat("  plyn domácností", round(sum(s$plyn_kwh * s$w) * 3.6e-6 * p$GAS_NCV_TO_GCV), "TJ (výhřevnost)",
    "| CO2 plyn", round(sum(s$co2_plyn * s$w) / 1e6, 2), "Mt  [ČSÚ bilance 2020, tab. 1-3.1: 77 707 TJ; ENERGO 04: 75 994 TJ, 4,23 Mt]\n")
cat("  CO2 tuhá paliva", round(sum(s$co2_paliva * s$w) / 1e6, 2), "Mt  [ENERGO 04: 2,54 Mt]\n")
cat("  průměrná spotřeba plynu (MWh/rok, spalné teplo): RD plyn", round(wmean(s$plyn_kwh[s$archetyp == "RD plyn"], s$w[s$archetyp == "RD plyn"]) / 1000, 1),
    "| byt plyn", round(wmean(s$plyn_kwh[s$archetyp == "byt plyn"], s$w[s$archetyp == "byt plyn"]) / 1000, 1),
    " [ENERGO topící: RD 1 710 m3 = 18,1 MWh; byt 929 m3 = 9,8 MWh]\n")
cat("  CO2 vytápění", round(sum((s$co2_plyn + s$co2_paliva + s$co2_teplo) * s$w) / 1e6, 2), "Mt (teplo v plném rozsahu ETS2)",
    "| bez tepla", round(sum((s$co2_plyn + s$co2_paliva) * s$w) / 1e6, 2), "Mt\n")
cat("  CO2 PHM", round(sum(s$co2_phm * s$w) / 1e6, 2), "Mt | litry na domácnost s autem (SRÚ)",
    round(wmean((darci$benzin_l + darci$nafta_l), darci$PKOEFP)), "l  [ENERGO:", p$PHM_L_DOMACNOST, "l]\n")
cat("\nPodíl dvojí zátěže podle archetypu (shodné hodnoty u skupin, které se mají lišit = varování):\n"); print(s_arch %>% select(archetyp, pct_zranitelne))
# citlivost: PHM škálované na úroveň ENERGO (787 l na domácnost s autem)
k_phm <- p$PHM_L_DOMACNOST / wmean(darci$benzin_l + darci$nafta_l, darci$PKOEFP)
cit <- s %>% mutate(A_c = A_vytapeni + A_phm * k_phm, V_c = vydaje_bydleni + vydaje_phm * k_phm, nar = 100 * A_c / V_c)
P75c <- 2 * wq0(cit$nar[ok & !cit$ut], cit$w[ok & !cit$ut])
cit <- cit %>% mutate(dz = vysoky_podil & ok & nar > P75c) %>% filter(ok_p) %>% group_by(archetyp) %>%
  summarise(pct_zranitelne_PHM_jako_ENERGO = round(100 * sum(w[dz]) / sum(w), 2))
cat("\nCitlivost – PHM škálované na ENERGO (×", round(k_phm, 2), "), práh nárůstu 2× medián =", round(P75c, 2), "%:\n"); print(cit)
write_csv(cit, file.path(OUT_DIR, "09_citlivost_phm.csv"))
sink()

print(prahy); print(s_arch %>% select(archetyp, n_vzorek, domacnosti_tis, A_ets2_kc_mesic, A_narust_vydaju_na_energie_pct,
                                      pct_nad_2M, pct_zranitelne, pct_zranitelne_ci95, zranitelne_tis), width = 200)
if (!is.null(srovnani)) print(srovnani, width = 250)

# --- Rozptyl zdražení PHM u domácností s autem (pro text o dopravě, 25. 11. 2026) ---
phm_rozptyl <- function(df, skupina) {
  a <- df %>% filter(A_phm > 0)
  tibble(skupina = skupina, n_vzorek = nrow(a),
         s_autem_pct = 100 * sum(df$w[df$A_phm > 0]) / sum(df$w),
         P10 = wq(a$A_phm / 12, a$w, .1), P25 = wq(a$A_phm / 12, a$w, .25), P50 = wq(a$A_phm / 12, a$w, .5),
         P75 = wq(a$A_phm / 12, a$w, .75), P90 = wq(a$A_phm / 12, a$w, .9), prumer = wmean(a$A_phm, a$w) / 12)
}
wq <- function(x, w, q) { o <- order(x); cw <- cumsum(w[o]) / sum(w); x[o][which(cw >= q)[1]] }
phm_r <- bind_rows(phm_rozptyl(s, "všechny domácnosti"),
                   phm_rozptyl(s %>% filter(decil %in% 1:4), "1.–4. decil"),
                   phm_rozptyl(s %>% filter(zranitelne), "zranitelné"),
                   phm_rozptyl(s %>% filter(archetyp %in% c("RD uhlí", "RD plyn")), "rodinné domy")) %>%
  mutate(across(where(is.double), ~ round(.x, 1)))
write_csv(phm_r, file.path(OUT_DIR, "09_phm_rozptyl.csv"))
print(phm_r)

# --- E4 (25. 11. 2026): odkud mají zranitelní v „ostatních“ náklad ETS2 na vytápění ---
e4 <- s %>% filter(zranitelne, archetyp == "ostatní") %>% group_by(ostatni_detail) %>%
  summarise(n_vzorek = n(), zranitelne_tis = sum(w) / 1000,
            plyn_kc_mesic = wmean((co2_plyn) * p$SCEN[["A_hranice_45EUR2020"]] * p$FX * p$VAT[["std"]], w) / 12,
            uhli_kc_mesic = wmean(co2_paliva * p$SCEN[["A_hranice_45EUR2020"]] * p$FX * p$VAT[["std"]], w) / 12,
            teplo_kc_mesic = wmean(A_teplo, w) / 12,
            s_plynem_pct = 100 * sum(w[kc_plyn > 0]) / sum(w), s_palivy_pct = 100 * sum(w[kc_paliva > 0]) / sum(w),
            s_ut_pct = 100 * sum(w[kc_ut > 0]) / sum(w), .groups = "drop") %>%
  mutate(across(where(is.double), ~ round(.x, 1)))
write_csv(e4, file.path(OUT_DIR, "09_e4_ostatni_zranitelne.csv")); print(e4)

# --- B3 kontrola: zranitelní mezi byty na teple ze zdroje v ETS1 (náklad jen z plynu, např. vaření, ohřev vody) ---
b3k <- s %>% filter(zranitelne, archetyp %in% c(TEPLO, TEPLO_ETS1)) %>% group_by(ut_ets2) %>%
  summarise(n_vzorek = n(), zranitelne_tis = sum(w) / 1000, A_vytapeni_kc_mesic = wmean(A_vytapeni, w) / 12,
            A_teplo_kc_mesic = wmean(A_teplo, w) / 12, s_plynem_pct = 100 * sum(w[kc_plyn > 0]) / sum(w),
            plyn_kc_mesic_vydaj = wmean(vydaje_plyn, w) / 12, prijem_kc_mesic = wmean(prijem_rok, w) / 12, .groups = "drop") %>%
  mutate(across(where(is.double), ~ round(.x, 1)))
write_csv(b3k, file.path(OUT_DIR, "09_b3_teplo_ets1_zranitelne.csv")); print(b3k)

# --- E1 (25. 11. 2026): rozptyl zdražení vytápění podle archetypu (Kč měsíčně, scénář A) ---
rozptyl_vyt <- function(df, skupina) df %>% filter(ok_p[match(DOMAC_ID, s$DOMAC_ID)], A_vytapeni > 0) %>% group_by(archetyp) %>%
  summarise(skupina = skupina, n_vzorek = n(), domacnosti_tis = sum(w) / 1000,
            P10 = wq0(A_vytapeni / 12, w, .1), P25 = wq0(A_vytapeni / 12, w, .25), P50 = wq0(A_vytapeni / 12, w, .5),
            P75 = wq0(A_vytapeni / 12, w, .75), P90 = wq0(A_vytapeni / 12, w, .9), prumer = wmean(A_vytapeni, w) / 12,
            P25_pct_prijmu = wq0(100 * A_vytapeni / prijem_rok, w, .25), P75_pct_prijmu = wq0(100 * A_vytapeni / prijem_rok, w, .75),
            .groups = "drop")
e1 <- bind_rows(rozptyl_vyt(s %>% filter(archetyp != TEPLO_ETS1), "všechny"), rozptyl_vyt(s %>% filter(zranitelne), "zranitelné")) %>%
  filter(archetyp != "ostatní") %>% mutate(across(where(is.double), ~ round(.x, 1)))
write_csv(e1, file.path(OUT_DIR, "09_e1_rozptyl_vytapeni.csv")); print(e1, width = 200)

# --- E1b: totéž jen pro zdražení HLAVNÍHO zdroje vytápění (bez vedlejšího plynu/uhlí) ---
e1b <- bind_rows(rozptyl_vyt(s %>% filter(archetyp != TEPLO_ETS1) %>% mutate(A_vytapeni = A_hlavni), "všechny"),
                 rozptyl_vyt(s %>% filter(zranitelne) %>% mutate(A_vytapeni = A_hlavni), "zranitelné")) %>%
  filter(!archetyp %in% c("ostatní", TEPLO_ETS1)) %>% mutate(across(where(is.double), ~ round(.x, 1)))
write_csv(e1b, file.path(OUT_DIR, "09_e1_rozptyl_hlavni_zdroj.csv"))

# --- B4 (25. 11. 2026): kolik by domácnosti zaplatily za povolenky ETS2 v cenách paliv ročně (mld. Kč, vč. DPH i bez) ---
b4 <- tibble(scenar = c("A", "B"),
  vytapeni_mld = c(sum(s$A_vytapeni * s$w), sum(s$B_vytapeni * s$w)) / 1e9,
  phm_mld = c(sum(s$A_phm * s$w), sum(s$B_phm * s$w)) / 1e9) %>%
  mutate(celkem_mld = vytapeni_mld + phm_mld,
         celkem_bez_dph_mld = vytapeni_mld / 1.2 + phm_mld / p$VAT[["std"]]) %>%   # teplo má 12 %, plyn/uhlí 21 % -> přibližně
  mutate(across(where(is.double), ~ round(.x, 1)))
write_csv(b4, file.path(OUT_DIR, "09_b4_platby_domacnosti.csv")); print(b4)

# --- E2 (26. 11. 2026, Polanecký): zdražení PHM podle velikosti obce a pracovní aktivity, přímo ze SRÚ ---
# V SILC jsou PHM jen doplněné hot-deckem (RD/BD × kvintil), proto rozdělení podle obce počítáme na dárcích ze SRÚ.
# Jen domácnosti s autem; náklad ETS2 v základním scénáři (A) vč. DPH, Kč měsíčně.
e_obec <- cti(najdi_sru(SRU_ROK, "e")) %>% transmute(DOMACID = num(DOMACID), VEL = num(VEL), EA = num(EA))
kc_t_A <- p$SCEN[["A_hranice_45EUR2020"]] * p$FX
e2 <- darci %>% left_join(e_obec, by = "DOMACID") %>%
  mutate(A_phm_mes = (benzin_l * p$KG_L[["benzin"]] + nafta_l * p$KG_L[["nafta"]] +
                      lpg_l * LPG_KG_L / 1000 * p$NCV[["lpg"]] * p$EF[["lpg"]]) / 1000 * kc_t_A * p$VAT[["std"]] / 12,
         obec = case_when(VEL <= 4 ~ "obec do 2 tis.", VEL <= 7 ~ "2–50 tis.", TRUE ~ "nad 50 tis."),
         prace = ifelse(EA > 0, "někdo pracuje", "nikdo nepracuje"),
         prijem = ifelse(KVINTIL <= 2, "1.–2. kvintil", "3.–5. kvintil"))
e2_tab <- function(df) df %>% summarise(n_vzorek = n(), P25 = wq(A_phm_mes, PKOEFP, .25), P50 = wq(A_phm_mes, PKOEFP, .5),
                                         P75 = wq(A_phm_mes, PKOEFP, .75), P90 = wq(A_phm_mes, PKOEFP, .9),
                                         prumer = wmean(A_phm_mes, PKOEFP), .groups = "drop")
e2_out <- bind_rows(
  e2 %>% group_by(obec) %>% e2_tab() %>% mutate(skupina = "všechny s autem"),
  e2 %>% filter(prijem == "1.–2. kvintil") %>% group_by(obec, prace) %>% e2_tab() %>% mutate(skupina = "nízkopříjmové (1.–2. kvintil)"),
  e2 %>% group_by(prace) %>% e2_tab() %>% mutate(skupina = "všechny s autem", obec = "celkem")) %>%
  relocate(skupina, obec, prace) %>% mutate(across(where(is.double), ~ round(.x)))
write_csv(e2_out, file.path(OUT_DIR, "09_e2_phm_obec.csv")); print(e2_out, n = 50)
