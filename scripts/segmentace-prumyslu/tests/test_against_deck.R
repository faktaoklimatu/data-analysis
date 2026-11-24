# Kontrola, že skripty dávají čísla uvedená v prezentaci v8.
# Spuštění s testovacími daty:  FOK_EUROSTAT_DIR=tests/fixtures Rscript tests/test_against_deck.R
source("R/00_setup.R")
for (f in c("R/02_registry.R", "R/03_ets_costs.R", "R/04_intensity.R", "R/05_regions.R")) source(f, encoding = "UTF-8")
chk <- function(label, x, target, tol) {
  ok <- abs(x - target) <= tol
  cat(sprintf("%-55s %10.3f  (prezentace %s)  %s\n", label, x, format(target), if (ok) "OK" else "!! ROZDÍL"))
  invisible(ok)
}
c24 <- read_csv("out/ets_costs_2024.csv", show_col_types = FALSE)
ts  <- read_csv("out/ets_timeseries.csv", show_col_types = FALSE)
st  <- read_csv("out/intensity_stats.csv", show_col_types = FALSE)
rs  <- read_csv("out/regions_stats.csv", show_col_types = FALSE)
res <- c(
  chk("Přímý náklad ETS, průmysl celkem, % HPH 2024", c24$direct_pct_gva[c24$nace == "C"], 0.3, 0.05),
  chk("Přímý náklad ETS, chemie, % HPH 2024",          c24$direct_pct_gva[c24$nace == "C20"], 7.1, 0.05),
  chk("Přímý náklad ETS, hutě, % HPH 2024",            c24$direct_pct_gva[c24$nace == "C24"], 2.1, 0.05),
  chk("Nepřímý náklad ETS, hutě, % HPH",               c24$indirect_pct_gva[c24$nace == "C24"], 10.8, 0.05),
  chk("Nákupy energie, hutě, % HPH",                   c24$energy_pct_gva[c24$nace == "C24"], 53.6, 0.1),
  chk("Deficit povolenek 2013–2025, Mt",               sum(ts$net_mt), 57, 0.5),
  chk("Deficit povolenek 2013–2025, mld. €",           sum(ts$net_eur_m) / 1000, 2.0, 0.05),
  chk("Slide 11: trend na 10× náročnost, p. b.",       st$slope_per_10x[1], -18.4, 0.1),
  chk("Slide 11: korelace",                            st$corr[1], -0.29, 0.005),
  chk("Slide 24: korelace kraje",                      rs$corr_all, 0.05, 0.01),
  chk("Slide 24: podíl MSK + Ústecký na emisích, %",   rs$share_msk_ust, 68, 0.5),
  chk("Slide 10: hutě, nejlepší odhad (Energetika Třinec 86,5 %), % HPH", c24$direct_best_pct_gva[c24$nace == "C24"], 1.1, 0.05),
  chk("Slide 10: hutě, dolní odhad (jen procesní), % HPH", c24$direct_low_pct_gva[c24$nace == "C24"], -5.2, 0.05),
  chk("Slide 10: chemie, dolní odhad (jen procesní), % HPH", c24$direct_low_pct_gva[c24$nace == "C20"], -0.3, 0.05),
  chk("Slide 24: Severozápad, místa v energeticky náročných oborech, %",
      read_csv("out/regions_ei_jobs.csv", show_col_types = FALSE) %>% filter(geo == "CZ04") %>% pull(ei_share_pct), 22, 0.5)
)
# v14: nové slajdy (spustí se, jen pokud existují výstupy skriptů 08–10)
if (file.exists("out/energy_prices_real.csv")) {
  ep <- read_csv("out/energy_prices_real.csv", show_col_types = FALSE)
  res <- c(res,
    chk("Slide 15: elektřina CZ reálně ×", ep$el_real_multiple[ep$geo == "CZ"], 2.0, 0.05),
    chk("Slide 15: plyn CZ reálně ×",      ep$gas_real_multiple[ep$geo == "CZ"], 1.6, 0.05),
    chk("Slide 15: plyn CZ 2025, €/MWh",   ep$gas_2025[ep$geo == "CZ"], 50.6, 0.5))
}
if (file.exists("out/io_metals.csv")) {
  io <- read_csv("out/io_metals.csv", show_col_types = FALSE)
  res <- c(res, chk("Slide 22: kovy v autech, % produkce", io$approx_total_pct[io$nace == "C29"], 5.3, 0.1),
                chk("Slide 22: kovy v kovovýrobě, % produkce", io$approx_total_pct[io$nace == "C25"], 24.7, 0.1))
}
if (file.exists("out/production_index_annual.csv")) {
  pa <- read_csv("out/production_index_annual.csv", show_col_types = FALSE) %>% filter(time == 2025) %>%
    select(geo, nace, index_2015) %>% pivot_wider(names_from = geo, values_from = index_2015)
  res <- c(res, chk("Slide 6: oborů, kde ČR roste rychleji než DE", sum(pa$CZ > pa$DE, na.rm = TRUE), 17, 0))
}
cat(if (all(res)) "\nVšechny kontroly prošly.\n" else "\nNěkteré kontroly neprošly.\n")
