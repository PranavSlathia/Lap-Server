# Dell Home Server — Agent Briefing

You are working on a project that will be deployed to Pronav's home server. Read this document before doing anything.

## The Server

A Dell Vostro laptop running Ubuntu Server 24.04 LTS, repurposed as a development/staging server. It sits at Pronav's home, lid closed, connected via WiFi.

- **Hostname:** prsnl
- **OS:** Ubuntu Server 24.04 LTS (minimized install)
- **CPU:** Intel Celeron 2957U @ 1.4GHz (2 cores, 2 threads) — it's slow, optimize accordingly
- **RAM:** 8 GB total (7.7 GB usable; check `free -h` before adding heavy services)
- **Disk:** 240GB Kingston SSD (218GB usable; check `df -h /` before large image pulls)
- **Docker:** v29.5.2 — ALL apps run as Docker containers, no bare-metal installs

## Port Registry — CHECK BEFORE USING ANY PORT

| Port | Used By | Access |
|------|---------|--------|
| 22 | SSH | Public |
| 80, 443 | Cloudflare | Public |
| 3000 | MOC backend | Localhost only |
| 3001 | Uptime Kuma | Tailscale only |
| 5001 | Dockge | Tailscale only |
| 5173 | MOC frontend | Public via Cloudflare Tunnel |
| 5433 | MOC PostgreSQL | Internal only |
| 5678 | n8n (workflow automation) | Tailscale + localhost |
| 6006 | Phoenix LLM traces | Tailscale only |
| 8004 | MOC embedding | Localhost only |
| 8006 | MOC graph consolidator | Localhost only |
| 8007 | Domain Hunter API | Localhost only |
| 8081 | pgweb | Tailscale only |
| 8090 | n8n public basic-auth gate | Localhost tunnel origin |
| 8790 | Quip agents bridge | n8n-net only via UFW |
| 9443 | Portainer | Tailscale only |
| 9999 | Dozzle | Tailscale only |
| 19999 | Netdata | Tailscale only |

**Available ranges:** 3100-3199, 4000-4999, 5174-5435, 5437-5499, 6000-6379, 6382-7999, 8012-8999

For n8n-specific runtime, security, Quip/WhatsApp, and ntfy decisions, read `docs/N8N-ARCHITECTURE.md` before changing `~/docker/n8n/`.

## How to Access

```bash
# From Pronav's home network
ssh pronav@192.168.1.18

# From anywhere (via Tailscale VPN)
ssh pronav@100.103.66.92
```

- User: `pronav`
- Auth: SSH key (no password needed)
- Sudo: passwordless (`sudo` just works, no password prompt)
- Breakglass fallback: `breakglass` is a local sudo user with the same SSH public keys as `pronav`.
  Use it only if `pronav` auth is broken. Do not commit or print its password.
- Tailscale SSH is intentionally disabled. Leave normal OpenSSH on `100.103.66.92` alone because
  deploy agents use it non-interactively.

## Networking

| Method | IP | When to use |
|--------|-----|------------|
| Local WiFi | 192.168.1.18 | When on same network (Airtel_renu_8079) |
| Tailscale | 100.103.66.92 | When remote or unsure |

- **Firewall (UFW) is active.** Public SSH is open; admin dashboards are Tailscale-only.
- Docker-published ports must bind explicitly to `127.0.0.1` or `100.103.66.92`. Do not rely on UFW alone for Docker port exposure.
- If your service needs a new admin port, prefer a Tailscale-IP bind over adding a broad UFW allow rule.
- **Upload bandwidth:** ~42 Mbps (WiFi). Not a datacenter — fine for dev, not for high-traffic production.

## How to Deploy

Everything runs in Docker. The main compose file is at `~/docker/docker-compose.yml` on the server.

### To add a new service:

1. **Add it to the docker-compose.yml** on the server (or create a separate compose file in `~/docker/`)
2. **Run:** `cd ~/docker && sudo docker compose up -d`
3. **Bind host ports explicitly** to `127.0.0.1` for tunnel-only services or `100.103.66.92` for Tailscale-only services
4. Containers must have an explicit restart policy (`always` for core infra; `unless-stopped` for intentionally operator-managed app sidecars)

### To deploy a custom app (e.g., FastAPI backend):

1. Clone the repo on the server OR build the Docker image locally and push to a registry
2. Add it to docker-compose.yml with appropriate ports and volumes
3. For persistent data (databases, uploads), use named Docker volumes — NOT bind mounts to random paths

### Example compose entry for a FastAPI app:

```yaml
services:
  my-backend:
    build: /home/pronav/my-app
    container_name: my-backend
    restart: always
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/mydb
    depends_on:
      - postgres

  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: always
    expose:
      - "5432"
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=mydb
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

## What's Already Running

| Container | Port | Purpose |
|-----------|------|---------|
| portainer | 9443 | Docker management UI |
| uptime-kuma | 3001 | Uptime monitoring |
| dozzle | 9999 | Live Docker log viewer |
| watchtower | — | Auto-updates container images daily |
| autoheal | — | Auto-restarts unhealthy containers |

Do NOT remove or modify these containers. They are infrastructure.

## Important Constraints

### Performance
- **CPU is weak** (1.4GHz Celeron). Avoid CPU-heavy operations. Use `--cpus` limits in Docker if needed, and treat sustained 15-minute load above ~3.0 as a capacity warning.
- **RAM is limited** (8GB shared across everything). Keep containers lean. Use Alpine-based images where possible. Monitor with `free -h`.
- **Disk is 240GB total.** Don't pull massive Docker images unnecessarily. Clean up with `docker system prune` periodically.

### Reliability
- This is a home server, NOT a datacenter. Power cuts and WiFi drops can happen.
- All containers must have an explicit restart policy. Use `restart: always` for core infra and `restart: unless-stopped` only when manual stop semantics matter.
- Store important data in Docker volumes (they survive container recreation).
- Add a systemd backup timer for every database; MOC uses `moc-backup.timer` + restic.
- The server auto-reboots at 4:00 AM if a kernel update requires it.
- Watchtower auto-updates container images daily — if you need to pin a version, specify it explicitly (e.g., `postgres:16-alpine`, not `postgres:latest`).

### Security
- Fail2ban protects SSH (5 failed attempts = 1 hour ban).
- UFW firewall is active — don't disable it.
- Don't expose database ports (5432, 27017, 6379) to the internet via Cloudflare Tunnel. Keep them internal.
- Use environment variables for secrets, never hardcode in compose files.

### Networking
- The server gets a static IP (192.168.1.18) on WiFi but has no public IP.
- Ethernet `enp7s0` is configured as the preferred network when plugged in; WiFi `wlp6s0` is the
  fallback. Netplan route metrics are Ethernet `100`, WiFi `600`, and Ethernet is optional so
  boot does not hang without a cable.
- To expose services to the internet: use **Cloudflare Tunnel** to a localhost-bound service, not port forwarding.
- For dev/testing: access via SSH tunnel or Tailscale IP directly.
- For incidents and recovery work, start with this repo's `SOS-RUNBOOK.md`.

## File Locations on the Server

| Path | What |
|------|------|
| `~/docker/` | Docker compose files |
| `/etc/netplan/01-network.yaml` | Network config |
| `/home/pronav/server-recovery/PRSNL_RECOVERY.md` | Live recovery note written by `scripts/access-hardening.sh` |
| `/etc/docker/daemon.json` | Docker daemon config |
| `/etc/fail2ban/jail.local` | Fail2ban config |
| `/etc/sysctl.d/99-server.conf` | Kernel tuning |

## Health Check

Run this to verify the server is healthy:

```bash
ssh pronav@192.168.1.18 "echo '=== UPTIME ===' && uptime && echo '=== MEMORY ===' && free -h && echo '=== DISK ===' && df -h / && echo '=== DOCKER ===' && sudo docker ps --format 'table {{.Names}}\t{{.Status}}' && echo '=== SERVICES ===' && for s in ssh docker fail2ban wpa_supplicant ufw tailscaled cloudflared cron; do echo \"\$s: \$(sudo systemctl is-active \$s)\"; done"
```

## Questions?

If you need to know something not covered here, SSH into the server and investigate. You have full root access. If something breaks, start with `SOS-RUNBOOK.md`, then check Dozzle through Tailscale (port 9999) for container logs or run `journalctl -xe` for system logs.
