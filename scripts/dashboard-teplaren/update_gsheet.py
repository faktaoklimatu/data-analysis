#!/usr/bin/env python
"""Apply targeted cell updates to the source GSheet for dashboard-teplaren.

The downloaded `Dashboard tepláren.xlsx` copy must never be hand-edited and
saved back with openpyxl: re-saving a workbook that was only opened for
reading (not by Google Sheets) drops the cached values of formula cells that
weren't touched, which silently corrupts unrelated columns (observed:
`publish_to_web` and `share_households_dhs_in_czechia` turned into NaN for
every row after editing two unrelated cells and re-saving). Editing through
the Sheets API instead means Google recalculates formulas itself, so this is
the only safe way to change a handful of fields (e.g. `year_finished`,
`status_notes`) between full research passes.

Setup (one-time):
1. Create a Google Cloud service account with the Sheets API enabled.
2. Download its JSON key and save it as `service_account.json` in this
   directory (gitignored), or point GOOGLE_APPLICATION_CREDENTIALS at it.
3. Share the source GSheet with the service account's email (the
   `client_email` field in the JSON key) as an Editor.

Usage:
    python update_gsheet.py updates.yaml
    python update_gsheet.py updates.yaml --dry-run

updates.yaml format (a list of entries, matched by the `name` column in the
"Výstup Přehled velkých tepláren" sheet):

    - name: Karviná
      set:
        year_finished: 2029
        status_notes: >
          Full replacement text for the note...
      append_lines:
        "Další odkazy / zdroje":
          - https://example.org/some-article
"""
import argparse
import os
import sys

import gspread
import yaml

SPREADSHEET_ID = "1l7xMSDAxTTECF9JDzXAMPVOGy7_vZao12-MpD7_ZBuQ"
# NOTE: the xlsx export (used by serialize.py) strips the colon from this
# name since Excel sheet names can't contain one, but the real GSheet tab
# title (what gspread needs) keeps it.
SHEET_NAME = "Výstup: Přehled velkých tepláren"
KEY_COLUMN_HEADER = "name"
DATA_START_ROW = 4  # Row 3 holds headers; data starts on row 4.


def build_header_map(ws: gspread.Worksheet) -> dict[str, int]:
    """Map both the machine-readable headers (row 3) and the human labels
    (row 1) to their 1-indexed column number, preferring row 3 where both
    exist for the same column."""

    rows = [ws.row_values(3), ws.row_values(1), ws.row_values(2)]
    width = max(len(r) for r in rows)

    headers: dict[str, int] = {}
    for idx in range(width):
        for row in rows:
            if idx < len(row) and row[idx].strip():
                headers.setdefault(row[idx].strip(), idx + 1)
    return headers


def find_row(ws: gspread.Worksheet, name: str, key_col: int) -> int:
    for i, value in enumerate(ws.col_values(key_col)[DATA_START_ROW - 1 :], start=DATA_START_ROW):
        if value.strip() == name:
            return i
    raise ValueError(f"No row found where column {KEY_COLUMN_HEADER!r} == {name!r}")


def apply_entry(
    ws: gspread.Worksheet, headers: dict[str, int], entry: dict, dry_run: bool
) -> None:
    name = entry["name"]
    row = find_row(ws, name, headers[KEY_COLUMN_HEADER])

    for field, value in entry.get("set", {}).items():
        col = headers[field]
        action = "Would set" if dry_run else "Setting"
        print(f"{action} {name!r} row {row}, {field!r} (col {col}) -> {value!r}")
        if not dry_run:
            ws.update_cell(row, col, value)

    for field, lines in entry.get("append_lines", {}).items():
        col = headers[field]
        current = ws.cell(row, col).value or ""
        new_value = (current + "\n" if current else "") + "\n".join(lines)
        action = "Would append to" if dry_run else "Appending to"
        print(f"{action} {name!r} row {row}, {field!r} (col {col}) -> {new_value!r}")
        if not dry_run:
            ws.update_cell(row, col, new_value)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("updates_file", help="YAML file describing the updates to apply")
    parser.add_argument("--dry-run", action="store_true", help="Print what would change without writing anything")
    parser.add_argument(
        "--credentials",
        default=os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "service_account.json"),
        help="Path to a Google service account JSON key (default: $GOOGLE_APPLICATION_CREDENTIALS or ./service_account.json)",
    )
    args = parser.parse_args()

    with open(args.updates_file, encoding="utf-8") as f:
        entries = yaml.safe_load(f)

    if not entries:
        print("Nothing to do: updates file is empty.")
        return

    gc = gspread.service_account(filename=args.credentials)
    sh = gc.open_by_key(SPREADSHEET_ID)
    ws = sh.worksheet(SHEET_NAME)
    headers = build_header_map(ws)

    for entry in entries:
        apply_entry(ws, headers, entry, args.dry_run)

    if args.dry_run:
        print("\nDry run only, nothing was written. Re-run without --dry-run to apply.")


if __name__ == "__main__":
    try:
        main()
    except gspread.exceptions.SpreadsheetNotFound:
        print(
            "Spreadsheet not found or not shared with the service account "
            "(check the service account's client_email has Editor access).",
            file=sys.stderr,
        )
        sys.exit(1)
