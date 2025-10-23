#!/bin/bash
set -euo pipefail

# Show help if requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat << EOF
ha_apple_content_cache_client.sh - Home Assistant Apple Content Caching client

USAGE:
  ha_apple_content_cache_client.sh [--help|-h]

DESCRIPTION:
  Pushes Apple Content Caching metrics from macOS to Home Assistant via REST API.
  
CONFIGURATION:
  Set HA_URL, HA_TOKEN, and optionally CLIENT_ID and CACHE_NAME in:
  ${ENV_PATH:-/usr/local/etc/ha-apple_content_cache-client/.env}

EXAMPLES:
  ha_apple_content_cache_client.sh         # Run once
  brew services start ...                  # Run as service
EOF
  exit 0
fi

ENV_PATH="${ENV_PATH:-/usr/local/etc/ha-apple_content_cache-client/.env}"
if [ -f "$ENV_PATH" ]; then
  export $(grep -v '^#' "$ENV_PATH" | xargs)
fi

HA_URL="${HA_URL:-}"
HA_TOKEN="${HA_TOKEN:-}"
CACHE_NAME="${CACHE_NAME:-Apple Content Caching}"

if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ]; then
  echo "Error: HA_URL and HA_TOKEN must be set in $ENV_PATH"
  exit 1
fi

if [ -n "${CLIENT_ID:-}" ]; then
  CLIENT_NAME="$CLIENT_ID"
else
  CLIENT_NAME=$(hostname -s)
fi

LOG_FILE="/usr/local/var/log/ha-apple_content_cache-client.log"
mkdir -p "$(dirname "$LOG_FILE")"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

STATS_JSON=$(AssetCacheManagerUtil status -j 2>/dev/null || echo '{}')

# Helper function to safely extract numeric values and convert to MB
extract_mb() {
  local key="$1"
  local val
  val=$(echo "$STATS_JSON" | /usr/bin/jq -r "$key // 0" 2>/dev/null)
  awk "BEGIN {printf "%.2f", $val / 1024 / 1024}"
}

ACTIVE=$(echo "$STATS_JSON" | jq -r '.result.Active // false')
if [ "$ACTIVE" == "true" ]; then ACTIVE_STATE="on"; else ACTIVE_STATE="off"; fi

declare -A METRICS=(
  ["actual"]=".result.ActualCacheUsed"
  ["free"]=".result.CacheFree"
  ["used"]=".result.CacheUsed"
  ["icloud"]=".result.CacheDetails.iCloud"
  ["ios"]=".result.CacheDetails["iOS Software"]"
  ["mac"]=".result.CacheDetails["Mac Software"]"
  ["other"]=".result.CacheDetails.Other"
  ["origin"]=".result.TotalBytesStoredFromOrigin"
  ["clients"]=".result.TotalBytesReturnedToClients"
  ["dropped"]=".result.TotalBytesDropped"
)

for key in "${!METRICS[@]}"; do
  value=$(extract_mb "${METRICS[$key]}")
  entity="sensor.${CLIENT_NAME}_apple_content_caching_${key}"
  friendly="${CLIENT_NAME^} ${CACHE_NAME} (${key^})"
  payload=$(cat <<EOF
{
  "state": $value,
  "attributes": {
    "unit_of_measurement": "MB",
    "friendly_name": "$friendly"
  }
}
EOF
)
  echo "[$(timestamp)] Updating $entity -> ${value}MB" >> "$LOG_FILE"
  curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" -d "$payload" "$HA_URL/api/states/$entity" >/dev/null 2>&1 || true
done

# Active binary sensor
binary_entity="binary_sensor.${CLIENT_NAME}_apple_content_caching_active"
binary_payload=$(cat <<EOF
{
  "state": "$ACTIVE_STATE",
  "attributes": {
    "friendly_name": "${CLIENT_NAME^} ${CACHE_NAME} Active"
  }
}
EOF
)
echo "[$(timestamp)] Updating $binary_entity -> $ACTIVE_STATE" >> "$LOG_FILE"
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" -d "$binary_payload" "$HA_URL/api/states/$binary_entity" >/dev/null 2>&1 || true
