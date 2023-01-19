import matplotlib.pyplot as plt
import pandas as pd
import eurostat

TOTAL_EMISSION = 'TOTX4_MEMONIA' # global variable
HEADER_LINE_START = 16 # global variable


def _get_data(state, year):
    """Import data from Eurostat.
    Select certain data.
    Rename columns, set index.
    """
    df = eurostat.get_data_df('env_air_gge')
    # Pandas query() does not allow backslash in column names so "rename column" is needed.
    df = df.rename(columns={'geo\\time': 'geo'})
    df = df.query("airpol == 'GHG' and geo == @state and unit == 'MIO_T'")
    df = df[["src_crf", year]]  # select just sector code and year
    df = df.set_index('src_crf')
    df = df.rename(columns={year: 'value'})
    return df


def _get_value(key, df):
    return df.loc[key, 'value']


def _get_sum(keys, df):
    sum = 0
    for key in keys:
        sum += _get_value(key, df)
    return sum


def _add_powerplant_data(source_df, year, powerplants):
    """Import data from xls.
    Select certain data.
    Rename columns, set index,
    add to core dataframe.
    """
    # load excel
    df_input = pd.read_excel("verified_emissions_2021_en.xlsx", header=HEADER_LINE_START)

    # adjust excel
    df = df_input.loc[df_input["PERMIT_IDENTIFIER"].isin(powerplants)]
    df = df.rename(columns={f'VERIFIED_EMISSIONS_{year}': "value"})
    df = df.set_index('PERMIT_IDENTIFIER')["value"]
    df = df.div(1000000)
    df = pd.DataFrame(df)

    # join dataframes
    new_df = pd.concat([source_df, df])
    df = new_df
    return df


def _add_sums_and_reminder(definition, total_value_code, df):
    """Computes the sum values and a reminder.
    perc_dict gathers percents for each wedge.
    So we can show them in outer chart labels.
    """
    cumulative_sum = 0

    for wedge_def in definition:
        wedge_code = wedge_def['code']
        if 'sum' in wedge_def:
            wedge_value = _get_sum(wedge_def['sum'], df)
            cumulative_sum += wedge_value
        elif 'reminder' in wedge_def:
            wedge_value = _get_value(total_value_code, df) - cumulative_sum
        df.loc[wedge_code, 'value'] = wedge_value  # add a new line to current df


def _compute_values(definition, df):
    """Compute values for inner and outer chart structure"""
    _add_sums_and_reminder(definition, TOTAL_EMISSION, df)

    for wedge_def in definition:
        if 'breakdown' in wedge_def:
            _add_sums_and_reminder(wedge_def['breakdown'], wedge_def['code'], df)


def _find_category_index(definition, category_code):
    """Returns category indexes"""
    for index, category in enumerate(definition):
        if category["code"] == category_code:
            return index
        elif category["code"] == "CRF1A1_CRF1B":     # For EU plot without energy breakdown
            return False
    raise ValueError("Code not find in definition list")


def _category_reshuffling(definition, category_code, reminder_position=1):
    """Reshuffle positions of wedge_values in certain chart category
    so the reminder value does not have to be placed at the end."""
    category_index = _find_category_index(definition, category_code)

    if category_index is not False:                 # condition cause EU plot does not use energy breakdown structure

        category = definition[category_index]

        reminder = category["breakdown"][-1]
        tmp_breakdown = category["breakdown"][:-1]  # Takes all but the last element
        tmp_breakdown.insert(reminder_position, reminder)
        category["breakdown"] = tmp_breakdown


def _reshuffle_energy(definition):
    """Call category_reshuffling function"""
    _category_reshuffling(definition, "CRF1A1") # for the energy segment


def _compute_outer_perc_dict(definition, df):
    """Compute relative values to create outer chart"""
    result = {}
    total_divider = _get_value(TOTAL_EMISSION, df)

    for inner_cat in definition:
        if "breakdown" not in inner_cat:
            continue
        for outer_cat in inner_cat["breakdown"]:
            cat_code = outer_cat["code"]
            result[cat_code] = _get_value(cat_code, df) / total_divider

    return result


def _create_plot_lists(definition, outer_perc_dict):
    """Get lists of chart structures, labels and colors."""
    plot_dict = {
        "inner_chart_structure": [], "outer_chart_structure": [],
        "inner_labels": [], "outer_labels": [],
        "inner_colors": [], "outer_colors": []
    }

    for area in definition:
        plot_dict["inner_chart_structure"].append(area['code'])
        plot_dict["inner_labels"].append(area['label'])
        plot_dict["inner_colors"].append(area['color'])
        if 'breakdown' not in area:
            continue
        for subarea in area['breakdown']:
            plot_dict["outer_chart_structure"].append(subarea['code'])
            plot_dict["outer_labels"].append(
                f"{subarea['label']} {(outer_perc_dict[subarea['code']]):.1%}")
            plot_dict["outer_colors"].append(subarea['color'])
    return plot_dict


def _draw_plot(state, year, plot_dict, outer_perc_dict, df):
    """Define paramethers to draw the plot"""
    fig, ax = plt.subplots(figsize=(12, 12))
    inner_size = 0.35
    outer_size = 0.2

    # inner plot circle
    ax.pie(df.loc[plot_dict['inner_chart_structure']]['value'], radius=(2 * inner_size),
           labels=plot_dict['inner_labels'],
           counterclock=False,
           startangle=90, colors=plot_dict['inner_colors'], autopct='%1.1f%%',
           textprops={'fontsize': 12, 'fontweight': 'bold', 'color': '#000000'}, pctdistance=0.73,
           labeldistance=1.55,
           wedgeprops=dict(width=inner_size, edgecolor='w'))

    # outer plot circle
    ax.pie(outer_perc_dict.values(), radius=(2 * inner_size + outer_size), labels=plot_dict['outer_labels'], counterclock=False,
           startangle=90, normalize=False, colors=plot_dict['outer_colors'],
           textprops={'fontsize': 12}, labeldistance=1.2,
           wedgeprops=dict(width=outer_size, edgecolor='w'))

    # title
    plt.title(f'Emise skleníkových plynů pro {state} za rok {year} v CO2 ekviv.', fontsize=20)

    # show number in the middle
    total_emisions = round(df.loc[TOTAL_EMISSION, 'value'], 2)
    ax.annotate(total_emisions, xy=(0.1, 0.1), xytext=(-0.15, -0.01), fontsize=25)

    plt.show()


def create_plot(state, year, definition, powerplants):
    """Call the main functions together"""
    df = _get_data(state, year)

    df = _add_powerplant_data(df, year, powerplants)

    _compute_values(definition, df)

    _reshuffle_energy(definition)

    outer_perc_dict = _compute_outer_perc_dict(definition, df)

    plot_dict = _create_plot_lists(definition, outer_perc_dict)

    _draw_plot(state, year, plot_dict, outer_perc_dict, df)
