#!/usr/bin/env bash
# Nightly second copy of the Dell's backups onto the secondary HDD (/mnt/hdd).
# Runs 05:15 UTC via hdd-backup-mirror.timer, after the 03:0x-03:2x backup jobs
# and clear of the Sunday 04:30 weekly maintenance.
#
# - restic-moc is mirrored exactly (--delete), so the copy stays a consistent repo;
#   refuses to run if the source repo looks empty or broken.
# - Dump directories are mirrored too, but files removed from the source move to
#   .retired/<name>/<date>/ and are only expired after MIRROR_RETENTION_DAYS, so the
#   HDD keeps a longer history than the SSD.
# - Verifies the mirrored restic repo opens and has the same snapshots as the source.
#
# Run manually: sudo systemctl start hdd-backup-mirror.service

set -euo pipefail

HDD=/mnt/hdd
DEST="$HDD/prsnl/backup-mirror"
MIRROR_RETENTION_DAYS="${MIRROR_RETENTION_DAYS:-60}"
export RESTIC_PASSWORD_FILE=/home/pronav/.restic-moc.key

# name|source|mode   mode: exact = mirror with --delete, history = keep extras
SOURCES=(
  "restic-moc|/home/pronav/backups/restic-moc|exact"
  "moc-dumps|/home/pronav/backups/moc|history"
  "dh-pg|/var/backups/dh|history"
  "deskos|/home/pronav/docker/deskos/backups|history"
)

log() { echo "[$(date -u +%FT%TZ)] $*"; }

mountpoint -q "$HDD" || { log "FAIL: $HDD is not mounted"; exit 1; }
mkdir -p "$DEST"

for entry in "${SOURCES[@]}"; do
  IFS='|' read -r name src mode <<<"$entry"
  if [ -z "$(find "$src" -type f -print -quit 2>/dev/null)" ]; then
    log "FAIL: $name source $src is missing or empty; not mirroring"
    exit 1
  fi
  # NTFS holds no Unix ownership/permissions: copy content and mtimes only.
  args=(-rt --modify-window=1 --partial-dir=.rsync-partial)
  if [ "$mode" = exact ]; then
    [ -f "$src/config" ] && [ -n "$(ls -A "$src/snapshots" 2>/dev/null)" ] \
      || { log "FAIL: $src does not look like a restic repo with snapshots"; exit 1; }
    args+=(--delete-after)
  fi
  if [ "$mode" = history ]; then
    # Files gone from the source move to a dated .retired dir instead of vanishing.
    args+=(--delete-after --backup --backup-dir="$DEST/.retired/$name/$(date -u +%F)")
  fi
  rsync "${args[@]}" "$src/" "$DEST/$name/"
  log "ok: $name ($(du -sh "$DEST/$name" | cut -f1))"
done

# Expire retired copies (not the live mirror) after the retention window.
[ -d "$DEST/.retired" ] && find "$DEST/.retired" -mindepth 2 -maxdepth 2 -type d \
  -mtime "+$MIRROR_RETENTION_DAYS" -exec rm -rf {} +

snapshot_times() { restic --repo "$1" snapshots --json --no-lock | grep -o '"time":"[^"]*"' | sort; }
src_snaps=$(snapshot_times /home/pronav/backups/restic-moc)
dst_snaps=$(snapshot_times "$DEST/restic-moc")
[ -n "$dst_snaps" ] && [ "$src_snaps" = "$dst_snaps" ] \
  || { log "FAIL: mirrored restic repo snapshots differ from source"; exit 1; }
log "ok: mirrored restic-moc opens; $(wc -l <<<"$dst_snaps") snapshots, newest $(tail -1 <<<"$dst_snaps" | cut -d'"' -f4)"
date -u +%FT%TZ > "$DEST/LAST_SUCCESS"
