# Agent Guide

This repo's durable source of truth is `CLAUDE.md`. Read it first before changing
ports, compose files, firewall posture, or recovery docs.

For incidents and recovery work, start with `SOS-RUNBOOK.md`.

## Access

```bash
ssh pronav@192.168.1.18
ssh pronav@100.103.66.92
```

- `pronav` uses SSH key auth and passwordless sudo.
- `breakglass` is a local sudo fallback user with copied SSH public keys. Use it only for access recovery.
- Keep the `breakglass` password outside this repo.
- Tailscale SSH is intentionally disabled because it can add browser approval to `ssh pronav@100.103.66.92` and interrupt deploy agents.

Live recovery note on the server:

```bash
/home/pronav/server-recovery/PRSNL_RECOVERY.md
```

## Operating Rules

- Do not expose admin, database, Redis, Docker, or worker ports publicly.
- Bind Docker-published ports explicitly to `127.0.0.1` or `100.103.66.92`.
- Use Cloudflare Tunnel for public HTTP/S, not router port forwarding.
- Check `CLAUDE.md` before assigning any port.
- Treat `~/docker/*/.env`, backup archives, DB dumps, token files, and `*.bak*` files as secrets or operational state; never commit them.
- Before overwriting a live compose file, use `scripts/deploy-compose.sh --dry-run`.
- Preserve normal OpenSSH over the Tailscale IP; do not enable Tailscale SSH unless the deploy workflow has been explicitly redesigned.

## Common Commands

```bash
./scripts/health-check.sh tailscale
./scripts/deploy-compose.sh infra tailscale --dry-run
./scripts/deploy-compose.sh n8n tailscale --dry-run
```

For the current port registry, deployed projects, Cloudflare routes, backup model,
and known retired components, read `CLAUDE.md`.
