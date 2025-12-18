#!/usr/bin/env python
import locale
import logging
import math
import re
import sys
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import yaml

CHP_STATUS_MAP: dict[str, str] = {
    "B: nepodpořeno": "rejected",
    "C: podpořeno": "accepted",
}


DH_STATUS_MAP: dict[str, str] = {
    "Hotovo": "done",
    "Probíhá": "in-progress",
    "Problematické": "problematic",
}

FUELS_MAP: dict[str, str] = {
    "Biomasa": "biomass",
    "Bioplyn": "biogas",
    "Černé uhlí": "hardcoal",
    "Energoplyn": "syngas",
    "Hnědé uhlí": "lignite",
    "Hutní plyn": "metgas",
    "Jaderné teplo": "nuclear",
    "Koksárenský plyn": "cokegas",
    "Komunální odpad": "msw",
    "LTO": "lho",
    "Odpadní teplo": "wasteheat",
    "TAP": "srf",
    "TTO": "hho",
    "Zemní plyn": "natgas",
    "Zásobování odjinud": "alt",
}


class QuotedString(str):
    """Wrapper for strings to enforce that it always be surrounded with
    quotes in YAML representation."""

    @staticmethod
    def yaml_represent(dumper: yaml.Dumper, data: Any) -> yaml.Node:
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="'")


def approximate_xy_coordinates(lon: float, lat: float) -> tuple[float, float] | None:
    """Approximate X-Y coordinates of WGS 84 geographic coordinates.
    The approximation is only valid for the region of Czechia.
    For direct use in CSS."""

    if np.isnan(lat) or np.isnan(lon):
        return None

    x = 100 * (lon - 12.05) / 7.4
    y = 100 * ((51.18 - lat) / 3.18)
    return x, y


def nan_default(value: Any, default: Any = None) -> Any:
    """Fall back to the specified default value if the input is NaN."""

    if isinstance(value, float) and np.isnan(value):
        return default
    return value


def process_row(row: pd.Series, df_mf: pd.DataFrame, df_chp: pd.DataFrame) -> dict:
    ghg_cols = [col for col in row.index if col.startswith("ghg_2")]
    emissions = row[ghg_cols][::-1].astype(float).div(1e6).round(3)
    coords = approximate_xy_coordinates(row["lon"], row["lat"])

    item = {
        "name": row["name"],
        "name_details": row["name_details"],
        "x": round(coords[0], 1) if coords else None,
        "y": round(coords[1], 1) if coords else None,
        "lon": round(row["lon"], 2) if coords else None,
        "lat": round(row["lat"], 2) if coords else None,
        "status": DH_STATUS_MAP.get(row["status_simple"], "unknown"),
        "status_text": row["status_text"],
        "notes": row["status_notes"],
        "owner": row["owner"],
        "owner_web": nan_default(row["owner_web"]),
        "num_households": int(nan_default(row["num_households"], 0)),
        "munis_supplied": nan_default(row["munis_supplied_simple"]),
        "fuels_main_today": row["fuels_main_today"],
    }

    if not emissions.isna().all():
        item["emissions_mtco2eq"] = emissions.fillna(0.0).tolist()
        item["emissions_latest"] = item["emissions_mtco2eq"][-1]

    if isinstance(row["ghg_note"], str) and row["ghg_note"] != "":
        item["emissions_note"] = row["ghg_note"]

    for col in (
        "fuels_main_future",
        "fuels_secondary_future",
        "fuels_secondary_today",
        "other_heating",
    ):
        if (isinstance(row[col], str) or isinstance(row[col], list)) and len(
            row[col]
        ) > 0:
            item[col] = row[col]

    if not np.isnan(row["share_households"]):
        item["share_households"] = round(100 * row["share_households"])

    # Include ModF subsidies.
    mf_ids = row["mf_application_ids"]
    if isinstance(mf_ids, list) and len(mf_ids) > 0:
        item["mf_subsidies"] = []

        for mf_id, mf_row in df_mf.loc[mf_ids].iterrows():
            item["mf_subsidies"].append(
                {
                    "call": mf_row.Call,
                    "application_id": mf_id,
                    "name": mf_row.ShortName,
                    "long_name": mf_row.LongName,
                    "amount": round(mf_row["Amount"]),
                }
            )

        mf_subsidies_total = round(df_mf.loc[mf_ids, "Amount"].sum())
        item["mf_subsidies_total"] = mf_subsidies_total
        item["mf_subsidies_per_household"] = round(
            1e6 * mf_subsidies_total / row["num_households"]
        )

    # Include CHP subsidies
    chp_ids = row["chp_application_ids"]
    if isinstance(chp_ids, list) and len(chp_ids) > 0:
        item["chp_subsidies"] = []
        for chp_id, chp_row in df_chp.loc[chp_ids].iterrows():
            item["chp_subsidies"].append(
                {
                    "power": round(chp_row["Power"]),
                    "since": QuotedString(chp_row["SinceDate"].strftime("%m/%Y")),
                    "fuel": chp_row["Fuel"],
                    "status": CHP_STATUS_MAP.get(chp_row["Status"], "unknown"),
                }
            )

    return item


def read_chp_supported_projects(filename: str | Path) -> pd.DataFrame:
    column_mapping = {
        "Instalovaný výkon (MWe)": "Power",
        "Datum \nuvedení do \nprovozu": "SinceDate",
        "Stav": "Status",
        "Druh paliva": "Fuel",
    }

    df = pd.read_excel(
        filename,
        # NOTE: Apparently, colons are not supported in sheet names.
        sheet_name="Vstup Podpora KVET",
        engine="openpyxl",
        index_col="Kód",
    )
    df = df[list(column_mapping)].rename(columns=column_mapping)

    df["Fuel"] = df["Fuel"].str.replace("\\s+", " ", regex=True)

    return df


def read_dh_systems(filename: str | Path) -> pd.DataFrame:
    def _map_fuels(fuels: list[str] | float) -> list[str] | float:
        if isinstance(fuels, list):
            return [FUELS_MAP.get(f, "unknown") for f in fuels]
        return fuels

    df = (
        pd.read_excel(
            filename,
            sheet_name="Teplárenství - komplet",
            engine="openpyxl",
            skiprows=2,
            usecols=lambda col: not col.startswith("Unnamed"),
        )
        .query("primary_product != '-- část --'")
        .sort_values(by="num_households", ascending=False)
    )

    for col in (
        "chp_application_ids",
        "fuels_main_future",
        "fuels_main_today",
        "fuels_secondary_future",
        "fuels_secondary_today",
        "mf_application_ids",
    ):
        df[col] = df[col].str.split(", ")
        if col.startswith("fuels_"):
            df[col] = df[col].apply(_map_fuels)

    return df


def read_modernisation_fund_projects(filename: str | Path) -> pd.DataFrame:
    column_mapping = {
        "Výzva": "Call",
        "Název akce": "LongName",
        "Název stručně": "ShortName",
        "Dotace (Kč)": "Amount",
    }

    df = pd.read_excel(
        filename,
        # NOTE: Apparently, there's a bug in openpyxl such that colons are not
        # supported in sheet names and the name is clipped to 31 characters.
        sheet_name="Vstup ModFond HEAT podpořené pr",
        engine="openpyxl",
        skiprows=1,
        index_col="Číslo RM",
    )
    df = df[list(column_mapping)].rename(columns=column_mapping)

    df.index = df.index.map(str)
    df["Amount"] = df["Amount"].div(1e6)
    df["Call"] = df["Call"].str.extract(r"(\d+/\d{4})$")[0]
    df["LongName"] = df["LongName"].apply(lambda s: re.sub("\\s+", " ", s))

    return df


if __name__ == "__main__":
    locale.setlocale(locale.LC_ALL, "cs_CZ")
    logging.basicConfig(
        format="%(levelname)s [%(asctime)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        level=logging.DEBUG,
        stream=sys.stderr,
    )
    logger = logging.getLogger()

    items: list[dict] = []

    # TODO: Read from the published GSheet instead.
    dataset_filename = "Dashboard tepláren.xlsx"

    # Database of district heating systems (DHS).
    logger.info(f"Reading district heating systems from {dataset_filename}...")
    df_dhs = read_dh_systems(dataset_filename)
    df_dhs_visible = df_dhs.query("publish_to_web == 1")
    df_dhs_hidden = df_dhs.query("publish_to_web != 1")

    # Database of projects supported from the Modernisation Fund (ModF).
    logger.info("Reading projects supported from the ModFund...")
    df_mf = read_modernisation_fund_projects(dataset_filename)

    # Database of projects supported from the CHP programme
    # ("provozní podpora KVET").
    logger.info(f"Reading supported CHP projects...")
    df_chp = read_chp_supported_projects(dataset_filename)

    for i, row in df_dhs_visible.iterrows():
        logger.debug(f"Processing site ‘{row['name']}’...")

        item = process_row(row, df_mf, df_chp)

        items.append(item)

    df_highlights = df_dhs_visible.groupby("status_simple").agg(
        ghg_share=("ghg_share", "sum"),
        num_households=("num_households", "sum"),
        num_items=("name", "count"),
    )
    df_highlights = df_highlights.iloc[[1, 2, 0]]

    highlights = [
        {
            "status": DH_STATUS_MAP[status_simple],
            "number": int(row.num_items),
            "num_households": int(row.num_households),
            "ghg_share": round(100 * float(row.ghg_share), 2),
        }
        for status_simple, row in df_highlights.iterrows()
    ]

    highlights.append(
        {
            "status": "not-shown",
            "number": len(df_dhs_hidden),
            "num_households": int(df_dhs_hidden.num_households.sum()),
            "ghg_share": round(100 * float(df_dhs_hidden.ghg_share.sum()), 2),
        }
    )

    logger.info("All plants processed. Exporting YAML...")

    result = {"highlights": highlights, "items": items}

    yaml.add_representer(QuotedString, QuotedString.yaml_represent)
    yaml.dump(result, sys.stdout, allow_unicode=True, sort_keys=False, width=math.inf)

    logger.info("Finished")
