#!/usr/bin/env bash
# setup-data-dirs.sh — create ./data/* and set the ownership each container's
# documented runtime UID needs. Replaces the old `chmod -R 777` bootstrap
# (world-writable Grafana SQLite = credential-theft vector for any local user).
#
# UIDs per official image docs:
#   Grafana       472:0       (uid grafana, gid root — grafana.com/docs: configure-docker)
#   Prometheus    65534:65534 (nobody — prom/prometheus Dockerfile)
#   Alertmanager  65534:65534 (nobody — prom/alertmanager Dockerfile)
#   Loki          10001:10001 (loki — grafana/loki Dockerfile)
# docker-compose.yml pins the same UIDs with `user:` so behavior is explicit.
#
# Usage:  sudo ./scripts/setup-data-dirs.sh
# Idempotent; safe to re-run. Run BEFORE `docker compose up -d` on first
# deploy and after pulling this change (Loki moves from root to UID 10001).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${REPO_DIR}/data"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: must run as root (chown to container UIDs): sudo $0" >&2
  exit 1
fi

declare -A OWNERS=(
  [grafana]="472:0"
  [prometheus]="65534:65534"
  [alertmanager]="65534:65534"
  [loki]="10001:10001"
)

for dir in "${!OWNERS[@]}"; do
  path="${DATA_DIR}/${dir}"
  owner="${OWNERS[$dir]}"
  mkdir -p "$path"
  chown -R "$owner" "$path"
  # Owner-only: rwX for the container UID, nothing for group/other.
  chmod -R u+rwX,go-rwx "$path"
  echo "OK: $path -> ${owner}"
done

echo
echo "Verify:"
ls -ln "$DATA_DIR"
