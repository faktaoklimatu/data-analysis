# 08a_sru_diagnostika.R – příprava na 08_sru_archetypy.R (nic o ETS2 zatím nepočítá)
#
# Ukáže:
#   1) jak jsou v SRÚ 2023 kódované proměnné o vytápění (VYTAPENI, ZDROJ_ENER a podobné)
#      a zda je má i SRÚ 2022,
#   2) kolik domácností (vzorek i váženě) padne do kandidátních buněk archetypů typ domu × zdroj,
#   3) zda deníky SRÚ obsahují i množství paliv, nebo jen Kč (COICOP 04.5 a 07.2.2),
#   4) kolik deníků roku 2023 se spáruje s příjmem ze SILC 2024 (příjem za rok 2023),
#   5) srovnání příjmů ENERGO 2021 (vlastní odpověď domácnosti, z 04_mikrosimulace.R)
#      se SILC 2022 (příjem za rok 2021) – jak moc můžeme věřit příjmům z ENERGO.
#
# Data (ČSÚ):
#   - Statistika rodinných účtů 2022, 2023 – mikrodata (ru2023e.csv domácnosti, ru2023d.csv deníky)
#     https://csu.gov.cz/rodinne_ucty
#   - EU-SILC 2022 a 2024, verze pro MF (Hextzp22.csv, Hextzp24.csv) https://csu.gov.cz/zivotni-podminky
#   - ENERGO 2021 – výstup output/04_mikro_domacnosti.csv https://csu.gov.cz/energo-2021
# Párování SRÚ–SILC převzato z 2026 Dekarbonizace domácností/R/07_sru_vice_let.R
#   (hh = DOMACID %/% 100, rok deníku = 2000 + DOMACID %% 100; SILC roku X+1 = příjem za rok X).
#
# Spuštění: z ETS2/R, po 04_mikrosimulace.R. Výstup: output/08a_sru_diagnostika.txt

source("00_setup.R")

SRU_KOREN <- file.path(CSU_DIR, "SRU")
SILC_KDE  <- c(file.path(CSU_DIR, "MF_SILC 2015-2024"),
               file.path(CSU_DIR, "MF_SILC 2015-2024.zip"))
INDEX_PRIJMU_2021_2028 <- 1.392   # stejný jako v METODIKA.md (valorizace příjmů ENERGO 2021 -> 2028)

num <- function(x) suppressWarnings(as.numeric(gsub(",", ".", x)))
cti <- function(f) readr::read_delim(f, delim = ";", locale = readr::locale(encoding = "windows-1250"),
                                     col_types = readr::cols(.default = "c"), show_col_types = FALSE)
wq0 <- function(x, w, q = 0.5) {
  ok <- !is.na(x) & !is.na(w); x <- x[ok]; w <- w[ok]
  if (!length(x)) return(NA_real_)
  o <- order(x); x <- x[o]; cw <- cumsum(w[o]) / sum(w)
  sapply(q, function(qq) x[which(cw >= qq)[1]])
}
najdi_sru <- function(rok, typ) {
  vzor <- paste0("^ru", rok, typ, "\\.csv$")
  f <- list.files(file.path(SRU_KOREN, rok), pattern = vzor, ignore.case = TRUE, full.names = TRUE)
  if (!length(f)) f <- list.files(SRU_KOREN, pattern = vzor, ignore.case = TRUE, full.names = TRUE, recursive = TRUE)
  if (!length(f)) return(NULL)
  f[1]
}
nadpis <- function(t) cat("\n\n==== ", t, " ====\n", sep = "")
tabul <- function(df, sl) df |>
  group_by(across(all_of(sl))) |>
  summarise(n_vzorek = n(), domacnosti_tis = round(sum(w, na.rm = TRUE) / 1000, 1), .groups = "drop")

# SILC: složka (CSV nebo vnořené zipy) nebo jeden velký zip – podle toho, co existuje
cti_silc_h <- function(rok) {
  yy <- sprintf("%02d", rok %% 100); vzor_csv <- paste0("^Hextzp", yy, "\\.csv$")
  tmp <- file.path(tempdir(), paste0("silc", yy)); dir.create(tmp, showWarnings = FALSE)
  for (k in SILC_KDE[file.exists(SILC_KDE)]) {
    if (dir.exists(k)) {
      f <- list.files(k, pattern = vzor_csv, ignore.case = TRUE, full.names = TRUE, recursive = TRUE)
      if (length(f)) return(cti(f[1]))
      z <- list.files(k, pattern = paste0("20", yy, ".*\\.zip$"), ignore.case = TRUE, full.names = TRUE, recursive = TRUE)
      if (length(z)) {
        csv <- grep(vzor_csv, unzip(z[1], list = TRUE)$Name, ignore.case = TRUE, value = TRUE)
        if (length(csv)) { unzip(z[1], files = csv[1], exdir = tmp); return(cti(file.path(tmp, csv[1]))) }
      }
    } else {
      inner <- grep(paste0("20", yy, "\\.zip$"), unzip(k, list = TRUE)$Name, ignore.case = TRUE, value = TRUE)
      if (length(inner)) {
        unzip(k, files = inner[1], exdir = tmp)
        csv <- grep(vzor_csv, unzip(file.path(tmp, inner[1]), list = TRUE)$Name, ignore.case = TRUE, value = TRUE)
        if (length(csv)) { unzip(file.path(tmp, inner[1]), files = csv[1], exdir = tmp); return(cti(file.path(tmp, csv[1]))) }
      }
    }
  }
  NULL
}

F <- file.path(OUT_DIR, "08a_sru_diagnostika.txt")
sink(F, split = TRUE)
cat("08a – diagnostika SRÚ pro archetypy | vytvořeno", format(Sys.time()), "\n")

# ---------- 1) Proměnné o vytápění v SRÚ ----------
f23 <- najdi_sru(2023, "e"); if (is.null(f23)) { sink(); stop("Nenašel jsem ru2023e.csv v ", SRU_KOREN) }
e <- cti(f23) |>
  mutate(w = num(PKOEFP), DOMACID = num(DOMACID),
         hh = DOMACID %/% 100, rok_deniku = 2000 + DOMACID %% 100,
         typ = case_when(num(DUM) %in% 1:2 ~ "RD", num(DUM) %in% 3:4 ~ "BD", TRUE ~ "jiný"))

nadpis("1a) Soubor ru2023e: všechny proměnné")
print(names(e))
kandidati <- grep("VYTAP|ZDROJ|ENER|PALIV|TOPEN|OHREV|TEPL", names(e), value = TRUE, ignore.case = TRUE)
nadpis("1b) Proměnné, které vypadají jako vytápění / zdroj energie")
print(kandidati)
nadpis("1c) Deníky v souboru 2023 podle roku deníku (domácnost bývá ve vzorku 2×)")
print(tabul(e, "rok_deniku"))

for (v in kandidati) {
  nadpis(paste0("1d) ", v, " × typ domu (jen deníky roku 2023 = unikátní domácnosti)"))
  print(tabul(filter(e, rok_deniku == 2023), c("typ", v)), n = Inf)
}

f22 <- najdi_sru(2022, "e")
nadpis("1e) Má ru2022e stejné proměnné o vytápění?")
if (is.null(f22)) cat("Soubor ru2022e.csv nenalezen.\n") else {
  n22 <- names(cti(f22)); cat("Ve 2022 chybí:", setdiff(kandidati, n22), "\n")
  cat("Ve 2022 navíc (vytápění/energie):", setdiff(grep("VYTAP|ZDROJ|ENER|PALIV|TOPEN", n22, value = TRUE, ignore.case = TRUE), kandidati), "\n")
}

# ---------- 2) Kandidátní archetypy: křížení VYTAPENI × ZDROJ_ENER × typ ----------
if (all(c("VYTAPENI", "ZDROJ_ENER") %in% names(e))) {
  nadpis("2) VYTAPENI × ZDROJ_ENER × typ domu (deníky 2023) – podle toho namapuji archetypy")
  print(tabul(filter(e, rok_deniku == 2023), c("typ", "VYTAPENI", "ZDROJ_ENER")), n = Inf)
} else cat("\n(2) VYTAPENI nebo ZDROJ_ENER v souboru není – mapování archetypů upravím podle 1b.\n")

# ---------- 3) Deníky: Kč i množství? ----------
fd <- najdi_sru(2023, "d")
d <- cti(fd) |> rename(COICOP = any_of(c("COOICOP", "COICOP"))) |> mutate(COICOP = num(COICOP))
nadpis("3a) Soubor ru2023d: proměnné")
print(names(d))
mnoz <- grep("MNOZ|MN_|KG|LITR|KWH|GJ|JEDN", names(d), value = TRUE, ignore.case = TRUE)
cat("Sloupce, které by mohly být množství:", if (length(mnoz)) mnoz else "žádné", "\n")
nadpis("3b) Položky COICOP 04.5 (energie) a 07.2.2 (PHM): počet záznamů a vyplněnost množství")
d_en <- d |> filter(COICOP %/% 100 == 45 | COICOP %/% 10 == 722)
print(d_en |> group_by(COICOP) |>
        summarise(zaznamu = n(), domacnosti = n_distinct(DOMACID),
                  across(all_of(mnoz), ~ sum(!is.na(num(.x)) & num(.x) > 0), .names = "vyplneno_{.col}"),
                  .groups = "drop"), n = Inf)

# ---------- 4) Párování na SILC 2024 (příjem za rok 2023) ----------
nadpis("4) Párování deníků 2023 na SILC 2024")
s24 <- cti_silc_h(2024)
if (is.null(s24)) cat("SILC 2024 (Hextzp24.csv) nenalezen.\n") else {
  s24 <- s24 |> transmute(hh = num(DOMAC_ID), prijem_silc = num(CP_PRIJ))
  e23 <- filter(e, rok_deniku == 2023) |> left_join(s24, by = "hh")
  cat("Deníků 2023:", nrow(e23), "| se SILC příjmem > 0:", sum(e23$prijem_silc > 0, na.rm = TRUE),
      sprintf("(%.1f %%)", 100 * mean(e23$prijem_silc > 0, na.rm = FALSE) ), "\n")
  if (all(c("VYTAPENI", "ZDROJ_ENER") %in% names(e)))
    print(e23 |> group_by(typ, VYTAPENI, ZDROJ_ENER) |>
            summarise(n = n(), se_silc = sum(prijem_silc > 0, na.rm = TRUE), .groups = "drop"), n = Inf)
}

# ---------- 5) Příjmy ENERGO 2021 vs. SILC 2022 (příjem za rok 2021) ----------
nadpis("5) Příjmy: ENERGO 2021 (vlastní odpověď) vs. SILC 2022 (příjem 2021), Kč/měsíc na domácnost, nominálně 2021")
m <- readr::read_csv(file.path(OUT_DIR, "04_mikro_domacnosti.csv"), show_col_types = FALSE)
cat("Sloupce ENERGO s příjmem:", grep("prijem|decil", names(m), value = TRUE, ignore.case = TRUE), "\n")
cat(sprintf("Domácnosti ENERGO bez příjmu: %.1f %% váženě\n", 100 * sum(m$w[is.na(m$prijem_rok)]) / sum(m$w)))
q <- c(.1, .25, .5, .75, .9)
en <- wq0(m$prijem_rok / INDEX_PRIJMU_2021_2028 / 12, m$w, q)

s22 <- cti_silc_h(2022)
if (is.null(s22)) cat("SILC 2022 (Hextzp22.csv) nenalezen.\n") else {
  vaha <- grep("^KOEF|VAHA|DB090|HX090|PKOEF", names(s22), value = TRUE, ignore.case = TRUE)[1]
  cat("Váha SILC:", if (is.na(vaha)) "nenalezena – POZOR, nevážené" else vaha, "\n")
  ws <- if (is.na(vaha)) rep(1, nrow(s22)) else num(s22[[vaha]])
  si <- wq0(num(s22$CP_PRIJ) / 12, ws, q)
  print(tibble(kvantil = paste0("P", q * 100), ENERGO_2021 = round(en), SILC_2022 = round(si),
               pomer_ENERGO_k_SILC = round(en / si, 2)))
  cat("Pozn.: ověř v číselníku SILC, že CP_PRIJ je roční čistý peněžní příjem domácnosti.\n",
      "Pokud je prijem_rok v 04 ekvivalizovaný, srovnání neplatí – pak uprav (viz výpis sloupců výše).\n")
}

sink()
cat("\nHotovo:", F, "\n")
