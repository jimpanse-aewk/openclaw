# trading agent — PARKED

**Parked date:** 2026-03-18 (system.md last modified)
**Status:** intentionally unbound — registered in `openclaw.json → agents.list`,
no Telegram/WhatsApp `bindings[]` entry, reachable only via direct API call.
**Workspace:** `/home/clown/.openclaw/workspace-trading/` (on host only,
last touched 2026-03-17; **not mirrored in this repo** — see
`agents/README.md`).

## Why this is here

Kept registered so that future work can flip a switch — add a binding in
`openclaw.json`, restart the gateway — and have the agent live again
without re-introducing the ID. Removing and re-adding would break any
persistent identity / session linkage the operator may want later.

## Why this is parked

No active trading workflow today. The agent inherits the default model
(`anthropic/claude-haiku-4-5`) and the system prompt has not been
revisited in the v2 refactor that updated `soc/` and `ha/` on 2026-04-14.
Treat as a draft that needs its own design session before being wired.

## What to do when unparking

1. Decide the routing target: a dedicated Telegram chat, a group, or a
   separate bot. Update `openclaw.json → bindings[]`.
2. Refresh `system.md` (this file's sibling) to the current op style
   (soc/ha use Telegram-friendly formatting, confirmation rules, etc.).
3. Build a workspace: `workspace-trading/{SOUL,IDENTITY,TOOLS,AGENTS,USER}.md`
   — mirror the structure used in `workspace/` and `workspace-ha-agent/`.
   The current `workspace-trading/` on the host is stale (2026-03-17) and
   should be regenerated, not restored.
4. Add per-agent `model:` override if the trading workload justifies a
   costlier model than Haiku.
5. Restart the gateway: `systemctl --user restart openclaw-gateway.service`.

## Do NOT

- Do not delete this directory — the ID would vanish from `openclaw.json`.
- Do not remove the `trading` entry from `agents.list` in
  `conf/openclaw.json.example` when sanitising — keep it as parked.
