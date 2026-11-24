# =============================================================================
# 03_ets_costs.R – přímé a nepřímé náklady EU ETS a nákupy energie podle oborů (ČR, 2024)
# Slidy 10, 16–20 (náklady na 100 € tržeb), 22 (časová řada), 26 (bod 3)
# Vstup:  out/registry_by_nace_year.csv (02_registry.R)
#         data/eurostat: nama_10_a64_B1G, sbs_ovw_act, env_ac_pefasu
# Výstup: out/ets_costs_2024.csv, out/ets_timeseries.csv, out/steel_sites.csv
# =============================================================================
source("R/00_setup.R")

YEAR_COST <- 2024   # rok cen a HPH
YEAR_ELEC <- 2023   # poslední rok PEFA
price_cost <- EUA_PRICE$price[EUA_PRICE$year == YEAR_COST]

reg <- read_csv(file.path(DIR_OUT, "registry_by_nace_year.csv"), show_col_types = FALSE)

gva <- es_read("nama_10_a64_B1G") %>% filter(geo == "CZ", time == YEAR_COST) %>%
  transmute(nace = from_es(nace_r2), gva_meur = values)
sbs <- es_read("sbs_ovw_act") %>% filter(geo == "CZ", time == YEAR_COST) %>%
  transmute(nace = from_es(nace_r2), indic_sbs, values) %>%
  pivot_wider(names_from = indic_sbs, values_from = values) %>%
  rename(turnover_meur = NETTUR_MEUR, energy_meur = PUR_NRG_MEUR, labour_meur = EXPN_SAL_BEN_MEUR)
elec <- es_read("env_ac_pefasu") %>% filter(geo == "CZ", time == YEAR_ELEC, prod_nrg == "P26") %>%
  transmute(nace = from_es(nace_r2), elec_tj = values)

# Přímé čisté náklady: (ověřené emise − bezplatné povolenky) × cena, podle zařízení
# Horní odhad: všechna průmyslová zařízení oboru vč. energetik a elektráren podniků.
# Dolní odhad: bez energetik (energetika = 1 v combustion_industrial.csv), které část tepla
#   a elektřiny prodávají (teplárenství, síť) – jejich deficit se oboru nepřičítá.
# Nejlepší odhad: energetiky se přičtou podílem výroby pro obor (podil_obor; Energetika Třinec 0,865 podle ERÚ).
comb_flags <- read_csv(file.path(DIR_MANUAL, "combustion_industrial.csv"), show_col_types = FALSE) %>%
  select(installation_id, energetika, podil_obor)
inst <- read_csv(file.path(DIR_OUT, "registry_installations.csv"), show_col_types = FALSE) %>%
  filter(year == YEAR_COST) %>%
  left_join(comb_flags, by = "installation_id") %>%
  mutate(energetika = coalesce(energetika, 0), podil_obor = coalesce(podil_obor, 1),
         net = coalesce(verified_em, 0) - coalesce(free_alloc, 0))
direct <- inst %>% group_by(nace) %>%
  summarise(net_t = sum(net), net_low_t = sum(net[energetika == 0]), net_best_t = sum(net * podil_obor),
            .groups = "drop")
direct_total <- direct %>% summarise(nace = "C", across(c(net_t, net_low_t, net_best_t), sum))
direct <- bind_rows(direct, direct_total) %>%
  mutate(direct_meur = net_t * price_cost / 1e6, direct_low_meur = net_low_t * price_cost / 1e6,
         direct_best_meur = net_best_t * price_cost / 1e6)

# Kompenzace nepřímých nákladů vyplacené za rok 2024 (MPO, 6. 1. 2026), převod kurzem ECB 2024
EUR_CZK_2024 <- 25.12
komp <- read_csv(file.path(DIR_MANUAL, "kompenzace_neprimych_nakladu_2024.csv"), show_col_types = FALSE) %>%
  mutate(nace = ifelse(nace == "C19-C20", "C20", nace)) %>%   # Unipetrol RPA: rafinerie + vodík -> chemie
  group_by(nace) %>% summarise(comp_meur = sum(kompenzace_kc) / EUR_CZK_2024 / 1e6, .groups = "drop")
komp <- bind_rows(komp, tibble(nace = "C", comp_meur = sum(komp$comp_meur)))

# Odečet elektřiny, která nepochází ze sítě (data/manual/vlastni_elektrina_odecet.csv):
#  a) vlastní výroba oboru podle PEFA (dodávka elektřiny oborem, SUP P26) – firma ji nekupuje za síťovou cenu;
#     je-li z fosilních paliv, její povolenky už jsou v přímém nákladu, z biomasy nenese náklad ETS vůbec;
#  b) energetiky, které PEFA vede v energetice (D35), ale v přímém nákladu je přiřazujeme oboru (Energetika Třinec, ŠKO-ENERGO).
own_raw <- read_csv(file.path(DIR_MANUAL, "vlastni_elektrina_odecet.csv"), show_col_types = FALSE) %>%
  mutate(own_tj = tj * podil_obor)
own <- own_raw %>% filter(nace != "C_ostatni") %>% group_by(nace) %>% summarise(own_tj = sum(own_tj), .groups = "drop")
own <- bind_rows(own, tibble(nace = "C", own_tj = sum(own_raw$own_tj)))

costs <- gva %>%
  left_join(sbs, by = "nace") %>%
  left_join(elec, by = "nace") %>%
  left_join(direct, by = "nace") %>%
  left_join(komp, by = "nace") %>%
  left_join(own, by = "nace") %>%
  mutate(
    name            = NACE_NAMES[nace],
    # nepřímé náklady v ceně elektřiny (horní odhad, bez kompenzace): TJ -> MWh × t/MWh × €/t
    indirect_meur   = elec_tj / 3.6 * 1000 * EF_ELEC * price_cost / 1e6,
    # nejlepší odhad: jen elektřina ze sítě (bez vlastní výroby a energetik započtených v přímém nákladu)
    indirect_best_meur = (elec_tj - coalesce(own_tj, 0)) / 3.6 * 1000 * EF_ELEC * price_cost / 1e6,
    indirect_best_pct_gva = indirect_best_meur / gva_meur * 100,
    energy_pct_gva  = energy_meur / gva_meur * 100,
    indirect_pct_gva = indirect_meur / gva_meur * 100,
    direct_pct_gva  = direct_meur / gva_meur * 100,
    # na 100 € tržeb
    labour_per100   = labour_meur / turnover_meur * 100,
    energy_per100   = energy_meur / turnover_meur * 100,
    indirect_per100 = indirect_meur / turnover_meur * 100,
    direct_per100   = direct_meur / turnover_meur * 100,
    direct_low_pct_gva = direct_low_meur / gva_meur * 100,
    direct_low_per100  = direct_low_meur / turnover_meur * 100,
    direct_best_pct_gva = direct_best_meur / gva_meur * 100,
    direct_best_per100  = direct_best_meur / turnover_meur * 100,
    comp_pct_indirect   = comp_meur / indirect_meur * 100,
    comp_pct_indirect_best = comp_meur / indirect_best_meur * 100,
    indirect_net_pct_gva = (indirect_meur - coalesce(comp_meur, 0)) / gva_meur * 100,
    share_gva_c     = gva_meur / gva_meur[nace == "C"] * 100
  )
write_csv(costs, file.path(DIR_OUT, "ets_costs_2024.csv"))

# Časová řada všech průmyslových zařízení (slide 22)
ts <- reg %>% group_by(year) %>%
  summarise(free_alloc_mt = sum(free_alloc) / 1e6, verified_mt = sum(verified_em) / 1e6,
            free_alloc_proc_mt = sum(free_alloc[source == "proc"]) / 1e6,
            verified_proc_mt   = sum(verified_em[source == "proc"]) / 1e6,
            net_mt = sum(net_t) / 1e6, net_eur_m = sum(net_eur_m), .groups = "drop") %>%
  left_join(EUA_PRICE, by = "year") %>%
  mutate(coverage_pct = free_alloc_mt / verified_mt * 100)
write_csv(ts, file.path(DIR_OUT, "ets_timeseries.csv"))

# Hutě podle lokalit (slide 18): Ostrava = Liberty + TAMEH, Třinec = TŽ + Energetika Třinec
SITES <- c(`73` = "Ostrava", `410` = "Ostrava", `421` = "Ostrava", `114` = "Třinec", `252` = "Třinec")
steel <- read_csv(file.path(DIR_OUT, "registry_installations.csv"), show_col_types = FALSE) %>%
  filter(nace == "C24") %>%
  mutate(site = coalesce(unname(SITES[as.character(installation_id)]), "ostatní"),
         net = coalesce(verified_em, 0) - coalesce(free_alloc, 0)) %>%
  group_by(site, year) %>%
  summarise(verified_kt = sum(verified_em, na.rm = TRUE) / 1e3, free_alloc_kt = sum(free_alloc, na.rm = TRUE) / 1e3,
            net_kt = sum(net) / 1e3, .groups = "drop")
write_csv(steel, file.path(DIR_OUT, "steel_sites.csv"))

cum <- reg %>% group_by(nace) %>% summarise(net_mt = sum(net_t) / 1e6, net_eur_m = sum(net_eur_m))
write_csv(cum, file.path(DIR_OUT, "ets_cumulative_2013_2025.csv"))

message(sprintf("03_ets_costs: přímý náklad průmyslu %s mil. € = %.2f %% HPH; kumulativně 2013–2025 %.1f Mt, %.2f mld. €",
                round(direct$direct_meur[direct$nace == "C"], 1),
                costs$direct_pct_gva[costs$nace == "C"], sum(cum$net_mt), sum(cum$net_eur_m) / 1000))
