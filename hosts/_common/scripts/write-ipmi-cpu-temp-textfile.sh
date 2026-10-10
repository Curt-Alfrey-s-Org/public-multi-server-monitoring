#!/usr/bin/env bash
# Write BMC CPU temperature for node_exporter textfile collector.
# Official ipmitool: https://github.com/ipmitool/ipmitool/blob/master/doc/ipmitool.1.in
# Textfile collector: https://github.com/
set -euo pipefail

OUT_DIR="${ALFA_IPMI_TEXTFILE_DIR:-/var/lib/alfa-monitoring/textfile}"
SENSOR="${ALFA_IPMI_CPU_SENSOR:-TEMP_CPU}"
TMP="${OUT_DIR}/ipmi_cpu_temp.prom.$$"
OUT="${OUT_DIR}/ipmi_cpu_temp.prom"

if ! command -v ipmitool >/dev/null 2>&1; then
  echo "write-ipmi-cpu-temp-textfile: ipmitool not found" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
# Local BMC via /dev/ipmi0 (no LAN credentials required on-host).
# Prefer "sensor reading" (numeric only); fall back to "sensor get" parse.
temp="$(ipmitool sensor reading "${SENSOR}" 2>/dev/null | awk -F'|' '{gsub(/ /, "", $2); print $2; exit}')"
if [[ -z "${temp}" ]] || [[ ! "${temp}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  raw="$(ipmitool sensor get "${SENSOR}" 2>/dev/null || true)"
  temp="$(printf '%s\n' "$raw" | awk -F: '/Sensor Reading/ { gsub(/[^0-9.+-]/, "", $2); print $2; exit }')"
fi
if [[ -z "${temp}" ]]; then
  echo "write-ipmi-cpu-temp-textfile: could not read ${SENSOR}" >&2
  exit 1
fi

cat > "${TMP}" <<EOF
# HELP ipmi_temperature_celsius IPMI threshold sensor temperature in degrees Celsius (BMC).
# TYPE ipmi_temperature_celsius gauge
ipmi_temperature_celsius{name="${SENSOR}",source="ipmi"} ${temp}
EOF
mv -f "${TMP}" "${OUT}"
