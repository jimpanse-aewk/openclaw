# openclaw — operator pickup card

One-page card to get back into the bot quickly. The full 792-line operator
handover lives in `docs/OPENCLAW_HANDOVER.md` (mirrored from the host's
`~/.openclaw/OPENCLAW_HANDOVER.md`). Start there when you need schema,
routing, or CLI reference.

## Where it runs

- Host: `openclaw` (`192.168.86.8`, user `clown`, ssh alias `claw`)
- Entry: `/home/clown/.npm-global/bin/openclaw` → `…/openclaw/openclaw.mjs`
- Unit: `~/.config/systemd/user/openclaw-gateway.service`
- Config: `/home/clown/.openclaw/openclaw.json`
- Secrets: `/home/clown/.config/openclaw/secrets.env`
  (mechanism: `EnvironmentFile=%h/.config/openclaw/secrets.env` drop-in)
- Version: `2026.4.2` (`d74a122`)

## Health check (30 seconds)

```bash
# From rawmeo / any box with the claw ssh alias
ssh claw 'systemctl --user is-active openclaw-gateway.service && \
          /home/clown/.npm-global/bin/openclaw health'

# From openclaw itself
systemctl --user is-active openclaw-gateway.service
openclaw health
```

Expected: `active` + `Telegram: ok (@Clown_ha_bot)` + `WhatsApp: linked` +
`Agents: main (default), trading, ha-agent`.

## If the bot isn't answering

1. **Check billing first** — `journalctl --user -u openclaw-gateway -n 30 \
   | grep -i 'credit balance'`. If present, top up Anthropic credits. No
   amount of restarting fixes an empty wallet.
2. **Service check** — `systemctl --user status openclaw-gateway --no-pager`.
3. **Route check** — `openclaw agents bindings` (expect
   `ha-agent <- telegram peer=group:-1003941975878` + `main <- telegram`).
4. **Log tail** — `journalctl --user -u openclaw-gateway -f` — watch a live
   message land.
5. See `docs/troubleshooting.md` for longer recipes (session wipe, WhatsApp
   stale-socket cycle, group-migration chat_id rename).

## Safe restart

```bash
ssh claw 'systemctl --user restart openclaw-gateway.service && \
          sleep 3 && \
          /home/clown/.npm-global/bin/openclaw health'
```

**Never** `kill -9` the openclaw processes — systemd will respawn them, but
in-memory session state is lost. Always use `systemctl --user restart`.

## Pending runtime change

Haiku → Sonnet model switch on `main` and `ha-agent` is pending. Not a
repo-level edit — it's a live-host change (`openclaw config set
agents.list[0].model anthropic/claude-sonnet-4-6` then restart, and repeat
for `ha-agent`). Defer to a dedicated session; add a decision record at
`docs/openclaw-model-switch.md` when it happens.

## What's in this repo vs what stays on the host

| Stays on the host only |
|---|
| `~/.openclaw/sessions/` — live conversation state |
| `~/.openclaw/memory/YYYY-MM-DD.md` — daily notes |
| `~/.openclaw/credentials/` — WhatsApp pairing data |
| `~/.openclaw/openclaw.json.bak*` — 8 historic backups |
| `/home/clown/.config/openclaw/secrets.env` — real secrets |
| `/tmp/openclaw/openclaw-YYYY-MM-DD.log` — json logs |

| In this repo |
|---|
| Sanitised `conf/*.example` templates |
| `systemd/` unit file (current) |
| `agents/*/system.md` snapshots |
| `workspace/` and `workspace-ha-agent/` context files |
| `ha-agent-context/` — the loaded-at-session-start HA docs |
| `scripts/` — on-host scripts (soc_sync, oc_scan, oc_block, …) |
| `docs/OPENCLAW_HANDOVER.md` — the operator handover mirror |

## Open questions (carried from onboarding 2026-04-18)

1. Second local user `openclaw` (uid 1001) — purpose unknown, noted for the
   operator to confirm. Likely legacy service-user pattern; confirm or remove.
2. WhatsApp integration is live and intentional, but the stale-socket restart
   cycle (~35 min) is a bug masquerading as a feature. Fix vs ignore TBD.
3. `gateway.auth.token` inside `openclaw.json` — local-loopback token.
   Low-risk if the machine is trusted, but it's still a credential; decide
   whether the committed `.example` should include a placeholder value or
   a different sanitisation story.

## Full doc index

- `docs/OPENCLAW_HANDOVER.md` — the 792-line canonical operator handover
- `docs/integrations.md` — HA, SOC, Telegram, WhatsApp wiring
- `docs/troubleshooting.md` — billing errors, session wipe, restart cycle
- `docs/archive-stale-2026-03-18/` — preserved stale snapshot from the
  project's initial `start/` folder. Stale, for reference only.
