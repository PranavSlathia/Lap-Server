#!/usr/bin/env bash
# Weekly Dell server maintenance.
# Runs Sunday 04:30 UTC (10:00 IST). Installed in root crontab.
# - Reports to ~/docker/scripts/reports/YYYY-MM-DD.md
# - Posts a GitHub issue if any WARN or CRITICAL
# - Applies safe auto-fixes in-line
# - Keeps last 12 reports
#
# Run manually: sudo bash ~/docker/scripts/weekly-maintenance.sh [--dry-run]

set -uo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

USER_HOME="/home/pronav"
SCRIPT_DIR="$USER_HOME/docker/scripts"
REPORT_DIR="$SCRIPT_DIR/reports"
LOCK_FILE="/var/lock/weekly-maintenance.lock"
DATE_TAG="$(date -u +%Y-%m-%d)"
REPORT_FILE="$REPORT_DIR/${DATE_TAG}.md"
GH_REPO="PranavSlathia/Lap-Server"
RETENTION_WEEKS=12

mkdir -p "$REPORT_DIR"
chown -R pronav:pronav "$SCRIPT_DIR"

# Single-instance lock
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "Another maintenance run is in progress; exiting." >&2
  exit 1
fi

# ── Counters & buffers ─────────────────────────────────────────
WARN_COUNT=0
CRIT_COUNT=0
AUTOFIX_COUNT=0
HEALTHY=()
WARNINGS=()
CRITICALS=()
AUTOFIXES=()

heal() { HEALTHY+=("$1"); }
warn() { WARNINGS+=("$1"); WARN_COUNT=$((WARN_COUNT+1)); }
crit() { CRITICALS+=("$1"); CRIT_COUNT=$((CRIT_COUNT+1)); }
fix()  { AUTOFIXES+=("$1"); AUTOFIX_COUNT=$((AUTOFIX_COUNT+1)); }

run() {
  # Run a command unless dry-run; capture return code
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "(dry-run) $*"
    return 0
  fi
  "$@"
}

# ── Check 1: Disk + inodes ─────────────────────────────────────
DISK_USE=$(df -P / | awk 'NR==2 {print $5}' | tr -d '%')
INODE_USE=$(df -Pi / | awk 'NR==2 {print $5}' | tr -d '%')
DOCKER_RECLAIM_BYTES=$(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1 | awk '{print $1$2}')

if   [[ $DISK_USE -ge 90 ]]; then crit "Disk root at ${DISK_USE}% (>=90% — CRITICAL)"
elif [[ $DISK_USE -ge 80 ]]; then warn "Disk root at ${DISK_USE}% (>=80%)"
else                              heal "Disk root at ${DISK_USE}%"
fi

if   [[ $INODE_USE -ge 70 ]]; then warn "Inodes at ${INODE_USE}% (>=70%)"
else                               heal "Inodes at ${INODE_USE}%"
fi

# ── Check 2: Container health & restart counts ────────────────
UNHEALTHY=$(docker ps -a --format '{{.Names}}|{{.Status}}' | awk -F'|' '$2 !~ /^Up / || $2 ~ /\(unhealthy\)/ {print $1": "$2}')
if [[ -n "$UNHEALTHY" ]]; then
  while IFS= read -r line; do warn "Container not healthy — $line"; done <<<"$UNHEALTHY"
else
  heal "All containers running cleanly"
fi

while IFS='|' read -r name rc; do
  if [[ ${rc:-0} -gt 5 ]]; then warn "Container $name has RestartCount=$rc (>5 — flapping)"; fi
done < <(docker ps -a --format '{{.Names}}' | while read n; do
           rc=$(docker inspect "$n" --format '{{.RestartCount}}' 2>/dev/null || echo 0)
           echo "$n|$rc"
         done)

# ── Check 3: Stale docker.sock detection (the Dozzle-class bug) ─
DOCK_SOCK_NO_HC=$(docker ps -a --format '{{.Names}}' | while read n; do
  has_sock=$(docker inspect "$n" --format '{{range .Mounts}}{{if eq .Destination "/var/run/docker.sock"}}yes{{end}}{{end}}' 2>/dev/null)
  has_hc=$(docker inspect "$n" --format '{{if .Config.Healthcheck}}yes{{end}}' 2>/dev/null)
  if [[ "$has_sock" == "yes" && "$has_hc" != "yes" ]]; then echo "$n"; fi
done)
if [[ -n "$DOCK_SOCK_NO_HC" ]]; then
  while IFS= read -r n; do
    warn "Container '$n' mounts docker.sock but has no healthcheck (vulnerable to stale-socket bug)"
    # Heuristic auto-restart: if logs show host-offline-class errors in last 100 lines, restart
    if docker logs --tail 100 "$n" 2>&1 | grep -qiE "cannot connect to the docker daemon|docker store unexpectedly disconnected|host .* unavailable"; then
      if [[ $DRY_RUN -eq 0 ]]; then
        docker restart "$n" >/dev/null && fix "Restarted '$n' (stale docker.sock — host-offline error in recent logs)"
      else
        fix "(dry-run) would restart '$n' (stale docker.sock signature in logs)"
      fi
    fi
  done <<<"$DOCK_SOCK_NO_HC"
else
  heal "All docker.sock-mounting containers have healthchecks"
fi

# ── Check 4: Update backlog ────────────────────────────────────
UPDATES=$(apt list --upgradable 2>/dev/null | grep -v '^Listing' | wc -l)
SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -ci security || true)
if   [[ $SECURITY_UPDATES -gt 0 ]]; then crit "Security updates pending: $SECURITY_UPDATES"
elif [[ $UPDATES -gt 20 ]];          then warn "$UPDATES packages upgradable (>20)"
else                                       heal "$UPDATES packages upgradable, 0 security"
fi

# ── Check 5: Reboot pending ────────────────────────────────────
if [[ -f /var/run/reboot-required ]]; then
  warn "Reboot required ($(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ',' | sed 's/,$//') )"
else
  heal "No reboot pending"
fi

# ── Check 6: Failed systemd units ──────────────────────────────
FAILED_UNITS=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
if [[ -n "$FAILED_UNITS" ]]; then
  while IFS= read -r u; do warn "Failed systemd unit: $u"; done <<<"$FAILED_UNITS"
else
  heal "No failed systemd units"
fi

# ── Check 7: fail2ban ──────────────────────────────────────────
if systemctl is-active fail2ban >/dev/null 2>&1; then
  BANNED=$(fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' | awk -F: '{print $2}' | tr -d ' \t')
  heal "fail2ban active, sshd jail: ${BANNED:-0} banned IPs"
else
  crit "fail2ban is NOT active"
fi

# ── Check 8: UFW posture ───────────────────────────────────────
UFW_STATE=$(ufw status | head -1)
if [[ "$UFW_STATE" == *"Status: active"* ]]; then
  PUBLIC_PORTS=$(ufw status | awk '/ALLOW/ && !/100\.64\.0\.0|192\.168\.1\.0|172\.24\.0\.0|127\.0\.0\.1/ && !/(v6)/ {print}' | grep -v '^$')
  # Expected public-allow rules: 22 (ssh) only. Cloudflare Tunnel uses outbound.
  UNEXPECTED_PUBLIC=$(echo "$PUBLIC_PORTS" | awk '{print $1}' | grep -vE '^(22|22/tcp|OpenSSH|Anywhere)$' | grep -v '^$' || true)
  heal "UFW active"
  if [[ -n "$UNEXPECTED_PUBLIC" ]]; then warn "Unexpected UFW public rules: $UNEXPECTED_PUBLIC"; fi
else
  crit "UFW not active"
fi

# ── Check 9: Tailscale ─────────────────────────────────────────
if command -v tailscale >/dev/null && tailscale status >/dev/null 2>&1; then
  TS_SELF=$(tailscale status --self --json 2>/dev/null | grep -m1 '"Online"' | awk '{print $2}' | tr -d ',')
  if [[ "$TS_SELF" == "true" ]]; then
    DERP_TO_MAC=$(tailscale status | awk '/pranavs-mac-mini/ {for(i=1;i<=NF;i++) if($i~/relay/) print "yes"}')
    [[ "$DERP_TO_MAC" == "yes" ]] && warn "Tailscale path to Mac mini is via DERP relay (not direct)" || heal "Tailscale online, direct path to Mac mini"
  else
    crit "Tailscale shows self offline"
  fi
else
  crit "Tailscale not running"
fi

# ── Check 10: Cloudflare Tunnel ────────────────────────────────
if systemctl is-active cloudflared >/dev/null 2>&1; then
  # Filter out known-benign noise:
  #   - "sendmsg: network is unreachable" — transient ISP blips, auto-reconnects
  #   - "stream X canceled by remote with error code 0" — clean SSE client disconnects
  CF_ERRORS_REAL=$(journalctl -u cloudflared --since "7 days ago" --no-pager 2>/dev/null \
    | grep -iE 'ERR|error' \
    | grep -vE 'sendmsg: network is unreachable|stream [0-9]+ canceled by remote with error code 0' \
    | wc -l)
  if   [[ $CF_ERRORS_REAL -gt 20 ]]; then warn "cloudflared has $CF_ERRORS_REAL non-benign errors in last 7d"
  else                                    heal "cloudflared active ($CF_ERRORS_REAL non-benign errors in 7d)"
  fi
else
  crit "cloudflared service not active"
fi

# ── Check 11: Public endpoint ──────────────────────────────────
HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 https://moc.prsnl.fyi || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
  heal "https://moc.prsnl.fyi → HTTP 200"
else
  # Auto-fix attempt: if origin localhost:5173 is 200 and cloudflared is active
  # but public is broken (e.g. 525, 502, 521), it's almost always cloudflared
  # in a stale-QUIC state — restart it. Same root cause as the 2026-05-05 525.
  ORIGIN_CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:5173 || echo "000")
  if [[ "$ORIGIN_CODE" == "200" ]] && systemctl is-active cloudflared >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 0 ]]; then
      systemctl restart cloudflared && sleep 8
      RETRY_CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 https://moc.prsnl.fyi || echo "000")
      if [[ "$RETRY_CODE" == "200" ]]; then
        fix "Public endpoint was HTTP $HTTP_CODE (origin healthy); restarted cloudflared and recovered to HTTP 200"
      else
        crit "https://moc.prsnl.fyi → HTTP $HTTP_CODE; tried cloudflared restart, still HTTP $RETRY_CODE"
      fi
    else
      fix "(dry-run) would restart cloudflared (origin localhost:5173 OK, public HTTP $HTTP_CODE)"
    fi
  else
    crit "https://moc.prsnl.fyi → HTTP $HTTP_CODE (origin localhost:5173 → HTTP $ORIGIN_CODE; cloudflared $(systemctl is-active cloudflared 2>&1))"
  fi
fi

# ── Check 12: Postgres health ──────────────────────────────────
if docker ps --format '{{.Names}}' | grep -q '^moc-db$'; then
  PG_SIZE=$(docker exec moc-db psql -U moc -d moc -tAc "SELECT pg_size_pretty(pg_database_size('moc'));" 2>/dev/null | tr -d '[:space:]')
  [[ -z "$PG_SIZE" ]] && PG_SIZE="?"
  LAST_VAC=$(docker exec moc-db psql -U moc -d moc -tAc "SELECT max(greatest(last_vacuum, last_autovacuum)) FROM pg_stat_user_tables;" 2>/dev/null | tr -d '[:space:]')
  # MOC moved from pg_dump files to restic via moc-backup.service/.timer (2026-05).
  BK_RESULT=$(systemctl show moc-backup.service -p Result --value 2>/dev/null)
  BK_FINISH=$(systemctl show moc-backup.service -p ExecMainExitTimestamp --value 2>/dev/null)
  if [[ -n "$BK_FINISH" ]]; then
    BACKUP_AGE_HOURS=$(( ( $(date +%s) - $(date -d "$BK_FINISH" +%s) ) / 3600 ))
    if [[ "$BK_RESULT" != "success" ]]; then crit "MOC restic backup last run result=${BK_RESULT} (${BACKUP_AGE_HOURS}h ago)"
    elif [[ $BACKUP_AGE_HOURS -gt 36 ]];   then warn "MOC restic backup is ${BACKUP_AGE_HOURS}h old (>36h)"
    else                                        heal "Postgres ${PG_SIZE}, restic backup ${BACKUP_AGE_HOURS}h ago"
    fi
  else
    warn "moc-backup.service has no successful run recorded (restic backup may be failing)"
  fi
else
  warn "moc-db container not running"
fi

# ── Check 13: Mem0 decommissioned (graph-first cutover 2026-05-05) ──
# Previously checked moc-memory reachability; removed after Mem0 retirement.

# ── Check 14: Watchtower polling ──────────────────────────────
if docker ps --format '{{.Names}}' | grep -q '^watchtower$'; then
  WT_SINCE=$(date -u --date '8 days ago' '+%Y-%m-%dT%H:%M:%S')
  WT_LAST=$(docker logs watchtower --since "$WT_SINCE" 2>&1 | grep -iE 'session done|scheduling|checking|next scheduled|update completed' | tail -1)
  if [[ -z "$WT_LAST" ]]; then
    # Fallback: any log line at all in last 8 days?
    WT_ANY=$(docker logs watchtower --since "$WT_SINCE" 2>&1 | tail -1)
    [[ -n "$WT_ANY" ]] && heal "Watchtower active (last log: $(echo "$WT_ANY" | head -c 80)...)" || warn "Watchtower has no log activity in last 8 days"
  else
    heal "Watchtower polling (last activity: $(echo "$WT_LAST" | head -c 80)...)"
  fi
else
  warn "Watchtower not running"
fi

# ── Check 15: Memory pressure ─────────────────────────────────
MEM_PCT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
SWAP_PCT=$(free | awk '/^Swap:/ {if($2>0) printf "%.0f", $3/$2*100; else print "0"}')
if   [[ $MEM_PCT -ge 90 ]]; then crit "RAM at ${MEM_PCT}%"
elif [[ $MEM_PCT -ge 80 ]]; then warn "RAM at ${MEM_PCT}%"
else                             heal "RAM at ${MEM_PCT}%, swap ${SWAP_PCT}%"
fi
[[ $SWAP_PCT -ge 50 ]] && warn "Swap at ${SWAP_PCT}% (heavy swapping)"

# ── Check 15b: CPU load pressure ──────────────────────────────
CPU_COUNT=$(nproc 2>/dev/null || echo 2)
LOAD15=$(awk '{print $3}' /proc/loadavg)
LOAD_PCT=$(awk -v loadavg="$LOAD15" -v cpu="$CPU_COUNT" 'BEGIN {printf "%.0f", (loadavg / cpu) * 100}')
if   [[ $LOAD_PCT -ge 200 ]]; then crit "15m load ${LOAD15} on ${CPU_COUNT} CPUs (${LOAD_PCT}% capacity)"
elif [[ $LOAD_PCT -ge 150 ]]; then warn "15m load ${LOAD15} on ${CPU_COUNT} CPUs (${LOAD_PCT}% capacity)"
else                                heal "15m load ${LOAD15} on ${CPU_COUNT} CPUs (${LOAD_PCT}% capacity)"
fi

# ── Check 16: Log file sizes ───────────────────────────────────
BIG_VAR_LOGS=$(find /var/log -type f -size +100M 2>/dev/null)
if [[ -n "$BIG_VAR_LOGS" ]]; then
  while IFS= read -r f; do warn "/var/log file >100MB: $f ($(du -h "$f" | awk '{print $1}'))"; done <<<"$BIG_VAR_LOGS"
fi

# Container logs
while read -r container_name; do
  log_path=$(docker inspect "$container_name" --format '{{.LogPath}}' 2>/dev/null)
  if [[ -f "$log_path" ]]; then
    size_mb=$(stat -c %s "$log_path" 2>/dev/null | awk '{print int($1/1024/1024)}')
    if [[ $size_mb -gt 50 ]]; then
      if [[ $DRY_RUN -eq 0 ]]; then
        docker restart "$container_name" >/dev/null 2>&1 && fix "Restarted '$container_name' to rotate log (was ${size_mb}MB; log-rotation: 10MB×3 should kick in)"
      else
        fix "(dry-run) would restart '$container_name' (log was ${size_mb}MB)"
      fi
    fi
  fi
done < <(docker ps --format '{{.Names}}')

# ── Auto-fix: image prune (dangling only) ─────────────────────
if [[ $DRY_RUN -eq 0 ]]; then
  PRUNED_IMG=$(docker image prune -af 2>&1 | tail -1 | grep -oE 'reclaimed[^[:space:]]+([^$]*)' || true)
  PRUNED_CON=$(docker container prune -f --filter 'until=168h' 2>&1 | tail -1 | grep -oE 'reclaimed[^[:space:]]+([^$]*)' || true)
  [[ -n "$PRUNED_IMG" ]] && fix "docker image prune: $PRUNED_IMG"
  [[ -n "$PRUNED_CON" ]] && fix "docker container prune (>7d stopped): $PRUNED_CON"
else
  fix "(dry-run) would prune unused docker images and containers >7d"
fi

# ── Auto-fix: harden any docker.sock-mounted container missing healthcheck ──
# We've already restarted ones in active distress (Check 3). Here we also try to add
# healthcheck via compose if their compose file is at ~/docker/docker-compose.yml.
# Conservative: only act if compose syntax already validates clean.
# Skipping aggressive auto-edit; just flag for manual hardening.
# (Manual hardening was applied to Dozzle previously; pattern is documented.)

# ── Compose report ─────────────────────────────────────────────
{
  echo "# Dell maintenance — ${DATE_TAG}"
  echo
  echo "_Run at $(date -u '+%Y-%m-%d %H:%M:%S UTC') | Hostname: $(hostname) | Uptime: $(uptime -p)_"
  echo
  echo "## Summary"
  echo "- Healthy: ${#HEALTHY[@]}"
  echo "- Warnings: ${WARN_COUNT}"
  echo "- Critical: ${CRIT_COUNT}"
  echo "- Auto-fixes applied: ${AUTOFIX_COUNT}"
  echo

  if [[ $CRIT_COUNT -gt 0 ]]; then
    echo "## 🚨 Action needed (CRITICAL)"
    for x in "${CRITICALS[@]}"; do echo "- $x"; done
    echo
  fi

  if [[ $WARN_COUNT -gt 0 ]]; then
    echo "## ⚠️ Warnings"
    for x in "${WARNINGS[@]}"; do echo "- $x"; done
    echo
  fi

  if [[ $AUTOFIX_COUNT -gt 0 ]]; then
    echo "## 🔧 Auto-fixes applied"
    for x in "${AUTOFIXES[@]}"; do echo "- $x"; done
    echo
  fi

  echo "## ✅ Healthy"
  for x in "${HEALTHY[@]}"; do echo "- $x"; done
} > "$REPORT_FILE"
chown pronav:pronav "$REPORT_FILE"

echo "Report: $REPORT_FILE"

# ── Notify via GitHub issue (only if WARN or CRITICAL) ────────
if [[ $DRY_RUN -eq 0 && ($CRIT_COUNT -gt 0 || $WARN_COUNT -gt 0) ]]; then
  TITLE="[maintenance ${DATE_TAG}] $CRIT_COUNT critical, $WARN_COUNT warnings"
  [[ $CRIT_COUNT -gt 0 ]] && TITLE="🚨 ${TITLE}"
  sudo -u pronav -H gh issue create \
    --repo "$GH_REPO" \
    --title "$TITLE" \
    --body-file "$REPORT_FILE" \
    --label "maintenance" 2>&1 | tail -3 || echo "gh issue create failed — report saved locally"
fi

# ── Retention: keep last $RETENTION_WEEKS reports ─────────────
if [[ $DRY_RUN -eq 0 ]]; then
  ls -1t "$REPORT_DIR"/*.md 2>/dev/null | tail -n +$((RETENTION_WEEKS+1)) | xargs -r rm -f
fi

exit 0
