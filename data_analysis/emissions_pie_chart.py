""" Utils to generate CSV data and plots for emissions pie charts. """

from dataclasses import dataclass
from typing import Optional

import matplotlib.pyplot as plt
import pandas as pd


@dataclass
class Wedge:
    id: str
    value: float
    parent_id: str
    label: str
    color: str


def _get_wedge(wedge_def: dict, wedge_value: float, parent_id: Optional[str] = None) -> Wedge:
    id = wedge_def['id']
    full_id = id if parent_id is None else f"{parent_id}_{id}"
    return Wedge(id=full_id, value=wedge_value, parent_id=parent_id,
                 label=wedge_def['label'], color=wedge_def['color'])

def get_total_emissions_value(df_crf_and_allowances: pd.DataFrame) -> float:
    # The TOTX4_MEMONIA code was dropped in a 2025 revision, so we
    # need to calculate it manually from the available components.
    return df_crf_and_allowances.loc["TOTX4_MEMO", 'value'] + df_crf_and_allowances.loc["CRF1D1A", 'value']


def get_emissions_value(key: str, df_crf_and_allowances: pd.DataFrame) -> float:
    try:
        return df_crf_and_allowances.loc[key, 'value']
    except KeyError:
        print(f"Warning: missing CRF code {key} in the data, filled with 0.0.")
        return 0.0


def get_emissions_sum_value(keys: list[str], df_crf_and_allowances: pd.DataFrame) -> float:
    return sum([get_emissions_value(key, df_crf_and_allowances) for key in keys])


def get_emissions_wedges(definition: dict,
                         total_value: float,
                         df_crf_and_allowances: pd.DataFrame,
                         parent_id: Optional[str] = None) -> list[Wedge]:
    output: list[Wedge] = []

    # Compute the sum of all codes that appear in the definition (to allow computing the remainder).
    all_codes = sum((wedge_def.get('codes', [])
                    for wedge_def in definition), start=[])
    all_codes_sum = get_emissions_sum_value(all_codes, df_crf_and_allowances)

    for wedge_def in definition:
        if 'codes' in wedge_def:
            wedge_value = get_emissions_sum_value(
                wedge_def['codes'], df_crf_and_allowances)
        elif 'remainder' in wedge_def:
            wedge_value = total_value - all_codes_sum
        else:
            assert False, "A definition must have codes or remainder"

        output.append(_get_wedge(wedge_def, wedge_value, parent_id))
    return output


def print_emissions_wedges_to_csv(wedges: list[Wedge], csv_path: str) -> pd.DataFrame:
    df = pd.DataFrame(wedges).set_index("id")
    # Remove wedges with empty labels and remove the color column (not needed by Illustrator).
    df = df[df["label"] != ""].drop("color", axis=1)
    df.to_csv(csv_path)
    return df


def draw_emissions_pie_chart(geo: str,
                             year: int,
                             inner_wedges: list[Wedge],
                             outer_wedges: list[Wedge],
                             total_value: float) -> None:
    """Define parameters to draw the plot"""
    fig, ax = plt.subplots(figsize=(12, 12))
    fig.patch.set_facecolor('white')
    inner_size = 0.35
    outer_size = 0.2

    # inner plot circle
    ax.pie([wedge.value for wedge in inner_wedges],
           labels=[wedge.label for wedge in inner_wedges],
           colors=[wedge.color for wedge in inner_wedges],
           autopct='%1.1f%%', counterclock=False, radius=(2 * inner_size), startangle=90,
           textprops={'fontsize': 12, 'fontweight': 'bold', 'color': '#000000'}, pctdistance=0.73,
           labeldistance=1.55, wedgeprops=dict(width=inner_size, edgecolor='w'))

    # outer plot circle
    ax.pie([wedge.value / total_value for wedge in outer_wedges],
           labels=[wedge.label for wedge in outer_wedges],
           colors=[wedge.color for wedge in outer_wedges],
           radius=(2 * inner_size + outer_size), counterclock=False, startangle=90, normalize=False,
           textprops={'fontsize': 12}, labeldistance=1.2,
           wedgeprops=dict(width=outer_size, edgecolor='w'))

    # title
    plt.title(
        f'Emise skleníkových plynů pro {geo} za rok {year} v CO2 ekviv.', fontsize=20)

    # show number in the middle
    total_emisions = round(total_value, 2)
    ax.annotate(total_emisions, xy=(0.1, 0.1),
                xytext=(-0.15, -0.01), fontsize=25)

    plt.show()
