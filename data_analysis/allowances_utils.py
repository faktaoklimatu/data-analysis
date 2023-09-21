""" Utils to load allowances data (EUA) from an Excel file. """

import pandas as pd


_HEADER_LINE_START = 16  # global variable


def get_allowances_data(year: int, allowance_permit_codes: list[str], eua_path: str) -> pd.DataFrame:
    """
    Import allowances data from an excel file for a given year and given list of permit codes.
    The dataframe is indexed by permit codes and has a single column, 'value', in megatons CO2.
    """
    # load excel
    allowances_df = pd.read_excel(eua_path, header=_HEADER_LINE_START)

    # adjust excel
    # Select the right rows and columns from the data frame.
    allowances_df = allowances_df.rename(
        columns={f"VERIFIED_EMISSIONS_{year}": "value"})
    allowances_df = allowances_df.loc[allowances_df["PERMIT_IDENTIFIER"].isin(allowance_permit_codes),
                                      ["PERMIT_IDENTIFIER", "value"]]
    allowances_df.set_index('PERMIT_IDENTIFIER', inplace=True)
    # Some elements are string "Excluded" or -1, convert that to zeros. Convert tons to megatons.
    allowances_df["value"] = pd.to_numeric(allowances_df["value"],
                                           errors='coerce').fillna(0).clip(lower=0) / 1_000_000
    return allowances_df
