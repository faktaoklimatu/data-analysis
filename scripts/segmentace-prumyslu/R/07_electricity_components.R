# =============================================================================
# 07_electricity_components.R – rozklad ceny elektřiny pro průmysl na složky
# Proč: v Česku platí velcí odběratelé (pásmo IF, 70–150 GWh) víc než střední (ID, 2–20 GWh),
#       v EU je to obvykle naopak. Rozklad ukáže, ve které složce rozdíl vzniká.
# Eurostat nrg_pc_205_c (roční): NRG_SUP = silová elektřina a obchod, NETC = síťové poplatky,
#       TAX_FEE_LEV_CHRG = daně, poplatky a odvody (vč. podpory OZE), další podsložky
# Výstup: out/electricity_components.csv (€/MWh)
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)

f <- file.path(DIR_ES, "nrg_pc_205_c.csv")
if (!file.exists(f)) {
  # API vrací 400, pokud filtr obsahuje dimenzi nebo kód, který datová sada nemá -> zkoušíme postupně jednodušší dotazy
  base <- list(geo = c("CZ", "SK", "DE", "AT", "PL", "HU"), nrg_cons = c("MWH2000-19999", "MWH70000-149999"),
               currency = "EUR", sinceTimePeriod = "2019")
  tries <- list(c(base, list(unit = "KWH")), base, base[c("geo", "nrg_cons", "sinceTimePeriod")])
  got <- NULL
  for (q in tries) {
    got <- tryCatch(es_get("nrg_pc_205_c", q), error = function(e) { message("  dotaz selhal: ", conditionMessage(e)); NULL })
    if (!is.null(got)) break
  }
  if (is.null(got)) stop("nrg_pc_205_c se nepodařilo stáhnout ani zjednodušeným dotazem")
  if ("currency" %in% names(got)) got <- got %>% filter(currency == "EUR")
  es_save(got, "nrg_pc_205_c")
}
comp <- read_csv(f, show_col_types = FALSE, col_types = cols(time = col_character()))
if ("unit" %in% names(comp)) comp <- comp %>% filter(unit == "KWH")
if ("currency" %in% names(comp)) comp <- comp %>% filter(currency == "EUR")
comp <- comp %>%
  mutate(band = recode(nrg_cons, `MWH2000-19999` = "ID", `MWH70000-149999` = "IF"),
         eur_mwh = values * 1000) %>%
  select(geo, band, time, nrg_prc, eur_mwh) %>%
  pivot_wider(names_from = band, values_from = eur_mwh) %>%
  mutate(IF_minus_ID = IF - ID) %>% arrange(geo, time, nrg_prc)
write_csv(comp, file.path(DIR_OUT, "electricity_components.csv"))
print(comp %>% filter(geo == "CZ", nrg_prc %in% c("NRG_SUP", "NETC", "TAX_FEE_LEV_CHRG")), n = 50)
