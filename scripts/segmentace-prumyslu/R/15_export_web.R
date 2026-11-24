# =============================================================================
# 15_export_web.R – data pro webovou prezentaci (repozitář web-cz)
# Zapíše malé tabulky (agregáty za obory) do web-cz/_data/segmentace_prumyslu/.
# Grafy na webu se kreslí jen z těchto souborů; žádné číslo se na webu nepíše ručně.
# Cesta k web-cz: proměnná prostředí FOK_WEB_DIR, výchozí ../../../web-cz (vedle data-analysis).
# =============================================================================
source("R/00_setup.R")

WEB_DIR <- file.path(Sys.getenv("FOK_WEB_DIR", "../../../web-cz"), "_data", "segmentace_prumyslu")
if (!dir.exists(dirname(WEB_DIR))) stop("Nenalezen repozitář web-cz: ", dirname(dirname(WEB_DIR)),
                                        " – nastavte FOK_WEB_DIR", call. = FALSE)
dir.create(WEB_DIR, showWarnings = FALSE)
rd  <- function(name) read_csv(file.path(DIR_OUT, paste0(name, ".csv")), show_col_types = FALSE)
web <- function(df, name) write_csv(df, file.path(WEB_DIR, paste0(name, ".csv")))
skupina <- function(n) case_when(n %in% SKUPINA_EXPORT ~ "export", n %in% SKUPINA_ENERGIE ~ "energie", TRUE ~ "ostatni")

# Str. 5, 6 – mozaika oborů
rd("obory_velikost_2025") %>%
  transmute(nace, obor = NACE_NAMES[nace], skupina = skupina(nace),
            podil_hph = round(podil_hph_pct, 1), pracujici_tis = round(pracujici_tis)) %>%
  web("obory_2025")

# Str. 7 – index výroby 2015 = 100, Česko a Německo
rd("production_index_annual") %>%
  transmute(nace, obor = NACE_NAMES[nace], skupina = skupina(nace), zeme = geo, rok = time,
            index = round(index_2015, 1)) %>%
  arrange(nace, zeme, rok) %>%
  web("vyroba_index")

# Str. 11, 12 – energetická náročnost a skladba paliv
rd("energie_narocnost_2023") %>% filter(nace != "C") %>%
  transmute(nace, obor = NACE_NAMES[nace], skupina = skupina(nace),
            tj_na_mil_eur = round(tj_na_mil_eur, 1), hlavni_palivo, hlavni_podil = round(hlavni_podil_pct)) %>%
  arrange(desc(tj_na_mil_eur)) %>%
  web("energie_narocnost")
rd("energie_skladba_2023") %>% filter(nace != "C", tj > 0) %>%
  transmute(nace, palivo, podil = round(podil_pct, 1)) %>%
  web("energie_skladba")

# Str. 10 – energie a práce v % nákladů (SUT)
rd("naklady_sut") %>%
  transmute(nace, obor = NACE_NAMES[nace], skupina = if_else(nace == "C", "celek", skupina(nace)),
            energie_pct = round(energie_pct, 1), prace_pct = round(prace_pct, 1), hph_mld_kc = round(hph / 1000)) %>%
  web("naklady_energie_prace")

# Str. 15, 16 – povolenky zdarma 2025
inst <- rd("registry_installations") %>% filter(year == 2025)
bind_rows(inst %>% mutate(sektor = "Průmysl celkem"), inst %>% filter(!is.na(sektor))) %>%
  group_by(sektor) %>%
  summarise(zdarma_mt = round(sum(free_alloc, na.rm = TRUE) / 1e6, 2),
            emise_mt = round(sum(verified_em, na.rm = TRUE) / 1e6, 2),
            podil_zdarma = round(sum(free_alloc, na.rm = TRUE) / sum(verified_em, na.rm = TRUE) * 100, 1)) %>%
  web("povolenky_zdarma")

# Str. 17 – energie vs. náklady ETS
rd("ets_costs_2024") %>% filter(nace != "C19") %>%
  transmute(nace, obor = NACE_NAMES[nace], podil_nakladu = round(podil_nakladu_c_pct, 1),
            nepr_ets = round(indirect_pct_naklady, 1), prime_ets = round(direct_pct_naklady, 1),
            prime_ets_nejlepsi = round(direct_best_pct_naklady, 1), prime_ets_deficity = round(direct_def_pct_naklady, 1)) %>%
  left_join(rd("naklady_sut") %>% transmute(nace, energie = round(energie_pct, 1)), by = "nace") %>%
  web("naklady_ets")

# Str. 20 – exportní jádro
rd("dovoz_aut_cina_eu") %>% mutate(dovoz_mld_eur = round(dovoz_mld_eur, 2)) %>% web("dovoz_aut_cina")
rd("exportni_jadro_prace") %>%
  transmute(nace, obor = NACE_NAMES[nace], rok = time,
            podil_prace_hph = round(podil_prace_hph, 1), naklady_prace = round(naklady_prace_idx, 1),
            hph_na_prac = round(hph_na_prac_idx, 1)) %>%
  web("mzdy_produktivita")

# Str. 26–28 – FIGARO
rd("figaro_obory") %>% filter(rok == 2024) %>%
  transmute(nace, obor = NACE_NAMES[nace], skupina = skupina(nace),
            penetrace = round(penetrace_pct, 1), z_eu = round(pen_eu_pct, 1), mimo_eu = round(pen_mimo_eu_pct, 1),
            vyvoz_mimo_ets = round(mimo_ets_pct, 1), vyvoz_uk = round(uk_pct, 1), vyvoz_mimo_ets_mld = round(mimo_ets_uk_mld, 1),
            # str. 28: vztah k CBAM (nařízení (EU) 2023/956, příloha I)
            cbam = case_when(nace == "C24" ~ "cely", nace %in% c("C20", "C23") ~ "cast",
                             nace %in% c("C25", "C27", "C28", "C29", "C30") ~ "odberatel", TRUE ~ "ostatni")) %>%
  web("obchod_2024")
rd("figaro_skupiny") %>%
  transmute(nace, obor = name, rok, penetrace = round(penetrace_pct, 1), z_eu = round(pen_eu_pct, 1), mimo_eu = round(pen_mimo_eu_pct, 1),
            tj_na_mil_eur = round(tj_na_mil_eur, 1),
            hph_meur = round(hph_meur), skupina = skupina(nace)) %>%
  web("skupiny_oboru")

# Str. 20–23 – lišty karet oborů: výroba 2015 → 2025, energie (% nákladů), přímé povolenky (% nákladů), zdarma
idx <- rd("production_index_annual") %>% filter(geo == "CZ", time == max(time)) %>% transmute(nace, vyroba = round(index_2015 - 100) + 0)   # + 0: bez „-0“
ets <- rd("ets_costs_2024")
sut <- rd("naklady_sut")
inst25 <- rd("registry_installations") %>% filter(year == 2025, !is.na(sektor)) %>% group_by(sektor) %>%
  summarise(zdarma = round(sum(free_alloc, na.rm = TRUE) / sum(verified_em, na.rm = TRUE) * 100))
karta <- function(n, sektor, prime_sloupec, prime_pozn) tibble(
  nace = n, obor = NACE_NAMES[[n]], vyroba = idx$vyroba[idx$nace == n],
  energie = round(sut$energie_pct[sut$nace == n], 1),
  prime_ets = round(ets[[prime_sloupec]][ets$nace == n], 1) + 0, prime_pozn = prime_pozn,
  zdarma = if (is.na(sektor)) NA_real_ else inst25$zdarma[inst25$sektor == sektor], zdarma_sektor = sektor)
bind_rows(
  karta("C23", "Výroba cementu", "direct_best_pct_naklady", ""),
  karta("C24", "Výroba oceli", "direct_best_pct_naklady", "nejlepší odhad (Energetika Třinec 86,5 %)"),
  karta("C20", "Chemikálie", "direct_pct_naklady", "horní odhad vč. elektráren a kotelen podniků")) %>%
  web("karty_oboru")
sut %>% filter(nace %in% SKUPINA_EXPORT) %>%
  transmute(nace, energie = round(energie_pct, 1)) %>%
  left_join(ets %>% transmute(nace, prime_ets = round(direct_pct_naklady, 1)), by = "nace") %>%
  left_join(idx, by = "nace") %>%
  web("karta_export")

message("15_export_web: ", length(list.files(WEB_DIR)), " souborů v ", normalizePath(WEB_DIR))
