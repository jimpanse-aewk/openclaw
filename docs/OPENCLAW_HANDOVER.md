# OPENCLAW_HANDOVER.md
Last updated: 2026-04-14 (v2 — post group-routing fix)
OpenClaw version: **2026.4.2** (`build: d74a122`, from `dist/package.json`)
Operator: jimpanse / rawmeo / pierr
Host: openclaw.86.8 (`clown` user)

---

## WHAT THIS FILE IS FOR

Read this at the start of any session that touches OpenClaw agents, bindings, Telegram/WhatsApp channels, or the `clown`-user config. It is the single source of truth for:
- OpenClaw runtime layout, process management, config schema
- How routing actually works (source-verified, not guessed)
- The Telegram group-routing scheme we landed on 2026-04-14
- Inventory of registered/unregistered agents
- CLI commands that were verified to work in this session
- Change procedures + known sharp edges

**IMPORTANT**: v2 corrects a mistake in v1 which claimed peer-based routing was unsupported. Peer-based routing **IS** a first-class feature — see "BINDINGS" below.

---

## 1. OPENCLAW RUNTIME

| Property | Value |
|---|---|
| Install path | `/home/clown/.npm-global/lib/node_modules/openclaw/` |
| Entry binary | `openclaw.mjs` (symlinked to `/home/clown/.npm-global/bin/openclaw`) |
| Config file | `/home/clown/.openclaw/openclaw.json` |
| Secrets file (env) | `/home/clown/.config/openclaw/secrets.env` — contains `TELEGRAM_BOT_TOKEN`, `ANTHROPIC_API_KEY`, `HA_TOKEN`, `HA_URL`, `TELEGRAM_CHAT_ID` |
| systemd unit | `~/.config/systemd/user/openclaw-gateway.service` (user scope, not system) |
| systemd drop-in | `~/.config/systemd/user/openclaw-gateway.service.d/override.conf` (adds `EnvironmentFile=%h/.config/openclaw/secrets.env`) |
| Process management | **systemd --user** (auto-restart on failure; `Restart=always`) |
| Running processes | `openclaw` (parent) + `openclaw-gateway` (child, PID listening on gateway port) |
| Gateway port | `127.0.0.1:18789` (loopback only, token auth) |
| Browser control | `127.0.0.1:18791` (auth=token) |
| Canvas host | `http://127.0.0.1:18789/__openclaw__/canvas/` |
| Log file | `/tmp/openclaw/openclaw-YYYY-MM-DD.log` (JSON-per-line, INFO by default; DEBUG available) |
| Bot handle | `@Clown_ha_bot` (display name: `Clown_bot` — same account) |

### Restart / health commands

```bash
# Restart (from anywhere)
systemctl --user restart openclaw-gateway.service

# Status
systemctl --user status openclaw-gateway.service
systemctl --user is-active openclaw-gateway.service

# Live logs
journalctl --user -u openclaw-gateway.service -f

# Or raw JSON log file
tail -f /tmp/openclaw/openclaw-$(date +%F).log
```

**Do NOT** `kill -9` the openclaw processes — systemd will respawn them but in-memory session state is lost. Always use `systemctl --user restart`.

---

## 2. CONFIG FILE SCHEMA (`openclaw.json`)

Top-level keys we use:

| Key | Type | Purpose |
|---|---|---|
| `meta` | `{lastTouchedVersion, lastTouchedAt}` | Openclaw writes these on every config mutation |
| `agents.defaults` | `{model: {primary}, models: {...}}` | Default model applied to agents with no override |
| `agents.list[]` | `[{id, name?, model?, agentDir, workspace}]` | Registered agents (order doesn't matter) |
| `tools.profile` | `"coding"`, etc. | Tool profile preset |
| `bindings[]` | routing rules (see BINDINGS) | Channel/peer/account → agent routing |
| `messages` | `{ackReactionScope}` | Reaction ack behavior |
| `commands` | `{native, nativeSkills, restart, ownerDisplay}` | Native slash-command gating |
| `session` | `{dmScope, store?, identityLinks?}` | Session keying strategy |
| `channels` | `{telegram, whatsapp, discord, ...}` | Per-channel configs |
| `gateway` | `{port, mode, bind, auth, tailscale}` | Gateway server config |
| `plugins.entries.<name>.enabled` | bool | Plugin toggles |

### Full authoritative type source (on-host)
```
/home/clown/.npm-global/lib/node_modules/openclaw/dist/plugin-sdk/src/config/
├── types.base.js        # DmPolicy, GroupPolicy, ReplyToMode, …
├── types.telegram.d.ts  # TelegramAccountConfig / TelegramGroupConfig / TelegramTopicConfig / …
├── types.messages.d.ts
├── types.tools.d.ts
└── types.channels.js    # channel monitors + health
```
Use `cat` on these when you need the absolute truth about any config shape.

### Zod schemas (runtime validation)
```
dist/io-DhtVmzAJ.js                  # BindingMatchSchema, RouteBindingSchema, AcpBindingSchema, BindingsSchema
dist/zod-schema.providers-core-BJorTsd7.js
dist/zod-schema.providers-whatsapp-piwHYP0l.js
dist/channel-config-schema-BAlK8Vas.js
```
`io-DhtVmzAJ.js:16980-17078` is the binding schema block — the definitive answer to "what match keys are allowed".

---

## 3. BINDINGS — HOW ROUTING ACTUALLY WORKS (CORRECTED v2)

**Authoritative sources** (all confirmed this session):
- Schema: `dist/io-DhtVmzAJ.js:17001-17020` (`BindingMatchSchema` + `RouteBindingSchema`)
- Lookup: `dist/bindings-CxBQdMiO.js` (`buildChannelAccountBindings`, `listBindings`)
- Resolution waterfall: `dist/resolve-route-DID7K3Jm.js:411-467` (`resolveAgentRoute` tiers)
- Peer-key indexing: `dist/format-DqAjfaGj.js:396` (`buildTelegramGroupPeerId`)
- Telegram route override: `dist/bot-message-context-LcO78rYq.js:377-470` (`resolveTelegramConversationRoute`)

### Supported `match` keys (from the zod schema — definitive)

```js
BindingMatchSchema = z.object({
  channel: z.string(),                // REQUIRED
  accountId: z.string().optional(),    // optional, default "" → DEFAULT_ACCOUNT_ID; "*" = any
  peer: z.object({
    kind: z.union([z.literal("direct"), z.literal("group"),
                   z.literal("channel"), z.literal("dm")]),
    id: z.string()
  }).strict().optional(),             // ✅ FIRST-CLASS (v1 got this wrong)
  guildId: z.string().optional(),      // Discord
  teamId: z.string().optional(),       // Slack
  roles: z.array(z.string()).optional() // Discord role IDs
}).strict();
```

### Binding types

| `type` | Schema | Notes |
|---|---|---|
| `"route"` (default) | `RouteBindingSchema` | Standard "send inbound → agent" routing. Peer is free-form. |
| `"acp"` | `AcpBindingSchema` | Agent Control Protocol (persistent/oneshot). **Requires** `match.peer.id` with a specific format per channel (telegram: `/^-\d+:topic:\d+$/`). Only used for Slack ACP spawns today. |

### Resolution waterfall (tiers, highest → lowest)

From `resolve-route-DID7K3Jm.js:411-467`:

1. `binding.peer` — exact peer match `(kind, id)`
2. `binding.peer.parent` — parent peer (forum topic → group inheritance)
3. `binding.peer.wildcard` — peer with `id: "*"` (kind-only wildcard)
4. `binding.guild+roles` — Discord guild + role gating
5. `binding.guild` — Discord guild alone
6. `binding.team` — Slack team
7. `binding.account` — accountPattern set, peer unset
8. `binding.channel` — channel-only catch-all (`accountPattern === "*"` OR default bucket)
9. `default` — `resolveDefaultAgentId(cfg)` fallback

**Peer-indexed bindings win over channel catch-alls regardless of array order** — they're in a different index bucket and checked first. Still, for readability, put specific bindings before catch-alls.

### Ordering quirk (read carefully)

`buildEvaluatedBindingsByChannel` (in `resolve-route-DID7K3Jm.js`) assigns `order` by array position and splits bindings into `byAccount` (specific `accountId`) vs `byAnyAccount` (`"*"`). For a peerless binding with empty `accountId` (the common case), it goes into `byAccount.get(DEFAULT_ACCOUNT_ID)`. This **only** matches when `input.accountId === DEFAULT_ACCOUNT_ID` — which is true in single-account setups (our case), but would break if you add a second telegram account.

**Rule of thumb**: when in doubt, set `match.accountId: "*"` on catch-all bindings. The main `main <- telegram` binding currently omits it and works only because we're single-account.

### Telegram-specific peer ID format

`buildTelegramGroupPeerId` (`format-DqAjfaGj.js:396`):
```js
messageThreadId != null
  ? `${chatId}:topic:${messageThreadId}`  // forum topics
  : String(chatId)                         // regular groups / supergroups
```
- Regular group `-5233378726` → peer id `"-5233378726"`
- Supergroup `-1003941975878` → peer id `"-1003941975878"` (signed string; NO `:topic:` suffix unless it's a forum topic)
- Forum topic in supergroup → peer id `"-1003941975878:topic:42"`

### Current bindings (this session, verified working)

```json
"bindings": [
  {
    "type": "route",
    "agentId": "ha-agent",
    "comment": "Route telegram group -1003941975878 to ha-agent (peer-based, tier-1 match) (supergroup post-migration)",
    "match": {
      "channel": "telegram",
      "peer": { "kind": "group", "id": "-1003941975878" }
    }
  },
  { "type": "route", "agentId": "main", "match": { "channel": "telegram" } }
]
```

Verified via `openclaw agents bindings`:
```
- ha-agent <- telegram peer=group:-1003941975878
- main    <- telegram
```

---

## 4. TELEGRAM OPERATIONAL NOTES (learned 2026-04-14)

### 4.1 Privacy mode

Telegram bots have a **privacy mode** flag set via BotFather `/setprivacy`. When enabled (the default):
- `getMe` returns `"can_read_all_group_messages": false`
- Bot only receives: `@mentions` of its username, replies to its own messages, and `/slash` commands
- Plain text chatter is **filtered at Telegram's servers** before delivery — it never reaches openclaw

Two ways to bypass:
1. **BotFather** `/setprivacy` → select bot → `Disable`. Affects the bot globally.
2. **Promote the bot to admin** in the specific group/supergroup. Admins bypass privacy mode for that chat only. Scoped and reversible — preferred.

This session we used option 2 for the `Administrators` group.

### 4.2 Basic-group → supergroup auto-migration (CRITICAL)

When you promote a bot to admin in a **basic** Telegram group, **Telegram automatically upgrades that group to a supergroup** and **changes the chat_id**.

Example from this session:
```
-5233378726  →  -1003941975878
```
(Basic group IDs are small negatives. Supergroup IDs start with `-100` and are much larger.)

Openclaw detects this in `bot-C3BP06QT.js` and logs:
```
[telegram] Group migrated: "<title>" -5233378726 → -1003941975878
[telegram] Migrating group config from -5233378726 to -1003941975878
Config overwrite: /home/clown/.openclaw/openclaw.json (sha256 ... -> ...)
[telegram] Group config migrated and saved successfully
```

**But** — observed this session — openclaw's auto-migration only updates `meta.lastTouchedAt` in the file. It **does not actually rename** `channels.telegram.groups[<old>]` → `groups[<new>]`, and it **does not touch** `bindings[].match.peer.id`. You have to do both by hand:

```python
# channels.telegram.groups key rename
g = cfg["channels"]["telegram"]["groups"]
g[NEW_ID] = g.pop(OLD_ID)

# every binding pointing to the old peer id
for b in cfg["bindings"]:
    peer = b.get("match", {}).get("peer")
    if peer and peer.get("id") == OLD_ID:
        peer["id"] = NEW_ID
```
Then restart the gateway.

**Watch for this every time** you promote a bot to admin in a basic group. If your binding suddenly stops firing, check the logs for a `Group migrated` line.

### 4.3 Privacy mode vs admin bypass — recap

| Setup | Bot sees plain text in groups? |
|---|---|
| Privacy ON + not admin | ❌ Only @mentions / replies / `/commands` |
| Privacy ON + **admin** | ✅ All messages (admin bypass) |
| Privacy OFF + not admin | ✅ All messages |
| Privacy OFF + admin | ✅ All messages |

`openclaw channels status --probe` will warn `Telegram Bot API privacy mode will block most group messages unless disabled` when `requireMention=false` is set but `can_read_all_group_messages=false` on `getMe`. The warning is real — but admin-in-group also satisfies it, even though the probe doesn't know the bot's admin status.

### 4.4 Group policy + allowFrom interaction

`channels.telegram.groupPolicy` (global default):
- `"allowlist"` — only senders in `groupAllowFrom`/`allowFrom` can reach the bot; empty list = silent drop (causes `skipping group message` with reason `not-allowed`)
- `"open"` — any sender can reach the bot; `requireMention` defaults to `false`
- `"disabled"` — all group messages blocked

Per-group override via `channels.telegram.groups[<chatId>]`:
```json
{
  "groupPolicy": "open",
  "requireMention": false,
  "allowFrom": [...],     // optional numeric user IDs
  "enabled": true,
  "systemPrompt": "...",  // per-group system prompt snippet
  "topics": {             // forum topic config (has its own agentId per topic!)
    "<threadId>": { "agentId": "<id>", "requireMention": false, ... }
  }
}
```
**Important**: `groups[<id>].agentId` **does NOT exist** per the type schema — only `topics[<threadId>].agentId` does, and only applies to forum topics. For non-forum groups, use peer-based `bindings[]`.

### 4.5 Bot identity names

`getMe` on our token returns:
```json
{
  "id": 8792388733,
  "is_bot": true,
  "first_name": "Clown_bot",    // display name — what users see in Telegram UI
  "username": "Clown_ha_bot",   // @handle — used for @mentions, deep links
  "can_join_groups": true,
  "can_read_all_group_messages": false,
  "supports_inline_queries": false
}
```
So `Clown_bot` (display) and `@Clown_ha_bot` (handle) are the **same account**. The `_ha_` in the handle is historical and doesn't mean "HA agent" — this bot fronts both SOC and HA agents.

---

## 5. REGISTERED AGENTS (from `openclaw.json → agents.list`)

| id | agentDir | workspace | model | purpose | binding |
|---|---|---|---|---|---|
| `main` | `/home/clown/.openclaw/agents/main/agent` | `/home/clown/.openclaw/workspace` | `anthropic/claude-haiku-4-5` | **SOC analyst** — Suricata/ELK/NetAlertX/Pi-hole alert triage; Clown "bro-style" persona | telegram catch-all |
| `trading` | `/home/clown/.openclaw/agents/trading/agent` | `/home/clown/.openclaw/workspace-trading` | (default) | Markets / portfolio / catalysts | **none (unreachable)** |
| `ha-agent` | `/home/clown/.openclaw/agents/ha-agent/agent` | `/home/clown/.openclaw/workspace-ha-agent` | `anthropic/claude-haiku-4-5` | **Home Assistant operator** — entity states, automations, service calls via `socha` | telegram peer `group:-1003941975878` (the `Administrators` supergroup) |

### Unregistered agent directories (exist but not in `agents.list`)

| Dir | Contents | Recommendation |
|---|---|---|
| `/home/clown/.openclaw/agents/coding` | `agent/system.md` | Drop or register. Superseded by IDE-side Claude Code |
| `/home/clown/.openclaw/agents/mind` | `agent/system.md` | Drop or register. Unclear scope |
| `/home/clown/.openclaw/agents/ops_manager` | `agent/system.md` | **Drop** — superseded by `main` |
| `/home/clown/.openclaw/agents/soc_analyst` | `agent/system.md` (56 lines, older SOC prompt) | **Drop** — `main` is the live SOC agent |
| `/home/clown/.openclaw/agents/ha_ops` | `agent/system.md` (60 lines, older HA prompt) | **Drop** — superseded by `ha-agent` (richer, live-data-populated) |
| `/home/clown/.openclaw/agents_retired/` | archive | Leave alone |

None are referenced by the runtime.

---

## 6. AGENT FILES INVENTORY

### `main` (SOC) — `/home/clown/.openclaw/workspace/`
| File | Role | Notes |
|---|---|---|
| `SOUL.md` | Persona | Clown, short/structured/direct, bro-style |
| `IDENTITY.md` | Role | SOC analyst for `192.168.86.0/24`, network-device-only view of HA |
| `TOOLS.md` | Command map | SOC commands, **HA section moved to `DELEGATED — HA AGENT`** |
| `AGENTS.md` | Session startup + sibling-agent registry (includes `ha-agent` entry) |
| `SOC_BASELINE.md`, `MEMORY.md`, `memory/YYYY-MM-DD.md` | Optional context |
| `/home/clown/.openclaw/agents/main/agent/system.md` | Top-level system prompt (OpenClaw entry) |

### `ha-agent` (HA operator) — `/home/clown/ha-agent/` (canonical)
| File | Role |
|---|---|
| `IDENTITY.md` | Persona + hard boundaries (no SOC access) |
| `CLAUDE.md` | AI operating file, document model, quick commands, two-path access rule |
| `HA_SNAPSHOT.md` | Architecture truth: access methods, `socha` commands, HA_VERSION 2026.4.2, 88 lights / 12 scenes / 6 switches / 6 automation domains, 13 healthy + 12 unavailable automations, integration list (Hue / Tapo / WiZ / Yeelink / Aqara / Sonos) |
| `HA_OPS.md` | Runbook: first checks, automation management, package editing via `openclaw_ha` direct key, service calls with confirmation rules, troubleshooting, escalation to SOC |
| `HA_QUICK.md` | Session-start card with 5 open items |

### `ha-agent` runtime wiring — `/home/clown/.openclaw/workspace-ha-agent/`
| File | Role |
|---|---|
| `SOUL.md` | HA-scoped persona |
| `IDENTITY.md` | Mirror of canonical |
| `TOOLS.md` | HA command map + known entities + escalation rules |
| `AGENTS.md` | Session-startup framework pointing back to `/home/clown/ha-agent/HA_*.md` |
| `/home/clown/.openclaw/agents/ha-agent/agent/system.md` | Top-level system prompt (copy of `IDENTITY.md`) |

### `trading` — `/home/clown/.openclaw/agents/trading/agent/system.md`
Standalone system prompt only; no workspace context files beyond what's in `/home/clown/.openclaw/workspace-trading/`.

---

## 7. SOC SOURCE DOCS (Windows-side canonical, NOT on openclaw)

These are the operator's editable source of truth for the SOC architecture. **Edit these**, not the openclaw-side copies.

Path: `C:\Users\pierr\project_test\` (on rawmeo-desktop WSL: `/mnt/c/Users/pierr/project_test/`)

| File | Role |
|---|---|
| `CLAUDE.md` | AI operating file v3 for SOC — `HA AGENT BOUNDARY` block delegates HA ops to `ha-agent` |
| `NET_SNAPSHOT.md` | Static facts — topology, SSH key maps (per-host), all NetAlertX devices, Tailscale nodes. **HA history annotated DELEGATED** |
| `SOC_OPS.md` | Runbook — alert pipeline, tuning, NetAlertX procedures, backup, troubleshooting, open items. Credentials row notes `HA_TOKEN` is `ha-agent`-owned |
| `QUICK.md` | Session-start card with `HA AGENT BOUNDARY` footer |
| `ARCH_DIARY.md` | Historical incidents (not modified by HA split) |
| `OPENCLAW_HANDOVER.md` | **This file** (mirror of `/home/clown/.openclaw/OPENCLAW_HANDOVER.md`) |

---

## 8. CHANNELS + CREDENTIALS

### Telegram (`channels.telegram`)
Current config (post-fix):
```json
{
  "enabled": true,
  "dmPolicy": "pairing",
  "groupPolicy": "allowlist",
  "streaming": "partial",
  "allowFrom": [],
  "groups": {
    "-1003941975878": { "groupPolicy": "open", "requireMention": false }
  }
}
```
Token source: `TELEGRAM_BOT_TOKEN` env var (loaded via systemd drop-in → `/home/clown/.config/openclaw/secrets.env`)

### WhatsApp (`channels.whatsapp`)
```json
{
  "enabled": true,
  "dmPolicy": "allowlist",
  "selfChatMode": true,
  "allowFrom": ["+66656899706"],
  "groupPolicy": "allowlist",
  "debounceMs": 0,
  "mediaMaxMb": 50
}
```
Session store: `/home/clown/.openclaw/credentials/whatsapp/default/creds.json` (+ pre-keys). Auto-backup on corruption (saw `restored corrupted WhatsApp creds.json from backup` this session — benign).

### Routing summary (post-fix)

| Channel / chat | Target agent | Binding tier |
|---|---|---|
| Telegram supergroup `Administrators` (`-1003941975878`) | `ha-agent` | 1 (peer) |
| All other telegram (DMs, other groups) | `main` (SOC) | 8 (channel catch-all) |
| WhatsApp `+66656899706` | `main` (SOC) | default |

---

## 9. CLI COMMAND REFERENCE (verified working 2026-04-14)

All commands assume you're logged in as `clown` on openclaw (or SSH'd in). Add a shebang-compatible PATH entry if the global bin isn't in PATH: `/home/clown/.npm-global/bin/openclaw`.

### Config
```bash
openclaw config validate                      # zod validation of openclaw.json
openclaw config get <dot.path>                # read a value
openclaw config set <dot.path> <value>        # write a value
openclaw config unset <dot.path>
openclaw config file                          # print config file path
```

### Agents
```bash
openclaw agents list                          # enumerate agents.list
openclaw agents add --id <id> --agent-dir <path> --workspace <path>
openclaw agents delete --id <id>              # prunes workspace + state too
openclaw agents bind --agent <id> --channel <channel> [--peer-kind <k> --peer-id <id>] [--account-id <id>]
openclaw agents unbind --agent <id> --channel <channel> [--peer-id <id>]
openclaw agents bindings                      # print current routing table
openclaw agents set-identity --id <id> ...
```
> `openclaw agents bind` is the *preferred* way to add a binding — it respects the schema automatically. We hand-edited `openclaw.json` this session because we wanted fine control over `comment` and ordering.

### Channels
```bash
openclaw channels list                         # accounts + auth profiles
openclaw channels status                       # cached summary
openclaw channels status --probe               # live probe (token validation, getMe, warnings)
openclaw channels status --deep                # include local gateway health
openclaw channels logs                         # tail recent channel log lines
openclaw channels login --channel whatsapp     # pair whatsapp
openclaw channels add --channel telegram --token <token>
openclaw channels remove --channel <ch> [--account <id>]
openclaw channels resolve <username>           # @username → numeric id
openclaw channels capabilities                 # provider capability matrix
```

### Probe warnings worth knowing
`openclaw channels status --probe` flagged on this session:
```
- telegram default: Config allows unmentioned group messages (requireMention=false).
  Telegram Bot API privacy mode will block most group messages unless disabled.
  (In BotFather run /setprivacy → Disable for this bot (then restart the gateway).)
```
As discussed in §4.3, admin-in-group bypass is an equivalent fix and the probe doesn't check for it.

### Doctor / audit
```bash
openclaw doctor                                # interactive fix-suggestions
openclaw audit                                 # security audit (dm/group policies, tool exposure)
```

### Other useful
```bash
openclaw agent <agentId> --message "..."      # run one agent turn via gateway (non-interactive)
openclaw devices                               # pairing / token management
openclaw approvals                             # exec-approval queue
openclaw cron                                  # scheduler
openclaw dashboard                             # open Control UI (browser)
openclaw backup                                # state backup/verify
```

---

## 10. HOW TO MAKE CHANGES

### Add/modify a binding (manual approach, what we used)

```bash
# 1. Back up
ssh claw 'cp /home/clown/.openclaw/openclaw.json /home/clown/.openclaw/openclaw.json.bak.$(date +%Y%m%d_%H%M%S)'

# 2. Edit /home/clown/.openclaw/openclaw.json directly. Put specific bindings BEFORE the catch-all for readability (order within peer-index bucket doesn't affect correctness since they're tier-1).

# 3. Validate
ssh claw '/home/clown/.npm-global/bin/openclaw config validate'

# 4. Verify CLI sees it
ssh claw '/home/clown/.npm-global/bin/openclaw agents bindings'

# 5. Restart gateway
ssh claw 'systemctl --user restart openclaw-gateway.service && systemctl --user is-active openclaw-gateway.service'

# 6. Test with a real message in the target chat and tail logs
ssh claw 'tail -f /tmp/openclaw/openclaw-$(date +%F).log'
```

### Add/modify a binding (CLI approach, recommended for simple cases)

```bash
openclaw agents bind --agent ha-agent --channel telegram \
                     --peer-kind group --peer-id -1003941975878
```

### Register a new agent

```bash
# 1. Create directories
mkdir -p /home/clown/.openclaw/agents/<id>/agent
mkdir -p /home/clown/.openclaw/workspace-<id>

# 2. Write system prompt
vim /home/clown/.openclaw/agents/<id>/agent/system.md

# 3. (Optional) Create workspace context files
vim /home/clown/.openclaw/workspace-<id>/{SOUL,IDENTITY,TOOLS,AGENTS}.md

# 4. Add to openclaw.json agents.list
vim /home/clown/.openclaw/openclaw.json
# -> insert {"id": "<id>", "name": "<id>", "model": "anthropic/claude-haiku-4-5",
#           "agentDir": "/home/clown/.openclaw/agents/<id>/agent",
#           "workspace": "/home/clown/.openclaw/workspace-<id>"}

# 5. Add binding if non-default routing needed (see above)

# 6. Validate + restart
openclaw config validate
systemctl --user restart openclaw-gateway.service
```

### Edit an agent's system prompt (no restart needed)

```bash
vim /home/clown/.openclaw/agents/<id>/agent/system.md
# Changes take effect on the next message — the system prompt is read per-turn, not per-boot.
```

### Edit workspace context files (no restart needed)

```bash
vim /home/clown/.openclaw/workspace[-<id>]/SOUL.md
# Loaded per-session by the agent's session-startup flow in AGENTS.md
```

### Disable Telegram privacy mode (BotFather path)

1. Telegram → DM `@BotFather`
2. `/setprivacy`
3. Select `@Clown_ha_bot`
4. Choose `Disable`
5. `systemctl --user restart openclaw-gateway.service` (forces bot to refresh `getMe`)

### Promote a bot to admin in a group (preferred, per-group)

Inside Telegram, open the group → group info → members → long-press the bot → Promote. **Warning**: if it's a basic group (chat_id like `-5233378726`), Telegram will immediately convert it to a supergroup and **change the chat_id**. See §4.2 and apply the peer-id rename + restart flow.

### Add a Telegram group to the route allowlist

```bash
# Per-group override (minimum viable: allow messages from any sender, no @mention required)
openclaw config set "channels.telegram.groups.<chatId>.groupPolicy" open
openclaw config set "channels.telegram.groups.<chatId>.requireMention" false
```
Or edit `openclaw.json` directly and add the key under `channels.telegram.groups`.

---

## 11. LOGS & DEBUGGING

### Log file structure
`/tmp/openclaw/openclaw-YYYY-MM-DD.log` — one JSON object per line. Fields:
- `time`: ISO timestamp with timezone
- `_meta.logLevelName`: `DEBUG|INFO|WARN|ERROR|FATAL`
- `_meta.name`: subsystem identifier (e.g. `{"subsystem":"gateway/channels/telegram"}`)
- `"0"`, `"1"`, `"2"`, `"3"`: positional log arguments

### Useful filters
```bash
# Every non-heartbeat event today
tail -f /tmp/openclaw/openclaw-$(date +%F).log | \
  python3 -c "
import json,sys
for line in sys.stdin:
    try: d=json.loads(line)
    except: continue
    msg=json.dumps(d)
    if 'web-heartbeat' in msg or 'health-monitor' in msg: continue
    t=d.get('time','')[:19]
    lvl=d.get('_meta',{}).get('logLevelName','')
    parts=[str(d.get(k)) for k in ('0','1','2','3') if d.get(k) is not None]
    print(t, lvl, ' | '.join(parts)[:260])
"

# Telegram only
journalctl --user -u openclaw-gateway.service -f | grep --line-buffered -iE 'telegram|binding|routing|skip'
```

### Enable DEBUG log level (verbose, includes inbound message content)
Openclaw 2026.4.2 reads `OPENCLAW_LOG_LEVEL` env var. Either:
```bash
# systemd drop-in
echo '[Service]
Environment=OPENCLAW_LOG_LEVEL=debug' >> ~/.config/systemd/user/openclaw-gateway.service.d/override.conf
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service
```
Or add `--log-level debug` in the unit file. **Revert after debugging** — debug logs are noisy and leak message content.

### Telegram Bot API direct probing (bypasses openclaw)
```bash
set -a; source /home/clown/.config/openclaw/secrets.env; set +a
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" | python3 -m json.tool
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChat?chat_id=<id>" | python3 -m json.tool
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChatAdministrators?chat_id=<id>" | python3 -m json.tool
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChatMemberCount?chat_id=<id>" | python3 -m json.tool
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=-5" | python3 -m json.tool
```
⚠️ **Calling `getUpdates` yourself can race with openclaw's long-poll.** If openclaw is running, prefer `getChat`/`getChatAdministrators` which are read-only. Avoid `getUpdates` except for emergency diagnostics, and don't commit an offset (no positive `offset` parameter) so openclaw still gets the update.

---

## 12. PIPELINE: SOC DATA FLOW (context for `main` agent)

### `soc_sync.sh` (cron `*/5 * * * *` in clown's crontab)
```bash
# Pulls latest_soc_report.json from ELK
ssh -i /home/clown/.ssh/oced25519 jimpanse@192.168.86.5 \
    "cat /home/jimpanse/scripts/reports/latest_soc_report.json" \
    > /home/clown/latest_soc_report.json

# Python pre-digest → /home/clown/soc_digest.txt (200-token summary)
```
Output file `/home/clown/soc_digest.txt` is what the `main` agent reads on `status soc`. Nothing in this script touches HA.

### Full pipeline
```
Suricata (.86.4) ── eve.json ── Filebeat ── Elasticsearch (.86.5:9200) ── Kibana
                                                   │
                                                   ├── soc_report.py (cron */15m on ELK)
                                                   │       └── latest_soc_report.json ── soc_sync.sh (cron */5m on openclaw)
                                                   │                                               └── soc_digest.txt → @Clown_ha_bot (main) → operator
                                                   │
                                                   └── Kibana dashboards (manual)

NetAlertX ARPSCAN (*/5m inside container, .86.11) ── /app/db/app.db ── new_device_alert.py (ELK) ── @Clown_ha_bot (main)
```

### ha-agent data flow (new 2026-04-14)
```
Operator (Telegram group Administrators) ── @Clown_ha_bot
                                                │
                                                └── openclaw bindings tier-1 peer match
                                                         │
                                                         └── ha-agent (Haiku)
                                                                  │
                                                                  ├── socha on ELK (HA API / token)
                                                                  │         └── HA REST @ 192.168.86.15:8123
                                                                  │
                                                                  └── direct SSH openclaw → HA (key: ~/.ssh/openclaw_ha)
                                                                            └── /config/packages/*.yaml shell edits
```

---

## 13. OPEN ITEMS (handover)

1. **Clean up unregistered agent dirs** — drop `soc_analyst`, `ops_manager`, `ha_ops` (confirmed duplicates).
2. **Workspace archive** — `workspace-boss`, `workspace-mind`, `workspace-coding`, `workspace-soc` are unreferenced. Candidates for archive after a few more stable sessions.
3. **12 unavailable HA automations** — investigate via `socha logbook automation.<id> 24` and decide per-automation: fix integration, disable, or delete.
4. **Telegram privacy-mode probe false-positive** — `openclaw channels status --probe` still warns about privacy mode even though the bot is now an admin in the only group it serves. Cosmetic; consider upstream PR or ignore.
5. **Hot-reload scope** — openclaw supports hot reload for `channels.telegram.groups.*.{requireMention,groupPolicy}` but NOT for `bindings[]`. Any binding change still requires `systemctl --user restart openclaw-gateway.service`. Verified in logs:
   ```
   [reload] config change detected; evaluating reload (bindings, channels.telegram.groups.-5233378726.requireMention, channels.telegram.groups.-5233378726.groupPolicy)
   [reload] config hot reload applied (channels.telegram.groups.-5233378726.requireMention, channels.telegram.groups.-5233378726.groupPolicy)
   ```
   Note `bindings` is detected but NOT in the "applied" list.
6. **Auto-migration bug** — openclaw's basic→supergroup migrator logs "migrated and saved successfully" but only touches `meta.lastTouchedAt`; doesn't actually rename group keys or update bindings. File an issue upstream, or always apply the rename by hand (see §4.2).
7. **`main` catch-all uses `accountPattern = ""` not `"*"`** — works for single-account setups but would silently fail if a second telegram account is added. Harden by setting `"accountId": "*"` explicitly.
8. **Periodic backup of `openclaw.json`** — right now we rely on manual `.bak.<ts>` copies. Consider adding to `soc_backup.sh`.
9. **Registering `trading` binding** — agent exists, no way to reach it. Decide scope (peer/account/dedicated bot) and add.
10. **`/ha_*` command namespace is a convention only** — runtime does not enforce it. If the operator wants actual slash-command routing, either add client-side dispatcher in `main` or use `openclaw commands native` flags (not explored this session).

---

## 14. SESSION CHANGELOG

### 2026-04-14 (this session)
- **Part 1 — SOC agent hardening**: stripped HA responsibilities from `main` agent. Updated Windows SOC docs (`CLAUDE.md`, `NET_SNAPSHOT.md`, `SOC_OPS.md`, `QUICK.md`) with `HA AGENT BOUNDARY` blocks + delegation annotations. Updated OpenClaw-side `workspace/{IDENTITY,TOOLS,AGENTS}.md` to remove direct HA commands, move socha chains to `DELEGATED — HA AGENT` block.
- **Part 2 — HA agent bootstrap**: created `/home/clown/ha-agent/` with `IDENTITY.md`, `CLAUDE.md`, `HA_SNAPSHOT.md` (populated with live `socha` data: 88 lights, 25 automations, integration list), `HA_OPS.md`, `HA_QUICK.md`. Created OpenClaw runtime wiring at `/home/clown/.openclaw/agents/ha-agent/agent/system.md` + `workspace-ha-agent/`. Registered in `agents.list`. Added new openclaw→HA direct SSH key `~/.ssh/openclaw_ha` (landing in addon container `a0d7b954-ssh`) — two-path access: direct SSH for shell/YAML, `socha` via ELK for API.
- **Part 3 — OpenClaw recon + this handover v1**: extracted binding schema, routing waterfall, runtime layout from dist files. v1 incorrectly concluded peer routing wasn't supported.
- **Group routing correction**: re-read `io-DhtVmzAJ.js` + `resolve-route-DID7K3Jm.js` — confirmed `match.peer.{kind,id}` IS first-class. Added peer-based binding for group `-5233378726` → `ha-agent`. Set `groups[-5233378726].groupPolicy: "open"` + `requireMention: false` to admit messages.
- **First test failure**: no telegram inbound events in logs. Diagnosed via `getMe` → `can_read_all_group_messages: false`. Privacy mode filtering.
- **Fix**: operator promoted `@Clown_ha_bot` to admin in the `Administrators` group. Telegram auto-migrated the basic group to a supergroup, chat_id changed `-5233378726` → `-1003941975878`.
- **Openclaw detected but incompletely applied** the migration — only updated `meta.lastTouchedAt`, didn't rename `groups[]` key or update `bindings[].match.peer.id`.
- **Manual finish**: renamed both in place. Restarted gateway.
- **End-to-end verification**: operator sent message in the `Administrators` supergroup, ha-agent responded with its correct persona ("I'm ha-agent — Home Assistant operator for rawmeo ..."), proving peer-based route fired (tier-1) over the `main` catch-all. `openclaw agents bindings` confirmed:
  ```
  - ha-agent <- telegram peer=group:-1003941975878
  - main    <- telegram
  ```
- **This handover v2** written with corrections and the new learnings.

---

## 15. FACTS THAT ARE EASY TO GET WRONG (v2 updated)

- **Agent IDs with hyphens work.** `sanitizeAgentId` does not strip `-`. `ha-agent` is a legal id and is used throughout this setup.
- **Peer-based bindings are real.** `match.peer.{kind,id}` is defined in `BindingMatchSchema` (`io-DhtVmzAJ.js:17005-17014`) and peer matching is tier 1 in the routing waterfall. If it's not working, check: (a) you updated the chat_id after a supergroup migration, (b) group policy isn't dropping the message before routing, (c) the binding's `channel` key is set and `accountId` is either unset (default bucket) or `"*"` (any bucket).
- **`channel` is mandatory on every binding.** Missing/empty channel = silent drop by `resolveNormalizedBindingMatch`.
- **Order of `bindings[]` affects readability but not correctness.** Peer-indexed bindings are checked in tier 1 regardless of array order. Still, put specific bindings first for human readers.
- **Basic groups auto-promote to supergroups when you make a bot admin** — and the chat_id changes. Always check for `[telegram] Group migrated` in the logs after promotion.
- **Openclaw's auto-migration of renamed chats is incomplete.** It logs success but doesn't rename `channels.telegram.groups[]` keys or update `bindings[].match.peer.id`. Do these by hand.
- **Hot reload covers `channels.*` and some other fields but NOT `bindings[]`**. Every binding edit needs a systemd restart.
- **The `main` agent's dir is `/home/clown/.openclaw/agents/main/agent`** (not `/main`). The `agent/` subdir holds `system.md`.
- **The `main` agent's workspace** is `/home/clown/.openclaw/workspace` (no `-main` suffix). Only non-main agents use `-<id>` suffix.
- **`ha` CLI is NOT available** inside the HA add-on SSH container (`a0d7b954-ssh`) landing from `openclaw_ha` — for `ha core *` equivalents, use `socha call` via ELK which goes through the REST API with `HA_TOKEN`.
- **`socha` lives on ELK**, not openclaw. API queries require an openclaw → ELK SSH hop (`ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 '/home/jimpanse/soc-core/bin/socha <cmd>'`). Direct openclaw → HA SSH (`~/.ssh/openclaw_ha`) is for shell + YAML work only.
- **`Clown_bot` (display) and `@Clown_ha_bot` (handle) are the same account.** Don't waste cycles looking for a second bot.
- **Telegram bot privacy mode is bypassed by admin promotion per-group** — no BotFather change needed if the operator only wants one group.
- **`getUpdates` race condition**: calling Telegram's `getUpdates` with curl while openclaw is polling will race; prefer `getChat`/`getChatAdministrators` for diagnostics. Don't commit an offset.

---

## 16. LOCATIONS CHEAT SHEET (v2)

```
=== OPENCLAW RUNTIME ===
openclaw install:    /home/clown/.npm-global/lib/node_modules/openclaw/
openclaw dist JS:    /home/clown/.npm-global/lib/node_modules/openclaw/dist/
openclaw CLI:        /home/clown/.npm-global/bin/openclaw
config:              /home/clown/.openclaw/openclaw.json
secrets env:         /home/clown/.config/openclaw/secrets.env
systemd unit:        ~/.config/systemd/user/openclaw-gateway.service (+ .d/override.conf)

=== AGENTS ===
agent system.md:     /home/clown/.openclaw/agents/<id>/agent/system.md
workspaces:          /home/clown/.openclaw/workspace{,-<id>}/
retired agents:      /home/clown/.openclaw/agents_retired/

=== HA AGENT CANONICAL ===
                     /home/clown/ha-agent/{IDENTITY,CLAUDE,HA_SNAPSHOT,HA_OPS,HA_QUICK}.md

=== LOGS ===
json log file:       /tmp/openclaw/openclaw-YYYY-MM-DD.log
systemd journal:     journalctl --user -u openclaw-gateway.service

=== SOC DATA PIPELINE ===
soc_sync.sh:         /home/clown/soc_sync.sh        (cron */5m)
soc report input:    /home/clown/latest_soc_report.json  (fetched from ELK every 5m)
soc digest output:   /home/clown/soc_digest.txt
cron:                crontab -l (or /var/spool/cron/crontabs/clown)

=== SSH KEYS ON clown ===
~/.ssh/oced25519              -> elk (ELK SOC brain)
~/.ssh/oc_to_suricata_ed25519 -> suricata (Pi5 IDS)
~/.ssh/openclaw_ha            -> HA direct (add-on a0d7b954-ssh), port 22222, user laguna (2026-04-14)

=== SOC CANONICAL DOCS (Windows, operator-editable) ===
C:\Users\pierr\project_test\  (rawmeo-desktop)
  CLAUDE.md, NET_SNAPSHOT.md, SOC_OPS.md, QUICK.md, ARCH_DIARY.md, OPENCLAW_HANDOVER.md

=== TELEGRAM BOT ===
handle:              @Clown_ha_bot
display name:        Clown_bot  (same account)
id:                  8792388733
current group:       Administrators (supergroup, -1003941975878) — ha-agent binding
routing scope:       DMs + all other chats -> main (SOC)
```

---

## 17. QUICK REFERENCE — "IF IT BREAKS"

| Symptom | First check |
|---|---|
| No Telegram messages reaching the bot | `openclaw channels status --probe` — look for privacy mode or groupPolicy warnings; `getMe` `can_read_all_group_messages`; bot admin in group? |
| Right message but wrong agent | `openclaw agents bindings` — check tier + peer id matches current chat_id |
| `skipping group message` in log | `channels.telegram.groupPolicy` + per-group override; sender in `groupAllowFrom`? |
| Group stopped working after admin promotion | Check logs for `Group migrated` — basic→supergroup; rename keys + peer.id, restart |
| Gateway in restart loop | `journalctl --user -u openclaw-gateway.service -n 50` — look for `Config invalid` / zod errors; restore from `.bak` |
| Agent responds with stale persona | Edit `agent/system.md` or `workspace/*/SOUL.md`; no restart needed, but clear session: `echo '{}' > ~/.openclaw/agents/<id>/sessions/sessions.json` + restart |
| `socha` returns empty | `HA_TOKEN` in soc.conf on ELK; `curl http://192.168.86.15:8123` returns 200 |
| HA unreachable from openclaw_ha | `ssh -i ~/.ssh/openclaw_ha -p 22222 laguna@192.168.86.15` works? Check add-on container status in HA UI |
| Bot replying but log silent | Log level may be INFO; inbound events are DEBUG. Enable `OPENCLAW_LOG_LEVEL=debug` temporarily |
| Config rejected with `Invalid input` at `bindings.0` | Missing `channel` key, wrong `peer.kind` value, or non-strict field. Compare against `io-DhtVmzAJ.js:17001-17020` |

---

*End of handover. If you find something wrong or discover a new edge case, update this file in both locations (`/home/clown/.openclaw/OPENCLAW_HANDOVER.md` and `C:\Users\pierr\project_test\OPENCLAW_HANDOVER.md`) and bump the "Last updated" date at the top.*

