# =============================================================================
# 11_hph_zamestnanost.R – velikost oborů a exportní jádro (str. 5, 6, 20)
# Eurostat nama_10_a64 (HPH B1G, náhrady zaměstnancům D1; mil. € b. c.) a
#          nama_10_a64_e (pracující EMP_DC, zaměstnanci SAL_DC; tis. osob), ČR 2015–2025
# Výstup: out/obory_velikost_2025.csv  – HPH, podíl na HPH průmyslu, pracující, skupina (str. 5, 6)
#         out/exportni_jadro_prace.csv  – náklady práce na zaměstnance a výroba na pracujícího,
#                                          2015 = 100, auta a stroje (str. 20)
# =============================================================================
source("R/00_setup.R")
options(fok.no_download = TRUE); source("R/01_download_eurostat.R", encoding = "UTF-8"); options(fok.no_download = FALSE)

OBORY <- setdiff(names(NACE_NAMES), "C")              # 19 oborů vč. rafinerií C19
f_a <- file.path(DIR_ES, "nama_10_a64_CZ.csv"); f_e <- file.path(DIR_ES, "nama_10_a64_e_CZ.csv")
if (stahnout(f_a)) es_save(es_get("nama_10_a64", list(geo = "CZ", na_item = c("B1G", "D1"), unit = "CP_MEUR",
                                                         nace_r2 = to_es(c("C", OBORY)), time = 2015:2025)), "nama_10_a64_CZ")
if (stahnout(f_e)) es_save(es_get("nama_10_a64_e", list(geo = "CZ", na_item = c("EMP_DC", "SAL_DC"), unit = "THS_PER",
                                                           nace_r2 = to_es(c("C", OBORY)), time = 2015:2025)), "nama_10_a64_e_CZ")

nama <- bind_rows(es_read("nama_10_a64_CZ"), es_read("nama_10_a64_e_CZ")) %>%
  transmute(nace = from_es(nace_r2), na_item, time, values) %>%
  pivot_wider(names_from = na_item, values_from = values)

# --- Str. 5, 6: velikost oborů 2025 ---------------------------------------------
# Podíl se počítá ze součtu 18 oborů bez rafinerií (C19), jak uvádí slajd („Bez rafinerií“).
# Součet 18 oborů = C − C19 (rozdíl jen zaokrouhlení v datech Eurostatu).
vel <- nama %>% filter(time == 2025, nace %in% setdiff(OBORY, "C19")) %>%
  transmute(nace, name = NACE_NAMES[nace], hph_meur = B1G, pracujici_tis = EMP_DC,
            podil_hph_pct = B1G / sum(B1G) * 100,
            skupina = case_when(nace %in% SKUPINA_EXPORT ~ "exportní jádro",
                                nace %in% SKUPINA_ENERGIE ~ "energeticky nejnáročnější",
                                TRUE ~ "ostatní")) %>%
  arrange(desc(hph_meur))
write_csv(vel, file.path(DIR_OUT, "obory_velikost_2025.csv"))

# --- Str. 20: mzdy vs. produktivita (auta, stroje) ------------------------------
# náklady práce na zaměstnance = D1 / SAL_DC; výroba na pracujícího = index výroby (sts_inpr_a) / EMP_DC
sts <- es_read("sts_inpr_a_annual") %>% filter(geo == "CZ") %>% transmute(nace = nace_r2, time, vyroba = values)
prace <- nama %>% filter(nace %in% c("C28", "C29")) %>%
  inner_join(sts, by = c("nace", "time")) %>%
  group_by(nace) %>% arrange(time) %>%
  mutate(naklady_prace_na_zam = D1 / SAL_DC * 1000,          # € na zaměstnance (mil. € / tis. osob × 1000)
         vyroba_na_prac       = vyroba / EMP_DC,
         naklady_prace_idx    = naklady_prace_na_zam / first(naklady_prace_na_zam) * 100,
         vyroba_na_prac_idx   = vyroba_na_prac / first(vyroba_na_prac) * 100) %>%
  ungroup() %>% select(nace, time, D1, SAL_DC, EMP_DC, vyroba, naklady_prace_na_zam, naklady_prace_idx, vyroba_na_prac_idx)
write_csv(prace, file.path(DIR_OUT, "exportni_jadro_prace.csv"))

message(sprintf("11_hph_zamestnanost: HPH 18 oborů 2025 = %.0f mil. €; auta náklady práce/zam. %+.0f %%, výroba/prac. %+.0f %% (2015→2025)",
                sum(vel$hph_meur), prace$naklady_prace_idx[prace$nace == "C29" & prace$time == 2025] - 100,
                prace$vyroba_na_prac_idx[prace$nace == "C29" & prace$time == 2025] - 100))

# --- Str. 20: dovoz aut z Číny do EU --------------------------------------------
# Eurostat Comext DS-059341 (obchod podle HS 2-4-6), dovoz (flow 1) EU27 z Číny, HS 8703 osobní auta, €
f_c <- file.path(DIR_ES, "comext_8703_CN.csv")
if (stahnout(f_c)) es_save(es_get("DS-059341", list(reporter = "EU27_2020", partner = "CN", product = "8703", flow = 1,
                                                       indicators = "VALUE_EUR", freq = "A"), api = COMEXT_API), "comext_8703_CN")
cina <- es_read("comext_8703_CN") %>% filter(time >= 2015) %>% transmute(rok = time, dovoz_mld_eur = values / 1e9)
write_csv(cina, file.path(DIR_OUT, "dovoz_aut_cina_eu.csv"))
