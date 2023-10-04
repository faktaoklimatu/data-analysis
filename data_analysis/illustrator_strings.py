""" Utils to generate CSV data for string variables into Illustrator. """

import pandas as pd


def czech_float(number: float, decimals: int = 1) -> str:
    return f"{number:,.{decimals}f}".replace(",", " ").replace(".", ",").replace("-", "−")


def print_illustrator_strings_to_csv(strings: dict[str, str], csv_path: str):
    df = pd.DataFrame(data={"id": strings.keys(),
                      "value": strings.values()}).set_index("id")
    df.to_csv(csv_path)
    return df
