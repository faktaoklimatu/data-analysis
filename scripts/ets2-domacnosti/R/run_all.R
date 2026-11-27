# run_all.R – celá dopadová analýza ETS2 (working directory = scripts/ets2-domacnosti/R)
# 01 a 03, 05: publikované tabulky ČSÚ (nepotřebují mikrodata); ENERGO 2021 je volitelné (jen kontroly v 08 a 09)
# 09: archetypy ze SILC (bydlení) + SRÚ (PHM), Documents/ČSÚ/MF_SILC 2015-2024 a SRU; srovnání s 07
# 11: kompenzace – kdo by dostal podporu podle různých pravidel (navazuje na objekt s z 09)
# 12: orientační cena 1 kWh tepla podle zdroje, dnes a s ETS2 (z výstupů 05 a 08)
# 10: mapa ORP pro blog (data/mf/ + SLDB 2021, výstup output/ a WEB_DIR/_data/ets2/)
# 13: agregovaná data pro grafy na webu (WEB_DIR/_data/ets2/; Eurostat API, potřebuje internet)
# Ceny ČSÚ: stáhnou se automaticky, pokud ještě nejsou (smaž složku ceny/ pro nové stažení)
if (!dir.exists(file.path(path.expand(Sys.getenv("ETS2_CSU_DIR", "~/Documents/ČSÚ")), "ceny"))) { cat("\n\n######## 00_stahni_csu.R ########\n"); source("00_stahni_csu.R") }
for (skript in c("08_ceny_csu.R", "01_csu_typove.R", "03_typove_domacnosti.R", "05_citlivost.R",
            # 04, 06, 07 (starší větev nad ENERGO) a 08a (diagnostika, SILC 2022) se nespouští, jen ručně
            "09_silc_archetypy.R", "11_kompenzace_nastroje.R", "12_cena_tepla.R")) {
  cat("\n\n######## ", skript, " ########\n"); source(skript, echo = FALSE)
}
# 10: podklad pro mapu v blogu (MF ukazatel energetické chudoby podle SO ORP); potřebuje internet (RCzechia stahuje hranice ORP)
cat("\n\n######## 10_mapa_orp.R ########\n")
source("10_mapa_orp.R", echo = FALSE)   # chyba (např. bez internetu) běh zastaví
cat("\n\n######## 13_data_web.R ########\n")
source("13_data_web.R", echo = FALSE)   # chyba (např. bez internetu) běh zastaví
