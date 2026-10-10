#!/usr/bin/env bash
# Install IPMI CPU temp textfile collector (BMC hosts only). Requires ipmitool + /dev/ipmi0.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
# shellcheck source=setup-lib.sh
source "${ROOT}/hosts/_common/setup-lib.sh"

alfa_setup_begin "ipmi-cpu-textfile"

USE_SUDO=0
SUDO=()
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO=(sudo)
  USE_SUDO=1
fi

alfa_require_cmd ipmitool
if [[ ! -e /dev/ipmi0 ]]; then
  alfa_die "/dev/ipmi0 missing -- this host has no local IPMI device"
fi

BIN_DIR="${ALFA_IPMI_BIN_DIR:-/mnt/HDDs/Alfa-AI/monitoring/bin}"
TEXTFILE_DIR="${ALFA_IPMI_TEXTFILE_DIR:-/var/lib/alfa-monitoring/textfile}"
alfa_log "installing textfile writer to ${BIN_DIR}"
"${SUDO[@]}" mkdir -p "${BIN_DIR}"
"${SUDO[@]}" install -m 0755 "${DIR}/scripts/write-ipmi-temps-textfile.sh" "${BIN_DIR}/alfa-write-ipmi-temps-textfile.sh"
"${SUDO[@]}" mkdir -p "${TEXTFILE_DIR}"
"${SUDO[@]}" install -m 0644 "${DIR}/systemd/alfa-ipmi-cpu-textfile.service" /etc/systemd/system/
"${SUDO[@]}" install -m 0644 "${DIR}/systemd/alfa-ipmi-cpu-textfile.timer" /etc/systemd/system/
"${SUDO[@]}" systemctl daemon-reload
"${SUDO[@]}" systemctl enable --now alfa-ipmi-cpu-textfile.timer
sleep 2
"${SUDO[@]}" systemctl start alfa-ipmi-cpu-textfile.service
if [[ ! -f "${TEXTFILE_DIR}/ipmi_cpu_temp.prom" ]]; then
  alfa_die "textfile not created at ${TEXTFILE_DIR}/ipmi_cpu_temp.prom"
fi
SENSOR_COUNT="$("${SUDO[@]}" grep -c '^ipmi_temperature_celsius{' "${TEXTFILE_DIR}/ipmi_cpu_temp.prom" || true)"
alfa_log "ok: ${SENSOR_COUNT} BMC temperature sensor(s) in ${TEXTFILE_DIR}/ipmi_cpu_temp.prom"
"${SUDO[@]}" grep '^ipmi_temperature_celsius{' "${TEXTFILE_DIR}/ipmi_cpu_temp.prom" | while IFS= read -r line; do
  alfa_log "  ${line}"
done
alfa_log "Ensure node_exporter mounts ${TEXTFILE_DIR} at --collector.textfile.directory"
alfa_setup_finish
