# Dell Home Server (prsnl) — Management Guide

This repo manages the Dell Vostro laptop converted into an Ubuntu home server on 2026-04-06.

For incidents and recovery work, start with `SOS-RUNBOOK.md`.

## Quick Access

```bash
# SSH (local network)
ssh pronav@192.168.1.18

# SSH (anywhere via Tailscale)
ssh pronav@100.103.66.92

# User: pronav | Passwordless sudo | SSH key auth from Mac Mini
```

`breakglass` is a local sudo fallback user with copied SSH public keys. Use it only for access
recovery and keep its password outside this repo. Tailscale SSH is intentionally disabled because
it can add browser approval to `ssh pronav@100.103.66.92` and interrupt deploy agents.

Live recovery note on the server: `/home/pronav/server-recovery/PRSNL_RECOVERY.md`.

## Web Dashboards

| Service | Local URL | Tailscale URL | Access | Purpose |
|---------|-----------|---------------|--------|---------|
| Portainer | SSH tunnel only | https://100.103.66.92:9443 | Tailscale only | Docker management UI |
| Uptime Kuma | SSH tunnel only | http://100.103.66.92:3001 | Tailscale only | Uptime monitoring |
| Dozzle | SSH tunnel only | http://100.103.66.92:9999 | Tailscale only | Live Docker log viewer |
| Netdata | SSH tunnel only | http://100.103.66.92:19999 | Tailscale only | Real-time system metrics |
| Phoenix | SSH tunnel only | http://100.103.66.92:6006 | Tailscale only | LLM trace observability (Quip brain) |

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
| 19999 | Netdata | netdata | Tailscale only | System metrics (+ allowed from n8n-net `172.24.0.0/16` for Quip alert checker) |

> **Gotcha:** a Docker `ports: "X:X"` publish binds `0.0.0.0` and **bypasses UFW** (DOCKER iptables
> chain), so "UFW doesn't allow it" ≠ "not exposed" — it's LAN-reachable. Always bind admin UIs to
> `100.103.66.92:` or `127.0.0.1:` explicitly. (Phoenix made this mistake; fixed 2026-06-11.)

### Project Ports

| Port | Project | Service | Container | Access | Compose File |
|------|---------|---------|-----------|--------|-------------|
| 3000 | MindOverChatter | Hono backend API | moc-server | Localhost only | ~/docker/moc/docker-compose.prod.yml |
| 5173 | MindOverChatter | React frontend (nginx) | moc-web | Public (via tunnel) | ~/docker/moc/docker-compose.prod.yml |
| 5433 | MindOverChatter | PostgreSQL + pgvector | moc-db | Internal only | ~/docker/moc/docker-compose.prod.yml |
| 8004 | MindOverChatter | Embedding service | moc-embedding | Localhost only | ~/docker/moc/docker-compose.prod.yml |
| 8006 | MindOverChatter | Graph consolidator | moc-graph-consolidator | Localhost only | ~/docker/moc/docker-compose.prod.yml |
| 5436 | Domain Hunter | PostgreSQL + pgvector | dh-pg | Localhost only | ~/docker/domain-hunter/compose.yml |
| 6381 | Domain Hunter | Redis | dh-redis | Localhost only | ~/docker/domain-hunter/compose.yml |
| 8007 | Domain Hunter | FastAPI API | dh-api | Localhost only | ~/docker/domain-hunter/compose.yml |
| 8088 | prsnl-landing | nginx static | prsnl-landing | Public (via tunnel) | ~/docker/landing/ |
| 5678 | n8n | Workflow automation UI/API | n8n | Tailscale + localhost | ~/docker/n8n/docker-compose.yml |
| 8090 | Quip | Caddy basic-auth gate → n8n | quip-n8n-gate | Localhost (tunnel origin) | ~/docker/n8n/docker-compose.yml |
| 6006 | Quip/observability | Phoenix LLM-trace UI + OTLP | phoenix | Tailscale only (`100.103.66.92`) | ~/docker/phoenix/docker-compose.yml |
| 8790 | Quip | quip-agents `/run` bridge (host systemd, not docker) | — | n8n-net only (`172.24.0.0/16`, bearer-gated) | /home/agent/quip-agents |

**Graph store note:** FalkorDB is **deprecated** — MOC's knowledge graph was cut over to
**Postgres** (`moc-db`, graph projection owned by `moc-graph-consolidator`;
`GRAPH_PROJECTION_BACKEND=postgres`, verified via `/health` → `"graphBackend":"postgres"`).
The old `moc-falkordb-1` container (6380) and the Mac Mini FalkorDB (`100.111.147.100:6379`)
are no longer in MOC's runtime path. Cutover tooling: `services/graph-consolidator/scripts/falkor_postgres_cutover.py`.

**Workers / internal-only (no host ports):** dh-scheduler, dh-worker-{registrar,a2,rdap,wayback,classifier,scoring}, vulture (DH Discord bot), moc-worker, n8n-runners, n8n-db (internal 5432), quip-db (internal 5432), quip-brain (internal 8080), quip-discord-bot (internal 8787), quip-whatsapp, quip-action-executor (internal 8788), quip-docker-proxy (internal 2375, read-only socket proxy).

### Available Port Ranges for New Projects

| Range | Suggested Use |
|-------|--------------|
| 3100-3199 | Web backends |
| 4000-4999 | APIs |
| 5174-5435 | Frontends |
| 5437-5499 | Databases |
| 6000-6379 | Misc services (6006 taken: Phoenix) |
| 6382-6999 | Misc services |
| 7000-7999 | Misc services |
| 8012-8087 | Python/ML services |
| 8091-8789 | Python/ML services (8090 taken: quip-n8n-gate) |
| 8791-8999 | Python/ML services (8790 taken: quip-agents) |

---

## Deployed Projects

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
| moc-embedding | moc-embedding (custom) | 8004 | Running (healthy) | Embedding service (~3.5GB) |
| moc-worker | moc-worker (custom) | (internal) | Running | Background work |
| moc-graph-consolidator | moc-graph-consolidator | 8006 | Running (healthy) | Owns Postgres graph projection writes (`graphBackend: postgres`) |

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

**Public URL:** none — `xd.prsnl.fyi` is parked (`http_status:404` in the tunnel; the `dh-web`
dashboard container was removed). Operated via **Vulture** (Discord bot, `vulture` container) +
the daily Discord digest + Tailscale/`dh-api`.
**Deployed:** 2026-05-14
**Repo:** github.com/PranavSlathia/XD
**Server path:** ~/docker/domain-hunter/
**Compose:** ~/docker/domain-hunter/compose.yml (profiles: foundation / api / workers / all)
**Deploy mode:** Self-hosted GitHub Actions runner on the Dell (`actions.runner.PranavSlathia-XD.dh-dell`). Every push to `main` rebuilds `dh-api` and restarts it.

Self-hosted expired-domain discovery + scoring pipeline. Ingest GitHub README citations → DNS NXDOMAIN filter → Open PageRank enrich → RDAP availability → Wayback CDX → composite scoring → daily Discord digest.

| Container | Image | Port | Status |
|-----------|-------|------|--------|
| dh-api | domain-hunter-dh-api | 8007 | FastAPI HTTP API |
| dh-scheduler | domain-hunter-dh-scheduler | — | APScheduler cron jobs (digest) |
| dh-worker-a2 | domain-hunter-dh-worker-a2 | — | GitHub README ingest |
| dh-worker-rdap | domain-hunter-dh-worker-rdap | — | DNS + OPR + RDAP enrich |
| dh-worker-wayback | domain-hunter-dh-worker-wayback | — | Wayback CDX |
| dh-worker-classifier | domain-hunter-dh-worker-classifier | — | Codex CLI safety classifier |
| dh-worker-scoring | domain-hunter-dh-worker-scoring | — | Composite scoring v3 |
| dh-worker-registrar | domain-hunter-dh-worker-registrar | — | Registrar checks |
| vulture | (custom) | — | Discord operator bot (`Vulture#1112`, slash commands) |
| dh-pg | pgvector/pgvector:pg16 | 5436 | Postgres + pgvector |
| dh-redis | redis:7-alpine | 6381 | Worker queue + pub/sub |

(`dh-web` operator dashboard: **removed**.)

**Env file:** `~/docker/domain-hunter/.env` (chmod 600) — see repo README for the required keys (DH_GITHUB_TOKEN, DH_OPENPAGERANK_API_KEY, DH_WHOISJSON_API_KEY, DH_DISCORD_WEBHOOK_URL, DH_SENTRY_DSN, etc.).

**External integrations wired:** Open PageRank (DomCop), WhoisJSON, Discord webhook.
⚠️ GlitchTip was **retired** (see §3) — if `DH_SENTRY_DSN` is still set in `.env`, DH error
events go nowhere; unset it or point at a live sink.

---

### 3. GlitchTip (self-hosted error tracking) — ⚪ RETIRED

**Status (2026-06-11 audit):** all four containers (gt-web, gt-worker, gt-pg, gt-redis) are
**gone** — neither running nor stopped. Port 8011 is free again. Compose/env files may remain at
`~/docker/domain-hunter/glitchtip-compose.yml` / `.glitchtip.env` for a future revival.
Anything still pointing a Sentry DSN at it (e.g. `DH_SENTRY_DSN`) is shipping events to nowhere.

---

### 4. n8n (workflow automation)

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

### 5. Quip (Discord-first ops assistant)

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
| WiFi | wlp6s0 — connected to Airtel_renu_8079 |
| Ethernet | enp7s0 — DHCP (backup) |
| Hostname | prsnl |

## OS & Software

- Ubuntu Server 24.04 LTS (minimized)
- Kernel: 6.8.0-124-generic
- Docker: v29.5.2
- Docker Compose: v5.1.4
- Node.js: v22.22.2
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

### Tailscale VPN
- Tailscale IP: 100.103.66.92
- Account: `<your-tailscale-account>` (see local notes)
- Devices on tailnet: Mac Mini (configured), MacBook Air (pending), iPhone (pending)

### Firewall (UFW) — Current Rules

```
UFW allow rules (verified 2026-06-11):
  22/tcp    → SSH, from anywhere (key-only, fail2ban). NOTE: fail2ban shows 0 bans
              over 9 days of uptime — the router almost certainly does not forward
              :22, so in practice SSH is LAN + Tailscale only.
  3001, 9443, 9999, 19999 → from Tailscale (100.64.0.0/10) only
  19999/tcp → also from n8n-net docker bridge (172.24.0.0/16) — Quip alert checker
              reads host metrics from Netdata (read-only)
  8790/tcp  → from 172.24.0.0/16 only — Quip brain→agents consult bridge (bearer-gated)

(Stale Langfuse :3030 rules removed 2026-06-11. Langfuse itself retired 2026-06-03 → Phoenix.)

Public traffic does NOT enter via UFW at all — it arrives via Cloudflare Tunnel
(outbound-only connection), which proxies to localhost:<port>. 80/443 are not
forwarded by the router.

Dockge (5001), pgweb (8081), Portainer edge (8000), n8n (5678), Phoenix (6006) are
restricted by their Docker port binding to `100.103.66.92:` (Tailscale interface)
rather than by UFW rules.

⚠️ Remember: Docker-published ports on 0.0.0.0 bypass UFW (DOCKER iptables chain).
Restrict containers by binding (`100.103.66.92:` / `127.0.0.1:`), not by UFW alone.

Internal or localhost-only:
  dh-pg (5436), dh-redis (6381), dh-api (8007),
  moc-db, moc-server (3000), moc-embedding (8004), moc-graph-consolidator (8006),
  n8n-runners (5679), n8n-db, quip-db, quip-brain, quip-action-executor,
  quip-docker-proxy, quip-n8n-gate (127.0.0.1:8090), prsnl-landing (127.0.0.1:8088)
```

## Security

### SSH (hardened 2026-04-06)
- **Password authentication: DISABLED** (key-only)
- **Root login: DISABLED**
- Key-based auth from Mac Mini (ed25519)
- Passwordless sudo via `/etc/sudoers.d/pronav`

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
| netdata | netdata/netdata | Real-time system monitoring | always |
| pgweb | sosedoff/pgweb:latest | Postgres web UI (port 8081) | always |
| watchtower | containrrr/watchtower | Auto-update containers | always |
| autoheal | willfarrell/autoheal | Restart unhealthy containers | always |

Infrastructure compose: `~/docker/docker-compose.yml` (pgweb + dockge live in their own dirs).

Note: `uptime-kuma` and `dozzle` currently run under hash-prefixed container names
(`58892943e1b5_uptime-kuma`, `a61f323b94f8_dozzle`) — leftover from an interrupted compose
recreate. Harmless, but `docker ps` greps and `docker restart uptime-kuma` by plain name will
miss them; a future `docker compose up -d --force-recreate` of the infra stack will fix the names.

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
| `/etc/docker/daemon.json` | Docker daemon settings |
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
| `~/bin/quip-db-backup.sh` | Quip DB (quip-db) restic backup script — repo `~/backups/restic-quip`, key `~/.restic-quip.key` |
| `/etc/systemd/system/quip-db-backup.timer` | Quip DB nightly backup timer (03:25 UTC) |

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
```bash
df -h /
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
| Disk | 218 GB | ~62 GB | ~146 GB | Docker images ~18GB · volumes ~8GB · **build cache regrows ~10-20GB/week** (GH Actions runner + quip rebuilds) — `docker builder prune -f` periodically, or use Quip's `/cleanup` |
| CPU | 2 cores | workload-dependent | Constrained | Celeron is the real bottleneck; avoid piling on crawlers/ML without offloading |

When adding projects, budget ~500MB-2GB RAM per project depending on stack and treat sustained 15-minute load over ~3.0 as a warning. The weekly maintenance script now flags CPU load pressure.

## Cloudflare Tunnel Routes

Single tunnel (`moc`), config at `/etc/cloudflared/config.yml`:

| Hostname | → Local | Container |
|----------|---------|-----------|
| prsnl.fyi | localhost:8088 | prsnl-landing (incl. `/deck`) |
| www.prsnl.fyi | localhost:8088 | prsnl-landing |
| moc.prsnl.fyi | localhost:5173 | moc-web |
| xd.prsnl.fyi | http_status:404 | parked (dh-web removed) |
| n8n.prsnl.fyi | localhost:8090 | quip-n8n-gate (Caddy Basic-Auth) → n8n |
