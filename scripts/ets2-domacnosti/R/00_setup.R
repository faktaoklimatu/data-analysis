# 00_setup.R – balíčky, cesty a společné funkce pro dopadovou analýzu ETS2
# Spouštěj z kořene složky ETS2/R (Positron: otevři složku jako workspace), nejlépe přes run_all.R.

pkgs <- c("dplyr", "tidyr", "readr", "readxl")
miss <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(miss)) install.packages(miss)
invisible(lapply(pkgs, library, character.only = TRUE))

# Mikrodata (lokálně, nikdy v repozitáři). Cestu lze změnit proměnnou prostředí ETS2_CSU_DIR.
CSU_DIR    <- path.expand(Sys.getenv("ETS2_CSU_DIR", "~/Documents/ČSÚ"))
ENERGO_ZIP <- file.path(CSU_DIR, "ENERGO 2021.zip")
OUT_DIR    <- Sys.getenv("ETS2_OUT", "output")   # mimo git (.gitignore); citlivostní běhy píší jinam (např. output/c1_bilance)

# Repozitář webu (publikovaný výstup). Skripty sem smějí ukládat jen agregovaná data pro grafy a mapu
# do file.path(WEB_DIR, "_data", "ets2"); mikrodata ani data za jednotlivé domácnosti nikdy.
# ETS2 se dělá ve vlastním worktree (hlavní web-cz bývá na jiné větvi); zápis jen na správné větvi.
WEB_DIR    <- path.expand(Sys.getenv("ETS2_WEB_DIR", "~/GitHub/web-cz-ets2"))
WEB_BRANCH <- "preview-socialni-klimaticka-politika"
web_vetev <- tryCatch(system2("git", c("-C", shQuote(WEB_DIR), "branch", "--show-current"), stdout = TRUE), error = function(e) NA)
if (!identical(web_vetev, WEB_BRANCH))
  stop("WEB_DIR (", WEB_DIR, ") není na větvi ", WEB_BRANCH, " (je na: ", paste(web_vetev, collapse = " "), "). Do webu nic nezapisuji.")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# Načtení mikrodat ENERGO 2021 (ČSÚ, sebraná data s váhami)
# Primárně čte předem rozbalený soubor s čistým názvem ENERGO_2021_data.xlsx (ve složce CSU_DIR).
# ZIP od ČSÚ má názvy souborů v nestandardním kódování -> R hlásí "invalid multibyte string";
# rozbalení ze ZIPu zůstává jen jako záloha.
ENERGO_XLSX <- file.path(CSU_DIR, "ENERGO_2021_data.xlsx")
# ENERGO je volitelné (jen kontroly v 08 a 09); bez něj se kontroly přeskočí.
ENERGO_OK <- file.exists(ENERGO_XLSX) || file.exists(ENERGO_ZIP)
load_energo <- function() {
  f <- ENERGO_XLSX
  if (!file.exists(f)) {
    tmp <- file.path(tempdir(), "energo"); dir.create(tmp, showWarnings = FALSE)
    unzip(ENERGO_ZIP, exdir = tmp, junkpaths = TRUE)
    fs <- list.files(tmp, full.names = TRUE)
    f <- file.path(tempdir(), "energo_data.xlsx")
    file.copy(fs[which.max(file.size(fs))], f, overwrite = TRUE)
  }
  d <- read_excel(f, guess_max = 10000, .name_repair = "minimal")
  names(d) <- iconv(names(d), "UTF-8", "UTF-8", sub = "")
  # textové odpovědi (výrobce kotle apod.) nepotřebujeme; pro jistotu vyčistíme kódování
  d[] <- lapply(d, function(x) if (is.character(x)) iconv(x, "UTF-8", "UTF-8", sub = "") else x)
  d
}

# Vážený kvantil: první hodnota, kde kumulativní podíl vah dosáhne q (NA a nuly vynechány)
wq <- function(x, w, q = 0.5) {
  ok <- !is.na(x) & x > 0 & !is.na(w)
  if (!any(ok)) return(NA_real_)
  x <- x[ok]; w <- w[ok]
  o <- order(x); x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  x[which(cw >= q)[1]]
}
wmean <- function(x, w) { ok <- !is.na(x) & !is.na(w); sum(x[ok] * w[ok]) / sum(w[ok]) }
is1 <- function(v) !is.na(v) & v == 1
pos <- function(v) ifelse(!is.na(v) & v > 0, v, NA_real_)
f0  <- function(v) ifelse(is.na(v), 0, v)

options(width = 160, dplyr.summarise.inform = FALSE)
