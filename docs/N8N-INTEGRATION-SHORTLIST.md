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

Why it matters:

- Shows a clean queue-mode topology: main n8n process, Redis, Postgres, and worker replicas.
- Uses a shared env anchor so master/worker settings do not drift.
- Includes useful security/env examples: settings-file permissions, file access restriction, Git bare-repo blocking, env access blocking, diagnostics off, metrics on, and queue health checks.
- Includes filesystem binary storage, Postgres backup script, and backup-before-update workflow.
- Caddy config includes the important SSE-friendly `flush_interval -1` reverse-proxy pattern.

Do not copy wholesale:

- It exposes the full n8n app through Caddy on public 80/443. The Dell design keeps the editor Tailscale-only.
- It also publishes `5678:5678`; the Dell compose must stay bound to `127.0.0.1` and `100.103.66.92`, never `0.0.0.0`.
- It uses floating tags (`caddy:latest`, `redis:alpine`, `postgres:17`, `n8nio/n8n:stable`). The Dell stack should stay version-pinned.
- Its retention defaults are too large for the Dell (`60` days and `1,000,000` executions). Current Dell retention is intentionally `7` days / `10,000`.
- Its worker scale is heavy for the Celeron (`2` workers, concurrency `10`). The Dell should not move there without measured execution volume.
- Its backup is only a local compressed `pg_dump`; Dell still needs restic/off-host backup and a restore drill.

Cherry-pick checklist:

- Keep the current Tailscale-only editor and localhost origin.
- Keep resource caps before adding any worker/Redis surface.
- If queue mode is revisited, decide binary storage first. n8n queue mode and local filesystem binary storage are a known design conflict for this server.
- Consider adapting the backup-before-update idea, but wire it into the existing restic/weekly-maintenance model.
- Keep Caddy/SSE notes only for a future Cloudflare Access-gated editor or public webhook route; do not expose the editor by default.

Source:

- `https://github.com/AiratTop/n8n-self-hosted`

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
