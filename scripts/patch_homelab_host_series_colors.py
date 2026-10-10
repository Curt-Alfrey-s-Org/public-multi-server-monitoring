#!/usr/bin/env python3
"""Pin stable per-host line colors on Homelab Grafana timeseries panels."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from homelab_host_series_colors import (
    COLOR_MODE_BY_SERIES_NAME,
    host_color_overrides,
    legend_looks_like_host_series,
)

REPO = Path(__file__).resolve().parents[1]
DASHBOARDS = (
    REPO / "grafana" / "dashboards" / "homelab_temperatures.json",
    REPO / "grafana" / "dashboards" / "homelab_infrastructure.json",
)


def patch_panel(panel: dict) -> bool:
    if panel.get("type") != "timeseries":
        return False
    fc = panel.setdefault("fieldConfig", {})
    defaults = fc.setdefault("defaults", {})
    defaults["color"] = dict(COLOR_MODE_BY_SERIES_NAME)
    if legend_looks_like_host_series(panel):
        fc["overrides"] = host_color_overrides()
    return True


def patch_dashboard(path: Path) -> int:
    with path.open(encoding="utf-8") as handle:
        dash = json.load(handle)
    changed = 0
    for panel in dash.get("panels") or []:
        if patch_panel(panel):
            changed += 1
    dash["version"] = int(dash.get("version") or 0) + 1
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(dash, handle, indent=2)
        handle.write("\n")
    return changed


def main() -> int:
    total = 0
    for path in DASHBOARDS:
        if not path.is_file():
            print(f"missing: {path}", file=sys.stderr)
            return 1
        n = patch_dashboard(path)
        print(f"{path.name}: patched {n} timeseries panels, version bumped")
        total += n
    return 0 if total else 1


if __name__ == "__main__":
    raise SystemExit(main())
