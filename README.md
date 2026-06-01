# Lap-Server

A Dell Vostro laptop turned into a personal home server. Runs Ubuntu Server 24.04 LTS, hosts personal projects via Cloudflare Tunnel, and is managed remotely from anywhere via Tailscale VPN.

This repo is the **management layer** — documentation, config snapshots, and helper scripts. The server itself lives in a corner with the lid closed, plugged in, doing its job.

---

## Why a laptop?

Old laptops are perfect home servers:

- **Free** — repurpose hardware that's gathering dust instead of paying for a VPS.
- **Built-in UPS** — the battery keeps it alive through power blips.
- **Quiet, low-power** — sips ~20W of electricity, sits silently with the lid closed.
- **Real hardware** — not a Raspberry Pi; runs full x86 Docker images, ML services, databases.

This particular Dell Vostro has an Intel Celeron 2957U (1.4GHz, 2 cores), 8GB RAM, and a Kingston A400 240GB SSD. Modest, but plenty for a single-user app stack.

---

## Architecture

```
                ┌─────────────────────────────────────────────┐
                │            Public Internet                  │
                └──────────────────┬──────────────────────────┘
                                   │
                                   ▼
                        ┌──────────────────────┐
                        │   Cloudflare Edge    │  (HTTPS termination,
                        │   *.prsnl.fyi        │   DDoS, caching)
                        └──────────┬───────────┘
                                   │ Cloudflare Tunnel
                                   │ (outbound-only,
                                   │  no port forwarding)
                                   ▼
   ┌────────────────────────────────────────────────────────────────────────┐
   │  Dell Vostro — Ubuntu Server 24.04 (hostname: prsnl)                   │
   │                                                                        │
   │  ┌──────────────────────────────────────────────────────────────────┐  │
   │  │  cloudflared (systemd) — public ingress                          │  │
   │  │    prsnl.fyi, www.prsnl.fyi → :8088  (prsnl-landing nginx)       │  │
   │  │    moc.prsnl.fyi           → :5173  (MOC web)                    │  │
   │  │    xd.prsnl.fyi            → :8005  (Domain Hunter web)          │  │
   │  └─────────────────────────┬────────────────────────────────────────┘  │
   │                            │                                           │
   │  ┌─────────────────────────▼────────────────────────────────────────┐  │
   │  │  Docker (live-restore, log rotation 10MB×3)                      │  │
   │  │                                                                  │  │
   │  │  Project: MindOverChatter (~/docker/moc/)                        │  │
   │  │    moc-web → moc-server → moc-db (pgvector)                      │  │
   │  │            ↘ moc-embedding · moc-worker · moc-graph-consolidator │  │
   │  │            ↘ moc-falkordb                                        │  │
   │  │                                                                  │  │
   │  │  Project: Domain Hunter (~/docker/domain-hunter/)                │  │
   │  │    dh-api · dh-web · dh-scheduler                                │  │
   │  │    dh-worker-{a2,rdap,wayback,classifier,scoring}                │  │
   │  │    dh-pg (pgvector) · dh-redis                                   │  │
   │  │                                                                  │  │
   │  │  Project: GlitchTip (~/docker/domain-hunter/glitchtip-compose)   │  │
   │  │    gt-web · gt-worker · gt-pg · gt-redis (error tracking, all)   │  │
   │  │                                                                  │  │
   │  │  Project: prsnl-landing (~/docker/landing/)                      │  │
   │  │    prsnl-landing (nginx) — public marketing page                 │  │
   │  │                                                                  │  │
   │  │  Project: n8n (~/docker/n8n/) — workflow automation              │  │
   │  │    n8n + external runners + Postgres, pinned 2.22.6, TS :5678    │  │
   │  │                                                                  │  │
   │  │  Infra (shared, in ~/docker/docker-compose.yml):                 │  │
   │  │    Portainer · Dockge · Uptime Kuma · Dozzle · Netdata           │  │
   │  │    Watchtower · Autoheal · pgweb                                 │  │
   │  └──────────────────────────────────────────────────────────────────┘  │
   │                                                                        │
   │  Hardening: UFW · fail2ban · SSH key-only · unattended-upgrades       │
   └────────────────────────────────────────────────────────────────────────┘
                         ▲                          ▲
                         │ SSH (key auth)           │ Tailscale VPN
                         │                          │ (100.103.66.92)
                ┌────────┴──────────┐      ┌────────┴─────────┐
                │   Mac Mini        │      │   MacBook Air,    │
                │   (home WiFi)     │      │   iPhone (anywhere)│
                └───────────────────┘      └───────────────────┘
```

### How traffic flows

- **Public users** → `https://<sub>.prsnl.fyi` → Cloudflare Edge → Tunnel → host's `cloudflared` → respective nginx/web container on a private port.
- **Admin (you)** → SSH or Tailscale → host directly → dashboards and admin services bound to Tailscale or reachable through SSH tunnels.

No port forwarding on your home router. Cloudflare Tunnel makes the connection outbound-only.

---

## Remote management

The server has **no public-facing admin ports**. To manage it:

```bash
# From home WiFi
ssh pronav@192.168.1.18

# From anywhere in the world (Tailscale VPN)
ssh pronav@100.103.66.92
```

**Tailscale** is what makes this possible — it creates a private mesh network across your devices (Mac Mini, MacBook Air, iPhone, the server). Each device gets a stable `100.x.x.x` IP that works regardless of which WiFi you're on. No VPN passwords, no port forwards, no dynamic DNS.

Once on the Tailscale network, all dashboards become reachable:

| Service | URL | Purpose |
|---------|-----|---------|
| Portainer | https://100.103.66.92:9443 | Docker container management |
| Uptime Kuma | http://100.103.66.92:3001 | Monitor app/service uptime |
| Dozzle | http://100.103.66.92:9999 | Live tail Docker logs |
| Netdata | http://100.103.66.92:19999 | Real-time CPU/RAM/disk/network metrics |
| n8n | http://100.103.66.92:5678 | Workflow automation (set up the owner account on first visit) |

---

## How projects are deployed

Every project follows the same pattern:

1. **Code lives at** `~/docker/<project-name>/` on the server (cloned from GitHub via `gh`)
2. **Each project has its own** `docker-compose.prod.yml` and `.env` (with `chmod 600`)
3. **All containers use** `restart: always` so they survive reboots
4. **Database ports stay internal** to the Docker network — never exposed to the host
5. **Public exposure** happens via Cloudflare Tunnel, not by opening firewall ports
6. **Backups** run daily via systemd timers where available; MOC uses `moc-backup.timer` + restic, while new database projects should get an explicit backup timer and monitor.

See `CLAUDE.md` for the full **Port Registry** before assigning new ports — no conflicts allowed across projects.

---

## Adding a new project

```bash
# 1. SSH in
ssh pronav@192.168.1.18

# 2. Clone your repo (gh CLI is already authed)
gh repo clone <owner>/<repo> ~/docker/<project>

# 3. Create .env (chmod 600)
cd ~/docker/<project>
nano .env  # add DB passwords, API keys, etc.
chmod 600 .env

# 4. Pick unused ports from CLAUDE.md → Port Registry
# 5. Build and start
docker compose -f docker-compose.prod.yml up -d

# 6. Open ports in UFW only if needed (prefer Tailscale-only for admin UIs)
sudo ufw allow from 100.64.0.0/10 to any port <PORT>  # Tailscale-only

# 7. Add Cloudflare Tunnel route for public access
cloudflared tunnel route dns <tunnel-name> <subdomain>.prsnl.fyi
# Edit /etc/cloudflared/config.yml to add the ingress rule
sudo systemctl restart cloudflared

# 8. Add Uptime Kuma monitor for the health endpoint
# 9. Set up a backup timer if there's a database
# 10. Update CLAUDE.md with the new ports + project section
```

A more detailed walkthrough lives in `AGENT-BRIEFING.md` — designed for AI agents but works for humans too.

---

## Repo structure

```
Lap-Server/
├── README.md              You are here
├── CLAUDE.md              Full reference: port registry, deployed projects, troubleshooting
├── AGENTS.md              Codex/agent operating guide, kept aligned with CLAUDE.md
├── AGENT-BRIEFING.md      Quick context for AI agents deploying to this server
├── SOS-RUNBOOK.md         Break-glass incident and recovery guide
├── docs/
│   ├── N8N-ARCHITECTURE.md   Detailed n8n runtime, security, Quip, and ntfy decisions
│   └── N8N-INTEGRATION-SHORTLIST.md   Yay/nay backlog for n8n nodes, helpers, and templates
├── configs/               Sanitized snapshots of server config files
│   ├── docker-daemon.json
│   ├── fail2ban-jail.local
│   ├── netplan.yaml.example   (template — fill in your WiFi creds locally)
│   ├── sysctl-server.conf
│   └── unattended-upgrades.conf
├── docker/
│   ├── docker-compose.yml     Infrastructure stack (Portainer, monitoring, etc.)
│   └── n8n/
│       └── docker-compose.yml n8n workflow automation (+ Postgres); secrets in .env on the server
└── scripts/
    ├── health-check.sh           Run a full server health check via SSH
    ├── deploy-compose.sh         Deploy docker-compose to the server
    └── weekly-maintenance.sh     Comprehensive Sunday maintenance — runs as root cron, checks restic backup freshness, posts GitHub issue on warnings/critical
```

---

## What's running right now

| Project | URL | Stack |
|---------|-----|-------|
| prsnl-landing | https://prsnl.fyi | nginx static landing page |
| MindOverChatter | https://moc.prsnl.fyi | React + Hono + PostgreSQL+pgvector + embedding + graph consolidator + FalkorDB |
| Domain Hunter | https://xd.prsnl.fyi (Tailscale-only in practice) | FastAPI + SQLAlchemy + Postgres+pgvector + Redis + 5 workers |
| GlitchTip | Tailscale: http://100.103.66.92:8011 | Self-hosted Sentry-compatible error tracking |
| n8n | Tailscale: http://100.103.66.92:5678 | Workflow automation (n8n 2.22.6 + external runners + native Python runner + Postgres + metrics) |

Detailed n8n notes live in `docs/N8N-ARCHITECTURE.md`; candidate add-ons and external templates are tracked in `docs/N8N-INTEGRATION-SHORTLIST.md`.

---

## Quick start

```bash
# Clone this repo
git clone git@github.com:PranavSlathia/Lap-Server.git
cd Lap-Server

# Run a health check on the server
./scripts/health-check.sh           # from home WiFi
./scripts/health-check.sh tailscale # from anywhere
```

For outages or recovery work, start with `SOS-RUNBOOK.md`.

Then read `CLAUDE.md` for everything else.
