# Shared by hosts/*/run.sh — source from repo after resolving ROOT.
# Git identity copied from rankings-bot (same operator commits).

MONITORING_ORIGIN_URL="${MONITORING_ORIGIN_URL:-https://github.com/Curt-Alfrey-s-Org/monitoring.git}"
GIT_USER_NAME="${GIT_USER_NAME:-Curt Alfrey}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:operator@example.com}"

ensure_git_identity() {
  local root="$1"
  if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: not a git repository: $root" >&2
    return 1
  fi
  git -C "$root" config --local user.name "$GIT_USER_NAME"
  git -C "$root" config --local user.email "$GIT_USER_EMAIL"
  echo "git identity (local): $(git -C "$root" config --local user.name) <$(git -C "$root" config --local user.email)>"
}

ensure_remote_origin() {
  local root="$1"
  if git -C "$root" remote get-url origin >/dev/null 2>&1; then
    git -C "$root" remote set-url origin "$MONITORING_ORIGIN_URL"
  else
    git -C "$root" remote add origin "$MONITORING_ORIGIN_URL"
  fi
  echo "git remote origin: $(git -C "$root" remote get-url origin)"
}
