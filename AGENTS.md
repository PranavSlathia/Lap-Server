# Dell Home Server (prsnl) — Management Guide

This repo manages the Dell Vostro laptop converted into an Ubuntu home server on 2026-04-06.

## Quick Access

```bash
# SSH (local network)
ssh pronav@192.168.1.18

# SSH (anywhere via Tailscale)
ssh pronav@100.103.66.92

# User: pronav | Passwordless sudo | SSH key auth from Mac Mini
```

## Web Dashboards

| Service | Local URL | Tailscale URL | Access | Purpose |
|---------|-----------|---------------|--------|---------|
| Portainer | https://192.168.1.18:9443 | https://100.103.66.92:9443 | LAN + Tailscale | Docker management UI |
| Uptime Kuma | http://192.168.1.18:3001 | http://100.103.66.92:3001 | LAN + Tailscale | Uptime monitoring |
| Dozzle | http://192.168.1.18:9999 | http://100.103.66.92:9999 | LAN + Tailscale | Live Docker log viewer |
| Netdata | http://192.168.1.18:19999 | http://100.103.66.92:19999 | Tailscale only | Real-time system metrics |

---

## Port Registry

**IMPORTANT: Check this table before assigning ports to new projects. No duplicates.**

### Infrastructure Ports (reserved)

| Port | Service | Container | Access | Notes |
|------|---------|-----------|--------|-------|
| 22 | SSH | host | Public | Key-only auth, password disabled |
| 80 | HTTP | host | Public | Reserved for Cloudflare |
| 443 | HTTPS | host | Public | Reserved for Cloudflare |
| 3001 | Uptime Kuma | uptime-kuma | LAN + Tailscale | Monitoring dashboard |
| 5001 | Dockge | dockge | LAN + Tailscale | Compose stack manager |
| 8000 | Portainer edge | portainer | LAN + Tailscale | Edge agent endpoint |
| 8080 | Watchtower | watchtower | Internal | Health check only |
| 8081 | pgweb | pgweb | LAN + Tailscale | Postgres web UI |
| 9443 | Portainer | portainer | LAN + Tailscale | Docker management |
| 9999 | Dozzle | dozzle | LAN + Tailscale | Log viewer |
| 19999 | Netdata | netdata | Tailscale only | System metrics |

### Project Ports

| Port | Project | Service | Container | Access | Compose File |
|------|---------|---------|-----------|--------|-------------|
| 3000 | MindOverChatter | Hono backend API | moc-server-1 | Public (via tunnel) | ~/docker/moc/docker-compose.prod.yml |
| 5173 | MindOverChatter | React frontend (nginx) | moc-web | Public (via tunnel) | ~/docker/moc/docker-compose.prod.yml |
| 5433 | MindOverChatter | PostgreSQL + pgvector | moc-db-1 | LAN + Tailscale | ~/docker/moc/docker-compose.prod.yml |
| 6380 | MindOverChatter | FalkorDB (graph) | moc-falkordb-1 | LAN + Tailscale | ~/docker/moc/docker-compose.prod.yml |
| 8004 | MindOverChatter | Embedding service | moc-embedding | LAN + Tailscale | ~/docker/moc/docker-compose.prod.yml |
| 8006 | MindOverChatter | Graph consolidator | moc-graph-consolidator | LAN + Tailscale | ~/docker/moc/docker-compose.prod.yml |
| 5436 | Domain Hunter | PostgreSQL + pgvector | dh-pg | LAN + Tailscale | ~/docker/domain-hunter/compose.yml |
| 6381 | Domain Hunter | Redis | dh-redis | LAN + Tailscale | ~/docker/domain-hunter/compose.yml |
| 8005 | Domain Hunter | Web/dashboard | dh-web | Public (via tunnel) | ~/docker/domain-hunter/compose.yml |
| 8007 | Domain Hunter | FastAPI API | dh-api | LAN + Tailscale | ~/docker/domain-hunter/compose.yml |
| 8011 | GlitchTip | Web (error tracking) | gt-web | Tailscale only | ~/docker/domain-hunter/glitchtip-compose.yml |
| 8088 | prsnl-landing | nginx static | prsnl-landing | Public (via tunnel) | ~/docker/landing/ |

**Workers (no host ports):** dh-scheduler, dh-worker-{a2,rdap,wayback,classifier,scoring}, gt-worker, gt-pg (internal 5432), gt-redis (internal 6379), moc-worker.

### Available Port Ranges for New Projects

| Range | Suggested Use |
|-------|--------------|
| 3100-3199 | Web backends |
| 4000-4999 | APIs |
| 5174-5435 | Frontends |
| 5437-5499 | Databases |
| 6000-6379 | Misc services |
| 6382-6999 | Misc services |
| 7000-7999 | Misc services |
| 8012-8087 | Python/ML services |
| 8089-8999 | Python/ML services |

---

## Deployed Projects

### 0. prsnl-landing

**Public URL:** https://prsnl.fyi · https://www.prsnl.fyi
**Server path:** ~/docker/landing/
**Container:** `prsnl-landing` (nginx:alpine, port 8088 → tunnel)
Static marketing/landing page. No DB, no backend.

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
| moc-server-1 | moc-server (custom) | 3000 | Running (healthy) | Hono backend |
| moc-db-1 | pgvector/pgvector:pg16 | 5433 | Running (healthy) | PostgreSQL + pgvector |
| moc-falkordb-1 | falkordb/falkordb | 6380 | Running (healthy) | Knowledge graph store |
| moc-embedding | moc-embedding (custom) | 8004 | Running (healthy) | Embedding service (~3.5GB) |
| moc-worker | moc-worker (custom) | (internal) | Running | Background work |
| moc-graph-consolidator | moc-graph-consolidator | 8006 | Running (healthy) | Graph maintenance |

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
- Daily backup at 2am: `~/docker/moc/backup-db.sh`
- Backups kept 7 days: `~/docker/moc/backups/`

**AI Integration:**
- Codex CLI v2.1.74 inside moc-server container
- Auth: `CLAUDE_CODE_OAUTH_TOKEN` env var (valid 1 year, expires ~April 2027)
- Token set in docker-compose.prod.yml server service environment

**Environment file:** `~/docker/moc/.env` (chmod 600)
- DB_PASSWORD, GROQ_API_KEY, CORS_ORIGINS, CLAUDE_MODEL, etc.

**To redeploy after code changes:**
```bash
# On the server
cd ~/docker/moc
git pull
docker compose -f docker-compose.prod.yml build server memory
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

**Public URL:** https://xd.prsnl.fyi (intended; primarily used via Tailscale + Discord digest)
**Deployed:** 2026-05-14
**Repo:** github.com/PranavSlathia/XD
**Server path:** ~/docker/domain-hunter/
**Compose:** ~/docker/domain-hunter/compose.yml (profiles: foundation / api / workers / all)
**Deploy mode:** Self-hosted GitHub Actions runner on the Dell (`actions.runner.PranavSlathia-XD.dh-dell`). Every push to `main` rebuilds `dh-api` and restarts it.

Self-hosted expired-domain discovery + scoring pipeline. Ingest GitHub README citations → DNS NXDOMAIN filter → Open PageRank enrich → RDAP availability → Wayback CDX → composite scoring → daily Discord digest.

| Container | Image | Port | Status |
|-----------|-------|------|--------|
| dh-api | domain-hunter-dh-api | 8007 | FastAPI HTTP API |
| dh-web | domain-hunter-dh-web | 8005 | Operator dashboard |
| dh-scheduler | domain-hunter-dh-scheduler | — | APScheduler cron jobs (digest) |
| dh-worker-a2 | domain-hunter-dh-worker-a2 | — | GitHub README ingest |
| dh-worker-rdap | domain-hunter-dh-worker-rdap | — | DNS + OPR + RDAP enrich |
| dh-worker-wayback | domain-hunter-dh-worker-wayback | — | Wayback CDX |
| dh-worker-classifier | domain-hunter-dh-worker-classifier | — | Codex CLI safety classifier |
| dh-worker-scoring | domain-hunter-dh-worker-scoring | — | Composite scoring v3 |
| dh-pg | pgvector/pgvector:pg16 | 5436 | Postgres + pgvector |
| dh-redis | redis:7-alpine | 6381 | Worker queue + pub/sub |

**Env file:** `~/docker/domain-hunter/.env` (chmod 600) — see repo README for the required keys (DH_GITHUB_TOKEN, DH_OPENPAGERANK_API_KEY, DH_WHOISJSON_API_KEY, DH_DISCORD_WEBHOOK_URL, DH_SENTRY_DSN, etc.).

**External integrations wired:** Open PageRank (DomCop), WhoisJSON, Discord webhook, GlitchTip (Sentry-compatible) via `DH_SENTRY_DSN`.

---

### 3. GlitchTip (self-hosted error tracking)

**Access:** Tailscale-only at http://100.103.66.92:8011 (no Cloudflare route)
**Deployed:** 2026-05-17 (~9 days ago)
**Server path:** ~/docker/domain-hunter/glitchtip-compose.yml (cohabits dh project dir)
**Env file:** ~/docker/domain-hunter/.glitchtip.env

| Container | Image | Port | Status |
|-----------|-------|------|--------|
| gt-web | glitchtip/glitchtip:latest | 8011 | Web UI + API |
| gt-worker | glitchtip/glitchtip:latest | — | Celery worker |
| gt-pg | postgres:16 | (internal 5432) | Event/issue store |
| gt-redis | redis:7-alpine | (internal 6379) | Celery broker |

Sentry-compatible — any service using the Sentry SDK can ship events here by setting its DSN. Used by Domain Hunter (`DH_SENTRY_DSN`).

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
- Kernel: 6.8.0-107-generic
- Docker: v29.3.1
- Node.js: v22.22.2
- Codex CLI: v2.1.92
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
Public access:
  22/tcp    → SSH (key-only, fail2ban)
  80/tcp    → HTTP (Cloudflare-only in practice)
  443/tcp   → HTTPS (Cloudflare-only in practice)

  Note: project ports are NOT publicly exposed via UFW — public traffic
  arrives via Cloudflare Tunnel (outbound-only), which connects to
  localhost:<port> inside the host. Audit `sudo ufw status` before opening
  any new public port.

LAN + Tailscale (192.168.1.0/24 + 100.64.0.0/10):
  3001  → Uptime Kuma
  5001  → Dockge
  8081  → pgweb
  9443  → Portainer
  9999  → Dozzle

Tailscale only (100.64.0.0/10):
  8011  → GlitchTip
  19999 → Netdata

Internal Docker networks only (no host binding or LAN-only):
  dh-pg (5436), dh-redis (6381), gt-pg, gt-redis,
  moc-db (5433), moc-falkordb (6380), moc-embedding (8004)
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
- Admin dashboards restricted to LAN + Tailscale (not public internet)
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

## Developer Tools on Server

| Tool | Version | Path | Purpose |
|------|---------|------|---------|
| code-review-graph | 2.1.0 | ~/.local/bin/code-review-graph | Structural codebase graph via MCP (22 tools) |
| Codex CLI | 2.1.92 | ~/.local/bin/Codex | AI coding assistant |
| Gemini CLI | 0.36.0 | /usr/bin/gemini | Google AI assistant |
| Codex CLI | 0.118.0 | /usr/bin/codex | OpenAI coding assistant |
| GitHub CLI | 2.45.0 | /usr/bin/gh | GitHub operations |

## Auth Tokens on Server

| Service | Method | Location | Expiry |
|---------|--------|----------|--------|
| Codex | OAuth token | `~/.bashrc` + `/etc/environment` + compose env | ~April 2027 |
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
| `/etc/sudoers.d/pronav` | Passwordless sudo |
| `~/docker/docker-compose.yml` | Infrastructure compose stack |
| `~/docker/moc/docker-compose.prod.yml` | MOC project compose |
| `~/docker/moc/.env` | MOC environment variables |
| `~/docker/moc/backup-db.sh` | MOC DB backup script |

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
9. **Set up backup cron** if project has a database
10. **Update this document** — add to Port Registry and Deployed Projects sections

## Troubleshooting

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

| Resource | Total | Used | Available | Notes (as of 2026-05-26) |
|----------|-------|------|-----------|--------------------------|
| RAM | 7.7 GB | ~4.8 GB | ~2.9 GB | MOC ~3.5GB · DH ~0.8GB · GT ~0.5GB · infra ~0.4GB · swap 2GB used |
| Disk | 218 GB | ~41 GB | ~167 GB | Docker images 16GB · volumes 7.4GB · build cache 10GB |
| CPU | 2 cores | load avg ~2.0 | At capacity | Celeron is the real bottleneck |

When adding projects, budget ~500MB-2GB RAM per project depending on stack. RAM is now the tightest resource — adding another data-heavy project will likely require offloading something else.

## Cloudflare Tunnel Routes

Single tunnel (`moc`), config at `/etc/cloudflared/config.yml`:

| Hostname | → Local | Container |
|----------|---------|-----------|
| prsnl.fyi | localhost:8088 | prsnl-landing |
| www.prsnl.fyi | localhost:8088 | prsnl-landing |
| moc.prsnl.fyi | localhost:5173 | moc-web |
| xd.prsnl.fyi | localhost:8005 | dh-web |

GlitchTip is intentionally Tailscale-only (no tunnel route).
