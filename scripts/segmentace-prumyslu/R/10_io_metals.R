# =============================================================================
# 10_io_metals.R – podíl výrobků hutí (CPA 24) na hodnotě produkce oborů, Česko (slide 22)
# Eurostat naio_10_cp1750 – symetrická input-output tabulka odvětví × odvětví, mil. €, domácí + dovoz (TOTAL)
# přímý podíl = C24 → obor / P1 oboru; nepřímý (2. kolo) = C25 → obor / P1 × (C24 → C25 / P1 C25)
# Výstup: out/io_metals.csv
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)
YEAR_IO <- 2020   # poslední rok symetrické tabulky pro ČR (2024 zatím prázdný)
f <- file.path(DIR_ES, "naio_10_cp1750_CZ.csv")
if (!file.exists(f)) es_save(es_get("naio_10_cp1750", list(geo = "CZ", unit = "MIO_EUR", stk_flow = "TOTAL",
                                                          ind_ava = c("C24", "C25", "P1"), time = YEAR_IO)), "naio_10_cp1750_CZ")
io <- read_csv(f, show_col_types = FALSE) %>% select(ind_ava, ind_use, values) %>%
  pivot_wider(names_from = ind_ava, values_from = values)
a25 <- io$C24[io$ind_use == "C25"] / io$P1[io$ind_use == "C25"]
SEC <- c("C10-12","C13-15","C16","C17","C18","C20","C21","C22","C23","C25","C26","C27","C28","C29","C30","C31_32","C33","F")
out <- io %>% filter(ind_use %in% SEC) %>%
  transmute(nace = ind_use, direct_pct = C24 / P1 * 100, via_C25_pct = C25 / P1 * a25 * 100,
            approx_total_pct = direct_pct + via_C25_pct, cost_effect_of_10pct_metal_price = approx_total_pct / 10) %>%
  arrange(desc(approx_total_pct))
write_csv(out, file.path(DIR_OUT, "io_metals.csv"))
print(out %>% mutate(across(where(is.numeric), ~ round(.x, 1))))
