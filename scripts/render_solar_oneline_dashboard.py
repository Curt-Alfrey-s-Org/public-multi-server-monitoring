"""Write grafana/dashboards/solar_plant_oneline.json.

Canvas element JSON matches Grafana v13.0.2
public/app/features/canvas/element.ts and metricValue.tsx
(config.text mode/field/fixed, connection path straight, direction mode/field/fixed).
Queries are Prometheus selectors only. No watt math.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "grafana" / "dashboards" / "solar_plant_oneline.json"

CLAMP = "#14352c"
EST = "#3d3214"
SITE = "#1a2740"
GOLD = "#1e2a3a"


def wire(target: str, *, mode: str, field: str = "", color: str = "#3dd68c", down: bool = False) -> dict:
    direction: dict = {"mode": mode, "fixed": "forward"}
    if field:
        direction["field"] = field
    if down:
        source = {"x": 0, "y": -1}
        dest = {"x": 0, "y": 1}
    else:
        source = {"x": 1, "y": 0}
        dest = {"x": -1, "y": 0}
    return {
        "source": source,
        "target": dest,
        "targetName": target,
        "path": "straight",
        "color": {"fixed": color},
        "size": {"mode": "fixed", "fixed": 3, "min": 1, "max": 10},
        "direction": direction,
    }


def metric(name: str, field: str, left: int, top: int, fill: str, connections: list | None = None) -> list:
    caption = label(f"{name} label", name, left, top, 150)
    caption["config"]["align"] = "center"
    caption["config"]["size"] = 12
    caption["placement"]["height"] = 18
    value = {
        "name": name,
        "type": "metric-value",
        "config": {
            "align": "center",
            "valign": "middle",
            "color": {"fixed": "#e7eef5"},
            "text": {"mode": "field", "fixed": "", "field": field},
            "size": 16,
        },
        "background": {"color": {"fixed": fill}},
        "border": {"color": {"fixed": "#31414e"}, "width": 1},
        "placement": {"left": left, "top": top + 18, "width": 150, "height": 44, "rotation": 0},
        "constraint": {"vertical": "top", "horizontal": "left"},
        "connections": connections or [],
    }
    return [caption, value]


def label(name: str, text: str, left: int, top: int, width: int = 420) -> dict:
    return {
        "name": name,
        "type": "text",
        "config": {
            "align": "left",
            "valign": "middle",
            "color": {"fixed": "#c5d0dc"},
            "text": {"mode": "fixed", "fixed": text, "field": ""},
            "size": 14,
        },
        "background": {"color": {"fixed": "transparent"}},
        "border": {"width": 0},
        "placement": {"left": left, "top": top, "width": width, "height": 28, "rotation": 0},
        "constraint": {"vertical": "top", "horizontal": "left"},
        "connections": [],
    }


def elements() -> list:
    green = "#3dd68c"
    amber = "#e0b050"
    blue = "#7eb6ff"
    pieces = [
        label("lane-t2", "T2 bus — device clamps (panels 1+2 are half-string estimates)", 16, 8, 640),
        metric("P1", "P1", 16, 40, EST, [wire("T2 MPPT", mode="fixed", color=amber)]),
        metric("P2", "P2", 180, 40, EST, [wire("T2 MPPT", mode="fixed", color=amber)]),
        metric(
            "T2 MPPT",
            "t2_mppt_w",
            360,
            40,
            CLAMP,
            [wire("Batt 1", mode="fixed", color=green)],
        ),
        metric("T2 charge", "t2_mppt_charge_w", 360, 112, CLAMP),
        metric(
            "Batt 1",
            "battery_1_w",
            560,
            40,
            CLAMP,
            [
                wire("Batt 2", mode="field", field="t2_ku_jumper_w", color=blue, down=True),
                wire("T2 shunt sign", mode="field", field="battery_1_w", color=green),
            ],
        ),
        metric("Jumper", "t2_ku_jumper_w", 560, 112, SITE),
        label("T2 shunt sign", "+ charge into T2 pack", 760, 48, 240),
        label("lane-ku", "KU bus — MPPT 2/3 and PWM are estimates, not clamps", 16, 200, 520),
        metric("P3", "P3", 16, 236, EST, [wire("KU MPPT 2+3 est", mode="fixed", color=amber)]),
        metric("P4", "P4", 180, 236, EST, [wire("KU MPPT 2+3 est", mode="fixed", color=amber)]),
        metric("P5", "P5", 16, 308, EST, [wire("KU MPPT 2+3 est", mode="fixed", color=amber)]),
        metric("P6", "P6", 180, 308, EST, [wire("KU MPPT 2+3 est", mode="fixed", color=amber)]),
        metric(
            "KU MPPT 2+3 est",
            "ku_victron_mppt23_est_w",
            360,
            260,
            EST,
            [wire("Batt 2", mode="fixed", color=amber)],
        ),
        metric("P7", "P7", 16, 392, EST, [wire("KU PWM est", mode="fixed", color=amber)]),
        metric("P8", "P8", 180, 392, EST, [wire("KU PWM est", mode="fixed", color=amber)]),
        metric(
            "KU PWM est",
            "ku_pwm_est_w",
            360,
            392,
            EST,
            [wire("Batt 2", mode="fixed", color=amber)],
        ),
        metric(
            "Batt 2",
            "battery_2_w",
            560,
            300,
            CLAMP,
            [
                wire("Trailer AC", mode="fixed", color=green),
                wire("KU shunt sign", mode="field", field="battery_2_w", color=green),
            ],
        ),
        label("KU shunt sign", "+ charge into KU pack", 760, 300, 240),
        metric("KU equal share", "ku_charger_equal_share_w", 360, 470, EST),
        metric("KU combined est", "ku_pwm_mppt_combined_est_w", 560, 470, EST),
        metric(
            "Trailer AC",
            "trailer_outlet_w",
            760,
            392,
            CLAMP,
            [wire("EM16 A3", mode="fixed", color=green)],
        ),
        metric(
            "EM16 A3",
            "em16_a3_live_w",
            940,
            320,
            CLAMP,
            [wire("Sungold AC in", mode="fixed", color=green)],
        ),
        metric(
            "EM16 B3",
            "em16_b3_live_w",
            940,
            392,
            CLAMP,
            [wire("Sungold AC in", mode="fixed", color=green)],
        ),
        label("lane-sg", "Sungold cart — not on the T2/KU DC bus", 940, 16, 460),
        metric(
            "Sungold PV",
            "sungold_pv_w",
            940,
            48,
            GOLD,
            [wire("Sungold batt in", mode="fixed", color=green)],
        ),
        metric("Sungold batt in", "sungold_batt_in_w", 1120, 48, GOLD),
        metric(
            "Sungold AC in",
            "sungold_ac_in_w",
            1120,
            250,
            GOLD,
            [wire("Sungold AC out", mode="fixed", color=green)],
        ),
        metric("Sungold AC out", "sungold_ac_out_w", 1300, 250, CLAMP),
        metric("Cart to AC out", "sungold_cart_to_load_w", 1300, 330, EST),
        label("lane-site", "Site totals — computed in Node-RED, not extra clamps", 16, 560, 520),
        metric("Site solar", "site_solar_w", 16, 596, SITE),
        metric("Site source", "site_source_w", 180, 596, SITE),
        metric("Site load", "site_total_load_w", 344, 596, SITE),
        metric("Unaccounted", "load_unaccounted_w", 508, 596, SITE),
    ]
    flat: list = []
    for piece in pieces:
        if isinstance(piece, list):
            flat.extend(piece)
        else:
            flat.append(piece)
    return flat


def dashboard() -> dict:
    return {
        "annotations": {"list": []},
        "editable": True,
        "fiscalYearStartMonth": 0,
        "graphTooltip": 0,
        "links": [
            {
                "title": "HA Energy",
                "type": "link",
                "url": "http://192.0.2.10:8123/energy",
                "targetBlank": True,
            },
            {
                "title": "HA Site solar",
                "type": "link",
                "url": "http://192.0.2.10:8123/site-solar",
                "targetBlank": True,
            },
            {
                "title": "Node-RED computed",
                "type": "link",
                "url": "http://192.0.2.10:1880/solar/computed",
                "targetBlank": True,
            },
        ],
        "panels": [
            {
                "id": 1,
                "type": "text",
                "title": "",
                "gridPos": {"h": 4, "w": 24, "x": 0, "y": 0},
                "options": {
                    "mode": "markdown",
                    "content": (
                        "## Solar plant one-line\n\n"
                        "Numbers are the Node-RED cache (`solarComputedLast`), scraped as "
                        "`solar_plant_watts` / `solar_plant_panel_watts`. "
                        "Green cards are device clamps. Amber cards are estimates "
                        "(KU MPPT 2/3, PWM, panel halves, equal share).\n\n"
                        "Arrow direction follows the sign of the bound series when the wire says so "
                        "(jumper, shunt): positive = forward, negative = reverse, zero = no arrow. "
                        "Other wires are fixed forward. "
                        "Grafana Canvas does not document particle animation, so there is none.\n\n"
                        "H5082 sockets are `solar_plant_socket` (on=1, off=0). "
                        "**Dump sockets** are Use=dump. **Manual sockets** are Use=normal. "
                        "Where and Load are the text from Site solar. "
                        "This table does not calculate watts.\n"
                    ),
                },
                "transparent": True,
            },
            {
                "id": 2,
                "type": "canvas",
                "title": "Plant",
                "gridPos": {"h": 36, "w": 24, "x": 0, "y": 4},
                "datasource": {"type": "prometheus", "uid": "prometheus"},
                "targets": [
                    {
                        "datasource": {"type": "prometheus", "uid": "prometheus"},
                        "expr": "solar_plant_watts",
                        "legendFormat": "{{series}}",
                        "refId": "A",
                    },
                    {
                        "datasource": {"type": "prometheus", "uid": "prometheus"},
                        "expr": "solar_plant_panel_watts",
                        "legendFormat": "{{panel}}",
                        "refId": "B",
                    },
                ],
                "fieldConfig": {
                    "defaults": {"unit": "watt", "decimals": 1, "custom": {}},
                    "overrides": [],
                },
                "options": {
                    "inlineEditing": False,
                    "showAdvancedTypes": False,
                    "panZoom": True,
                    "infinitePan": False,
                    "root": {
                        "type": "frame",
                        "name": "Frame",
                        "background": {"color": {"fixed": "#0f1419"}},
                        "elements": elements(),
                    },
                },
            },
            socket_table(3, "Dump sockets", "dump", 0),
            socket_table(4, "Manual sockets", "normal", 12),
        ],
        "refresh": "10s",
        "schemaVersion": 39,
        "tags": ["solar", "victron"],
        "time": {"from": "now-15m", "to": "now"},
        "timepicker": {},
        "timezone": "browser",
        "title": "Solar plant one-line",
        "uid": "solar-plant-oneline",
        "version": 1,
    }


def socket_table(pid: int, title: str, use: str, x: int) -> dict:
    """H5082 socket table (solar_plant_socket, 1 = on, 0 = off). Labels, not watts."""
    ds = {"type": "prometheus", "uid": "prometheus"}
    return {
        "id": pid,
        "type": "table",
        "title": title,
        "gridPos": {"h": 12, "w": 12, "x": x, "y": 40},
        "datasource": dict(ds),
        "targets": [
            {
                "datasource": dict(ds),
                "editorMode": "code",
                "expr": f'solar_plant_socket{{use="{use}"}}',
                "format": "table",
                "instant": True,
                "legendFormat": "",
                "refId": "A",
            }
        ],
        "transformations": [
            {
                "id": "organize",
                "options": {
                    "excludeByName": {"Time": True, "__name__": True, "job": True, "instance": True},
                    "indexByName": {"plug": 0, "side": 1, "location": 2, "load": 3, "use": 4, "Value": 5},
                    "renameByName": {
                        "plug": "Plug",
                        "side": "Side",
                        "location": "Where",
                        "load": "Load",
                        "use": "Use",
                        "Value": "Power",
                    },
                },
            }
        ],
        "fieldConfig": {
            "defaults": {"custom": {"align": "auto", "filterable": True}},
            "overrides": [
                {
                    "matcher": {"id": "byName", "options": "Power"},
                    "properties": [
                        {
                            "id": "mappings",
                            "value": [
                                {
                                    "type": "value",
                                    "options": {
                                        "0": {"text": "off", "color": "red"},
                                        "1": {"text": "on", "color": "green"},
                                    },
                                }
                            ],
                        }
                    ],
                }
            ],
        },
        "options": {"showHeader": True, "cellHeight": "sm", "footer": {"show": False}},
    }


def main() -> None:
    OUT.write_text(json.dumps(dashboard(), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(OUT)


if __name__ == "__main__":
    main()
