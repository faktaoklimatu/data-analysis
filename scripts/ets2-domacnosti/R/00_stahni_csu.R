# 00_stahni_csu.R – stáhne ceny energií a paliv od ČSÚ jedním spuštěním (Positron: Source, nebo dvojklik na stahni_ceny_csu.command)
# Ukládá do CENY_DIR (mimo sdílený disk). Nic se nepřepisuje: každé stažení má datum v názvu.
#  1) Průměrné spotřebitelské ceny pohonných hmot – týdenní šetření (benzín, nafta, LPG)
#     NKOD: https://data.gov.cz/dataset?iri=https%3A%2F%2Fdata.gov.cz%2Fzdroj%2Fdatov%C3%A9-sady%2F00025593%2F29d4dbe6d8d5e4bdab7cfea0f4593971
#  2) DataStat API ČSÚ (https://csu.gov.cz/zakladni-informace-pro-pouziti-api-datastatu):
#     najde v katalogu sady a předdefinované výběry k cenám energií a indexům spotřebitelských cen
#     a stáhne je jako CSV. Seznam nalezeného ukládá do _katalog_nalezeno.csv, ať je vidět, co se stáhlo.

pkgs <- c("jsonlite")
miss <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(miss)) install.packages(miss)
library(jsonlite)

CENY_DIR <- file.path(path.expand(Sys.getenv("ETS2_CSU_DIR", "~/Documents/ČSÚ")), "ceny")
dir.create(CENY_DIR, showWarnings = FALSE, recursive = TRUE)
dnes <- format(Sys.Date(), "%Y-%m-%d")
API  <- "https://data.csu.gov.cz/api"
options(timeout = 300)

stahni <- function(url, soubor) {
  cil <- file.path(CENY_DIR, soubor)
  ok <- tryCatch({ download.file(url, cil, mode = "wb", quiet = TRUE); TRUE },
                 error = function(e) { message("  CHYBA: ", conditionMessage(e)); FALSE })
  if (ok) message("  OK  ", soubor, " (", round(file.size(cil) / 1024), " kB)")
  ok
}

# ---------- 1) pohonné hmoty ----------
message("1) Ceny pohonných hmot (týdenní)")
stahni("https://vdb.czso.cz/pll/eweb/cenyphm.data", paste0("ceny_phm_tydenni_", dnes, ".csv"))
stahni("https://vdb.czso.cz/pll/eweb/cenyphm.metadata", paste0("ceny_phm_tydenni_metadata_", dnes, ".json"))

# ---------- 2) DataStat: hledání v katalogu ----------
message("2) DataStat – katalog sad")
kat <- tryCatch(fromJSON(paste0(API, "/katalog/v1/sady"), flatten = TRUE), error = function(e) NULL)
if (is.null(kat)) stop("Katalog DataStatu se nepodařilo načíst – zkontroluj připojení nebo ", API)
if (!is.data.frame(kat)) kat <- as.data.frame(kat[[which(sapply(kat, is.data.frame))[1]]])
bez_seznamu <- function(df) df[, !sapply(df, is.list), drop = FALSE]   # JSON pole (např. úrovně období) do CSV nejdou
write.csv(bez_seznamu(kat), file.path(CENY_DIR, paste0("_katalog_sady_", dnes, ".csv")), row.names = FALSE)

txt <- function(df) apply(df[, sapply(df, is.character), drop = FALSE], 1, paste, collapse = " | ")
kod_sloupec <- function(df) {                         # sloupec s kódem sady/výběru
  k <- grep("^kod$|kod$|^code$|^id$", names(df), ignore.case = TRUE, value = TRUE)
  if (!length(k)) stop("Nenašel jsem sloupec s kódem; sloupce: ", paste(names(df), collapse = ", "))
  k[1]
}
KLIC_SADY <- "spotřebitelských cen|ceny elektři|cen elektři|zemního plynu|ceny plynu|cen energi|tepeln|pohonných hmot"
nalez <- kat[grepl(KLIC_SADY, txt(kat), ignore.case = TRUE), , drop = FALSE]
ks <- kod_sloupec(kat)
message("  nalezeno sad: ", nrow(nalez), " (", paste(nalez[[ks]], collapse = ", "), ")")

# ---------- 3) výběry nalezených sad -> CSV ----------
KLIC_VYBERU <- "elektři|plyn|tuhá paliva|paliv|tepeln|teplo|energi|bydlen|04\\.5|pohonn|úhrn|celkem"
prehled <- list()
for (s in nalez[[ks]]) {
  vy <- tryCatch(fromJSON(sprintf("%s/katalog/v1/sady/%s/vybery", API, s), flatten = TRUE), error = function(e) NULL)
  if (is.null(vy) || !NROW(vy)) next
  if (!is.data.frame(vy)) vy <- as.data.frame(vy[[which(sapply(vy, is.data.frame))[1]]])
  kv <- kod_sloupec(vy)
  vy$sada <- s
  vy$vybrano <- grepl(KLIC_VYBERU, txt(vy), ignore.case = TRUE)
  prehled[[s]] <- vy
  for (v in vy[[kv]][vy$vybrano]) {
    message(" sada ", s, " výběr ", v)
    stahni(sprintf("%s/dotaz/v1/data/vybery/%s?format=CSV", API, v), sprintf("%s_%s_%s.csv", s, v, dnes))
  }
}
if (length(prehled)) {
  prehled <- lapply(prehled, bez_seznamu)
  spolecne <- Reduce(intersect, lapply(prehled, names))
  p <- do.call(rbind, lapply(prehled, function(x) x[, spolecne, drop = FALSE]))
  write.csv(p, file.path(CENY_DIR, paste0("_katalog_nalezeno_", dnes, ".csv")), row.names = FALSE)
}
# ---------- 4) výběry stahované vždy (kódy ověřené v katalogu 16. 10. 2026) ----------
#  CEN0101ET03 indexy spotřebitelských cen podle COICOP 2018, měsíční (tuhá paliva 04.5.4, teplo 04.5.5 aj.)
#  CEN0101IT01 ceny plynu pro domácnosti, CEN0101KT01 ceny elektřiny pro domácnosti (pololetní, Kč/MWh)
#  CEN0101OT01 průměrné ceny pohonných hmot, měsíční
message("4) Pevně dané výběry")
for (v in c("CEN0101ET03", "CEN0101IT01", "CEN0101KT01", "CEN0101OT01")) {
  f <- sprintf("%s_%s.csv", v, dnes)
  if (!file.exists(file.path(CENY_DIR, f))) stahni(sprintf("%s/dotaz/v1/data/vybery/%s?format=CSV", API, v), f)
}
message("\nHotovo. Soubory jsou v ", CENY_DIR, ". Pošli Claudovi, ať je zpracuje (08_ceny_csu.R).")
