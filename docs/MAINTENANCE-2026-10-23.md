# Dell maintenance — 2026-10-23

Last live verification: **17:26 UTC / 22:56 IST**, over normal OpenSSH on the home LAN.

## Result

- Installed all **11 updates eligible under normal APT phasing**, including the two
  Ubuntu-security zlib packages. The remaining cloud-init update is phased by Ubuntu.
- Recovered approximately **4.04 GB / 3.76 GiB** during the measured cleanup window.
  Root filesystem usage is **85%**, with **32.3 GiB available** (`df -h` rounds to 33G).
- All **32 regular production containers are healthy**. The extra running MOC test
  PostgreSQL container and stopped quarantine-inspection database were preserved.
- Both public sites returned HTTP 200. Core host services are active. Normal SSH and
  the private Docker port bindings remain intact; Tailscale SSH remains disabled.
- Corrected the Google Drive backup's self-copying-log defect and restarted its existing
  job. **Remote copy and verification were still pending at handoff.**

No host reboot, application deployment, production database change, or volume deletion
was performed.

## Cleanup and retained state

| Metric | Before cleanup | After cleanup and updates |
|---|---:|---:|
| Root bytes used | 196,176,494,592 | 192,136,785,920 |
| Root bytes available | 30,678,327,296 | 34,718,035,968 |
| Root usage | 87% | 85% |
| Docker images | 48 | 45 |
| Docker build cache | 0 B | 0 B |
| Docker volumes | 42 | 42 |

The initial quick health check showed 89%; the table uses the later exact byte readings
around the cleanup window. Normal concurrent workload activity can affect the delta.

Removed three untagged, unreferenced MOC images built on October 6:

- `b1d0ea6885ff` — old server/worker runtime
- `b882af11c8c8` — old voice runtime
- `efd77f6431ae` — old Mastra ops runtime

Each image was checked against the container inventory before removal. Removal used
explicit image IDs without force. Tagged release/recovery/rollback images and both
PostgreSQL images referenced by running containers were retained. Deleted image layers
would need rebuilding to recover.

Cleared downloaded APT archives after installation and applied the runbook's 14-day
archived-journal retention, which reclaimed approximately 1.3 GiB. Deleted old journal
entries have no local undo. Recent journals, application logs, sources, and backups remain.
APT autoremove had no candidates. No Docker build cache was present to prune.

The only stopped container is `moc-spr01-quarantine-proof-20260924`, labelled
`moc.test-owner=spr01-quarantine-inspection-20260924`. Its database volume and inspection
state were preserved. The running `moc-full456-cb6f-pg-v2` test database was also retained.

Major retained storage observed during the audit:

- Approximately 37 GiB in `/home/pronav/.local/share/moc-spr-proof`.
- Approximately 8.5 GiB in `/home/pronav/.cache/moc-full-gate-20260917`, containing
  validation worktrees, results, and proof data rather than just downloaded packages.
- Approximately 41 GiB in `/home/pronav/aws-account-backups`.
- Approximately 19 GiB in `/home/pronav/backups`.

Further significant reclamation needs a deliberate retention/archive decision for these
datasets. They were not treated as disposable merely because they are old or under `.cache`.

## Installed updates

| Package(s) | Installed version |
|---|---|
| zlib1g, zlib1g-dev | `1:1.3.dfsg-3.1ubuntu2.3` |
| nodejs | `24.22.1-1nodesource1` |
| docker-ce, docker-ce-cli, docker-ce-rootless-extras | `5:29.9.2-1~ubuntu.24.04~noble` |
| containerd.io | `2.4.2-3~ubuntu.24.04~noble` |
| docker-buildx-plugin | `0.38.1-1~ubuntu.24.04~noble` |
| docker-compose-plugin | `5.6.1-1~ubuntu.24.04~noble` |
| docker-model-plugin | `1.2.9-1~ubuntu.24.04~noble` |
| tailscale | `1.104.2` |

Both package transactions were simulated first and then run through transient systemd
jobs with exact versions, configuration preservation, no removals, and automatic
needrestart actions disabled. `dpkg --audit` was clean and `apt-get check` passed afterward.

Docker live-restore was enabled and the application containers kept their start times.
Autoheal restarted during the Docker update. Dozzle retained a stale Docker socket,
reported HTTP 500 on its health check, and recovered after a targeted restart.

The only available package left is phased `cloud-init` (`26.2-0ubuntu1~24.04.2`).
No phasing override was applied. The running and expected kernel are both
`6.8.0-147-generic`; no reboot-required file is present.

**Installed does not mean every long-running process has reloaded the patched libraries.**
The final `needrestart` audit still listed containerd/shims and several host services,
including SSH, fail2ban, Desk OS collection, polkit, dbus, logind, and WiFi support.
These restarts should be completed in a controlled window once the backup copy has
finished. The existing backup inhibitor still blocks shutdown while that copy is pending.

## Google Drive backup repair

The existing copy service had made 18 attempts across four days. Rclone repeatedly
failed with `source file is being updated` for its own `logs/gdrive-copy/rclone-copy.log`
and the active `logs/reboot-inhibitor/inhibitor.log` inside the source backup tree.
The copy status file also changes between copy and verification.

Updated `/home/pronav/aws-account-backups/tools/wait_then_copy_to_gdrive.sh` to apply
one shared filter list to **both** `rclone copy` and `rclone check`:

```text
/logs/gdrive-copy/**
/logs/reboot-inhibitor/**
/GDRIVE_COPY_STATUS.txt
/.gdrive-copy.lock
```

These are exclusions for volatile control metadata. Backup payload and completed AWS
source logs remain included. The script still uploads the final status separately.
The existing remote destination and one-way, size-only verification were preserved.
No remote objects were deleted.

Validation:

- `bash -n` passed.
- A local-filesystem fixture run through the server's rclone included the payload and
  completed AWS log while excluding all four categories of volatile metadata.
- The existing copy service restarted at **17:15:36 UTC** and stayed running through
  the package updates. No new ERROR entries were present at the final check.
- The job was still inventorying the approximately 1.09 million-file backup; successful
  copy and verification have **not** yet been established.

The original script is retained beside it as
`wait_then_copy_to_gdrive.sh.pre-maintenance-20261023`.

Also moved the misplaced `StartLimitIntervalSec=0` setting from `[Service]` to `[Unit]`
in `aws-backup-gdrive-copy.service` and `aws-backup-archive-upload.service`.
`systemd-analyze verify` passed and the loaded units report `StartLimitIntervalUSec=0`.
Original unit files are retained with `.pre-maintenance-20261023` suffixes. A daemon reload
applied the correction without starting the inactive archive-upload workflow.

## Other observations

- MOC, Domain Hunter, and Desk OS scheduled backups succeeded today at 03:06:36,
  03:19:39, and 03:22:43 UTC respectively. This is job-completion evidence, not a restore drill.
- The 119 failed systemd entries are all transient MOC validation/proof jobs. Their
  failure records were preserved; they are not 119 failed persistent host daemons.
- MOC graph health remains `healthy=true`, `ready=false`, `operationalStatus=critical`,
  with 51 retry-exhausted jobs (zero recent) and 462 orphan findings. This application
  issue was not changed by maintenance.
- The Mac and Dell are connected to different Tailscale networks. Both clients report
  online with no health warnings, but the Dell is absent from the Mac's current peer
  list. Maintenance used LAN SSH. No tailnet/profile change was made.
- Last resource sample: 2.2 GiB RAM used, 5.5 GiB available; load averages
  `1.89 / 2.65 / 2.44` on the two-core host.
