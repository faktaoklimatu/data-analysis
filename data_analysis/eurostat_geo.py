""" Selected geo codes understood by Eurostat API. """

from enum import Enum


class Geo(Enum):
    AT = "AT"
    BE = "BE"
    BG = "BG"
    CY = "CY"
    CZ = "CZ"
    DE = "DE"
    DK = "DK"
    EE = "EE"
    EL = "EL"
    ES = "ES"
    FI = "FI"
    FR = "FR"
    HR = "HR"
    HU = "HU"
    IE = "IE"
    IT = "IT"
    LT = "LT"
    LU = "LU"
    LV = "LV"
    MT = "MT"
    NL = "NL"
    PL = "PL"
    PT = "PT"
    RO = "RO"
    SE = "SE"
    SI = "SI"
    SK = "SK"

    EU27 = "EU27_2020"


eu27_geo_dict: dict[Geo, str] = {
    Geo.AT: 'Rakousko',
    Geo.BE: 'Belgie',
    Geo.BG: 'Bulharsko',
    Geo.CY: 'Kypr',
    Geo.CZ: 'Česko',
    Geo.DE: 'Německo',
    Geo.DK: 'Dánsko',
    Geo.EE: 'Estonsko',
    Geo.EL: 'Řecko',
    Geo.ES: 'Španělsko',
    Geo.FI: 'Finsko',
    Geo.FR: 'Francie',
    Geo.HR: 'Chorvatsko',
    Geo.HU: 'Maďarsko',
    Geo.IE: 'Irsko',
    Geo.IT: 'Itálie',
    Geo.LT: 'Litva',
    Geo.LU: 'Lucembursko',
    Geo.LV: 'Lotyšsko',
    Geo.MT: 'Malta',
    Geo.NL: 'Nizozemsko',
    Geo.PL: 'Polsko',
    Geo.PT: 'Portugalsko',
    Geo.RO: 'Rumunsko',
    Geo.SE: 'Švédsko',
    Geo.SI: 'Slovinsko',
    Geo.SK: 'Slovensko',
}
