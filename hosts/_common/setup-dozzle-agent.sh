#!/usr/bin/env bash
# Deploy Dozzle agent on a Docker host (Linux / hub shell).
# Central UI: http://192.0.2.10:8888
#
# Required env:
#   DOZZLE_AGENT_HOSTNAME  - sidebar label (e.g. hub-111)
# Optional:
#   DOZZLE_AGENT_PUBLISH   - host port mapping (default 7007:7007)
#   ALFA_MONITORING_LOG_PUSH_DEST - scp log to the monitoring host () after run
#
# Usage (from hosts/192.0.2.10 or 192.0.2.10):
#   export DOZZLE_AGENT_HOSTNAME=hub-111
#   ./setup-dozzle-agent.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE="${ROOT}/hosts/_common/docker-compose.dozzle-agent.yml"
# shellcheck source=setup-lib.sh
source "${ROOT}/hosts/_common/setup-lib.sh"

alfa_setup_begin "dozzle-agent"

if [[ -z "${DOZZLE_AGENT_HOSTNAME:-}" ]]; then
  alfa_die "set DOZZLE_AGENT_HOSTNAME before running (e.g. hub-111)"
fi

USE_SUDO=0
SUDO=()
if [[ "$(id -u)" -ne 0 ]]; then
  if docker info >/dev/null 2>&1; then
    USE_SUDO=0
  else
    SUDO=(sudo)
    USE_SUDO=1
  fi
fi

alfa_verify_docker "$USE_SUDO"

if [[ ! -f "$COMPOSE" ]]; then
  alfa_die "missing $COMPOSE"
fi

export DOZZLE_AGENT_PUBLISH="${DOZZLE_AGENT_PUBLISH:-7007:7007}"

# hub / some hosts do not pass shell exports into docker compose interpolation;
# write an explicit env file (same pattern as brain-exporters on ).
ENV_FILE="$(mktemp /tmp/alfa-dozzle-agent.XXXXXX.env)"
cleanup_env_file() {
  rm -f "$ENV_FILE"
}
trap cleanup_env_file EXIT

cat >"$ENV_FILE" <<EOF
DOZZLE_AGENT_HOSTNAME=${DOZZLE_AGENT_HOSTNAME}
DOZZLE_AGENT_PUBLISH=${DOZZLE_AGENT_PUBLISH}
EOF
chmod 600 "$ENV_FILE"

compose_args=(docker compose --env-file "$ENV_FILE" -f "$COMPOSE")

alfa_log "docker compose pull (dozzle-agent image amir20/dozzle:v10.6.15)"
"${SUDO[@]}" "${compose_args[@]}" pull

alfa_log "docker compose up -d dozzle-agent (hostname=${DOZZLE_AGENT_HOSTNAME})"
"${SUDO[@]}" "${compose_args[@]}" up -d

alfa_verify_container_running "$USE_SUDO" dozzle-agent

alfa_log "agent listening on ${DOZZLE_AGENT_PUBLISH}"
alfa_log "Firewall: allow TCP 7007 from 192.0.2.10 only (see docs/DOZZLE_FLEET.md)"
alfa_log "Central UI should list this host after DOZZLE_REMOTE_AGENT includes this IP:7007"
alfa_setup_finish
