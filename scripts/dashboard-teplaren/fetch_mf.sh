#!/bin/bash

set -euo pipefail

# Fetch CSV file of "Modernizační fond" from open data of SFŽP
URL="https://otevrenadata.sfzp.cz/data/sfzp_aktivni_IS.csv"
OUTFILE="sfzp_aktivni_IS"

curl -L -o "$OUTFILE.csv" "$URL"
echo "Downloaded to $OUTFILE.csv"

# Keep only lines containing "ModF"
{ head -n 1 "$OUTFILE.csv"; grep "ModF" "$OUTFILE.csv"; } > "$OUTFILE.ModF.csv"
echo "Filtered to only ModF entries in $OUTFILE.ModF.csv"

# Keep only lines containing "HEAT" or "I+"
{ head -n 1 "$OUTFILE.csv"; grep -E "HEAT|I\+" "$OUTFILE.csv"; } > "$OUTFILE.CHP.csv"
echo "Filtered to only HEAT or I+ entries in $OUTFILE.CHP.csv"

# Note that the output CSV uses Single Low-9 Quotation Mark inside the company name instead of comma
# to avoid conflict with the CSV delimiter (and avoid escaping).

echo "Replace . by "," in numeric columns after importing into Google Sheets"