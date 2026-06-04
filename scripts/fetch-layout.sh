#!/usr/bin/env bash
set -euo pipefail

echo_with_date() {
    lvl="${1^^}"
    echo "$(date) [$lvl]: $2"
    if [[ "$lvl" == "ERROR" ]]; then
        echo "Usage: bash $0 [voyager] [Lm4R0]"
        exit 1
    fi
}

LAYOUT_GEOMETRY="${1:-}"
LAYOUT_ID="${2:-}"

if [[ -z "$LAYOUT_GEOMETRY" || -z "$LAYOUT_ID" ]]; then
    echo_with_date ERROR "Missing LAYOUT_GEOMETRY or LAYOUT_ID"
fi

# Query Oryx API
response=$(curl --location 'https://oryx.zsa.io/graphql' \
    --header 'Content-Type: application/json' \
    --data "{\"query\":\"query getLayout(\$hashId: String!, \$revisionId: String!, \$geometry: String) {layout(hashId: \$hashId, geometry: \$geometry, revisionId: \$revisionId) { revision { hashId, qmkVersion, title }}}\",\"variables\":{\"hashId\":\"$LAYOUT_ID\",\"geometry\":\"$LAYOUT_GEOMETRY\",\"revisionId\":\"latest\"}}" \
    | jq '.data.layout.revision | [.hashId, .qmkVersion, .title]')

hash_id=$(echo "${response}" | jq -r '.[0]')
if [[ -z "$hash_id" || "$hash_id" == "null" ]]; then
    echo_with_date ERROR "Layout profile not found on Oryx for ID: $LAYOUT_ID"
fi
firmware_version=$(printf "%.0f" $(echo "${response}" | jq -r '.[1]'))
change_description=$(echo "${response}" | jq -r '.[2]')
if [[ -z "${change_description}" ]]; then
    change_description="latest layout modification made with Oryx"
fi

layout_source="https://oryx.zsa.io/source/${hash_id}"
echo_with_date INFO "Downloading layout source from: $layout_source"
curl -sSfLo source.zip "$layout_source"

output="keyboards/$LAYOUT_GEOMETRY/$LAYOUT_ID"
mkdir -p "$output"
unzip -q -o source.zip -d "$output"
rm -rf "$output/source"
mv $output/zsa_${LAYOUT_GEOMETRY}_*_source "$output/source"
rm source.zip

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "change_description=$change_description" >> "$GITHUB_OUTPUT"
fi
