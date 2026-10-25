# Dell Server Current Status

Latest live maintenance verification: **2026-10-25, 11:35 UTC / 17:05 IST**, over LAN SSH.
See [the October 25 maintenance report](MAINTENANCE-2026-10-25.md).

- The Oct 23 Google Drive copy completed and verified. A controlled reboot cleared all stale
  libraries; no restart or kernel reboot is pending.
- **New secondary storage:** the 500 GB HDD is mounted at `/mnt/hdd`. It holds a nightly backup
  mirror (05:15 UTC), verified cold archives, and the AWS account backup.
- **SSD went from 86% to 55% used (97 GiB free).** HDD: 23% used, 361 GB free.
- 33 containers healthy. SMART passed on both disks; smartd is monitoring them.
- **Lost in the reboot:** three ephemeral MOC test DBs.
- **Netdata turned out not to be deployed.**

Open work: [Pending Tasks in CLAUDE.md](../CLAUDE.md#pending-tasks-as-of-2026-10-25).

**The October 23 summary below is the previous snapshot.**

Previous live maintenance verification: **2026-10-23, 17:26 UTC / 22:56 IST**, over LAN SSH.
See [the October 23 maintenance report](MAINTENANCE-2026-10-23.md). Eleven eligible
package updates were installed; only Ubuntu's phased cloud-init update remains.
All 32 regular production containers are healthy. Approximately 4.04 GB was reclaimed;
root disk is 85% full with about 33 GiB free. The running kernel is `6.8.0-147-generic`.

The Google Drive backup's self-copying-log defect was corrected and its existing job
restarted, but remote copy/verification is still pending. Its reboot inhibitor remains
active. Some long-running host processes still need restarts to load updated libraries.
MOC graph health remains critical (51 exhausted jobs, 462 orphan findings). The additional
running and stopped MOC test databases and validation evidence were preserved.

The Mac's current Tailscale network differs from the Dell's; both clients are online,
but the Dell is absent from the Mac's peer list. LAN SSH works normally.

**The September and August records below are historical snapshots.**

Previous live update verification: **2026-09-15, 15:39 UTC / 21:09 IST**.
See [the September 15 OS update report](OS-UPDATE-2026-09-15.md) and
[maintenance report](MAINTENANCE-2026-09-15.md). All 83 pending APT updates are installed,
the host is running kernel `6.8.0-139-generic`, and no reboot is pending. Root disk is 52%
full, Docker build cache is empty, and all 32 production containers are healthy. The
existing MOC graph/data-quality warnings remain outstanding.

**The detailed August 21 snapshot below is historical, not a current health reading.**

Last verified: 2026-08-21 over Tailscale SSH after the n8n/Quip retirement, Docker-cache cleanup,
Domain Hunter restoration, and the always-on acquisition-research upgrade.

This is a sanitized operator snapshot. It intentionally contains no passwords, tokens, `.env`
values, database dumps, or recovery secrets. If a handoff paste includes a password, keep it out of
this repo and rotate it if it may have landed in chat logs or shared artifacts.

## Source Of Truth

- Durable server guide: `CLAUDE.md`
- Incident runbook: `SOS-RUNBOOK.md`
- Live snapshot command: `ssh pronav@100.103.66.92 'bash ~/bin/dell-status.sh'`
- MOC deployed source marker: `/home/pronav/docker/moc/.deployed-source-head`

Do not infer the running MOC revision from GitHub `main` alone. Read the deployed-source marker on
the server.

## Host

| Item | Current value |
|------|---------------|
| Hostname | `prsnl` |
| OS | Ubuntu Server 24.04 LTS |
| Kernel | `6.8.0-147-generic` (2026-10-25) |
| Storage | SSD `/` (240 GB Kingston), HDD `/mnt/hdd` (500 GB Toshiba, NTFS; cold/backup copy only) |
| LAN IP | `192.168.1.18/24` on `wlp6s0` |
| Active WiFi | `Airtel_renu_1470`; `Airtel_renu_8079` retained as a recovery AP |
| Tailscale IP | `100.103.66.92` |
| SSH | `ssh pronav@100.103.66.92` |
| Docker | `29.7.2` |
| Docker Compose | `v5.5.0` |
| Node.js | `v24.19.0` |
| cloudflared | `2026.3.0` |

Live resource snapshot:

| Metric | Value |
|--------|-------|
| Uptime | 23 hours |
| Load average | `1.60 3.18 3.68` after the fifth live Domain Hunter inventory cycle |
| Memory | `3.5Gi used / 7.7Gi total`, `4.1Gi available` |
| Disk `/` | `105G used / 218G total`, `51% full`, `102G free` |

Maintenance on 2026-08-20 retired n8n/Quip and pruned `59.38GB` of BuildKit cache. Domain Hunter
was then restored from the verified pre-removal archive after it had been removed in error. The
restore recreated its 11 containers, database/Redis volumes, application images, and 2.1GB runner
workspace. The rebuild left `642.6MB` of cache, only about `700KB` reclaimable. Check `df -h /`
and `docker system df` before large image pulls.

On 2026-08-21, Domain Hunter was upgraded in place to an eight-container default stack. The dead
scheduler and the default A2, classifier, and registrar containers were removed; A2/classifier and
registrar code remain available only through explicit Compose profiles. The project, database,
evidence history, backup timer, API, and Vulture bot were retained. Validated authority and market
reference files add about `124MB`; current BuildKit cache is about `1.4GB` with only a few megabytes
reclaimable.

The 2026-08-01 cold boot completed the pending maintenance reboot. `/var/run/reboot-required` is
absent. Do not restart the network stack casually over SSH.

## Access And Recovery

| Path | Status |
|------|--------|
| `pronav` SSH over Tailscale | Verified working |
| `pronav` sudo | Passwordless |
| `breakglass` fallback | Local sudo user; use only for access recovery |
| Tailscale SSH | Intentionally disabled; keep normal OpenSSH working |
| Tailscale health | LAN/Tailscale SSH, public DNS, and MagicDNS work; `tailscale status` still reports a configured-DNS health warning |
| Live recovery note | `/home/pronav/server-recovery/PRSNL_RECOVERY.md` |
| Retirement bundle | `/home/pronav/server-recovery/retired/20260820T160354Z/`; checksum-verified, mode `0700` |

Keep the `breakglass` password outside this repo. The live recovery note and password manager are
the places for recovery credentials.

### 2026-08-01 WiFi and DNS recovery

- The server had been powered off and its only saved AP was the former SSID
  `Airtel_renu_8079`. Temporarily broadcasting that exact SSID and PSK on the router's normal
  `192.168.1.0/24` LAN restored SSH at `192.168.1.18`; an isolated guest/VLAN SSID would not have
  worked with the server's static address and gateway.
- `/etc/netplan/01-network.yaml` now contains both `Airtel_renu_8079` and the current
  `Airtel_renu_1470` AP. `netplan generate` and `netplan apply` passed, and `wpa_cli` confirmed
  `Airtel_renu_1470`, WPA2-PSK, `COMPLETED`, and `192.168.1.18`.
- The pre-change Netplan file is root-only at
  `/etc/netplan/01-network.yaml.pre-wifi-recovery-20260801`. No WiFi PSK is stored in this repo.
- Host DNS initially failed because Tailscale had replaced `/etc/resolv.conf` while
  `systemd-resolved` was disabled. `systemd-resolved` is now enabled, `/etc/resolv.conf` points to
  `/run/systemd/resolve/stub-resolv.conf`, and `tailscaled` was restarted. Public DNS, MagicDNS,
  Internet access, Tailscale SSH, the production URL, and the container health check all passed.
  The previous resolver file is root-only at `/etc/resolv.conf.pre-dns-recovery-20260801`.

## Public And Admin URLs

| Service | URL | Exposure |
|---------|-----|----------|
| Production app | `https://moc.prsnl.fyi` | Public via Cloudflare Tunnel, auth-gated |
| Landing site | `https://prsnl.fyi` | Public via Cloudflare Tunnel |
| Portainer | `https://100.103.66.92:9443` | Tailscale-only bind |
| Uptime Kuma | `http://100.103.66.92:3001` | Tailscale-only bind |
| Dozzle | `http://100.103.66.92:9999` | Tailscale-only bind |
| Phoenix | `http://100.103.66.92:6006` | Tailscale-only bind |
| pgweb | `http://100.103.66.92:8081` | Tailscale-only bind |
| Pranav Desk OS display | `http://192.168.1.18:8791` | Home-LAN bind |
| Pranav Desk OS admin | `http://100.103.66.92:8792/manage` | Tailscale-only bind |
| prsnl Ops Deck | `http://100.103.66.92:8787` | Tailscale-only bind |
| ntfy | `http://100.103.66.92:8788` | Tailscale-only bind |

`https://moc.prsnl.fyi/` and `https://prsnl.fyi/` returned HTTP `200`; `n8n.prsnl.fyi` returned
the intended parked HTTP `404` after retirement. `xd.prsnl.fyi` remains parked at HTTP `404`
because the old Domain Hunter web dashboard was already removed; the active service uses Vulture
and a localhost-only API.

## Current Port Binds

Public or Tailscale-facing listeners:

| Bind | Service |
|------|---------|
| `0.0.0.0:22`, `[::]:22` | OpenSSH |
| `100.103.66.92:1883` | Ops Deck Mosquitto |
| `100.103.66.92:3001` | Uptime Kuma |
| `100.103.66.92:4111`, `100.103.66.92:4112` | `moc-mastra-ops-server` |
| `100.103.66.92:6006` | Phoenix |
| `100.103.66.92:8000` | Portainer edge |
| `100.103.66.92:8081` | pgweb |
| `100.103.66.92:8787` | prsnl Ops Deck |
| `100.103.66.92:8788` | ntfy |
| `100.103.66.92:8792` | Pranav Desk OS admin/editor |
| `100.103.66.92:9443` | Portainer |
| `100.103.66.92:9999` | Dozzle |
| `192.168.1.18:8791` | Pranav Desk OS iPad display/device API |

Localhost-only listeners:

| Bind | Service |
|------|---------|
| `127.0.0.1:3000` | MOC backend |
| `127.0.0.1:5173` | MOC frontend origin |
| `127.0.0.1:5436` | Domain Hunter PostgreSQL |
| `127.0.0.1:6381` | Domain Hunter Redis |
| `127.0.0.1:8004` | MOC embedding |
| `127.0.0.1:8005` | MOC voice service |
| `127.0.0.1:8006` | MOC graph consolidator |
| `127.0.0.1:8007` | Domain Hunter API |
| `127.0.0.1:8088` | prsnl landing origin |
| `127.0.0.1:8011` | MOC Sherpa STT |
| `127.0.0.1:8012` | MOC Sherpa TTS |

Correction from older handoffs: MOC embedding and MOC graph consolidator are currently
`127.0.0.1`-bound, not `0.0.0.0`-bound.

## Firewall

`ufw` is active.

| Rule | Scope |
|------|-------|
| `22` | Anywhere, key-only SSH with fail2ban |
| `19999` | `100.64.0.0/10`, Netdata over Tailscale |
| `9443` | `100.64.0.0/10`, Portainer over Tailscale |
| `9999` | `100.64.0.0/10`, Dozzle over Tailscale |
| `3001` | `100.64.0.0/10`, Uptime Kuma over Tailscale |
| `8787`, `8788`, `1883` on `tailscale0` | Ops Deck, ntfy, and MQTT over Tailscale |
| `7880`, `7881`, `50000:50100/udp` on `tailscale0` | MOC LiveKit signaling/media |
| `6006/tcp` from `172.19.0.0/16` | MOC OTLP export to Phoenix |

Docker-published ports can bypass UFW when bound broadly. Keep admin and internal services bound to
`100.103.66.92` or `127.0.0.1`, as listed above.

Pranav Desk OS was deployed on 2026-08-01 under `/home/pronav/docker/deskos`. Its two containers are intentionally split: the LAN listener on `192.168.1.18:8791` exposes only the display/device surface, and the Tailscale listener on `100.103.66.92:8792` exposes `/manage`, admin routes, and the separately authenticated Work Pulse ingest route. `POST /api/v1/work/events` accepts only sanitized lifecycle state and is intentionally 404 on the LAN display listener. Claude/Codex hooks send a nonblocking local datagram to an off-path macOS relay, which then authenticates over Tailscale; no transcript or prompt data is accepted. Port `8790` was freed when the Quip bridge was retired.

DNS note: during 2026-06-29 maintenance, Docker daemon DNS was pinned in `/etc/docker/daemon.json`
to public resolvers (`1.1.1.1`, `8.8.8.8`) to prevent stale Tailscale DNS inheritance. Recreated
app/worker/proxy containers confirmed Docker's internal resolver forwarding to those upstreams.
Older DB/Redis containers may still show stale DNS comments until their next recreate, but they do
not need external DNS and were intentionally left running.

## Running Containers

Core infra:

| Container | Status |
|-----------|--------|
| `portainer` | healthy |
| `uptime-kuma` | healthy |
| `dozzle` | healthy |
| `watchtower` | healthy |
| `autoheal` | healthy |
| `pgweb` | healthy |
| `phoenix` | healthy |

MOC:

| Container | Status |
|-----------|--------|
| `moc-server` | healthy |
| `moc-worker` | healthy |
| `moc-web` | healthy |
| `moc-db` | healthy |
| `moc-embedding` | healthy |
| `moc-graph-consolidator` | healthy |
| `moc-mastra-ops-server` | healthy |
| `moc-voice` | healthy |
| `moc-sherpa-stt` | healthy |
| `moc-sherpa-tts` | healthy |
| `moc-livekit` | healthy |

Domain Hunter:

| Container | Status |
|-----------|--------|
| `dh-api` | healthy, zero restarts |
| `dh-pg` | healthy, zero restarts |
| `dh-redis` | healthy, zero restarts |
| `dh-worker-inventory` | healthy, zero restarts |
| `dh-worker-rdap` | healthy, zero restarts |
| `dh-worker-scoring` | healthy, zero restarts |
| `dh-worker-wayback` | healthy, zero restarts |
| `vulture` | healthy, zero restarts |

Pranav Desk OS:

| Container | Status |
|-----------|--------|
| `pranav-desk-os-display` | healthy |
| `pranav-desk-os-admin` | healthy |

Ops Deck:

| Container | Status |
|-----------|--------|
| `prsnl-ops-deck` | healthy |
| `prsnl-ntfy` | healthy |
| `prsnl-mosquitto` | healthy |

n8n and Quip have no running or stopped containers. The `n8n-net` network remains because Phoenix
still uses it.

## Domain Hunter Restoration And Always-On Upgrade

- Server path: `/home/pronav/docker/domain-hunter`; deployed revision `b439969fe923` on `main`.
- Alembic is at `0005_inventory_pipeline (head)`. The default runtime is the API, Postgres, Redis,
  Vulture, and inventory/RDAP/Wayback/scoring workers.
- The first five live six-hour cycles each read `680,453` pending-delete rows, prefiltered `342,421`
  clean `.com` names, persisted `207` authority matches, and completed all `150` bounded public
  detail checks with zero source/detail failures.
- Automatic review produced `3` research, `192` observe, and `12` reject verdicts. Manual
  rights/history review closed all three research hits, so the live actionable queue and digest are
  correctly empty; audit mode retains the evidence and decisions.
- `/api/pipeline/status` reports `automated_purchase_enabled=false` and
  `human_approval_required=true`. No marketplace write credentials or buy/bid operation exists.
- Failed Wayback transport/schema requests now remain pending instead of being stored as false
  zero-capture evidence. The live worker is bounded to `20` domains per batch at one request per
  second. After the safety deployment, `98` ambiguous zero-capture rows from the affected window
  were removed for retry while all `62` existing positive snapshots were retained. The first
  bounded retry attempted `20`: five genuine positive histories were saved, `15` upstream failures
  wrote nothing, and the pending-review backlog moved from `145` to `140`.
- `dh-pg-backup.timer` remains enabled and active. The final deployment created and verified
  `/var/backups/dh/dh-2026-08-20-1908.pgdump` before reconciliation.
- GitHub Actions runner `dh-dell` is online, idle, and has labels
  `self-hosted,Linux,X64,dh-dell` for `PranavSlathia/XD`.
- Vulture slash commands are connected. `DH_DISCORD_CHANNEL_ID` is not configured, so automatic
  daily channel posting is disabled without affecting discovery.
- Original recovery point remains checksum-verified at
  `/home/pronav/server-recovery/retired/20260820T160354Z/`.

## MOC Runtime

| Item | Current value |
|------|---------------|
| Server path | `/home/pronav/docker/moc` |
| Branch | `main` |
| Repository HEAD | `91c332bf` |
| Deployed marker | `91c332bf` |
| Dirty files | None reported |
| Graph backend | Postgres graph projection |
| Last consolidation | `2026-08-17 04:49:50.645476+00` |
| Graphile jobs | `pending=0`, `running=0`, `dead=0`; `retryExhausted=38` in background jobs |
| Quarantine | `unreviewed=19`, `total=44` |
| Graph health | Reachable, but operational status `critical` from 38 exhausted jobs and 546 orphan findings; untouched during retirement |

FalkorDB is retired from MOC's runtime path. Do not use the Mac Mini FalkorDB note from older
handoffs as the current graph-store design.

## Image Size Notes

Largest relevant images as of 2026-08-20:

| Image | Size | Main size driver |
|-------|------|------------------|
| `moc-worker` / `moc-server` | `1.68GB` each | shared application runtime layers |
| `moc-embedding` | `1.25GB` | embedding runtime/model dependencies |
| `moc-voice` | `1.23GB` | voice runtime dependencies |
| `moc-graph-consolidator` | `1.19GB` | graph projection runtime |
| `arizephoenix/phoenix` | `961MB` | MOC trace observability; seven-day retention enabled |
| Domain Hunter active application images | `767MB` each | six active tags share most layers; old opt-in/retired tags are not running |

## Useful Diagnostics

```bash
# Full live status
ssh pronav@100.103.66.92 'bash ~/bin/dell-status.sh'

# Port and exposure audit
ssh pronav@100.103.66.92 'sudo ufw status numbered'
ssh pronav@100.103.66.92 'sudo ss -tulpen | awk '\''NR==1 || /docker-proxy|:22|:80|:443|:9090/ {print}'\'''

# MOC runtime source and health
ssh pronav@100.103.66.92 'cd ~/docker/moc && cat .deployed-source-head && git status --short'
ssh pronav@100.103.66.92 'curl -s localhost:3000/api/health/graph | jq .'

# Local browser access to private origins
ssh -L 3000:localhost:3000 -L 5173:localhost:5173 pronav@100.103.66.92
```
