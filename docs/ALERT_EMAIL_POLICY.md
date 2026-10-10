# Alert email policy (temporary)

**Operator decision (2026-08-07):** host/service **down** detection for the cluster is
owned by the alfa-ai start/stop orchestrator on ``
(`Start-Stop-AlfaAi.ps1` / cluster preflight). Duplicate **email** pages for scrape-down,
ICMP, Windows worker down, public/LAN blackbox failures, etc. are disabled.

## What still emails

Only temperature warnings from `prometheus/rules/homelab_temperature_alerts.yml`:

| Alert | Severity |
|-------|----------|
| `GpuTemperatureHigh` | warning |
| `CpuTemperatureHigh` | warning |

Routed in `alertmanager/alertmanager.yml` to receiver `email-ops` (SMTP + alfa-ai webhook).

## What does not email (goes to the alfa-ai webhook instead)

**Changed 2026-09-25:** the default route receiver is `alfa-ai-webhook`
(`POST http://192.0.2.10:8420/alfa-ai/api/internal/alerts`, bearer from
`secrets/alfa_ai_webhook_token`). It used to be `null`, which meant down, backup,
and probe alerts reached nobody, and the alfa-ai brain (which owns host/service
down handling) only ever saw temperature alerts. Every `warning` / `critical`
alert that is not a temperature alert now goes **only** to that webhook (no email).
That includes (non-exhaustive):

- `TargetDown`, `WindowsWorkerDown`, `WindowsWorkerDownExtended`
- `BlackboxIcmpHostUnreachable`, `BlackboxProbeFailed`, `BlackboxProbeFailedPublic`
- `AlfaPostgresBackupStale` / `AlfaPostgresBackup*`
- `AlfaAiIncidentMetricsScrapeDown`, rankings/brain down rules, etc.

Alerts with `severity` `info` or `none` still go to the `null` sink (visible in the
Prometheus / Alertmanager UI only).

`Watchdog` still pulses healthchecks.io (not email).

To silence the webhook again for a noisy alert, add a route above the defaults that
sends it to `null` (e.g. `alertname = "WindowsWorkerDown"`), validate, and reload.

## Why

alfa-ai cluster start already reports unreachable hosts. Email down alerts were noisy
(FIRING/RESOLVED cycles when gaming PCs or the pool stop). Temperature remains the
only paging class for now.

## Restore broader email paging later

1. Edit `alertmanager/alertmanager.yml`: set root `receiver: email-ops` again (it
   already includes the alfa-ai webhook), or re-add severity routes.
2. Validate: `amtool check-config` (see header comment in that file).
3. Reload: `curl -fsS -X POST http://127.0.0.1:9093/-/reload`

## Official references

- Alertmanager routing tree / receivers:
  https://prometheus.io/docs/alerting/latest/configuration/
- Related: [TEMPERATURE_ALERTS.md](TEMPERATURE_ALERTS.md),
  [OPPORTUNISTIC_WINDOWS_HOST_DOWN.md](OPPORTUNISTIC_WINDOWS_HOST_DOWN.md)

Last updated: 2026-09-25
