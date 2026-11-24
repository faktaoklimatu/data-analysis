# =============================================================================
# 08_production_annual.R – roční index průmyslové výroby 2015–2025, Česko a Německo (slide 6, small multiples)
# Eurostat sts_inpr_a (objem, očištěno o pracovní dny, 2021 = 100) → přepočet na 2015 = 100
# Potraviny = C10+C11(+C12), nábytek a ostatní = C31+C32; váhy = přidaná hodnota 2021 (sbs_weights_2021)
# Výstup: out/production_index_annual.csv
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)
# sts_composite() je v R/funkce.R (načte ji 00_setup.R)

f <- file.path(DIR_ES, "sts_inpr_a_annual.csv")
sub <- c(paste0("C", 10:33), "C13-C15")
if (stahnout(f)) {
  es_save(es_get("sts_inpr_a", list(geo = c("CZ", "DE"), nace_r2 = sub, indic_bt = "PRD", s_adj = "CA",
                                    unit = "I21", sinceTimePeriod = 2015)), "sts_inpr_a_annual")
}
sts <- read_csv(f, show_col_types = FALSE) %>% filter(time >= 2015, time <= 2025) %>% select(geo, nace_r2, time, values)
w <- es_read("sbs_weights_2021") %>% transmute(geo, nace_r2, w = values)
agg1315 <- sts %>% filter(nace_r2 == "C13-C15")   # agregát textilu Eurostat publikuje – použijeme ho
sts <- sts_composite(sts %>% filter(nace_r2 != "C13-C15"), w)
if (nrow(agg1315)) sts <- bind_rows(sts %>% filter(nace_r2 != "C13-C15"), agg1315)
idx <- sts %>% group_by(geo, nace_r2) %>% arrange(time) %>%
  mutate(index_2015 = values / values[time == 2015] * 100) %>% ungroup() %>%
  mutate(nace = from_es(nace_r2)) %>% filter(nace %in% c(SECTORS_18 <- c("C10-12","C13-15","C16","C17","C18","C20","C21","C22","C23","C24","C25","C26","C27","C28","C29","C30","C31_32","C33")))
write_csv(idx %>% select(geo, nace, time, index_2015), file.path(DIR_OUT, "production_index_annual.csv"))
chk <- idx %>% filter(time == 2025) %>% select(geo, nace, index_2015) %>% pivot_wider(names_from = geo, values_from = index_2015)
print(chk); cat("Česko roste rychleji než Německo v", sum(chk$CZ > chk$DE, na.rm = TRUE), "z", nrow(chk), "oborů\n")
