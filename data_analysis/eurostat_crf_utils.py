""" Utils to load CRF data from eurostat. """

from typing import Optional

import eurostat
import pandas as pd

from data_analysis.eurostat_geo import Geo


def get_eurostat_crf_data(geo: Optional[Geo], crf_code: Optional[str], year: int) -> pd.DataFrame:
    """
    Import data from Eurostat for a given geo / crf code and year.
    The dataframe is indexed by CRF codes / geo and has a single column, "value", in megatons CO2eq.
    """
    filter_pars = {
        "startPeriod": year,
        "endPeriod": year,
        "airpol": "GHG",
        "unit": "MIO_T"
    }
    if geo is not None:
        filter_pars["geo"] = geo.value
        main_dimension = "src_crf"
    elif crf_code is not None:
        filter_pars["src_crf"] = crf_code
        main_dimension = "geo"

    df = eurostat.get_data_df("env_air_gge", filter_pars=filter_pars)
    # Pandas query() does not allow backslash in column names so "rename column" is needed.
    # In some versions of data, the column is called geo\time, in some geo\TIME_PERIOD.
    # In some version of python/pandas/eurostat, the year column name is a (numeric) string.
    year_column_name = str(year)
    df = df.rename(columns={"geo\\time": "geo",
                            "geo\\TIME_PERIOD": "geo",
                            year_column_name: "value"})
    df = df[[main_dimension, "value"]]
    df = df.set_index(main_dimension)
    return df


def get_eurostat_crf_data_for_geo(geo: Geo, year: int) -> pd.DataFrame:
    return get_eurostat_crf_data(geo, None, year)


def get_eurostat_crf_data_for_code(crf_code: str, year: int) -> pd.DataFrame:
    # Hotfix for a missing code.
    if crf_code == "TOTX4_MEMONIA":
        # The TOTX4_MEMONIA code was dropped in a 2025 revision, so we
        # need to calculate it manually from the available components.
        df_totx4_memo = get_eurostat_crf_data(None, "TOTX4_MEMO", year)
        # CRF1D1A is the code for international aviation.
        df_intl_aviation = get_eurostat_crf_data(None, "CRF1D1A", year)
        return df_totx4_memo + df_intl_aviation

    return get_eurostat_crf_data(None, crf_code, year)
