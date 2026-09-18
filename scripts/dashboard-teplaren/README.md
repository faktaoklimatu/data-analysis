## Dependencies

- NumPy
- openpyxl
- pandas
- PyYAML
- gspread (only needed for `update_gsheet.py`)

## Usage

1. Download the dataset from Google Sheets as an Excel file called `Dashboard tepláren.xlsx`.
2. Run `fetch_mf.sh` to fetch open data from SFŽP.
3. Run `python serialize.py > dashboard-teplaren.yml` to generate the dataset in YAML.
4. Copy over to web-cz.
5. Delete the downloaded/generated files again (`Dashboard tepláren.xlsx`, `dashboard-teplaren.yml`, `sfzp_aktivni_IS*.csv`) — they're cheap to regenerate next time and shouldn't linger in the working directory.

## Updating the source GSheet

`update_gsheet.py` applies targeted cell edits (e.g. `year_finished`, `status_notes`, source links) straight to the source GSheet via the Sheets API, from a small YAML changeset. See the script's docstring for the changeset file format; the run instructions are `python update_gsheet.py <changeset>.yaml --dry-run`, then re-run without `--dry-run` once the dry-run output looks right. Delete the changeset file once applied — it's a one-off input, not something to keep around.

Do not try to apply such edits by hand-editing the downloaded `Dashboard tepláren.xlsx` with openpyxl and saving it back — re-saving a workbook that wasn't opened by Google Sheets drops the cached values of untouched formula cells, which silently corrupts unrelated columns.

### Getting a service account JSON key (one-time setup)

`update_gsheet.py` authenticates as a Google service account, not as a personal Google user. You need one that has the Sheets API enabled and Editor access to the source GSheet:

1. In the [Google Cloud Console](https://console.cloud.google.com/), pick or create a project (any project works; it doesn't need to be faktaoklimatu-branded).
2. Enable the **Google Sheets API** for that project: APIs & Services -> Enabled APIs & services -> + Enable APIs and Services -> search "Google Sheets API" -> Enable.
3. Create a service account: APIs & Services -> Credentials -> + Create Credentials -> Service account. Give it any name (e.g. `dashboard-teplaren-sheets`); it doesn't need any project-level IAM role since access is granted per-file in step 5.
4. Open the new service account -> Keys tab -> Add Key -> Create new key -> JSON. This downloads the key file — save it as `service_account.json` in this directory (`scripts/dashboard-teplaren/`). It's already gitignored; never commit it.
5. Open the key file (or the service account's Details tab in the Console) and copy its `client_email` (looks like `dashboard-teplaren-sheets@<project-id>.iam.gserviceaccount.com`). Share the [source GSheet](https://docs.google.com/spreadsheets/d/1l7xMSDAxTTECF9JDzXAMPVOGy7_vZao12-MpD7_ZBuQ/edit) with that email address as **Editor**, the same way you'd share it with a person.
6. Verify it works: `python update_gsheet.py <any-changeset>.yaml --dry-run` should read the sheet and print the planned changes without error.

If you'd rather not put the key file on disk, point `GOOGLE_APPLICATION_CREDENTIALS` at wherever you keep it instead (the script falls back to that env var when `service_account.json` isn't present).

## Fetching SFŽP open data

`fetch_mf.sh` pins the leaf certificate for `otevrenadata.sfzp.cz` in `sfzp_leaf_ca.pem`, because that host serves its certificate without the intermediate needed to build a chain against default trust stores. `sfzp_leaf_ca.pem` is a permanent, committed file (not something to regenerate or gitignore) — see the comment in `fetch_mf.sh` for how to refresh it if it stops working once the certificate rotates.
