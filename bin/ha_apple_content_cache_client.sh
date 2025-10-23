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

# Debug: Log the JSON output
echo "[$(timestamp)] AssetCacheManagerUtil output: $STATS_JSON" >> "$LOG_FILE"

# Check if we got valid JSON
if ! echo "$STATS_JSON" | jq empty 2>/dev/null; then
  echo "[$(timestamp)] ERROR: Invalid JSON from AssetCacheManagerUtil" >> "$LOG_FILE"
  exit 1
fi

# Helper function to safely extract numeric values and convert to MB
extract_mb() {
  local key="$1"
  local val
  val=$(echo "$STATS_JSON" | /usr/bin/jq -r "$key // 0" 2>/dev/null)
  awk "BEGIN {printf \"%.2f\", $val / 1024 / 1024}"
}

ACTIVE=$(echo "$STATS_JSON" | jq -r '.result.Active // false')
if [ "$ACTIVE" == "true" ]; then ACTIVE_STATE="on"; else ACTIVE_STATE="off"; fi

# Process each metric individually to avoid associative array issues
process_metric() {
  local key="$1"
  local jq_path="$2"
  local value=$(extract_mb "$jq_path")
  local entity="sensor.${CLIENT_NAME}_apple_content_caching_${key}"
  local client_cap=$(echo "${CLIENT_NAME}" | sed 's/./\U&/')
  local key_cap=$(echo "${key}" | sed 's/./\U&/')
  local friendly="${client_cap} ${CACHE_NAME} (${key_cap})"
  local payload=$(cat <<EOF
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
}

# Process each metric
process_metric "actual" ".result.ActualCacheUsed"
process_metric "free" ".result.CacheFree"
process_metric "used" ".result.CacheUsed"
process_metric "icloud" ".result.CacheDetails.iCloud"
process_metric "ios" '.result.CacheDetails["iOS Software"]'
process_metric "mac" '.result.CacheDetails["Mac Software"]'
process_metric "other" ".result.CacheDetails.Other"
process_metric "origin" ".result.TotalBytesStoredFromOrigin"
process_metric "clients" ".result.TotalBytesReturnedToClients"
process_metric "dropped" ".result.TotalBytesDropped"

# Active binary sensor
binary_entity="binary_sensor.${CLIENT_NAME}_apple_content_caching_active"
client_cap=$(echo "${CLIENT_NAME}" | sed 's/./\U&/')
binary_payload=$(cat <<EOF
{
  "state": "$ACTIVE_STATE",
  "attributes": {
    "friendly_name": "${client_cap} ${CACHE_NAME} Active"
  }
}
EOF
)
echo "[$(timestamp)] Updating $binary_entity -> $ACTIVE_STATE" >> "$LOG_FILE"
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" -d "$binary_payload" "$HA_URL/api/states/$binary_entity" >/dev/null 2>&1 || true
