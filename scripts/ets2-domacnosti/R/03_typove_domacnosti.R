# 03_typove_domacnosti.R – dopad ETS2 na typové domácnosti (vytápění + PHM), scénáře A a B, rok 2028
# Vstup: output/01_typove_spotreby_csu.csv. Výstup: output/03_typove_domacnosti.csv
source("00_setup.R"); source("02_parametry.R")
t <- read_csv(file.path(OUT_DIR, "01_typove_spotreby_csu.csv"), show_col_types = FALSE)
CO2  <- c(plyn_m3 = p$T_CO2_NA_M3_PLYNU, hnede_q = p$NCV[["hnede"]] * p$EF[["hnede"]] / 1e4,
          cerne_q = p$NCV[["cerne"]] * p$EF[["cerne"]] / 1e4, teplo_gj = p$DT_KG_PER_GJ / 1000)   # t CO2 / jednotku
CENA <- c(plyn_m3 = p$CENA[["plyn_kc_kwh"]] * p$GAS_KWH_PER_M3_GCV, hnede_q = p$CENA[["hnede_kc_q"]],
          cerne_q = p$CENA[["cerne_kc_q"]], teplo_gj = p$CENA[["teplo_kc_gj"]])
res <- t %>%
  mutate(co2_vytapeni_t = spotreba * CO2[palivo],
         vat = ifelse(palivo == "teplo_gj", p$VAT[["teplo"]], p$VAT[["std"]]),
         # jmenovatel: VŠECHNA paliva na vytápění (hlavní palivo + dřevo/pelety), ne jen palivo v ETS2
         vydaje_kc = (spotreba * CENA[palivo] + p$BIOMASA_KC_2021[typ] * p$INDEX_TUHA) * p$CENY_2026_NA_2028,   # v cenách 2028 jako ETS2
         phm_l_auto = p$PHM_L_DOMACNOST, podil_nafty = p$PODIL_NAFTY_DOMACNOST,
         co2_phm_t = phm_l_auto * ((1 - podil_nafty) * p$KG_L[["benzin"]] + podil_nafty * p$KG_L[["nafta"]]) / 1000) %>%
  tidyr::crossing(tibble(scenar = names(p$SCEN), cena_povolenky_eur = unname(p$SCEN))) %>%
  mutate(kc_t = cena_povolenky_eur * p$FX,
         vytapeni_kc_rok = co2_vytapeni_t * kc_t * vat, vytapeni_kc_mesic = vytapeni_kc_rok / 12,
         zdrazeni_vytapeni_pct = 100 * vytapeni_kc_rok / vydaje_kc,
         phm_kc_rok = co2_phm_t * kc_t * p$VAT[["std"]], phm_kc_mesic = phm_kc_rok / 12,
         celkem_s_autem_kc_mesic = vytapeni_kc_mesic + phm_kc_mesic) %>%
  select(typ, scenar, cena_povolenky_eur, palivo, spotreba, co2_vytapeni_t, vytapeni_kc_rok, vytapeni_kc_mesic,
         zdrazeni_vytapeni_pct, phm_l_auto, co2_phm_t, phm_kc_rok, phm_kc_mesic, celkem_s_autem_kc_mesic) %>%
  arrange(match(typ, t$typ), scenar)
write_csv(res, file.path(OUT_DIR, "03_typove_domacnosti.csv"))
print(res %>% mutate(across(where(is.numeric), ~ round(.x, 1))), n = 30, width = 250)
