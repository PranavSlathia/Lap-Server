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
| 8080 | Watchtower | watchtower | Internal | Health check only |
| 9443 | Portainer | portainer | LAN + Tailscale | Docker management |
| 9999 | Dozzle | dozzle | LAN + Tailscale | Log viewer |
| 19999 | Netdata | netdata | Tailscale only | System metrics |

### Project Ports

| Port | Project | Service | Container | Access | Compose File |
|------|---------|---------|-----------|--------|-------------|
| 3000 | MindOverChatter | Hono backend API | moc-server | Public (via tunnel) | ~/docker/moc/docker-compose.prod.yml |
| 5173 | MindOverChatter | React frontend (nginx) | moc-web | Public (via tunnel) | standalone docker run |
| 5432 | MindOverChatter | PostgreSQL + pgvector | moc-db | Internal only | ~/docker/moc/docker-compose.prod.yml |
| 8004 | MindOverChatter | Mem0 memory service | moc-memory | Internal only | ~/docker/moc/docker-compose.prod.yml |

### Available Port Ranges for New Projects

| Range | Suggested Use |
|-------|--------------|
| 3100-3199 | Web backends |
| 4000-4999 | APIs |
| 5174-5199 | Frontends |
| 5433-5499 | Databases |
| 6000-6999 | Misc services |
| 7000-7999 | Misc services |
| 8100-8999 | Python/ML services |

---

## Deployed Projects

### 1. MindOverChatter (MOC)

**Public URL:** https://moc.prsnl.fyi
**Deployed:** 2026-04-06
**Repo:** github.com/PranavSlathia/MindOverChatter
**Server path:** ~/docker/moc/
**Compose:** ~/docker/moc/docker-compose.prod.yml

| Container | Image | Port | Status | RAM |
|-----------|-------|------|--------|-----|
| moc-web | nginx:alpine | 5173 | Running | ~50MB |
| moc-server | moc-server (custom) | 3000 | Running (healthy) | ~200MB |
| moc-db | pgvector/pgvector:pg16 (SHA pinned) | 5432 (internal) | Running (healthy) | ~500MB |
| moc-memory | moc-memory (custom) | 8004 (internal) | Running (healthy) | ~1.6GB |

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
- Claude Code CLI v2.1.74 inside moc-server container
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
Public access:
  22/tcp    → SSH
  80/tcp    → HTTP (Cloudflare)
  443/tcp   → HTTPS (Cloudflare)
  3000/tcp  → MOC backend
  5173/tcp  → MOC frontend

LAN only (192.168.1.0/24):
  9443  → Portainer
  9999  → Dozzle
  3001  → Uptime Kuma

Tailscale only (100.64.0.0/10):
  9443  → Portainer
  9999  → Dozzle
  3001  → Uptime Kuma
  19999 → Netdata

Closed (internal Docker network only):
  5432  → PostgreSQL
  8004  → Mem0 memory service
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
| portainer | portainer/portainer-ce:lts | Docker management UI | always |
| uptime-kuma | louislam/uptime-kuma:1 | Uptime monitoring | always |
| dozzle | amir20/dozzle:latest | Docker log viewer | always |
| watchtower | containrrr/watchtower | Auto-update containers | always |
| autoheal | willfarrell/autoheal | Restart unhealthy containers | always |
| netdata | netdata/netdata | Real-time system monitoring | always |

Infrastructure compose: `~/docker/docker-compose.yml`

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

| Resource | Total | Used | Available | Notes |
|----------|-------|------|-----------|-------|
| RAM | 7.7 GB | ~2.8 GB | ~4.9 GB | MOC uses ~2.3GB, infra ~0.5GB |
| Disk | 218 GB | ~21 GB | ~186 GB | MOC images + data ~12GB |
| CPU | 2 cores | Low avg load | Comfortable | Celeron is slow but handles current load |

When adding projects, budget ~500MB-2GB RAM per project depending on stack.
