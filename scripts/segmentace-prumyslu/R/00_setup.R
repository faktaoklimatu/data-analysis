# =============================================================================
# Fakta o klimatu – Segmentace průmyslu: zátěž EU ETS pro obory českého průmyslu
# 00_setup.R – balíčky, cesty a konstanty společné pro všechny skripty
# Spouštějte skripty z kořenové složky projektu (tam, kde je složka R/).
# =============================================================================

pkgs <- c("readxl", "dplyr", "tidyr", "readr", "jsonlite", "stringr")
missing_pkgs <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs)) install.packages(missing_pkgs)
suppressPackageStartupMessages(invisible(lapply(pkgs, library, character.only = TRUE)))

# --- Cesty --------------------------------------------------------------------
DIR_RAW    <- "data/raw"        # registr EU ETS (xlsx)
DIR_ES     <- Sys.getenv("FOK_EUROSTAT_DIR", "data/eurostat")  # stažená data Eurostatu
DIR_MANUAL <- "data/manual"     # ručně připravené převodníky (zařízení -> obor, kraj)
DIR_OUT    <- "out"             # výsledky (CSV), ze kterých se kreslí grafy
for (d in c(DIR_RAW, DIR_ES, DIR_OUT)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

# --- Registr EU ETS -------------------------------------------------------------
# Union Registry, tabulka ověřených emisí a alokací (obsahuje roky 2013–2025)
# https://climate.ec.europa.eu/eu-action/carbon-markets/eu-emissions-trading-system-eu-ets/union-registry_en
REGISTRY_URL  <- paste0("https://climate.ec.europa.eu/document/download/",
                        "53018483-62b3-499e-9ab9-b4a831cc44f4_en?filename=verified_emissions_2025_en.xlsx")
REGISTRY_FILE <- file.path(DIR_RAW, "verified_emissions_2025_en.xlsx")

# --- Ceny povolenek -----------------------------------------------------------------
# Průměrná roční cena primárních aukcí EUA (€/t), DEHSt:
# https://www.dehst.de/EN/Topics/EU-ETS-1/EU-ETS-1-Information/Auctioning/auctioning_node.html
EUA_PRICE <- tibble(
  year  = 2013:2025,
  price = c(4.33, 5.90, 7.60, 5.26, 5.80, 14.90, 24.66, 24.59, 52.47, 80.40, 83.68, 65.01, 73.86)
)

# --- Emisní faktor elektřiny ------------------------------------------------------------
# Maximální regionální faktor Czechia-Slovakia, příloha III pokynů ke státní podpoře v ETS
# https://www.eftasurv.int/cms/sites/default/files/documents/2020_ETS_Guidelines_and_2022_supplements_consolidated.pdf
EF_ELEC <- 0.85  # t CO2 / MWh

# --- Obory --------------------------------------------------------------------------------
NACE_NAMES <- c(
  "C10-12" = "Potraviny a nápoje", "C13-15" = "Textil a oděvy", "C16" = "Dřevo",
  "C17" = "Papír", "C18" = "Tisk", "C19" = "Rafinerie", "C20" = "Chemie",
  "C21" = "Farmacie", "C22" = "Pryž a plasty", "C23" = "Cement, sklo, keramika",
  "C24" = "Hutě a slévárny", "C25" = "Kovovýroba", "C26" = "Elektronika",
  "C27" = "Elektrická zařízení", "C28" = "Stroje", "C29" = "Auta",
  "C30" = "Ostatní doprava", "C31_32" = "Nábytek a ostatní", "C33" = "Opravy a instalace",
  "C" = "Zpracovatelský průmysl celkem"
)
# Eurostat používá u sloučených oborů jiné kódy
NACE_ES <- c("C10-12" = "C10-C12", "C13-15" = "C13-C15", "C31_32" = "C31_C32")
to_es   <- function(x) ifelse(x %in% names(NACE_ES), NACE_ES[x], x)
from_es <- function(x) { inv <- setNames(names(NACE_ES), NACE_ES); ifelse(x %in% names(inv), inv[x], x) }

# Pomocná funkce: načte uložená data Eurostatu (viz 01_download_eurostat.R)
es_read <- function(name) {
  f <- file.path(DIR_ES, paste0(name, ".csv"))
  if (!file.exists(f)) stop("Chybí ", f, " – spusťte nejdřív R/01_download_eurostat.R")
  read_csv(f, show_col_types = FALSE, col_types = cols(time = col_integer(), .default = col_guess()))
}

# Sdílené pomocné funkce
source("R/funkce.R", encoding = "UTF-8")

# --- Skupiny oborů (str. 6, 10, 11) ---------------------------------------------------------
SKUPINA_EXPORT  <- c("C26", "C27", "C28", "C29", "C30")   # exportní jádro: elektronika, el. zařízení, stroje, auta, ost. doprava
SKUPINA_ENERGIE <- c("C17", "C20", "C23", "C24")          # energeticky nejnáročnější: papír, chemie, cement/sklo/keramika, hutě
