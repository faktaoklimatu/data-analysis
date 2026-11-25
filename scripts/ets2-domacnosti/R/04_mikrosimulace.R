# 04_mikrosimulace.R – mikrosimulace ETS2 na všech domácnostech ENERGO 2021 (vytápění + PHM)
# Výstupy: output/04_decily.csv, 04_mikro_domacnosti.csv (pro 07), 04_typ_bydleni_palivo.csv, 04_kraje.csv, 04_zatepleni.csv, 04_agregaty.csv
source("00_setup.R"); source("02_parametry.R")
d <- load_energo(); w <- d$Vahy

RD <- d$EODUMTYP %in% c(1, 2); BD <- d$EODUMTYP %in% c(3, 4)
plyn <- is1(d$ERVYTAPENI_02); hnede <- is1(d$ERVYTAPENI_04); cerne <- is1(d$ERVYTAPENI_05)
drevo <- is1(d$ERVYTAPENI_10); teplo <- is1(d$ERVYTAPENI_15); elektr <- is1(d$ERVYTAPENI_01)
auto <- is1(d$EDAUTAPOCET)
area <- ifelse(!is.na(d$EOBYTPLOCHA_01) & d$EOBYTPLOCHA_01 >= 10 & d$EOBYTPLOCHA_01 <= 600, d$EOBYTPLOCHA_01, NA)

zp_kwh   <- pos(ifelse(d$EPSPOTREBAZPMJ %in% 2, d$EPSPOTREBAZPMNOZ * p$GAS_KWH_PER_M3_GCV, d$EPSPOTREBAZPMNOZ))
hnede_q  <- pos(d$EPTPMNOZSTVI_01); cerne_q <- pos(d$EPTPMNOZSTVI_02)
koks_q   <- pos(d$EPTPMNOZSTVI_03); brik_q <- pos(d$EPTPMNOZSTVI_04); olej_l <- pos(d$EPTPMNOZSTVI_11)
lpg_kg   <- pos(ifelse(d$EPSPOTREBALPGMJ %in% 1, d$EPSPOTREBALPGMNOZ, d$EPSPOTREBALPGMNOZ * 0.51))  # "m3" je v datech zjevně litr kapaliny: ×0,51 kg/l
teplo_gj <- pos(d$EPSPOTRVYTTABGJ_01)
row_l <- function(code) Reduce(`+`, lapply(sprintf("%02d", 1:3), function(k)
  ifelse(d[[paste0("EDPALIVO_", k)]] %in% code, f0(d[[paste0("EDMNOZCRMNOZSTVI_", k)]]), 0)))
benzin_l <- row_l(1); nafta_l <- row_l(2)

# Imputace chybějící spotřeby: vážený medián spotřeby na m2 ve skupině × plocha bytu; bez plochy medián skupiny
imput <- function(x, users, groups) {
  flag <- rep(FALSE, length(x))
  for (g in groups) {
    m <- users & g
    med_m2 <- wq((x / area)[m], w[m])
    fill <- m & is.na(x) & !is.na(area)
    x[fill] <- med_m2 * area[fill]; flag[fill] <- TRUE
    fill2 <- m & is.na(x)
    x[fill2] <- wq(x[m & !flag], w[m & !flag]); flag[fill2] <- TRUE
  }
  list(x = x, flag = flag)
}
uziva_plyn <- is1(d$ERPALIVOAN_02); uziva_teplo <- teplo | is1(d$ERPALIVOAN_15)
zp  <- imput(zp_kwh, uziva_plyn, list(RD & plyn, BD & plyn, RD & !plyn, BD & !plyn, !(RD | BD)))
dt  <- imput(teplo_gj, uziva_teplo, list(BD & teplo, RD & teplo, !teplo))
hu  <- imput(hnede_q, hnede, list(RD, !RD))
cu  <- imput(cerne_q, cerne, list(RD, !RD))

co2 <- tibble(
  plyn    = f0(zp$x) * 3.6e-3 * p$GAS_NCV_TO_GCV * p$EF[["plyn"]] / 1000,
  uhli    = (f0(hu$x) / 10 * p$NCV[["hnede"]] * p$EF[["hnede"]] + f0(cu$x) / 10 * p$NCV[["cerne"]] * p$EF[["cerne"]] +
             f0(koks_q) / 10 * p$NCV[["koks"]] * p$EF[["koks"]] +
             f0(brik_q) / 10 * p$NCV[["brikety_uhelne"]] * p$EF[["brikety_uhelne"]]) / 1000,
  ostatni = (f0(lpg_kg) / 1000 * p$NCV[["lpg"]] * p$EF[["lpg"]] +
             f0(olej_l) * p$TOPNY_OLEJ_KG_L / 1000 * p$NCV[["topny_olej"]] * p$EF[["topny_olej"]]) / 1000,
  teplo   = f0(dt$x) * p$DT_PODIL_ETS2 * p$DT_KG_PER_GJ / 1000,
  phm     = (benzin_l * p$KG_L[["benzin"]] + nafta_l * p$KG_L[["nafta"]]) / 1000)

# Příjem: čistý měsíční; hrubý × 0,78; jinak střed intervalu; × 12 × UPRATE; ekvivalizace odmocninou počtu osob
stredy <- c(7500, 15000, 25000, 35000, 45000, 55000, 65000, 75000, 85000, 95000, 120000)
inc <- ifelse(!is.na(d$EZDOMPRIJEMKC) & d$EZDOMPRIJEMKC > 0,
              ifelse(d$EZDOMPRIJEMTYP %in% 2, d$EZDOMPRIJEMKC * p$HRUBA_NA_CISTOU, d$EZDOMPRIJEMKC),
              stredy[d$EZDOMODHADPRIJEMKC])
inc <- inc * 12 * p$UPRATE
eq_inc <- inc / sqrt(pmax(d$MOPOCOSB_EG, 1))
ok <- !is.na(eq_inc)
o <- order(eq_inc[ok]); idx <- which(ok)[o]
cw <- cumsum(w[idx]) / sum(w[idx])
decil <- rep(NA_real_, nrow(d)); decil[idx] <- pmin(ceiling(cw * 10), 10)

naklady <- function(kc_t) {
  k <- co2 %>% mutate(across(everything(), ~ .x * kc_t * p$VAT[["std"]]),
                      teplo = co2$teplo * kc_t * p$VAT[["teplo"]])
  k %>% mutate(vytapeni = plyn + uhli + ostatni + teplo, celkem = vytapeni + phm)
}
KA <- naklady(p$SCEN[["A_hranice_45EUR2020"]] * p$FX)
KB <- naklady(p$SCEN[["B_futures_Dec28"]] * p$FX)

hlavni <- case_when(plyn ~ "plyn", hnede | cerne ~ "uhlí", teplo ~ "dálkové teplo",
                    drevo ~ "dřevo", elektr ~ "elektřina/TČ", TRUE ~ "ostatní")
mik <- tibble(w = w, decil = decil, dum = ifelse(RD, "RD", ifelse(BD, "BD", "jiný")),
              hlavni_palivo = hlavni, kraj = d$Kraj, prijem_rok = inc, auto = auto,
              zatepleno = is1(d$EODUMZATEPLZPUSOB_01),
              A_vytapeni = KA$vytapeni, A_phm = KA$phm, A_celkem = KA$celkem,
              B_vytapeni = KB$vytapeni, B_phm = KB$phm, B_celkem = KB$celkem) %>%
  mutate(A_podil_prijmu = 100 * A_celkem / prijem_rok, B_podil_prijmu = 100 * B_celkem / prijem_rok)

# Export domácností pro 07_zranitelne.R (spotřeby po imputaci)
write_csv(tibble(id = seq_len(nrow(d)), w = w, decil = decil, dum = mik$dum, hlavni_palivo = hlavni, kraj = d$Kraj,
                 osoby = pmax(d$MOPOCOSB_EG, 1), prijem_rok = inc, plyn_kwh = f0(zp$x), hnede_q = f0(hu$x), cerne_q = f0(cu$x),
                 koks_q = f0(koks_q), brik_q = f0(brik_q), lpg_kg = f0(lpg_kg), olej_l = f0(olej_l), teplo_gj = f0(dt$x),
                 benzin_l = benzin_l, nafta_l = nafta_l, elektr_vytapeni = elektr,
                 elektrina_zalohy_kc_mes_2021 = d$EPZALOHYELEKTRINA,
                 biomasa_kc_rok_2021 = f0(d$EPSPOTREBATPKC_05) + f0(d$EPSPOTREBATPKC_06) + f0(d$EPSPOTREBATPKC_07)),
          file.path(OUT_DIR, "04_mikro_domacnosti.csv"))

summ <- function(df, ...) df %>% filter(!is.na(A_podil_prijmu)) %>% group_by(...) %>% summarise(
  domacnosti_tis = sum(w) / 1000,
  A_vytapeni_kc_mesic = wmean(A_vytapeni, w) / 12, A_phm_kc_mesic = wmean(A_phm, w) / 12,
  A_celkem_kc_mesic = wmean(A_celkem, w) / 12, B_celkem_kc_mesic = wmean(B_celkem, w) / 12,
  A_podil_prijmu_pct = 100 * wmean(A_celkem, w) / wmean(prijem_rok, w),
  A_median_podil_pct = wq(A_podil_prijmu, w),
  A_podil_nad_2pct_prijmu = 100 * sum(w[A_podil_prijmu > 2]) / sum(w),
  B_podil_nad_2pct_prijmu = 100 * sum(w[B_podil_prijmu > 2]) / sum(w)) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))
s_dec <- summ(mik, decil); s_pal <- summ(mik, dum, hlavni_palivo); s_kraj <- summ(mik, kraj)
s_zat <- mik %>% filter(dum == "RD", hlavni_palivo %in% c("plyn", "uhlí"), !is.na(A_podil_prijmu)) %>%
  group_by(hlavni_palivo, zatepleno) %>%
  summarise(domacnosti_tis = sum(w) / 1000, A_vytapeni_kc_mesic = wmean(A_vytapeni, w) / 12)
agg <- tibble(
  co2_vytapeni_Mt = sum((co2$plyn + co2$uhli + co2$ostatni + co2$teplo) * w) / 1e6,
  co2_plyn_Mt = sum(co2$plyn * w) / 1e6, co2_uhli_Mt = sum(co2$uhli * w) / 1e6,
  co2_teplo_ETS2_Mt = sum(co2$teplo * w) / 1e6, co2_phm_Mt = sum(co2$phm * w) / 1e6,
  # validace na národní bilanci ČSÚ (tab. 1-3.1, rok 2020)
  plyn_TJ_mikrosimulace = sum(co2$plyn * w) / p$EF[["plyn"]], plyn_TJ_CSU_2020_tab_1_3_1 = 77706.8,
  uhli_TJ_mikrosimulace = sum(co2$uhli * w) / p$EF[["hnede"]], tuha_paliva_TJ_CSU_2020_tab_1_3_1 = 26563.0,
  domacnosti_mil = sum(w) / 1e6,
  A_naklady_domacnosti_mld_kc = sum(KA$celkem * w) / 1e9, B_naklady_domacnosti_mld_kc = sum(KB$celkem * w) / 1e9,
  A_prumer_kc_mesic = wmean(KA$celkem, w) / 12, B_prumer_kc_mesic = wmean(KB$celkem, w) / 12,
  podil_dom_s_nulovym_vytapenim_pct = 100 * sum(w[KA$vytapeni == 0]) / sum(w),
  podil_imputovany_plyn_pct = 100 * sum(w[zp$flag]) / sum(w[uziva_plyn]),
  podil_imputovane_teplo_pct = 100 * sum(w[dt$flag]) / sum(w[uziva_teplo]),
  prijem_chybi_pct = 100 * sum(w[!ok]) / sum(w)) %>%
  pivot_longer(everything(), names_to = "ukazatel", values_to = "hodnota") %>% mutate(hodnota = round(hodnota, 2))

write_csv(s_dec, file.path(OUT_DIR, "04_decily.csv")); write_csv(s_pal, file.path(OUT_DIR, "04_typ_bydleni_palivo.csv"))
write_csv(s_kraj, file.path(OUT_DIR, "04_kraje.csv")); write_csv(s_zat, file.path(OUT_DIR, "04_zatepleni.csv"))
write_csv(agg, file.path(OUT_DIR, "04_agregaty.csv"))
print(s_dec, width = 200); print(s_pal, n = 30, width = 200); print(s_kraj, width = 200); print(s_zat); print(agg, n = 30)
