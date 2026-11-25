# 07_zranitelne.R – kdo je ETS2 zasažen nejvíc: vysoký podíl výdajů na energie A ZÁROVEŇ nejvyšší procentní nárůst
# Vstup: output/04_mikro_domacnosti.csv (z 04_mikrosimulace.R). Kontrola: python_kontrola/zranitelne.py (jen na sdíleném disku projektu)
# Definice:
#   výdaje na energie na bydlení = vytápění (spotřeba × cena 2025/26) + elektřina (zálohy 2021 × HICP elektřina 2025/2021)
#                                  + biomasa (výdaje 2021 × HICP tuhá paliva); + PHM (litry × cena) = výdaje na energie celkem
#   vysoký podíl  = podíl energie na bydlení na čistém příjmu > 2× vážený medián (indikátor "2M", EPAH)
#   vysoký nárůst = náklad ETS2 / výdaje na energie celkem v horní čtvrtině domácností
#   dvojí zátěž   = obojí zároveň
# Dálkové teplo: archetyp "zdroj tepla spadne do ETS2" – plný dopad u všech domácností na teple, bez předpokladu
#   o podílu soustav v ETS2. Výsledky pro domácnosti na teple jsou podmíněné. Práh nárůstu (P75) se počítá
#   bez domácností na teple, aby na tomto archetypu nezávisel.
# Výstupy: output/07_*.csv
source("00_setup.R"); source("02_parametry.R")

# vážený kvantil včetně nul (na rozdíl od wq v 00_setup.R, který nuly vynechává)
wq0 <- function(x, w, q = 0.5) {
  ok <- !is.na(x) & !is.na(w); x <- x[ok]; w <- w[ok]
  if (!length(x)) return(NA_real_)
  o <- order(x); x <- x[o]; cw <- cumsum(w[o]) / sum(w)
  x[which(cw >= q)[1]]
}

h0 <- read_csv(file.path(OUT_DIR, "04_mikro_domacnosti.csv"), show_col_types = FALSE)
h <- h0 %>% mutate(dt_ets2 = teplo_gj > 0)

co2_vyt <- with(h, (plyn_kwh * 3.6e-3 * p$GAS_NCV_TO_GCV * p$EF[["plyn"]] +
  hnede_q / 10 * p$NCV[["hnede"]] * p$EF[["hnede"]] + cerne_q / 10 * p$NCV[["cerne"]] * p$EF[["cerne"]] +
  koks_q / 10 * p$NCV[["koks"]] * p$EF[["koks"]] + brik_q / 10 * p$NCV[["brikety_uhelne"]] * p$EF[["brikety_uhelne"]] +
  lpg_kg / 1000 * p$NCV[["lpg"]] * p$EF[["lpg"]] +
  olej_l * p$TOPNY_OLEJ_KG_L / 1000 * p$NCV[["topny_olej"]] * p$EF[["topny_olej"]]) / 1000)
co2_dt  <- ifelse(h$dt_ets2, h$teplo_gj * p$DT_KG_PER_GJ / 1000, 0)
co2_phm <- (h$benzin_l * p$KG_L[["benzin"]] + h$nafta_l * p$KG_L[["nafta"]]) / 1000
for (s in c("A", "B")) {
  kc <- p$SCEN[[ifelse(s == "A", "A_hranice_45EUR2020", "B_futures_Dec28")]] * p$FX
  h[[paste0(s, "_vytapeni")]] <- co2_vyt * kc * p$VAT[["std"]] + co2_dt * kc * p$VAT[["teplo"]]
  h[[paste0(s, "_phm")]] <- co2_phm * kc * p$VAT[["std"]]
  h[[paste0(s, "_celkem")]] <- h[[paste0(s, "_vytapeni")]] + h[[paste0(s, "_phm")]]
}

C <- p$CENA
el <- ifelse(!is.na(h$elektrina_zalohy_kc_mes_2021) & h$elektrina_zalohy_kc_mes_2021 > 0,
             h$elektrina_zalohy_kc_mes_2021 * 12 * p$INDEX_ELEKTRINA, NA)
h$elektrina_imput <- is.na(el)
for (g in split(seq_len(nrow(h)), list(h$dum, h$elektr_vytapeni), drop = TRUE)) {
  med <- wq0(el[g], h$w[g]); el[g][is.na(el[g])] <- med
}
h <- h %>% mutate(
  vydaje_vytapeni = plyn_kwh * C[["plyn_kc_kwh"]] + hnede_q * C[["hnede_kc_q"]] +
    (cerne_q + koks_q + brik_q) * C[["cerne_kc_q"]] + lpg_kg * C[["lpg_kc_kg"]] + olej_l * C[["olej_kc_l"]] +
    teplo_gj * C[["teplo_kc_gj"]] + biomasa_kc_rok_2021 * p$INDEX_TUHA,
  vydaje_vytapeni = vydaje_vytapeni * p$CENY_2026_NA_2028,   # vše v cenách 2028 jako ETS2 a příjmy
  vydaje_elektrina = el * p$CENY_2026_NA_2028,
  vydaje_bydleni = vydaje_vytapeni + vydaje_elektrina,
  vydaje_phm = (benzin_l * C[["benzin_kc_l"]] + nafta_l * C[["nafta_kc_l"]]) * p$CENY_2026_NA_2028,
  vydaje_energie = vydaje_bydleni + vydaje_phm,
  podil_bydleni_na_prijmu = 100 * vydaje_bydleni / prijem_rok,
  A_narust_pct = 100 * A_celkem / vydaje_energie,
  A_podil_prijmu = 100 * A_celkem / prijem_rok)

ok  <- !is.na(h$prijem_rok)
M2  <- 2 * wq0(h$podil_bydleni_na_prijmu[ok], h$w[ok])
okp <- ok & !h$dt_ets2
P75 <- wq0(h$A_narust_pct[okp], h$w[okp], 0.75)
bj <- ifelse(h$dum == "BD", "BJ", h$dum)
h <- h %>% mutate(
  vysoky_podil = ok & podil_bydleni_na_prijmu > M2,
  vysoky_narust = ok & A_narust_pct >= P75,
  dvoji_zatez = vysoky_podil & vysoky_narust,
  skupina = ifelse(hlavni_palivo == "dálkové teplo", paste(bj, "dálkové teplo (zdroj v ETS2)"), paste(bj, hlavni_palivo)))

summ <- function(df, ...) df %>% filter(!is.na(prijem_rok)) %>% group_by(...) %>% summarise(
  domacnosti_tis = sum(w) / 1000,
  vydaje_energie_kc_mesic = wmean(vydaje_energie, w) / 12,
  vydaje_bydleni_kc_mesic = wmean(vydaje_bydleni, w) / 12,
  podil_bydleni_na_prijmu_median_pct = wq0(podil_bydleni_na_prijmu, w),
  A_ets2_kc_mesic = wmean(A_celkem, w) / 12, B_ets2_kc_mesic = wmean(B_celkem, w) / 12,
  A_narust_vydaju_na_energie_pct = 100 * wmean(A_celkem, w) / wmean(vydaje_energie, w),
  B_narust_vydaju_na_energie_pct = 100 * wmean(B_celkem, w) / wmean(vydaje_energie, w),
  A_narust_vytapeni_pct = ifelse(wmean(vydaje_vytapeni, w) > 0, 100 * wmean(A_vytapeni, w) / wmean(vydaje_vytapeni, w), NA),
  A_podil_prijmu_pct = 100 * wmean(A_celkem, w) / wmean(prijem_rok, w),
  pct_nad_2M = 100 * sum(w[vysoky_podil]) / sum(w),
  pct_horni_ctvrtina_narustu = 100 * sum(w[vysoky_narust]) / sum(w),
  pct_dvoji_zatez = 100 * sum(w[dvoji_zatez]) / sum(w),
  dvoji_zatez_tis = sum(w[dvoji_zatez]) / 1000,
  n_vzorek = n()) %>% mutate(across(where(is.numeric), ~ round(.x, 2)))

s_skup <- summ(h, skupina) %>% arrange(desc(pct_dvoji_zatez))
s_dec  <- summ(h, decil); s_kraj <- summ(h, kraj); s_all <- summ(h)
dz <- h %>% filter(dvoji_zatez)
slozeni <- function(col) dz %>% group_by({{ col }}) %>% summarise(podil_skupiny_dvoji_zateze_pct = round(100 * sum(w) / sum(dz$w), 1))
prahy <- tibble(
  prah_2M_podil_energie_bydleni_pct = M2, median_podil_energie_bydleni_pct = M2 / 2,
  prah_P75_narust_vydaju_pct = P75, dvoji_zatez_tis = sum(dz$w) / 1000,
  dvoji_zatez_pct_domacnosti = 100 * sum(dz$w) / sum(h$w[ok]),
  elektrina_imputovana_pct = 100 * sum(h$w[h$elektrina_imput]) / sum(h$w),
  vydaje_energie_mld_kc = sum(h$vydaje_energie * h$w) / 1e9, A_ets2_mld_kc = sum(h$A_celkem * h$w) / 1e9) %>%
  pivot_longer(everything(), names_to = "ukazatel", values_to = "hodnota") %>% mutate(hodnota = round(hodnota, 2))

write_csv(s_skup, file.path(OUT_DIR, "07_skupiny.csv")); write_csv(s_dec, file.path(OUT_DIR, "07_decily.csv"))
write_csv(s_kraj, file.path(OUT_DIR, "07_kraje.csv")); write_csv(s_all, file.path(OUT_DIR, "07_celkem.csv"))
write_csv(prahy, file.path(OUT_DIR, "07_prahy.csv"))
write_csv(slozeni(skupina), file.path(OUT_DIR, "07_dvoji_zatez_skupina.csv"))
write_csv(slozeni(decil), file.path(OUT_DIR, "07_dvoji_zatez_decil.csv"))
print(prahy); print(s_skup, n = 30, width = 250); print(s_dec, width = 250); print(slozeni(skupina), n = 30); print(slozeni(decil))
