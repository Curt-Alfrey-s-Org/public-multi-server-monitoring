#!/usr/bin/env bash
# Write all BMC temperature sensors (degrees C) for node_exporter textfile collector.
# Official ipmitool: https://github.com/ipmitool/ipmitool/blob/master/doc/ipmitool.1.in
#   sensor list  -- Name | Reading | Units | ...
#   sdr type Temperature -- Name | ID | Status | Entity | N degrees C
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
  {
    echo "__SENSOR__"
    ipmitool sensor list 2>/dev/null || true
    echo "__SDR__"
    ipmitool sdr type Temperature 2>/dev/null || ipmitool sdr type temperature 2>/dev/null || true
  } | awk -F '|' '
function trim(s) { gsub(/^ +| +$/, "", s); return s }
function esc(name) {
  gsub(/\\/, "\\\\", name)
  gsub(/"/, "\\\"", name)
  return name
}
function emit(name, val) {
  if (name == "" || val !~ /^[0-9+-]/) return
  if (name in seen) return
  seen[name] = 1
  printf "ipmi_temperature_celsius{name=\"%s\",source=\"ipmi\"} %s\n", esc(name), val
}
function val_from_deg_c(reading) {
  reading = trim(reading)
  if (reading !~ /degrees C/) return ""
  sub(/ degrees C.*$/, "", reading)
  if (reading ~ /^[0-9+-]/) return reading
  return ""
}
BEGIN { mode = "" }
/^__SENSOR__$/ { mode = "sensor"; next }
/^__SDR__$/ { mode = "sdr"; next }
$0 ~ /^#/ { next }
$0 ~ /^Sensor ID/ { next }
$0 ~ /^---/ { next }
mode == "sensor" {
  name = trim($1)
  reading = trim($2)
  units = trim($3)
  if (units ~ /degrees C/) emit(name, reading)
}
mode == "sdr" {
  name = trim($1)
  val = val_from_deg_c($5)
  emit(name, val)
}
'
} > "${TMP}"

if ! grep -q '^ipmi_temperature_celsius{' "${TMP}"; then
  echo "write-ipmi-temps-textfile: no degree-C sensors from ipmitool sensor list or sdr type Temperature" >&2
  rm -f "${TMP}"
  exit 1
fi

mv -f "${TMP}" "${OUT}"
