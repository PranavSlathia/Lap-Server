# Lap-Server — Dell Vostro Home Server

Management repo for a Dell Vostro laptop converted into an Ubuntu home server. Hosts personal projects (currently MindOverChatter at `https://moc.prsnl.fyi`).

## Contents

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Full server documentation, port registry, deployed projects, troubleshooting |
| `AGENT-BRIEFING.md` | Quick context briefing for AI agents deploying new projects to this server |
| `configs/` | Snapshots of server config files (sanitized — see `.example` versions) |
| `docker/docker-compose.yml` | Infrastructure compose stack (Portainer, Uptime Kuma, Dozzle, Watchtower, Autoheal) |
| `scripts/health-check.sh` | Run a full server health check via SSH |
| `scripts/deploy-compose.sh` | Deploy docker-compose to the server |

## Getting Started

```bash
# Clone
git clone git@github.com:PranavSlathia/Lap-Server.git
cd Lap-Server

# Health check (from home WiFi)
./scripts/health-check.sh

# Or via Tailscale
./scripts/health-check.sh tailscale
```

## Sensitive Files (Not in Git)

These files contain credentials and are in `.gitignore`. Recreate them locally on the server:

| File | Source |
|------|--------|
| `configs/netplan.yaml` | Use `configs/netplan.yaml.example` as template, fill in WiFi credentials |
| `~/docker/moc/.env` (on server) | Project-specific env vars (DB password, API keys, OAuth tokens) |

See `CLAUDE.md` for full details on what each file should contain.
