# 12_cena_tepla.R – orientační cena 1 kWh tepla podle zdroje, dnes a se zavedením ETS2 (základní scénář A)
#
# Podklad pro větu v blogu o tom, co se vyplatí (čerpadlo vs. plynový a uhelný kotel) a pro srovnání se dřevem.
# Vstupy: output/08_ceny.csv (ceny plynu, elektřiny, hnědého uhlí), output/05_citlivost_kc_mesic.csv
# (náklad ETS2 typové domácnosti a její spotřeba -> přirážka ETS2 na jednotku paliva),
# ČSÚ CEN0101KT01 (cena elektřiny podle pásma spotřeby, poslední pololetí).
# Předpoklady (orientační):
#   - tepelné čerpadlo: SCOP 2,5 (starší dům, radiátory) a 3,0 (lépe zateplený dům).
#     Cena elektřiny: (a) průměr všech domácností (ČSÚ, Celkem) – horní mez;
#     (b) pásmo DD 5–15 MWh a (c) pásmo DE nad 15 MWh. Domácnosti s čerpadlem mají sazbu D56d/D57d
#     (nízký tarif 20–22 h denně, distribuce v NT asi o 70 % levnější než v D02d) a spotřebu typicky v pásmu DD/DE.
#     ČSÚ nečlení cenu podle distribučních sazeb, pásma spotřeby jsou nejbližší veřejný údaj.
#   - starší plynový kotel: účinnost 85 %; výhřevnost plynu 10,6 kWh/m3
#   - starý kotel na uhlí: účinnost 55–65 %; hnědé uhlí tříděné 17,6 GJ/t (kostka/ořech)
#   - dřevo: tvrdé 1 500 Kč/prm sypaný (tzb-info 4/2026), 1 300 kWh/prm sypaný, kotel 60–70 %; ETS2 se netýká
# Výstup: output/12_cena_tepla.csv

suppressPackageStartupMessages({ library(dplyr); library(readr) })
OUT_DIR <- if (exists("OUT_DIR")) OUT_DIR else "output"
CSU_DIR <- if (exists("CSU_DIR")) CSU_DIR else path.expand(Sys.getenv("ETS2_CSU_DIR", "~/Documents/ČSÚ"))
ceny <- read_csv(file.path(OUT_DIR, "08_ceny.csv"), show_col_types = FALSE)
cena <- function(p) ceny$hodnota[ceny$parametr == p]
cit  <- read_csv(file.path(OUT_DIR, "05_citlivost_kc_mesic.csv"), show_col_types = FALSE)
ets  <- function(typ) { r <- cit[cit$typ == typ, ]
  list(kc_rok = as.numeric(r[["základ (A, 61 €)"]]) * 12, mnozstvi = as.numeric(r$spotreba)) }

# cena elektřiny podle pásma spotřeby, poslední pololetí (Kč/kWh)
f_el <- sort(list.files(file.path(CSU_DIR, "ceny"), pattern = "^CEN0101K_.*\\.csv$", full.names = TRUE))
el <- read_csv(tail(f_el, 1), show_col_types = FALSE) %>%
  mutate(rok = as.integer(sub(".*(\\d{4})$", "\\1", Pololetí)), pol = as.integer(substr(Pololetí, 1, 1))) %>%
  filter(rok * 10 + pol == max(rok * 10 + pol))
el_pasmo <- function(p) el$Hodnota[startsWith(el$`Pásmo spotřeby`, p)] / 1000
OBDOBI_EL <- el$Pololetí[1]

plyn_kwh_m3 <- 10.6;  uhli_kwh_q <- 17.6 * 1000 / 3.6 / 10   # 17,6 GJ/t -> kWh/q
drevo_kc_prm <- 1500; drevo_kwh_prm <- 1300

e_plyn <- ets("RD plyn");       ets_plyn_kwh <- e_plyn$kc_rok / (e_plyn$mnozstvi * plyn_kwh_m3)
e_uhli <- ets("RD hnědé uhlí"); ets_uhli_kwh <- e_uhli$kc_rok / (e_uhli$mnozstvi * uhli_kwh_q)

radek <- function(zdroj, palivo_kc_kwh, ets_kc_kwh, ucinnost) tibble(
  zdroj = zdroj, palivo_kc_kwh = round(palivo_kc_kwh, 2), ucinnost = ucinnost,
  dnes_kc_kwh_tepla = round(palivo_kc_kwh / ucinnost, 2),
  ets2_kc_kwh_tepla = round((palivo_kc_kwh + ets_kc_kwh) / ucinnost, 2))
vysl <- bind_rows(
  radek("tepelné čerpadlo, průměrná cena elektřiny, SCOP 2,5", cena("elektrina_kc_kwh"), 0, 2.5),
  radek("tepelné čerpadlo, pásmo DD (5–15 MWh), SCOP 2,5", el_pasmo("DD"), 0, 2.5),
  radek("tepelné čerpadlo, pásmo DD (5–15 MWh), SCOP 3,0", el_pasmo("DD"), 0, 3.0),
  radek("tepelné čerpadlo, pásmo DE (nad 15 MWh), SCOP 2,5", el_pasmo("DE"), 0, 2.5),
  radek("tepelné čerpadlo, pásmo DE (nad 15 MWh), SCOP 3,0", el_pasmo("DE"), 0, 3.0),
  radek("starší plynový kotel", cena("plyn_kc_kwh"), ets_plyn_kwh, 0.85),
  radek("starý kotel na uhlí (65 %)", cena("hnede_kc_q") / uhli_kwh_q, ets_uhli_kwh, 0.65),
  radek("starý kotel na uhlí (55 %)", cena("hnede_kc_q") / uhli_kwh_q, ets_uhli_kwh, 0.55),
  radek("kotel na dřevo (70 %)", drevo_kc_prm / drevo_kwh_prm, 0, 0.70),
  radek("kotel na dřevo (60 %)", drevo_kc_prm / drevo_kwh_prm, 0, 0.60)) %>%
  mutate(obdobi_elektriny = OBDOBI_EL)
write_csv(vysl, file.path(OUT_DIR, "12_cena_tepla.csv"))

# srovnání čerpadla (pásmo DD, SCOP 2,5 = střední odhad; DE SCOP 3,0 = příznivý) s kotli
tc <- vysl$dnes_kc_kwh_tepla[2]; tc_lo <- vysl$dnes_kc_kwh_tepla[5]
srov <- vysl %>% filter(!grepl("čerpadlo", zdroj)) %>%
  transmute(zdroj, cerpadlo_levnejsi_dnes_pct = paste0(round(100 * (1 - tc / dnes_kc_kwh_tepla)), "–", round(100 * (1 - tc_lo / dnes_kc_kwh_tepla))),
            cerpadlo_levnejsi_ets2_pct = paste0(round(100 * (1 - tc / ets2_kc_kwh_tepla)), "–", round(100 * (1 - tc_lo / ets2_kc_kwh_tepla))))
print(as.data.frame(vysl)); print(as.data.frame(srov))
