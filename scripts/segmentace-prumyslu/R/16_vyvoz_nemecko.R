# =============================================================================
# 16_vyvoz_nemecko.R – klesá český vývoz do Německa? (podklad ke slajdu „německá poptávka klesá“)
# Comext DS-045409 (roční, EUR): dovoz Německa z ČR a ze světa, celkem a podle kapitol HS
#   – vývoz CZ→DE měříme jako dovoz DE z CZ (stejný zdroj jako jmenovatel podílu)
# Deflátor: index dovozních cen Německa ze zemí EU (sts_inpi_a, PRC_IMP_EU, 2021 = 100) pro odpovídající CPA
# Výstup: out/vyvoz_nemecko.csv
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)

COMEXT_API <- "https://ec.europa.eu/eurostat/api/comext/dissemination/statistics/1.0/data/"
ROKY <- 2015:2025

# skupiny: kapitoly HS -> deflátor CPA
SKUPINY <- tribble(
  ~skupina,               ~hs,                         ~cpa,
  "Celkem",               "TOTAL",                     "CPA_C",
  "Auta a díly",          "87",                        "CPA_C29",
  "Stroje",               "84",                        "CPA_C28",
  "Elektro",              "85",                        "CPA_C26_27",
  "Železo a ocel",        c("72", "73"),               "CPA_C24_25",
  "Chemie a plasty",      as.character(28:40),         "CPA_C20_21"
) |> tidyr::unnest(hs)

f_tr <- file.path(DIR_ES, "comext_de_dovoz.csv")
if (stahnout(f_tr)) {
  tr <- es_get("DS-045409", list(format = "JSON", freq = "A", reporter = "DE", partner = c("CZ", "WORLD"),
                                 product = unique(SKUPINY$hs), flow = "1", indicators = "VALUE_IN_EUROS",
                                 time = ROKY), api = COMEXT_API)
  es_save(tr, "comext_de_dovoz")
}
f_pi <- file.path(DIR_ES, "sts_inpi_a_de.csv")
if (stahnout(f_pi)) {
  pi <- es_get("sts_inpi_a", list(geo = "DE", indic_bt = "PRC_IMP_EU", unit = "I21",
                                  cpa2_1 = unique(SKUPINY$cpa), time = ROKY))
  es_save(pi, "sts_inpi_a_de")
}
tr <- read_csv(f_tr, show_col_types = FALSE)
pi <- read_csv(f_pi, show_col_types = FALSE) |> select(cpa = cpa2_1, time, cena = values)

v <- tr |>
  inner_join(SKUPINY, by = c(product = "hs"), relationship = "many-to-many") |>
  group_by(skupina, cpa, partner, time) |> summarise(eur = sum(values, na.rm = TRUE), .groups = "drop") |>
  pivot_wider(names_from = partner, values_from = eur) |>
  left_join(pi, by = c("cpa", "time")) |>
  arrange(skupina, time) |>
  group_by(skupina) |>
  mutate(vyvoz_mld_eur      = CZ / 1e9,
         vyvoz_realne_mld   = CZ / (cena / cena[time == 2021]) / 1e9,   # ceny 2021
         vyvoz_realne_i2015 = 100 * vyvoz_realne_mld / vyvoz_realne_mld[time == 2015],
         dovoz_de_realne_i2015 = 100 * (WORLD / cena) / (WORLD / cena)[time == 2015],
         podil_cz_pct       = 100 * CZ / WORLD) |>
  ungroup() |>
  select(skupina, rok = time, vyvoz_mld_eur, vyvoz_realne_mld, vyvoz_realne_i2015,
         dovoz_de_realne_i2015, podil_cz_pct, deflator_cpa = cpa, cena_i2021 = cena)

write_csv(v, file.path(DIR_OUT, "vyvoz_nemecko.csv"))
print(v |> filter(rok %in% c(2015, 2019, 2021, 2022, 2023, 2024, 2025)) |>
        mutate(across(where(is.double), ~ round(.x, 1))), n = 60, width = 200)

# --- Nejnovější data: měsíčně ------------------------------------------------
# Comext měsíčně (zatím do srpna 2026) -> stejné období leden–srpen v letech 2019–2026
# Průmyslová výroba CZ a DE (sts_inpr_m, zpracovatelský průmysl C, sezónně očištěno) -> čtvrtletní průměry
f_trm <- file.path(DIR_ES, "comext_de_dovoz_m.csv")
if (stahnout(f_trm)) {
  trm <- es_get("DS-045409", list(format = "JSON", freq = "M", reporter = "DE", partner = c("CZ", "WORLD"),
                                  product = unique(SKUPINY$hs), flow = "1", indicators = "VALUE_IN_EUROS",
                                  sinceTimePeriod = "2019-01"), api = COMEXT_API)
  es_save(trm, "comext_de_dovoz_m")
}
f_pim <- file.path(DIR_ES, "sts_inpi_m_de.csv")
if (stahnout(f_pim)) {
  pim <- es_get("sts_inpi_m", list(geo = "DE", indic_bt = "PRC_IMP_EU", unit = "I21",
                                   cpa2_1 = unique(SKUPINY$cpa), sinceTimePeriod = "2019-01"))
  es_save(pim, "sts_inpi_m_de")
}
f_prm <- file.path(DIR_ES, "sts_inpr_m_cz_de.csv")
if (stahnout(f_prm)) {
  prm <- es_get("sts_inpr_m", list(geo = c("CZ", "DE"), indic_bt = "PRD", nace_r2 = "C", s_adj = "SCA",
                                   unit = "I21", sinceTimePeriod = "2019-01"))
  es_save(prm, "sts_inpr_m_cz_de")
}

trm <- read_csv(f_trm, show_col_types = FALSE, col_types = cols(product = "c", time = "c")) |> filter(!is.na(values))
pim <- read_csv(f_pim, show_col_types = FALSE, col_types = cols(time = "c")) |> select(cpa = cpa2_1, time, cena = values)
posl_mes <- max(trm$time[trm$partner == "CZ" & trm$product == "TOTAL"])       # poslední měsíc s daty, např. "2026-08"
mes_do <- as.integer(substr(posl_mes, 6, 7))

vm <- trm |>
  inner_join(SKUPINY, by = c(product = "hs"), relationship = "many-to-many") |>
  left_join(pim, by = c("cpa", "time")) |>
  mutate(rok = as.integer(substr(time, 1, 4)), mes = as.integer(substr(time, 6, 7))) |>
  filter(mes <= mes_do) |>
  group_by(skupina, partner, rok) |>
  summarise(eur = sum(values), eur_real = sum(values / cena * 100), n_mes = n_distinct(mes), .groups = "drop") |>
  filter(n_mes == mes_do) |>
  pivot_wider(names_from = partner, values_from = c(eur, eur_real)) |>
  group_by(skupina) |> arrange(rok, .by_group = TRUE) |>
  mutate(obdobi = paste0("1–", mes_do, "/", rok),
         vyvoz_mld_eur = eur_CZ / 1e9,
         vyvoz_realne_i2022 = 100 * eur_real_CZ / eur_real_CZ[rok == 2022],
         dovoz_de_realne_i2022 = 100 * eur_real_WORLD / eur_real_WORLD[rok == 2022],
         podil_cz_pct = 100 * eur_CZ / eur_WORLD) |>
  ungroup() |>
  select(skupina, rok, obdobi, vyvoz_mld_eur, vyvoz_realne_i2022, dovoz_de_realne_i2022, podil_cz_pct)
write_csv(vm, file.path(DIR_OUT, "vyvoz_nemecko_ytd.csv"))

vq <- read_csv(f_prm, show_col_types = FALSE, col_types = cols(time = "c")) |>
  mutate(ctvrtleti = paste0(substr(time, 1, 4), "Q", (as.integer(substr(time, 6, 7)) - 1) %/% 3 + 1)) |>
  group_by(geo, ctvrtleti) |> filter(n() == 3) |>                          # jen celá čtvrtletí
  summarise(index_2021 = mean(values), .groups = "drop") |>
  group_by(geo) |> mutate(index_2022 = 100 * index_2021 / mean(index_2021[startsWith(ctvrtleti, "2022")])) |>
  ungroup()
write_csv(vq, file.path(DIR_OUT, "vyroba_cz_de_ctvrtletne.csv"))

cat("\nLeden–", mes_do, ": vývoz CZ→DE a dovoz Německa (reálně, 2022 = 100), podíl ČR\n", sep = "")
print(vm |> filter(rok >= 2022) |> mutate(across(where(is.double), ~ round(.x, 1))), n = 50)
cat("\nPrůmyslová výroba (C, SA), 2022 = 100\n")
print(vq |> filter(ctvrtleti >= "2022Q1") |> select(-index_2021) |> pivot_wider(names_from = geo, values_from = index_2022) |>
        mutate(across(where(is.double), ~ round(.x, 1))), n = 30)
