# 02_parametry.R – všechny vstupní parametry (rok 2028). Zdroje a odkazy viz ../inputs.csv a ../METODIKA.md
p <- list()
p$HICP <- c(2.89, 9.19, 6.36, 2.60, 2.46, 3.0, 2.5, 2.1)   # EU HICP 2021–2028 (%): 2021–25 Eurostat prc_hicp_aind (EU27_2020),
                                                        # 2026–28 projekce ECB (září 2026, eurozóna; EU leden–říjen 2026 průměr 3,0 %)
p$HICP_INDEX <- prod(1 + p$HICP / 100)                 # 2020 -> 2028
p$CENY_2026_NA_2028 <- prod(1 + p$HICP[7:8] / 100)    # ceny energií 2026 -> 2028 (stejný rok jako povolenka a příjmy)
p$SCEN <- c(A_hranice_45EUR2020 = 45 * p$HICP_INDEX,   # ~61 €/t (do 26. 11. 2026 60 €/t)
            B_futures_Dec28     = 76.47)               # EUA2 Dec-28, 1. 10. 2026
p$FX  <- 24.2                                          # CZK/EUR 2028, ČNB podzim 2026 (prognóza 5. 11. 2026)
p$VAT <- c(std = 1.21, teplo = 1.12)
# Vývoj emisí v sektorech ETS2 pro odhad výnosu 2028–2032 (13_data_web.R, tok peněz), od posledního roku inventury:
# budovy −3 % ročně (trend 2015–2024 −4 %, rok 2024 teplý), doprava 0 % (trend +2 %, ale elektroauta a limity CO2),
# reakce na cenu ETS2 od 2028 −2,5 % (krátkodobá elasticita ~−0,2 × zdražení paliv ~12 %). Rozhodnutí 23. 11. 2026.
p$EM_TREND <- c(doprava = 0, budovy = -0.03)
p$EM_REAKCE_ETS2 <- -0.025
# citlivost: tempo změn 2025→2030 ve scénáři WEM projekcí ČHMÚ (2025, tab. 1a), přenesené na skutečné emise 2024
p$EM_TREND_WEM <- c(doprava = (13.78 / 15.56)^(1/5) - 1, budovy = ((5.83 + 3.57) / (8.19 + 3.18))^(1/5) - 1)
p$EF  <- c(plyn = 55.61, hnede = 99.05, cerne = 94.04, koks = 107.0, brikety_uhelne = 97.50,
           lpg = 65.86, topny_olej = 74.10)            # t CO2/TJ (ČHMÚ, národní hodnoty pro ETS2)
p$NCV <- c(hnede = 17.6, cerne = 27.5, koks = 28.12, brikety_uhelne = 23.12, lpg = 45.95,
           topny_olej = 43.11)                         # GJ/t
p$GAS_KWH_PER_M3_GCV <- 10.6
p$GAS_NCV_MJ_M3 <- 34.72
p$GAS_NCV_TO_GCV <- p$GAS_NCV_MJ_M3 / (p$GAS_KWH_PER_M3_GCV * 3.6)
p$TOPNY_OLEJ_KG_L <- 0.84
p$DT_EFF_ZDROJ <- 0.90
p$DT_ZTRATY <- 0.15
p$DT_KG_PER_GJ <- p$EF[["plyn"]] / (p$DT_EFF_ZDROJ * (1 - p$DT_ZTRATY))
p$DT_PODIL_ETS2 <- 0.25                                # odhad, k ověření (ERÚ)
p$KG_L <- c(benzin = 2.16, nafta = 2.52)               # kg CO2 / prodaný litr vč. biosložky
p$CENA <- c(plyn_kc_kwh = 2.433, hnede_kc_q = 680, cerne_kc_q = 870, teplo_kc_gj = 1130,
            benzin_kc_l = 38.64, nafta_kc_l = 39.35, lpg_kc_kg = 40.06, olej_kc_l = 30)   # ČSÚ, viz 08_ceny_csu.R; hnědé uhlí = ceníky 2026 (dříve 696), teplo = ERÚ 2024 malé plynové zdroje × HICP (dříve 1169 z ENERGO)
# Výchozí výdaje na energie (07): výdaje 2021 z ENERGO × index HICP ČR 2025/2021 (Eurostat prc_hicp_aind)
p$INDEX_ELEKTRINA <- 7.128 / 5.0155   # ČSÚ CEN0101KT01: 1. pol. 2026 / průměr 2021
p$INDEX_TUHA      <- 198.9 / 114.3   # CP0454 tuhá paliva (dřevo, pelety)
p$UPRATE <- 49215 / 37839 * 1.020 * 1.025 * 1.024     # příjmy 2021 -> 2028
p$HRUBA_NA_CISTOU <- 0.78
# Typové domácnosti (03): výdaje na dřevo/pelety, aby % zdražení vytápění mělo ve jmenovateli všechna paliva (z 06)
p$BIOMASA_KC_2021 <- c(`RD plyn` = 699, `RD hnědé uhlí` = 2774, `RD hnědé uhlí + dřevo` = 4308, `RD hnědé uhlí bez dřeva` = 596,
                       `RD černé uhlí (citlivost)` = 3040, `BJ plyn` = 26, `BJ dálkové teplo (zdroj v ETS2)` = 0)
# PHM na DOMÁCNOST s autem (ne na auto; domácnost má v průměru 1,13 auta), mikrodata ENERGO 2021 (06)
p$PHM_L_DOMACNOST <- 786.6
p$PODIL_NAFTY_DOMACNOST <- 0.439
str(p)
# --- typové domácnosti z publikovaných tabulek ČSÚ ---
p$POMER_UHLI_S_DREVEM  <- 0.8616   # průměr RD hnědé + dřevo / všichni RD na hnědé (mikrodata ENERGO, viz 06)
p$POMER_UHLI_BEZ_DREVA <- 1.2061   # průměr RD hnědé bez dřeva / všichni
p$T_CO2_NA_M3_PLYNU <- p$GAS_NCV_MJ_M3 * p$EF[["plyn"]] / 1e6
