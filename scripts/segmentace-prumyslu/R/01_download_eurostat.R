# =============================================================================
# 01_download_eurostat.R – stažení vstupních dat z API Eurostatu (JSON-stat 2.0)
# Výstup: data/eurostat/<název>.csv v jednotném formátu (dimenze + time + values)
# Dokumentace API: https://wikis.ec.europa.eu/display/EUROSTATHELP/API+Statistics+-+data+query
# =============================================================================
source("R/00_setup.R")

ES_API <- "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/"

# Převede odpověď JSON-stat na tabulku (jeden řádek = jedna hodnota)
parse_jsonstat <- function(j) {
  ids <- unlist(j$id); sizes <- unlist(j$size)
  cats <- lapply(ids, function(d) {
    idx <- unlist(j$dimension[[d]]$category$index)
    names(sort(idx))
  })
  names(cats) <- ids
  pos <- as.integer(names(j$value))
  out <- vector("list", length(ids)); names(out) <- ids
  rem <- pos
  for (i in rev(seq_along(ids))) {
    out[[ids[i]]] <- cats[[i]][rem %% sizes[i] + 1]
    rem <- rem %/% sizes[i]
  }
  as_tibble(out) %>% mutate(values = as.numeric(unlist(j$value)),
                          time = if (all(grepl("^[0-9]{4}$", time))) as.integer(time) else time)  # pololetí "2025-S1" zůstávají text
}

# Stáhne jeden dotaz; filtry jako pojmenovaný seznam vektorů
es_get <- function(dataset, filters) {
  q <- paste(unlist(Map(function(k, v) paste0(k, "=", v), names(filters), filters)), collapse = "&")
  url <- paste0(ES_API, dataset, "?", q)
  message("Stahuji ", dataset, " …")
  parse_jsonstat(jsonlite::fromJSON(url, simplifyVector = FALSE))
}

es_save <- function(df, name) write_csv(df, file.path(DIR_ES, paste0(name, ".csv")))

GEOS    <- c("CZ", "SK", "DE", "AT", "PL", "HU")
NACE_C  <- c("C", "C10-C12", "C13-C15", paste0("C", 16:30), "C31_C32", "C33")

if (!isTRUE(getOption("fok.no_download"))) {
  # 1) Emise skleníkových plynů podle odvětví (účty emisí do ovzduší), kt CO2e
  es_save(es_get("env_ac_ainah_r2", list(geo = GEOS, nace_r2 = NACE_C, airpol = "GHG",
                                         unit = "THS_T", time = 2015:2019)), "env_ac_ainah_r2")
  # 2) Hrubá přidaná hodnota, běžné ceny, mil. €
  es_save(es_get("nama_10_a64", list(geo = GEOS, nace_r2 = NACE_C, na_item = "B1G",
                                     unit = "CP_MEUR", time = c(2015:2019, 2024))), "nama_10_a64_B1G")
  # 3) Index průmyslové výroby (2021 = 100) – včetně složek sloučených oborů
  sts_nace <- c("C", paste0("C", 10:33))
  es_save(es_get("sts_inpr_a", list(geo = setdiff(GEOS, "SK"), nace_r2 = sts_nace, indic_bt = "PRD", s_adj = "CA",
                                    unit = "I21", time = c(2015, 2025))), "sts_inpr_a")
  # váhy pro sloučené obory C10-12, C13-15, C31_32: přidaná hodnota 2021 z podnikové statistiky
  # (2021 = základní rok indexu); složení viz funkce sts_composite() v R/funkce.R
  es_save(es_get("sbs_ovw_act", list(geo = setdiff(GEOS, "SK"), nace_r2 = paste0("C", c(10:15, 31, 32)),
                                     indic_sbs = "AV_MEUR", time = 2021)), "sbs_weights_2021")
  # 4) Podniková statistika ČR 2024: tržby, nákupy energie, osobní náklady
  es_save(es_get("sbs_ovw_act", list(geo = "CZ", nace_r2 = NACE_C,
                                     indic_sbs = c("NETTUR_MEUR", "PUR_NRG_MEUR", "EXPN_SAL_BEN_MEUR"),
                                     time = 2024)), "sbs_ovw_act")
  # 5) Užití elektřiny podle odvětví (PEFA), TJ
  es_save(es_get("env_ac_pefasu", list(geo = "CZ", nace_r2 = NACE_C, stk_flow = "USE",
                                       prod_nrg = "P26", unit = "TJ", time = 2023)), "env_ac_pefasu")
  # 6) Zaměstnanost v krajích (NUTS 3), tis. osob
  nuts3 <- c("CZ010", "CZ020", "CZ031", "CZ032", "CZ041", "CZ042", "CZ051", "CZ052",
             "CZ053", "CZ063", "CZ064", "CZ071", "CZ072", "CZ080")
  es_save(es_get("nama_10r_3empers", list(geo = nuts3, nace_r2 = c("C", "TOTAL"), wstatus = "EMP",
                                          unit = "THS", time = c(2015:2019, 2023))), "nama_10r_3empers")
  # 6b) Zaměstnanost v místních jednotkách podle regionů soudržnosti (NUTS 2) a oborů – energeticky náročné obory
  es_save(es_get("sbs_r_nuts2021", list(geo = paste0("CZ0", 1:8), nace_r2 = c("C", "C17", "C20", "C23", "C24"),
                                        indic_sbs = "EMP_LOC_NR", time = 2023)), "sbs_r_nuts2021")
  # 7) Slovensko: index výroby jen za skupiny oborů – ŠÚ SR DATAcube pm0040ms
  #    https://data.statistics.sk/  (ruční export do data/eurostat/sk_prod.csv: nace,2015,…,2025)
  message("Hotovo. Slovenský index (sk_prod.csv) je potřeba stáhnout ručně z DATAcube ŠÚ SR.")
}
