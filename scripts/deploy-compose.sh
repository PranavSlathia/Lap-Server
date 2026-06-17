#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Deploy a tracked compose file to the Dell server.

Usage:
  ./scripts/deploy-compose.sh [infra|n8n] [local|tailscale] [--dry-run] [--yes]

Defaults:
  target: infra
  host:   local

Examples:
  ./scripts/deploy-compose.sh infra tailscale --dry-run
  ./scripts/deploy-compose.sh n8n tailscale --yes

The script copies to a temporary remote candidate, validates it with
`docker compose config -q`, shows a diff, backs up the current remote compose,
then applies only after confirmation or --yes.
USAGE
}

TARGET="infra"
NETWORK="local"
DRY_RUN=0
ASSUME_YES=0

for arg in "$@"; do
  case "$arg" in
    infra|n8n) TARGET="$arg" ;;
    local|tailscale) NETWORK="$arg" ;;
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$NETWORK" == "tailscale" ]]; then
  HOST="100.103.66.92"
else
  HOST="192.168.1.18"
fi

case "$TARGET" in
  infra)
    LOCAL_COMPOSE="$(cd "$(dirname "$0")/.." && pwd)/docker/docker-compose.yml"
    REMOTE_DIR="/home/pronav/docker"
    REMOTE_COMPOSE="$REMOTE_DIR/docker-compose.yml"
    DEPLOY_CMD='sudo docker compose -f docker-compose.yml pull && sudo docker compose -f docker-compose.yml up -d'
    ;;
  n8n)
    LOCAL_COMPOSE="$(cd "$(dirname "$0")/.." && pwd)/docker/n8n/docker-compose.yml"
    REMOTE_DIR="/home/pronav/docker/n8n"
    REMOTE_COMPOSE="$REMOTE_DIR/docker-compose.yml"
    DEPLOY_CMD='docker compose -f docker-compose.yml pull --ignore-buildable || true; docker compose -f docker-compose.yml up -d --build'
    ;;
esac

REMOTE="pronav@$HOST"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
CANDIDATE="$REMOTE_DIR/.deploy-candidate-$STAMP.yml"
BACKUP="$REMOTE_COMPOSE.bak-$STAMP"

echo "Target: $TARGET"
echo "Host:   $REMOTE"
echo "Local:  $LOCAL_COMPOSE"
echo "Remote: $REMOTE_COMPOSE"
echo

if [[ ! -f "$LOCAL_COMPOSE" ]]; then
  echo "Missing local compose file: $LOCAL_COMPOSE" >&2
  exit 1
fi

if [[ "$TARGET" == "infra" ]]; then
  docker compose -f "$LOCAL_COMPOSE" config -q
fi

scp "$LOCAL_COMPOSE" "$REMOTE:$CANDIDATE"

ssh "$REMOTE" "cd '$REMOTE_DIR' && docker compose -f '$CANDIDATE' config -q"

echo
echo "Remote diff:"
ssh "$REMOTE" "diff -u '$REMOTE_COMPOSE' '$CANDIDATE' || true"
echo

if [[ $DRY_RUN -eq 1 ]]; then
  ssh "$REMOTE" "rm -f '$CANDIDATE'"
  echo "Dry run complete. No remote files changed."
  exit 0
fi

if [[ $ASSUME_YES -ne 1 ]]; then
  read -r -p "Apply this compose to $TARGET on $HOST? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *)
      ssh "$REMOTE" "rm -f '$CANDIDATE'"
      echo "Aborted. Candidate removed."
      exit 1
      ;;
  esac
fi

ssh "$REMOTE" "set -euo pipefail
cp -a '$REMOTE_COMPOSE' '$BACKUP'
mv '$CANDIDATE' '$REMOTE_COMPOSE'
cd '$REMOTE_DIR'
$DEPLOY_CMD
"

echo
echo "Done. Backup: $BACKUP"
ssh "$REMOTE" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
