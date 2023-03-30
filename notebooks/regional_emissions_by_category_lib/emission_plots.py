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
    # In some versions of data, the column is called geo\time, in some geo\TIME_PERIOD.
    df = df.rename(columns={'geo\\time': 'geo'})
    df = df.rename(columns={'geo\\TIME_PERIOD': 'geo'})
    df = df.query("airpol == 'GHG' and geo == @state and unit == 'MIO_T'")

    # In some version of python/pandas/eurostat, the column name is a (numeric) string.
    year_column_name = str(year)
    df = df[["src_crf", year_column_name]]  # select just sector code and year
    df = df.set_index('src_crf')
    df = df.rename(columns={year_column_name: 'value'})
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


def _add_line_to_df(wedge_code, wedge_value, df):
    df.loc[wedge_code, 'value'] = wedge_value # add a new line to current df


def _create_powerplant_allowances_list(definition):
    """Creates list of powerplants with allowances from definition"""
    allowances = []

    for inner_cat in definition:
        if "breakdown" not in inner_cat:
            continue
        for outer_cat in inner_cat["breakdown"]:
            if 'allowances' in outer_cat:
                allowances += outer_cat['sum']

    return(allowances)


def _add_sums_and_reminder(definition, total_value_code, perc_dict, df):
    cumulative_sum = 0
    total_divider = _get_value(TOTAL_EMISSION, df)  # divider for percentage computing

    # first pass to compute cumulative_sum
    for wedge_def in definition:
        if 'sum' in wedge_def:
            wedge_value = _get_sum(wedge_def['sum'], df)
            _add_line_to_df(wedge_def['code'], wedge_value, df)
            cumulative_sum += wedge_value

    # second pass to compute the reminder (if exists)
    for wedge_def in definition:
        if 'reminder' in wedge_def:
            wedge_value = _get_value(total_value_code, df) - cumulative_sum
            _add_line_to_df(wedge_def['code'], wedge_value, df)

    # third pass to compute values for outer perc dict (if in second pass, total outer chart sum > 1 so plot gets error)
    for wedge_def in definition:
        wedge_value = _get_value(wedge_def['code'], df)
        perc_dict[wedge_def['code']] = (wedge_value / total_divider)


def _compute_values(definition, outer_perc_dict, df):
    """Compute values for inner and outer chart structure"""
    _add_sums_and_reminder(definition, TOTAL_EMISSION, {}, df)

    for wedge_def in definition:
        if 'breakdown' in wedge_def:
            _add_sums_and_reminder(wedge_def['breakdown'], wedge_def['code'], outer_perc_dict, df)


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


def create_plot(state, year, definition):
    """Call the main functions together"""
    df = _get_data(state, year)

    powerplants = _create_powerplant_allowances_list(definition)

    df = _add_powerplant_data(df, year, powerplants)

    outer_perc_dict = {}
    _compute_values(definition, outer_perc_dict, df)

    plot_dict = _create_plot_lists(definition, outer_perc_dict)

    _draw_plot(state, year, plot_dict, outer_perc_dict, df)

