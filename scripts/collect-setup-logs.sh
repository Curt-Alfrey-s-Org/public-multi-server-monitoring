#!/usr/bin/env bash
# Run on the monitoring host (192.0.2.10). Pulls latest alfa-monitoring setup logs
# from cluster members via scp for analysis (Grafana/Loki not required).
#
# Prereq: SSH key auth to each host as SSH_USER.
#
# Remote paths tried in order:
#   ~/.local/state/alfa-monitoring-setup/latest.log   (Linux / hub non-root)
#   /var/log/alfa-monitoring-setup/latest.log         (Linux root)
#   /c/ProgramData/AlfaMonitoring/setup-logs/latest-run.log  (Windows OpenSSH path)
#
# Usage:
#   chmod +x scripts/collect-setup-logs.sh
#   SSH_USER=operator ./scripts/collect-setup-logs.sh
#
# Optional:
#   HOSTS="192.0.2.10 192.0.2.10" SSH_USER=operator ./scripts/collect-setup-logs.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${MONITORING_ROOT:-$ROOT}/data/setup-logs/collected"
SSH_USER="${SSH_USER:-}"
TS="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST/$TS"

DEFAULT_HOSTS=(192.0.2.10 192.0.2.10 192.0.2.10 192.0.2.10 192.0.2.10 192.0.2.10)
if [[ -n "${HOSTS:-}" ]]; then
  read -r -a HOST_ARR <<< "$HOSTS"
else
  HOST_ARR=("${DEFAULT_HOSTS[@]}")
fi

if [[ -z "$SSH_USER" ]]; then
  echo "error: set SSH_USER (e.g. operator on hub; Windows OpenSSH user on )" >&2
  exit 1
fi

pull_one() {
  local ip="$1" out="$2"
  local rel
  for rel in \
    '.local/state/alfa-monitoring-setup/latest.log' \
    '/var/log/alfa-monitoring-setup/latest.log' \
    '/c/ProgramData/AlfaMonitoring/setup-logs/latest-run.log'
  do
    if scp -o BatchMode=yes -o ConnectTimeout=12 \
      "${SSH_USER}@${ip}:${rel}" "$out" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

for ip in "${HOST_ARR[@]}"; do
  out="$DEST/$TS/${ip}-setup.log"
  echo "=== $SSH_USER@$ip -> $out ==="
  if pull_one "$ip" "$out"; then
    echo "ok: $ip"
  else
    echo "warn: could not fetch setup log from $ip (SSH, path, or script never ran)"
    echo "missing $(date -Iseconds)" >"$out.missing"
  fi
done

echo "Done. Logs under: $DEST/$TS"
