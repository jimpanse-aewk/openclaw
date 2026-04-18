# agents/

Snapshot of the three agent system prompts wired into OpenClaw on the live
host. Each subfolder matches an entry in `openclaw.json → agents.list`.

## id → agentDir mapping (from `conf/openclaw.json.example`)

| Agent id | Live `agentDir` on host | This repo |
|---|---|---|
| `main` | `/home/clown/.openclaw/agents/soc/agent/` | `agents/soc/system.md` |
| `ha-agent` | `/home/clown/.openclaw/agents/ha/agent/` | `agents/ha/system.md` |
| `trading` | `/home/clown/.openclaw/agents/trading/agent/` | `agents/trading/system.md` |

**The id is the public name; the directory is the implementation.** On
2026-04-14 the id-vs-dir split was introduced so Telegram bindings could stay
stable while the underlying prompt files were swapped to v2 versions (`soc/`,
`ha/`) — preserving the bindings, discarding session history.

## Directories NOT mirrored here

| On host | Why excluded |
|---|---|
| `/home/clown/.openclaw/agents/main/sessions/` | runtime state — live conversations |
| `/home/clown/.openclaw/agents/ha-agent/sessions/` | runtime state |
| `/home/clown/.openclaw/agents_retired/` | archived prompts, host-only |
| `/home/clown/.openclaw/workspace-trading/` | unchanged since 2026-03-17; unused. Keep on host only — see `trading/PARKED.md`. |

## Workspace vs system.md

- `agents/<x>/system.md` — the **top-level system prompt**, read per-turn.
- `workspace/` (this repo) — the `main` agent's read-at-session-start context
  (IDENTITY, SOUL, TOOLS, MEMORY, AGENTS, USER, etc.).
- `workspace-ha-agent/` (this repo) — the `ha-agent` equivalent.
- `ha-agent-context/` (this repo) — `/home/clown/ha-agent/` on the host: an
  extra context bundle the HA agent loads during startup (HA_SNAPSHOT,
  HA_OPS, HA_QUICK, CLAUDE, IDENTITY).

Changes to `system.md` take effect on the **next message** — no gateway
restart needed. Changes to `bindings[]` in `openclaw.json` require a
`systemctl --user restart openclaw-gateway.service`.

## Deploying a prompt edit

From a rawmeo session with the repo checked out:

```bash
# Example: push updated SOC system prompt to the live host
scp -P 22222 -i ~/.ssh/openclaw_elk_ed25519 \
    agents/soc/system.md \
    clown@192.168.86.8:/home/clown/.openclaw/agents/soc/agent/system.md
```

No restart required; the next turn picks it up. Verify with
`ssh claw '/home/clown/.npm-global/bin/openclaw health'`.
