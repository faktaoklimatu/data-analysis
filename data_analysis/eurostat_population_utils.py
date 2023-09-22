""" Utils to load demographic data from eurostat. """

import eurostat
import pandas as pd

from data_analysis.eurostat_geo import Geo


def get_eurostat_population_data(geo: Geo, year: int) -> int:
    """ Returns population count for given geo and year """
    df: pd.DataFrame = eurostat.get_data_df('demo_pjan', filter_pars={
        'startPeriod': year,
        'endPeriod': year,
        'geo': geo.value,
        'age': 'TOTAL',
        'sex': 'T'})
    # In some version of python/pandas/eurostat, the column name is a (numeric) string.
    year_column_name = str(year)
    return df[year_column_name][0]
