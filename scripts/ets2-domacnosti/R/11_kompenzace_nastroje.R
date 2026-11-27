# 11_kompenzace_nastroje.R – kdo by dostal kompenzaci ETS2 podle různých pravidel (SILC 2024)
#
# Otázka: naše „zranitelné domácnosti“ (R/09) úřady identifikovat neumějí (neznají palivo ani dopad ETS2).
# Jak dobře je zasáhnou nástroje, které stojí na údajích, jež stát má?
#
# Pro každé pravidlo: kdo dostane jakou částku -> měříme
#   naklad_mld        roční náklad (mld. Kč, ceny a příjmy 2028)
#   podil_k_zranit    kolik % peněz skončí u zranitelných (zbytek = únik)
#   pokryti_zranit    kolik % zranitelných dostane aspoň něco (zbytek = mezery)
#   vyrovnano_zranit  kolik % souhrnného dopadu ETS2 na zranitelné podpora vyrovná (sum min(platba, dopad) / sum dopad)
#   plne_vyrovnani    kolik % zranitelných dostane aspoň celý svůj dopad
# Vše ve scénáři A a B (cena povolenky).
#
# Pravidla (částka vždy měsíčně):
#   0 ideal          každé zranitelné domácnosti přesně její dopad (srovnávací strop: dokonalé cílení)
#   1 plosne         stejná částka všem domácnostem
#   2 decily_1_4     stejná částka domácnostem v 1.–4. decilu (cílení jen podle příjmu)
#   3 davky_bydleni  stejná částka příjemcům dávek na bydlení (SILC 2024: příspěvek na bydlení PBYDL nebo
#                    dávky hmotné nouze HM_NOUZE > 0) – přiblížení dnešní superdávky (v SILC podhlášeno)
#   4 paq_pausal     příjemci dávek na bydlení: +20 % energetického paušálu (460–860 Kč podle velikosti), návrh PAQ a CVF
#   5 decily_1_4_RD  stejná částka 1.–4. decilu v rodinných domech (příjem + typ bydlení, oboje úřad ověří)
#   9 RD_zaklad_tuha 1.–4. decil v RD 600 Kč + RD na tuhá paliva (uhlí i dřevo) příplatek 850 Kč (scénář A; B úměrně) – příklad do textu
#  10 RD_tuha_taper  jako 9, ale místo ostré hranice postupné snižování (plně do 3. decilu, nula na hranici 5. decilu)
#  11 RD_byt_plyn    10 + byty s vlastním plynovým kotlem 570 Kč (A)
#  12 RD_byty_vse    11 + byty na teple ze zdroje v ETS2 500 Kč (A)
#  13 pal_vlastni    nárok podle vlastního fosilního vytápění k rozhodnému dni (kap. 5.2 návrhu): RD uhlí/dřevo, RD plyn,
#                    byt plyn; částka = průměrný dopad ETS2 na zranitelné v dané skupině (zaokrouhleno na 10 Kč), se snižováním.
#                    Pozn.: „byt plyn“ v SILC (BD & ZDROJ_ENER 2) zahrnuje i domovní kotelny – nejdou odlišit.
#  14 pal_vlastni_teplo  13 + byty na teple ze zdroje v ETS2 (přes adresy od dodavatele), částka stejně
#  15 duchod_podm    jako 14, ale jen domácnostem s důchodcem (PRDUCH + NPDUCH > 0) – příplatek k důchodu vyplácený ČSSZ,
#                    podmíněný příjmem domácnosti a palivem. Doplněk přes úřad práce pro domácnosti bez důchodce = rozdíl 14 − 15
#                    (14 a „15 + doplněk“ jsou tedy totéž pravidlo, liší se jen kanálem výplaty).
#   7 paq_balik      celý návrh PAQ a CVF: sleva na poplatníka + valorizace důchodů + paušál (sleva a důchody nejdou ze SKF)
#   8 paq_bez_slevy  totéž bez slevy na poplatníka
#   6 decily_1_4_pal stejná částka 1.–4. decilu, které topí uhlím/dřevem nebo plynem (příjem + palivo – vyžaduje údaj o palivu)
# Jednotná částka u 1, 2, 3, 5, 6 = průměrný dopad ETS2 na zranitelnou domácnost v daném scénáři.
#
# Populace: všechny domácnosti; byty na teple rozdělené na část v ETS2 (podíl f_teplo_ets2 z 09, s nákladem na vytápění)
# a část mimo ETS2 (zbytek váhy, jen PHM, nezranitelné) – stejně jako počty v R/09.
# Spuštění: z ETS2/R po 09_silc_archetypy.R (v run_all.R ve stejném prostředí); jinak si 09 spustí sám.
# Výstup: output/11_kompenzace_nastroje.csv

suppressPackageStartupMessages({ library(dplyr); library(readr); library(tidyr) })
if (!exists("s") || !is.data.frame(s) || !"f_teplo_ets2" %in% names(s)) source("09_silc_archetypy.R", echo = FALSE)
OUT_DIR <- if (exists("OUT_DIR")) OUT_DIR else "output"

# dávky na bydlení ze SILC (ročně, Kč)
dav <- cti_silc_h(SILC_ROK) %>%
  transmute(DOMAC_ID = num(DOMAC_ID), pbydl = coalesce(num(PBYDL), 0), hmn = coalesce(num(HM_NOUZE), 0),
            n_ea = coalesce(num(EA), 0), n_duch = coalesce(num(PRDUCH), 0) + coalesce(num(NPDUCH), 0))
x <- s %>% left_join(dav, by = "DOMAC_ID") %>%
  mutate(davka_bydleni = (pbydl > 0) | (hmn > 0))

# rozdělení bytů na teple na část v ETS2 a mimo
# (podíl v ETS2 je u každé domácnosti zvlášť, f_teplo_ets2 z 09 – podle kraje, viz TEPLO_VAHA_KRAJ)
# od B3 (25. 11. 2026) je rozdělení na zdroj v ETS2 / ETS1 už v s z 09 (sloupec ut_ets2), tady jen převzít
x_in <- x %>% mutate(w_pop = w, teplo_v_ets2 = archetyp == TEPLO & ut_ets2)
pop <- x_in %>% filter(!is.na(prijem_rok), prijem_rok > 0)

# valorizace: PAQ 5,54 mld. Kč/rok; SILC počítá všechny důchodce (PRDUCH + NPDUCH, 2,7 mil.) -> částka kalibrovaná na stejný úhrn
DUCH_KC <- 5.54e9 / 12 / sum((coalesce(num(dav$n_duch), 0))[match(pop$DOMAC_ID, dav$DOMAC_ID)] * pop$w_pop)
pausal <- function(n) c(2300, 2800, 3300, 3800, 4300)[pmin(pmax(n, 1), 5)]   # Kč/měsíc, zákon 151/2025 Sb.
pal_ets2 <- pop$archetyp %in% c("RD uhlí", "RD plyn", "byt plyn") | (pop$ZDROJ_ENER %in% c(2, 3))

# postupné snižování (taper): plná platba do horní hranice 3. decilu ekvivalizovaného příjmu (příjem / odmocnina z počtu osob),
# pak lineárně k nule na horní hranici 5. decilu -> žádný skok na hranici nároku
eq <- pop$prijem_rok / pop$sj   # spotřební jednotky OECD (SJ), stejně jako decily v 09 (C8)
wq <- function(x, w, p) { o <- order(x); cw <- cumsum(w[o]) / sum(w); x[o][which(cw >= p)[1]] }
EQ_P30 <- wq(eq, pop$w_pop, 0.3); EQ_P50 <- wq(eq, pop$w_pop, 0.5)
taper <- pmin(1, pmax(0, (EQ_P50 - eq) / (EQ_P50 - EQ_P30)))
cat("Taper: plná platba do", round(EQ_P30 / 12), "Kč/měs. (ekviv.), nula od", round(EQ_P50 / 12), "Kč/měs.\n")

CASTKY <- list()
vyhodnot <- function(sc) {
  dopad <- pop[[paste0(sc, "_vytapeni")]]   # jen vytápění, PHM se nekompenzují (změna 23. 11. 2026)                    # Kč/rok
  z <- pop$zranitelne; wt <- pop$w_pop
  prum_z <- sum(dopad[z] * wt[z]) / sum(wt[z])               # průměrný dopad na zranitelnou domácnost, Kč/rok
  d14 <- pop$decil %in% 1:4
  # částky pro 13/14: průměrný dopad na zranitelné ve skupině, Kč/rok (zaokrouhleno na 10 Kč měsíčně)
  skup_pal <- ifelse(pop$teplo_v_ets2, "teplo", ifelse(pop$archetyp %in% c("RD uhlí", "RD plyn", "byt plyn"), pop$archetyp, NA))
  # výše platby = průměrné zdražení HLAVNÍHO zdroje vytápění u zranitelných ve skupině (25. 11. 2026; platba se řídí
  # jen hlavním zdrojem, vedlejší plyn/uhlí nevyrovnává). Hodnotí se ale proti celému zdražení vytápění (dopad).
  hlavni <- dplyr::case_when(pop$ZDROJ_ENER %in% 2 ~ pop[[paste0(sc, "_plyn")]] + ifelse(pop$ut_ets2, pop[[paste0(sc, "_teplo")]], 0),
                             pop$ZDROJ_ENER %in% 3 ~ pop[[paste0(sc, "_uhli")]],
                             pop$VYTAPENI %in% 1 & pop$ut_ets2 ~ pop[[paste0(sc, "_teplo")]], TRUE ~ 0)
  cast_pal <- sapply(c("RD uhlí", "RD plyn", "byt plyn", "teplo"), function(g) {
    k <- z & skup_pal %in% g; round(sum(hlavni[k] * wt[k]) / sum(wt[k]) / 12, -1) * 12 })
  cat("Scénář", sc, "– částky pro nárok podle paliva (Kč/měs.):", paste(names(cast_pal), cast_pal / 12, collapse = " | "), "\n")
  CASTKY[[sc]] <<- cast_pal / 12
  pl_pal <- ifelse(is.na(skup_pal), 0, cast_pal[ifelse(is.na(skup_pal), "teplo", skup_pal)])
  pravidla <- list(
    ideal          = ifelse(z, dopad, 0),
    plosne         = rep(prum_z, nrow(pop)),
    decily_1_4     = ifelse(d14, prum_z, 0),
    davky_bydleni  = ifelse(pop$davka_bydleni, prum_z, 0),
    paq_pausal     = ifelse(pop$davka_bydleni, 0.2 * pausal(pop$osoby) * 12, 0),
    decily_1_4_RD  = ifelse(d14 & pop$typ == "RD", prum_z, 0),
    decily_1_4_pal = ifelse(d14 & pal_ets2, prum_z, 0),
    # příklad do textu: základ pro 1.–4. decil v RD + příplatek RD na tuhá paliva (uhlí i dřevo, nárok k rozhodnému dni);
    # historická pravidla (říjen 2026): částky 600 + 850 Kč/měsíc odvozené od tehdejšího průměrného dopadu 779 Kč;
    # teď se jen škálují poměrem k aktuálnímu prum_z, slouží ke srovnání, hlavní návrh je pal_vlastni_teplo
    RD_zaklad_tuha = ifelse(d14 & pop$typ == "RD", prum_z * 600 / 779, 0) + ifelse(d14 & pop$archetyp == "RD uhlí", prum_z * 850 / 779, 0),
    # totéž s postupným snižováním místo ostré hranice 4. decilu
    RD_tuha_taper  = taper * (ifelse(pop$typ == "RD", prum_z * 600 / 779, 0) + ifelse(pop$archetyp == "RD uhlí", prum_z * 850 / 779, 0)),
    # + byty s vlastním plynovým kotlem (ověření přes odběrné místo plynu): 570 Kč (A), se snižováním
    RD_byt_plyn    = taper * (ifelse(pop$typ == "RD", prum_z * 600 / 779, 0) + ifelse(pop$archetyp == "RD uhlí", prum_z * 850 / 779, 0) +
                              ifelse(pop$archetyp == "byt plyn", prum_z * 570 / 779, 0)),
    # + byty na teple ze zdroje v ETS2 (ověření přes dodavatele tepla): 500 Kč (A), se snižováním
    RD_byty_vse    = taper * (ifelse(pop$typ == "RD", prum_z * 600 / 779, 0) + ifelse(pop$archetyp == "RD uhlí", prum_z * 850 / 779, 0) +
                              ifelse(pop$archetyp == "byt plyn", prum_z * 570 / 779, 0) + ifelse(pop$teplo_v_ets2, prum_z * 500 / 779, 0)),
    # nárok podle vlastního fosilního vytápění k rozhodnému dni (plyn přes odběrné místo, tuhá paliva přes kontrolu kotle)
    pal_vlastni       = taper * ifelse(skup_pal %in% c("RD uhlí", "RD plyn", "byt plyn"), pl_pal, 0),
    pal_vlastni_teplo = taper * pl_pal,
    # B1 (25. 11. 2026): doklad o kontrole kotle na tuhá paliva neodliší uhlí od dřeva -> horní mez: částku pro uhlí
    # dostanou i rodinné domy s hlavním zdrojem dřevo a biomasa (ZDROJ_ENER 4, vč. pelet)
    pal_vlastni_teplo_drevo = taper * ifelse(pop$typ == "RD" & pop$ZDROJ_ENER %in% 4, cast_pal["RD uhlí"], pl_pal),
    # varianta: stejná částka všem bytům na dálkovém teple (i ze zdroje v ETS1, kde ETS2 topení nezdraží)
    pal_vlastni_teplo_vse = taper * ifelse(pop$archetyp %in% c(TEPLO, TEPLO_ETS1), cast_pal["teplo"], pl_pal),
    duchod_podm       = taper * pl_pal * (pop$n_duch > 0),
    # celý balík PAQ a CVF (s. 24–28): sleva na poplatníka +1 200 Kč/rok každé ekonomicky aktivní osobě,
    # valorizace důchodů (úhrn 5,54 mld. Kč jako PAQ, rozložený na všechny důchodce v SILC), paušál +20 % příjemcům dávek na bydlení
    paq_balik      = pop$n_ea * 1200 + pop$n_duch * DUCH_KC * 12 + ifelse(pop$davka_bydleni, 0.2 * pausal(pop$osoby) * 12, 0),
    paq_bez_slevy  = pop$n_duch * DUCH_KC * 12 + ifelse(pop$davka_bydleni, 0.2 * pausal(pop$osoby) * 12, 0))
  bind_rows(lapply(names(pravidla), function(nm) {
    pl <- pravidla[[nm]]
    tibble(scenar = sc, pravidlo = nm,
           castka_kc_mesic = round(ifelse(nm %in% c("ideal", "paq_pausal", "paq_balik", "paq_bez_slevy", "RD_zaklad_tuha", "RD_tuha_taper", "RD_byt_plyn", "RD_byty_vse", "pal_vlastni", "pal_vlastni_teplo", "pal_vlastni_teplo_drevo", "pal_vlastni_teplo_vse", "duchod_podm"), NA, prum_z / 12)),
           prijemci_tis = round(sum(wt[pl > 0]) / 1000),
           prijemci_zranit_tis = round(sum(wt[pl > 0 & z]) / 1000),   # překryv oprávněných a zranitelných (27. 11. 2026)
           prijemci_osob_tis = round(sum((wt * pop$osoby)[pl > 0]) / 1000),
           naklad_mld = round(sum(pl * wt) / 1e9, 2),
           podil_k_zranit = round(100 * sum((pl * wt)[z]) / sum(pl * wt), 1),
           pokryti_zranit = round(100 * sum(wt[z & pl > 0]) / sum(wt[z]), 1),
           vyrovnano_zranit = round(100 * sum((pmin(pl, dopad) * wt)[z]) / sum((dopad * wt)[z]), 1),
           plne_vyrovnani = round(100 * sum(wt[z & pl >= dopad]) / sum(wt[z]), 1),
           vyrovnano_RD_tuha = round(100 * sum((pmin(pl, dopad) * wt)[z & pop$archetyp == "RD uhlí"]) / sum((dopad * wt)[z & pop$archetyp == "RD uhlí"]), 1),
           vyrovnano_RD_plyn = round(100 * sum((pmin(pl, dopad) * wt)[z & pop$archetyp == "RD plyn"]) / sum((dopad * wt)[z & pop$archetyp == "RD plyn"]), 1),
           vyrovnano_byty = round(100 * sum((pmin(pl, dopad) * wt)[z & pop$typ != "RD"]) / sum((dopad * wt)[z & pop$typ != "RD"]), 1))
  }))
}
vysl <- bind_rows(vyhodnot("A"), vyhodnot("B"))
write_csv(vysl, file.path(OUT_DIR, "11_kompenzace_nastroje.csv"))

# kontrola: počet zranitelných musí sedět s R/09 (zranitelne_tis_teplo_jen_ets2)
cat("\nKONTROLA: zranitelné domácnosti (tis.):", round(sum(pop$w_pop[pop$zranitelne]) / 1000, 1),
    "| příjemci dávek na bydlení v SILC (tis.):", round(sum(pop$w_pop[pop$davka_bydleni]) / 1000),
    "| z toho zranitelní (tis.):", round(sum(pop$w_pop[pop$davka_bydleni & pop$zranitelne]) / 1000), "\n")
cat("Zranitelní v RD s důchodcem v domácnosti (%):", round(100 * sum(pop$w_pop[pop$zranitelne & pop$typ == "RD" & pop$n_duch > 0]) / sum(pop$w_pop[pop$zranitelne & pop$typ == "RD"]), 1), "\n")
cat("Zranitelní s důchodcem v domácnosti (%):", round(100 * sum(pop$w_pop[pop$zranitelne & pop$n_duch > 0]) / sum(pop$w_pop[pop$zranitelne]), 1), "\n")
cat("Zranitelní podle archetypu, podíl s dávkou na bydlení (%):\n")
print(pop %>% filter(zranitelne) %>% group_by(archetyp) %>%
        summarise(tis = round(sum(w_pop) / 1000), s_davkou_pct = round(100 * sum(w_pop[davka_bydleni]) / sum(w_pop), 1),
                  n_vzorek = n()))
print(as.data.frame(vysl))

# --- B7 (25. 11. 2026): čísla citovaná v textu, která se dřív jen vypisovala do konzole ---
sj_typ <- c(jednotlivec = 1, par = 1.7, rodina_2_deti_do_13 = 2.7)   # spotřební jednotky OECD (SJ)
zr <- pop$zranitelne; wz <- pop$w_pop
param <- bind_rows(
  tibble(ukazatel = paste0("castka_A_", names(CASTKY$A)), hodnota = unname(CASTKY$A)),
  tibble(ukazatel = paste0("castka_B_", names(CASTKY$B)), hodnota = unname(CASTKY$B)),
  tibble(ukazatel = c("plna_platba_do_kc_mesic_na_SJ", "nulova_platba_od_kc_mesic_na_SJ"), hodnota = c(EQ_P30, EQ_P50) / 12),
  tibble(ukazatel = paste0("plna_platba_do_kc_mesic_", names(sj_typ)), hodnota = EQ_P30 / 12 * sj_typ),
  tibble(ukazatel = paste0("nulova_platba_od_kc_mesic_", names(sj_typ)), hodnota = EQ_P50 / 12 * sj_typ),
  tibble(ukazatel = c("zranitelne_tis", "zranitelne_s_davkou_na_bydleni_pct", "zranitelne_s_davkou_RD_uhli_pct",
                      "zranitelne_RD_s_duchodcem_pct", "zranitelne_s_duchodcem_pct"),
         hodnota = c(sum(wz[zr]) / 1000, 100 * sum(wz[zr & pop$davka_bydleni]) / sum(wz[zr]),
                     100 * sum(wz[zr & pop$davka_bydleni & pop$archetyp == "RD uhlí"]) / sum(wz[zr & pop$archetyp == "RD uhlí"]),
                     100 * sum(wz[zr & pop$typ == "RD" & pop$n_duch > 0]) / sum(wz[zr & pop$typ == "RD"]),
                     100 * sum(wz[zr & pop$n_duch > 0]) / sum(wz[zr]))),
  # valorizace důchodů (27. 11. 2026): o kolik ETS2 zvedne ceny (náklad ETS2 domácností / jejich výdaje, proxy z SILC:
  # podíl na čistém příjmu) a kolik zdražení vytápění by zranitelným s důchodcem vrátila valorizace o tuto inflaci
  tibble(ukazatel = c("ets2_naklad_pct_prijmu_vsech", "zranitelne_s_duchodcem_ets2_vytapeni_pct_prijmu",
                      "valorizace_vrati_zranitelnym_duchodcum_pct"),
         hodnota = {
           infl <- 100 * sum(pop$A_celkem * wz) / sum(pop$prijem_rok * wz)
           zd <- zr & pop$n_duch > 0
           zatez <- 100 * sum(pop$A_vytapeni[zd] * wz[zd]) / sum(pop$prijem_rok[zd] * wz[zd])
           c(infl, zatez, 100 * infl / zatez) })) |>
  mutate(hodnota = round(hodnota, 2))
write_csv(param, file.path(OUT_DIR, "11_kompenzace_parametry.csv")); print(param, n = 40)
