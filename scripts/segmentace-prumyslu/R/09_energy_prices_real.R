# =============================================================================
# 09_energy_prices_real.R – elektřina a plyn pro velký průmysl, nominálně a reálně (slide 15)
# Elektřina: out/electricity_price.csv (06_electricity_price.R), pásmo IF 70–150 GWh
# Plyn: Eurostat nrg_pc_203, pásmo I4 (100 000–999 999 GJ), bez DPH a vratných daní (X_VAT), €/kWh
# Inflace: Eurostat prc_hicp_aind, HICP EU27_2020, CP00, průměrný roční index (2015 = 100)
# Výstup: out/energy_prices_real.csv
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)
GEO_G <- c("EU27_2020", "CZ", "DE", "AT", "PL", "SK", "HU")
fg <- file.path(DIR_ES, "nrg_pc_203.csv"); fh <- file.path(DIR_ES, "prc_hicp_aind.csv")
if (!file.exists(fg)) es_save(es_get("nrg_pc_203", list(geo = GEO_G, nrg_cons = "GJ100000-999999", tax = "X_VAT",
                                                      currency = "EUR", unit = "KWH", sinceTimePeriod = "2019-S1")), "nrg_pc_203")
if (!file.exists(fh)) es_save(es_get("prc_hicp_aind", list(geo = c("EU27_2020", "CZ"), coicop = "CP00", unit = "INX_A_AVG",
                                                          sinceTimePeriod = 2015)), "prc_hicp_aind")
h <- read_csv(fh, show_col_types = FALSE) %>% filter(geo == "EU27_2020")
defl <- h$values[h$time == 2025] / h$values[h$time == 2019]
gas <- read_csv(fg, show_col_types = FALSE, col_types = cols(time = col_character())) %>%
  mutate(year = substr(time, 1, 4)) %>% filter(year %in% c("2019", "2025", "2026")) %>%
  group_by(geo, year) %>% summarise(eur_mwh = mean(values, na.rm = TRUE) * 1000, .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = eur_mwh, names_prefix = "gas_")
el <- read_csv(file.path(DIR_OUT, "electricity_price.csv"), show_col_types = FALSE) %>% filter(band == "IF") %>%
  transmute(geo, el_2019 = eur_mwh_2019, el_2025 = eur_mwh_2025, el_2026 = eur_mwh_2026)
out <- inner_join(el, gas, by = "geo") %>%
  mutate(el_real_multiple = el_2025 / (el_2019 * defl), gas_real_multiple = gas_2025 / (gas_2019 * defl), hicp_eu_2025_2019 = defl)
write_csv(out, file.path(DIR_OUT, "energy_prices_real.csv"))
print(out %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
