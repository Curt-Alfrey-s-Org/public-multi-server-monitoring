# Alertmanager secrets (gitignored)

Everything in this directory except this README is gitignored. Alertmanager
reads these files **at notification time** (documented `*_file` options), so
the container starts even while they hold placeholders — delivery just fails
(logged in `docker logs monitoring-alertmanager`) until they are real.

| File | Contents (one line) | Used by |
|---|---|---|
| `smtp_password` | SMTP auth password for the account in `alertmanager.yml` `global.smtp_auth_username` | `smtp_auth_password_file` |
| `healthchecks_ping_url` | `https://hc-ping.com/<uuid>` of your healthchecks.io check (Period 5 min, Grace 5 min) | `webhook_configs.url_file` (Watchdog dead-man's-switch) |

Create them:

```bash
cd /home/operator/monitoring/secrets
printf '%s' 'THE-REAL-SMTP-PASSWORD'                > smtp_password
printf '%s' 'https://hc-ping.com/YOUR-CHECK-UUID'   > healthchecks_ping_url
# Alertmanager container runs as UID/GID 65534 (nobody). Either:
#   sudo chgrp 65534 smtp_password healthchecks_ping_url && chmod 640 … && chmod 750 .
# or (homelab fallback when chgrp unavailable):
chmod 644 smtp_password healthchecks_ping_url
```

Or sync from the ALFA SMTP app password used by WordPress mail:

```bash
grep '^ALFA_SMTP_APP_PASSWORD=' /home/operator/example-site-perch/.env | cut -d= -f2- > smtp_password
chgrp 65534 smtp_password && chmod 640 smtp_password
```

The non-secret SMTP settings (server:port, from, username, to) live in
`alertmanager/alertmanager.yml` (SMTP:
`smtp.example.com:587`, `operator@example.com`).
