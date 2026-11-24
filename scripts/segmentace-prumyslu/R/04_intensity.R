# =============================================================================
# 04_intensity.R – emisní náročnost odvětví vs. změna výroby (slide 11)
# Emisní náročnost = součet emisí 2015–2019 / součet HPH 2015–2019 (běžné ceny), t CO2e / mil. €
# Výroba = index průmyslové výroby 2025 / 2015 − 1
# Body: obor × země (CZ, DE, AT, PL, HU); Slovensko za skupiny oborů (ŠÚ SR)
# Kontrola robustnosti: stejný výpočet s náročností jen za rok 2018
# Výstup: out/intensity_points.csv, out/intensity_stats.csv
# =============================================================================
source("R/00_setup.R")

YEARS_INT <- 2015:2019
ghg <- es_read("env_ac_ainah_r2")
gva <- es_read("nama_10_a64_B1G")
sts <- es_read("sts_inpr_a")

# Sloučené obory (C10-12, C13-15, C31_32) – vážený průměr indexů složek, váhy = přidaná hodnota 2021.
# Použije se jen tehdy, když stažený index obsahuje složky a ne přímo sloučený kód.
# sts_composite() je v R/funkce.R
if (!any(sts$nace_r2 == "C10-C12") && file.exists(file.path(DIR_ES, "sbs_weights_2021.csv"))) {
  w <- es_read("sbs_weights_2021") %>% transmute(geo, nace_r2, w = values)
  sts <- sts_composite(sts, w)
}

intensity <- function(yrs) {
  inner_join(
    ghg %>% filter(time %in% yrs) %>% group_by(geo, nace_r2) %>% summarise(ghg_kt = sum(values), .groups = "drop"),
    gva %>% filter(time %in% yrs) %>% group_by(geo, nace_r2) %>% summarise(gva_meur = sum(values), .groups = "drop"),
    by = c("geo", "nace_r2")) %>%
    mutate(t_per_meur = ghg_kt * 1000 / gva_meur)
}
int_avg <- intensity(YEARS_INT)
int_18  <- intensity(2018) %>% select(geo, nace_r2, t_per_meur_2018 = t_per_meur)

prod <- sts %>% filter(time %in% c(2015, 2025)) %>%
  select(geo, nace_r2, time, values) %>%
  pivot_wider(names_from = time, values_from = values, names_prefix = "P") %>%
  mutate(output_change_pct = (P2025 / P2015 - 1) * 100)

pts <- int_avg %>% inner_join(int_18, by = c("geo", "nace_r2")) %>%
  inner_join(prod %>% select(geo, nace_r2, output_change_pct), by = c("geo", "nace_r2")) %>%
  filter(nace_r2 != "C", nace_r2 != "C19", geo != "SK", is.finite(output_change_pct))

# Slovensko: index jen za skupiny oborů -> náročnost se počítá za stejné skupiny
sk_groups <- list("20" = "C20", "21" = "C21", "26" = "C26", "27" = "C27", "28" = "C28",
                  "10-12" = "C10-C12", "13-15" = "C13-C15", "16-18" = c("C16", "C17", "C18"),
                  "22-23" = c("C22", "C23"), "24-25" = c("C24", "C25"), "29-30" = c("C29", "C30"),
                  "31-33" = c("C31_C32", "C33"))
sk_prod_file <- file.path(DIR_ES, "sk_prod.csv")
if (file.exists(sk_prod_file)) {
  skp <- read_csv(sk_prod_file, show_col_types = FALSE, col_types = cols(nace = col_character()))
  sum_for <- function(df, codes, col) sum(df[[col]][df$geo == "SK" & df$nace_r2 %in% codes])
  ia <- intensity(YEARS_INT); i18 <- intensity(2018)
  sk <- bind_rows(lapply(names(sk_groups), function(k) {
    cs <- sk_groups[[k]]; r <- skp[skp$nace == k, ]
    tibble(geo = "SK", nace_r2 = paste0("SK", k),
           ghg_kt = sum_for(ia, cs, "ghg_kt"), gva_meur = sum_for(ia, cs, "gva_meur"),
           t_per_meur_2018 = sum_for(i18, cs, "ghg_kt") * 1000 / sum_for(i18, cs, "gva_meur"),
           output_change_pct = (r[["2025"]] / r[["2015"]] - 1) * 100) %>%
      mutate(t_per_meur = ghg_kt * 1000 / gva_meur)
  }))
  pts <- bind_rows(pts, sk)
}
pts <- pts %>% mutate(nace = from_es(nace_r2))
write_csv(pts, file.path(DIR_OUT, "intensity_points.csv"))

trend <- function(x, y) { f <- lm(y ~ log10(x)); c(slope_per_10x = unname(coef(f)[2]), corr = cor(log10(x), y)) }
stats <- bind_rows(
  c(variant = "průměr 2015–2019", as.list(trend(pts$t_per_meur, pts$output_change_pct)), n = nrow(pts)),
  c(variant = "rok 2018",         as.list(trend(pts$t_per_meur_2018, pts$output_change_pct)), n = nrow(pts))
)
write_csv(stats, file.path(DIR_OUT, "intensity_stats.csv"))
print(stats)
