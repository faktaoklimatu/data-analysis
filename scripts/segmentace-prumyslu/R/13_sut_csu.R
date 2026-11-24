# =============================================================================
# 13_sut_csu.R – struktura nákladů oborů: energie a práce (str. 10, 17, 21–23)
# ČSÚ, tabulky dodávek a užití (SUT), běžné kupní ceny, mil. Kč, list „Matice dodávek a užití“
#   2024 (semidefinitivní) a 2025 (předběžné); výsledek = součet obou let
#   https://apl.czso.cz/pll/rocenka/rocenkaout.dod_uziti?mylang=CZ (údaje platné k 30. 6. 2026)
# Celkové náklady = mezispotřeba (CELKEM) + náhrady zaměstnancům (D.11 + D.12)
# Nákupy energie  = užití produktů CZ-CPA 05 (uhlí), 06 (ropa a zemní plyn), 19 (koks a ropné produkty),
#                   35 (elektřina, plyn, pára) – včetně uhlí a koksu do vysokých pecí
# Chemie (C20): v národních účtech ČR obsahuje i rafinerii. Za energii se bere jen podíl k z CPA 19
#   (topné oleje; k = ostatní ropné produkty / (nafta + ostatní ropné produkty) v PEFA 2023),
#   ropa (CPA 06) a zbytek CPA 19 (petrochemická surovina) se odečítají i z celkových nákladů.
# C = zpracovatelský průmysl bez rafinerií (C19).
# Výstup: out/naklady_sut.csv
# =============================================================================
source("R/00_setup.R")

# Odkazy na soubory: složka v cestě se mění s každým vydáním ČSÚ. Nový odkaz vrátí formulář:
#   curl -X POST https://apl.czso.cz/pll/rocenka/rocenkaout.soubor --data "mylang=CZ&rok=2025&ceny=bc&verze=260630"
SUT_URL <- c(`2024` = "https://apl.czso.cz/nufile/sut/ldrj8f6d54gw/SUT_2024s.xls",
             `2025` = "https://apl.czso.cz/nufile/sut/ldrj8f6d54gw/SUT_2025p.xls")

# Načte list „Matice dodávek a užití“ jako dlouhou tabulku řádek (CPA nebo položka D.11…) × obor NACE
read_sut <- function(rok) {
  f <- file.path(DIR_RAW, basename(SUT_URL[[rok]]))
  if (stahnout(f)) { download.file(SUT_URL[[rok]], f, mode = "wb"); zapis_stazeni(f, SUT_URL[[rok]]) }
  x <- read_excel(f, sheet = "Matice dodávek a užití", col_names = FALSE, col_types = "text", .name_repair = "minimal")
  nace_cols <- which(grepl("^[0-9]{2}$", unlist(x[8, ])))          # sloupce oborů 01–99 (kódy v 8. řádku)
  radky <- 9:nrow(x)
  # kontrola rozložení souboru: když ČSÚ list posune, ať výpočet spadne, ne tiše počítá špatně
  popisky <- trimws(x[[9]][radky])
  stopifnot("SUT: čekám 88 oborů (01–99) v 8. řádku" = length(nace_cols) == 88,
            "SUT: chybí nebo se opakuje řádek CELKEM / D.11 / D.12 / B.1g / CPA 05, 06, 19, 35" =
              all(table(factor(popisky, levels = c("CELKEM", "D.11", "D.12", "B.1g", "05", "06", "19", "35"))) == 1))
  tibble(radek = rep(trimws(x[[9]][radky]), times = length(nace_cols)),
         nace2 = rep(unlist(x[8, nace_cols]), each = length(radky)),
         mil_kc = as.numeric(unlist(x[radky, nace_cols])),
         rok = as.integer(rok))
}
sut <- bind_rows(lapply(names(SUT_URL), read_sut))

# podíl topných olejů na CPA 19 v chemii, z PEFA 2023 (env_ac_pefasu, stahuje 12_energie_pefa.R):
# ostatní ropné produkty / (nafta P16 + ostatní ropné produkty)
ROPNE_OST <- c("P12", "P14", "P15", "P17", "P18", "P19", "P20", "P21")
pefa_c20 <- es_read("env_ac_pefasu_all") %>% filter(nace_r2 == "C20")
K_C20 <- with(pefa_c20, sum(values[prod_nrg %in% ROPNE_OST]) / (values[prod_nrg == "P16"] + sum(values[prod_nrg %in% ROPNE_OST])))

# obor po dvou místech -> obor prezentace
to_obor <- function(n2) case_when(n2 %in% c("10", "11", "12") ~ "C10-12", n2 %in% c("13", "14", "15") ~ "C13-15",
                                  n2 %in% c("31", "32") ~ "C31_32", TRUE ~ paste0("C", n2))

po_oborech <- sut %>% filter(nace2 %in% sprintf("%02d", 10:33), nace2 != "19") %>%
  group_by(nace2, rok) %>%
  summarise(mezispotreba = sum(mil_kc[radek == "CELKEM"]),
            prace        = sum(mil_kc[radek %in% c("D.11", "D.12")]),
            hph          = sum(mil_kc[radek == "B.1g"]),
            cpa05 = sum(mil_kc[radek == "05"]), cpa06 = sum(mil_kc[radek == "06"]),
            cpa19 = sum(mil_kc[radek == "19"]), cpa35 = sum(mil_kc[radek == "35"]), .groups = "drop") %>%
  mutate(chemie   = nace2 == "20",
         energie  = if_else(chemie, cpa05 + K_C20 * cpa19 + cpa35, cpa05 + cpa06 + cpa19 + cpa35),
         odecet   = if_else(chemie, cpa06 + (1 - K_C20) * cpa19, 0),      # ropa a surovina mimo náklady
         naklady  = mezispotreba - odecet + prace)

agreg <- function(d) d %>% summarise(across(c(naklady, energie, prace, hph, mezispotreba, odecet), sum), .groups = "drop")
naklady <- bind_rows(
  po_oborech %>% mutate(nace = to_obor(nace2)) %>% group_by(nace) %>% agreg(),
  po_oborech %>% agreg() %>% mutate(nace = "C")) %>%
  mutate(name = NACE_NAMES[nace],
         energie_pct = energie / naklady * 100,
         prace_pct   = prace / naklady * 100,
         skupina = case_when(nace %in% SKUPINA_EXPORT ~ "exportní jádro",
                             nace %in% SKUPINA_ENERGIE ~ "energeticky nejnáročnější", TRUE ~ "ostatní"),
         k_c20 = K_C20) %>%
  select(nace, name, skupina, naklady, energie, prace, hph, energie_pct, prace_pct, mezispotreba, odecet, k_c20) %>%
  arrange(desc(energie_pct))
write_csv(naklady, file.path(DIR_OUT, "naklady_sut.csv"))

message(sprintf("13_sut_csu: energie %% nákladů 2024+2025 – hutě %.1f, chemie %.1f, C23 %.1f, průmysl %.1f (k chemie = %.2f)",
                naklady$energie_pct[naklady$nace == "C24"], naklady$energie_pct[naklady$nace == "C20"],
                naklady$energie_pct[naklady$nace == "C23"], naklady$energie_pct[naklady$nace == "C"], K_C20))
