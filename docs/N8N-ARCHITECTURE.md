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

Live Quip sidecars (Slice 1 + Slice 2 + Slice 3, as of 2026-06-02):

| Service | Purpose | Exposure |
|---------|---------|----------|
| `quip-discord-bot` | Discord `/quip` + @mention + DM handling, allowlist, dedupe, n8n callback, **internal `POST /send`** (`:8787`) for proactive delivery, Confirm/Cancel buttons + `confirm/cancel <token>` text (owner-only) | internal only; outbound to Discord; no host port |
| `quip-docker-proxy` | Read-only Docker API for container status (`POST 0`, `EXEC 0`) | internal `n8n-net` only |
| `quip-db` | Postgres 16 — reminders / processed_events / messages / **pending_actions** (Slice 3 audit) | internal `n8n-net` only; nightly restic backup (`quip-db-backup.timer`) |
| `quip-action-executor` | **Sole docker-write path** (Slice 3): bearer-gated Node sidecar over `/var/run/docker.sock`; whitelist `restart/start/stop/cleanup`; refuses MOC + `quip-*` + n8n-core; resolves hash-prefixed container names | internal `n8n-net` only; **no host port**; runs as root for socket access |

Slice 2 n8n workflows (all active): `Quip` (main agent, Fireworks DeepSeek-V4-Flash), `get_container_status` (MOC-filtered, redacted), `set/list/cancel_reminder` (Postgres tools), `Quip Scheduler` (1-min cron → due reminders → bot `/send`), `Quip Digest` (09:00 IST → status → `/send`). Reminders fire proactively to Discord via the bot `/send` endpoint (bearer-gated, owner/guild allowlist).

Slice 3 — guarded server-action writes (all active): the agent calls **`propose_action`** (`quipProposeAct1`) for any restart/start/stop/cleanup; it validates the whitelist + protected-set (MOC / `quip-*` / n8n-core refused), mints a short confirm token, stages a `pending_actions` row, and returns the token for the bot to attach Confirm/Cancel buttons. A separate **no-LLM `Quip Confirm`** workflow (`quipConfirm0001`, webhook `quip-confirm`) looks up the token (scoped to `user_id`), checks pending + unexpired, and on **execute** calls `quip-action-executor` (httpHeaderAuth cred `quipActCred0001`) then marks the row `executed`; cancel/expiry/used/non-owner all refuse without acting. Nothing runs without an explicit owner confirmation. The docker-socket-proxy itself remains read-only — the only write path is the audited, token-gated `quip-action-executor`.

Slice 4 — notes + keyword recall (all active): a new owner-scoped `notes` table in `quip-db` (`text`, `tags text[]`, a generated `tsvector` + GIN indexes; covered by the existing nightly backup) plus four agent tools — **`save_note`** (`quipSaveNote001`, auto-extracts `#hashtags` into `tags`), **`recall_notes`** (`quipRecallNot01`, ranked Postgres full-text search via `websearch_to_tsquery`, optional `#tag` filter), **`list_notes`** (`quipListNote001`), and **`delete_note`** (`quipDelNote0001`). FTS only (no embeddings on the Celeron yet) — the `text`/`tsv` column is left as a clean seam for a future `pgvector` semantic recall. No bot code change; replies pass through the existing `redact()` gate.

Slice 5 — alerts + richer UX (all active). Tables `alert_state` + `followups` added to `quip-db`. Four pieces:
- **Real-time incident alerts** — `quipAlertCheck1` cron (every 5 min) reads container health from the read-only docker-proxy + host disk/CPU from Netdata (via the n8n-net bridge gateway `172.24.0.1:19999`; a UFW rule allows `172.24.0.0/16 → :19999`), runs an `alertEval` state machine (`alert_state`: alert once per incident + 6h cooldown re-ping + recovery), and DMs the owner via `/send`. MOC / `quip-*` / n8n-core never alerted; clean stops (exit 0) ignored.
- **Restart-target select menu** — bare `restart`/`stop`/`start` (no target) in the bot opens a `StringSelectMenu` of non-protected containers (options from the `quip-menu` webhook → `quipMenu00001`); picking one synthesizes `restart <target>` through the main pipe → existing Slice-3 Confirm/Cancel. Owner-only.
- **Digest weather + news** — `quipDigest00001` now fetches Open-Meteo (Jammu) + Hacker News RSS and feeds a weather line + top-5 headlines into the digest agent. Calendar intentionally skipped.
- **Post-action health follow-up** — `quipConfirm0001` enqueues a `followups` row (+3 min) after a successful restart/start; `quipFollowups1` cron (1 min) re-checks the container and DMs only if it's still unhealthy/down, then closes the row.

Slice 6 — spontaneous check-ins + GIFs everywhere (active): `quipCheckin0001` cron (every 15 min) reads a single-row `checkin_state` table; when a stored random `next_checkin_at` is due **and** the time is inside the 9am–3am IST window (quiet 3am–9am), it fetches a random dad joke + useless fact, has the persona LLM compose a short witty check-in **and** a GIF search phrase, then DMs the owner via `/send` with that phrase. The bot resolves the phrase to a GIF URL via the **KLIPY** API and appends it (Discord auto-embeds). KLIPY's key is a path param, so the bot (not n8n) holds it — `KLIPY_API_KEY` in the bot's chmod-600 env_file, never in the repo. Each fire rolls a new random next time (3–7h out, ~3/day; quiet-hours slots pushed to ~9am).

GIFs are universal: the bot's `renderWithGif` (shared by interactive replies and proactive `/send`) extracts a `[[gif: <phrase>]]` marker from any message text **or** an explicit `gif` field, resolves it via KLIPY, and embeds it. The persona tells the agent it can send GIFs via that marker (so "send me a gif" works). Reminders attach a random reminder GIF; alerts and post-action follow-ups attach a GIF by kind (problem vs recovery); the digest emits a mood-matched GIF marker. The `/send` contract's optional `gif` field is validated in `validateSend`.

Quip's persona now includes a self-aware **identity + capability map** (`quip-soul.md`): it knows what it is and everything it can do (see/manage/remember/GIFs + the proactive alerts/digest/check-ins/health-rechecks), so it describes itself accurately instead of denying powers it has.

**`quip-brain` (AI SDK brain — NOW THE PRODUCTION CONVERSATIONAL PATH, cut over 2026-06-02):** a code-first agent brain (Hono + Vercel AI SDK v6, `@ai-sdk/fireworks`) that **replaced the n8n agent node**. It exposes `POST /quip` matching the bot contract (`{…event} → {reply, confirm, gif}`), defines all tools as typed `tool({inputSchema, execute})` functions (39 vitest green, incl. the SDK mock model — the thing n8n couldn't do), and reuses the same persona + `redact` hard-gate. Runs as a standalone container (`docker run --restart unless-stopped`, image `quip-brain:dev`, built from `~/docker/n8n/quip/`) on `n8n-net` — no host port; env `quip-brain.env` (chmod-600) holds `FIREWORKS_API_KEY` + `PG*` (PGHOST=quip-db, PGUSER/PGDATABASE=quip, password copied verbatim from quip-db.env — never in repo/chat). **Full 9-tool parity:** `get_container_status`, `save/recall/list/delete_note` (FTS + #tags), `set/list/cancel_reminder` (recurrence), `propose_action` (mints token, stages into the shared `pending_actions` so the existing Confirm buttons + `quip-confirm` executor still run). The bot's `QUIP_USE_BRAIN=true` + `QUIP_BRAIN_URL=http://quip-brain:8080/quip` route conversational traffic to the brain; **n8n keeps cron/scheduling** (scheduler, digest, alerts, check-ins, follow-ups) and the confirm executor. **Rollback:** `QUIP_USE_BRAIN=false` + recreate the bot (the n8n agent workflow `quipMainPipe0001` is still importable). Now **compose-managed** (in `docker-compose.yml`, image `n8n-quip-brain`, mem 320M).

**External integrations (OpenClaw-inspired, Phase B).** Hybrid strategy: **Composio** (managed-OAuth connector, free tier) for OAuth apps, **Baileys** for WhatsApp (own number), **on-box PAT** for GitHub. **Gmail via Composio is LIVE (2026-06-02):** `COMPOSIO_API_KEY` in `quip-brain.env`; the brain exposes a `connect_integration` tool (returns a `connect.composio.dev` link the owner authorizes in-browser — picks the account, no guessing) plus curated Gmail tools (fetch/read/send/draft/reply). Connection is via `connectedAccounts.link(userId, authConfigId)` — the legacy `toolkits.authorize` endpoint is retired for managed configs. Execute modifiers force `verbose:false` + trim bodies so Gmail's full-HTML payloads (~90KB/email) can't blow the model's context. **WhatsApp via Baileys is LIVE (2026-06-02):** `quip-whatsapp` sidecar (standalone `docker run`, image `quip-whatsapp:dev`, on `n8n-net`, volume `quip-wa-auth`→`/data/wa-auth`, env `quip-whatsapp.env`) links the owner's OWN number (no Business API) via **QR scan** (pairing codes proved flaky; the sidecar writes a QR PNG to `/data/wa-qr.png`). Internal HTTP: `/health`, `/wa-send` (bearer-gated), `/wa-pair`. The brain's `send_whatsapp` tool posts to it. Notes: pin WA version (`fetchLatestBaileysVersion`) to avoid 405; expect `515 restartRequired`→reconnect after QR scan; wipe `/data/wa-auth` + restart on `401 loggedOut`. **Both `quip-brain` + `quip-whatsapp` are now compose-managed** (`docker-compose.yml`, images `n8n-quip-brain`/`n8n-quip-whatsapp`); the `quip-wa-auth` volume is declared `external` so `compose down` never drops the paired WhatsApp session. **Persistent memory** is live (brain stores conversational turns in the `messages` table and replays the last ~12 as `messages` to the model). **Security guardrails** are live: the persona treats fetched content (email/WhatsApp/web) as untrusted data (never instructions) and confirms before any send; `POST /quip` is bearer-gated by a shared `QUIP_BRAIN_TOKEN` (in `quip-brain.env` + `quip-discord-bot.env` + `quip-whatsapp.env`). **Skills loader** is live: markdown `SKILL.md` playbooks bundled at `src/skills/` (`COPY src/skills /app/skills`), surfaced via a `use_skill` tool + a system-prompt index (seeds: inbox-triage, email-draft, server-triage). Next: GitHub (PAT, deferred), then the Domain Hunter / discord.py pivot. Part of the broader direction — Discord as the universal frontend, with a Hono+AI-SDK brain, a Python discord.py bot for Domain Hunter (replacing dh-web), and LangGraph for DH's pipeline — assessed in the Quip repo.

Deferred items (digest rich embed, DH digest summaries, link summarization, semantic/graph recall, Send-and-Wait refactor, multi-user, GlitchTip error alerts) are tracked in the Quip repo's `docs/DEFERRED-BACKLOG.md`.

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
