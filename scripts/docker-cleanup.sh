#!/usr/bin/env bash
# Docker disk cleanup (safe defaults: no `docker volume prune`).
# - Removes stopped containers, unused networks, dangling images (system prune)
# - Clears build cache (builder prune)
# - Removes images not referenced by any container (image prune -af) — frees the
#   bulk of "RECLAIMABLE" space from `docker system df`; next run pulls again if needed.

set -euo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LOG=${LOG:-/var/log/docker-cleanup.log}

{
  echo "===== $(date -Is) docker-cleanup start ====="
  docker system prune -f
  docker builder prune -f
  docker image prune -af
  echo "--- $(date -Is) docker system df ---"
  docker system df
  echo
} >>"${LOG}" 2>&1
