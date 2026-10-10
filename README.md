# Multi-server monitoring (public snapshot)

Docker Compose stack: Prometheus, Grafana, Alertmanager, blackbox, Loki, and optional
exporters. This repository is a scrubbed snapshot; see `docs/PUBLIC_SNAPSHOT.md`.

## Configure before you run

1. Copy `config/hosts.example.env` to `config/hosts.env` and set your host roles (do not commit `hosts.env`).
2. Copy `.env.example` to `.env` and set **`GRAFANA_ADMIN_PASSWORD=change-me`** (change before exposing port 3000).
3. Copy `config/scrape-targets.example.yml` to the path mounted as `/etc/prometheus/scrape-targets.yml` in `docker-compose.yml` (or edit the example in place for a lab).

## Adding a host

Add one `<host>:<port>` entry under **`targets`** in the file referenced by **`file_sd_configs`**
in `prometheus/prometheus.yml` (default: `config/scrape-targets.example.yml`). That edit is the
only inventory change required for a new scrape target.

## Run

```bash
docker compose up -d
```

Change the Grafana admin password before exposing the UI to any untrusted network.

See `docs/PUBLIC_SNAPSHOT.md`, `SERVER_STACKS.md`, and `PORTS.md` for stack layout.

