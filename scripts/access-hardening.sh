#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-pronav@100.103.66.92}"

echo "Target: $HOST"
echo "This preserves normal OpenSSH access, creates/updates the breakglass user,"
echo "writes /home/pronav/server-recovery/PRSNL_RECOVERY.md, and validates netplan."
echo "It does not enable Tailscale SSH because that can interrupt deploy SSH flows."
echo

read -r -s -p "New password for local breakglass user: " BG_PASS
echo
read -r -s -p "Retype password: " BG_PASS2
echo

if [[ -z "$BG_PASS" ]]; then
  echo "Breakglass password cannot be empty." >&2
  exit 1
fi

if [[ "$BG_PASS" != "$BG_PASS2" ]]; then
  echo "Passwords did not match." >&2
  exit 1
fi

quoted_pass="$(printf '%q' "$BG_PASS")"

ssh -o BatchMode=yes "$HOST" "sudo env BG_PASS=$quoted_pass bash -s" <<'REMOTE'
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

log "starting access hardening on $(hostname)"

log "ensuring OpenSSH is enabled"
systemctl enable --now ssh >/dev/null

if command -v tailscale >/dev/null 2>&1; then
  log "ensuring tailscaled is enabled"
  systemctl enable --now tailscaled >/dev/null 2>&1 || true

  # Keep normal OpenSSH on 100.103.66.92. Tailscale SSH can require browser
  # approval and break automated deploy commands that expect plain ssh.
  tailscale set --ssh=false >/dev/null 2>&1 || true
fi

log "creating/updating breakglass sudo user"
if ! id breakglass >/dev/null 2>&1; then
  adduser --disabled-password --gecos "Breakglass admin" breakglass >/dev/null
fi

printf 'breakglass:%s\n' "$BG_PASS" | chpasswd
usermod -aG sudo breakglass
passwd -u breakglass >/dev/null 2>&1 || true

log "copying pronav authorized_keys to breakglass"
if [[ -s /home/pronav/.ssh/authorized_keys ]]; then
  install -d -m 700 -o breakglass -g breakglass /home/breakglass/.ssh
  install -m 600 -o breakglass -g breakglass /home/pronav/.ssh/authorized_keys /home/breakglass/.ssh/authorized_keys
fi

log "writing recovery note"
install -d -m 755 -o pronav -g pronav /home/pronav/server-recovery
tee /home/pronav/server-recovery/PRSNL_RECOVERY.md >/dev/null <<'RECOVERY'
# PRSNL Dell Recovery Notes

Host: prsnl
Primary user: pronav
Breakglass local admin: breakglass
Tailscale IP: 100.103.66.92
LAN IP: 192.168.1.18

## Normal access

```bash
ssh pronav@100.103.66.92
ssh pronav@192.168.1.18
```

Breakglass fallback:

```bash
ssh breakglass@100.103.66.92
ssh breakglass@192.168.1.18
```

## Important limit

Remote SSH and Tailscale require the Dell to be powered on, booted into Ubuntu,
and connected to at least one network path. If the box is in BIOS, recovery,
or has no Wi-Fi/Ethernet/tether/LTE path, use local keyboard and screen.

## Boot issue from June 2026

The SSD was physically loose. If the machine shows Windows Boot Manager,
PXE/Realtek network boot, or "required device is not connected" again:

1. Power down.
2. Reseat the internal SanDisk SSD.
3. Boot with F12.
4. Pick the SSD/Ubuntu entry, not PXE/network boot.

## Keyboard recovery

Bluetooth keyboards are not reliable for BIOS, GRUB, or recovery screens.
Keep a wired USB keyboard for local recovery.

## App paths

Repo: `/home/pronav/docker/moc`
Deployed commit marker: `/home/pronav/docker/moc/.deployed-source-head`
Daily DB backups: `/home/pronav/docker/moc/backups`
Ops backups/secrets: `/home/pronav/docker/moc-ops-backups`

## AWS backup archive

Local archive:
`/home/pronav/aws-account-backups/archives/aws-account-999200449801-20260616T100005Z.tar.gz`

Google Drive:
`gdrive:AWS account backups/archives/aws-account-999200449801-20260616T100005Z.tar.gz`
RECOVERY
chown pronav:pronav /home/pronav/server-recovery/PRSNL_RECOVERY.md

if command -v netplan >/dev/null 2>&1; then
  log "validating netplan"
  netplan generate >/dev/null
fi

log "status"
hostname
id breakglass
systemctl is-active ssh
systemctl is-active tailscaled 2>/dev/null || true
if command -v tailscale >/dev/null 2>&1; then
  tailscale debug prefs 2>/dev/null | grep -i '"RunSSH"' || true
fi
ls -l /home/pronav/server-recovery/PRSNL_RECOVERY.md
log "done"
REMOTE

echo
echo "Verifying access paths..."
ssh -o BatchMode=yes "$HOST" 'hostname; whoami; id breakglass; systemctl is-active ssh; systemctl is-active tailscaled 2>/dev/null || true'

echo
echo "Done. Recovery note on the Dell:"
echo "/home/pronav/server-recovery/PRSNL_RECOVERY.md"
