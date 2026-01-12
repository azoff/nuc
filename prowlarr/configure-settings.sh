#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/config/config.xml"
API_KEY="${PROWLARR__ApiKey:-${PROWLARR_API_KEY:-}}"
AUTH_METHOD="${PROWLARR__AuthenticationMethod:-External}"
AUTH_REQUIRED="${PROWLARR__AuthenticationRequired:-DisabledForLocalAddresses}"
INSTANCE_NAME="${PROWLARR__InstanceName:-Prowlarr}"
BIND_ADDRESS="${PROWLARR__BindAddress:-*}"
PORT="${PROWLARR__Server__Port:-${PROWLARR_PORT:-9696}}"
LOG_LEVEL="${PROWLARR__LogLevel:-info}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

ensure_config_file() {
  if [ ! -f "${CONFIG_FILE}" ]; then
    mkdir -p "$(dirname "${CONFIG_FILE}")"
    cat >"${CONFIG_FILE}" <<EOF
<Config>
  <BindAddress>*</BindAddress>
  <SslPort>6969</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <ApiKey></ApiKey>
  <AuthenticationMethod>External</AuthenticationMethod>
  <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
  <Branch>master</Branch>
  <LogLevel>info</LogLevel>
  <SslCertPath></SslCertPath>
  <SslCertPassword></SslCertPassword>
  <UrlBase></UrlBase>
  <InstanceName>Prowlarr</InstanceName>
  <UpdateMechanism>Docker</UpdateMechanism>
</Config>
EOF
  fi
}

set_tag() {
  local tag="$1" value="$2"
  if grep -q "<$tag>" "${CONFIG_FILE}"; then
    sed -i "s|<${tag}>.*</${tag}>|<${tag}>${value}</${tag}>|" "${CONFIG_FILE}"
  else
    # insert before closing Config
    sed -i "s|</Config>|  <${tag}>${value}</${tag}>\n</Config>|" "${CONFIG_FILE}"
  fi
}

main() {
  ensure_config_file

  [ -n "${API_KEY}" ] && set_tag "ApiKey" "${API_KEY}"
  set_tag "AuthenticationMethod" "${AUTH_METHOD}"
  set_tag "AuthenticationRequired" "${AUTH_REQUIRED}"
  set_tag "BindAddress" "${BIND_ADDRESS}"
  set_tag "InstanceName" "${INSTANCE_NAME}"
  set_tag "LogLevel" "${LOG_LEVEL}"
  set_tag "Port" "${PORT}"
  # Preserve SslPort/EnableSsl as-is unless overridden via env
  if [ -n "${PROWLARR__Ssl__Port:-${PROWLARR_SSL_PORT:-}}" ]; then
    set_tag "SslPort" "${PROWLARR__Ssl__Port:-${PROWLARR_SSL_PORT}}"
  fi
  if [ -n "${PROWLARR__Ssl__Enabled:-${PROWLARR_ENABLE_SSL:-}}" ]; then
    set_tag "EnableSsl" "${PROWLARR__Ssl__Enabled:-${PROWLARR_ENABLE_SSL}}"
  fi

  # Ensure ownership/permissions for app user
  chown "${PUID}:${PGID}" "${CONFIG_FILE}"
  chmod 664 "${CONFIG_FILE}"
}

main "$@"
