#!/bin/bash

set -euo pipefail

# Fetch CSV file of "Modernizační fond" from open data of SFŽP
URL="https://otevrenadata.sfzp.cz/data/sfzp_aktivni_IS.csv"
OUTFILE="sfzp_aktivni_IS"

# otevrenadata.sfzp.cz serves its leaf certificate without the "Thawte TLS RSA
# CA G1" intermediate, so default trust stores can't build the chain. Pin the
# leaf cert directly instead of disabling verification. Re-fetch
# sfzp_leaf_ca.pem (e.g. via `openssl s_client -connect otevrenadata.sfzp.cz:443
# -showcerts`) if this starts failing after the certificate rotates (valid
# until 2026-12-18).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
curl -L --cacert "$SCRIPT_DIR/sfzp_leaf_ca.pem" -o "$OUTFILE.csv" "$URL"
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