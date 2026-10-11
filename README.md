# Multi-server monitoring (public snapshot)

Docker Compose stack. Services in `docker-compose.yml`:

| Service | Host port |
|---------|-----------|
| Prometheus | 9092 |
| Grafana | 3000 |
| Alertmanager | 9093 |
| Blackbox exporter | 9115 |
| Loki | 3100 |
| Alloy | 12345 |
| cAdvisor | 8081 |
| IPMI exporter | 9290 |
| Dozzle | 8888 |
| Node exporter | none (compose network only) |

Scrubbed snapshot: see `docs/PUBLIC_SNAPSHOT.md`.

## Configure before you run

1. Copy `config/hosts.example.env` to `config/hosts.env`. Do not commit `hosts.env`.
2. Copy `.env.example` to `.env`. Set a Grafana admin password before anyone else can open port 3000. Do not commit `.env`.
3. Copy `config/scrape-targets.example.yml` to the host file that compose mounts at `/etc/prometheus/scrape-targets.yml`.

## Add a host

Prometheus reads targets from `file_sd_configs` in `prometheus/prometheus.yml` (mounted file `/etc/prometheus/scrape-targets.yml`). Add one `host:port` entry under `targets`. That file is the whole inventory change.

## Run

```bash
docker compose up -d
```

Change the Grafana admin password before exposing the UI.
