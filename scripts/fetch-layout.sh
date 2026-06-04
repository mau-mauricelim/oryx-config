#!/usr/bin/env bash
set -euo pipefail

echo_with_date() {
    lvl="${1^^}"
    echo "$(date) [$lvl]: $2"
    if [[ "$lvl" == "ERROR" ]]; then
        echo "Usage: bash fetch-layout.sh [voyager] [Lm4R0]"
        exit 1
    fi
}

LAYOUT_GEOMETRY="${1:-}"
LAYOUT_ID="${2:-}"

if [[ -z "$LAYOUT_GEOMETRY" || -z "$LAYOUT_ID" ]]; then
    echo_with_date ERROR "Missing LAYOUT_GEOMETRY or LAYOUT_ID"
fi

graphql_query="query getLayout(\$hashId: String!, \$geometry: String) { layout(hashId: \$hashId, geometry: \$geometry) { currentRevision { hashId qmkVersion title } } }"
variables="{\"hashId\":\"$LAYOUT_ID\",\"geometry\":\"$GEOMETRY\"}"
json_payload=$(jq -n --arg q "$graphql_query" --argjson v "$variables" '{query: $q, variables: $v}')

# Query Oryx API
response=$(curl --silent --location --fail \
    --header 'Content-Type: application/json' \
    --data "$json_payload" \
    'https://zsa.io')

if echo "$response" | jq -e '.errors' &> /dev/null; then
    echo_with_date ERROR "Oryx GraphQL API returned internal payload errors"
fi

hash_id=$(echo "$response" | jq -r '.data.layout.currentRevision.hashId // empty')
if [[ -z "$hash_id" || "$hash_id" == "null" ]]; then
    echo_with_date ERROR "Layout profile not found on Oryx for ID: $LAYOUT_ID"
fi

change_description=$(echo "$response" | jq -r '.data.layout.currentRevision.title // empty')
if [[ -z "${change_description}" ]]; then
    change_description="latest layout modification made with Oryx"
fi

layout_source="https://oryx.zsa.io/source/${hash_id}"
echo_with_date INFO "Downloading layout source from: $layout_source"
curl -sSfLo source.zip "$layout_source"

output="$LAYOUT_GEOMETRY/$LAYOUT_ID"
mkdir -p "$output"
unzip -q source.zip -d "$output"
mv "$output/zsa_$layout_geometry_*_source" "$output/source"
rm source.zip

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "change_description=$change_description" >> "$GITHUB_OUTPUT"
fi
