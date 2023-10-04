""" Snippets of accompanying texts for emission infographics. """

import pandas as pd

from data_analysis.emissions_pie_chart import *
from data_analysis.illustrator_strings import *
from data_analysis.eurostat_geo import Geo
from data_analysis.sectors import *


def _get_decimals(geo: Geo) -> int:
    ''' CZ and SK have small values, more decimals for Mt are needed'''
    if geo == Geo.CZ or geo == Geo.SK:
        return 2
    else:
        return 1


def get_gases_info() -> str:
    """ Returns explanation how different GHG converted into CO2eq. """
    return 'Všechny hodnoty v grafu jsou <glossary id="antropogennisklenikoveplyny">antropogenní emise</glossary> skleníkových plynů CO<sub>2</sub>, N<sub>2</sub>O, CH<sub>4</sub>, HFC, PFC, SF<sub>6</sub>, NF<sub>3</sub> vyjádřené jako <glossary id="co2eq">CO<sub>2</sub>eq</glossary>. Jednotka CO<sub>2</sub> ekvivalent zohledňuje dlouhodobý efekt skleníkových plynů v atmosféře a převádí je na množství CO<sub>2</sub>, které by mělo stejný efekt. Více viz článek [Global warming potential](https://en.wikipedia.org/wiki/Global_warming_potential).'


def get_methodology_info() -> str:
    """ Returns info about CRF methodology. """
    return 'Emisní inventura poskytovaná Eurostatem využívá formát a strukturu dat CRF (_Common Reporting Format_). Veškerá metodika k výpočtům a reportingu je na stránkách národního programu inventarizace emisí ([NGGIP – national greenhouse gas inventory programme](https://www.ipcc-nggip.iges.or.jp/)) a je závazná pro všechny státy [UNFCCC](https://cs.wikipedia.org/wiki/R%C3%A1mcov%C3%A1_%C3%BAmluva_OSN_o_zm%C4%9Bn%C4%9B_klimatu). Data o emisích poskytují Eurostatu jednotlivé země EU – data za Českou republiku sestavuje ČHMÚ, podílí se na tom ovšem více českých institucí.'


def get_lulucf_info(year: int, geo: Geo, lulucf_emissions: float) -> str:
    details = ""
    if geo == Geo.CZ:
        details = "Právě v Česku jsme v posledních letech svědky výrazného výkyvu kvůli masivní těžbě dřeva při kůrovcové kalamitě."
    if lulucf_emissions < 0:
        sign = "záporné"
    else:
        sign = "kladné"

    """ Returns explanation why LULUCF is not included in emission graphs. """
    return f'Pro snadnější možnost srovnávání emisí [napříč státy EU](/infografiky/emise-vybrane-staty) vynecháváme kategorii lesnictví a využití půdy (která bývá označována _LULUCF_ podle anglického _Land use, land use change, forestry_). Díky ukládání uhlíku v zeleni má totiž tato kategorie ve většině států EU záporné emise, což komplikuje vizualizaci. Sektor LULUCF se také často ze srovnávání [vynechává](https://climateactiontracker.org/methodology/indc-ratings-and-lulucf/), protože jednak obsahuje vysokou nejistotu v datech, neboť záporné hodnoty mohou zakrývat _strukturální_ emise z energetiky, průmyslu a zemědělství, a jednak je tento sektor náchylnější na výkyvy v čase. {details} Za rok {year} byly podle odhadů emise v tomto sektoru _{sign}_ ve výši {czech_float(lulucf_emissions, decimals=_get_decimals(geo))} Mt CO<sub>2</sub>eq.'


def get_trade_and_flights_info(geo: Optional[Geo]) -> str:
    """ Returns info about methodology of trade and flights in the emission accounting. """
    if geo is None or geo == Geo.CZ:
        return f"**Údaje odpovídají emisím vyprodukovaným v dané zemi**, avšak vzhledem k vývozu a dovozu zboží nemusejí odpovídat emisím vzniklých ze spotřeby v dané zemi. ČR například do dalších zemí EU vyváží elektřinu, ocel, automobily apod. a dováží zboží z jiných zemí EU nebo z Číny. **Zahrnutí letecké dopravy je podobně problematické** – zobrazený příspěvek letecké dopravy odpovídá emisím vyprodukovaným {get_flights_from_snippet(geo)}. {get_flights_info(geo)}."
    elif geo == Geo.SK:
        return f"**Údaje odpovídají emisím vyprodukovaným v dané zemi**, avšak vzhledem k vývozu a dovozu zboží nemusejí odpovídat emisím vzniklých ze spotřeby v dané zemi. Slovensko například do dalších zemí EU vyváží automobily, ocel apod. a dováží zboží z jiných zemí EU nebo z Číny. **Zahrnutí letecké dopravy je podobně problematické** – zobrazený příspěvek letecké dopravy odpovídá emisím vyprodukovaným {get_flights_from_snippet(geo)}. {get_flights_info(geo)}."
    elif geo == Geo.EU27:
        return f"**Údaje odpovídají emisím vyprodukovaným v Evropské unii**, avšak vzhledem k vývozu a dovozu zboží nemusejí odpovídat emisím vzniklých ze spotřeby. Země EU např. do třetích zemí mimo EU vyváží ocel, automobily apod. a dováží zboží z jiných třetích zemí, např. z Číny. **Zahrnutí letecké dopravy je podobně problematické** - zobrazený příspěvek letecké dopravy odpovídá emisím vyprodukovaným {get_flights_from_snippet(geo)}. {get_flights_info(geo)}."
    assert False, "unknown GEO used"


def get_flights_from_snippet(geo: Optional[Geo]) -> str:
    """
    Returns info about which flight are included in accounting. It is only a sentence snippet,
    must be carefully incorporated in the right context.
    """
    if geo is None:
        return "lety z letišť v dané zemi"
    elif geo == Geo.CZ:
        return "lety z letišť v ČR"
    elif geo == Geo.SK:
        return "lety z letišť na Slovensku"
    elif geo == Geo.EU27:
        return "lety z letišť v EU"
    assert False, "unknown GEO used"


def get_flights_estimate_snippet(geo: Optional[Geo]) -> str:
    """
    Returns info about flight emissions misrepresentation. Is only a sentence snippet, must be
    carefully incorporated in the right context.
    """
    if geo == Geo.EU27:
        return "Tento údaj tedy pravděpodobně zcela neodpovídá množství emisí, které Evropané způsobí"
    else:
        return "Je to tedy pravděpodobně podhodnocený údaj"


def get_flights_info(geo: Optional[Geo]) -> str:
    """
    Returns info about flight emissions accounting.
    """
    if geo is None:
        return f"{get_flights_estimate_snippet(geo)} (mnoho Čechů létá z Vídně či Bratislavy) a neodpovídá zcela množství emisí, které Češi způsobí (typicky např. let českého člověka do New Yorku s přestupem v Amsterdamu se započítá do zobrazených emisí jen jako Praha–Amsterdam, zatímco emise z letu Amsterdam–New York se započtou Nizozemsku). Není také započítáno, že emise vypuštěné vysoko v atmosféře mají přibližně dvojnásobný efekt"
    elif geo == Geo.CZ:
        return f"{get_flights_estimate_snippet(geo)} (mnoho Čechů létá z Vídně či Bratislavy) a neodpovídá zcela množství emisí, které Češi způsobí (typicky např. let českého člověka do New Yorku s přestupem v Amsterdamu se započítá do zobrazených emisí jen jako Praha–Amsterdam, zatímco emise z letu Amsterdam–New York se započtou Nizozemsku). Není také započítáno, že emise vypuštěné vysoko v atmosféře mají přibližně dvojnásobný efekt"
    elif geo == Geo.SK:
        return f"{get_flights_estimate_snippet(geo)} (mnoho Slováků létá z Vídně) a neodpovídá zcela množství emisí, které Slováci způsobí (typicky např. let z Bratislavy do New Yorku s přestupem v Dublinu se započítá do zobrazených emisí jen jako Bratislava–Dublin, zatímco emise z letu Dublin–New York se započtou Irsku). Není také započítáno, že emise vypuštěné vysoko v atmosféře mají přibližně dvojnásobný efekt"
    elif geo == Geo.EU27:
        return f"{get_flights_estimate_snippet(geo)} (typicky např. let člověka z Vídně do Limy s přestupem v Atlantě se započítá do zobrazených emisí jen jako Vídeň–Atlanta, zatímco emise z letu Atlanta–Lima se započtou USA). Není také započítáno, že emise vypuštěné vysoko v atmosféře mají přibližně dvojnásobný efekt"
    assert False, "unknown GEO used"


def get_sectoral_tips(sector: Sector, geo: Optional[Geo] = None) -> str:
    """
    Returns various tips around emission sectors (either explaining the type of emissions or
    possible measures for emission reductions or both).
    """
    if sector == Sector.INDUSTRY:
        return "V této kategorii jsou zahrnuty tři druhy emisí. Za prvé jde o emise ze spalování fosilních paliv v průmyslu (např. koksu ve vysokých pecích nebo zemního plynu v cementárně). Za druhé jde o procesní emise, které vznikají chemickou reakcí při výrobním procesu – například při redukci uhlíku z železné rudy nebo při kalcinaci vápence při výrobě cementu. Za třetí jde o úniky skleníkových plynů související s průmyslem – například úniky F-plynů při jejich používání v chladících průmyslových produktech nebo úniky metanu při těžbě uhlí či v plynárenské infrastruktuře."
    elif sector == Sector.TRANSPORT:
        return "Snížit emise z dopravy je možné přechodem na alternativní druhy pohonu (např. na biometan, CNG, vodík nebo na elektřinu), zvýšením podílu hromadné dopravy a snížením počtu vozidel na silnicích. Objem silniční dopravy lze snížit vyšší obsazeností vozidel (např. spolujízdou) či obecně snížením nutnosti dopravy (např. prací na dálku)."
    elif sector == Sector.ELECTRICITY_HEAT:
        return "Emise skleníkových plynů původem z energetiky je možné snížit energetickými úsporami a rozvojem obnovitelných a nízkouhlíkových zdrojů energie."
    elif sector == Sector.BUILDINGS:
        return "Jde o topení a ohřev vody v domácnostech, kancelářích a institucích (pokud energie není dodávána z teplárny) a také o vaření plynem. Průmyslové budovy jsou zahrnuty v kategorii Průmysl."
    elif sector == Sector.AGRICULTURE:
        return "K omezení emisí metanu ze zemědělství by vedlo snížení počtu chovaného dobytka (a s tím související snížení spotřeby hovězího masa a mléčných výrobků), změna nakládání se statkovými hnojivy (například jejich stabilizací v bioplynových stanicích) a méně intenzivní hnojení průmyslovými hnojivy. Omezení chovu dobytka však může mít i negativní dopad na kvalitu půdy, dostupnost přírodního hnojiva atd."
    elif sector == Sector.WASTE:
        if geo == Geo.CZ:
            solution = " Řešením může být zákaz skládkování využitelných odpadů po vzoru většiny zemí EU a využití biologicky rozložitelných odpadů k produkci biometanu, který se namísto zemního plynu může využít například v dopravě."
        else:
            solution = ""
        return f"Emise z odpadového hospodářství produkují především skládky odpadu, ze kterých do atmosféry uniká metan. Ten vzniká rozkladem biologicky rozložitelného materiálu (papíru, kartonu, textilií a bioodpadu) v tělese skládky.{solution}"
    assert False, f"unknown sector {sector} provided"


def get_sectoral_info(sector: Sector, geo: Geo, df_wedges: pd.DataFrame,
                      df_crf: pd.DataFrame, total_value: float, population: int) -> str:
    """
    Returns a paragraph of text explaining emissions in the provided sector and geo for the latest
    year (captured using `df_wedges` for sectors in the pie charts, `df_crf` for all CRF codes, and
    `total_value` for the total emissions value). `population` is the size of the population in the
    given geo (needed for emissions per capita).
    """
    def _get(id: str) -> float:
        return df_wedges.loc[id, "value"]

    def _total(id: str) -> str:
        return czech_float(_get(id), _get_decimals(geo))

    def _percent(id: str) -> str:
        return czech_float(_get(id) / total_value * 100, 1)

    def _per_person(id: str, kg: bool = False) -> str:
        value = _get(id) * 1_000_000
        decimals = 2
        if kg:
            value *= 1_000
            decimals = 1
        value_per_person = value / population
        return czech_float(value_per_person, decimals)

    if sector == Sector.INDUSTRY:
        return f'__Průmysl:__ {_total("industry")} mil. tun CO<sub>2</sub> ({_percent("industry")} % celkových emisí, {_per_person("industry")} t CO<sub>2</sub>eq na obyvatele ročně). {get_sectoral_tips(sector)}'

    elif sector == Sector.TRANSPORT:
        total_trains = get_emissions_value("CRF1A3C", df_crf)
        total_trains_str = czech_float(total_trains, _get_decimals(geo))
        percent_trains_str = czech_float(total_trains / total_value * 100, 1)

        return f'__Doprava:__ {_total("transport")} mil. tun CO<sub>2</sub> ({_percent("transport")} % celkových emisí, {_per_person("transport")} t CO<sub>2</sub>eq na obyvatele ročně). Osobní automobilová doprava ročně vyprodukuje {_total("transport_cars")} mil. tun CO<sub>2</sub> ({_percent("transport_cars")} %), zatímco nákladní a autobusová doprava je zodpovědná za {_total("transport_trucks-buses")} mil. tun CO<sub>2</sub> ({_percent("transport_trucks-buses")} %). Neelektrifikovaná vlaková doprava ročně způsobí emise {total_trains_str} mil. tun CO<sub>2</sub>eq ({percent_trains_str} %), v grafu je započtena v rámci ostatní dopravy. Emise z letecké dopravy jsou {_total("transport_airplanes")} mil. tun tun CO<sub>2</sub> ({_percent("transport_airplanes")} %, {_per_person("transport_airplanes", kg=True)} kg na obyvatele ročně) a odpovídají emisím vyprodukovaným {get_flights_from_snippet(geo)}. {get_flights_estimate_snippet(geo)}, více v poznámkách níže. {get_sectoral_tips(sector)}'

    elif sector == Sector.ELECTRICITY_HEAT:
        if geo == Geo.CZ or geo == Geo.SK:
            total_electricity = _get("electricity-heat") - \
                _get("electricity-heat_CHP")
            total_electricity_str = czech_float(
                total_electricity, _get_decimals(geo))
            total_electricity_percent_str = czech_float(
                total_electricity / total_value * 100, 1)

        if geo == Geo.CZ:
            details = f'Emise v energetice pochází především ze spalování hnědého uhlí a zemního plynu v elektrárnách ({total_electricity_str} milionů tun, resp. {total_electricity_percent_str} % celkových ročních emisí) a dále z tepláren ({_total("electricity-heat_CHP")} mil. tun, či {_percent("electricity-heat_CHP")} % celkových emisí ročně). Největším jednotlivým emitentem CO<sub>2</sub> jsou elektrárny v Počeradech (pět hnědouhelných bloků a jeden na zemní plyn), které ročně vyprodukují {_total("electricity-heat_pocerady")} mil. tun CO<sub>2</sub>, což je {_percent("electricity-heat_pocerady")} % celkových emisí České republiky. Pět největších českých fosilních elektráren, Počerady, Ledvice, Prunéřov, Tušimice a Chvaletice, vyprodukují ročně více emisí CO<sub>2</sub> než veškerá silniční doprava.'
        elif geo == Geo.SK:
            details = f'Tyto emise pochází především z tepláren ({_total("electricity-heat_CHP")} mil. tun, či {_percent("electricity-heat_CHP")} % celkových emisí ročně) a dále z tepelných elektráren ({total_electricity_str} milionů tun, resp. {total_electricity_percent_str} % celkových ročních emisí).'
        elif geo == Geo.EU27:
            details = ""

        return f'__Výroba elektřiny a tepla:__ {_total("electricity-heat")} milionů tun CO<sub>2</sub> ({_percent("electricity-heat")} % celkových emisí, {_per_person("electricity-heat")} t CO<sub>2</sub>eq na obyvatele ročně). {details} {get_sectoral_tips(sector)}'

    elif sector == Sector.BUILDINGS:
        return f'__Budovy:__ {_total("buildings")} mil. tun CO<sub>2</sub> ({_percent("buildings")} % celkových emisí, tedy {_per_person("buildings")} t CO<sub>2</sub>eq na obyvatele ročně). {get_sectoral_tips(sector)}'

    elif sector == Sector.AGRICULTURE:
        livestock_str = czech_float(
            get_emissions_value("CRF31", df_crf), _get_decimals(geo))
        managed_agricultural_soils_str = czech_float(
            get_emissions_value("CRF3D", df_crf), _get_decimals(geo))
        agricultural_fuels_str = czech_float(
            get_emissions_value("CRF1A4C", df_crf), _get_decimals(geo))

        return f'__Zemědělství:__ {_total("agriculture")} mil. tun CO<sub>2</sub>eq ({_percent("agriculture")} % celkových emisí, {_per_person("agriculture")} t CO<sub>2</sub>eq na obyvatele ročně). Emise v zemědělství pochází především z chovu hospodářských zvířat ({livestock_str} mil. tun) v podobě emisí metanu a také z obdělávání půdy a s tím spojenými emisemi N<sub>2</sub>O ({managed_agricultural_soils_str} mil. tun). Také sem patří spalování pohonných hmot v zemědělství a lesnictví ({agricultural_fuels_str} mil. tun). {get_sectoral_tips(sector)}'

    elif sector == Sector.WASTE:
        return f'__Odpadové hospodářství:__ {_total("waste")} mil. tun CO<sub>2</sub>eq ročně ({_percent("waste")} % celkových emisí, {_per_person("waste")} t CO<sub>2</sub>eq na obyvatele ročně). {get_sectoral_tips(sector, geo)}'

    assert False, f"unknown sector {sector} provided"


def get_sectoral_evolution_info(sector: Sector, geo: Geo,
                                year_from: int, year_to: int,
                                inner_dict_from, inner_dict_to,
                                df_crf_from, df_crf_to) -> str:
    """
    Returns a paragraph of text explaining evolution of emissions in the provided sector and geo
    from `year_from` to `year_to` (captured using `inner_dict_from` and `inner_dict_to` for the
    high-level sectors and using the complete CRF data frames `df_crf_from` and `df_crf_to` for all
    sub-sectors).
    """
    def _get_sector_to() -> str:
        return czech_float(inner_dict_to[sector.value], decimals=_get_decimals(geo))

    def _get_percentage_change() -> str:
        value_from = inner_dict_from[sector.value]
        value_to = inner_dict_to[sector.value]
        change_by_percent = abs((1 - value_to / value_from) * 100)
        return f"{change_by_percent:.0f}"

    def _get_crf_value(crf_code: str, df: pd.DataFrame) -> float:
        return df.loc[crf_code, "value"]

    def _get_crf_decrease(crf_code: str, remaining: bool = False) -> str:
        value_from = _get_crf_value(crf_code, df_crf_from)
        value_to = _get_crf_value(crf_code, df_crf_to)
        ratio = value_to / value_from if remaining else 1 - value_to / value_from
        percent = ratio * 100
        return f"{percent:.0f}"

    if sector == Sector.ELECTRICITY_HEAT:
        if geo == Geo.CZ:
            details = 'Tyto emise pochází především ze spalování hnědého uhlí v elektrárnách a v posledních desetiletích spíše stagnují, a to i přesto, že v roce 2002 byla spuštěna Jaderná elektrárna Temelín. Výraznější pokles je patrný až v několika posledních letech v souvislosti s nárůstem cen [emisních povolenek](/explainery/emisni-povolenky-ets).'
        else:
            assert geo == Geo.EU27, f"unexpected geo value {geo}"
            details = 'Tyto emise začaly výrazněji klesat po roce 2007. V posledních letech pozorujeme jejich rychlejší pokles, který lze vzhledem k závazku EU dosáhnout do roku 2050 <glossary id="co2eq">klimatické neutrality</glossary> očekávat i v budoucnu.'

        return f'__Výroba elektřiny a tepla:__ Objem emisí z výroby elektřiny a tepla klesl oproti roku {year_from} o {_get_percentage_change()} % na {_get_sector_to()} milionů tun CO<sub>2</sub>eq ročně. {details} {get_sectoral_tips(sector)}'

    elif sector == Sector.INDUSTRY:
        if geo == Geo.CZ:
            details = f'Útlumem těžkého průmyslu v první polovině devadesátých let došlo k výraznému snížení emisí ze spalování fosilních paliv. Konkrétně emise ze spalování při výrobě železa a oceli klesly do roku 2000 o dvě třetiny a v roce {year_to} se pohybovaly pod {_get_crf_decrease("CRF1A2A", remaining=True)} % oproti úrovním z roku {year_from}. Emise z (nespalovacích) průmyslových procesů přitom spíše stagnují. Například emise z výroby skla, cementu, vápna nebo amoniaku a z petrochemie se pohybují na podobných úrovních jako na začátku devadesátých let. Dlouhodobě a setrvale rostou pouze emise z F-plynů, jež nahrazují dříve používané látky poškozující ozonovou vrstvu, které jsou dnes regulované Montrealským protokolem.'
        else:
            assert geo == Geo.EU27, f"unexpected geo value {geo}"
            details = f'Postupným útlumem těžkého průmyslu došlo k výraznému snížení emisí ze spalování fosilních paliv. Konkrétně emise ze spalování při výrobě železa a oceli klesly do roku {year_to} o {_get_crf_decrease("CRF1A2A")} %. Emise z (nespalovacích) průmyslových procesů přitom do roku {year_to} klesly jen o {_get_crf_decrease("CRF2")} %. V každé oblasti průmyslových procesů je tento pokles odlišný. Například emise z výroby cementu klesly od roku {year_from} o {_get_crf_decrease("CRF2A1")} %. K poklesu dochází i v chemickém odvětví, kdy klesly mj. emise z výroby amoniaku o {_get_crf_decrease("CRF2B1")} % či emise z výroby kyseliny dusičné o {_get_crf_decrease("CRF2B2")} %. Naopak mírný nárůst pozorujeme u emisí z petrochemie. K poklesu dochází i u produkce železa a oceli (o {_get_crf_decrease("CRF2C1")} %) nebo produkce hliníku (o {_get_crf_decrease("CRF2C3")} %). Od devadesátých let výrazně vzrostly emise z F-plynů, jež nahrazují dříve používané látky poškozující ozonovou vrstvu, které jsou dnes regulované Montrealským protokolem. Tyto emise vzrostly z nuly na 88,4 Mt CO<sub>2</sub>eq v roce 2014. Od té doby dochází k jejich poklesu, přičemž v roce {year_to} dosahovaly hodnoty {czech_float(_get_crf_value("CRF2F", df_crf_to))} Mt CO<sub>2</sub>eq.'

        return f'__Průmysl:__ Emise z průmyslu klesly od roku {year_from} o {_get_percentage_change()} % na {_get_sector_to()} mil. tun CO<sub>2</sub>eq ročně. {get_sectoral_tips(sector)} {details}'

    elif sector == Sector.TRANSPORT:
        total_transport = inner_dict_to[sector.value]
        road = _get_crf_value("CRF1A3B", df_crf_to)
        airplanes = sum(_get_crf_value(code, df_crf_to)
                        for code in SUBSECTOR_CODES[Subsector.AIRPLANES])
        percentage_road = (road / total_transport) * 100
        percentage_airplanes = (airplanes / total_transport) * 100

        if geo == Geo.CZ:
            growth = "Od roku 2014 (s výjimkou roku 2020) lze opět sledovat růst emisí."
        else:
            assert geo == Geo.EU27, f"unexpected geo value {geo}"
            growth = "Od roku 2013 lze opět sledovat růst emisí."

        return f'__Doprava:__ Emise z dopravy vzrostly oproti roku {year_from} o {_get_percentage_change()} % na {_get_sector_to()} mil. tun CO<sub>2</sub>eq ročně. V detailním grafu napravo je po roce 2007 patrný dočasný pokles emisí v důsledku globální finanční krize a následné ekonomické recese. {growth} Emise skleníkových plynů v dopravě vznikají primárně spalováním fosilních paliv v motorech silničních dopravních prostředků – v roce {year_to} to bylo {percentage_road:.0f} % všech emisí z dopravního sektoru, {percentage_airplanes:.0f} % tvořila letecká doprava. {get_sectoral_tips(sector)}'

    elif sector == Sector.BUILDINGS:
        details = "Většina poklesu, o jednu polovinu, se uskutečnila během devadesátých let díky plynofikaci a zvyšující se energetické efektivitě budov." if geo == Geo.CZ else ""

        return f'__Budovy:__ Emise klesly oproti roku {year_from} o {_get_percentage_change()} % na {_get_sector_to()} mil. tun CO<sub>2</sub>eq ročně. {get_sectoral_tips(sector)} {details}'

    elif sector == Sector.AGRICULTURE:
        details = "Právě snížení stavu chovaného dobytka se odráží v poklesu emisí, o téměř polovinu, v první polovině devadesátých let." if geo == Geo.CZ else ""

        return f'__Zemědělství:__ Emise ze zemědělského sektoru klesly od roku {year_from} o {_get_percentage_change()} % na {_get_sector_to()} mil. tun CO<sub>2</sub>eq ročně. Emise pocházejí především z chovu hospodářských zvířat a z obdělávání půdy a s tím spojenými emisemi N<sub>2</sub>O. {get_sectoral_tips(sector)} {details}'

    elif sector == Sector.WASTE:
        common = f'{_get_percentage_change()} % na {_get_sector_to()} mil. tun CO<sub>2</sub>eq ročně. {get_sectoral_tips(sector, geo)}'

        if geo == Geo.CZ:
            return f'__Odpadové hospodářství:__ Emise z odpadového hospodářství od devadesátých let setrvale rostou. Do roku {year_to} stouply o {common}'
        else:
            assert geo == Geo.EU27, f"unexpected geo value {geo}"
            return f'__Odpadové hospodářství:__ Emise z odpadového hospodářství klesají od poloviny 90. let. Do roku {year_to} klesly o {common}'

    assert False, f"unknown sector {sector} provided"
