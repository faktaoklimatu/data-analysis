""" Utils to get CRF codes for sectors. """

from enum import Enum
from typing import Optional


class Sector(Enum):
    INDUSTRY = "industry"
    TRANSPORT = "transport"
    ELECTRICITY_HEAT = "electricity-heat"
    BUILDINGS = "buildings"
    AGRICULTURE = "agriculture"
    WASTE = "waste"
    OTHER = "other"


class Subsector(Enum):
    METAL = "metal"
    MINERAL = "mineral"
    FUELS = "fuels"

    CARS = "cars"
    TRUCKS_BUSES = "trucks-buses"
    AIRPLANES = "airplanes"


SECTOR_CODES: dict[Sector, list[str]] = {
    Sector.INDUSTRY: ['CRF2', 'CRF1A2', 'CRF1A1B', 'CRF1A1C', 'CRF1A3E', 'CRF1B'],
    Sector.TRANSPORT: ['CRF1A3A', 'CRF1A3B', 'CRF1A3C', 'CRF1A3D', 'CRF1D1A'],
    Sector.ELECTRICITY_HEAT: ['CRF1A1A'],
    Sector.BUILDINGS: ['CRF1A4A', 'CRF1A4B'],
    Sector.AGRICULTURE: ['CRF1A4C', 'CRF3'],
    Sector.WASTE: ['CRF5'],
}

SUBSECTOR_CODES: dict[Subsector, list[str]] = {
    Subsector.METAL: ['CRF1A2A', 'CRF1A2B', 'CRF2C'],
    Subsector.MINERAL: ['CRF1A2F', 'CRF2A'],
    Subsector.FUELS: ['CRF1A1C', 'CRF1A1B', 'CRF1A3E', 'CRF1B'],
    Subsector.CARS: ['CRF1A3B1'],
    Subsector.TRUCKS_BUSES: ['CRF1A3B2', 'CRF1A3B3'],
    Subsector.AIRPLANES: ['CRF1D1A', 'CRF1A3A'],
}

SECTOR_LABEL_CZ: dict[Sector, str] = {
    Sector.INDUSTRY: "Průmysl",
    Sector.TRANSPORT: "Doprava (včetně letecké)",
    Sector.ELECTRICITY_HEAT: "Výroba elektřiny a tepla",
    Sector.BUILDINGS: "Budovy",
    Sector.AGRICULTURE: "Zemědělství",
    Sector.WASTE: "Odpadové hospodářství",
    Sector.OTHER: "Jiné",
}

SUBSECTOR_LABEL_CZ: dict[Subsector, str] = {
    Subsector.METAL: "Ocel a jiné kovy",
    Subsector.MINERAL: "Cement a jiné minerály",
    Subsector.FUELS: "Těžba a zpracování fosilních paliv",
    Subsector.CARS: "Osobní automobilová doprava",
    Subsector.TRUCKS_BUSES: "Nákladní a autobusová doprava",
    Subsector.AIRPLANES: "Letecká doprava",
}

SECTOR_COLOR_INTERNAL: dict[Sector, str] = {
    Sector.INDUSTRY: "#7363bd",
    Sector.TRANSPORT: "#a10014",
    Sector.ELECTRICITY_HEAT: "#ff4245",
    Sector.BUILDINGS: "#00007f",
    Sector.AGRICULTURE: "#1ecfbd",
    Sector.WASTE: "#029485",
    Sector.OTHER: "#f8c551",
}

_subsector_color_sector: Optional[Sector] = None
_subsector_color_order: Optional[Sector] = 0


def get_next_internal_subsector_color(sector: Sector) -> str:
    global _subsector_color_sector, _subsector_color_order
    # Keep an internal counter for given sector (in a global variable)
    if sector == _subsector_color_sector:
        _subsector_color_order += 1
    else:
        _subsector_color_sector = sector
        _subsector_color_order = 1

    # For internal purposes, only decrease the alpha value from the base color
    assert _subsector_color_order <= 10, "only up to 10 subsectors is supported"
    alpha = 255 - 24 * _subsector_color_order
    return SECTOR_COLOR_INTERNAL[sector] + hex(alpha)[2:]


def get_sector_definition(sector: Sector) -> dict:
    definition = {'id': sector.value,
                  # TODO: generalize when generating data in multiple languages.
                  'label': SECTOR_LABEL_CZ[sector],
                  'color': SECTOR_COLOR_INTERNAL[sector]}
    if sector in SECTOR_CODES:
        return definition | {'codes': SECTOR_CODES[sector]}
    else:
        return definition | {'remainder': True}


def get_subsector_definition(sector: Sector, subsector: Subsector) -> dict:
    return {'id': subsector.value,
            'codes': SUBSECTOR_CODES[subsector],
            'label': SUBSECTOR_LABEL_CZ[subsector],
            'color': get_next_internal_subsector_color(sector)}


def get_invisible_subsector_definition() -> dict:
    # Sectors without label are not plotted (nor included in the CSV).
    return {'label': '',
            'color': '#ffffff00'}
