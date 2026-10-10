#!/usr/bin/env bash
# Create data/dozzle/users.yaml for central Dozzle auth (simple provider).
# Run once on the monitoring host 192.0.2.10 from the monitoring repo root:
#   ./scripts/setup-dozzle-auth.sh
#
# Credentials: set DOZZLE_OPERATOR_USER and DOZZLE_OPERATOR_PASSWORD in ./.env
# (see .env.example). Skips if data/dozzle/users.yaml already exists.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/data/dozzle/users.yaml"
ENV_FILE="${ROOT}/.env"

mkdir -p "${ROOT}/data/dozzle"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ -f "$OUT" ]]; then
  echo "exists: $OUT (unchanged)"
  echo "Login: ${DOZZLE_OPERATOR_USER:-operator} (password in monitoring/.env)"
  exit 0
fi

USER="${DOZZLE_OPERATOR_USER:-operator}"
PASS="${DOZZLE_OPERATOR_PASSWORD:-}"
if [[ -z "$PASS" ]]; then
  PASS="$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)"
  echo "Generated DOZZLE_OPERATOR_PASSWORD (add to monitoring/.env): $PASS"
fi

docker run --rm amir20/dozzle:v10.6.15 generate "$USER" \
  --password "$PASS" --email ops@local --name Operator \
  --user-roles download > "$OUT"

chmod 600 "$OUT"
echo "wrote $OUT"
echo "Login: ${USER} (password in monitoring/.env if set)"
