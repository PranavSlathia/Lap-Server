# n8n Architecture on the Dell Server

This document is the durable reference for the self-hosted n8n deployment on the Dell home server (`prsnl`). It records what is live, why it is shaped this way, and which scaling/integration options are deliberately deferred.

Last updated: 2026-06-01.

## Current State

| Item | Value |
|------|-------|
| Server path | `~/docker/n8n/` |
| Repo mirror | `docker/n8n/docker-compose.yml` |
| Editor access | `http://100.103.66.92:5678` over Tailscale; also `https://n8n.prsnl.fyi` behind a Caddy HTTP Basic-Auth gate (`quip-n8n-gate`) — approved 2026-06-01 |
| Local origin | `http://127.0.0.1:5678` for host-local health checks / tunnel origin |
| Public route | `https://n8n.prsnl.fyi` → Cloudflare Tunnel → `quip-n8n-gate` (Caddy basic-auth, bound `127.0.0.1:8090`) → `n8n:5678`; gated, never raw |
| n8n image | `n8nio/n8n:2.22.6` |
| runner image | `n8nio/runners:2.22.6` |
| database image | `postgres:16-alpine` |
| compose network | `n8n-net` |
| secrets file | `~/docker/n8n/.env`, chmod `600`, not committed |

Live containers:

| Container | Role | Port exposure | Limit |
|-----------|------|---------------|-------|
| `n8n` | Editor, webhook engine, workflow scheduler, task broker | `127.0.0.1:5678`, `100.103.66.92:5678` | 1 GiB |
| `n8n-runners` | External Code-node task runner | internal only | 256 MiB |
| `n8n-db` | Postgres store for workflows, credentials, executions | internal only | 256 MiB |

## Traffic Model

```mermaid
flowchart LR
  Owner["Owner devices on Tailscale"] -->|HTTP :5678| Tailscale["100.103.66.92"]
  Health["Host-local checks"] -->|HTTP :5678| Localhost["127.0.0.1"]
  OffNet["Owner off-tailnet"] -->|HTTPS| CF["Cloudflare Tunnel n8n.prsnl.fyi"]
  CF --> Gate["quip-n8n-gate (Caddy basic-auth, 127.0.0.1:8090)"]
  Gate --> N8N
  Tailscale --> N8N["n8n container"]
  Localhost --> N8N
  N8N -->|Postgres| DB["n8n-db"]
  N8N -->|Task broker :5679| Runner["n8n-runners"]
  Runner -->|task results| N8N
```

The editor is reachable over Tailscale and, since 2026-06-01, via `https://n8n.prsnl.fyi` behind a Caddy HTTP Basic-Auth gate (`quip-n8n-gate`). The n8n container's own published ports still bind only to `100.103.66.92` and `127.0.0.1`, never `0.0.0.0`; the public path is the gate (bound `127.0.0.1:8090`) fronted by the Cloudflare Tunnel. There is no raw/unauthenticated public editor exposure. (Cloudflare Access was the intended gate, but Zero Trust requires a payment card; the Caddy basic-auth proxy is the card-free perimeter, with n8n's own owner login behind it.)

## Runtime Configuration

Core deployment choices:

- Postgres backend, not SQLite.
- External task runners, matching n8n's official hosting pattern.
- Native Python runner enabled for Python Code nodes.
- Filesystem binary data mode to keep binary payloads out of Postgres.
- Execution pruning enabled: 7 days (`168` hours) and max 10,000 executions.
- Metrics enabled at `/metrics`.
- Telemetry, personalization prompts, version notifications, and hiring banner disabled.
- `NODE_OPTIONS=--max-old-space-size=768` to keep Node heap below the 1 GiB container cap.

Next hardening items from the integration shortlist:

- Add `N8N_GIT_NODE_DISABLE_BARE_REPOS=true` during the next compose-hardening pass.
- Add a dedicated `/files` mount plus `N8N_RESTRICT_FILE_ACCESS_TO=/files` before workflows need local file read/write or OCR attachment processing.
- Add an n8n update wrapper that takes and verifies an off-host/restic-backed `n8n-db` backup before image pulls or container recreation.

Execution retention is intentionally still debug-friendly:

```env
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_PROGRESS=false
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=false
```

After the first Quip Discord workflows are stable, the safe optimization is:

```env
EXECUTIONS_DATA_SAVE_ON_SUCCESS=none
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_PROGRESS=false
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=false
```

## Security Model

Runtime hardening:

- `n8n` and `n8n-runners` run as uid/gid `1000:1000`.
- `no-new-privileges:true` is set on runtime containers.
- n8n settings file permission enforcement is enabled.
- Code-node environment access is blocked.
- Code-node access to n8n internal files is blocked.
- Images are pinned to explicit versions, not `latest`.

Security policy is managed by env:

```env
N8N_SECURITY_POLICY_MANAGED_BY_ENV=true
N8N_PERSONAL_SPACE_SHARING_ENABLED=false
N8N_PERSONAL_SPACE_PUBLISHING_ENABLED=false
N8N_MFA_ENFORCED_ENABLED=false
```

MFA enforcement is deliberately `false` until the owner account has MFA configured. Flip it only after verifying the owner can log in with MFA, or the instance can lock out the only operator.

Secrets:

- `N8N_ENCRYPTION_KEY` must never be lost or rotated casually; it encrypts stored n8n credentials.
- `N8N_DB_PASSWORD` and `N8N_RUNNERS_AUTH_TOKEN` live only in `~/docker/n8n/.env`.
- `.env` and future secret files such as `quip-discord-bot.env` must remain chmod `600` and uncommitted.

## Quip / Discord Integration Plan

Quip is the planned Discord assistant product. n8n is the orchestration layer; the editor must remain access-controlled (Tailscale, or `n8n.prsnl.fyi` behind the Caddy basic-auth gate) — never raw-public.

Target traffic model:

```mermaid
flowchart LR
  Discord["Discord private server/channel"] -->|Gateway / interactions| Bot["quip-discord-bot sidecar"]
  Bot -->|authorized event| N8NInternal["n8n internal webhook on n8n-net"]
  N8NInternal --> Tools["Groq, Docker proxy, Postgres, GlitchTip"]
  Bot -->|reply / follow-up| Discord
```

Hard requirements for Quip:

- No public Quip webhook in v1. The Discord bot connects outbound to Discord and calls n8n internally.
- n8n editor and REST API are never raw-public: reachable over Tailscale, or via `n8n.prsnl.fyi` behind the Caddy HTTP Basic-Auth gate (approved 2026-06-01). No unauthenticated public route.
- Discord owner/guild/channel allowlist and Discord event dedupe happen before n8n workflow execution.
- Prefer Discord slash commands so Message Content privileged intent is not needed in v1.
- n8n uses credentials for Groq and service APIs; Code nodes must not read secrets from `$env`.
- Tool outputs are redacted before reaching Groq.
- MOC remains excluded from every action.

Live Quip sidecars (Slice 1 + Slice 2, as of 2026-06-02):

| Service | Purpose | Exposure |
|---------|---------|----------|
| `quip-discord-bot` | Discord `/quip` + @mention + DM handling, allowlist, dedupe, n8n callback, **internal `POST /send`** (`:8787`) for proactive delivery | internal only; outbound to Discord; no host port |
| `quip-docker-proxy` | Read-only Docker API for container status | internal `n8n-net` only |
| `quip-db` | Postgres 16 — reminders / processed_events / messages (Slice 2) | internal `n8n-net` only; nightly restic backup (`quip-db-backup.timer`) |

Slice 2 n8n workflows (all active): `Quip` (main agent, Fireworks DeepSeek-V4-Flash), `get_container_status` (MOC-filtered, redacted), `set/list/cancel_reminder` (Postgres tools), `Quip Scheduler` (1-min cron → due reminders → bot `/send`), `Quip Digest` (09:00 IST → status → `/send`). Reminders fire proactively to Discord via the bot `/send` endpoint (bearer-gated, owner/guild allowlist). The docker-socket-proxy stays read-only; only Slice 3 will introduce guarded server-action writes.

Candidate community nodes, helper services, and self-hosting templates are tracked in `docs/N8N-INTEGRATION-SHORTLIST.md`. Treat that file as the gate before installing n8n community nodes or copying external compose patterns into the Dell stack.

For external workflow libraries, the policy is stricter: use them as pattern references only. Do not import public workflow JSONs into the live Dell n8n without disabling triggers, replacing all credentials/IDs/URLs, and reviewing every Code, HTTP Request, database, file, Execute Command, and AI-agent tool node.

## Deferred Choices

### Queue Mode

Do not enable queue mode yet.

Queue mode adds Redis, workers, and more operational surface. It is the major scalability switch, but this Dell host is a Celeron with 8 GB RAM and the current workload is single-user. There is also an important compatibility issue: n8n queue mode does not support filesystem binary storage. Moving to queue mode should be paired with a binary storage decision, likely S3-compatible storage, and only after workflow volume justifies it.

### Public HTTPS Host Vars

`n8n.prsnl.fyi` now exists (gated public editor, approved 2026-06-01), but these are intentionally **left unset / at the Tailscale values**:

```env
# NOT set — would pin n8n to a single base URL and degrade the Tailscale path
N8N_HOST=n8n.prsnl.fyi
N8N_PROTOCOL=https
WEBHOOK_URL=https://n8n.prsnl.fyi/
```

n8n supports only one base URL; setting these to the public host can break CSRF/absolute links on the Tailscale path (the documented primary admin route). The editor works over **both** paths via relative URLs + the gate's Caddy SSE handling (`flush_interval -1`, verified `/rest/settings` 200 through the gate). Set the public host vars only if off-tailnet editing actually misbehaves after owner signup — accepting that it makes the public host primary. For Quip v1 the bot calls n8n's webhook **internally**, so no public webhook hostname is needed regardless.

### ntfy

ntfy is a soft yes for infrastructure alerts, not for Quip v1.

Good future uses:

- Uptime Kuma / Netdata real-time infra alerts.
- Backup failed / stale backup alerts.
- Reboot complete alerts.
- n8n workflow failure notifications.
- Long-running maintenance completion.

Do not use ntfy as:

- The Quip command interface.
- A replacement for Quip's 9 am Discord digest and reminders.

If deployed later, make it private by default:

- Suggested path: `~/docker/ntfy/`.
- Suggested local origin: `127.0.0.1:8091`.
- Suggested Tailscale admin bind: `100.103.66.92:8091`.
- `auth-default-access: deny-all`.
- Separate publish and read credentials.
- No attachments initially.

## Operations

Render config locally:

```bash
N8N_DB_PASSWORD=dummy \
N8N_ENCRYPTION_KEY=dummy \
N8N_RUNNERS_AUTH_TOKEN=dummy \
docker compose -f docker/n8n/docker-compose.yml config
```

Deploy the committed compose to the server:

```bash
scp docker/n8n/docker-compose.yml pronav@100.103.66.92:~/docker/n8n/docker-compose.yml
ssh pronav@100.103.66.92 'cd ~/docker/n8n && docker compose -f docker-compose.yml up -d'
```

Verify health and exposure:

```bash
ssh pronav@100.103.66.92 '
  cd ~/docker/n8n
  docker compose -f docker-compose.yml ps
  curl -fsS http://127.0.0.1:5678/healthz
  curl -fsS http://127.0.0.1:5678/metrics | sed -n "1,8p"
  docker ps --filter name=n8n --format "{{.Names}} {{.Ports}}"
'
```

Expected exposure:

- `n8n`: `100.103.66.92:5678->5678/tcp`, `127.0.0.1:5678->5678/tcp`
- `n8n-runners`: internal only
- `n8n-db`: internal only
- no `0.0.0.0`

Check runtime hardening:

```bash
ssh pronav@100.103.66.92 '
  for c in n8n n8n-runners; do
    docker inspect "$c" --format "$c user={{.Config.User}} security={{json .HostConfig.SecurityOpt}} mem={{.HostConfig.Memory}}"
    docker exec "$c" id
  done
'
```

## Backup and Recovery Requirements

n8n now stores automation workflows, execution history, encrypted credentials, and planned Quip data. It needs the same durability discipline as project databases.

Hard requirements:

- Nightly backup of `n8n-db`.
- Separate secure backup of `N8N_ENCRYPTION_KEY`.
- Restore drill documented before relying on Quip reminders/notes.
- Weekly maintenance should check n8n backup freshness once the backup timer exists.

Losing `N8N_ENCRYPTION_KEY` means credentials stored in n8n are unrecoverable even if the database restore succeeds.

## References

- n8n environment variables: `https://docs.n8n.io/hosting/configuration/environment-variables/`
- n8n security environment variables: `https://docs.n8n.io/hosting/configuration/environment-variables/security/`
- n8n execution data pruning: `https://docs.n8n.io/hosting/scaling/execution-data/`
- n8n binary data scaling: `https://docs.n8n.io/hosting/scaling/binary-data/`
- n8n queue mode: `https://docs.n8n.io/hosting/scaling/queue-mode/`
- n8n metrics: `https://docs.n8n.io/hosting/configuration/configuration-examples/prometheus/`
- ntfy configuration and auth: `https://docs.ntfy.sh/config/`
- ntfy publish API: `https://docs.ntfy.sh/publish/`
