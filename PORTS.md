# Port reference (homelab / web-sites host)

Default LAN host in this repo: **`192.0.2.10`**. Replace with your IP where needed.

**Compose stacks and which containers belong to each:** see **[SERVER_STACKS.md](./SERVER_STACKS.md)**.

For **live** published ports on a machine:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

---

## Central monitoring stack (`docker-compose.yml` in this repo)

| Service | Host port | Container port | URL / notes |
|---------|-----------|----------------|-------------|
| Grafana | **3000** | 3000 | `http://192.0.2.10:3000` |
| Prometheus | **9092** | 9090 | `http://192.0.2.10:9092` (UI; internal scrape target is `:9090`) |
| Alertmanager | **9093** | 9093 | `http://192.0.2.10:9093` |
| Loki | **3100** | 3100 | HTTP API; **`/ready`** for health |
| Loki (gRPC) | *(not published)* | **9096** | Internal (`common` config); not mapped to host by default |
| Grafana Alloy UI | **12345** | 12345 | `http://192.0.2.10:12345` |
| cAdvisor | **8081** | 8080 | `http://192.0.2.10:8081` |
| blackbox exporter | **9115** | 9115 | `http://192.0.2.10:9115` |

### Grafana (port **3000**) — UI, dashboards, datasources

All of this is the **same host port** as Grafana above; no extra ports for “the dashboard” vs “Grafana”.

| What | URL / path | Notes |
|------|------------|--------|
| Grafana web UI | `http://192.0.2.10:3000` | Login; datasources **Prometheus** (`uid: prometheus`) and **Loki** (`uid: loki`) are provisioned |
| Default home (after login) | *Homelab app launcher* | Set via `GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH` in `docker-compose.yml` |
| Dashboards folder | **Dashboards → Homelab** | File provisioning: `grafana/provisioning/dashboards/dashboards.yml` → `grafana/dashboards/*.json` |
| Explore (metrics / logs) | **Explore** in left nav | Same **3000**; pick datasource **Prometheus** or **Loki** |
| Drilldown (Grafana 12) | **Drilldown** in left nav | Optional entry point for metrics/logs/traces apps |

**Homelab dashboards** (UIDs stable in JSON — open as `http://192.0.2.10:3000/d/<uid>`):

| UID | Title |
|-----|--------|
| `homelab-launcher` | Homelab app launcher |
| `homelab-infrastructure` | Homelab infrastructure overview |
| `homelab-prom-deep` | Prometheus deep health (targets & scrapes) |

**Other provisioned JSON** (no `uid` in file — Grafana assigns one on first load; still under folder **Homelab**):

- Alfa Accuracy & Performance - Staging (`alfa_accuracy.json`)
- Alfa System Health - Staging (`alfa_health.json`)
- Alfa System Overview - Staging (`alfa_overview.json`)
- Alfa Rating System Rollout Metrics (`alfa-rollout-metrics` in file `rollout_metrics.json`)
- Rankings Bot - API Performance (`rankings_bot_api.json`)
- Rankings Bot - System Overview (`rankings_bot_overview.json`)

**Related UIs (other ports):**

| App | Port | URL |
|-----|------|-----|
| Prometheus UI | **9092** | `http://192.0.2.10:9092` — **Status → Targets**, **Graph**, **Alerts** |
| Alertmanager UI | **9093** | `http://192.0.2.10:9093` |
| Alloy UI | **12345** | `http://192.0.2.10:12345` |
| cAdvisor | **8081** | `http://192.0.2.10:8081` |

**Per-host DB exporters (`` -- LAN scrape from ``):

| Host port | Exporter | Prometheus job |
|-----------|----------|----------------|
| **9187** | rankings Postgres | `postgres` |
| **9121** | rankings Redis | `redis` |
| **9188** | legacy alfa-postgres | `postgres-alfa` |
| **9104** | alfaqd MySQL | `mysqld-alfa` |

Compose: `hosts/192.0.2.10/docker-compose.*-exporters.yml`. UFW: allow **192.0.2.10**.

**App `/metrics` on `` (LAN):

| Host port | Service | Prometheus job |
|-----------|---------|----------------|
| **8002** | contracts-bot-api | `contracts-bot-api` |
| **8003** | rankings-bot-api | `rankings-bot-api` |

---

## Host / systemd (same machine, outside this compose)

Documented in `prometheus.yml` comments:

| What | Port | Notes |
|------|------|--------|
| node_exporter (systemd) | **9100** | Scraped as `host.docker.internal:9100` from Prometheus container |
| Host Prometheus (systemd, if any) | **9090** | Intentionally **not** used by the monitoring container (stack uses **9092** on host) |

---

## Blackbox & launcher-related host ports

Prometheus blackbox **homelab-ui** probes (edit in `prometheus/prometheus.yml` if yours differ):

| Target | Host port | Notes |
|--------|-----------|--------|
| Dockge | **5001** | Also default in Grafana launcher variable `dockge_port`; alfa Dockge compose default is **5002** → map to your real publish |
| Dozzle (central UI) | **8888** | Fleet log viewer on `` (central UI); Grafana launcher `dozzle_port` |
| Dozzle agent | **7007** | One per Docker host; allow inbound from `` central UI |

**LAN health checks** (blackbox job `blackbox-http-lan`):

| URL path | Typical host port | Service |
|----------|-------------------|---------|
| `/health` | **8420** | Alfa operator console / API (see alfa-ai compose) |
| `/api/health/ready` | **8011** | RV Auto Finder API |
| `/health/liveliness` | **8413** | Alfa LiteLLM (host maps to container `4000`) |

---

## Alfa AI (`/home/operator/alfa-ai/deploy/docker-compose.yml`)

Defaults are env-overridable; **host → container** below.

| Service | Default host bind | Container port |
|---------|-------------------|----------------|
| alfa-ai-api | **127.0.0.1:8412** | 8000 |
| Operator console (LAN) | **8420** (all interfaces unless you change compose) | 8000 |
| alfa-ai-postgres | **127.0.0.1:5540** | 5432 |
| alfa-ai-redis | **127.0.0.1:6390** | 6379 |
| alfa-ai-litellm | **8413** | 4000 |
| alfa-ai-nginx | **127.0.0.1:8090** | 80 |

See also: `alfa-ai/docs/PORT_ASSIGNMENTS.md`, `rankings-bot/docs/PORT_MANAGEMENT.md` (cross-links).

---

## RV Auto Finder (`/home/operator/rv-auto-finder/docker-compose.yml`)

| Service | Host bind | Container port |
|---------|-----------|----------------|
| Postgres | **127.0.0.1:5437** | 5432 |
| Redis | **127.0.0.1:6380** | 6379 |
| API | **8011** | 8011 |

---

## Rankings Bot & multi-bot (canonical: `rankings-bot/docs/PORT_MANAGEMENT.md`)

Summary of **common host publishes** (production may omit API publish; tunnel → nginx → container):

| Service | Host bind | Container port |
|---------|-----------|----------------|
| Rankings Bot API | **127.0.0.1:8003** | 8003 |
| Market Bot API | **127.0.0.1:8004** | 8000 |
| Contracts Bot API | **127.0.0.1:8002** | 8000 |
| Credit Check Bot API | **127.0.0.1:8005** | 8000 |
| ATEMS API | **127.0.0.1:5000** | 5000 |
| Rankings nginx (optional LAN) | **8088** → nginx 80 | see `nginx-config/docker-compose.nginx.yml` |

---

## Dockge (template: `alfa-ai/deploy/petals/docker-compose.dockge.yml`)

| Service | Host port | Container port |
|---------|-----------|----------------|
| Dockge | **`${DOCKGE_HOST_PORT:-5002}`** | 5001 |

On **192.0.2.10** your running container may use **5001** (see Grafana launcher / blackbox config).

---

## Remote / other

| Target | Port | Notes |
|--------|------|--------|
| hub `node_exporter` | **9100** on `192.0.2.10` | Job `node-remote` in `prometheus.yml` |
| hub DCGM GPU exporter (optional) | **9400** on `192.0.2.10` | Job `nvidia-dcgm-remote`; `./setup-host-metrics.sh --with-gpu` |
| Windows workers (Petals hosts) | **9182** on ``, ``, ``, `` | Job `windows-exporter-remote`; allow **192.0.2.10** inbound |
| Linux Petals worker ai-148 | **9100** on `192.0.2.10` | Job `node-remote`; deploy via `hosts/192.0.2.10/setup-linux-metrics.sh` |
| Linux inference shard gpu-248 | **9100** / **9400** on `192.0.2.10` (Wi-Fi static; USB Ethernet unplugged 2026-09-14) | Jobs `node-remote` + `nvidia-dcgm-remote` |

---

## Quick internal-only ports (Docker DNS, not on host)

Examples Prometheus uses inside networks:

- `rankings-bot-api:8003` (metrics `/metrics` if enabled)
- `grafana:3000`, `prometheus:9090`, `loki:3100`, `alertmanager:9093`, `cadvisor:8080`, `blackbox:9115`, `alloy:12345`

Use **`docker network inspect <name>`** if you need which stack attaches to which network.
