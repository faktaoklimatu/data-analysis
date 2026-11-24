# =============================================================================
# 12_energie_pefa.R – energetická náročnost oborů a skladba paliv (str. 11, 12)
# Eurostat env_ac_pefasu (fyzické energetické toky, užití USE, TJ), ČR 2023 (poslední rok)
# Hrubé užití energie = P00 (energetické produkty) + R00 (energetické zbytky); bez přírodních vstupů N00
#   (u chemie N06 = 11 890 TJ biomasy jako přírodní vstup, nejde o nakoupenou energii), tj. včetně koksu do vysokých pecí
#   a surovin pro chemii (nafta P16). HPH 2023 z nama_10_a64 (11_hph_zamestnanost.R).
# Výstup: out/energie_narocnost_2023.csv – TJ pro energetické účely, HPH, TJ / mil. € HPH, hlavní palivo (str. 11)
#         out/energie_skladba_2023.csv   – obor × skupina paliv, TJ a % (str. 12)
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)

YEAR_PEFA <- 2023
OBORY <- setdiff(names(NACE_NAMES), c("C", "C19"))   # rafinerie vynechány (slajd)
f <- file.path(DIR_ES, "env_ac_pefasu_all.csv")
if (stahnout(f)) es_save(es_get("env_ac_pefasu", list(geo = "CZ", stk_flow = "USE", unit = "TJ",
                                                         nace_r2 = to_es(c("C", OBORY)), time = YEAR_PEFA)), "env_ac_pefasu_all")

# Skupiny paliv (kódy PEFA: https://ec.europa.eu/eurostat/cache/metadata/en/env_ac_pefa_esms.htm)
PALIVA <- tribble(
  ~prod_nrg, ~palivo,
  "P26", "Elektřina",
  "P13", "Zemní plyn",
  "P08", "Uhlí a koks", "P09", "Uhlí a koks", "P11", "Uhlí a koks",
  "P10", "Koksárenský a vysokopecní plyn",
  "P16", "Nafta (surovina)",     # neenergetické užití, ze skladby se vynechává
  "P12", "Ostatní ropné produkty", "P14", "Ostatní ropné produkty", "P15", "Ostatní ropné produkty",
  "P17", "Ostatní ropné produkty", "P18", "Ostatní ropné produkty", "P19", "Ostatní ropné produkty",
  "P20", "Ostatní ropné produkty", "P21", "Ostatní ropné produkty",
  "P27", "Teplo",
  "P23", "Biomasa", "P24", "Biomasa", "P25", "Biomasa",
  "R28", "Odpady", "R29", "Odpady",
  "P22", "Jaderné palivo"
)

pefa <- es_read("env_ac_pefasu_all") %>% transmute(nace = from_es(nace_r2), prod_nrg, tj = values)

skladba_vse <- pefa %>% inner_join(PALIVA, by = "prod_nrg")
skladba <- skladba_vse %>% filter(palivo != "Nafta (surovina)") %>%
  group_by(nace, palivo) %>% summarise(tj = sum(tj, na.rm = TRUE), .groups = "drop") %>%
  group_by(nace) %>% mutate(podil_pct = tj / sum(tj) * 100) %>% ungroup()

# kontrola: skupiny paliv dávají dohromady celkové hrubé užití P00 + R00
celkem <- pefa %>% filter(prod_nrg %in% c("P00", "R00")) %>% group_by(nace) %>% summarise(tj_celkem = sum(tj))
rozdil <- skladba_vse %>% group_by(nace) %>% summarise(tj = sum(tj, na.rm = TRUE)) %>% inner_join(celkem, by = "nace") %>%
  filter(abs(tj - tj_celkem) > 1)
if (nrow(rozdil)) warning("Skupiny paliv nedávají celkové užití: ", paste(rozdil$nace, collapse = ", "))

hph <- es_read("nama_10_a64_CZ") %>% filter(na_item == "B1G", time == YEAR_PEFA) %>%
  transmute(nace = from_es(nace_r2), hph_meur = values)
hlavni <- skladba %>% group_by(nace) %>% slice_max(tj, n = 1, with_ties = FALSE) %>%
  select(nace, hlavni_palivo = palivo, hlavni_podil_pct = podil_pct)

f_ep <- file.path(DIR_ES, "env_ac_pefa04_ep.csv")
if (stahnout(f_ep)) es_save(es_get("env_ac_pefa04", list(geo = "CZ", unit = "TJ",
                                                            indic_pefa = c("NETDOM_EUSE_EP", "NETDOM_EUSE_NEP", "EPRD_DOM"),
                                                            nace_r2 = to_es(c("C", OBORY, "C19")), time = c(2015, YEAR_PEFA))), "env_ac_pefa04_ep")
ep <- es_read("env_ac_pefa04_ep") %>% filter(time == YEAR_PEFA) %>%
  transmute(nace = from_es(nace_r2), indic_pefa, values) %>% pivot_wider(names_from = indic_pefa, values_from = values) %>%
  transmute(nace, tj_energie = NETDOM_EUSE_EP, tj_suroviny = NETDOM_EUSE_NEP, tj_vlastni_vyroba = EPRD_DOM)

narocnost <- celkem %>% rename(tj_hrube = tj_celkem) %>% inner_join(ep, by = "nace") %>%
  inner_join(hph, by = "nace") %>% left_join(hlavni, by = "nace") %>%
  mutate(name = NACE_NAMES[nace], tj_na_mil_eur = tj_energie / hph_meur, tj_hrube_na_mil_eur = tj_hrube / hph_meur,
         skupina = case_when(nace %in% SKUPINA_EXPORT ~ "exportní jádro",
                             nace %in% SKUPINA_ENERGIE ~ "energeticky nejnáročnější", TRUE ~ "ostatní")) %>%
  arrange(desc(tj_na_mil_eur))

write_csv(narocnost, file.path(DIR_OUT, "energie_narocnost_2023.csv"))
write_csv(skladba, file.path(DIR_OUT, "energie_skladba_2023.csv"))
message(sprintf("12_energie_pefa: hutě %.0f TJ/mil. €, chemie %.0f, papír %.0f",
                narocnost$tj_na_mil_eur[narocnost$nace == "C24"], narocnost$tj_na_mil_eur[narocnost$nace == "C20"],
                narocnost$tj_na_mil_eur[narocnost$nace == "C17"]))
