# Docker stacks on this server (inventory)

This file describes **Compose projects (“stacks”)** and the **containers** normally found in each, plus commands to **regenerate a live list** on the machine.

**Host:** typically **`192.0.2.10`** (web-sites). Paths below are under **`/home/operator`** unless noted.

---

## Refresh live state (always up to date)

```bash
# All Compose projects Docker knows about
docker compose ls -a

# Every running container with its Compose project (blank = not from Compose, or no label)
docker ps --format 'table {{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Status}}\t{{.Image}}'

# Same, sorted by stack name
docker ps -a --format '{{.Label "com.docker.compose.project"}}\t{{.Names}}\t{{.Status}}' | sed 's/^\t/(no-compose-project)\t/' | sort
```

**Containers without a Compose project** often include: **Cloudflare tunnels** (`cf-*`), **Buildx** builders, one-off runs, or stacks started outside `docker compose`.

---

## Stacks (from `docker compose ls` on this host)

| Compose project | Config file(s) | Role |
|-----------------|----------------|------|
| **monitoring** | `/home/operator/monitoring/docker-compose.yml` | Central Prometheus, Grafana, Loki, Alloy, Alertmanager, blackbox, cAdvisor, DB exporters |
| **deploy** | `/home/operator/alfa-ai/deploy/docker-compose.yml` | Alfa AI API, LiteLLM, Postgres, Redis, nginx, Petals gateway |
| **petals** | `/home/operator/alfa-ai/deploy/petals/docker-compose.worker.yml` (+ overrides) | Petals GPU worker + small sidecar containers |
| **rv-auto-finder** | `/home/operator/rv-auto-finder/docker-compose.yml` | RV API, Postgres, Redis, Celery, frontend |
| **uspbf** | `/home/operator/USPBF/docker-compose.yml` | USPBF WordPress stack (DB, nginx, WP) |
| **alfaqd-website** | `/home/operator/alfaqd-website/docker-compose.yml` | Alfa QD marketing site (WordPress, MySQL, nginx) |
| **dockge-105** | `/opt/dockge/compose.yaml` | Dockge UI on this node (path may differ if you symlink stacks) |

---

## Containers per stack (expected members)

### `monitoring`

| Container name |
|----------------|
| `monitoring-prometheus` |
| `monitoring-grafana` |
| `monitoring-alertmanager` |
| `monitoring-loki` |
| `monitoring-alloy` |
| `monitoring-blackbox` |
| `monitoring-cadvisor` |
| `monitoring-postgres-exporter-rankings` |
| `monitoring-redis-exporter-rankings` |
| `monitoring-postgres-exporter-rv` |
| `monitoring-postgres-exporter-alfa` |
| *(optional, profile `mysql`)* `monitoring-mysqld-exporter-alfa`, `monitoring-mysqld-exporter-uspbf` |

### `deploy` (alfa-ai)

| Container name |
|----------------|
| `alfa-ai-api` |
| `alfa-ai-litellm` |
| `alfa-ai-postgres` |
| `alfa-ai-redis` |
| `alfa-ai-nginx` |
| `alfa-ai-petals-gateway` |
| `alfa-ai-worker` *(if worker service is enabled in the same project on your host)* |

*Note:* On some hosts the **worker** is only in the **petals** project; `docker compose ls` is authoritative.

### `petals`

| Container name |
|----------------|
| `petals-worker` |
| `worker-monitor` |
| `worker-heartbeat` |

### `rv-auto-finder`

| Container name |
|----------------|
| `rv-auto-finder-api` |
| `rv-auto-finder-postgres` |
| `rv-auto-finder-redis` |
| `rv-auto-finder-celery-worker` |
| `rv-auto-finder-celery-beat` |
| `rv-auto-finder-frontend` |

### `uspbf`

| Container name |
|----------------|
| `uspbf_wordpress_1` |
| `uspbf_db_1` |
| `uspbf-nginx` |

### `alfaqd-website`

| Container name |
|----------------|
| `alfa_wordpress_1` |
| `alfa_db_1` |
| `alfa-nginx` |

### `dockge-105`

| Container name |
|----------------|
| `dockge-105` *(name may match project)* |

---

## Not in `docker compose ls` but often on this host

| Name | Typical role |
|------|----------------|
| `cf-probilliards`, `cf-uspbf`, `cf-alfa` | **Cloudflare tunnels** (not always started via Compose from this list) |
| `buildx_buildkit_*` | **Docker Buildx** builder |
| `epic_tu` | **Ad-hoc / test** container (verify before removing) |
| **`probilliards-nginx`** | Started from **`rankings-bot/nginx-config/docker-compose.nginx.yml`** — may show under a **different** Compose project name depending on **`-p`** / directory when you ran `up` |
| **`rankings-bot-api`**, **`rankings-bot-postgres`**, etc. | **Rankings Bot production** — `docker compose -f production/docker-compose.prod.yml` from **`rankings-bot`** repo; project name defaults to **directory** (e.g. `production` or `rankings-bot`) unless `name:` is set |

To see the Rankings stack if present:

```bash
docker ps -a --filter 'name=rankings-bot' --format 'table {{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Status}}'
```

---

## Related docs

| Topic | File |
|--------|------|
| Host ports & UIs | [PORTS.md](./PORTS.md) |
| Rankings ports / nginx | `rankings-bot/docs/PORT_MANAGEMENT.md` |

---

## Snapshot (example — **do not treat as current**)

Captured from one `docker compose ls` / `docker ps` run; **always use the commands in the first section** before changing firewall or DNS.

See git history of this file if you want to store occasional snapshots; otherwise keep this file **timeless** and use live commands.
