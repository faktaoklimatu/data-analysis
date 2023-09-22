""" Snippets of accompanying texts for emission infographics. """

from enum import Enum

import pandas as pd

from data_analysis.emissions_pie_chart import *
from data_analysis.illustrator_strings import *
from data_analysis.eurostat_geo import Geo


class Sector(Enum):
    INDUSTRY = 0
    TRANSPORT = 1
    ELECTRICITY_HEAT = 2
    BUILDINGS = 3
    AGRICULTURE = 4
    WASTE = 5


def get_gases_info() -> str:
    return 'Všechny hodnoty v grafu jsou <glossary id="antropogennisklenikoveplyny">antropogenní emise</glossary> skleníkových plynů CO<sub>2</sub>, N<sub>2</sub>O, CH<sub>4</sub>, HFC, PFC, SF<sub>6</sub>, NF<sub>3</sub> vyjádřené jako <glossary id="co2eq">CO<sub>2</sub>eq</glossary>. Jednotka CO<sub>2</sub> ekvivalent zohledňuje dlouhodobý efekt skleníkových plynů v atmosféře a převádí je na množství CO<sub>2</sub>, které by mělo stejný efekt. Více viz článek [Global warming potential](https://en.wikipedia.org/wiki/Global_warming_potential).'


def get_methodology_info() -> str:
    return 'Emisní inventura poskytovaná Eurostatem využívá formát a strukturu dat CRF (_Common Reporting Format_). Veškerá metodika k výpočtům a reportingu je na stránkách národního programu inventarizace emisí ([NGGIP – national greenhouse gas inventory programme](https://www.ipcc-nggip.iges.or.jp/)) a je závazná pro všechny státy [UNFCCC](https://cs.wikipedia.org/wiki/R%C3%A1mcov%C3%A1_%C3%BAmluva_OSN_o_zm%C4%9Bn%C4%9B_klimatu). Data o emisích poskytují Eurostatu jednotlivé země EU – data za Českou republiku sestavuje ČHMÚ, podílí se na tom ovšem více českých institucí.'


def get_lulucf_info(year: int, strings: dict[str, str]) -> str:
    return f'Pro snadnější možnost srovnávání emisí [napříč státy EU](/infografiky/emise-vybrane-staty) vynecháváme kategorii lesnictví a využití půdy (která bývá označována _LULUCF_ podle anglického _Land use, land use change, forestry_). Díky ukládání uhlíku v zeleni má totiž tato kategorie ve většině států EU záporné emise, což komplikuje vizualizaci. Sektor LULUCF se také často ze srovnávání [vynechává](https://climateactiontracker.org/methodology/indc-ratings-and-lulucf/), protože jednak obsahuje vysokou nejistotu v datech, neboť záporné hodnoty mohou zakrývat _strukturální_ emise z energetiky, průmyslu a zemědělství, a jednak je tento sektor náchylnější na výkyvy v čase. Právě v Česku jsme v posledních letech svědky výrazného výkyvu kvůli masivní těžbě dřeva při kůrovcové kalamitě. Za rok {year} byly podle odhadů emise v tomto sektoru _kladné_ ve výši {strings["lulucf-emissions"]} Mt CO<sub>2</sub>eq.'


def get_flights_info(geo: Geo) -> str:
    if geo == Geo.CZ:
        return "lety z letišť v ČR. Je tedy pravděpodobně podhodnocený (mnoho Čechů létá z Vídně či Bratislavy) a neodpovídá zcela množství emisí, které Češi způsobí (typicky např. let českého člověka do New Yorku s přestupem v Amsterdamu se započítá do zobrazených emisí jen jako Praha–Amsterdam, zatímco emise z letu Amsterdam–New York se započtou Nizozemsku). Není také započítáno, že emise vypuštěné vysoko v atmosféře mají přibližně dvojnásobný efekt"
    elif geo == Geo.SK:
        return "lety z letišť na Slovensku. Je to tedy pravděpodobně podhodnocený údaj (mnoho Slováků létá z Vídně) a neodpovídá zcela množství emisí, které Slováci způsobí (typicky např. let z Bratislavy do New Yorku s přestupem v Dublinu se započítá do zobrazených emisí jen jako Bratislava–Dublin, zatímco emise z letu Dublin–New York se započtou Irsku). Není také započítáno, že emise vypuštěné vysoko v atmosféře mají přibližně dvojnásobný efekt"
    elif geo == Geo.EU27:
        return "lety z letišť v EU. Pravděpodobně tedy zcela neodpovídá množství emisí, které Evropané způsobí (typicky např. let člověka z Vídně do Limy s přestupem v Atlantě se započítá do zobrazených emisí jen jako Vídeň–Atlanta, zatímco emise z letu Atlanta–Lima se započtou USA). Není také započítáno, že emise vypuštěné vysoko v atmosféře mají přibližně dvojnásobný efekt"
    assert False, "unknown GEO used"


def get_sectoral_info(sector: Sector, geo: Geo, df_wedges: pd.DataFrame,
                      df_crf: pd.DataFrame, total_value: float, population: int) -> str:
    def _get(id: str) -> float:
        return df_wedges.loc[id, "value"]

    def _total(id: str) -> str:
        return czech_float(_get(id), 2)

    def _percent(id: str) -> str:
        return czech_float(_get(id) / total_value * 100, 1)

    def _per_person(id: str, decimals: int = 2, multiplier: int = 1) -> str:
        return czech_float(_get(id) * 1_000_000 * multiplier / population, decimals)

    if sector == Sector.INDUSTRY:
        return f'__Průmysl:__ {_total("industry")} mil. tun CO<sub>2</sub> ({_percent("industry")} % celkových emisí, {_per_person("industry")} t CO<sub>2</sub>eq na obyvatele ročně). V této kategorii jsou zahrnuty tři druhy emisí. Za prvé jde o emise ze spalování fosilních paliv v průmyslu (např. koksu ve vysokých pecích nebo zemního plynu v cementárně). Za druhé jde o procesní emise, které vznikají chemickou reakcí při výrobním procesu – například při redukci uhlíku z železné rudy nebo při kalcinaci vápence při výrobě cementu. Za třetí jde o úniky skleníkových plynů související s průmyslem – například úniky F-plynů při jejich používání v chladících průmyslových produktech nebo úniky metanu při těžbě uhlí či v plynárenské infrastruktuře.'

    elif sector == Sector.TRANSPORT:
        total_trains = get_emissions_value("CRF1A3C", df_crf)
        total_trains_str = czech_float(total_trains, 2)
        percent_trains_str = czech_float(total_trains / total_value * 100, 1)

        return f'__Doprava:__ {_total("transport")} mil. tun CO<sub>2</sub> ({_percent("transport")} % celkových emisí, {_per_person("transport")} t CO<sub>2</sub>eq na obyvatele ročně). Osobní automobilová doprava vyprodukuje {_total("transport_cars")} mil. tun CO<sub>2</sub> ({_percent("transport_cars")} %) ročně, zatímco nákladní a autobusová doprava je zodpovědná za {_total("transport_trucks-buses")} mil. tun CO<sub>2</sub> ({_percent("transport_trucks-buses")} %). Vlaková doprava je v grafu započtena, ale je příliš malá na to, aby se zobrazila ({total_trains_str} mil. tun CO<sub>2</sub>eq, což je {percent_trains_str} % celkových ročních emisí). Emise z letecké dopravy jsou {_total("transport_airplanes")} mil. tun tun CO<sub>2</sub> ({_percent("transport_airplanes")} %, {_per_person("transport_airplanes", 1, 1000)} kg na obyvatele ročně) a odpovídá emisím vyprodukovaným {get_flights_info(geo)}. Snížit emise z dopravy je možné přechodem na nízkouhlíková paliva (např. na elektřinu, biometan nebo vodík), zvýšením podílu vlakové a autobusové dopravy a snížením nutnosti přepravy (což může znamenat třeba bydlet blíže práci).'

    elif sector == Sector.ELECTRICITY_HEAT:
        if geo == Geo.CZ or geo == Geo.SK:
            total_electricity = _get("electricity-heat") - \
                _get("electricity-heat_CHP")
            total_electricity_str = czech_float(total_electricity, 2)
            total_electricity_percent_str = czech_float(
                total_electricity / total_value * 100, 2)

        if geo == Geo.CZ:
            details = f'Emise v energetice pochází především ze spalování hnědého uhlí a zemního plynu v elektrárnách ({total_electricity_str} milionů tun, resp. {total_electricity_percent_str} % celkových ročních emisí) a dále z tepláren ({_total("electricity-heat_CHP")} mil. tun, či {_percent("electricity-heat_CHP")} % celkových emisí ročně). Největším jednotlivým emitentem CO<sub>2</sub> jsou elektrárny v Počeradech (pět hnědouhelných bloků a jeden na zemní plyn), které ročně vyprodukují {_total("electricity-heat_pocerady")} mil. tun CO<sub>2</sub>, což je {_percent("electricity-heat_pocerady")} % celkových emisí České republiky. Pět největších českých fosilních elektráren, Počerady, Ledvice, Prunéřov, Tušimice a Chvaletice, vyprodukují ročně více emisí CO<sub>2</sub> než veškerá silniční doprava.'
        elif geo == Geo.SK:
            details = f'Tyto emise pochází především z tepláren ({_total("electricity-heat_CHP")} mil. tun, či {_percent("electricity-heat_CHP")} % celkových emisí ročně) a dále z tepelných elektráren ({total_electricity_str} milionů tun, resp. {total_electricity_percent_str} % celkových ročních emisí).'
        elif geo == Geo.EU27:
            details = ""

        return f'__Výroba elektřiny a tepla:__ {_total("electricity-heat")} milionů tun CO<sub>2</sub> ({_percent("electricity-heat")} % celkových emisí, {_per_person("electricity-heat")} t CO<sub>2</sub>eq na obyvatele ročně). {details} Emise skleníkových plynů původem z energetiky je možné snížit energetickými úsporami a rozvojem obnovitelných a nízkouhlíkových zdrojů energie.'

    elif sector == Sector.BUILDINGS:
        return f'__Budovy:__ {_total("buildings")} mil. tun CO<sub>2</sub> ({_percent("buildings")} % celkových emisí, tedy {_per_person("buildings")} t CO<sub>2</sub>eq na obyvatele ročně). Jde o topení a ohřev vody v domácnostech, kancelářích a institucích (pokud energie není dodávána z teplárny) a také o vaření plynem. Průmyslové budovy jsou zahrnuty v kategorii Průmysl.'

    elif sector == Sector.AGRICULTURE:
        livestock_str = czech_float(get_emissions_value("CRF31", df_crf), 2)
        managed_agricultural_soils_str = czech_float(
            get_emissions_value("CRF3D", df_crf), 2)

        return f'__Zemědělství:__ {_total("agriculture")} mil. tun CO<sub>2</sub>eq ({_percent("agriculture")} % celkových emisí, {_per_person("agriculture")} t CO<sub>2</sub>eq na obyvatele ročně). Emise v zemědělství pochází především z chovu hospodářských zvířat ({livestock_str} mil. tun) v podobě emisí metanu a také z obdělávání půdy a s tím spojenými emisemi N<sub>2</sub>O ({managed_agricultural_soils_str} mil. tun CO<sub>2</sub>eq). Také sem patří spalování pohonných hmot v zemědělství a lesnictví. K omezení emisí metanu ze zemědělství by pomohlo snížení počtu chovaného dobytka (a s tím související snížení spotřeby hovězího masa a mléčných výrobků), správné nakládání se statkovými hnojivy (například jejich stabilizací v bioplynových stanicích) a méně intenzivní hnojení průmyslovými hnojivy.'

    elif sector == Sector.WASTE:
        return f'__Odpadové hospodářství:__ {_total("waste")} mil. tun CO<sub>2</sub>eq ročně ({_percent("waste")} % celkových emisí, {_per_person("waste")} t CO<sub>2</sub>eq na obyvatele ročně). Emise z odpadového hospodářství produkují především skládky odpadu, ze kterých do atmosféry uniká metan, který vzniká rozkladem biologicky rozložitelného materiálu v tělese skládky. Řešením je zákaz skládkování využitelných odpadů po vzoru většiny zemí EU a využití biologicky rozložitelných odpadů k produkci biometanu pro užití namísto zemního plynu například v dopravě.'
