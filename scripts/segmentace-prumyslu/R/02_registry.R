# =============================================================================
# 02_registry.R – zařízení EU ETS v ČR: přiřazení k oborům a krajům
# Vstup:  data/raw/verified_emissions_2025_en.xlsx (Union Registry)
#         data/manual/activity_to_nace.csv     – kód činnosti ETS -> obor NACE
#         data/manual/installation_nace_override.csv – ruční přeřazení zařízení s kódem 99
#         data/manual/combustion_industrial.csv – 22 průmyslových zdrojů vedených jako spalování
#         data/manual/installations_kraj.csv    – kraj podle místa provozu
# Výstup: out/registry_installations.csv (zařízení × rok)
#         out/registry_by_nace_year.csv   (obor × typ × rok)
# =============================================================================
source("R/00_setup.R")

if (stahnout(REGISTRY_FILE)) {
  download.file(REGISTRY_URL, REGISTRY_FILE, mode = "wb")
  zapis_stazeni(REGISTRY_FILE, REGISTRY_URL)
}

raw <- read_excel(REGISTRY_FILE, sheet = "data", skip = 2, col_types = "text")

# Stacionární zařízení v ČR (účty provozovatelů zařízení, ne letecké a námořní)
cz <- raw %>% filter(REGISTRY_CODE == "CZ", ACCOUNT_TYPE == "OPERATOR HOLDING ACCOUNT")

num <- function(x) suppressWarnings(as.numeric(x))  # "n/a" a "Excluded" -> NA
years <- 2013:2025

inst <- bind_rows(lapply(years, function(y) tibble(
  installation_id = as.integer(cz$INSTALLATION_IDENTIFIER),
  name            = cz$INSTALLATION_NAME,
  activity_code   = as.integer(cz$MAIN_ACTIVITY_TYPE_CODE),
  year            = y,
  # bezplatná alokace = základní alokace + alokace z rezervy pro nové účastníky
  free_alloc      = rowSums(cbind(num(cz[[paste0("ALLOCATION_", y)]]),
                                  num(cz[[paste0("ALLOCATION_RESERVE_", y)]])), na.rm = TRUE),
  # přechodná alokace na výrobu elektřiny (čl. 10c) – do výpočtu nevstupuje
  transitional    = num(cz[[paste0("ALLOCATION_TRANSITIONAL_", y)]]),
  verified_em     = num(cz[[paste0("VERIFIED_EMISSIONS_", y)]])
)))

act_map  <- read_csv(file.path(DIR_MANUAL, "activity_to_nace.csv"), show_col_types = FALSE)
comb_map <- read_csv(file.path(DIR_MANUAL, "combustion_industrial.csv"), show_col_types = FALSE)
kraj_map <- read_csv(file.path(DIR_MANUAL, "installations_kraj.csv"), show_col_types = FALSE)

inst <- inst %>%
  # krok 1: procesní činnosti podle kódu činnosti
  left_join(act_map %>% select(activity_code, nace_proc = nace), by = "activity_code") %>%
  # krok 2: vybrané průmyslové zdroje vedené jako spalování (kód 20, starý kód 1)
  left_join(comb_map %>% select(installation_id, nace_comb = nace), by = "installation_id") %>%
  mutate(
    source = case_when(!is.na(nace_proc) ~ "proc",
                       activity_code %in% c(1, 20) & !is.na(nace_comb) ~ "comb",
                       TRUE ~ NA_character_),
    nace = coalesce(nace_proc, nace_comb)
  ) %>%
  filter(!is.na(source)) %>%
  select(-nace_proc, -nace_comb)

# krok 3: ruční přeřazení zařízení vedených jako „jiná činnost“ (kód 99) – data/manual/installation_nace_override.csv
ovr_file <- file.path(DIR_MANUAL, "installation_nace_override.csv")
if (file.exists(ovr_file)) {
  ovr <- read_csv(ovr_file, show_col_types = FALSE)
  inst <- inst %>% left_join(ovr %>% select(installation_id, nace_ovr = nace), by = "installation_id") %>%
    mutate(nace = coalesce(nace_ovr, nace)) %>% select(-nace_ovr) %>% filter(nace != "vyřadit")
}

inst <- inst %>%
  left_join(kraj_map %>% select(installation_id, kraj), by = "installation_id") %>%
  # sektory pro podíl povolenek zdarma (S16): cement = činnosti 29 (slínek) a 30 (vápno), sklo a keramika = zbytek C23
  mutate(sektor = case_when(nace == "C24" ~ "Výroba oceli",
                            activity_code %in% c(29, 30) ~ "Výroba cementu",
                            nace == "C23" ~ "Sklo a keramika",
                            nace == "C20" ~ "Chemikálie",
                            TRUE ~ NA_character_))

# Kontrola: všechna zařízení s emisemi 2015–2019 mají přiřazený kraj
no_kraj <- inst %>% filter(year %in% 2015:2019, verified_em > 0, is.na(kraj)) %>% distinct(installation_id, name)
if (nrow(no_kraj)) warning("Zařízení bez kraje: ", paste(no_kraj$name, collapse = "; "))

write_csv(inst, file.path(DIR_OUT, "registry_installations.csv"))

by_nace <- inst %>%
  group_by(nace, source, year) %>%
  summarise(free_alloc   = sum(free_alloc, na.rm = TRUE),
            transitional = sum(transitional, na.rm = TRUE),
            verified_em  = sum(verified_em, na.rm = TRUE),
            n_installations = sum(!is.na(verified_em) & verified_em > 0),
            .groups = "drop") %>%
  left_join(EUA_PRICE, by = "year") %>%
  mutate(net_t = verified_em - free_alloc,          # kladné = deficit (podnik musí dokoupit)
         net_eur_m = net_t * price / 1e6)

write_csv(by_nace, file.path(DIR_OUT, "registry_by_nace_year.csv"))
message("02_registry: ", n_distinct(inst$installation_id), " průmyslových zařízení, ",
        nrow(by_nace), " řádků obor × typ × rok")
