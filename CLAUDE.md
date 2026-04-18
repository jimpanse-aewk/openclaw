# Project: openclaw

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
Versioned snapshot of the OpenClaw bot's configuration, agents, and workspace
context files. The live bot runs on `openclaw` (`192.168.86.8`, user `clown`)
as a user systemd unit (`openclaw-gateway.service`) fronting `@Clown_ha_bot`
on Telegram plus a WhatsApp binding. Edits flow repo → openclaw on deploy;
runtime state (sessions, memory, credentials, logs) stays on the host.

## Current state
- OpenClaw `v2026.4.2` (`d74a122`), installed under `/home/clown/.npm-global/`,
  running as `openclaw-gateway.service` (user scope). Listens on `127.0.0.1:18789`.
- Agents wired in `openclaw.json`: `main → agents/soc`, `ha-agent → agents/ha`,
  `trading` (parked — no Telegram binding). Model: `anthropic/claude-haiku-4-5`
  on `main` and `ha-agent`; trading inherits default.
- Telegram routing: supergroup `-1003941975878` (Administrators) → `ha-agent`
  (tier-1 peer match); everything else → `main`.
- WhatsApp routing: `+66656899706` → `main` (allowlist).
- SOC digest refreshed every 5 min by clown cron `*/5 * * * * soc_sync.sh`
  pulling from ELK (`.86.5`).
- **Live failure mode today:** Anthropic API credit balance exhausted. Gateway
  is up, channels are connected, every agent turn returns `billing — credit
  balance too low`. Top up credits before anything else.
- **Pending runtime change (separate session):** Haiku → Sonnet model switch
  on `main` / `ha-agent`. Not a repo-level task; see `docs/troubleshooting.md`
  for context.

## Out of scope
- Bot-writable runtime state on the host: `~/.openclaw/sessions/`,
  `~/.openclaw/memory/YYYY-MM-DD.md`, `~/.openclaw/credentials/`,
  `~/.openclaw/logs/`, `~/.openclaw/flows/`, `/tmp/openclaw/*.log`.
- HA entity inventory, Suricata rule tuning, NetAlertX DB — owned by the SOC
  / HA ops runbooks on ELK (`jimpanse-aewk/soc`).
- Fleet liveness monitoring — owned by `jimpanse-aewk/heartbeat`.
- Host backups — owned by `jimpanse-aewk/backupSOC`.
- Historical `openclaw.json.bak*` files — kept on-host only; `scp` on demand.

## Active TODOs
- [ ] Review the second local user account `openclaw` (uid 1001) — purpose
      unknown, noted in `docs/OPENCLAW_HANDOVER.md` open-questions.
- [ ] WhatsApp stale-socket restart cycle fires every ~35 min
      (`health-monitor: restarting (reason: stale-socket)`). Documented as a
      known issue in `docs/troubleshooting.md`. Workaround is the restart
      itself; fix unclear, may need upstream.
- [ ] Fold Haiku → Sonnet switch into a dedicated session (decision record,
      live edit of `openclaw.json`, restart, verify both agents respond).
- [ ] `context/services/openclaw-bot.md` cross-linked to this repo — re-sync
      whenever runtime layout changes materially (unit name, port, agent set).

## Reference
- `docs/OPENCLAW_HANDOVER.md` — 792-line operator handover (v2 2026-04-14,
  mirrored from `~/.openclaw/OPENCLAW_HANDOVER.md` on the host). Canonical
  for routing, schemas, CLI, known gotchas.
- `docs/integrations.md` — HA, SOC, Telegram, WhatsApp wiring.
- `docs/troubleshooting.md` — billing errors, session wipe, WhatsApp restart
  cycle, safe-restart recipe.
- `agents/README.md` — agent id → agentDir mapping and parked-agent rules.
- `~/dev/context/machines/openclaw.md` — host facts (IP, SSH, Tailscale).
- `~/dev/context/services/openclaw-bot.md` — bot-as-service summary.
- `~/dev/docs/audit-report-20260417-1106.md` — OpenClaw ground-truth audit
  from 2026-04-17 (point-in-time snapshot).
