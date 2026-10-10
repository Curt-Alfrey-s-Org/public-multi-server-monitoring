#!/usr/bin/env bash
# Shared helpers for host setup scripts: logging, verification, optional log push to the monitoring host ().
# shellcheck shell=bash
# Usage: set -euo pipefail; ROOT=...; source "${ROOT}/hosts/_common/setup-lib.sh"; alfa_setup_begin "my-run"

alfa_setup_begin() {
  local label="${1:-setup}"
  if [[ "$(id -u)" -eq 0 ]]; then
    ALFA_SETUP_LOG_DIR="/var/log/alfa-monitoring-setup"
  else
    ALFA_SETUP_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/alfa-monitoring-setup"
  fi
  mkdir -p "$ALFA_SETUP_LOG_DIR"
  ALFA_SETUP_LOG="${ALFA_SETUP_LOG_DIR}/${label}-$(date +%Y%m%d-%H%M%S).log"
  touch "$ALFA_SETUP_LOG"
  ln -sfn "$ALFA_SETUP_LOG" "${ALFA_SETUP_LOG_DIR}/latest.log"
  export ALFA_SETUP_LOG ALFA_SETUP_LOG_DIR
  alfa_log "=== begin ${label} host=$(hostname -f 2>/dev/null || hostname) user=$(whoami) ==="
}

alfa_log() {
  local line="[$(date -Iseconds)] $*"
  echo "$line" | tee -a "$ALFA_SETUP_LOG"
}

alfa_warn() {
  alfa_log "WARN: $*"
}

alfa_die() {
  alfa_log "FATAL: $*"
  alfa_push_setup_log || true
  exit 1
}

alfa_require_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    alfa_die "required command not found in PATH: $c"
  fi
}

# Arg: 1 = use sudo for docker, 0 = current user must access docker socket
alfa_verify_docker() {
  local use_sudo="$1"
  alfa_require_cmd docker
  alfa_log "checking: docker info"
  if [[ "$use_sudo" == "1" ]]; then
    sudo docker info >/dev/null || alfa_die "docker daemon not reachable (sudo docker info failed)"
    alfa_log "checking: docker compose"
    sudo docker compose version >/dev/null || alfa_die "docker compose plugin missing"
  else
    docker info >/dev/null 2>&1 || alfa_die "docker daemon not reachable (run with sudo or add user to docker group)"
    alfa_log "checking: docker compose"
    docker compose version >/dev/null 2>&1 || alfa_die "docker compose plugin missing"
  fi
}

alfa_verify_http_metrics() {
  local url="$1"
  local name="${2:-endpoint}"
  alfa_require_cmd curl
  alfa_log "checking: GET $url ($name)"
  local sample
  sample="$(curl -fsS --max-time 8 "$url" 2>/dev/null | head -c 800 || true)"
  if [[ "$sample" != *"# HELP "* ]] && [[ "$sample" != *"# TYPE "* ]]; then
    alfa_log "response sample (first 800 bytes):"
    alfa_log "$sample"
    alfa_die "metrics endpoint did not return Prometheus exposition: $url"
  fi
  alfa_log "ok: $name responds with Prometheus metrics"
}

alfa_verify_container_running() {
  local use_sudo="$1"
  local cname="$2"
  alfa_log "checking: container running: $cname"
  local running
  if [[ "$use_sudo" == "1" ]]; then
    running="$(sudo docker inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)"
  else
    running="$(docker inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)"
  fi
  if [[ "$running" != "true" ]]; then
    alfa_log "docker inspect / logs:"
    if [[ "$use_sudo" == "1" ]]; then
      sudo docker ps -a --filter "name=${cname}" || true
      sudo docker logs --tail 120 "$cname" 2>&1 || true
    else
      docker ps -a --filter "name=${cname}" || true
      docker logs --tail 120 "$cname" 2>&1 || true
    fi
    alfa_die "container not running: $cname"
  fi
}

alfa_verify_nvidia_for_docker_gpu() {
  alfa_log "checking: nvidia-smi (GPU profile requested)"
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    alfa_die "nvidia-smi not found; install NVIDIA drivers before --with-gpu"
  fi
  nvidia-smi -L || alfa_die "nvidia-smi -L failed"
  alfa_log "checking: docker NVIDIA runtime (docker info)"
  if docker info 2>/dev/null | grep -qi 'nvidia'; then
    alfa_log "ok: docker info mentions nvidia"
  else
    alfa_warn "docker info does not mention nvidia — install nvidia-container-toolkit if GPU compose fails"
  fi
}

# Optional: export ALFA_MONITORING_LOG_PUSH_DEST=user@192.0.2.10:/path/to/dir/
alfa_push_setup_log() {
  local dest="${ALFA_MONITORING_LOG_PUSH_DEST:-}"
  [[ -z "$dest" ]] && return 0
  [[ -f "${ALFA_SETUP_LOG:-}" ]] || return 0
  if ! command -v scp >/dev/null 2>&1; then
    alfa_warn "scp not found; cannot push log to $dest"
    return 1
  fi
  local host rfile
  if [[ "$dest" != *:* ]]; then
    alfa_warn "ALFA_MONITORING_LOG_PUSH_DEST must be user@host:/path/ (got: $dest)"
    return 1
  fi
  host="${dest%%:*}"
  local path="${dest#*:}"
  rfile="${path%/}/$(hostname -s 2>/dev/null || hostname)-setup-$(date +%Y%m%d-%H%M%S).log"
  alfa_log "pushing log via scp to ${host}:${rfile}"
  if scp -o BatchMode=yes -o ConnectTimeout=10 -p "$ALFA_SETUP_LOG" "${host}:${rfile}"; then
    alfa_log "ok: log pushed"
  else
    alfa_warn "scp failed (SSH key to $host? path writable?)"
    return 1
  fi
}

alfa_setup_finish() {
  alfa_log "=== finished OK; log file: $ALFA_SETUP_LOG ==="
  alfa_push_setup_log || true
}
