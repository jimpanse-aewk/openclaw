<!-- Overwrite (never append) at session end to keep a single current pickup card. -->

# HANDOVER — openclaw

<!-- UNVERIFIED 2026-04-28 — body fields synthesized by Claude, not yet operator-confirmed. -->

## Status

BROKEN

## Last session

2026-04-28 — Skeleton-compliance retrofit. CLAUDE.md reshaped to post-Q11 head-shape with `Status: BROKEN` line ahead of Q14 amendment. HANDOVER.md authored fresh in spec six-section shape; existing root pickup-card content moved to `docs/PICKUP.md` via `git mv` (history preserved). CHANGELOG.md authored with retrofit + historical entries. `.gitignore` unchanged (already spec-canonical 8/8).

## Current state

Gateway process running, Telegram and WhatsApp channels connected, but bot is **effectively non-functional** — Anthropic API credits exhausted, every agent turn returns `billing — credit balance too low`. No diagnostic action restores function until credits are topped up.

Repo state post-retrofit: working tree clean. Skeleton-compliance shape landed.

Pending runtime changes (live-host edits, not in this repo):
- Haiku → Sonnet model switch on `main` and `ha-agent` agents — blocked on credit top-up. After top-up: `openclaw config set agents.list[0].model anthropic/claude-sonnet-4-6` (and equivalent for ha-agent), then `systemctl --user restart openclaw-gateway.service`. Add a decision record at `docs/openclaw-model-switch.md` when it lands.

## Next action

Top up Anthropic credits. Verify bot answers messages again (`ssh claw 'openclaw health'` + send a Telegram test). Once verified WORKING, transition `## Status` in this file and in CLAUDE.md to `WORKING` in a separate commit. Then queue the Haiku → Sonnet switch as the next session.

## Open questions

1. Second local user `openclaw` (uid 1001) — purpose unknown, noted at onboarding 2026-04-18. Likely legacy service-user pattern; confirm or remove.
2. WhatsApp integration is live and intentional, but the stale-socket restart cycle (~35 min) is a bug masquerading as a feature. Fix vs ignore TBD; root cause unclear, may need upstream report.
3. `gateway.auth.token` inside `openclaw.json` — local-loopback token. Low-risk if the machine is trusted, but it's still a credential; decide whether the committed `.example` should include a placeholder value or a different sanitisation story.

## Carry-forward context

Where it runs:
- Host: `openclaw` (`192.168.86.8`, user `clown`, ssh alias `claw`)
- Entry: `/home/clown/.npm-global/bin/openclaw` → `…/openclaw/openclaw.mjs`
- Unit: `~/.config/systemd/user/openclaw-gateway.service`
- Config: `/home/clown/.openclaw/openclaw.json`
- Secrets: `/home/clown/.config/openclaw/secrets.env` (`EnvironmentFile=` drop-in)
- Version: `2026.4.2` (`d74a122`)

Repo boundary — runtime state stays on host:
- `~/.openclaw/sessions/`, `~/.openclaw/memory/`, `~/.openclaw/credentials/`
- `~/.openclaw/openclaw.json.bak*` (rollback backups, scp on demand)
- `/home/clown/.config/openclaw/secrets.env` (real secrets)
- `/tmp/openclaw/openclaw-YYYY-MM-DD.log` (json logs)

Repo-side artifacts: `conf/*.example` (sanitized templates), `systemd/` unit file, `agents/*/system.md`, `workspace/`, `workspace-ha-agent/`, `ha-agent-context/`, `scripts/`, `docs/OPENCLAW_HANDOVER.md` (manual mirror).

Operational runbooks (Health check, Safe restart, diagnostic ladder): `docs/PICKUP.md` (relocated 2026-04-28 retrofit). Deep technical reference: `docs/OPENCLAW_HANDOVER.md` (793 lines, mirrored from host). Troubleshooting recipes: `docs/troubleshooting.md`.
