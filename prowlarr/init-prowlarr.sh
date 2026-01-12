#!/usr/bin/with-contenv bash
set -euo pipefail

API_KEY="${PROWLARR__ApiKey:-${PROWLARR_API_KEY:-}}"
API_URL="http://127.0.0.1:${PROWLARR__Server__Port:-${PROWLARR_PORT:-9696}}/api/v1"
CLIENT_NAME="Transmission"
TRANSMISSION_HOST="${TRANSMISSION_HOST:-vpn}"
TRANSMISSION_PORT="${TRANSMISSION_PORT:-9091}"
TRANSMISSION_USER="${TRANSMISSION_USER:-transmission}"
TRANSMISSION_PASSWORD="${TRANSMISSION_PASSWORD:-transmission}"
LOG_PREFIX="[prowlarr-init]"
LOG_FILE="/config/prowlarr-init.log"
TPB_BASE_URL="${TPB_BASE_URL:-https://apibay.org}"

log() {
  echo "${LOG_PREFIX} $*"
  printf '%s %s\n' "${LOG_PREFIX}" "$*" >>"${LOG_FILE}"
}

wait_for_api() {
  if [ -z "${API_KEY}" ]; then
    log "ERROR: API key not provided. Set PROWLARR_API_KEY (or PROWLARR__API_KEY)." >&2
    return 1
  fi
  for i in {1..60}; do
		if curl -fsS -H "X-Api-Key: ${API_KEY}" "${API_URL}/system/status" >/dev/null 2>&1; then
      log "API is ready (attempt ${i})."
      return 0
		else
			log "API not ready yet (attempt ${i}); retrying..."
    fi
    sleep 2
  done
  log "ERROR: Prowlarr API did not become ready in time." >&2
  return 1
}

client_exists() {
  curl -fsS -H "X-Api-Key: ${API_KEY}" "${API_URL}/downloadclient" \
    | jq -e 'map(.name=="'"${CLIENT_NAME}"'") | any' >/dev/null
}

create_transmission_client() {
  log "Creating Transmission download client pointing at ${TRANSMISSION_HOST}:${TRANSMISSION_PORT}."
  schema=$(curl -fsS -H "X-Api-Key: ${API_KEY}" "${API_URL}/downloadclient/schema" || true)
  if [ -z "${schema}" ]; then
    log "ERROR: Empty schema response from /downloadclient/schema"
    return 1
  fi

  payload=$(echo "${schema}" | jq --arg host "${TRANSMISSION_HOST}" \
    --argjson port "${TRANSMISSION_PORT}" \
    --arg user "${TRANSMISSION_USER}" \
    --arg pass "${TRANSMISSION_PASSWORD}" \
    --arg name "${CLIENT_NAME}" '
    map(select(.implementation=="Transmission"))[0] as $d |
    {
      name: $name,
      enable: true,
      categories: [],
      supportsCategories: true,
      protocol: $d.protocol,
      priority: 1,
      removeCompletedDownloads: true,
      removeFailedDownloads: true,
      implementation: $d.implementation,
      implementationName: $d.implementationName,
      configContract: $d.configContract,
      fields: ($d.fields | map(
        if .name=="host" then .value=$host
        elif .name=="port" then .value=$port
        elif .name=="username" then .value=$user
        elif .name=="password" then .value=$pass
        else . end
      )),
      tags: []
    }
  ')

  if [ -z "${payload}" ] || [ "${payload}" = "null" ]; then
    log "ERROR: Could not build payload for Transmission download client; schema missing?"
    return 1
  fi

  resp=$(curl -sS -o /tmp/transmission-create.out -w '%{http_code}' -H "X-Api-Key: ${API_KEY}" -H 'Content-Type: application/json' \
    -X POST "${API_URL}/downloadclient" \
    -d "${payload}" || true)
  if [ "${resp}" != "200" ] && [ "${resp}" != "201" ]; then
    log "ERROR: Transmission client create failed (status ${resp}): $(cat /tmp/transmission-create.out)"
    return 1
  fi
  log "Transmission download client created (status ${resp})."
}

create_tpb_indexer() {
  log "Creating The Pirate Bay indexer with base URL ${TPB_BASE_URL}."
  schema=$(curl -fsS -H "X-Api-Key: ${API_KEY}" "${API_URL}/indexer/schema" || true)
  if [ -z "${schema}" ]; then
    log "ERROR: Empty schema response from /indexer/schema"
    return 1
  fi
  payload=$(echo "${schema}" | jq --arg baseUrl "${TPB_BASE_URL}" '
    map(select(.name=="The Pirate Bay"))[0] as $d |
    {
      name: $d.name,
      enable: true,
      enableRss: true,
      enableAutomaticSearch: true,
      enableInteractiveSearch: true,
      appProfileId: 1,
      priority: 25,
      supportsRss: true,
      supportsSearch: true,
      protocol: $d.protocol,
      implementation: $d.implementation,
      configContract: $d.configContract,
      definitionName: $d.name,
      definitionId: $d.id,
      fields: ($d.fields | map(if .name=="baseUrl" then .value=$baseUrl else . end)),
      tags: []
    }
  ')

  if [ -z "${payload}" ] || [ "${payload}" = "null" ]; then
    log "ERROR: Could not build payload for The Pirate Bay indexer; schema missing?"
    return 1
  fi

  resp=$(curl -sS -o /tmp/tpb-create.out -w '%{http_code}' -H "X-Api-Key: ${API_KEY}" -H 'Content-Type: application/json' \
    -X POST "${API_URL}/indexer" \
    -d "${payload}" || true)
  if [ "${resp}" != "200" ] && [ "${resp}" != "201" ]; then
    log "ERROR: TPB create failed (status ${resp}): $(cat /tmp/tpb-create.out)"
    return 1
  fi
  log "The Pirate Bay indexer created (status ${resp})."
}

ensure_tpb_indexer() {
  existing_json=$(curl -fsS -H "X-Api-Key: ${API_KEY}" "${API_URL}/indexer")
  tpb_id=$(echo "${existing_json}" | jq -r 'map(select(.name=="The Pirate Bay"))[0].id // empty')
  tpb_enabled=$(echo "${existing_json}" | jq -r 'map(select(.name=="The Pirate Bay"))[0].enable // false')

  if [ -n "${tpb_id}" ]; then
    if [ "${tpb_enabled}" = "true" ]; then
      log "The Pirate Bay indexer already present and enabled; skipping creation."
      return 0
    fi
    log "Enabling existing The Pirate Bay indexer (id ${tpb_id})."
    body=$(curl -fsS -H "X-Api-Key: ${API_KEY}" "${API_URL}/indexer/${tpb_id}")
    body=$(echo "${body}" | jq '.enable=true | .appProfileId=1')
    resp=$(echo "${body}" | curl -sS -o /tmp/tpb-update.out -w '%{http_code}' -H "X-Api-Key: ${API_KEY}" -H 'Content-Type: application/json' \
      -X PUT "${API_URL}/indexer/${tpb_id}" -d @- || true)
    if [ "${resp}" != "200" ] && [ "${resp}" != "202" ]; then
      log "ERROR: TPB enable failed (status ${resp}): $(cat /tmp/tpb-update.out)"
      return 1
    fi
    log "The Pirate Bay indexer enabled (status ${resp})."
    return 0
  fi

  create_tpb_indexer
}

main() {
  log "Waiting for Prowlarr API to be ready..."
  wait_for_api || exit 1

  if client_exists; then
    log "Transmission client already present; skipping creation."
  else
    create_transmission_client
  fi

  ensure_tpb_indexer
}

main "$@"
