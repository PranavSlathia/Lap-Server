# Dell maintenance — 2026-09-15

Subsequent update: the 83 packages identified below were installed in a later maintenance
window the same day. See [the OS update report](OS-UPDATE-2026-09-15.md). The snapshot
below remains the record of the earlier cleanup window.

Final verification: 14:46 UTC / 20:16 IST over normal OpenSSH on Tailscale.
Scope: disposable caches, unused build images, container inventory, and health checks.
No application deployment, package installation, reboot, or service restart was performed.

## Result

Approximately **45.5 GB (42.4 GiB) of actual filesystem space recovered**. Root usage fell
from **72% to 52%**, with **101 GiB available** at final verification.

| Metric | Before | After |
|---|---|---|
| Root bytes used | 159,487,741,952 | 113,989,869,568 |
| Root bytes available | 62,588,530,688 | 108,086,403,072 |
| Docker build cache | 40.82 GB / 253 records | 0 B / 0 records |
| Docker images | 61 | 44 |
| Running production containers | 32, all healthy | 32, all healthy |
| Stopped containers | 0 | 0 |
| Docker volumes | 24 | 24, unchanged |

Docker's per-operation reclaimed estimates include shared-layer accounting and should not
be added together as an exact filesystem saving; the actual before/after filesystem delta
above is the headline measurement.

## Cleanup performed

- Cleared Docker build cache in two passes. The first retained recently used cache; after
  unused images were removed, the second cleared all remaining unused build cache.
- Removed 17 untagged, unused images and their unreferenced layers. Running-container
  images, including the untagged images used by MOC, were retained.
- Cleared downloaded OS package archives: approximately 914 MiB to 40 KiB.
- Cleared the host user's uv package cache using its own in-use safety checks; the tool
  reported 933.3 MiB removed. Installed environments were not removed.
- Cleared user/root npm download caches. The user's remaining approximately 95 MiB
  includes the preserved npx tool cache; root npm data is approximately 156 KiB.
- No stopped container qualified for deletion. A temporary MOC run container appeared
  during verification and disappeared before the final check; this maintenance did not
  start, stop, or remove it.

Deleted cache/download contents can be regenerated or downloaded again. Deleted local
build images were not archived and would require rebuilding to recover. Tagged
deployment/recovery images, source/build output directories, logs, model/reference data,
database volumes, and backup/recovery archives were preserved. Docker still reports
2.794 GB of unused image storage and 901.3 MB of unlinked volume storage; these were not
blanket-pruned because they may serve deployment, optional profiles, or recovery.

## Health after cleanup

- Uptime: 39 minutes. Load averages: 1.11 / 1.42 / 2.11 on two CPU cores; the earlier
  post-boot/cleanup load had settled below the documented 15-minute warning level of 3.0.
- RAM: 4.4 GiB used of 7.7 GiB, with 3.3 GiB available. Swap used: 35 MiB of 15 GiB.
- All 32 production containers healthy, with their original start times preserved.
  pgweb's one restart was already present before cleanup; no container reported OOMKilled.
- No failed system services. SSH, Docker, fail2ban, firewall, Tailscale, Cloudflare Tunnel,
  cron, DNS resolver, and Desk OS collector were active.
- Both public sites returned HTTP 200 on the final check. An earlier one-off TLS timeout
  from the Mac cleared on recheck; no tunnel or network change was made.
- Domain Hunter health returned `ok=true`, `db=true`, `redis=true`; its deployment runner
  was active. Its latest inventory run succeeded: 707,337 rows fetched, 225 persisted,
  and 150/150 detail checks successful. There were 3 research entries, not verified
  acquisition-ready recommendations; 125 RDAP and 225 Wayback checks remained pending.
- MOC, Domain Hunter, and Desk OS backup services completed successfully after boot at
  14:11:21, 14:08:53, and 14:10:37 UTC respectively. This verifies job completion, not a
  fresh restore drill. Existing archives were not pruned.
- The existing scheduled SSD trim completed successfully at 14:41:54 UTC.
- No reboot-required flag was present. Docker-published services remained on localhost,
  Tailscale, or the documented Desk OS LAN binding; no exposure changes were made.

## Follow-up work, not performed

1. **System updates (completed later):** package indexes were refreshed successfully. At
   this snapshot there were 83 installed packages with available upgrades, including 59
   candidates available from Ubuntu's security repository. They were installed in the
   later update/restart window recorded in `OS-UPDATE-2026-09-15.md`.
2. **MOC application health:** infrastructure is reachable, but graph health reports
   degraded state, a last consolidation on August 17, 38 stale retry-exhausted jobs, and
   462 orphan findings. These require application/data investigation, not cache deletion.
   The source checkout HEAD was `08ec695a` while the deployed marker was `6943c37`;
   this maintenance did not deploy the checkout or alter either marker.
3. **Domain Hunter evidence freshness:** the successful scan still used August 20 market
   and authority reference versions, with the market reference explicitly marked stale.
   Candidate research and source freshness need separate engine work.

Domain Hunter, Vulture, MOC, Phoenix, Desk OS, and all other running projects were retained.
n8n/Quip were not restored or otherwise changed.
