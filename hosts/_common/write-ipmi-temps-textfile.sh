#!/usr/bin/env bash
# Write all BMC temperature sensors (degrees C) for node_exporter textfile collector.
# Official ipmitool: https://github.com/ipmitool/ipmitool/blob/master/doc/ipmitool.1.in
# Textfile collector: https://github.com/
set -euo pipefail

OUT_DIR="${ALFA_IPMI_TEXTFILE_DIR:-/var/lib/alfa-monitoring/textfile}"
TMP="${OUT_DIR}/ipmi_cpu_temp.prom.$$"
OUT="${OUT_DIR}/ipmi_cpu_temp.prom"

if ! command -v ipmitool >/dev/null 2>&1; then
  echo "write-ipmi-temps-textfile: ipmitool not found" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

{
  echo "# HELP ipmi_temperature_celsius IPMI threshold sensor temperature in degrees Celsius (BMC)."
  echo "# TYPE ipmi_temperature_celsius gauge"
  ipmitool sensor list 2>/dev/null | awk -F'|' '
    function trim(s) { gsub(/^ +| +$/, "", s); return s }
    {
      name = trim($1)
      reading = trim($2)
      units = trim($3)
      if (units ~ /degrees C/ && reading ~ /^[0-9+-]/) {
        gsub(/\\/, "\\\\", name)
        gsub(/"/, "\\\"", name)
        printf "ipmi_temperature_celsius{name=\"%s\",source=\"ipmi\"} %s\n", name, reading
      }
    }
  '
} > "${TMP}"

if ! grep -q '^ipmi_temperature_celsius{' "${TMP}"; then
  echo "write-ipmi-temps-textfile: no degree-C sensors from ipmitool sensor list" >&2
  rm -f "${TMP}"
  exit 1
fi

mv -f "${TMP}" "${OUT}"
