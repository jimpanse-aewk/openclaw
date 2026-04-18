# openclaw

Versioned snapshot of the OpenClaw bot — configuration, agents, and workspace
context. Bot runs on the `openclaw` mini PC (`192.168.86.8`, user `clown`) and
fronts `@Clown_ha_bot` on Telegram plus a WhatsApp allowlist for `+66…706`.

## What this does

Holds the machine-agnostic parts of OpenClaw under git, so the agent prompts,
systemd unit, helper scripts, and workspace context files can be edited,
reviewed, and restored. Live runtime state (sessions, memory, credentials,
logs) stays on the host and is **not** part of this repo.

## Host snapshot

- Host: `openclaw` (Minisforum Venus mini PC), Ubuntu 24.04.3 LTS
- LAN: `192.168.86.8` — Tailscale: `100.69.198.82`
- SSH: port `22222`, user `clown`, key `openclaw_elk_ed25519`
- OpenClaw: `v2026.4.2` (build `d74a122`) under `/home/clown/.npm-global/`
- Unit: `openclaw-gateway.service` (user scope, `Restart=always`)
- Gateway: `127.0.0.1:18789` (loopback, token auth)

## Active agents (from `openclaw.json`)

| id | agentDir on host | Telegram routing | Model |
|---|---|---|---|
| `main` | `agents/soc/agent/` | catch-all (DMs + other groups) | haiku-4-5 |
| `ha-agent` | `agents/ha/agent/` | supergroup `-1003941975878` | haiku-4-5 |
| `trading` | `agents/trading/agent/` | **none — parked** | default |

See `agents/README.md` for the id-vs-dir split and how the parked `trading`
agent is handled.

## Repo layout

```
conf/              openclaw.json + secrets.env examples (real files quarantined)
systemd/           openclaw-gateway.service + drop-in template
scripts/           host scripts: soc_sync.sh (cron), oc_scan.sh, start-openclaw.sh, …
agents/            SOC + HA + trading system.md snapshots
workspace/         main agent workspace (IDENTITY/SOUL/TOOLS/MEMORY/AGENTS/USER/…)
workspace-ha-agent/ ha-agent workspace (same shape, HA-scoped)
ha-agent-context/  /home/clown/ha-agent/ — HA_SNAPSHOT/HA_OPS/HA_QUICK/CLAUDE/IDENTITY
docs/              OPENCLAW_HANDOVER (792 lines), integrations, troubleshooting
CLAUDE.md          Context manifest for Claude Code sessions
```

## Status

**Process: running.** Gateway active, Telegram + WhatsApp connected.
**Effective status: broken — Anthropic credits exhausted.** Every agent turn
returns `billing — credit balance too low`. Top up before anything else.

## See also

- `jimpanse-aewk/soc` — SOC tooling on ELK (socalert/socdoctor/socha binaries)
- `jimpanse-aewk/backupSOC` — automated SOC backup tool
- `jimpanse-aewk/heartbeat` — Tailscale fleet liveness
- `~/dev/context/services/openclaw-bot.md` — canonical bot-as-service facts
- `~/dev/docs/handover-2026-04-17.md` — dev/ architecture overview
