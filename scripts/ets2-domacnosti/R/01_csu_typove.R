# 01_csu_typove.R – spotřeby typových domácností z PUBLIKOVANÝCH tabulek ČSÚ ENERGO 2021
# https://csu.gov.cz/produkty/spotreba-paliv-a-energii-v-domacnostech-energo-2021 (ZIP 15018922_data.zip)
# Tabulky: 2-10 (průměrná spotřeba na byt užívající palivo), 3-1.1 (domácnosti podle hlavního paliva),
#          1-3.1 (konečná spotřeba domácností podle účelu, 2020), 2-11 (automobily)
# Výstup: output/01_typove_spotreby_csu.csv, output/01_csu_mezivypocty.csv
source("00_setup.R"); source("02_parametry.R")
CSU_TAB <- "../data/csu_energo_2021"       # rozbalený 15018922_data.zip
if (!dir.exists(CSU_TAB)) { dir.create(CSU_TAB, recursive = TRUE); unzip("../15018922_data.zip", exdir = CSU_TAB) }

rd   <- function(f) suppressMessages(read_excel(file.path(CSU_TAB, f), col_names = FALSE, .name_repair = "minimal"))
num  <- function(v) suppressWarnings(as.numeric(gsub("[()[:space:] ]", "", as.character(v))))
lab  <- function(t) trimws(as.character(t[[1]]))

# Tab. 2-10: sloupce 2021 = 3 (celkem), 8 (RD), 13 (BD); počet bytů užívajících palivo je řádek nad názvem paliva
t210 <- rd("150189220210.xlsx"); l210 <- lab(t210)
t210_val <- function(palivo, jednotka, col) {
  i <- which(startsWith(l210, palivo))[1]
  j <- i + which(l210[(i + 1):(i + 5)] == jednotka)[1]
  c(hodnota = num(t210[[col]][j]), n = num(t210[[col]][i - 1]))
}
# Tab. 3-1.1: 2021 vytápění = sl. 3, vaření = sl. 9; bloky "Byty celkem", "byty v RD", "byty v BD"
t31 <- rd("150189220311.xlsx"); l31 <- lab(t31)
t31_val <- function(blok, palivo, col) {
  i <- which(l31 == blok)[1]
  j <- i + which(l31[(i + 1):(i + 11)] == palivo)[1]
  num(t31[[col]][j])
}
# Tab. 1-3.1: blok 2020 (řádek se 2020 ve 3. sloupci), zemní plyn: sl. 2 celkem, 3 vytápění, 5 vaření (TJ)
t131 <- rd("150189220131.xlsx"); l131 <- lab(t131)
i2020 <- which(num(t131[[3]]) == 2020)[1]
jz <- i2020 + which(l131[i2020:(i2020 + 14)] == "zemní plyn")[1] - 1
plyn_celkem_TJ <- num(t131[[2]][jz]); plyn_vytapeni_TJ <- num(t131[[3]][jz]); plyn_vareni_TJ <- num(t131[[5]][jz])
# Tab. 2-11: automobily (sloupec 4 = 2021 počet/hodnota, sloupec 6 = 2021 %)
t211 <- rd("150189220211.xlsx"); l211 <- lab(t211); u211 <- trimws(as.character(t211[[2]]))
km      <- num(t211[[4]][which(l211 == "v ČR" & u211 == "km")[1]])
l100_n  <- num(t211[[4]][which(l211 == "nafta" & startsWith(u211, "litry"))[1]])
l100_b  <- num(t211[[4]][which(l211 == "benzin" & startsWith(u211, "litry"))[1]])
n_n     <- num(t211[[4]][which(l211 == "nafta" & u211 == "počet")[1]])
n_b     <- num(t211[[4]][which(l211 == "benzin" & u211 == "počet")[1]])
podil_auto <- num(t211[[6]][which(l211 == "využívá automobil")[1]])
podil_nafty <- n_n / (n_n + n_b)
phm_l <- km * (podil_nafty * l100_n + (1 - podil_nafty) * l100_b) / 100

# Plyn: průměr všech uživatelů -> domácnosti topící plynem
# (uživatelé, kteří netopí plynem, ho používají na vaření; spotřeba na vaření z tab. 1-3.1 / počet vařících domácností)
vareni_dom <- t31_val("Byty celkem", "zemní plyn", 9)
m3_vareni  <- plyn_vareni_TJ * 1e6 / vareni_dom / p$GAS_NCV_MJ_M3
plyn_topi <- function(col, blok) {
  u <- t210_val("zemní plyn", "m3 / byt", col); n_top <- t31_val(blok, "zemní plyn", 3)
  c(m3_uzivatele = u[["hodnota"]], n_uzivatele = u[["n"]], n_topi = n_top,
    m3_topi = (u[["hodnota"]] * u[["n"]] - (u[["n"]] - n_top) * m3_vareni) / n_top)
}
RDp <- plyn_topi(8, "byty v RD"); BDp <- plyn_topi(13, "byty v BD")
hnede_q <- t210_val("hnědé uhlí", "q / byt", 8)[["hodnota"]]
cerne_q <- t210_val("černé uhlí", "q / byt", 8)[["hodnota"]]
teplo_gj <- t210_val("nakupované teplo", "GJ / byt", 13)[["hodnota"]]

typy <- tibble(
  typ = c("RD plyn", "RD hnědé uhlí", "RD hnědé uhlí + dřevo", "RD hnědé uhlí bez dřeva",
          "RD černé uhlí (citlivost)", "BJ plyn", "BJ dálkové teplo (zdroj v ETS2)"),
  palivo = c("plyn_m3", "hnede_q", "hnede_q", "hnede_q", "cerne_q", "plyn_m3", "teplo_gj"),
  spotreba = c(RDp[["m3_topi"]], hnede_q, hnede_q * p$POMER_UHLI_S_DREVEM, hnede_q * p$POMER_UHLI_BEZ_DREVA,
               cerne_q, BDp[["m3_topi"]], teplo_gj),
  phm_l_auto = phm_l, podil_nafty = podil_nafty, podil_s_autem_pct = podil_auto)
mezi <- tibble(ukazatel = c("plyn – m3 na domácnost vařící na plynu",
  "RD plyn – průměr všech uživatelů (tab. 2-10)", "RD – byty užívající plyn", "RD – byty topící plynem (tab. 3-1)",
  "BD plyn – průměr všech uživatelů (tab. 2-10)", "BD – byty užívající plyn", "BD – byty topící plynem (tab. 3-1)",
  "plyn celkem domácnosti 2020, TJ (tab. 1-3.1)", "plyn na vytápění 2020, TJ", "auto – km v ČR (tab. 2-11)",
  "auto – podíl nafty", "auto – litry/rok"),
  hodnota = c(m3_vareni, RDp[["m3_uzivatele"]], RDp[["n_uzivatele"]], RDp[["n_topi"]], BDp[["m3_uzivatele"]],
              BDp[["n_uzivatele"]], BDp[["n_topi"]], plyn_celkem_TJ, plyn_vytapeni_TJ, km, podil_nafty, phm_l))
write_csv(typy, file.path(OUT_DIR, "01_typove_spotreby_csu.csv")); write_csv(mezi, file.path(OUT_DIR, "01_csu_mezivypocty.csv"))
print(typy, width = 200); print(mezi, n = 20)
