# Dell update inventory — urgency and capabilities

Verified 2026-09-15 against refreshed live APT metadata, official Ubuntu changelogs/security notices, and upstream release notes. This is the historical pre-update inventory. **All 83 listed package updates were subsequently installed successfully**; see [the completed OS update report](OS-UPDATE-2026-09-15.md).

Urgency is an operator judgment for this two-core Docker host, not a vendor CVSS ranking or a package-installation sequence. Related binary packages share a source release and should be updated together; a companion library, translation or development package is not necessarily independently vulnerable.

A read-only simulation (`apt-get -s --with-new-pkgs upgrade`) reported **78 upgrades, 25 newly installed dependencies, zero removals and five phased/deferred upgrades**. The deferred candidates were dnsmasq-base and the four Netplan packages. The later user-approved maintenance window included those five candidates and verified networking after reboot. Eighteen new packages split firmware by vendor; seven provide the new kernel, modules, headers and tools. The 59 Ubuntu-security-origin candidates are not 59 distinct vulnerabilities; some other repositories also contain security fixes.

Host Node/Python/library updates do not replace the versions packaged inside existing application images. The host kernel and Docker runtime do affect running container infrastructure. Backups and a controlled reboot were verified during the completed update window.

## Highest priority

### 1–5: linux-meta

Fixes kernel networking, memory, filesystem and other security flaws; stays on Linux 6.8. Companion headers/tools track the patched kernel. Reboot required. [Official source](https://ubuntu.com/security/notices/USN-8729-1).

| # | Package | Installed | Available |
|---|---|---|---|
| 1 | `linux-generic` | `6.8.0-138.138` | `6.8.0-139.139` |
| 2 | `linux-headers-generic` | `6.8.0-138.138` | `6.8.0-139.139` |
| 3 | `linux-image-generic` | `6.8.0-138.138` | `6.8.0-139.139` |
| 4 | `linux-libc-dev` | `6.8.0-138.138` | `6.8.0-139.139` |
| 5 | `linux-tools-common` | `6.8.0-138.138` | `6.8.0-139.139` |

### 6: containerd.io

Security fixes for malicious-image unpacking/resource exhaustion and safer handling of registry authentication headers; fixes startup and I/O hangs. No major new end-user feature. [Official source](https://github.com/containerd/containerd/releases/tag/v2.3.5).

| # | Package | Installed | Available |
|---|---|---|---|
| 6 | `containerd.io` | `2.3.4-1~ubuntu.24.04~noble` | `2.3.5-1~ubuntu.24.04~noble` |

### 7–9: docker-ce

Adds container umask controls, configurable default AppArmor templates and annotation filtering; hardens container isolation. Rootless extras add an optional pesto port driver; this Dell uses ordinary rootful Docker. [Official source](https://docs.docker.com/engine/release-notes/29/#2980).

| # | Package | Installed | Available |
|---|---|---|---|
| 7 | `docker-ce` | `5:29.7.2-1~ubuntu.24.04~noble` | `5:29.8.0-1~ubuntu.24.04~noble` |
| 8 | `docker-ce-cli` | `5:29.7.2-1~ubuntu.24.04~noble` | `5:29.8.0-1~ubuntu.24.04~noble` |
| 9 | `docker-ce-rootless-extras` | `5:29.7.2-1~ubuntu.24.04~noble` | `5:29.8.0-1~ubuntu.24.04~noble` |

### 10–12: openssh

Fixes agent-forwarding restrictions, a client use-after-free, and tunnel-forwarding restrictions. No new SSH workflow; restart the SSH service safely after updating. [Official source](https://ubuntu.com/security/notices/USN-8721-1).

| # | Package | Installed | Available |
|---|---|---|---|
| 10 | `openssh-client` | `1:9.6p1-3ubuntu13.18` | `1:9.6p1-3ubuntu13.19` |
| 11 | `openssh-server` | `1:9.6p1-3ubuntu13.18` | `1:9.6p1-3ubuntu13.19` |
| 12 | `openssh-sftp-server` | `1:9.6p1-3ubuntu13.18` | `1:9.6p1-3ubuntu13.19` |

### 13–17: glibc

Fixes memory-corruption and denial-of-service issues in core host C-library functions. Companion development packages are matching rebuilds, not separate new capabilities. [Official source](https://ubuntu.com/security/notices/USN-8737-2).

| # | Package | Installed | Available |
|---|---|---|---|
| 13 | `libc-bin` | `2.39-0ubuntu8.8` | `2.39-0ubuntu8.9` |
| 14 | `libc-dev-bin` | `2.39-0ubuntu8.8` | `2.39-0ubuntu8.9` |
| 15 | `libc-devtools` | `2.39-0ubuntu8.8` | `2.39-0ubuntu8.9` |
| 16 | `libc6` | `2.39-0ubuntu8.8` | `2.39-0ubuntu8.9` |
| 17 | `libc6-dev` | `2.39-0ubuntu8.8` | `2.39-0ubuntu8.9` |

### 18–27: util-linux

Fixes local privilege-escalation races and bypasses in mounting plus unsafe partition probing. Companion utilities/libraries update together; no new operational feature. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/u/util-linux/util-linux_2.39.3-9ubuntu6.6/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 18 | `bsdutils` | `1:2.39.3-9ubuntu6.5` | `1:2.39.3-9ubuntu6.6` |
| 19 | `eject` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |
| 20 | `fdisk` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |
| 21 | `libblkid1` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |
| 22 | `libfdisk1` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |
| 23 | `libmount1` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |
| 24 | `libsmartcols1` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |
| 25 | `libuuid1` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |
| 26 | `mount` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |
| 27 | `util-linux` | `2.39.3-9ubuntu6.5` | `2.39.3-9ubuntu6.6` |

### 28–29: udisks2

Fixes mounting on behalf of other users without correct authorization, which could permit local privilege escalation. No new feature. [Official source](https://ubuntu.com/security/notices/USN-8701-1).

| # | Package | Installed | Available |
|---|---|---|---|
| 28 | `libudisks2-0` | `2.10.1-6ubuntu1.3` | `2.10.1-6ubuntu1.5` |
| 29 | `udisks2` | `2.10.1-6ubuntu1.3` | `2.10.1-6ubuntu1.5` |

## Next: security fixes

### 30: libssh

Fixes SSH-library crashes, information disclosure, AES-GCM integrity checking and use-after-free. Separate from the OpenSSH server package; no new feature. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/libs/libssh/libssh_0.10.6-2ubuntu0.5/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 30 | `libssh-4` | `0.10.6-2ubuntu0.4` | `0.10.6-2ubuntu0.5` |

### 31–38: python3.12

Fixes tarfile extraction-filter handling and excessive CPU use in incremental HTML parsing. Python remains 3.12.3; installed development/venv companions update together. [Official source](https://changelogs.ubuntu.com/changelogs/pool/universe/p/python3.12/python3.12_3.12.3-1ubuntu0.17/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 31 | `libpython3.12-dev` | `3.12.3-1ubuntu0.16` | `3.12.3-1ubuntu0.17` |
| 32 | `libpython3.12-minimal` | `3.12.3-1ubuntu0.16` | `3.12.3-1ubuntu0.17` |
| 33 | `libpython3.12-stdlib` | `3.12.3-1ubuntu0.16` | `3.12.3-1ubuntu0.17` |
| 34 | `libpython3.12t64` | `3.12.3-1ubuntu0.16` | `3.12.3-1ubuntu0.17` |
| 35 | `python3.12` | `3.12.3-1ubuntu0.16` | `3.12.3-1ubuntu0.17` |
| 36 | `python3.12-dev` | `3.12.3-1ubuntu0.16` | `3.12.3-1ubuntu0.17` |
| 37 | `python3.12-minimal` | `3.12.3-1ubuntu0.16` | `3.12.3-1ubuntu0.17` |
| 38 | `python3.12-venv` | `3.12.3-1ubuntu0.16` | `3.12.3-1ubuntu0.17` |

### 39: libgcrypt20

Hardens RSA against timing-based attacks, including constant-time processing and implicit rejection. Security improvement, not a new encryption feature. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/libg/libgcrypt20/libgcrypt20_1.10.3-2ubuntu0.2/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 39 | `libgcrypt20` | `1.10.3-2ubuntu0.1` | `1.10.3-2ubuntu0.2` |

### 40–50: gnupg2

Enforces a minimum GCM authentication-tag length in gpgsm decryption. The other GnuPG components are matching family rebuilds; not eleven new vulnerabilities/features. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/g/gnupg2/gnupg2_2.4.4-2ubuntu17.6/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 40 | `dirmngr` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 41 | `gnupg` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 42 | `gnupg-l10n` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 43 | `gnupg-utils` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 44 | `gpg` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 45 | `gpg-agent` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 46 | `gpg-wks-client` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 47 | `gpgconf` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 48 | `gpgsm` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 49 | `gpgv` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |
| 50 | `keyboxd` | `2.4.4-2ubuntu17.4` | `2.4.4-2ubuntu17.6` |

### 51: libevent

Fixes unsafe buffer-reference handling in the installed core library. Other HTTP/RPC source-family fixes should not be confused with this core-only binary. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/libe/libevent/libevent_2.1.12-stable-9ubuntu2.1/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 51 | `libevent-core-2.1-7t64` | `2.1.12-stable-9ubuntu2` | `2.1.12-stable-9ubuntu2.1` |

### 52–53: zlib

Prevents an infinite loop/resource exhaustion in CRC-combination functions. The development package tracks the patched library; no new compression capability. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/z/zlib/zlib_1.3.dfsg-3.1ubuntu2.2/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 52 | `zlib1g` | `1:1.3.dfsg-3.1ubuntu2.1` | `1:1.3.dfsg-3.1ubuntu2.2` |
| 53 | `zlib1g-dev` | `1:1.3.dfsg-3.1ubuntu2.1` | `1:1.3.dfsg-3.1ubuntu2.2` |

### 54: cpio

Fixes unsafe extraction hard-link targets, unbounded stack allocation and terminal-unsafe filename output. Safer archive processing, not a new archive format. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/c/cpio/cpio_2.15%2bdfsg-1ubuntu2.1/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 54 | `cpio` | `2.15+dfsg-1ubuntu2` | `2.15+dfsg-1ubuntu2.1` |

### 55: attr

Matching libattr1 rebuild from the attr security release, whose changes harden file-attribute tools against symlink traversal. No new application capability. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/a/attr/attr_2.5.2-1ubuntu0.1/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 55 | `libattr1` | `1:2.5.2-1build1.1` | `1:2.5.2-1ubuntu0.1` |

### 56: coreutils

Fixes an out-of-bounds read in sort. No new general-purpose shell utilities. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/c/coreutils/coreutils_9.4-3ubuntu6.3/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 56 | `coreutils` | `9.4-3ubuntu6.2` | `9.4-3ubuntu6.3` |

### 57: diffutils

Fixes integer overflows in diff3. No new comparison or merge feature. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/d/diffutils/diffutils_3.10-1ubuntu0.1/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 57 | `diffutils` | `1:3.10-1build1` | `1:3.10-1ubuntu0.1` |

### 58–62: ncurses

Fixes a terminal-description parser stack-buffer overflow; libraries and terminal data update together. No new UI capability. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/n/ncurses/ncurses_6.4%2b20240113-1ubuntu2.2/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 58 | `libncursesw6` | `6.4+20240113-1ubuntu2.1` | `6.4+20240113-1ubuntu2.2` |
| 59 | `libtinfo6` | `6.4+20240113-1ubuntu2.1` | `6.4+20240113-1ubuntu2.2` |
| 60 | `ncurses-base` | `6.4+20240113-1ubuntu2.1` | `6.4+20240113-1ubuntu2.2` |
| 61 | `ncurses-bin` | `6.4+20240113-1ubuntu2.1` | `6.4+20240113-1ubuntu2.2` |
| 62 | `ncurses-term` | `6.4+20240113-1ubuntu2.1` | `6.4+20240113-1ubuntu2.2` |

## Reliability and features

### 63: tailscale

Fixes connectivity loss when a network-map update overlaps reauthentication. Relevant to remote-access reliability, but not evidence for the prior Dell outage's cause. [Official source](https://tailscale.com/changelog#2026-09-10).

| # | Package | Installed | Available |
|---|---|---|---|
| 63 | `tailscale` | `1.102.3` | `1.102.4` |

### 64: docker-buildx-plugin

Adds the standard cloud driver for separately configured Docker Build Cloud; improves builder readiness, Bake secret handling and multi-node push correctness. No cloud service is enabled by upgrading. [Official source](https://github.com/docker/buildx/releases/tag/v0.37.0).

The patch update additionally fixes incomplete multi-node image tags and builder timeout/cleanup behavior. [0.37.1 notes](https://github.com/docker/buildx/releases/tag/v0.37.1).

| # | Package | Installed | Available |
|---|---|---|---|
| 64 | `docker-buildx-plugin` | `0.36.1-1~ubuntu.24.04~noble` | `0.37.1-1~ubuntu.24.04~noble` |

### 65: docker-compose-plugin

Surfaces lifecycle-hook output and errors; improves watch/symlink synchronization, startup timeouts, network options and safeguards around output-directory replacement. [Official source](https://github.com/docker/compose/releases/tag/v5.5.1).

| # | Package | Installed | Available |
|---|---|---|---|
| 65 | `docker-compose-plugin` | `5.5.0-1~ubuntu.24.04~noble` | `5.5.1-1~ubuntu.24.04~noble` |

### 66: nodejs

Adds provider-backed private-key loading, non-throwing MIMEType.parse and histogram statistical testing; improves BlockList performance and refreshes bundled TLS/HTTP dependencies. [Official source](https://nodejs.org/en/blog/release/v24.21.0).

| # | Package | Installed | Available |
|---|---|---|---|
| 66 | `nodejs` | `24.20.0-1nodesource1` | `24.21.0-1nodesource1` |

### 67: dnsmasq

Adds optional DNS-0x20 spoof-resistance, PXE-specific DHCP options and DNSSEC retry improvements, plus security/crash fixes. No dnsmasq process was running; this is phased on the Dell. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/d/dnsmasq/dnsmasq_2.91-0ubuntu0.24.04.1/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 67 | `dnsmasq-base` | `2.90-2ubuntu0.4` | `2.91-0ubuntu0.24.04.1` |

### 68–71: netplan.io

Correctly returns a failure exit status on errors so automation can detect failed network configuration. No new networking mode. These four packages are phased. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/n/netplan.io/netplan.io_1.1.2-8ubuntu1%7e24.04.3/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 68 | `libnetplan1` | `1.1.2-8ubuntu1~24.04.2` | `1.1.2-8ubuntu1~24.04.3` |
| 69 | `netplan-generator` | `1.1.2-8ubuntu1~24.04.2` | `1.1.2-8ubuntu1~24.04.3` |
| 70 | `netplan.io` | `1.1.2-8ubuntu1~24.04.2` | `1.1.2-8ubuntu1~24.04.3` |
| 71 | `python3-netplan` | `1.1.2-8ubuntu1~24.04.2` | `1.1.2-8ubuntu1~24.04.3` |

### 72–76: krb5

Fixes overflow/incorrect messages for far-future password-expiry intervals; no new Kerberos authentication capability. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/k/krb5/krb5_1.20.1-6ubuntu2.10/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 72 | `krb5-locales` | `1.20.1-6ubuntu2.8` | `1.20.1-6ubuntu2.10` |
| 73 | `libgssapi-krb5-2` | `1.20.1-6ubuntu2.8` | `1.20.1-6ubuntu2.10` |
| 74 | `libk5crypto3` | `1.20.1-6ubuntu2.8` | `1.20.1-6ubuntu2.10` |
| 75 | `libkrb5-3` | `1.20.1-6ubuntu2.8` | `1.20.1-6ubuntu2.10` |
| 76 | `libkrb5support0` | `1.20.1-6ubuntu2.8` | `1.20.1-6ubuntu2.10` |

## Routine / low immediate impact

### 77: linux-firmware

Converts the broad firmware package into a metapackage with vendor-split dependencies. Packaging change; no verified new capability for this Dell. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/l/linux-firmware/linux-firmware_20240318.git3b128b60.0ubuntu3.1/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 77 | `linux-firmware` | `20240318.git3b128b60-0ubuntu2.29` | `20240318.git3b128b60.0ubuntu3.1` |

### 78: wireless-regdb

Updates the Wi-Fi regulatory database from February to May 2026. Do not infer faster Wi-Fi or new radio-band support on this hardware. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/w/wireless-regdb/wireless-regdb_2026.05.30-0ubuntu1%7e24.04.1/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 78 | `wireless-regdb` | `2026.02.04-0ubuntu1~24.04.1` | `2026.05.30-0ubuntu1~24.04.1` |

### 79–80: python-apt

Refreshes mirror lists for Ubuntu 24.04.5. No new package-management API feature. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/p/python-apt/python-apt_2.7.7ubuntu5.3/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 79 | `python-apt-common` | `2.7.7ubuntu5.2` | `2.7.7ubuntu5.3` |
| 80 | `python3-apt` | `2.7.7ubuntu5.2` | `2.7.7ubuntu5.3` |

### 81–82: ubuntu-release-upgrader

Fixes t64-package dependency installation during release upgrades and refreshes mirrors. Installing the tool does not itself upgrade Ubuntu to another release. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/u/ubuntu-release-upgrader/ubuntu-release-upgrader_24.04.29/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 81 | `python3-distupgrade` | `1:24.04.28` | `1:24.04.29` |
| 82 | `ubuntu-release-upgrader-core` | `1:24.04.28` | `1:24.04.29` |

### 83: base-files

Updates the displayed Ubuntu point-release identity to 24.04.5. Cosmetic/version metadata, not a new OS or kernel. [Official source](https://changelogs.ubuntu.com/changelogs/pool/main/b/base-files/base-files_13ubuntu10.5/changelog).

| # | Package | Installed | Available |
|---|---|---|---|
| 83 | `base-files` | `13ubuntu10.4` | `13ubuntu10.5` |

## Scope and interpretation

- Security fixes are the main reason to update; no evidence of active exploitation on this Dell was established by this review.
- Tailscale's patch addresses one connectivity failure mode, not proof that it caused the September outage. Preserve ordinary OpenSSH over Tailscale; do not turn on Tailscale SSH as part of package maintenance.
- The strongest genuine feature additions are Docker permission controls, Buildx cloud-driver support, Compose hook diagnostics, Node.js developer APIs, and optional dnsmasq DNS/PXE features. None automatically adds product features to MOC or Domain Hunter.
- The kernel security notice requires a reboot. Firmware layout changes and phased network packages merit review before a full update; no forced phasing, reboot or application deployment was performed here.
- Detailed kernel source-changelog retrieval timed out; kernel findings above are based on Ubuntu's exact-version security notice instead. For firmware/kernel-meta/regulatory records whose current changelog omits the exact previous branch revision, only the current release entry and independently verified changes are described.
