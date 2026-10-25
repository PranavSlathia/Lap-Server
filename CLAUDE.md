# Dell Home Server (prsnl) — Management Guide

This repo manages the Dell Vostro laptop converted into an Ubuntu home server on 2026-04-06.

For incidents and recovery work, start with `SOS-RUNBOOK.md`.

## Secondary HDD storage — 2026-10-25

A second disk (500 GB Toshiba HDD, NTFS) is mounted at **`/mnt/hdd`** for **cold storage and a second
copy of backups only**. Never use it for live databases. `/mnt/hdd/Pictures` holds personal photos:
never touch them. Details are under Hardware → "Secondary HDD". Open work is in **Pending Tasks** at
the end of this file. Maintenance record: `docs/MAINTENANCE-2026-10-25.md`.

## Retirement and restoration snapshot — 2026-08-20

- **n8n and Quip are retired.** Their containers, active data volumes, unused images, n8n working
  directory, and obsolete firewall rules were removed. The disabled/inactive 56MB `quip-agents`
  source directory remains as low-cost recovery material. Do not redeploy them without an explicit
  restore decision.
- **Domain Hunter is active and protected.** It was restored from the verified pre-removal
  configuration and PostgreSQL archive on 2026-08-20 after an erroneous removal, then upgraded on
  2026-08-21 to an eight-container always-on acquisition-research stack. The project, database,
  backup timer, Vulture bot, and `dh-dell` runner remain; only the dead scheduler and three old
  default/opt-in worker containers were removed.
- `n8n.prsnl.fyi` is parked at `http_status:404`. `xd.prsnl.fyi` remains parked because the old
  Domain Hunter web dashboard had already been removed; Domain Hunter operates through Vulture and
  its localhost API.
- Recovery material is checksum-verified and stored outside this repo at
  `/home/pronav/server-recovery/retired/20260820T160354Z/` (mode `0700`; files mode `0600`).
- Phoenix remains active for MOC observability. Its `default` project has a seven-day trace
  retention policy scheduled daily at `01:00 UTC`.

## Quick Access

```bash
# SSH (local network)
ssh pronav@192.168.1.18

# SSH (anywhere via Tailscale)
ssh pronav@100.103.66.92

# User: pronav | Passwordless sudo | SSH key auth from Mac Mini
```

`breakglass` is a local sudo fallback user (uid 1002, `sudo` group; sudo is **password-required**
per `scripts/access-hardening.sh` — no NOPASSWD) carrying the same Mac Mini SSH public key. Use it
only for access recovery; its password lives in a **password manager** (the durable copy) and is
also recorded in the on-server recovery note (`PRSNL_RECOVERY.md`) for convenience — never in this
repo. Note: `access-hardening.sh` rewrites the recovery note *without* the password, so the
password-manager copy is the one that survives a re-run. **Provisioned & SSH-verified 2026-06-17**
(`ssh breakglass@100.103.66.92`) — prior
to that the account was documented but did not actually exist on the box. Tailscale SSH is intentionally disabled
(`tailscale debug prefs` → `"RunSSH": false`) because it can add browser approval to
`ssh pronav@100.103.66.92` and interrupt deploy agents; normal OpenSSH over the Tailscale IP is what
deploy agents use.

> ⚠️ **Single-key fragility (as of 2026-06-17):** only **one** key is in `pronav`'s (and
> `breakglass`'s) `authorized_keys` — the Mac Mini ed25519 (`pronav@Pranavs-Mac-mini.local`). Both
> remote paths therefore depend on the **Mac Mini being available**. If it is off/unreachable, the
> only way in is the physical console + password (the trap that caused the 2026-06-17 lockout).
> Fix: add the MacBook Air and iPhone public keys to `~/.ssh/authorized_keys` so more than one
> device can reach the box.

Live recovery note on the server: `/home/pronav/server-recovery/PRSNL_RECOVERY.md`.

## Web Dashboards

| Service | Local URL | Tailscale URL | Access | Purpose |
|---------|-----------|---------------|--------|---------|
| Portainer | SSH tunnel only | https://100.103.66.92:9443 | Tailscale only | Docker management UI |
| Uptime Kuma | SSH tunnel only | http://100.103.66.92:3001 | Tailscale only | Uptime monitoring |
| Dozzle | SSH tunnel only | http://100.103.66.92:9999 | Tailscale only | Live Docker log viewer |
| Netdata | — | ~~http://100.103.66.92:19999~~ | — | **Not deployed** as of 2026-10-25 (see Pending Tasks) |
| Phoenix | SSH tunnel only | http://100.103.66.92:6006 | Tailscale only | MOC LLM-trace observability |

---

## Port Registry

**IMPORTANT: Check this table before assigning ports to new projects. No duplicates.**

### Infrastructure Ports (reserved)

| Port | Service | Container | Access | Notes |
|------|---------|-----------|--------|-------|
| 22 | SSH | host | Public | Key-only auth, password disabled |
| 80 | HTTP | host | Public | Reserved for Cloudflare |
| 443 | HTTPS | host | Public | Reserved for Cloudflare |
| 3001 | Uptime Kuma | uptime-kuma | Tailscale only | Bound to `100.103.66.92` |
| 5001 | Dockge | dockge | Tailscale only | Bound to `100.103.66.92` |
| 8000 | Portainer edge | portainer | Tailscale only | Bound to `100.103.66.92` |
| 8080 | Watchtower | watchtower | Internal | Health check only |
| 8081 | pgweb | pgweb | Tailscale only | Bound to `100.103.66.92` |
| 9443 | Portainer | portainer | Tailscale only | Bound to `100.103.66.92` |
| 9999 | Dozzle | dozzle | Tailscale only | Bound to `100.103.66.92` |
| 19999 | Netdata | — | — | Not deployed as of 2026-10-25; port reserved pending decision |

> **Gotcha:** a Docker `ports: "X:X"` publish binds `0.0.0.0` and **bypasses UFW** (DOCKER iptables
> chain), so "UFW doesn't allow it" ≠ "not exposed" — it's LAN-reachable. Always bind admin UIs to
> `100.103.66.92:` or `127.0.0.1:` explicitly. (Phoenix made this mistake; fixed 2026-06-11.)

### Project Ports

| Port | Project | Service | Container | Access | Compose File |
|------|---------|---------|-----------|--------|-------------|
| 3000 | MindOverChatter | Hono backend API | moc-server | Localhost only | ~/docker/moc/docker-compose.prod.yml |
| 4111-4112 | MindOverChatter | Mastra ops server | moc-mastra-ops-server | Tailscale only (`100.103.66.92`; both host ports map to container `4111`) | ~/docker/moc/docker-compose.prod.override.yml |
| 5173 | MindOverChatter | React frontend (nginx) | moc-web | Public (via tunnel) | ~/docker/moc/docker-compose.prod.yml |
| 5433 | MindOverChatter | PostgreSQL + pgvector | moc-db | Internal only | ~/docker/moc/docker-compose.prod.yml |
| 5436 | Domain Hunter | PostgreSQL + pgvector | dh-pg | Localhost only | ~/docker/domain-hunter/compose.yml |
| 6381 | Domain Hunter | Redis | dh-redis | Localhost only | ~/docker/domain-hunter/compose.yml |
| 8004 | MindOverChatter | Embedding service | moc-embedding | Localhost only | ~/docker/moc/docker-compose.prod.yml |
| 8006 | MindOverChatter | Graph consolidator | moc-graph-consolidator | Localhost only | ~/docker/moc/docker-compose.prod.yml |
| 8007 | Domain Hunter | FastAPI API | dh-api | Localhost only | ~/docker/domain-hunter/compose.yml |
| 8088 | prsnl-landing | nginx static | prsnl-landing | Public (via tunnel) | ~/docker/landing/ |
| 6006 | MOC observability | Phoenix LLM-trace UI + OTLP | phoenix | Tailscale only (`100.103.66.92`) | ~/docker/phoenix/docker-compose.yml |
| 1883 | prsnl Ops Deck | MQTT broker | prsnl-mosquitto | Tailscale only (`100.103.66.92`) | ~/docker/prsnl-ops-deck/deploy/docker-compose.yml |
| 8787 | prsnl Ops Deck | Operations dashboard | prsnl-ops-deck | Tailscale only (`100.103.66.92`) | ~/docker/prsnl-ops-deck/deploy/docker-compose.yml |
| 8788 | prsnl Ops Deck | ntfy notifications | prsnl-ntfy | Tailscale only (`100.103.66.92`) | ~/docker/prsnl-ops-deck/deploy/docker-compose.yml |
| 8791 | Pranav Desk OS | iPad display shell + device API | pranav-desk-os-display | Home LAN only (`192.168.1.18`) | ~/docker/deskos/docker-compose.yml |
| 8792 | Pranav Desk OS | `/manage` editor + admin API | pranav-desk-os-admin | Tailscale only (`100.103.66.92`) | ~/docker/deskos/docker-compose.yml |

**Graph store note:** FalkorDB is **deprecated** — MOC's knowledge graph was cut over to
**Postgres** (`moc-db`, graph projection owned by `moc-graph-consolidator`;
`GRAPH_PROJECTION_BACKEND=postgres`, verified via `/health` → `"graphBackend":"postgres"`).
The old `moc-falkordb-1` container (6380) and the Mac Mini FalkorDB (`100.111.147.100:6379`)
are no longer in MOC's runtime path. Cutover tooling: `services/graph-consolidator/scripts/falkor_postgres_cutover.py`.

**Workers / internal-only (no host ports):**
`dh-worker-{inventory,rdap,wayback,scoring}`, `vulture`, `moc-worker`, and MOC's internal
voice/LiveKit components. Domain Hunter A2/classifier and registrar workers exist only in explicit
profiles; the scheduler is retired. The n8n and Quip workers were removed on 2026-08-20.

### Available Port Ranges for New Projects

| Range | Suggested Use |
|-------|--------------|
| 3100-3199 | Web backends |
| 4000-4999 | APIs |
| 5174-5435 | Frontends |
| 5437-5499 | Databases (5436 is Domain Hunter PostgreSQL) |
| 6000-6379 | Misc services (6006 taken: Phoenix) |
| 6382-6999 | Misc services (6381 is Domain Hunter Redis) |
| 7000-7999 | Misc services |
| 8012-8087 | Python/ML services |
| 8090-8786 | Python/ML services (8787-8788 taken by Ops Deck) |
| 8789-8790, 8793-8999 | Python/ML services (8791-8792 Desk OS) |

---

## Deployed Projects

### Pranav Desk OS

**Deployed:** 2026-08-01

**Server path:** `~/docker/deskos/`

**Display:** `http://192.168.1.18:8791`
**Admin:** `http://100.103.66.92:8792/manage`

| Container | Port | Status | Notes |
|-----------|------|--------|-------|
| pranav-desk-os-display | `192.168.1.18:8791` | Running (healthy) | ES5 iPad shell and paired-device API; no admin routes |
| pranav-desk-os-admin | `100.103.66.92:8792` | Running (healthy) | Tailscale-only editor/admin API; no device routes |

The root filesystems are read-only, containers run as UID/GID `1000:1000` with all capabilities dropped, and the Docker socket is not mounted. `deskos-collector.service` writes an atomic allowlisted host snapshot every 15 seconds; `deskos-backup.timer` makes daily SQLite online backups with 14-day retention. The admin listener also owns `POST /api/v1/work/events`, authenticated by a dedicated hash-only Work Pulse token; the display listener returns 404 for that route. A fail-open macOS lifecycle-hook relay sends only allowlisted Claude/Codex state over Tailscale, never prompts or transcripts. Port `8790` was freed when the Quip bridge was retired.

### prsnl Ops Deck

**Server path:** `~/docker/prsnl-ops-deck/deploy/`
**Dashboard:** `http://100.103.66.92:8787` (Tailscale only)

| Container | Port | Status | Purpose |
|-----------|------|--------|---------|
| `prsnl-ops-deck` | `100.103.66.92:8787` | Running (healthy) | Private operations dashboard |
| `prsnl-ntfy` | `100.103.66.92:8788` | Running (healthy) | Private notification rail |
| `prsnl-mosquitto` | `100.103.66.92:1883` | Running (healthy) | Private MQTT broker |

All three listeners are bound to the Tailscale address and allowed only on `tailscale0` by UFW.

### 0. prsnl-landing

**Public URL:** https://prsnl.fyi · https://www.prsnl.fyi
**Server path:** ~/docker/landing/
**Container:** `prsnl-landing` (nginx:alpine, port 8088 → tunnel)
Static marketing/landing page. No DB, no backend.
Also serves **https://prsnl.fyi/deck** (MOC "how we use AI" company deck, added 2026-06-05) —
drop `NAME.html` into `~/docker/landing/dist/` and nginx `try_files $uri.html` serves it at `/NAME`.

---

### 1. MindOverChatter (MOC)

**Public URL:** https://moc.prsnl.fyi
**Deployed:** 2026-04-06
**Repo:** github.com/PranavSlathia/MindOverChatter
**Server path:** ~/docker/moc/
**Compose:** ~/docker/moc/docker-compose.prod.yml

| Container | Image | Port | Status | Notes |
|-----------|-------|------|--------|-------|
| moc-web | nginx:alpine | 5173 | Running | React SPA + reverse proxy |
| moc-server | moc-server (custom) | 3000 | Running (healthy) | Hono backend |
| moc-db | pgvector/pgvector:pg16 | 5433 | Running (healthy) | PostgreSQL + pgvector — also the **graph store** (FalkorDB deprecated) |
| moc-embedding | moc-embedding (custom) | 8004 | Running (healthy) | Embedding service; image is ~5.31GB, mostly Python/ML deps |
| moc-worker | moc-worker (custom) | (internal) | Running (healthy) | Background work; shares ~3.88GB server/worker image |
| moc-graph-consolidator | moc-graph-consolidator | 8006 | Running (healthy) | Owns Postgres graph projection writes (`graphBackend: postgres`) |
| moc-mastra-ops-server | moc-mastra-ops:local | 4111, 4112 | Running (healthy) | Tailscale-only ops server; override compose maps both host ports to container `4111` |

**Cloudflare Tunnel:**
- Tunnel ID: `7959ea52-7f58-4657-b933-f785af2c87ad`
- Domain: `moc.prsnl.fyi` → localhost:5173 (nginx proxies /api/* to backend)
- Config: `/etc/cloudflared/config.yml`
- Runs as: systemd service (`cloudflared.service`)

**Architecture:**
```
Browser → https://moc.prsnl.fyi
  → Cloudflare Tunnel → nginx (port 5173)
    → /           → React SPA (static files)
    → /api/*      → proxy to moc-server:3000
    → /health     → proxy to moc-server:3000
```

**Database:**
- PostgreSQL 16 + pgvector extension
- 25 tables, ~3MB data
- Image pinned by SHA256 digest (Watchtower won't auto-update)
- Daily backup: `moc-backup.timer` runs `~/bin/moc-backup-restic.sh`
- Restic backup freshness is checked by weekly maintenance via `moc-backup.service`

**AI Integration:**
- Claude Code CLI (v2.1.92 on host; container version may lag — check `docker exec moc-server claude --version`)
- Auth: `CLAUDE_CODE_OAUTH_TOKEN` env var (valid 1 year, expires ~April 2027)
- Token set in docker-compose.prod.yml server service environment

**Environment file:** `~/docker/moc/.env` (chmod 600)
- DB_PASSWORD, GROQ_API_KEY, CORS_ORIGINS, CLAUDE_MODEL, etc.

**To redeploy after code changes:**
```bash
# On the server
cd ~/docker/moc
git pull
docker compose -f docker-compose.prod.yml build server embedding worker graph-consolidator
docker compose -f docker-compose.prod.yml up -d

# For frontend changes (build locally, transfer dist):
# On Mac:
VITE_API_URL="https://moc.prsnl.fyi" pnpm --filter @moc/web build
tar -czf /tmp/moc-web-dist.tar.gz -C apps/web/dist .
scp /tmp/moc-web-dist.tar.gz pronav@192.168.1.18:/tmp/
# On server:
sudo rm -rf /tmp/moc-web-dist/*
cd /tmp/moc-web-dist && tar xzf /tmp/moc-web-dist.tar.gz
sudo docker restart moc-web
```

---

### 2. Domain Hunter (XD)

**Active, restored 2026-08-20, and upgraded 2026-08-21.** The server checkout and PostgreSQL state
were restored from the checksum-verified pre-removal archive. The eight-container default stack is
healthy, `dh-pg-backup.timer` is active, and the `dh-dell` GitHub Actions runner is online. The
sealed archive remains available as a recovery point. Never retire or remove this project without
an explicit new instruction from Pranav.

**Public URL:** none — `xd.prsnl.fyi` is parked (`http_status:404` in the tunnel; the `dh-web`
dashboard container was removed). Operated via **Vulture** (Discord bot, `vulture` container) +
Tailscale/`dh-api`. Vulture slash commands work; automatic daily channel posting is currently off
because `DH_DISCORD_CHANNEL_ID` is not configured.
**Deployed:** 2026-05-14
**Repo:** github.com/PranavSlathia/XD
**Server path:** ~/docker/domain-hunter/
**Compose:** ~/docker/domain-hunter/compose.yml (default plus `experimental` and
`hand-registration` opt-in profiles)
**Deploy mode:** Self-hosted GitHub Actions runner on the Dell
(`actions.runner.PranavSlathia-XD.dh-dell`). Relevant pushes to `main` run unit and real-Postgres
tests, create a database backup, migrate, rebuild, and reconcile the default stack.

Self-hosted, evidence-first expiring-domain research pipeline. Every six hours it narrows the
public DropCatch five-day pending-delete feed through cached OpenPageRank authority, conservative
NameBio retail-demand evidence, acquisition details, anomaly gates, RDAP, and Wayback. Output is
`research`, `observe`, or `reject`; it never buys, bids, backorders, lists, or spends.

| Container | Image | Port | Status |
|-----------|-------|------|--------|
| dh-api | domain-hunter-dh-api | 8007 | FastAPI HTTP API |
| dh-worker-inventory | domain-hunter-dh-worker-inventory | — | Six-hour pending-delete discovery and evidence scoring |
| dh-worker-rdap | domain-hunter-dh-worker-rdap | — | Authoritative registration/lifecycle confirmation |
| dh-worker-wayback | domain-hunter-dh-worker-wayback | — | Bounded archive-history enrichment |
| dh-worker-scoring | domain-hunter-dh-worker-scoring | — | Composite scoring v3 |
| vulture | (custom) | — | Discord operator bot (`Vulture#1112`, slash commands) |
| dh-pg | pgvector/pgvector:pg16 | 5436 | Postgres + pgvector |
| dh-redis | redis:7-alpine | 6381 | Isolated Redis state |

(`dh-web` operator dashboard: **removed**.)

**Env file:** `~/docker/domain-hunter/.env` (chmod 600) — see the repo README. The default inventory
path needs no marketplace credential. Downloaded reference data lives under `/var/data/dh/reference`.

**External integrations wired:** DropCatch public downloads/details, OpenPageRank public Top-10M,
NameBio RetailStats (attribution required), ICANN RDAP, Wayback CDX, and Vulture. The new
OpenPageRank API key and hand-registration profile are optional.
⚠️ GlitchTip was **retired** (see §3) — if `DH_SENTRY_DSN` is still set in `.env`, DH error
events go nowhere; unset it or point at a live sink.

---

### 3. GlitchTip (self-hosted error tracking) — ⚪ RETIRED

**Status (2026-06-11 audit):** all four containers (gt-web, gt-worker, gt-pg, gt-redis) are
**gone** — neither running nor stopped. Port 8011 is free again. Compose/env files may remain at
`~/docker/domain-hunter/glitchtip-compose.yml` / `.glitchtip.env` for a future revival.
Anything still pointing a Sentry DSN at it (e.g. `DH_SENTRY_DSN`) is shipping events to nowhere.

---

### 4. n8n (workflow automation) — ⚪ RETIRED 2026-08-20

**Historical section only.** All 17 workflows were inactive and there had been no executions in
the preceding week. The four-container stack, images, data volumes, server directory, and public
gate were removed after a verified `pg_dump` plus configuration archive. `n8n.prsnl.fyi` now
returns 404.

**Access:** Tailscale at http://100.103.66.92:5678; also public at https://n8n.prsnl.fyi behind a Caddy HTTP Basic-Auth gate (`quip-n8n-gate`, 127.0.0.1:8090). Cloudflare Access was the intended gate but Zero Trust requires a card; the Caddy basic-auth proxy is the card-free perimeter. n8n's own owner login sits behind it.
**Deployed:** 2026-06-01
**Server path:** ~/docker/n8n/docker-compose.yml
**Architecture doc:** docs/N8N-ARCHITECTURE.md
**Env file:** ~/docker/n8n/.env (chmod 600) — `N8N_ENCRYPTION_KEY` (never lose/rotate — encrypts all stored credentials), `N8N_DB_PASSWORD`, `N8N_RUNNERS_AUTH_TOKEN`

| Container | Image | Port | Status |
|-----------|-------|------|--------|
| n8n | n8nio/n8n:2.22.6 (pinned) | 5678 | Editor + webhook/execution engine |
| n8n-runners | n8nio/runners:2.22.6 (pinned) | (internal 5679 broker) | External Code-node task runner |
| n8n-db | postgres:16-alpine | (internal 5432) | Workflow / credential / execution store |

Config notes:
- Postgres backend (not SQLite) for concurrency safety; execution data pruned at 7 days / 10k max; binary data on filesystem (keeps DB small).
- External task runners match n8n's official hosting pattern; native Python runner is enabled for Python Code nodes.
- n8n and n8n-runners are pinned to uid/gid `1000:1000` and `no-new-privileges` so future image default changes do not accidentally run them as root.
- Memory-capped (n8n 1G, runner 256M, db 256M) + `NODE_OPTIONS=--max-old-space-size=768` so it can't starve MOC.
- `N8N_SECURE_COOKIE=false` (http over the Tailscale-encrypted transport); telemetry off; metrics on at `/metrics`; timezone Asia/Kolkata; Code-node env/file access hardened; images pinned (Watchtower won't touch them).
- Security policy is managed by env: personal-space sharing/publishing are disabled; MFA enforcement is explicitly off until the owner account has MFA configured.
- n8n is dual-bound to `100.103.66.92:5678` and `127.0.0.1:5678`; it is still not LAN/public exposed.
- Not using queue mode / Redis / worker processors yet; that is intentionally deferred until real workflow volume justifies the extra always-on services.
- ntfy is a future infra-alert rail only.
- Quip (Discord ops assistant) shipped and lives in the same compose project — see §5.

---

### 5. Quip (Discord-first ops assistant) — ⚪ RETIRED 2026-08-20

**Historical section only.** Quip's remaining database volume and n8n gate were archived and
removed; `quip-agents.service` remains disabled/inactive. Phoenix is not retired: it now serves
active MOC telemetry and is documented as MOC observability.

**Frontend:** Discord (bot `Quip#7007` + specialist agents). No public web UI.
**Deployed:** 2026-06-02 onward
**Repo:** github.com/PranavSlathia/quip
**Server path:** ~/docker/n8n/ (same compose project as n8n; build context `~/docker/n8n/quip`,
rsync-synced from the repo — **not** a git checkout; see repo STATUS.md for the deploy flow)

| Component | Where | Port | Purpose |
|-----------|-------|------|---------|
| quip-discord-bot | container | internal 8787 (`/send`) | Discord frontend: @mention/DM/slash (`/quip`, `/cleanup`), confirm buttons, embeds |
| quip-brain | container | internal 8080 | Hono + Vercel AI SDK agent (Fireworks DeepSeek): tools, memory, guarded actions |
| quip-db | container | internal 5432 | Postgres: conversation memory, notes, reminders, `pending_actions` audit |
| quip-whatsapp | container | internal | Baileys WhatsApp sidecar (own number) |
| quip-action-executor | container | internal 8788 | Sole writer of whitelisted docker actions (restart/start/stop/cleanup) after user confirm |
| quip-docker-proxy | container | internal 2375 | Read-only docker socket proxy (CONTAINERS/INFO/PING/SYSTEM GET; `POST: 0`) |
| quip-n8n-gate | container | 127.0.0.1:8090 | Caddy basic-auth gate fronting n8n for n8n.prsnl.fyi |
| quip-agents | **host systemd service** (`/home/agent/quip-agents`, non-root `agent` user) | 0.0.0.0:8790 (UFW: n8n-net only, bearer-gated) | Specialist CLI agents (Madame Web/gemini, Scrivener/codex, Gwen/qwen) as Discord bots + brain→agent `/run` consult bridge |
| phoenix | container (`~/docker/phoenix/`) | 100.103.66.92:6006 | Arize Phoenix LLM-trace UI; brain exports OTLP via docker network (`http://phoenix:6006/v1/traces`) |

Security model: brain/bot never touch the docker socket directly — reads via the read-only proxy,
writes only through the executor after an explicit Discord confirm (audited in `pending_actions`).
MOC containers are protected/refused targets. Nightly quip-db restic backup (timer already listed
in Key Config Files).

---

## Hardware

| Spec | Value |
|------|-------|
| Model | Dell Vostro |
| CPU | Intel Celeron 2957U @ 1.4GHz (2C/2T) |
| RAM | 8 GB (7.7 GB usable) |
| Storage | Kingston A400 240GB SSD (218GB usable) |
| Second disk | Toshiba MQ01ABF050 500GB HDD (`sda3`, NTFS) mounted at `/mnt/hdd` (ntfs3, `nofail`). See "Secondary HDD" below. |
| WiFi | wlp6s0 — connected to Airtel_renu_8079 |
| Ethernet | enp7s0 — DHCP (backup) |
| Hostname | prsnl |

### Secondary HDD (`/mnt/hdd`) — added 2026-10-25

- **`/mnt/hdd/Pictures/` holds about 24k personal photos (35 GB). Never modify, move or format.**
  The plan for some later date: copy them to the Mac, verify, then reformat the whole disk as ext4.
- `fstab`: `UUID=1AD04DDBD04DBDAF /mnt/hdd ntfs3 …,uid=1000,gid=1000,fmask=0177,dmask=0077,nofail`.
  If the disk dies, boot still continues.
- Our data lives under `/mnt/hdd/prsnl/`:
  - `backup-mirror/` is the second copy of the backups. `hdd-backup-mirror.timer` runs daily at 05:15 UTC
    (`~/bin/hdd-backup-mirror.sh`, repo `scripts/` + `configs/systemd/`). It mirrors restic-moc
    exactly and checks that its snapshots match the source. MOC dumps, DH pg dumps and Desk OS backups
    are mirrored with history: removed files go to `.retired/<name>/<date>/` and expire after 60 days.
    `LAST_SUCCESS` holds the time of the last good run.
  - `aws-account-backups/` holds the AWS account 999200449801 backup (closed account; **only local
    copy**, plus Google Drive). It contains the original `.tar.gz` (md5 verified) and a `.tar.zst` of the
    backup root. It was moved off the SSD on 2026-10-25; the `aws-backup-*` units are disabled.
  - `cold-archive/` holds verified `.tar.zst` archives of cold MOC gate/integrity backups moved off the
    SSD. `MANIFEST.tsv` gives the original path and sha256 for each one.
- ntfs3 stores Unix ownership and modes for files Linux creates. The cold and AWS archives were written by root
  (root-only, mode 0600), so read them with `sudo`. They are tarballs anyway, so restores keep the original modes.
- Not for live databases or containers. It's a 5400 rpm laptop drive; use it only as a second copy or for cold storage.
- Kernel arg `libata.force=1:3.0G` (`/etc/default/grub.d/90-sata-link-cap.cfg`) caps this port. SMART
  attribute 199 (UDMA_CRC) still rises at about 0.75 per MB transferred at any link speed, with zero
  kernel ATA errors. That's a firmware counting quirk, not a cable fault. smartd monitors both disks.

## OS & Software

- Ubuntu Server 24.04 LTS (minimized)
- Kernel: 6.8.0-147-generic
- Docker: v29.9.2
- Docker Compose: v5.6.1
- Node.js: v24.22.1
- Claude Code CLI: v2.1.92
- GitHub CLI: v2.45.0 (authenticated as PranavSlathia)
- Gemini CLI: installed via npm
- Codex CLI: installed via npm
- Tailscale: connected (100.103.66.92)
- Cloudflared: v2026.3.0

## Network Configuration

### Static WiFi IP
- IP: 192.168.1.18/24
- Gateway: 192.168.1.1
- DNS: 8.8.8.8, 8.8.4.4
- Config: `/etc/netplan/01-network.yaml`
- Network owner: `systemd-networkd`; NetworkManager is disabled because all live
  interfaces are unmanaged by it.
- Apt online gate: `/etc/systemd/system/apt-daily.service.d/online.conf` and
  `apt-daily-upgrade.service.d/online.conf` wait for `wlp6s0:routable`; the optional,
  unplugged Ethernet interface does not block automatic updates.

### Tailscale VPN
- Tailscale IP: 100.103.66.92
- Account: `<your-tailscale-account>` (see local notes)
- Devices observed 2026-06-29: Dell server (`prsnl`), Mac Mini (`pranavs-mac-mini`), active macOS peer (`prsnl-1`), iPhone (`iphone183`, offline/last seen 81 days ago)

### Firewall (UFW) — Current Rules

```
UFW allow rules (verified 2026-10-25):
  22/tcp    → SSH, from anywhere (key-only, fail2ban). NOTE: fail2ban showed 0 failures
              and 0 bans on 2026-10-25; the router likely does not forward
              :22, so in practice SSH is LAN + Tailscale only.
  3001, 9443, 9999, 19999 → from Tailscale (100.64.0.0/10) only
              (19999/Netdata is stale: Netdata is not deployed — see Pending Tasks)
  6006/tcp  → from moc-net docker bridge (172.19.0.0/16) only, on 100.103.66.92 —
              metadata-only MOC OpenTelemetry export to Phoenix; the UI stays Tailscale-bound
(The Quip-era 19999-from-n8n-net and 8790 rules are gone since the 2026-08-20 retirement.)

(Stale Langfuse :3030 rules removed 2026-06-11. Langfuse itself retired 2026-06-03 → Phoenix.)

Public traffic does NOT enter via UFW at all — it arrives via Cloudflare Tunnel
(outbound-only connection), which proxies to localhost:<port>. 80/443 are not
forwarded by the router.

Dockge (5001), pgweb (8081), and Portainer edge (8000) are restricted by their Docker
port binding to `100.103.66.92:` (Tailscale interface) rather than by UFW rules.
Phoenix (6006) uses the same Tailscale binding plus the narrowly scoped moc-net
exception above for in-host telemetry delivery.

⚠️ Remember: Docker-published ports on 0.0.0.0 bypass UFW (DOCKER iptables chain).
Restrict containers by binding (`100.103.66.92:` / `127.0.0.1:`), not by UFW alone.

Internal or localhost-only:
  moc-db, moc-server (3000), moc-embedding (8004), moc-graph-consolidator (8006),
  prsnl-landing (127.0.0.1:8088)
```

## Security

### SSH (hardened 2026-04-06; re-verified 2026-06-17)
- **Password authentication: DISABLED** (key-only) — enforced in `sshd_config`,
  `sshd_config.d/00-disable-password-auth.conf`, and `sshd_config.d/50-cloud-init.conf`.
  The `pronav` console password (reset to a simple value during the 2026-06-17 lockout) is
  therefore **only** usable at the physical console + Cockpit (`:9090`), never over SSH.
- **Root login: DISABLED**
- Key-based auth from Mac Mini (ed25519). ⚠️ **Only this one key is authorized** for both
  `pronav` and `breakglass` → SSH access depends on the Mac Mini being up. Add MacBook Air +
  iPhone keys to remove this single point of failure.
- Passwordless sudo via `/etc/sudoers.d/pronav`
- **Breakglass admin**: user `breakglass`, `sudo` group, **password-required** sudo (no NOPASSWD
  drop-in — matches `scripts/access-hardening.sh`), same Mac Mini key authorized. Provisioned &
  SSH login-verified 2026-06-17; re-provision/refresh via `bash scripts/access-hardening.sh`.
  Password is kept in a password manager (durable) **and** recorded in the server recovery note
  (`PRSNL_RECOVERY.md`) for convenience — never in this repo. `access-hardening.sh` regenerates the
  note without the password, so re-running it requires re-adding the note copy if you want both.
- `/etc/sudoers.d/pronav` permissions corrected to `root:root 0440` on 2026-06-17 (was flagged by
  `visudo -c` as "bad permissions" — sudo can ignore a wrongly-permissioned drop-in).

### Fail2ban
- Protects SSH from brute-force attacks
- Ban time: 1 hour
- Max retries: 5 within 10 minutes
- Config: `/etc/fail2ban/jail.local`

### Unattended Upgrades
- Auto-installs security patches daily
- Auto-reboots at 4:00 AM if kernel update requires it
- Removes unused kernels and dependencies

### Container Security
- Admin dashboards restricted to Tailscale, with Docker published ports bound to `100.103.66.92` where possible
- Database ports not exposed to host
- Watchtower disabled for pinned DB images (SHA digest)
- Docker log rotation: 10MB max, 3 files per container
- Logrotate: additional daily rotation at `/etc/logrotate.d/docker-containers`

## Performance Tuning

### Kernel Parameters (`/etc/sysctl.d/99-server.conf`)
```
vm.swappiness=10                          # Minimize swap usage
fs.inotify.max_user_watches=524288        # More file watchers for dev tools
net.core.somaxconn=65535                  # Max socket connections
net.ipv4.tcp_max_syn_backlog=65535        # TCP backlog
net.ipv4.ip_local_port_range=1024 65535   # Full port range
net.ipv4.tcp_tw_reuse=1                   # Reuse TIME_WAIT sockets
```

### Disk
- Write caching enabled via hdparm
- Read speed: ~490 MB/s

### Laptop-Specific
- Lid close: ignored (`/etc/systemd/logind.conf`)
- Sleep/suspend/hibernate: masked (disabled)
- Runs headless with lid closed, plugged into power

## Infrastructure Containers

| Container | Image | Purpose | Restart |
|-----------|-------|---------|---------|
| portainer | portainer/portainer-ce:lts | Docker management UI (port 9443) | always |
| dockge | louislam/dockge:1 | Compose stack manager (port 5001) | always |
| uptime-kuma | louislam/uptime-kuma:1 | Uptime monitoring | always |
| dozzle | amir20/dozzle:latest | Docker log viewer | always |
| netdata | — | Not deployed as of 2026-10-25 (no container/image) | — |
| pgweb | sosedoff/pgweb:latest | Postgres web UI (port 8081) | always |
| watchtower | containrrr/watchtower | Auto-update containers | always |
| autoheal | willfarrell/autoheal | Restart unhealthy containers | always |

Infrastructure compose: `~/docker/docker-compose.yml` (pgweb + dockge live in their own dirs).

Autoheal uses `AUTOHEAL_START_PERIOD=300` and `AUTOHEAL_INTERVAL=30` (verified 2026-10-25) so
normal post-boot database/model warm-up does not trigger a restart loop. `uptime-kuma` and
`dozzle` run under their normal container names.

## Developer Tools on Server

| Tool | Version | Path | Purpose |
|------|---------|------|---------|
| code-review-graph | 2.1.0 | ~/.local/bin/code-review-graph | Structural codebase graph via MCP (22 tools) |
| Claude Code CLI | 2.1.92 | ~/.local/bin/claude | AI coding assistant |
| Gemini CLI | 0.36.0 | /usr/bin/gemini | Google AI assistant |
| Codex CLI | 0.118.0 | /usr/bin/codex | OpenAI coding assistant |
| GitHub CLI | 2.45.0 | /usr/bin/gh | GitHub operations |

## Auth Tokens on Server

| Service | Method | Location | Expiry |
|---------|--------|----------|--------|
| Claude Code | OAuth token | `~/.bashrc` + `/etc/environment` + compose env | ~April 2027 |
| GitHub CLI | Device code OAuth | `~/.config/gh/hosts.yml` | Long-lived |
| Cloudflare Tunnel | Cert | `~/.cloudflared/cert.pem` | Long-lived |
| Tailscale | Machine auth | systemd service | Auto-renew |

## Key Config File Locations

| File | Purpose |
|------|---------|
| `/etc/netplan/01-network.yaml` | WiFi + Ethernet config |
| `/etc/docker/daemon.json` | Docker daemon settings: json-file log rotation, overlay2, live-restore, DNS pinned to `1.1.1.1`/`8.8.8.8` |
| `/etc/fail2ban/jail.local` | Fail2ban rules |
| `/etc/sysctl.d/99-server.conf` | Kernel tuning |
| `/etc/systemd/logind.conf` | Lid close behavior |
| `/etc/apt/apt.conf.d/50unattended-upgrades` | Auto-update settings |
| `/etc/cloudflared/config.yml` | Cloudflare Tunnel routing |
| `/etc/systemd/system/cloudflared.service.d/restart.conf` | `Restart=always` + `RestartSec=5` — auto-recover the tunnel if cloudflared exits (NB: `SIGHUP` stops cloudflared here; use `systemctl restart` to apply ingress changes) |
| `/etc/sudoers.d/pronav` | Passwordless sudo |
| `~/docker/docker-compose.yml` | Infrastructure compose stack |
| `~/docker/moc/docker-compose.prod.yml` | MOC project compose |
| `~/docker/moc/.env` | MOC environment variables |
| `~/bin/moc-backup-restic.sh` | MOC restic backup script |
| `/etc/systemd/system/moc-backup.timer` | MOC daily backup timer |
| `/etc/fstab` (`/mnt/hdd` entry) | Secondary HDD mount (ntfs3, `nofail`) |
| `/etc/default/grub.d/90-sata-link-cap.cfg` | `libata.force=1:3.0G` for the HDD port |
| `/etc/systemd/system/hdd-backup-mirror.{service,timer}` | Nightly 05:15 UTC backup mirror to the HDD (repo `configs/systemd/`) |
| `~/bin/hdd-backup-mirror.sh` | Mirror script (repo `scripts/hdd-backup-mirror.sh`) |
| `/home/pronav/server-recovery/maintenance-20261025/` | Archived Docker volumes and pre-change fstab/grub copies from 2026-10-25 |
| `/home/pronav/server-recovery/retired/20260820T160354Z/` | Checksum-verified n8n/Quip recovery material plus the Domain Hunter pre-removal restore point and pre-retention Phoenix backup; never commit |

## Adding a New Project

When deploying a new project to this server:

1. **Check the Port Registry** above — pick unused ports
2. **Create project directory:** `mkdir -p ~/docker/PROJECT_NAME`
3. **Clone repo:** `gh repo clone OWNER/REPO ~/docker/PROJECT_NAME`
4. **Create .env:** `chmod 600 ~/docker/PROJECT_NAME/.env`
5. **Build and start:** `cd ~/docker/PROJECT_NAME && docker compose -f docker-compose.prod.yml up -d`
6. **Open UFW ports** if needed (prefer Tailscale-only for admin)
7. **Add Cloudflare Tunnel route** if public access needed:
   ```bash
   cloudflared tunnel route dns moc SUBDOMAIN.prsnl.fyi
   # Update /etc/cloudflared/config.yml with new ingress rule
   sudo systemctl restart cloudflared
   ```
8. **Add Uptime Kuma monitor** for health endpoint
9. **Set up backup timer** if project has a database
10. **Update this document** — add to Port Registry and Deployed Projects sections

## Troubleshooting

For incidents, use `SOS-RUNBOOK.md` first. The checks below are quick references.

### Can't SSH into server
1. `ping 192.168.1.18` (local) or `ping 100.103.66.92` (Tailscale)
2. If both fail, server may have lost power — physical restart needed
3. After reboot, all services auto-start (WiFi, SSH, Docker, tunnel)

### Container not running
```bash
sudo docker ps -a                           # Check status
sudo docker start CONTAINER_NAME            # Start it
sudo docker logs --tail 50 CONTAINER_NAME   # Check errors
```

### Cloudflare Tunnel down
```bash
sudo systemctl status cloudflared
sudo systemctl restart cloudflared
sudo journalctl -u cloudflared --tail 20
```

### Disk space low
Cold data can be moved to `/mnt/hdd/prsnl/cold-archive/` as a verified `.tar.zst` (see
`docs/MAINTENANCE-2026-10-25.md` for the tar-compare-then-delete procedure).
```bash
df -h / /mnt/hdd
sudo docker system prune -a                # Remove unused images
sudo docker builder prune -f               # Clear build cache
```

### Server health check
```bash
ssh pronav@192.168.1.18 "echo '=== UPTIME ===' && uptime && echo '=== MEMORY ===' && free -h && echo '=== DISK ===' && df -h / && echo '=== DOCKER ===' && sudo docker ps --format 'table {{.Names}}\t{{.Status}}' && echo '=== SERVICES ===' && for s in ssh docker fail2ban wpa_supplicant ufw tailscaled cloudflared cron; do echo \"\$s: \$(sudo systemctl is-active \$s)\"; done"
```

## Resource Budget

| Resource | Total | Used | Available | Notes (as of 2026-06-11) |
|----------|-------|------|-----------|--------------------------|
| RAM | 7.7 GB | ~3.7-4.5 GB typical | ~3-4 GB typical | Keep new services lean; embedding is the largest workload (~800MB of its cold pages live in swap by design) |
| Disk (SSD `/`) | 218 GB | 115 GB | 97 GB | 55% on 2026-10-25 after image/volume cleanup and moving cold archives + AWS backup to the HDD (was 86%) |
| Disk (HDD `/mnt/hdd`) | 465 GB | 105 GB | 361 GB | Cold archives, backup mirror, AWS backup, plus 35 GB personal photos |
| CPU | 2 cores | workload-dependent | Constrained | Celeron is the real bottleneck; avoid piling on crawlers/ML without offloading |

When adding projects, budget ~500MB-2GB RAM per project depending on stack and treat sustained 15-minute load over ~3.0 as a warning. The weekly maintenance script now flags CPU load pressure.

MOC image-size watchlist from 2026-06-29: `moc-embedding:latest` is 5.31GB because `uv sync
--no-dev` contributes a 5.13GB layer; `moc-worker:latest`/`moc-server` is 3.88GB because the runtime
copies a 2.87GB root `node_modules` plus 642MB of globally installed Claude/Codex CLIs. Future MOC
Dockerfile work should split build/runtime stages, prune production deps, and avoid baking model
caches or unused CLIs into runtime images.

## Cloudflare Tunnel Routes

Single tunnel (`moc`), config at `/etc/cloudflared/config.yml`:

| Hostname | → Local | Container |
|----------|---------|-----------|
| prsnl.fyi | localhost:8088 | prsnl-landing (incl. `/deck`) |
| www.prsnl.fyi | localhost:8088 | prsnl-landing |
| moc.prsnl.fyi | localhost:5173 | moc-web |
| xd.prsnl.fyi | http_status:404 | parked (dh-web removed) |
| n8n.prsnl.fyi | http_status:404 | parked after n8n retirement |

## Pending Tasks (as of 2026-10-25)

Single canonical list; other docs link here. Remove items when done.

**Secondary HDD (`/mnt/hdd`)**
1. **Move the photos off the HDD, then reformat it as ext4.** `/mnt/hdd/Pictures` (~24k photos, 35 GB) may be
   their *only* copy. Order: copy to the Mac, verify checksums, reformat the whole disk as ext4, migrate
   `/mnt/hdd/prsnl/`, and update the `/etc/fstab` UUID. Keep the `/mnt/hdd` mountpoint so scripts don't change.
   Consider an extra copy (e.g. Google Drive) before then.
2. **Add alerting for the backup mirror.** Hook `hdd-backup-mirror.service` `OnFailure=` to ntfy, and have
   `weekly-maintenance.sh` flag a stale `/mnt/hdd/prsnl/backup-mirror/LAST_SUCCESS` (older than 2 days).
   Today a failed run is only visible in the journal and failed-units list.
3. **Do a restore drill from the HDD mirror.** Restore the latest snapshot from
   `/mnt/hdd/prsnl/backup-mirror/restic-moc` into a temporary database.
3a. **Keep the restic key off the SSD.** `~/.restic-moc.key` exists only on the SSD, so if the SSD
    dies the HDD mirror of restic-moc can't be decrypted. Store a copy in the password manager.
    Never put it in this repo.
4. Optional: the `libata.force=1:3.0G` cap (`/etc/default/grub.d/90-sata-link-cap.cfg`) had no
   measurable effect. Drop it at a convenient reboot, or keep it (it's harmless).

**MOC**
5. **Recreate the three test DBs the 2026-10-25 reboot destroyed.** These were the proof runs
   `full456-cb6f-20261021-v2`, `spr01-batch` and `spr01-consent` (ephemeral containers, no mounts).
   Rebuild them from their own setup steps.
6. **Before any reboot,** list containers with restart policy `no` or `AutoRemove`; they won't
   survive it. Give the MOC proof harness persistent volumes or a restart story.
7. **Decide retention for `~/.local/share/moc-spr-proof`.** It's 39 GiB and was still growing on
   2026-10-22, making it the largest remaining SSD consumer.
8. Graph health is still `operationalStatus=critical` (51 exhausted jobs, 462 orphan findings).

**Host / docs**
9. **Netdata isn't deployed** (no container/image/compose entry), but docs and UFW still list it on 19999.
   Redeploy it under compose, or remove it from the docs and drop the UFW rule.
10. **AWS backup tooling.** The `aws-backup-*` units are disabled and its `tools/` scripts point at the
    old SSD path. Update or delete them if another AWS backup is ever needed. The data lives on
    `/mnt/hdd/prsnl/aws-account-backups/` and Google Drive.
11. Long-standing: add a second SSH key (MacBook Air / iPhone). The Mac and the Dell are on different
    Tailscale networks (LAN SSH works). Ethernet `enp7s0` has no carrier, so the box is WiFi-only.
