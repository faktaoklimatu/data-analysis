# 05_citlivost.R – citlivost dopadu na vytápění typových domácností (Kč/měsíc vč. DPH)
# Vstup: output/01_typove_spotreby_csu.csv. Výstup: output/05_citlivost_kc_mesic.csv
source("00_setup.R"); source("02_parametry.R")
t <- read_csv(file.path(OUT_DIR, "01_typove_spotreby_csu.csv"), show_col_types = FALSE) %>%
  filter(typ != "RD černé uhlí (citlivost)")
PA <- p$SCEN[["A_hranice_45EUR2020"]]
vyt <- function(palivo, x, P, ncv_hnede = p$NCV[["hnede"]], dt_kg = p$DT_KG_PER_GJ, pt = 1) {
  kc_t <- P * p$FX * pt
  switch(palivo,
    plyn_m3  = x * p$T_CO2_NA_M3_PLYNU * kc_t * p$VAT[["std"]],
    hnede_q  = x / 10 * ncv_hnede * p$EF[["hnede"]] / 1000 * kc_t * p$VAT[["std"]],
    teplo_gj = x * dt_kg / 1000 * kc_t * p$VAT[["teplo"]])
}
var <- list(
  "základ (A, 61 €)"                      = list(P = PA),
  "povolenka 45 € nominálně"               = list(P = 45),
  "povolenka 100 €"                        = list(P = 100),
  "přenos do ceny 80 %"                    = list(P = PA, pt = 0.8),
  "hnědé uhlí 14,02 GJ/t (národní průměr)" = list(P = PA, ncv_hnede = 14.02),
  "hnědé uhlí 19,8 GJ/t (Mostecká pánev)"  = list(P = PA, ncv_hnede = 19.8),
  "výtopna 95 % / ztráty 10 %"             = list(P = PA, dt_kg = p$EF[["plyn"]] / (0.95 * 0.90)),
  "výtopna 85 % / ztráty 20 %"             = list(P = PA, dt_kg = p$EF[["plyn"]] / (0.85 * 0.80)))
res <- t %>% select(typ, palivo, spotreba)
for (v in names(var)) res[[v]] <- round(mapply(function(pa, x) do.call(vyt, c(list(palivo = pa, x = x), var[[v]])),
                                              res$palivo, res$spotreba) / 12)
write_csv(res, file.path(OUT_DIR, "05_citlivost_kc_mesic.csv")); print(t(res))
