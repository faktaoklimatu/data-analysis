""" Utils to load demographic data from eurostat. """

import eurostat
import pandas as pd

from data_analysis.eurostat_geo import Geo


def get_eurostat_population_data(year: int) -> int:
    """ Returns population count for given geo and year """
    df: pd.DataFrame = eurostat.get_data_df('demo_pjan', filter_pars={
        'startPeriod': year,
        'endPeriod': year,
        'age': 'TOTAL',
        'sex': 'T',
    })
    # Pandas query() does not allow backslash in column names so "rename column" is needed.
    # In some versions of data, the column is called geo\time, in some geo\TIME_PERIOD.
    # In some version of python/pandas/eurostat, the year column name is a (numeric) string.
    year_column_name = str(year)
    df = df.rename(columns={'geo\\time': 'geo',
                            'geo\\TIME_PERIOD': 'geo',
                            year_column_name: 'value'})
    df = df[['geo', 'value']]
    df = df.set_index('geo')
    return df


def get_eurostat_population_data_for_geo(geo: Geo, year: int) -> int:
    df = get_eurostat_population_data(year)
    return df.loc[geo.value, "value"]
