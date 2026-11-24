# =============================================================================
# 01_download_eurostat.R – stažení vstupních dat z API Eurostatu (JSON-stat 2.0)
# Výstup: data/eurostat/<název>.csv v jednotném formátu (dimenze + time + values)
# Dokumentace API: https://wikis.ec.europa.eu/display/EUROSTATHELP/API+Statistics+-+data+query
# =============================================================================
source("R/00_setup.R")

ES_API <- "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/"
# Comext (zahraniční obchod podle HS): stejný formát JSON-stat, jiná adresa
COMEXT_API <- "https://ec.europa.eu/eurostat/api/comext/dissemination/statistics/1.0/data/"

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
es_get <- function(dataset, filters, api = ES_API) {
  q <- paste(unlist(Map(function(k, v) paste0(k, "=", v), names(filters), filters)), collapse = "&")
  url <- paste0(api, dataset, "?", q)
  message("Stahuji ", dataset, " …")
  parse_jsonstat(jsonlite::fromJSON(url, simplifyVector = FALSE))
}

es_save <- function(df, name) write_csv(df, file.path(DIR_ES, paste0(name, ".csv")))

NACE_C  <- c("C", "C10-C12", "C13-C15", paste0("C", 16:30), "C31_C32", "C33")

if (!isTRUE(getOption("fok.no_download"))) {
  # Data pro náklady ETS (03_ets_costs.R) a index výroby (08_production_annual.R).
  # Ostatní skripty si svá data stahují samy (11–14).
  # 1) Hrubá přidaná hodnota ČR 2024, běžné ceny, mil. €
  es_save(es_get("nama_10_a64", list(geo = "CZ", nace_r2 = NACE_C, na_item = "B1G",
                                     unit = "CP_MEUR", time = 2024)), "nama_10_a64_B1G")
  # 2) Váhy pro sloučené obory C10-12, C13-15, C31_32: přidaná hodnota 2021 z podnikové statistiky
  #    (2021 = základní rok indexu výroby); složení viz funkce sts_composite() v R/funkce.R
  es_save(es_get("sbs_ovw_act", list(geo = c("CZ", "DE"), nace_r2 = paste0("C", c(10:15, 31, 32)),
                                     indic_sbs = "AV_MEUR", time = 2021)), "sbs_weights_2021")
  # 3) Podniková statistika ČR 2024: tržby, nákupy energie, osobní náklady
  es_save(es_get("sbs_ovw_act", list(geo = "CZ", nace_r2 = NACE_C,
                                     indic_sbs = c("NETTUR_MEUR", "PUR_NRG_MEUR", "EXPN_SAL_BEN_MEUR"),
                                     time = 2024)), "sbs_ovw_act")
  # 4) Užití elektřiny podle odvětví (PEFA), TJ
  es_save(es_get("env_ac_pefasu", list(geo = "CZ", nace_r2 = NACE_C, stk_flow = "USE",
                                       prod_nrg = "P26", unit = "TJ", time = 2023)), "env_ac_pefasu")
}
