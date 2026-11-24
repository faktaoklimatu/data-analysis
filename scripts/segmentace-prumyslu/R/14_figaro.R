# =============================================================================
# 14_figaro.R – dovozní konkurence a vývoz mimo EU ETS (str. 26, 27, 28)
# Eurostat FIGARO, mezinárodní input-output tabulka odvětví × odvětví, základní ceny, mil. €:
#   naio_10_fcp_ii4 (2024), naio_10_fcp_ii2 (2015, vydání 2014–2017)
# Pro obor X v ČR (řádky ind_ava = X, sečteno přes všechna užití ind_use vč. konečné poptávky):
#   produkce P = vše, co obor X v ČR dodá kamkoli (c_orig = CZ, všechny c_dest)
#   vývoz E    = dodávky z ČR do zahraničí (c_orig = CZ, c_dest ≠ CZ)
#   dovoz M    = výrobky oboru X ze zahraničí užité v ČR (c_orig ≠ CZ, c_dest = CZ)
#   dovozní penetrace = M / (P − E + M)  (podíl dovozu na domácí spotřebě)
#   vývoz mimo oblast EU ETS = vývoz mimo EU27, Norsko, Island, Lichtenštejnsko a Švýcarsko; UK zvlášť
# Energie (str. 27): Eurostat env_ac_pefa04, čisté domácí užití energie pro energetické účely (NETDOM_EUSE_EP),
#   TJ, 2015 a 2023 – stejná definice jako str. 11 (12_energie_pefa.R)
# Výstup: out/figaro_obory.csv – obor × rok: P, E, M, penetrace (z EU / mimo EU), vývoz mimo EU ETS, UK
#         out/figaro_skupiny.csv – str. 26 a 27 se sloučenými obory (dřevo + papír, rafinerie + chemie)
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)

# Pozn.: Řecko má ve FIGARO kód EL (ne GR)
EU27 <- c("AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "ES", "FI", "FR", "EL", "HR", "HU", "IE", "IT", "LT",
          "LU", "LV", "MT", "NL", "PL", "PT", "RO", "SE", "SI", "SK")
ETS_OBLAST <- c(EU27, "NO", "IS", "LI", "CH")   # Island a Lichtenštejnsko FIGARO neuvádí (jsou v WRL_REST)
OBORY <- setdiff(names(NACE_NAMES), "C")        # 19 oborů vč. rafinerií; kódy FIGARO jsou shodné
FIG <- c(`2024` = "naio_10_fcp_ii4", `2015` = "naio_10_fcp_ii2")

fig_get <- function(rok, smer) {
  name <- paste0("figaro_", rok, "_", smer)
  if (stahnout(file.path(DIR_ES, paste0(name, ".csv")))) {
    flt <- list(ind_ava = OBORY, unit = "MIO_EUR", time = as.integer(rok))
    if (smer == "z_cz") flt$c_orig <- "CZ" else flt$c_dest <- "CZ"
    es_save(es_get(FIG[[rok]], flt), name)
  }
  es_read(name)
}

fig <- bind_rows(lapply(names(FIG), function(rok) {
  z <- fig_get(rok, "z_cz"); do <- fig_get(rok, "do_cz")
  # kontrola: všechny země EU a oblasti ETS musí mít ve FIGARO svůj kód (jinak by spadly do „mimo EU“)
  chybi <- setdiff(c(EU27, "NO", "CH", "UK"), unique(z$c_dest))
  if (length(chybi)) stop("FIGARO ", rok, ": chybí kódy zemí ", paste(chybi, collapse = ", "))
  vyst <- z %>% group_by(nace = ind_ava) %>%
    summarise(P = sum(values),
              E = sum(values[c_dest != "CZ"]),
              E_mimo_ets = sum(values[!c_dest %in% ETS_OBLAST & c_dest != "UK"]),
              E_uk = sum(values[c_dest == "UK"]))
  dov <- do %>% filter(c_orig != "CZ") %>% group_by(nace = ind_ava) %>%
    summarise(M = sum(values), M_eu = sum(values[c_orig %in% EU27]))
  inner_join(vyst, dov, by = "nace") %>% mutate(rok = as.integer(rok))
}))

penetrace <- function(d) d %>% mutate(domaci_spotreba = P - E + M,
                                      penetrace_pct   = M / domaci_spotreba * 100,
                                      pen_eu_pct      = M_eu / domaci_spotreba * 100,
                                      pen_mimo_eu_pct = (M - M_eu) / domaci_spotreba * 100)
obory <- fig %>% penetrace() %>%
  mutate(name = NACE_NAMES[nace],
         mimo_ets_pct = E_mimo_ets / P * 100, uk_pct = E_uk / P * 100,
         mimo_ets_uk_mld = (E_mimo_ets + E_uk) / 1000)
write_csv(obory, file.path(DIR_OUT, "figaro_obory.csv"))

# --- Str. 26, 27: sloučené obory, energie a HPH -----------------------------------
SLOUC <- c(C16 = "C16_17", C17 = "C16_17", C19 = "C19_20", C20 = "C19_20")
SLOUC_NAMES <- c(C16_17 = "Dřevo a papír", C19_20 = "Rafinerie a chemie")
# data stahuje 12_energie_pefa.R (env_ac_pefa04_ep.csv)
energie <- es_read("env_ac_pefa04_ep") %>% filter(indic_pefa == "NETDOM_EUSE_EP", nace_r2 != "C") %>%
  transmute(nace = from_es(nace_r2), rok_e = time, tj = values)
hph <- es_read("nama_10_a64_CZ") %>% filter(na_item == "B1G", time %in% c(2015, 2023, 2024)) %>%
  transmute(nace = from_es(nace_r2), rok_h = time, hph_meur = values)

skup <- function(n) coalesce(unname(SLOUC[n]), n)
# rok FIGARO -> rok energie (2024 ještě není, bere se 2023)
ROK_E <- c(`2015` = 2015L, `2024` = 2023L)
e_sk <- energie %>% inner_join(hph, by = c("nace", "rok_e" = "rok_h")) %>%
  group_by(nace = skup(nace), rok_e) %>% summarise(tj = sum(tj), hph_e = sum(hph_meur), .groups = "drop")
h_sk <- hph %>% group_by(nace = skup(nace), rok_h) %>% summarise(hph_meur = sum(hph_meur), .groups = "drop")

skupiny <- fig %>% group_by(nace = skup(nace), rok) %>% summarise(across(c(P, E, M, M_eu), sum), .groups = "drop") %>%
  penetrace() %>%
  mutate(rok_e = ROK_E[as.character(rok)]) %>%
  left_join(e_sk, by = c("nace", "rok_e")) %>%
  left_join(h_sk, by = c("nace", "rok" = "rok_h")) %>%
  mutate(name = coalesce(unname(SLOUC_NAMES[nace]), unname(NACE_NAMES[nace])),
         tj_na_mil_eur = tj / hph_e,
         # čtyři skupiny: prahy 10 TJ / mil. € HPH a 50 % dovozní penetrace
         kvadrant = case_when(tj_na_mil_eur >= 10 & penetrace_pct >= 50 ~ "náročné + silná dovozní konkurence",
                              tj_na_mil_eur >= 10 ~ "náročné, regionální trh",
                              penetrace_pct >= 50 ~ "obchodované, nenáročné",
                              TRUE ~ "nenáročné, regionální trh")) %>%
  select(nace, name, rok, P, E, M, M_eu, domaci_spotreba, penetrace_pct, pen_eu_pct, pen_mimo_eu_pct,
         rok_energie = rok_e, tj, tj_na_mil_eur, hph_meur, kvadrant)
write_csv(skupiny, file.path(DIR_OUT, "figaro_skupiny.csv"))

message(sprintf("14_figaro: dovozní penetrace 2024 – elektronika %.0f %%, hutě %.0f %%, cement/sklo %.0f %%",
                obory$penetrace_pct[obory$nace == "C26" & obory$rok == 2024],
                obory$penetrace_pct[obory$nace == "C24" & obory$rok == 2024],
                obory$penetrace_pct[obory$nace == "C23" & obory$rok == 2024]))
