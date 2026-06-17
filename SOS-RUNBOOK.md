# Dell Server SOS Runbook

This is the break-glass guide for the Dell home server (`prsnl`). Use it when SSH, public sites, Docker, backups, or admin dashboards are not behaving.

It intentionally contains no secrets. If a command needs credentials, read them from the live server's protected env files.

## Golden Rules

- Do not open database, Redis, admin UI, or worker ports to the public internet.
- Docker-published ports must bind to `127.0.0.1` for tunnel-only services or `100.103.66.92` for Tailscale-only services. Do not rely on UFW alone to protect Docker-published ports.
- Public HTTP/S traffic should enter through Cloudflare Tunnel, not router port forwarding.
- Do not commit `.env`, backup archives, database dumps, token files, or `*.bak*` files.
- Before claiming an outage is fixed, verify the user-facing URL or service health, not just that a process restarted.

## First 5 Minutes

From the Mac:

```bash
ssh pronav@192.168.1.18
ssh pronav@100.103.66.92
./scripts/health-check.sh tailscale
```

On the server:

```bash
uptime
free -h
df -h /
systemctl --failed
sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
sudo ufw status numbered
```

If the host is reachable, capture the current state before restarting anything:

```bash
sudo journalctl -p warning..alert --since "30 min ago" --no-pager
sudo docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

## Access Recovery

Known-good access paths:

```bash
ssh pronav@100.103.66.92
ssh pronav@192.168.1.18
ssh breakglass@100.103.66.92
ssh breakglass@192.168.1.18
```

`breakglass` is a local sudo admin for emergencies only. Keep its password outside this repo and
do not print it into logs. The live recovery note is:

```bash
/home/pronav/server-recovery/PRSNL_RECOVERY.md
```

Tailscale SSH is intentionally disabled on `prsnl`; keep normal OpenSSH working over the
Tailscale IP because deploy agents use `ssh pronav@100.103.66.92` non-interactively.

Current network priority is Ethernet-first, WiFi-fallback:

- `enp7s0`: DHCP, optional, route metric `100`
- `wlp6s0`: static `192.168.1.18`, default route metric `600`

If local SSH and Tailscale SSH both fail:

1. Check power and the physical laptop.
2. Check WiFi/router status.
3. If Ethernet is available, plug it in and retry `ssh pronav@192.168.1.18` after the router assigns a lease.
4. Use keyboard/monitor access if possible.
5. If the machine shows Windows Boot Manager, PXE/Realtek network boot, or "required device is not connected", power down and reseat the internal SSD before changing software.
6. Use a wired USB keyboard for BIOS/GRUB/recovery. Bluetooth keyboards are not reliable before Ubuntu boots.
7. After login, check:

```bash
ip -4 addr
sudo systemctl status ssh --no-pager
sudo systemctl status tailscaled --no-pager
sudo systemctl status docker --no-pager
```

If local SSH works but Tailscale does not:

```bash
sudo systemctl status tailscaled --no-pager
tailscale status
tailscale ip
sudo systemctl restart tailscaled
```

Verify Tailscale SSH stayed disabled:

```bash
tailscale debug prefs | grep -i '"RunSSH"'
```

Expected: `"RunSSH": false`.

If SSH is refusing key auth, inspect the effective SSH config before editing:

```bash
sudo sshd -T | grep -Ei 'passwordauthentication|permitrootlogin|pubkeyauthentication|authorizedkeysfile'
sudo journalctl -u ssh --since "30 min ago" --no-pager
sudo fail2ban-client status sshd
```

## Public Site Recovery

Check public URLs first:

```bash
for u in https://prsnl.fyi https://www.prsnl.fyi https://moc.prsnl.fyi https://xd.prsnl.fyi; do
  curl -sk -o /dev/null -w "$u %{http_code}\n" "$u"
done
```

Then check the local origins on the server:

```bash
curl -fsS http://127.0.0.1:8088/ >/dev/null && echo landing-ok
curl -fsS http://127.0.0.1:5173/ >/dev/null && echo moc-web-ok
curl -fsS http://127.0.0.1:8005/ >/dev/null && echo dh-web-ok
sudo systemctl status cloudflared --no-pager
sudo journalctl -u cloudflared --since "30 min ago" --no-pager
```

If the local origin is healthy but the public URL is down, restart only Cloudflare Tunnel:

```bash
sudo systemctl restart cloudflared
sleep 10
sudo systemctl status cloudflared --no-pager
```

If the local origin is not healthy, fix the relevant container first and leave `cloudflared` alone.

## Docker Recovery

Use the owning compose directory. Do not recreate unrelated stacks.

| Area | Compose path |
|------|--------------|
| Shared infra | `~/docker/docker-compose.yml` |
| Dockge | `~/docker/dockge/docker-compose.yml` |
| pgweb | `~/docker/pgweb/docker-compose.yml` |
| MOC prod stack | `~/docker/moc/docker-compose.prod.yml` |
| MOC fallback/graph stack | `~/docker/moc/docker-compose.yml` |
| Domain Hunter | `~/docker/domain-hunter/compose.yml` |
| GlitchTip | `~/docker/domain-hunter/glitchtip-compose.yml` |
| Landing page | `~/docker/landing/` |

Typical flow:

```bash
sudo docker logs --tail 100 CONTAINER
sudo docker inspect CONTAINER --format '{{json .State.Health}}'
cd ~/docker/PROJECT
docker compose -f COMPOSE.yml config -q
docker compose -f COMPOSE.yml up -d SERVICE
```

If a container was recreated for port binding or image pinning, verify it returned healthy and that the published address is still private:

```bash
sudo docker ps --filter name=CONTAINER --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

## Port Exposure Audit

Run this after any compose or Docker networking change:

```bash
sudo ss -tulpen | awk 'NR==1 || /docker-proxy/ {print $1, $2, $5, $7}'
sudo docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

Expected Docker-published local addresses:

- `127.0.0.1` for Cloudflare-origin or host-local services.
- `100.103.66.92` for Tailscale-only dashboards and admin services.
- No Docker-published service should bind to local `0.0.0.0`.

Probe from the Mac when validating LAN exposure:

```bash
for p in 3001 5001 5678 8000 8004 8006 8007 8011 8081 9443 9999 19999; do
  nc -vz -G 2 192.168.1.18 "$p"
done
```

Expected result: public/admin/internal project ports should fail from LAN unless intentionally served through Cloudflare or Tailscale.

## Backup Checks

MOC uses restic through `moc-backup.timer` and `moc-backup.service`.

```bash
systemctl list-timers 'moc-backup*'
systemctl status moc-backup.service --no-pager
systemctl show moc-backup.service -p ActiveEnterTimestamp -p Result -p ExecMainStatus
sudo journalctl -u moc-backup.service -n 100 --no-pager
```

Weekly maintenance checks the service freshness. If it reports stale backups, confirm whether the timer ran before changing scripts.

Restore rule: perform a restore drill into a new temporary database/container first. Do not overwrite the production volume as the first recovery step.

## Git And Rollback

Before changing a live app repo on the server:

```bash
cd ~/docker/moc && git status --short --branch
cd ~/docker/domain-hunter && git status --short --branch
```

Do not discard someone else's live changes. If a compose edit needs rollback and a timestamped backup exists, inspect it first:

```bash
ls -lt *.bak* */*.bak* 2>/dev/null
diff -u CURRENT_FILE BACKUP_FILE
```

Then restore deliberately, validate the compose file, and restart only the affected service:

```bash
cp BACKUP_FILE CURRENT_FILE
docker compose -f COMPOSE.yml config -q
docker compose -f COMPOSE.yml up -d SERVICE
```

## Disk Pressure

Check before pruning:

```bash
df -h /
sudo docker system df
sudo du -xh /var/lib/docker --max-depth=1 | sort -h
```

Low-risk cleanup:

```bash
sudo docker builder prune -f
sudo journalctl --vacuum-time=14d
```

Avoid `docker system prune -a` during an incident unless you have confirmed no needed image rollback will be lost.

## Known Residual Items

- Netdata still runs from its existing raw Docker setup. Its port is Tailscale-protected; convert it to managed compose before trying to pin it.
- Historical Cloudflare or container log errors can remain noisy after a fix. Prefer fresh `--since` windows for incident verification.
- Some live application repos can be dirty because deployment agents edit compose files on the server. Treat those as live operational changes, not disposable local noise.
