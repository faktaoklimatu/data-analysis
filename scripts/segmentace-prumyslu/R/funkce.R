# =============================================================================
# funkce.R – pomocné funkce sdílené více skripty (načítá je 00_setup.R)
# =============================================================================

# Složí index výroby sloučených oborů (C10-C12, C13-C15, C31_C32) ze složek,
# vážených přidanou hodnotou (weights: geo, nace_r2, w).
sts_composite <- function(sts, weights) {
  # Složky bez indexu (důvěrné, např. tabák C12 v ČR) nebo s nulovou vahou se vynechají
  # a váhy ostatních se přepočtou; složka musí mít index ve všech použitých letech.
  groups <- list("C10-C12" = c("C10", "C11", "C12"), "C13-C15" = c("C13", "C14", "C15"),
                 "C31_C32" = c("C31", "C32"))
  add <- bind_rows(lapply(names(groups), function(g) {
    sts %>% filter(nace_r2 %in% groups[[g]], !is.na(values)) %>%
      inner_join(weights, by = c("geo", "nace_r2")) %>%
      filter(!is.na(w), w > 0) %>%
      group_by(geo, nace_r2) %>% filter(n() == n_distinct(sts$time)) %>% ungroup() %>%
      group_by(geo, time) %>%
      summarise(values = weighted.mean(values, w), n_comp = n(), .groups = "drop") %>%
      mutate(nace_r2 = g)
  }))
  bind_rows(sts %>% filter(!nace_r2 %in% add$nace_r2), add %>% select(-n_comp))
}
