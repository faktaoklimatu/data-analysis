# 06_kontrola_mikrodata_typove.R – KONTROLA: mediány spotřeb typových domácností z mikrodat ENERGO 2021
# (srovnání s publikovanými průměry ČSÚ v 01; poměry uhlí s dřevem / bez dřeva pro 02_parametry.R)
# Výstup: output/06_energo_podily.csv, 06_typove_biomasa_phm.csv, output/06_energo_typove_mikrodata.csv, output/06_pomery_uhli_drevo.csv
source("00_setup.R"); source("02_parametry.R")
d <- load_energo(); w <- d$Vahy

RD <- d$EODUMTYP %in% c(1, 2)          # samostatný RD, dvojdomek/řadový
BD <- d$EODUMTYP %in% c(3, 4)          # bytový dům
# Hlavní palivo na vytápění: 01 elektřina, 02 plyn, 04 hnědé uhlí, 05 černé uhlí, 10 dřevo, 15 dálkové teplo
plyn <- is1(d$ERVYTAPENI_02); hnede <- is1(d$ERVYTAPENI_04); cerne <- is1(d$ERVYTAPENI_05)
drevo <- is1(d$ERVYTAPENI_10); teplo <- is1(d$ERVYTAPENI_15); elektr <- is1(d$ERVYTAPENI_01)
drevo_vedl <- is1(d$ERVYTAPVEDL_10)
auto <- is1(d$EDAUTAPOCET)

podily <- bind_rows(lapply(list(RD = RD, BD = BD), function(m) {
  pal <- list(plyn = plyn, `hnědé uhlí` = hnede, `černé uhlí` = cerne, `dálkové teplo` = teplo,
              `dřevo` = drevo, `elektřina` = elektr)
  tibble(palivo = names(pal),
         podil_pct = 100 * sapply(pal, function(c) sum(w[m & c]) / sum(w[m])),
         domacnosti_tis = sapply(pal, function(c) sum(w[m & c]) / 1000))
}), .id = "dum")
write_csv(podily, file.path(OUT_DIR, "06_energo_podily.csv")); print(podily, n = 50)

# Spotřeby: plyn (EPSPOTREBAZPMJ 1 = kWh, 2 = m3), tuhá paliva v q, dálkové teplo v GJ
zp_kwh   <- pos(ifelse(d$EPSPOTREBAZPMJ %in% 2, d$EPSPOTREBAZPMNOZ * p$GAS_KWH_PER_M3_GCV, d$EPSPOTREBAZPMNOZ))
hnede_q  <- pos(d$EPTPMNOZSTVI_01); cerne_q <- pos(d$EPTPMNOZSTVI_02); teplo_gj <- pos(d$EPSPOTRVYTTABGJ_01)
# Doprava: EDPALIVO_xx 1 = benzin, 2 = nafta; litry načerpané v ČR, řádky 1–3
row_l <- function(code) Reduce(`+`, lapply(sprintf("%02d", 1:3), function(k)
  ifelse(d[[paste0("EDPALIVO_", k)]] %in% code, f0(d[[paste0("EDMNOZCRMNOZSTVI_", k)]]), 0)))
benzin_l <- row_l(1); nafta_l <- row_l(2); litry <- benzin_l + nafta_l

typy <- list(
  "RD plyn"                         = list(m = RD & plyn, x = list(plyn_kwh = zp_kwh)),
  "RD hnědé uhlí (bez dřeva)"       = list(m = RD & hnede & !drevo_vedl, x = list(hnede_q = hnede_q)),
  "RD hnědé uhlí + dřevo"           = list(m = RD & hnede & drevo_vedl, x = list(hnede_q = hnede_q)),
  "RD černé uhlí (citlivost)"       = list(m = RD & cerne, x = list(cerne_q = cerne_q)),
  "BJ plyn"                         = list(m = BD & plyn, x = list(plyn_kwh = zp_kwh)),
  "BJ dálkové teplo (zdroj v ETS2)" = list(m = BD & teplo, x = list(teplo_gj = teplo_gj)))
typove <- bind_rows(lapply(names(typy), function(t) {
  m <- typy[[t]]$m; x <- typy[[t]]$x[[1]]; nm <- names(typy[[t]]$x)
  mm <- m & auto & litry > 0
  tibble(typ = t, domacnosti_tis = sum(w[m]) / 1000, promenna = nm,
         n = sum(m & !is.na(x)), median = wq(x[m], w[m]), p25 = wq(x[m], w[m], .25), p75 = wq(x[m], w[m], .75),
         podil_s_autem_pct = 100 * sum(w[m & auto]) / sum(w[m]),
         phm_l = wq(litry[mm], w[mm]), podil_nafty = sum(nafta_l[mm] * w[mm]) / sum(litry[mm] * w[mm]))
}))
write_csv(typove, file.path(OUT_DIR, "06_energo_typove_mikrodata.csv")); print(typove, width = 200)

# Poměry průměrné spotřeby hnědého uhlí (RD): s dřevem jako vedlejším palivem / bez dřeva vůči všem RD na hnědé uhlí
pomery <- tibble(
  skupina = c("RD hnědé uhlí – všichni", "RD hnědé uhlí + dřevo", "RD hnědé uhlí bez dřeva"),
  prumer_q = c(wmean(hnede_q[RD & hnede], w[RD & hnede]),
               wmean(hnede_q[RD & hnede & drevo_vedl], w[RD & hnede & drevo_vedl]),
               wmean(hnede_q[RD & hnede & !drevo_vedl], w[RD & hnede & !drevo_vedl]))) %>%
  mutate(pomer_k_vsem = prumer_q / prumer_q[1])
write_csv(pomery, file.path(OUT_DIR, "06_pomery_uhli_drevo.csv")); print(pomery)

# Výdaje na dřevo a pelety (Kč/rok 2021, vážený průměr vč. nul = vlastní dřevo) a litry PHM na domácnost s autem
# -> parametry p$BIOMASA_KC_2021 a p$PHM_L_DOMACNOST v 02_parametry.R (jmenovatel % zdražení musí zahrnout VŠECHNA paliva na vytápění)
bio <- f0(d$EPSPOTREBATPKC_05) + f0(d$EPSPOTREBATPKC_06) + f0(d$EPSPOTREBATPKC_07)
skup <- list(`RD plyn` = RD & plyn, `RD hnědé uhlí` = RD & hnede, `RD hnědé uhlí + dřevo` = RD & hnede & drevo_vedl,
             `RD hnědé uhlí bez dřeva` = RD & hnede & !drevo_vedl, `RD černé uhlí (citlivost)` = RD & cerne,
             `BJ plyn` = BD & plyn, `BJ dálkové teplo (zdroj v ETS2)` = BD & teplo)
s_l <- litry > 0
bp <- tibble(typ = names(skup), biomasa_kc_rok_2021 = sapply(skup, function(m) wmean(bio[m], w[m])),
             phm_l_domacnost = wmean(litry[s_l], w[s_l]), podil_nafty = sum((nafta_l * w)[s_l]) / sum((litry * w)[s_l]))
write_csv(bp, file.path(OUT_DIR, "06_typove_biomasa_phm.csv")); print(bp)
