# Host agents

Per-host exporter install scripts were removed from this public snapshot. Deploy
`node_exporter`, `cadvisor`, or other agents on your servers, then add each `host:port` to
`config/scrape-targets.example.yml` (see root README).
