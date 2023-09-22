""" Utils to load allowances data (EUA) from an Excel file. """

from typing import Optional

import pandas as pd


_HEADER_LINE_START = 16  # global variable


def get_allowances_data(year: int, registry_code: str,
                        main_activity_code: Optional[int], eua_path: str) -> pd.DataFrame:
    """
    Import allowances data from an excel file for a given year and optinally, given code of main
    activity. The dataframe is indexed by permit codes and has a single column, 'value', in megatons
    CO2.
    """
    df: pd.DataFrame = pd.read_excel(eua_path, header=_HEADER_LINE_START)
    df = df.rename(
        columns={f"VERIFIED_EMISSIONS_{year}": "value"})

    main_activity_code_condition = True
    if main_activity_code is not None:
        main_activity_code_condition = (df["MAIN_ACTIVITY_TYPE_CODE"] == main_activity_code)
    df = df.loc[(main_activity_code_condition & (df["REGISTRY_CODE"] == registry_code)),
                ["PERMIT_IDENTIFIER", "value", "IDENTIFIER_IN_REG", "MAIN_ACTIVITY_TYPE_CODE"]]
    df.set_index('PERMIT_IDENTIFIER', inplace=True)
    # Some elements are string "Excluded" or -1, convert that to zeros. Convert tons to megatons.
    df["value"] = pd.to_numeric(df["value"],
                                errors='coerce').fillna(0).clip(lower=0) / 1_000_000
    df.sort_values("value", ascending=False, inplace=True)
    return df
