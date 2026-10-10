#!/usr/bin/env bash
# Load drivetemp so SATA/SAS disks expose hwmon temps to node_exporter.
# Kernel: https://docs.kernel.org/hwmon/drivetemp.html
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
# shellcheck source=setup-lib.sh
source "${ROOT}/hosts/_common/setup-lib.sh"

alfa_setup_begin "drivetemp-module"

USE_SUDO=0
SUDO=()
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO=(sudo)
  USE_SUDO=1
fi

if ! modinfo drivetemp >/dev/null 2>&1; then
  alfa_die "drivetemp kernel module not available (install linux-modules-extra?)"
fi

"${SUDO[@]}" modprobe drivetemp
echo drivetemp | "${SUDO[@]}" tee /etc/modules-load.d/drivetemp.conf >/dev/null

count=0
for _f in /sys/class/hwmon/hwmon*/name; do
  if [[ -f "$_f" ]] && grep -qx drivetemp "$_f" 2>/dev/null; then
    count=$((count + 1))
  fi
done

if [[ "$count" -eq 0 ]]; then
  alfa_log "WARN: drivetemp loaded but no drivetemp hwmon yet (disk may not support SMART temp)"
else
  alfa_log "ok: ${count} drivetemp hwmon device(s)"
fi

alfa_setup_finish
