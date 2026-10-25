# Dell maintenance — 2026-10-25

Live verification: **07:54–08:01 UTC**, over normal OpenSSH on the home LAN.

## Result

- Host healthy: up 5d 23h (booted 2026-10-19), load `1.20 / 1.62 / 1.90`, 4.7 GiB RAM
  available, 4.0 GiB swap in use. Root is **86% used, 32 GiB available**.
- All regular production containers are healthy (35 running). Non-production: three
  running MOC test PostgreSQL containers (`moc-spr01-consent-pg-v1`, `moc-spr01-batch-pg-v1`,
  `moc-full456-cb6f-pg-v2`) and the stopped `moc-spr01-quarantine-proof-20260924` — all preserved.
- Core host services active. Both public sites returned HTTP 200. MOC `/health` is `ok`.
- No APT updates available (the phased cloud-init update is no longer listed).
- MOC, Domain Hunter and Desk OS backups all succeeded at about 03:05–03:21 UTC today.
- fail2ban: 0 failures and 0 bans. Journals use 227 MiB.

Follow-up work the owner approved the same morning (details below): SMART tooling installed, unused
images and volumes cleaned up, and a controlled reboot at 08:07 UTC. No deployment or
production database change was made.

## Carried-over items from 2026-10-23

**Google Drive backup copy: closed.** `aws-backup-gdrive-copy.service` finished at
2026-10-23 18:30:35 UTC: `rclone copy` completed, the size-only one-way check passed, and
`GDRIVE_COPY_STATUS.txt` reports `status=complete`. Both shutdown inhibitors are inactive.
The service exited 0, and its loop has stopped.

**Library restarts: partially closed.** needrestart still flags:

| Unit | Why still flagged | Action |
|---|---|---|
| unattended-upgrades | Old libraries in memory | **Restarted** this session (active) |
| containerd | Its main process restarted 2026-10-24. The flag comes from about 35 `containerd-shim` processes from the 2026-10-19 boot (`KillMode=process`). | Clears only when the containers restart → reboot |
| dbus, systemd-logind | Not safe to restart while running | Reboot |
| wpa_supplicant | The only network link: `enp7s0` has no carrier. A remote restart risks losing the box. | Reboot (or console) |

SSH, fail2ban, the Desk OS collector and polkit no longer appear, so they were already reloaded.
The running and expected kernel are both `6.8.0-147-generic`, so no kernel reboot is pending.
**Closed by reboot** (see "Reboot" below). After the reboot, needrestart reports no stale services.

## Storage

| Path | Size | Note |
|---|---:|---|
| `/home/pronav/aws-account-backups` | 41 GiB | The local copy is now duplicated on Google Drive (copy and check complete) |
| `/home/pronav/.local/share/moc-spr-proof` | 39 GiB | Grew about 2 GiB since 2026-10-23. Active MOC validation output (latest 2026-10-22). |
| `/var/lib/docker` | 33 GiB | Images 21.9 GB (9.3 GB reclaimable), volumes 9.9 GB |
| `/home/pronav/backups` | 19 GiB | |
| `/home/pronav/.cache/moc-full-gate-20260917` | 8.5 GiB | Validation worktrees and proof data |

The two untagged images (`9b05db12a354`, `8ed3192326bb`) are old `pgvector` digests that
running test/production databases still use, so they are not prunable. The rest of the
reclaimable image space is tagged MOC rollback/recovery sets (`rollback-20260917`,
`rollback/recovery-082c9b6c`) and the retired `domain-hunter-dh-scheduler`. There are also
27 unreferenced Docker volumes (24 anonymous, plus `moc-mastra-ops_mastra_ops_data`,
`moc-sdk-pnpm-store`, `moc_audio-data`). All of this was retained pending a retention decision.

Biggest available win: with the Drive copy verified, the 41 GiB local AWS backup could be
archived or removed. That is irreversible locally and needs an explicit decision.

## Other observations

- 157 failed systemd units (up from 119), all transient `moc-*` validation/diagnostic jobs. None are host daemons.
- Mac↔Dell Tailscale split from 2026-10-23 is unchanged; LAN SSH was used.
- `smartctl` was not installed at audit time. It was installed in the follow-up (see below).

## Follow-up actions (approved by owner)

### SMART monitoring

Installed `smartmontools` 7.4. `smartmontools.service` (smartd) is enabled and active.

| Disk | Role | SMART | Notes |
|---|---|---|---|
| `sdb` Kingston SA400S3 240 GB | Root (`/`) | PASSED | Life left 95%, 5,946 power-on hours, 6.4 TiB host writes, 0 uncorrectable, 0 reallocated, 13 bad blocks (stable figure), no error log |
| `sda` Toshiba MQ01ABF050 500 GB | **Unused**: old Windows NTFS disk, not in fstab | PASSED | 0 reallocated, 12,874 hours. **UDMA_CRC_Error_Count 130,439,794** points to a link or cable problem. Do not rely on this disk without reseating it. |

### Image and volume cleanup

Removed 14 image tags, none used by any container. Removal went by tag, without force:

- `moc-rollback-20260917/{mastra-ops-server,server,voice,worker}`
- `moc-rollback-{mastra-ops-server,server,voice,worker}:082c9b6c-20260921`
- `moc-{mastra-ops-server,server,voice,worker,web}:recovery-082c9b6c-20260923` (the `moc-web` tag only untagged `nginx:alpine`)
- `domain-hunter-dh-scheduler:latest` (retired scheduler)

Kept: the `moc-release-*:df212b6a` set as the newest rollback point, Domain Hunter
profile images (a2/classifier/registrar), and `moc-spr01-bounded-proof:71995a84`.

Removed all 27 unused volumes **after archiving each one** to
`/home/pronav/server-recovery/maintenance-20261025/volumes/`. That folder holds
`<volume>.tar.zst` and `<volume>.inspect.json` files plus `SHA256SUMS`; it totals 364 MB,
with the directory at mode 0700 and the files at 0600. Every archive passed a `tar -t`
read-back before its volume was removed. Contents:

- 23 anonymous PostgreSQL data directories (MOC test DBs, 2026-07-11 → 2026-10-05, about 2.2 GB raw)
- 1 anonymous Redis volume (`dump.rdb`, 2026-06-02)
- `moc-mastra-ops_mastra_ops_data` (stale since June; the live container uses `moc_mastra_ops_data`)
- `moc-sdk-pnpm-store` and `moc_audio-data` (both empty)

To restore one: `docker volume create NAME && zstd -dc NAME.tar.zst | sudo tar -C /var/lib/docker/volumes/NAME/_data -xf -`

Result: root went from **86% → 82%** used, and from **32 → 40 GiB** available.
Images: 45 → 37 (15.3 GB). Volumes: 42 → 15, all in use.

### Reboot

Reboot issued at 08:07:24 UTC. SSH was back at 08:10:55, over WiFi on the same address (Ethernet still has no carrier).

- All production containers came back healthy; 32 were running and none were starting or unhealthy.
- needrestart: no stale services. Kernel `6.8.0-147-generic`.
- Core services are active, including smartd. No failed units other than `moc-*`.
- prsnl.fyi and moc.prsnl.fyi return 200. MOC `/health` is `ok` and `dh-api` returns 200.
- Tailscale is up at 100.103.66.92. Private listeners are still bound to the Tailscale IP.
- Backup timers are scheduled for 2026-10-26 at about 03:04–03:20 UTC.

**Casualty: three MOC test databases were lost.** `moc-spr01-consent-pg-v1`, `moc-spr01-batch-pg-v1`
and `moc-full456-cb6f-pg-v2` had restart policy `no` and **no mounts** (`Mounts: []`, network
`none`). Docker removed them during shutdown, and their contents could not be recovered. A MOC
proof harness was tracking `moc-full456-cb6f-pg-v2` by container ID and PID
(owner `full456-cb6f-20261021-v2`). Those proof runs (full456-cb6f, spr01 batch/consent)
need to be restarted from their own setup steps. No production data was involved.

### Documentation drift found

- **Netdata is not deployed.** There is no container, no image, and no entry in `~/docker/docker-compose.yml`,
  and it was not running before the reboot either. CLAUDE.md still lists it under port 19999.
- The second disk (`sda`) was undocumented; it has now been added to the CLAUDE.md hardware table.

## Secondary HDD put into service (owner request, same day)

**Investigation.** `sda3` (NTFS, 465 GB) holds `Pictures/`: 24,197 personal photos, 35 GB,
2013–2021, plus an empty Windows `Recovery` folder. 430 GB is free. The owner chose to keep
NTFS for now and, at some later date, move the photos to the Mac and reformat as ext4.
**The photos were not modified.**

**SATA "CRC errors" are a firmware quirk.** Attribute 199 rose by exactly 3,187 for a 4 GiB
read at both 6 Gb/s and 3 Gb/s. It scales with bytes moved (about 0.75 per MB, for 4 KiB and
4 MiB commands alike), does not change at idle, and the kernel logged zero ATA
exceptions/ICRC/resets. Real link CRC errors fail commands and vary with link speed.
`libata.force=1:3.0G` was added anyway (`/etc/default/grub.d/90-sata-link-cap.cfg`,
reboot 08:30 UTC). It is harmless at 5400 rpm. A long SMART self-test was started
(due about 10:36 UTC).

**Mount.** `/etc/fstab`: `UUID=1AD04DDBD04DBDAF /mnt/hdd ntfs3
rw,noatime,uid=1000,gid=1000,fmask=0177,dmask=0077,nofail,x-systemd.device-timeout=15s`.
Pre-change copies: `server-recovery/maintenance-20261025/{fstab,grub.cfg}.pre-hdd`.

**Backup mirror.** New `hdd-backup-mirror.{service,timer}` (daily 05:15 UTC, runs as `pronav`,
`RequiresMountsFor=/mnt/hdd`, idle I/O) runs `~/bin/hdd-backup-mirror.sh` into
`/mnt/hdd/prsnl/backup-mirror/`:

| Name | Source | Mode |
|---|---|---|
| restic-moc | `~/backups/restic-moc` | exact mirror; verified that snapshot lists match (197 = 197) |
| moc-dumps | `~/backups/moc` | history; 2,086 files, md5 match |
| dh-pg | `/var/backups/dh` | history; md5 match |
| deskos | `~/docker/deskos/backups` | history |

The first run had a bug: it pruned by file mtime and deleted the mirrored copies of the
long-kept MOC dumps. Only mirror copies were affected; the source was untouched. It was fixed
before the timer's first scheduled run. Source deletions now move to `.retired/<name>/<date>/`
and expire after 60 days; a fixture test confirmed this.

**Cold-archive offload.** Moved the cold MOC gate/integrity backup folders from `~/backups`
(last written 2026-08-14 → 2026-09-25) and `~/.cache/moc-full-gate-20260917` to
`/mnt/hdd/prsnl/cold-archive/<name>.tar.zst`. Each archive passed `tar --compare` against the
original before the SSD copy was removed. Index: `cold-archive/MANIFEST.tsv` (original path,
sha256, bytes). Pointer: `~/backups/OFFLOADED-TO-HDD.md`. Kept on SSD: `restic-moc`, `moc`, and
`spr01-online-production-*` (written 2026-10-21).

**AWS account backup moved to the HDD (owner request).** `hdd-aws-move.service`, a one-off job
queued behind the cold offload, does the following:
- Copies `archives/aws-account-999200449801-20260616T100005Z.tar.gz` (20 GB) to
  `/mnt/hdd/prsnl/aws-account-backups/archives/` and checks it against the recorded md5
  `eb0171d480e088efb7dd1e1987ec3ac8`.
- Packs the 21 GB / ~1.09M-file backup root into `.tar.zst` and compares it byte-for-byte (`tar --compare`).
- Removes the SSD copies **only after the HDD's extended SMART self-test passes**.
- Keeps `DO_NOT_DELETE_AWS_BACKUPS.txt`, `tools/`, `logs/` and the run script in place and adds
  `MOVED-TO-HDD.md`. Google Drive copies are unchanged.
The four `aws-backup-*` boot units were disabled (their work was complete; unit files kept).
Re-enable with `systemctl enable` only after pointing them at the new location.

## Final state (11:35 UTC)

- **Cold offload:** 42 folders moved and verified, 0 failures. Of the ~23 GiB moved, part was hard links
  to live pnpm `node_modules`, so the SSD gain was smaller than the raw size.
- **AWS move:** archive md5 matched in 15 min, then `tar --compare` of the tree came out clean. The HDD
  extended self-test passed (`Completed without error`, 12,876 h), then the SSD copy was removed.
  A later `sudo sha256sum -c SHA256SUMS` passed for both files on the HDD.
- **Photos:** `/mnt/hdd/Pictures` was untouched.
- **Health:** 33 containers running, none unhealthy. No failed units other than `moc-*`. The mirror timer
  is due at 2026-10-26 about 05:16 UTC.

| | Start of day | End of day |
|---|---:|---:|
| SSD (`/`) | 86% used, 32 GiB free | **55% used, 97 GiB free** |
| HDD (`/mnt/hdd`) | unused, 430 GB free | 23% used, 361 GB free |
