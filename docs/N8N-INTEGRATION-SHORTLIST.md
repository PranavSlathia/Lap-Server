# n8n / Quip Integration Shortlist

Last updated: 2026-06-01.

This is the durable review list for n8n community nodes, helper services, and external self-hosting templates that might improve Quip or the Dell n8n deployment.

This is not an install list. Anything marked yay still needs a focused implementation pass, staging check, and rollback path before it touches the live Dell server.

## Verdict Legend

| Verdict | Meaning |
|---------|---------|
| Yay | Worth adding or prototyping after the current Quip slice finishes. |
| Conditional yay | Useful capability, but only with explicit guardrails. |
| Reference yay | Good source of patterns, not a drop-in dependency. |
| Nay | Do not install for Quip / Dell n8n unless the product plan changes. |

## Yay Backlog

### n8n-nodes-tesseractjs / OCR

Verdict: conditional yay for prototype; yay for the product capability.

Add window: after Quip Slice 1 proves the Discord pipe.

Why it matters:

- Lets Quip read Discord image attachments and screenshots.
- Pairs well with Groq for "extract the error", "summarize this image", "turn this screenshot into a task", and "read this bill / note / receipt".
- Fits the Discord pivot better than the old WhatsApp media path.

Guardrails:

- Prefer a small capped OCR sidecar if the community node strains n8n memory.
- If the node is used directly, test it in staging first and watch n8n RSS during repeated OCR jobs.
- Image-only first. No PDFs until memory and timeout behavior are proven.
- Enforce max file size, timeout, MIME allowlist, and one OCR job at a time on the Dell.
- Never OCR arbitrary URLs. Only process attachments from the allowlisted Discord owner/channel.
- OCR output must pass through Quip's `redact()` gate before Groq sees it.

Source:

- `https://www.npmjs.com/package/n8n-nodes-tesseractjs`

### AiratTop/n8n-self-hosted

Verdict: reference yay, not a drop-in deploy.

Add window: after Quip Slice 1, during the next n8n infra-hardening review.

Review snapshot: repo checked on 2026-06-01. The default branch was `main`, last pushed 2026-04-14, with 10 stars / 4 forks. Treat it as a small but useful reference template, not as a mature upstream dependency.

Why it matters:

- Shows a clean queue-mode topology: main n8n process, Redis, Postgres, and worker replicas.
- Uses a shared env anchor so master/worker settings do not drift.
- Includes useful security/env examples: settings-file permissions, file access restriction, Git bare-repo blocking, env access blocking, diagnostics off, metrics on, and queue health checks.
- Includes filesystem binary storage, Postgres backup script, and backup-before-update workflow.
- Caddy config includes the important SSE-friendly `flush_interval -1` reverse-proxy pattern.

Already covered on the Dell:

- Postgres backend instead of SQLite.
- Filesystem binary mode for the current non-queue setup.
- Metrics enabled.
- Telemetry / personalization / version noise disabled.
- n8n editor kept private on Tailscale, not exposed through a public reverse proxy.
- Version-pinned n8n images, resource caps, non-root runtime user, and `no-new-privileges`.

Useful lessons to add or keep in the backlog:

| Lesson from AiratTop | Dell action | Timing |
|----------------------|-------------|--------|
| Backup before updates | Add an n8n update wrapper that refuses to pull/recreate if the `n8n-db` backup fails, records image versions, then runs the update. Use restic/off-host storage, not just a local dump. | After the n8n-db nightly backup exists. |
| Dedicated workflow file area | Add a `/files` mount plus `N8N_RESTRICT_FILE_ACCESS_TO=/files` before enabling workflows that read/write local files or OCR attachments. This limits file-node blast radius. | Before OCR/file-heavy Quip workflows. |
| Git-node hardening | Add `N8N_GIT_NODE_DISABLE_BARE_REPOS=true` in the next compose-hardening pass, after rendering config successfully. | Low-risk future compose update. |
| Queue-mode env parity | If queue mode is ever enabled, use a common env anchor for main + workers so DB, Redis, encryption key, security, and pruning settings cannot drift. | Only when queue mode is justified. |
| Queue health checks | If queue mode is enabled, add Redis health checks and `QUEUE_HEALTH_CHECK_ACTIVE=true`; keep Redis internal-only and passworded. | Only with queue mode. |
| Conservative worker scaling | Airat runs two workers at concurrency 10. On the Dell, start at one worker with concurrency 1-2 and scale only from measured execution backlog. | Only with queue mode. |
| Reverse-proxy SSE handling | If an Access-gated HTTPS n8n route is added later, preserve Caddy/nginx SSE behavior (`flush_interval -1` equivalent), add `X-Robots-Tag: noindex`, and keep the editor behind auth. | Only if a public/Access-gated editor route is explicitly approved. |
| SMTP recovery | Consider SMTP only for account recovery / notifications. It is not needed for Quip Slice 1 and introduces another secret to manage. | Optional, after owner account setup. |

Do not copy wholesale:

- It exposes the full n8n app through Caddy on public 80/443. The Dell design keeps the editor Tailscale-only.
- It also publishes `5678:5678`; the Dell compose must stay bound to `127.0.0.1` and `100.103.66.92`, never `0.0.0.0`.
- It uses floating tags (`caddy:latest`, `redis:alpine`, `postgres:17`, `n8nio/n8n:stable`). The Dell stack should stay version-pinned.
- Its retention defaults are too large for the Dell (`60` days and `1,000,000` executions). Current Dell retention is intentionally `7` days / `10,000`.
- Its worker scale is heavy for the Celeron (`2` workers, concurrency `10`). The Dell should not move there without measured execution volume.
- Its backup is only a local compressed `pg_dump`; Dell still needs restic/off-host backup and a restore drill.
- Its update script uses `docker compose down`, which is unnecessary downtime for the Dell unless the update specifically requires a full stop. Prefer backup, pull/build, `up -d`, health check, and rollback notes.

Cherry-pick checklist:

- Keep the current Tailscale-only editor and localhost origin.
- Keep resource caps before adding any worker/Redis surface.
- If queue mode is revisited, decide binary storage first. n8n queue mode and local filesystem binary storage are a known design conflict for this server.
- Consider adapting the backup-before-update idea, but wire it into the existing restic/weekly-maintenance model.
- Keep Caddy/SSE notes only for a future Cloudflare Access-gated editor or public webhook route; do not expose the editor by default.

Source:

- `https://github.com/AiratTop/n8n-self-hosted`
- n8n security env reference: `https://docs.n8n.io/hosting/configuration/environment-variables/security/`
- n8n binary data scaling reference: `https://docs.n8n.io/hosting/scaling/binary-data/`
- n8n queue mode reference: `https://docs.n8n.io/hosting/scaling/queue-mode/`

### Zie619/n8n-workflows

Verdict: reference yay, import nay.

Add window: after Quip Slice 1, when designing Slice 2+ workflows and the first real n8n exports.

Review snapshot: repo checked on 2026-06-01. It is active, MIT-licensed, very popular, and last pushed 2026-05-31. GitHub metadata showed 54k+ stars and 7k+ forks. The latest release was a 2025-08-14 history rewrite for DMCA compliance, so treat provenance as mixed and use it for internal design reference only.

What it is:

- A large searchable corpus of n8n workflow JSONs and a small FastAPI/GitHub Pages browser.
- The checked-out repo contained 2,061 workflow JSON files under `workflows/`; its generated site metadata advertised 4,343 workflows.
- The corpus covers many nodes Quip will likely need later: Discord, schedule triggers, Respond to Webhook, Extract From File, Postgres, GitHub, OpenAI/LLM, HTTP Request, and workflow backup patterns.

Why it matters:

- Good inspiration library for Quip workflow structure once the Discord pipe is working.
- Useful examples for digest-like scheduled workflows, Discord delivery, file extraction/OCR-adjacent flows, response formatting, n8n workflow export/backup, and error-node placement.
- Useful negative examples too: it shows how quickly public webhooks, Code nodes, HTTP Request, Execute Command, and AI-agent/tool combinations expand the attack surface.

Findings from local scan:

| Signal | Count / note |
|--------|--------------|
| Workflow JSON files in clone | 2,061 |
| Category directories | 188 |
| Files with credential references | 1,752 |
| Files with webhook IDs | 1,051 |
| Files with `$env` expressions | 1,415 |
| Files with execute-command references | 23 |
| Files with AI-agent / LLM / MCP-ish references | 622 |
| Common node types | HTTP Request, Code, Webhook, Respond to Webhook, Schedule Trigger, Extract From File, Postgres, Discord |

Useful Quip searches to revisit:

- Discord response patterns: `workflows/Webhook/*Discord*`, `workflows/Discord*`, `workflows/Discordtool*`.
- Digest and scheduled work: `workflows/Schedule/*`, `workflows/Wait/*Schedule*`, `workflows/Http/*Schedule*`.
- OCR/file intake structure: `workflows/Extractfromfile/*`, `workflows/Readbinaryfiles/*`, `workflows/Code/*Extractfromfile*`.
- Workflow export/backup idea: `workflows/Code/0628_Code_Schedule_Export_Scheduled.json` and the Gitea variant.
- Postgres/assistant data patterns: `workflows/Postgrestool/*`, `workflows/Postgres/*`.

Do not copy wholesale:

- Do not import any workflow directly into the live Dell n8n.
- Do not activate imported webhooks or schedules without rebuilding triggers and auth.
- Do not reuse credential IDs, credential names, webhook IDs, hardcoded repo names, public URLs, or environment references.
- Do not copy Code, HTTP Request, Execute Command, Postgres, GitHub, or AI-agent tool chains without line-by-line review.
- Do not treat generated metadata such as "production-ready", "excellent", or "optimized" as an assurance. It is labeling, not proof.

Workflow intake rule:

1. Use the repo as a pattern search library only.
2. Copy the idea into a new Quip workflow; do not import the raw JSON as production.
3. If importing for inspection, keep the workflow disabled and remove triggers first.
4. Replace all credentials, webhook paths, URLs, environment expressions, schedule rules, and IDs.
5. Review every Code, HTTP Request, database, file, Execute Command, AI Agent, and tool node before activation.
6. Add redaction before Groq for any server, log, file, OCR, or third-party output.
7. Export the final Quip workflow to the Quip repo and keep the Dell server docs in sync.

Source:

- `https://github.com/Zie619/n8n-workflows`

## Parked / Rejected

These were reviewed and should not be reintroduced without a new product requirement.

| Candidate | Verdict | Reason |
|-----------|---------|--------|
| `n8n-nodes-sshv2` | Nay | Direct SSH/file/command access is too broad for an LLM-orchestrated assistant. Use audited sidecars and narrow Docker/API proxies instead. |
| `n8n-nodes-datastore` | Nay | In-memory datastore and archived project. Use Postgres or official n8n data storage patterns instead. |
| `n8n-nodes-evolution-api` | Nay for current plan | WhatsApp/Evolution is out of Quip v1 after the Discord pivot. |
| `n8n-nodes-evolution-api-media-downloader` | Hard nay | WhatsApp-only, stale/fragile package path, and no value after the Discord pivot. |

## Intake Rule

Before adding anything here:

- Pull or inspect the source locally.
- Check maintenance status, release recency, package dependencies, security advisories, and whether it expands the attack surface.
- Classify it as product capability, n8n node, sidecar, or deployment template. Do not let a useful capability imply that the exact package is safe to install.
- Record the guardrails that make the yay safe on the Dell's 2-core / 8 GB resource budget.
