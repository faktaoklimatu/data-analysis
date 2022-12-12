import matplotlib.pyplot as plt
import eurostat

TOTAL_EMISSION = 'TOTX4_MEMONIA'


def _get_data(state, year):
    df = eurostat.get_data_df('env_air_gge')
    # Pandas query() does not allow backslash in column names so "rename column" is needed.
    df = df.rename(columns={'geo\\time': 'geo'})
    df = df.query("airpol == 'GHG' and geo == @state and unit == 'MIO_T'")
    df = df[["src_crf", year]]  # jen kod odvětví a rok
    df = df.set_index('src_crf')  # src_crf jako index
    df = df.rename(columns={year: 'value'})
    return df


def _get_value(key, df):  # získej hodnotu. Zadej klíč a df
    return df.loc[key, 'value']


def _get_sum(keys, df):
    sum = 0
    for key in keys:
        sum += _get_value(key, df)
    return sum


def _add_sums_and_reminder(definition, total_value_code, perc_dict, df):
    """Computes the sum values and a reminder.
    perc_dict gathers percents for each wedge.
    So we can show them in outer chart labels.
    """
    cumulative_sum = 0
    total_divider = _get_value(TOTAL_EMISSION, df)  # dělitel pro výpočet procent
    for wedge_def in definition:
        wedge_code = wedge_def['code']
        if 'sum' in wedge_def:
            wedge_value = _get_sum(wedge_def['sum'], df)
            cumulative_sum += wedge_value
        elif 'reminder' in wedge_def:
            wedge_value = _get_value(total_value_code, df) - cumulative_sum
        perc_dict[wedge_code] = (
                    wedge_value / total_divider)
        df.loc[wedge_code, 'value'] = wedge_value  # přidá nový řádek ke stávajímu df


def _compute_values(definition, df, outer_perc_dict):
    _add_sums_and_reminder(definition, TOTAL_EMISSION, {}, df)

    for wedge_def in definition:
        if 'breakdown' in wedge_def:
            _add_sums_and_reminder(wedge_def['breakdown'], wedge_def['code'], outer_perc_dict, df)


def _create_plot_lists(definition, outer_perc_dict):
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
                f"{subarea['label']} {(outer_perc_dict[subarea['code']]):.1%}")  # outer_perc_dict
            plot_dict["outer_colors"].append(subarea['color'])
    return plot_dict


def _draw_plot(state, year, plot_dict, outer_perc_dict, df):
    fig, ax = plt.subplots(figsize=(12, 12))
    inner_size = 0.35
    outer_size = 0.2

    # vnitřní
    ax.pie(df.loc[plot_dict['inner_chart_structure']]['value'], radius=(2 * inner_size),
           labels=plot_dict['inner_labels'],
           counterclock=False,
           startangle=90, colors=plot_dict['inner_colors'], autopct='%1.1f%%',
           textprops={'fontsize': 12, 'fontweight': 'bold', 'color': '#000000'}, pctdistance=0.73,
           labeldistance=1.55,
           wedgeprops=dict(width=inner_size, edgecolor='w'))

    # vnější
    ax.pie(outer_perc_dict.values(), radius=(2 * inner_size + outer_size), labels=plot_dict['outer_labels'], counterclock=False,
           startangle=90, normalize=False, colors=plot_dict['outer_colors'],
           textprops={'fontsize': 12}, labeldistance=1.2,
           wedgeprops=dict(width=outer_size, edgecolor='w'))

    # nadpis
    plt.title(f'Emise skleníkových plynů pro {state} za rok {year} v CO2 ekviv.', fontsize=20)

    # číslo v prostřed
    total_emisions = round(df.loc[TOTAL_EMISSION, 'value'], 2)
    ax.annotate(total_emisions, xy=(0.1, 0.1), xytext=(-0.15, -0.01), fontsize=25)

    plt.show()


def create_plot(state, year, definition):
    df = _get_data(state, year)

    outer_perc_dict = {}
    _compute_values(definition, df, outer_perc_dict)

    plot_dict = _create_plot_lists(definition, outer_perc_dict)

    _draw_plot(state, year, plot_dict, outer_perc_dict, df)
