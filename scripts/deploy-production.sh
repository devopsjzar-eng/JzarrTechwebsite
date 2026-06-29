#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-/var/www/JzarrTechwebsite}"
BRANCH="${1:-main}"
FRONTEND_DIR="$REPO_DIR/jzarrtech"
BACKEND_DIR="$REPO_DIR/jzarrtechserver"
ECOSYSTEM_FILE="$BACKEND_DIR/ecosystem.config.cjs"
PM2_APP="jzarrtechserver"
LOCAL_HEALTH_URL="http://127.0.0.1:8787/api/health"
PUBLIC_HEALTH_URL="https://api.jzarrtech.com/api/health"
LOCK_FILE="/tmp/jzarrtech-production-deploy.lock"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '\nDeployment failed: %s\n' "$*" >&2
  exit 1
}

for command in git npm curl flock sudo; do
  command -v "$command" >/dev/null 2>&1 || fail "Required command is missing: $command"
done

[[ -d "$REPO_DIR/.git" ]] || fail "Repository not found at $REPO_DIR"
[[ -f "$BACKEND_DIR/.env" ]] || fail "Missing production environment file: $BACKEND_DIR/.env"
[[ -f "$ECOSYSTEM_FILE" ]] || fail "Missing PM2 configuration: $ECOSYSTEM_FILE"

exec 9>"$LOCK_FILE"
flock -n 9 || fail "Another JzarrTech deployment is already running."

cd "$REPO_DIR"

CURRENT_BRANCH="$(git branch --show-current)"
[[ "$CURRENT_BRANCH" == "$BRANCH" ]] ||
  fail "Expected branch '$BRANCH', but '$CURRENT_BRANCH' is checked out."

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  fail "Tracked production files have local changes. Commit or resolve them before deploying."
fi

log "Authenticating sudo access"
sudo -v

log "Fetching origin/$BRANCH"
git fetch --prune origin "$BRANCH"
git merge --ff-only "origin/$BRANCH"

log "Installing locked workspace dependencies"
npm ci

log "Running backend tests"
npm test --workspace jzarrtechserver

log "Building frontend"
npm run build --workspace jzarrtech
[[ -f "$FRONTEND_DIR/build/index.html" ]] || fail "Frontend build did not produce build/index.html."

log "Starting or reloading only $PM2_APP"
sudo pm2 startOrReload "$ECOSYSTEM_FILE" --only "$PM2_APP" --update-env

log "Waiting for local API health"
healthy=false
for _ in {1..15}; do
  if curl --fail --silent --show-error "$LOCAL_HEALTH_URL" | grep -q '"ok":true'; then
    healthy=true
    break
  fi
  sleep 2
done

if [[ "$healthy" != true ]]; then
  sudo pm2 logs "$PM2_APP" --lines 40 --nostream || true
  fail "Local API health check did not pass."
fi

log "Checking API through Nginx"
curl --fail --silent --show-error "$PUBLIC_HEALTH_URL" | grep -q '"ok":true' ||
  fail "Public API health check did not pass."

sudo pm2 save

log "Deployment complete at commit $(git rev-parse --short HEAD)"
