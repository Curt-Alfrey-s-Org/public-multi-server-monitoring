# Backup policy — `./data/`

Decided 2026-06-09 (NEXT_STEPS.md Phase 3). `./data/` is gitignored runtime
state; this documents what is backed up, what is deliberately not, and why.

## What IS backed up

| Path | Contents | How |
|---|---|---|
| `data/grafana/grafana.db` | UI-created dashboards, Grafana-managed alert rules, users, API keys/service accounts | `scripts/backup-data.sh` — online-safe copy via the SQLite Backup API (`sqlite3 ".backup"`), gzipped into `./backups/` (gitignored), `PRAGMA integrity_check` verified, 14-day retention |

Provisioned dashboards/datasources live in git (`grafana/dashboards/`,
`grafana/provisioning/`) and are the source of truth. The SQLite backup exists
because UI state (users, service accounts, any dashboard edited but not yet
re-exported to git) is real and was previously unprotected. **Still re-export
dashboards to git when you change them** — the DB backup is a safety net, not
the workflow.

## What is NOT backed up (documented acceptable loss)

| Path | Contents | Decision |
|---|---|---|
| `data/prometheus/` | 30d TSDB | **Disposable.** Metrics history is nice-to-have; on host loss the stack restarts with an empty TSDB and refills. Proper TSDB backups require the snapshot API (`--web.enable-admin-api` + `/api/v1/admin/tsdb/snapshot`) — admin API is deliberately not enabled on a LAN-exposed UI. Revisit only if metric history becomes a business requirement. |
| `data/loki/` | 30d log chunks + TSDB index | **Disposable.** Same trade-off; Loki has no simple single-binary snapshot story for filesystem storage (upstream guidance targets object storage replication). |
| `data/alertmanager/` | Silences, notification log | **Disposable.** Silences are short-lived operational state. |

## Running

```bash
sudo /home/operator/monitoring/scripts/backup-data.sh
```

Needs root because `data/grafana` is owned by UID 472 with owner-only modes
(see `scripts/setup-data-dirs.sh`). No cron is installed by the repo; the
header of `backup-data.sh` shows a crontab line when you want to schedule it,
and copying `./backups/` to the `` NFS hub is a manual/operator decision.

## Restore

```bash
cd /home/operator/monitoring
docker compose stop grafana
gunzip -c backups/grafana-<TS>.db.gz | sudo tee data/grafana/grafana.db >/dev/null
sudo chown 472:472 data/grafana/grafana.db
docker compose start grafana
```
