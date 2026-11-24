# =============================================================================
# 06_electricity_price.R – cena elektřiny pro průmysl (slide 12)
# Eurostat nrg_pc_205, bez DPH a vratných daní (X_VAT), €/kWh, pololetí 2019, 2025 a 2026 (jakmile vyjde)
# Pásma odběru: ID 2–20 GWh, IF 70–150 GWh ročně (IF = typický energeticky náročný podnik)
# Výstup: out/electricity_price.csv (průměr obou pololetí, €/MWh)
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)

GEO_PC <- c("EU27_2020", "CZ", "DE", "ES", "FR", "IT", "HU", "NL", "AT", "PL", "RO", "SK", "FI", "SE")
f <- file.path(DIR_ES, "nrg_pc_205.csv")
# stáhne znovu, pokud soubor chybí nebo v něm ještě není rok 2026 (Eurostat zveřejňuje pololetí s ~4–5měsíčním zpožděním)
need <- !file.exists(f) || !any(grepl("^2026", read_csv(f, show_col_types = FALSE, col_types = cols(time = col_character()))$time))
if (need) {
  es_save(es_get("nrg_pc_205", list(geo = GEO_PC, nrg_cons = c("MWH2000-19999", "MWH70000-149999"),
                                    tax = "X_VAT", currency = "EUR", unit = "KWH",
                                    sinceTimePeriod = "2019-S1")) %>% filter(substr(time, 1, 4) %in% c("2019", "2025", "2026")), "nrg_pc_205")
}
pc <- read_csv(f, show_col_types = FALSE, col_types = cols(time = col_character())) %>%
  mutate(year = substr(time, 1, 4), band = recode(nrg_cons, `MWH2000-19999` = "ID", `MWH70000-149999` = "IF")) %>%
  group_by(geo, band, year) %>% summarise(eur_mwh = mean(values, na.rm = TRUE) * 1000, n = sum(!is.na(values)), .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = c(eur_mwh, n))
write_csv(pc, file.path(DIR_OUT, "electricity_price.csv"))
print(pc %>% filter(band == "IF") %>% arrange(eur_mwh_2025))
