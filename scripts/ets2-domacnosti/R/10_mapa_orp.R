# 10_mapa_orp.R – přesné hranice SO ORP pro mapu v blogu (mikroregionální ukazatel energetické chudoby MF ČR)
# Vstup:   ../data/mf/mf_orp_ukazatel_energeticke_chudoby.csv
#          (přepis tabulky A1.1 z tematického reportu MF „Mikroregionální ukazatel energetické chudoby“, 2026)
# Hranice: balík RCzechia, funkce orp_polygony() (zdroj ČÚZK); stahuje data z internetu, proto běží jen s připojením
# Vstup 2: ../data/csu_sldb/SLDB2021_podily_energonositelu_SOORP_v1.xlsx, list RD
#          a list BJ (SLDB 2021, podíly obydlených bytů v rodinných a bytových domech podle paliva za SO ORP)
# Výstup:  OUT_DIR/orp_energeticka_chudoba.geojson – zjednodušené hranice + údaje pro okénko v mapě
#          WEB_DIR/_data/ets2/orp_mapa.json – totéž pro web (GeoJSON, přípona .json kvůli Jekyll _data)
#          WEB_DIR/_data/ets2/kraje_mapa.json – hranice krajů pro mapu
#          (stejné názvy vlastností jako přibližná verze v data/mf/orp_energeticka_chudoba_priblizne.geojson)
# Pozor:   hodnoty tabulky A1.1 se mírně liší od textu reportu (Broumov 16,9 % vs. 19,6 %, medián 11,5 % vs. 13,5 %).
#          Mapa proto barví kategorie podle kvartilů (pořadí) jako report MF. Ověřit s MF.

if (!exists("WEB_DIR")) source("00_setup.R")
for (b in c("RCzechia", "sf", "dplyr", "readr", "readxl")) if (!requireNamespace(b, quietly = TRUE)) install.packages(b)
library(sf); library(dplyr); library(readr); library(readxl)

d   <- read_csv("../data/mf/mf_orp_ukazatel_energeticke_chudoby.csv", show_col_types = FALSE)
orp <- RCzechia::orp_polygony()

norm <- function(x) tolower(gsub("[[:space:]]*-[[:space:]]*", "-", gsub("[[:space:]]+", " ", trimws(x))))
orp$klic <- norm(orp$NAZ_ORP)
d$klic   <- norm(d$so_orp)
d$klic[d$klic == "praha"] <- orp$klic[grepl("praha", orp$klic)][1]

m <- orp |> inner_join(d, by = "klic")
chybi_v_datech <- setdiff(orp$klic, d$klic)
chybi_v_mape   <- setdiff(d$klic, orp$klic)
cat("ORP v mapě:", nrow(orp), " | v datech:", nrow(d), " | spárováno:", nrow(m), "\n")
if (length(chybi_v_datech) || length(chybi_v_mape)) {
  cat("V mapě bez dat:", paste(chybi_v_datech, collapse = "; "), "\n")
  cat("V datech bez mapy:", paste(chybi_v_mape, collapse = "; "), "\n")
  stop("Doplň párování názvů ORP (viz výše).")
}

# SLDB 2021: byty v rodinných domech podle paliva (veřejné agregáty ČSÚ za SO ORP)
sldb <- read_excel("../data/csu_sldb/SLDB2021_podily_energonositelu_SOORP_v1.xlsx", sheet = "RD") |>
  transmute(klic       = norm(`SO ORP`),
            rd_byty    = `Obydlené byty`,
            rd_uhli    = round(100 * Uhlí, 1),
            rd_plyn    = round(100 * Plyn, 1),
            rd_drevo   = round(100 * `Dřevo, pelety`, 1),
            rd_nezj    = round(100 * Nezjištěno, 1),
            rd_czt     = round(100 * `CZT (dálkové)`, 1))
sldb_bj <- read_excel("../data/csu_sldb/SLDB2021_podily_energonositelu_SOORP_v1.xlsx", sheet = "BJ") |>
  transmute(klic    = norm(`SO ORP`),
            bj_byty = `Obydlené byty`,
            bj_plyn = round(100 * Plyn, 1),
            bj_czt  = round(100 * `CZT (dálkové)`, 1))
sldb <- sldb |> left_join(sldb_bj, by = "klic")
sldb$klic[sldb$klic == "praha"] <- orp$klic[grepl("praha", orp$klic)][1]
chybi_sldb <- setdiff(m$klic, sldb$klic)
if (length(chybi_sldb)) stop("SLDB: chybí párování ORP: ", paste(chybi_sldb, collapse = "; "))
m <- m |> left_join(sldb, by = "klic")
cat("SLDB 2021, byty v RD celkem:", sum(m$rd_byty),
    "| na uhlí:", round(sum(m$rd_byty * m$rd_uhli / 100)),
    "| na plyn:", round(sum(m$rd_byty * m$rd_plyn / 100)), "(kontrola proti archetypům SILC v 09)\n")
cat("SLDB 2021, byty v BD celkem:", sum(m$bj_byty), "| na plyn (vč. domovních kotelen):", round(sum(m$bj_byty * m$bj_plyn / 100)), "\n")

# Teplo ze zdrojů v ETS2 podle SO ORP: lokality ERÚ (do 20 MWt, uhlí + plyn aspoň 50 %) napárované podle názvu
# na obce v rámci kraje (RCzechia::obce_body). Podíl tepla ze zdrojů v ETS2 na všem dálkovém teple v SO ORP
# x byty na dálkovém teple (SLDB 2021) = odhad bytů na teple ze zdroje v ETS2. Lokalita ERÚ je cenová lokalita
# (může zahrnovat i nebytové odběratele), proto jde o přiblížení.
ERU_KRAJ_NUTS <- c(A = "CZ010", S = "CZ020", C = "CZ031", P = "CZ032", K = "CZ041", U = "CZ042", L = "CZ051",
                   H = "CZ052", E = "CZ053", J = "CZ063", B = "CZ064", M = "CZ071", Z = "CZ072", T = "CZ080")
# Pozor: vykon_mwt v ERÚ je výkon vlastních zdrojů držitele licence v lokalitě, ne zdroje, odkud teplo je.
# Lokalita, která dodá víc tepla, než její zdroje zvládnou (výkon x 3 000 h x 3,6 GJ/MWh), teplo nakupuje
# z velkého zdroje (typicky ETS1, např. Havířov z Dětmarovic) a za zdroj v ETS2 se nepočítá.
eru <- read_csv("../data/eru/eru_teplo_2024.csv", show_col_types = FALSE) |>
  filter(kraj %in% names(ERU_KRAJ_NUTS)) |>
  mutate(gj = rowSums(across(ends_with("_mnozstvi_gj")), na.rm = TRUE),
         ets2 = !is.na(vykon_mwt) & vykon_mwt <= 20 & coalesce(uhli_pct, 0) + coalesce(plyn_pct, 0) >= 50 &
                gj <= vykon_mwt * 3.6 * 3000,
         nuts = ERU_KRAJ_NUTS[kraj],
         # B5 (25. 11. 2026): spojovník bez mezer patří k názvu obce (Frýdek-Místek, Brandýs nad Labem-Stará Boleslav);
         # oddělovač části lokality je pomlčka/spojovník s mezerami, závorka nebo čárka
         klic_obec = tolower(trimws(sub("\\s+[-\u2013].*$|[(,].*$", "", lokalita))),
         klic_obec_kratky = tolower(trimws(sub("[-\u2013(,].*$", "", lokalita))),   # záloha: dřívější pravidlo
         klic_obec = ifelse(kraj == "A", "praha", klic_obec),            # pražské lokality nesou jméno čtvrti/ulice
         klic_obec = sub(" u .*$", "", klic_obec),                        # „Meziboří u Litvínova“
         klic_obec = sub(" [ivx]+$", "", klic_obec),                      # „Přerov I“, „Sezimovo Ústí II“ (B5)
         klic_obec = sub(" a .*$", "", klic_obec),                        # „Karviná a Havířov“ -> první obec (B5)
         klic_obec = recode(klic_obec, "vlaším" = "vlašim"))
obce <- sf::st_drop_geometry(RCzechia::obce_body()) |>
  transmute(klic_obec = tolower(NAZ_OBEC), nuts = KOD_CZNUTS3, KOD_ORP) |> distinct(klic_obec, nuts, .keep_all = TRUE)
eru <- eru |> left_join(obce, by = c("klic_obec", "nuts"))
# záloha pro lokality, kde plný název obec nenašel (např. „Most-Velebudice“ = část obce Most)
nenaparovane <- is.na(eru$KOD_ORP)
eru$KOD_ORP[nenaparovane] <- obce$KOD_ORP[match(paste(ifelse(eru$kraj[nenaparovane] == "A", "praha", eru$klic_obec_kratky[nenaparovane]), eru$nuts[nenaparovane]),
                                                 paste(obce$klic_obec, obce$nuts))]
cat("B5: napárováno plným názvem", sum(!nenaparovane), "| zálohou", sum(nenaparovane & !is.na(eru$KOD_ORP)), "| zbývá", sum(is.na(eru$KOD_ORP)), "lokalit\n")
print(eru |> filter(is.na(KOD_ORP)) |> arrange(desc(gj)) |> select(kraj, lokalita, gj, ets2) |> head(15))
cat("ERÚ: lokality napárované na obec:", round(100 * sum(eru$gj[!is.na(eru$KOD_ORP)]) / sum(eru$gj)), "% tepla celkem,",
    round(100 * sum(eru$gj[!is.na(eru$KOD_ORP) & eru$ets2]) / sum(eru$gj[eru$ets2])), "% tepla ze zdrojů v ETS2\n")
eru_orp <- eru |> filter(!is.na(KOD_ORP)) |> group_by(KOD_ORP) |>
  summarise(teplo_ets2_gj = sum(gj[ets2]), teplo_gj = sum(gj), .groups = "drop") |>
  mutate(podil_tepla_ets2 = teplo_ets2_gj / teplo_gj)
m <- m |> left_join(eru_orp, by = "KOD_ORP") |>
  mutate(byty_czt = bj_byty * bj_czt / 100 + rd_byty * rd_czt / 100,
         byty_teplo_ets2 = byty_czt * coalesce(podil_tepla_ets2, 0),
         teplo_ets2 = round(100 * byty_teplo_ets2 / (bj_byty + rd_byty), 1),
         teplo_ets2_byty = round(byty_teplo_ets2, -1),
         podil_tepla_ets2 = round(100 * podil_tepla_ets2, 1))
cat("Odhad bytů na teple ze zdroje v ETS2 (SLDB x ERÚ):", round(sum(m$byty_teplo_ets2) / 1000), "tis.",
    "(kontrola: dashboard tepláren FoK 380 tis.)\n")

m <- m |>
  transmute(orp    = so_orp,
            kraj   = NAZ_CZNUTS3,
            podil  = podil_vydaju_na_prijmech_pct,
            vydaje = vydaje_vytapeni_kc_rd_rok,
            cena   = cena_energie_vytapeni_kc_gj,
            prijem = disp_prijem_kc_obyv_rok,
            teplo  = cena_dodaneho_tepla_kc_gj,
            rd     = podil_obydli_v_rd_pct,
            rd_eg  = podil_rd_trida_e_g_pct,
            bd_eg  = podil_bd_trida_e_g_pct,
            rd_byty, rd_uhli, rd_plyn, rd_drevo, rd_nezj, bj_byty, bj_plyn, bj_czt, rd_czt, teplo_ets2, teplo_ets2_byty, podil_tepla_ets2) |>
  st_transform(5514) |>
  st_simplify(dTolerance = 300, preserveTopology = TRUE) |>
  st_collection_extract("POLYGON") |>   # zjednodušení dělá u 7 ORP GeometryCollection se zbytkovými čarami
  st_transform(4326)

out <- file.path(OUT_DIR, "orp_energeticka_chudoba.geojson")
if (file.exists(out)) file.remove(out)
st_write(m, out, driver = "GeoJSON", layer_options = "COORDINATE_PRECISION=3", quiet = TRUE)
cat("Uloženo:", out, "(", round(file.size(out) / 1024), "kB )\n")

# Hranice krajů pro mapu: sloučené SO ORP (před zjednodušením), zjednodušené stejně jako ORP
kraje <- orp |> group_by(KOD_KRAJ) |> summarise(.groups = "drop") |>
  st_transform(5514) |> st_simplify(dTolerance = 300, preserveTopology = TRUE) |>
  st_collection_extract("POLYGON") |> st_transform(4326)
kraje_out <- file.path(WEB_DIR, "_data", "ets2", "kraje_mapa.json")
dir.create(dirname(kraje_out), showWarnings = FALSE, recursive = TRUE)
if (file.exists(kraje_out)) file.remove(kraje_out)
st_write(kraje, kraje_out, driver = "GeoJSON", layer_options = "COORDINATE_PRECISION=3", quiet = TRUE)
cat("Uloženo pro web:", kraje_out, "(", nrow(kraje), "krajů )\n")

# Kopie pro web: jen agregáty za SO ORP (MF report + SLDB 2021), žádná mikrodata
web_out <- file.path(WEB_DIR, "_data", "ets2", "orp_mapa.json")
dir.create(dirname(web_out), showWarnings = FALSE, recursive = TRUE)
file.copy(out, web_out, overwrite = TRUE)
cat("Uloženo pro web:", web_out, "\n")
