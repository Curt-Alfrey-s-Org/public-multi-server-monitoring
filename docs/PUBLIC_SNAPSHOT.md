# Public snapshot

This tree is a **scrubbed snapshot** of the private monitoring repository. It is not a
continuation of private git history. Build artifacts and source SHA are recorded only on
the operator build host outside this export.

## Scrape targets file (`config/scrape-targets.example.yml`)

Prometheus loads remote scrape targets through **`file_sd_configs`**, not
`scrape_config_files`. The latter merges entire scrape job definitions; the targets file
must be a list of target groups in [file service discovery
format](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#file_sd_config).

Each document in the YAML list is one target group:

```yaml
- targets:
    - 192.0.2.10:9100
    - 192.0.2.20:9100
  labels:
    job: node-exporter
```

- **`targets`**: list of `host:port` strings. Use documentation addresses
  [RFC 5737](https://www.rfc-editor.org/rfc/rfc5737) `192.0.2.10` and `192.0.2.20` as
  examples for two servers, or your own LAN IPs after you copy the file.
- **`labels`**: optional static labels attached to every target in the group (for example
  `job`, `role`, or `environment`).

Copy the example to a live path mounted into the Prometheus container (see
`docker-compose.yml`, volume for `scrape-targets.yml`) and edit **`targets` only** when
you add a host.

Loopback self-scrape for Prometheus itself uses **`127.0.0.1:9090`** in
`prometheus/prometheus.yml`.

Official reference: [Prometheus configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/).

## Dropped from this snapshot

These files named this deployment's hosts and were not rewritten into the two-host example:

- fleet log-agent doc
- out-of-band temperature doc
- follow-ups doc whose filename embedded a live octet
- homelab infrastructure dashboard
- homelab temperature dashboard
- homelab launcher dashboard
- inference dashboard
- host series color script
- temperature dashboard patch script
