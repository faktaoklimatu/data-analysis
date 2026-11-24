# =============================================================================
# 05_regions.R – emisní expozice krajů a změna zaměstnanosti v průmyslu (slide 24)
# Expozice = průměrné ověřené emise průmyslových zařízení 2015–2019 / průměrná zaměstnanost 2015–2019
# Zaměstnanost ve zpracovatelském průmyslu: změna 2015 -> 2023 (poslední rok regionálních účtů)
# Výstup: out/regions.csv, out/regions_stats.csv
# =============================================================================
source("R/00_setup.R")

YEARS_EXP <- 2015:2019
NUTS3 <- c(CZ010 = "Praha", CZ020 = "Středočeský", CZ031 = "Jihočeský", CZ032 = "Plzeňský",
           CZ041 = "Karlovarský", CZ042 = "Ústecký", CZ051 = "Liberecký", CZ052 = "Královéhradecký",
           CZ053 = "Pardubický", CZ063 = "Vysočina", CZ064 = "Jihomoravský", CZ071 = "Olomoucký",
           CZ072 = "Zlínský", CZ080 = "Moravskoslezský")

inst <- read_csv(file.path(DIR_OUT, "registry_installations.csv"), show_col_types = FALSE)
em <- inst %>% filter(year %in% YEARS_EXP, kraj %in% NUTS3) %>%
  group_by(kraj) %>% summarise(ets_kt_avg = sum(verified_em, na.rm = TRUE) / length(YEARS_EXP) / 1000)

emp <- es_read("nama_10r_3empers") %>% mutate(kraj = NUTS3[geo])
emp_w <- emp %>% select(geo, kraj, nace_r2, time, values) %>%
  pivot_wider(names_from = c(nace_r2, time), values_from = values)

reg <- emp_w %>%
  mutate(emp_total_avg = rowMeans(across(paste0("TOTAL_", YEARS_EXP))),
         share_c_2015  = C_2015 / TOTAL_2015 * 100,
         emp_c_change_pct = (C_2023 / C_2015 - 1) * 100) %>%
  left_join(em, by = "kraj") %>%
  mutate(ets_kt_avg = coalesce(ets_kt_avg, 0),
         exposure_t_per_emp = ets_kt_avg * 1000 / (emp_total_avg * 1000))
write_csv(reg, file.path(DIR_OUT, "regions.csv"))

x <- log10(pmax(reg$exposure_t_per_emp, 0.1))
no_prg <- reg$kraj != "Praha"
stats <- tibble(
  corr_all       = cor(x, reg$emp_c_change_pct),
  corr_no_prague = cor(x[no_prg], reg$emp_c_change_pct[no_prg]),
  share_msk_ust  = sum(reg$ets_kt_avg[reg$kraj %in% c("Moravskoslezský", "Ústecký")]) / sum(reg$ets_kt_avg) * 100,
  cz_emp_c_change_pct = (sum(reg$C_2023) / sum(reg$C_2015) - 1) * 100
)
write_csv(stats, file.path(DIR_OUT, "regions_stats.csv"))
print(stats)

# Pracovní místa v energeticky náročných oborech (papír, chemie, cement/sklo/keramika, hutě)
# Podniková statistika podle místních jednotek existuje jen za regiony soudržnosti NUTS 2.
NUTS2 <- c(CZ01 = "Praha", CZ02 = "Střední Čechy", CZ03 = "Jihozápad", CZ04 = "Severozápad",
           CZ05 = "Severovýchod", CZ06 = "Jihovýchod", CZ07 = "Střední Morava", CZ08 = "Moravskoslezsko")
KRAJ_NUTS2 <- c(CZ010 = "CZ01", CZ020 = "CZ02", CZ031 = "CZ03", CZ032 = "CZ03", CZ041 = "CZ04", CZ042 = "CZ04",
                CZ051 = "CZ05", CZ052 = "CZ05", CZ053 = "CZ05", CZ063 = "CZ06", CZ064 = "CZ06",
                CZ071 = "CZ07", CZ072 = "CZ07", CZ080 = "CZ08")
if (file.exists(file.path(DIR_ES, "sbs_r_nuts2021.csv"))) {
  ei <- es_read("sbs_r_nuts2021") %>% filter(time == 2023) %>%
    select(geo, nace_r2, values) %>% pivot_wider(names_from = nace_r2, values_from = values) %>%
    mutate(region = NUTS2[geo], ei_jobs = C17 + C20 + C23 + C24, ei_share_pct = ei_jobs / C * 100)
  write_csv(ei, file.path(DIR_OUT, "regions_ei_jobs.csv"))
  reg2 <- reg %>% mutate(nuts2 = KRAJ_NUTS2[geo]) %>% left_join(ei %>% select(nuts2 = geo, ei_share_pct), by = "nuts2")
  write_csv(reg2, file.path(DIR_OUT, "regions.csv"))
  print(ei %>% select(region, ei_jobs, C, ei_share_pct))
}
