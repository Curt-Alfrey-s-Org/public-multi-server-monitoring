# Windows — shared installer

- **`setup-lib.ps1`** — logging (`ProgramData\AlfaMonitoring\setup-logs\`), verification helpers, optional `ALFA_MONITORING_LOG_PUSH_DEST` scp push.
- **`install-windows-exporter.ps1`** — verifies admin, MSI size, `msiexec` exit, **service Running**, **`/metrics`** content; writes **`latest-run.log`** for pull from ``.

Per-machine wrappers: `hosts/192.0.2.10/install-metrics.ps1` (and ``, ``, ``).

Run **elevated PowerShell** from the host folder.
