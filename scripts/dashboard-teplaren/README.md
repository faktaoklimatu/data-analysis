## Dependencies

- NumPy
- openpyxl
- pandas
- PyYAML

## Usage

1. Download the dataset from Google Sheets as an Excel file called `Dashboard tepláren.xlsx`.
2. Run `fetch_mf.sh` to fetch open data from SFŽP.
3. Run `python serialize.py > dashboard-teplaren.yml` to generate the dataset in YAML.
4. Copy over to web-cz.
