#!/usr/bin/env bash
# backup-data.sh — back up the stateful parts of ./data/ that are NOT
# reproducible from git. See docs/BACKUP.md for the policy and what is
# intentionally excluded (Prometheus TSDB, Loki chunks, Alertmanager silences).
#
# What it does:
#   * Grafana SQLite (data/grafana/grafana.db): online-safe copy via
#     `sqlite3 ".backup"` (SQLite Backup API — consistent even while Grafana
#     is running; plain `cp` of a live SQLite DB can produce a torn copy).
#   * Nothing else under data/grafana is archived: plugins are reinstalled and
#     dashboards/datasources are provisioned from git (docs/BACKUP.md).
#   * Prunes backups older than $RETENTION_DAYS (default 14).
#
# Usage:   sudo ./scripts/backup-data.sh
# Env:     BACKUP_DIR        (default <repo>/backups — gitignored)
#          RETENTION_DAYS    (default 14)
#
# No cron is installed by this repo; schedule it yourself when ready, e.g.:
#   sudo crontab -e
#   15 3 * * * /home/operator/monitoring/scripts/backup-data.sh >> /var/log/monitoring-backup.log 2>&1
# Copying the resulting files to the  NFS hub is the operator's call.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-${REPO_DIR}/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
GRAFANA_DB="${REPO_DIR}/data/grafana/grafana.db"
TS="$(date +%Y%m%d-%H%M%S)"

# Preflight
command -v sqlite3 >/dev/null || { echo "ERROR: sqlite3 not installed (apt install sqlite3)" >&2; exit 1; }
[[ -f "$GRAFANA_DB" ]] || { echo "ERROR: $GRAFANA_DB not found — has the stack ever run?" >&2; exit 1; }
[[ -r "$GRAFANA_DB" ]] || { echo "ERROR: cannot read $GRAFANA_DB — run with sudo (dir is owned by UID 472)" >&2; exit 1; }

mkdir -p "$BACKUP_DIR"

# 1) Grafana SQLite — consistent online copy via the SQLite Backup API.
out_db="${BACKUP_DIR}/grafana-${TS}.db"
sqlite3 "$GRAFANA_DB" ".backup '${out_db}'"
sqlite3 "$out_db" "PRAGMA integrity_check;" | grep -qx "ok" \
  || { echo "ERROR: integrity_check failed on ${out_db}" >&2; exit 1; }
gzip "$out_db"
echo "OK: ${out_db}.gz"

# 2) Alertmanager nflog/silences and Prometheus/Loki data are intentionally
#    NOT backed up — documented as acceptable loss in docs/BACKUP.md.

# 3) Prune old backups.
find "$BACKUP_DIR" -name 'grafana-*.db.gz' -mtime "+${RETENTION_DAYS}" -print -delete

echo "Done. Backups in ${BACKUP_DIR}:"
ls -lh "$BACKUP_DIR" | tail -n +2
