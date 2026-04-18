# Troubleshooting

Live-failure recipes for OpenClaw. For schema/routing/CLI reference go to
`OPENCLAW_HANDOVER.md` instead — this file is symptom → fix.

## Bot process is up but nothing answers

**Most likely: Anthropic API credit balance exhausted.** Observed all day
2026-04-18. Channels stay connected, every agent turn returns
`billing — credit balance too low`. No restart fixes this.

```bash
ssh claw 'journalctl --user -u openclaw-gateway -n 20 --no-pager \
          | grep -i "credit balance"'
```

If that pattern shows up, top up the Anthropic account. No other action is
useful until credits are back.

## Bot completely silent (no process, not just unresponsive)

```bash
ssh claw 'systemctl --user status openclaw-gateway --no-pager' 
# Expected: active (running). PID 1143 at time of onboarding.

ssh claw 'systemctl --user restart openclaw-gateway.service && \
          sleep 3 && /home/clown/.npm-global/bin/openclaw health'
```

If `openclaw health` reports `Telegram: ok` + `WhatsApp: linked` + three
agents — service layer is healthy. The "not answering" problem is upstream
(API credits, network).

## Telegram routing wrong (right message, wrong agent)

```bash
ssh claw '/home/clown/.npm-global/bin/openclaw agents bindings'
```

Expected:
```
- ha-agent <- telegram peer=group:-1003941975878
- main    <- telegram
```

If `ha-agent` is missing or the peer id is different, the group was
migrated and `openclaw.json` wasn't updated. See `OPENCLAW_HANDOVER.md §4.2`
for the chat_id rename procedure.

## Group stopped routing to ha-agent after admin promotion

Telegram auto-promotes basic groups to supergroups when a bot becomes
admin, **changing the chat_id**. OpenClaw logs the migration but does NOT
rename `openclaw.json` keys. Look for:

```bash
ssh claw 'journalctl --user -u openclaw-gateway | grep -i "Group migrated"'
```

If you see `Group migrated: "<title>" <old_id> → <new_id>`, apply the
manual rename in `OPENCLAW_HANDOVER.md §4.2` + `systemctl --user restart
openclaw-gateway.service`.

## Agent responds with stale / hallucinated data

Session memory has accumulated confusion. Wipe the session and restart:

```bash
# For the SOC agent (main):
ssh claw 'echo "{}" > /home/clown/.openclaw/agents/main/sessions/sessions.json && \
          systemctl --user restart openclaw-gateway.service && \
          sleep 3 && /home/clown/.npm-global/bin/openclaw health'

# For ha-agent:
ssh claw 'echo "{}" > /home/clown/.openclaw/agents/ha-agent/sessions/sessions.json && \
          systemctl --user restart openclaw-gateway.service'
```

Prompt edits to `agents/<id>/system.md` or workspace files do NOT require
a restart — they're read per-turn. Only `bindings[]` edits and this
session-wipe flow need a restart.

## WhatsApp restart cycle every ~35 min

**Known issue — not a show-stopper.** The journal shows a repeating loop:

```
[health-monitor] [whatsapp:default] health-monitor: restarting (reason: stale-socket)
[whatsapp] [default] starting provider (+66656899706)
[whatsapp] Listening for personal WhatsApp inbound messages.
```

The restart is the workaround — WhatsApp socket goes stale, the health
monitor restarts the provider, listener resumes. Messages during the
~1-second window can be missed. No fix at this OpenClaw version (2026.4.2);
carry this as a known behavior until an upstream fix exists.

## `openclaw.json` rejected with zod / validation error

Gateway enters restart loop. Check:

```bash
ssh claw 'journalctl --user -u openclaw-gateway -n 50 --no-pager \
          | grep -iE "invalid|zod|config"'
```

Common causes:
- missing `channel` key on a binding (silent drop → validation error)
- wrong `peer.kind` value (only `direct`, `group`, `channel`, `dm` allowed)
- trailing comma / malformed JSON

Fastest recovery: restore from the most recent `.bak`:

```bash
ssh claw 'ls -t /home/clown/.openclaw/openclaw.json.bak* | head -1'
# then:
ssh claw 'cp /home/clown/.openclaw/openclaw.json.bak.<YYYYMMDD>-<HHMMSS> \
             /home/clown/.openclaw/openclaw.json && \
          /home/clown/.npm-global/bin/openclaw config validate && \
          systemctl --user restart openclaw-gateway.service'
```

## Telegram probe warns about privacy mode (cosmetic)

```
telegram default: Config allows unmentioned group messages (requireMention=false).
Telegram Bot API privacy mode will block most group messages unless disabled.
```

Bypassed by admin-in-group promotion. The probe doesn't check admin status,
so this warning stays even when routing works. Leave it; see
`OPENCLAW_HANDOVER.md §4.3`.

## Telegram API direct probing (skipping the gateway)

When openclaw is running, prefer read-only API calls — avoid `getUpdates`
as it races with openclaw's long-poll:

```bash
ssh claw 'set -a; source /home/clown/.config/openclaw/secrets.env; set +a; \
          curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" \
          | python3 -m json.tool'
```

Same pattern for `getChat?chat_id=<id>` and `getChatAdministrators?chat_id=<id>`.

## Model switch — Haiku → Sonnet (pending)

Not an active troubleshooting recipe. Noted here so it's easy to find when
you come back to it. The switch is a live-host config change:

```bash
# When ready, a dedicated session should:
# 1. Back up openclaw.json
# 2. openclaw config set agents.list[0].model anthropic/claude-sonnet-4-6
# 3. openclaw config set agents.list[2].model anthropic/claude-sonnet-4-6
#    (index 0 = main, index 2 = ha-agent; verify with `openclaw agents list`)
# 4. systemctl --user restart openclaw-gateway.service
# 5. Test both agents with a real message; watch for cost jump in journal
```

Context: agents' `SOUL.md` / `MEMORY.md` still describe the bot as "Haiku
(cost-aware)". If the switch lands, update those lines alongside the config
change. No decision record committed yet — write `docs/openclaw-model-switch.md`
as part of that session.

## First-look commands (copy-paste for cold pickup)

```bash
ssh claw 'systemctl --user status openclaw-gateway --no-pager && \
          /home/clown/.npm-global/bin/openclaw health && \
          /home/clown/.npm-global/bin/openclaw agents bindings && \
          journalctl --user -u openclaw-gateway -n 15 --no-pager'
```

That one block tells you: service state, channel health, routing table, and
the last 15 log lines.
