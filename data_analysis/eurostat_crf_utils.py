""" Utils to load CRF data from eurostat. """

import eurostat
import pandas as pd


def get_eurostat_crf_data(geo: str, year: int) -> pd.DataFrame:
    """
    Import data from Eurostat for a given geo (like 'CZ' or 'EU27_2020') and year.
    The dataframe is indexed by CRF codes and has a single column, 'value', in megatons CO2eq.
    """
    df = eurostat.get_data_df('env_air_gge', filter_pars={
        'startPeriod': year,
        'endPeriod': year,
        'geo': [geo],
        'airpol': ['GHG'],
        'unit': 'MIO_T'})
    # Pandas query() does not allow backslash in column names so "rename column" is needed.
    # In some versions of data, the column is called geo\time, in some geo\TIME_PERIOD.
    df = df.rename(columns={'geo\\time': 'geo', 'geo\\TIME_PERIOD': 'geo'})

    # In some version of python/pandas/eurostat, the column name is a (numeric) string.
    year_column_name = str(year)
    df = df[["src_crf", year_column_name]]  # select just sector code and year
    df = df.set_index('src_crf')
    df = df.rename(columns={year_column_name: 'value'})
    return df
