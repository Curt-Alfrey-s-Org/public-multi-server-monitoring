#!/usr/bin/env bash
# Deploy NVIDIA DCGM exporter (:9400) for GPU temps/metrics on Linux Docker hosts.
# Usage (from a host folder, e.g. hosts/192.0.2.10):
#   sudo ALFA_DCGM_CONTAINER_NAME=ai-148-dcgm-exporter ./setup-dcgm-exporter.sh
#
# Requires: NVIDIA drivers, nvidia-container-toolkit, Docker Compose v2.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
# shellcheck source=setup-lib.sh
source "${DIR}/setup-lib.sh"

alfa_setup_begin "dcgm-exporter"

COMPOSE_FILE="${DIR}/docker-compose.dcgm-exporter.yml"
CONTAINER_NAME="${ALFA_DCGM_CONTAINER_NAME:-alfa-dcgm-exporter}"

USE_SUDO=0
SUDO=()
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO=(sudo)
  USE_SUDO=1
fi

if [[ "$USE_SUDO" -eq 1 ]]; then
  alfa_verify_docker 1
else
  alfa_verify_docker 0
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  alfa_die "missing $COMPOSE_FILE"
fi

alfa_verify_nvidia_for_docker_gpu

export ALFA_DCGM_CONTAINER_NAME="$CONTAINER_NAME"

alfa_log "docker compose pull (dcgm-exporter)"
"${SUDO[@]}" docker compose -f "$COMPOSE_FILE" pull dcgm-exporter

alfa_log "docker compose up -d (dcgm-exporter)"
if ! "${SUDO[@]}" docker compose -f "$COMPOSE_FILE" up -d dcgm-exporter; then
  alfa_log "FATAL: DCGM compose up failed"
  "${SUDO[@]}" docker compose -f "$COMPOSE_FILE" logs --tail 100 dcgm-exporter || true
  alfa_die "dcgm-exporter did not start"
fi

alfa_verify_container_running "$USE_SUDO" "$CONTAINER_NAME"

alfa_log "waiting for dcgm-exporter /metrics (up to 90s)"
metrics_ok=0
for _i in $(seq 1 30); do
  sample="$(curl -fsS --max-time 3 http://127.0.0.1:9400/metrics 2>/dev/null | head -c 800 || true)"
  if [[ "$sample" == *"# HELP "* ]] || [[ "$sample" == *"# TYPE "* ]]; then
    metrics_ok=1
    break
  fi
  sleep 2
done
if [[ "$metrics_ok" -ne 1 ]]; then
  alfa_die "metrics endpoint did not return Prometheus exposition: http://127.0.0.1:9400/metrics"
fi
alfa_log "ok: dcgm-exporter responds with Prometheus metrics"

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi 'Status: active'; then
  alfa_log "hint: ufw allow from 192.0.2.10 to any port 9400 proto tcp"
fi

alfa_log "Prometheus job nvidia-dcgm-remote scrapes this host :9400"
alfa_setup_finish
