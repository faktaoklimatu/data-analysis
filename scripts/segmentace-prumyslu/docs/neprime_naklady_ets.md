# Nepřímé náklady EU ETS: jak je počítáme

Povolenky neplatí jen podniky za své vlastní emise (**přímý náklad**). Platí je i elektrárny a promítají je do ceny
elektřiny, takže je nepřímo platí každý, kdo elektřinu kupuje (**nepřímý náklad**). Na snímku S17 jsou oba náklady
v % celkových nákladů oboru. Tady je popsáno, jak se nepřímý náklad počítá a proč.

Výpočet je v `R/03_ets_costs.R`, výsledky v `out/ets_costs_2024.csv` a `data_slajdy/naklady_ets.csv`.

## Vzorec

```
nepřímý náklad = elektřina ze sítě (MWh) × emisní faktor (t CO₂/MWh) × cena povolenky (€/t) − kompenzace (€)
```

| Část | Hodnota | Zdroj |
|---|---|---|
| Elektřina ze sítě | spotřeba elektřiny oboru 2023 minus vlastní výroba | Eurostat PEFA `env_ac_pefasu` (P26), odečet `data/manual/vlastni_elektrina_odecet.csv` |
| Emisní faktor | 0,85 t CO₂/MWh | pokyny EU ke státní podpoře v rámci ETS, příloha III (region Česko–Slovensko) |
| Cena povolenky | 65,01 €/t (průměr aukcí 2024) | DEHSt |
| Kompenzace | vyplaceno za rok 2024 | MPO, `data/manual/kompenzace_neprimych_nakladu_2024.csv` |

V datech jsou tři varianty, na snímku se používá ta poslední:

| Varianta | Sloupec v `naklady_ets.csv` | Papír | Hutě | Chemie | Průmysl |
|---|---|---|---|---|---|
| veškerá elektřina vč. vlastní výroby | `nepr_ets_vc_vlastni` | 2,4 % | 1,5 % | 2,0 % | 0,6 % |
| jen elektřina ze sítě | `nepr_ets_pred_kompenzaci` | 1,0 % | 1,2 % | 1,5 % | 0,5 % |
| **ze sítě po kompenzaci** (S17) | `nepr_ets` | **0,3 %** | **0,8 %** | **1,2 %** | **0,5 %** |

(% celkových nákladů oboru 2024 podle tabulek dodávek a užití ČSÚ.)

## 1. Proč jen elektřina ze sítě

Některé obory si velkou část elektřiny vyrábějí samy. Papírny 58 % (z černého louhu a dřevního odpadu), hutě
a chemie zhruba čtvrtinu (vlastní teplárny a energetiky). Taková elektřina povolenku v ceně nenese: z biomasy žádnou,
z fosilních paliv už je její povolenka v **přímém** nákladu oboru. Nepřímý náklad z ní by se tak počítal navíc
nebo dvakrát. Navíc ji obor nekupuje, takže není ani v nákupech energie, se kterými se nepřímý náklad na S17 srovnává.

## 2. Proč 0,85 t/MWh a proč je to horní odhad

O kolik povolenky zdraží elektřinu, záleží na tom, **která elektrárna cenu určuje**. Na burze určuje cenu v každé
hodině nejdražší elektrárna, kterou je ještě potřeba zapnout, a ta do ceny promítne své náklady na povolenky:

| Elektrárna, která určuje cenu | Emise | Zdražení při 65 €/t |
|---|---|---|
| uhelná (hnědé uhlí) | ~0,85–1 t/MWh | ~55 €/MWh |
| plynová (paroplynová) | ~0,37 t/MWh | ~24 €/MWh |
| obnovitelný zdroj, jádro | 0 | 0 |

Faktor 0,85 t/MWh stanovila EU pro region Česko–Slovensko a používá ho i pro výpočet kompenzací. Předpokládá,
že cenu vždy určuje uhelná elektrárna. V posledních letech ji ale velkou část hodin určují plynové elektrárny
a čím dál častěji obnovitelné zdroje. Skutečný průměrný dopad je proto nižší. Při faktoru plynové elektrárny by
nepřímé náklady vyšly zhruba o 55 % nižší. Zůstáváme u 0,85, protože je oficiální a nedá se nám vyčítat podhodnocení.

## 3. Jak fungují české kompenzace

Kompenzace vracejí energeticky náročným podnikům část povolenek zaplacených v ceně elektřiny. Pravidla stanoví EU
(pokyny ke státní podpoře v rámci EU ETS na roky 2021–2030), v Česku je vyplácí Ministerstvo průmyslu a obchodu
z výnosů z dražeb povolenek, zpětně za předchozí rok.

```
kompenzace = 75 % × cena povolenky (termínové ceny z předchozího roku) × 0,85 t/MWh × spotřeba elektřiny podle benchmarku
```

- **Nárok mají jen odvětví na seznamu EU**, kterým hrozí únik uhlíku: železo a ocel, papír a celulóza, část chemie
  (chlor, vodík, hnojiva…), hliník, průmyslové plyny aj. Auta, stroje, potraviny, plasty nebo cement nárok nemají.
- **Benchmark:** neproplácí se skutečná spotřeba, ale spotřeba efektivního výrobce na tunu výrobku × skutečná výroba
  (kde benchmark není, 80 % historické spotřeby). Neefektivní podnik dostane relativně méně.
- **Vlastní výroba elektřiny se nekompenzuje** – stejná logika jako v bodě 1.

Za rok 2024 vyplatilo MPO **2,24 mld. Kč (89 mil. €) 32 firmám**:

| Obor | Firem | Kompenzace | Nepřímý náklad ze sítě | Pokrytí |
|---|---|---|---|---|
| Papír | 9 | 28,6 mil. € | 40,8 mil. € | 70 % |
| Hutě | 12 | 30,0 mil. € | 94,6 mil. € | 32 % |
| Chemie vč. rafinerií | 8 | 26,7 mil. € | 126,5 mil. € | 21 % |
| Cement, sklo, keramika | 2 | 3,5 mil. € | 116,0 mil. € | 3 % |
| **Průmysl celkem** | **32** | **89,2 mil. €** | **1 033 mil. €** | **9 %** |

Přepočet kurzem ECB 2024 (25,12 Kč/€). Kompenzace ORLEN Unipetrol RPA je přiřazená chemii, jako ostatní data o rafineriích.

**Co z toho plyne:** u papíru stát vrací většinu nepřímého nákladu, u hutí třetinu. Průmysl jako celek dostane zpět
jen asi desetinu, protože většina oborů nárok nemá – u nich zůstává celý (horní) odhad.

## Omezení

- Elektřina je za rok 2023 (poslední PEFA), cena povolenky a kompenzace za rok 2024.
- Kompenzace se počítá z benchmarků a ceny z předchozího roku, náš nepřímý náklad ze skutečné spotřeby. Pokrytí
  v tabulce proto není přesně „kolik % nákladu stát vrátil“, jen řádový ukazatel.
- Kompenzace nemůže náklad oboru snížit pod nulu (`pmax(…, 0)` ve skriptu).
