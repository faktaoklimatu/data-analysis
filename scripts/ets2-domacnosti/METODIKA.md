# Sociální klimatická politika (ETS2 a domácnosti): jak se co počítá

*Fakta o klimatu, stav k 23. 11. 2026. Popisuje jen aktuální výpočet, bez historie změn (ta je v `METODIKA.md`). Čísla v textu jsou pro orientaci, platí vždy výstupy skriptů.*

## 1. Základní předpoklady

| Parametr | Hodnota | Kde |
|---|---|---|
| Rok dopadu | 2028 (první rok ETS2) | |
| Cena povolenky, základní scénář | 45 € v cenách 2020 → asi 60 € za tunu v roce 2028 (HICP EU) | `R/02_parametry.R`, `p$SCEN` |
| Vyšší scénář (citlivost) | 76,47 € (futures EUA2 prosinec 2028, 1. 10. 2026) | tamtéž |
| Kurz | 24,2 Kč/€ (prognóza ČNB pro 2028, podzim 2026), jediný kurz pro celou studii | `p$FX` |
| DPH | 21 %, dálkové teplo 12 % | `p$VAT` |
| Přenos do cen | 100 %, bez změny chování domácností | |
| Emisní faktory | národní hodnoty ČHMÚ pro ETS2 | `p$EF` |

Náklad ETS2 pro domácnost = emise × cena povolenky × kurz × DPH.

## 2. Data

- **EU-SILC 2024 (ČSÚ, verze pro MF):** hlavní zdroj. Příjem, typ bydlení, způsob vytápění a náklady na energie u téže domácnosti, asi 8 500 domácností s váhami.
- **Statistika rodinných účtů (SRÚ) 2023:** pohonné hmoty (SILC je nemá) a podíl uhlí ve výdajích za tuhá paliva.
- **ČSÚ ENERGO 2021 (volitelné):** jen kontrola cen uhlí a tepla a emisí na korunu tuhých paliv; bez něj se kontroly přeskočí. Starší větev výpočtu nad ENERGO (04, 06, 07) a diagnostika 08a (SILC 2022) se v `run_all.R` nespouští.
- **ERÚ, výsledné ceny tepla 2024:** ceny tepla a určení, které lokality spadají pod ETS2.
- **SLDB 2021:** byty podle paliva po správních obvodech ORP (mapy).
- **Eurostat:** realizované ceny plynu (nrg_pc_202), energetická bilance (nrg_bal_c), inventura emisí (env_air_gge).
- **MF, Mikroregionální ukazatel energetické chudoby (2026):** mapa ohrožení.

Mikrodata (SILC, SRÚ, ENERGO) jsou jen lokálně v `~/Documents/ČSÚ`. Na web jdou jen agregáty.

## 3. Typy domácností (archetypy)

| Archetyp | Vymezení v SILC |
|---|---|
| Rodinný dům na uhlí | rodinný dům, hlavní zdroj tuhá paliva (uhlí) |
| Rodinný dům na plyn | rodinný dům, hlavní zdroj plyn |
| Byt na plyn | bytový dům, plyn (vlastní ústřední/etážové topení nebo lokální topidla; domovní kotelna je v SILC „dálkové teplo“) |
| Byt na teple ze zdroje v ETS2 | bytový dům na dálkovém teple ze zdroje, který by spadal pod ETS2 |
| Byt na teple ze zdroje v ETS1 | ostatní byty na dálkovém teple; ETS2 jim topení nezdraží, zranitelnost se neposuzuje |
| Ostatní | dřevo, elektřina, tepelné čerpadlo, jiné (rozpad v `09_silc_ostatni.csv`) |

**Dálkové teplo v ETS2.** SILC zdroj tepla nezná. Zdroj v ETS2 = cenová lokalita ERÚ do 20 MWt, uhlí + plyn aspoň 50 % a dodané teplo nejvýš výkon × 3 000 h × 3,6 GJ/MWh (větší dodávka znamená nákup tepla z velkého zdroje v ETS1). Váha bytů na teple se násobí podílem tepla ze zdrojů v ETS2 v kraji a celek se škáluje na asi 380 tis. domácností (dashboard tepláren FoK). Je to spíš dolní odhad. Stejnou krajskou pravděpodobnost dostávají i domácnosti jiných archetypů s platbou za ústřední topení, celkem je tak na zdroji v ETS2 asi 419 tis. domácností. Ponecháno záměrně: 380 tis. z dashboardu zahrnuje jen licencované zdroje, nelicencované domovní kotelny na plyn (také v ETS2) v něm chybí. Citlivost s kalibrací na všechny domácnosti s ústředním topením (celkem 380 tis.): 185 tis. zranitelných místo 187 tis. (před úpravou C6; po ní základ 189 tis.) Patří sem i asi 113 tis. domácností na plyn, které platí i za ústřední topení a teplou vodu (SILC u nich jako hlavní zdroj uvádí vlastní kotel, takže platba je spíš za teplou vodu nebo společný zdroj neznámého paliva). Kdyby byla tato platba vždy za zdroj v ETS2, přibylo by asi 10 tis. zranitelných.

## 4. Od výdajů k emisím

- **Plyn:** výdaj / realizovaná cena plynu podle pásma spotřeby (Eurostat; D1/D2/D3) → kWh → emise. Spalné teplo se přepočítá na výhřevnost (0,910).
- **Tuhá paliva:** výdaj × podíl uhlí ve výdajích za paliva ze SRÚ (rodinné domy na uhlí 92 %, byty 68 %, ostatní rodinné domy 0 %) / cena hnědého uhlí (ceníky skladů, 680 Kč/q v roce 2026, přepočet HICP) → emise. Dřevo a pelety ETS2 nepodléhají.
- **Dálkové teplo:** výdaj / cena tepla z ERÚ (lokality v ETS2: 1 089 Kč/GJ, 2024) → GJ × emisní faktor vážený palivy lokalit v ETS2 (74,6 kg CO₂/GJ; plyn s účinností 90 %, hnědé uhlí 80 %, ztráty v rozvodu 15 %, biomasa 0). Cena tepla i podíl tepla z ETS2 v krajích používají stejný výběr lokalit (C6).
- **Pohonné hmoty:** domácnost s autem dostane litry náhodného dárce z SRÚ ze stejné buňky (rodinný/bytový dům × kvintil příjmu); litry × 2,16 (benzín) / 2,52 (nafta) kg CO₂.
- **Elektřina a tepelná čerpadla:** bez dopadu ETS2 (elektřina je v ETS1).

## 5. Ceny a příjmy v roce 2028

- Výdaje na energie se přeceňují na rok 2028: poslední známé ceny (1. pololetí 2026) × 1,02 ročně.
- Příjem: příjem v SILC (za rok před šetřením) × růst průměrné mzdy, pro SILC 2024 koeficient 1,216. Decily z ekvivalizovaného příjmu (příjem / odmocnina z počtu osob).
- Pravidlo konzistence: každá částka se na množství převádí cenou téhož roku, ze kterého je výdaj; až potom se vše přeceňuje do 2028. Čitatel i jmenovatel každého podílu mají stejný rozsah domácností.

## 6. Zranitelné domácnosti

Domácnost je zranitelná, když splní všechny tři podmínky:

1. **nízký příjem:** 1.–4. decil ekvivalizovaného příjmu;
2. **ohrožení energetickou chudobou (2M) po ETS2:** výdaje na energie v bydlení včetně nákladu ETS2 na vytápění / čistý příjem > 2× medián tohoto podílu po ETS2 (práh přepočtený z rozdělení po ETS2: 18,1 %; před ETS2 17,1 %);
3. **citelný dopad:** zdražení vytápění kvůli ETS2 aspoň 1 % čistého příjmu. Pohonné hmoty se do této podmínky nezapočítávají.

Výsledek (`09_silc_prahy.csv`, `_data/ets2/zranitelne.csv`): asi 262 tis. domácností, 95% interval 241–284 tis. (bootstrap po domácnostech, 500 opakování, prahy pevné). Náklad ETS2 v textu (Kč měsíčně, % příjmu) je celkový, tedy vytápění i pohonné hmoty.

## 7. Přímá platba (náš návrh)

- **Nárok:** podle příjmu se plynulým snižováním. Plná výše do horní hranice 3. decilu ekvivalizovaného příjmu, lineárně k nule na mediánu (5. decil). Bez ostré hranice.
- **Výše:** podle paliva a typu bydlení = průměrné zdražení vytápění zranitelných domácností ve skupině (rodinný dům na tuhá paliva, rodinný dům na plyn, byt na plyn, byt na teple ze zdroje v ETS2). Pohonné hmoty platba nevyrovnává.
- **Průběh v čase:** 2028 a 2029 plná výše, 2030 75 %, 2031 50 %, 2032 25 %, potom konec (`PRUBEH` v `13_data_web.R`). Výše se má odvíjet od skutečné ceny povolenky.
- **Náklad:** v plné výši asi 6,0 mld. Kč ročně, za 2028–2032 asi 21 mld. Kč. Je to horní odhad: počítá s tím, že požádají všichni oprávnění.
- **Srovnávaná pravidla** (`11_kompenzace_nastroje.R`): platba všem domácnostem, příjemcům dávek na bydlení, návrh PAQ Research a CVF (sleva na poplatníka, valorizace důchodů ve stejném úhrnu, +20 % energetického paušálu), náš návrh s teplem jen ze zdrojů v ETS2 a s teplem všem bytům na dálkovém teple. Ukazatele: náklad, podíl peněz pro zranitelné, kolik zranitelných nedostane nic, jaká část zdražení vytápění se jim vrátí (v plné výši, v průměru za 5 let a v roce 2032).

## 8. Sociální klimatický fond a plán

- **Alokace pro ČR:** 1 562 617 717 € z EU (příloha II nařízení 2023/955, podíl 2,40 %, fond 65 mld. €). Snížení fondu na 54,6 mld. € platí jen při odkladu ETS2 podle čl. 30k směrnice; ETS2 se odložilo nařízením 2026/667, fond tedy zůstává.
- **Fond pro plán:** alokace × kurz ÷ 0,75 (nejméně čtvrtinu doplácí stát) = asi 50 mld. Kč za 2026–2032.
- **Limit přímých plateb:** nejvýš 37,5 % celkových nákladů plánu (čl. 8 odst. 2). Stát může do plánu dát víc než povinnou čtvrtinu.
- **Návrh MŽP:** budovy 40,8, doprava 10, technická pomoc 1,2 mld. Kč z 52 mld. Kč (PwC pro MŽP 2025), přepočteno poměrem na náš fond.
- **Náš návrh:** investice jako MŽP + přímé platby navrch (rozšířený plán asi 71 mld. Kč, přímé platby 29 %). Platí EU (38 mld.) a stát z výnosů ETS2 (33 mld.); investice i platby z obou zdrojů poměrně.

## 9. Tok peněz z povolenek

- **Platby odběratelů paliv v ČR:** emise v sektorech ETS2 podle inventury (silniční doprava po kategoriích vozidel, vytápění domácností, vytápění služeb; rok 2024) × 60 € × kurz, bez DPH, za 2028–2032. Chybí menší průmyslové provozy.
- **Vývoj emisí:** budovy −3 % ročně, doprava beze změny, od 2028 −2,5 % jako reakce na cenu (`p$EM_TREND`, `p$EM_REAKCE_ETS2`). Výsledek asi 194 mld. Kč. Citlivost podle tempa poklesu v projekcích ČHMÚ (WEM 2025, přeneseno na emise 2024): asi 172 mld. Kč.
- **Rozdělení:** do fondu Česko přispívá podle podílu na emisích ETS2 v EU (2,48 %, průměr 2016–2018; tím se řídí i podíl na dražbách, čl. 30d odst. 5 směrnice), dostává 2,40 % fondu. Zbytek výnosu jde do státního rozpočtu.
- Zjednodušení: rezerva tržní stability a přesuny dražeb v čase pominuty, fond je za 2026–2032, platby za 2028–2032.

## 10. Mapy

- **Paliva v SO ORP:** podíly obydlených bytů v rodinných a bytových domech podle paliva (SLDB 2021), `R/10_mapa_orp.R`.
- **Teplo ze zdrojů v ETS2:** byty na dálkovém teple (SLDB 2021) × podíl tepla ze zdrojů v ETS2 v SO ORP (lokality ERÚ napárované na obce podle názvu; přiblížení).
- **Ohrožení energetickou chudobou:** ukazatel MF (podíl předpokládaných výdajů na vytápění na příjmu, kvartily).
- Hranice SO ORP a krajů: ČÚZK přes balík RCzechia.

## 11. Hlavní omezení

- Statický odhad bez změny chování (kromě odhadu toku peněz).
- Počet domácností na teple ze zdrojů v ETS2 (380 tis.) je nejistý (citlivost C3, `ETS2_N_TEPLO_TIS`): při 300 tis. vychází 183 tis. zranitelných, při 450 tis. 194 tis.
- Interval spolehlivosti (C5): bootstrap po domácnostech stratifikovaný podle kraje, v každé replikaci se znovu počítá práh 2M po ETS2 i hranice 4. decilu. MF verze SILC neobsahuje výběrové obvody (PSU), takže skutečná nejistota bude o něco větší; nezahrnuje ani nejistotu počtu bytů na teple (C3) a ceny povolenky.
- Podíl vráceného zdražení „za období 2028–2032“ a „v roce 2032“ počítá se stejným zdražením každý rok (C7). Spotřeba fosilních paliv ale do roku 2032 klesne, takže skutečný podíl bude spíš vyšší; uvedené hodnoty jsou dolní mez.
- Cena uhlí (680 Kč/q) výsledky neovlivňuje: emise z uhlí se kalibrují na bilanci, takže nižší cena jen sníží kalibrační faktor (500 Kč/q: 0,57, 600 Kč/q: 0,69, 680 Kč/q: 0,78), počty i částky zůstanou stejné (citlivost C2, `ETS2_CENA_UHLI_Q`). Nižší ceny by navíc znamenaly, že SILC nadhodnocuje spotřebu uhlí o 45–75 %, což je méně věrohodné.
- Výše platby se odvozuje z průměrného zdražení zranitelných domácností a návrh se hodnotí na téže skupině (kruhovost, C4). Srovnání s plošnými návrhy proto náš návrh mírně zvýhodňuje. Ověřit při přepočtu na SILC 2025 (částky z 2024 vyhodnotit na 2025).
- Mikrosimulace (díl I) a tok peněz (díl II) pracují s různou výší emisí 2028: mikrosimulace s dnešní spotřebou kalibrovanou na bilanci a zimu 2028 (plyn, uhlí a teplo ze zdrojů v ETS2, asi 5,8 Mt CO₂), tok peněz s inventurou 2024, trendem −3 % ročně a cenovou reakcí (asi 3,8 Mt). Část rozdílu je definiční (teplo z výtopen je v inventuře v 1A1a, ne v 1A4b), část je chybějící pokles spotřeby do 2028 v mikrosimulaci (asi −11 %). Dopady na domácnosti jsou proto spíš horní odhad, výnos spíš opatrný.
- Náklady v SILC uvádí respondent (zálohy), příjem je za předchozí rok.
- Pohonné hmoty přes dárce ze SRÚ: průměry sedí, vazba na konkrétní domácnost je náhodná.
- Zdroj dálkového tepla u konkrétní domácnosti neznáme.
- Malé buňky (byty na elektřinu, tepelná čerpadla) jsou jen orientační.
- Cena povolenky je nejistá; dopady rostou s cenou zhruba úměrně.

## 12. Soubory a spuštění

- Spuštění všeho: `R/run_all.R` (`Rscript --no-init-file`, kódování UTF-8).
- Parametry: `R/02_parametry.R`. Dopady a zranitelnost: `R/09_silc_archetypy.R`. Mapy: `R/10_mapa_orp.R`. Kompenzace: `R/11_kompenzace_nastroje.R`. Data pro web a financování: `R/13_data_web.R`.
- Výstupy výpočtů: `R/output/`. Data pro web: `web-cz/_data/ets2/` (soubory a grafy viz Google Sheet „ETS2 – data ke grafům“).
