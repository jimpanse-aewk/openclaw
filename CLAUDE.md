# Project: openclaw

Status: BROKEN
Last verified: 2026-04-28
Last audited: 2026-04-28

## Handover
- HANDOVER.md — pickup card, read first
- README.md — human overview
- docs/ — detailed docs (if present)

## Loads
- context/machines/openclaw.md
- context/services/openclaw-bot.md
- context/services/home-assistant.md
- context/services/elk.md
- context/services/netalertx.md
- context/services/suricata.md
- context/topology/lan-86.md
- context/topology/tailscale.md
- context/ops/ssh-keys.md
- context/ops/conventions.md
- context/ops/backup.md

## Goal
Versioned snapshot of the OpenClaw bot's configuration, agents, and workspace context files. The live bot runs on `openclaw` (`192.168.86.8`, user `clown`) as a user systemd unit (`openclaw-gateway.service`) fronting `@Clown_ha_bot` on Telegram plus a WhatsApp binding. Edits flow repo → openclaw on deploy; runtime state (sessions, memory, credentials, logs) stays on the host.

## Current state
- OpenClaw `v2026.4.2` (`d74a122`), installed under `/home/clown/.npm-global/`, running as `openclaw-gateway.service` (user scope). Listens on `127.0.0.1:18789`.
- Agents wired in `openclaw.json`: `main → agents/soc`, `ha-agent → agents/ha`, `trading` (parked — no Telegram binding). Model: `anthropic/claude-haiku-4-5` on `main` and `ha-agent`; trading inherits default.
- Telegram routing: supergroup `-1003941975878` (Administrators) → `ha-agent` (tier-1 peer match); everything else → `main`.
- WhatsApp routing: `+66656899706` → `main` (allowlist).
- SOC digest refreshed every 5 min by clown cron `*/5 * * * * soc_sync.sh` pulling from ELK (`.86.5`).

## Out of scope
- HA entity inventory, Suricata rule tuning, NetAlertX DB — owned by the SOC / HA ops runbooks on ELK (`jimpanse-aewk/soc`).
- Fleet liveness monitoring — owned by `jimpanse-aewk/heartbeat`.
- Host backups — owned by `jimpanse-aewk/backupSOC`.
- Bot-writable runtime state and rollback files — see Commit hygiene.

## Active TODOs (ordered)
1. **(investigation)** Purpose of the second local user account `openclaw` (uid 1001) is unknown. Noted in `docs/OPENCLAW_HANDOVER.md` open-questions. Establish what it's for, then either document or remove.
2. **(upstream, known issue)** WhatsApp stale-socket restart cycle fires every ~35 min (`health-monitor: restarting (reason: stale-socket)`). Documented in `docs/troubleshooting.md`. Workaround is the restart itself; root-cause fix unclear, may need upstream report.
3. **(scheduled session)** Haiku → Sonnet switch: decision record, live edit of `openclaw.json`, restart, verify both agents respond. Blocked on credit top-up (see Live issues).

## Reference
- `docs/OPENCLAW_HANDOVER.md` — 793-line operator handover (v2 2026-04-14, mirrored from `~/.openclaw/OPENCLAW_HANDOVER.md` on the host). Canonical for routing, schemas, CLI, known gotchas.
- `docs/PICKUP.md` — operator pickup card (Health check, Safe restart, runtime/host facts, full doc index). Relocated from root during 2026-04-28 retrofit.
- `docs/integrations.md` — HA, SOC, Telegram, WhatsApp wiring.
- `docs/troubleshooting.md` — billing errors, session wipe, WhatsApp restart cycle, safe-restart recipe.
- `agents/README.md` — agent id → agentDir mapping and parked-agent rules.
- `~/dev/context/machines/openclaw.md` — host facts (IP, SSH, Tailscale).
- `~/dev/context/services/openclaw-bot.md` — bot-as-service summary.
- `~/dev/docs/audit-report-20260417-1106.md` — OpenClaw ground-truth audit from 2026-04-17 (point-in-time snapshot).

## Commit hygiene
Never commit any of the following to this repo:
- Anything under `~/.openclaw/sessions/`, `~/.openclaw/memory/`, `~/.openclaw/credentials/`, `~/.openclaw/logs/`, `~/.openclaw/flows/`.
- Anything under `/tmp/openclaw/`.
- `openclaw.json.bak*` rollback files (keep host-only; `scp` on demand).
- Raw API keys or Telegram/WhatsApp tokens. Credential material lives in `~/.openclaw/credentials/` on the host, never here.

If any of the above appear in `git status`, stop and investigate before staging.

## ⚠️ Live issues (read first)
- **Billing — credit balance too low.** Anthropic API credits exhausted. Gateway is up, channels are connected, every agent turn returns the billing error. **Top up credits before anything else.**
- **Pending runtime change (separate session):** Haiku → Sonnet model switch on `main` / `ha-agent`. Not a repo-level task; see `docs/troubleshooting.md` for context. Tracked as TODO 3.

## Incidents
_None recorded in this repo._ Billing exhaustion (see Live issues) is current-state, not a resolved incident — move it here once cleared.

## Session end checklist
- Commit identity: `Jim <cookiehacker32@gmail.com>` — verify before every commit, do not carry forward from prior turns.
