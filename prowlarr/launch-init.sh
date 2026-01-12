#!/usr/bin/with-contenv bash
set -euo pipefail

SCRIPT="/opt/init-prowlarr.sh"
LOG_PREFIX="[prowlarr-init-launch]"

log() { echo "${LOG_PREFIX} $*"; }

if [ ! -x "${SCRIPT}" ]; then
  log "Init script ${SCRIPT} missing or not executable; skipping."
  exit 0
fi

log "Starting init script in background; logs go to /config/prowlarr-init.log."
(
  exec "${SCRIPT}"
) &

exit 0
