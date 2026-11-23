#!/usr/bin/env python
"""Download the source GSheet as `Dashboard tepláren.xlsx` into the current directory.

    python download_gsheet.py

Uses the same service account as update_gsheet.py (see its docstring for the
one-time setup; read access is enough here, but the Google Drive API must
also be enabled in the service account's Cloud project), so it works without any browser
login or Claude connector, e.g. in unattended runs. Google itself does the xlsx
export, so formulas keep their cached values. Needs access to
oauth2.googleapis.com, sheets.googleapis.com and www.googleapis.com.
"""
import os
import sys

import gspread
from gspread.utils import ExportFormat

SPREADSHEET_ID = "1l7xMSDAxTTECF9JDzXAMPVOGy7_vZao12-MpD7_ZBuQ"
OUTPUT = "Dashboard tepláren.xlsx"  # the name serialize.py expects


def main() -> int:
    credentials = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "service_account.json")
    sheet = gspread.service_account(filename=credentials).open_by_key(SPREADSHEET_ID)
    content = sheet.export(format=ExportFormat.EXCEL)  # fetch first: no empty file on error
    with open(OUTPUT, "wb") as handle:
        handle.write(content)
    print(f"Wrote {OUTPUT}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
