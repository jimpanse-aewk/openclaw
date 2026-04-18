# HA_OPS.md — rawmeo ha-agent runbook
Last updated: 2026-04-14

## SCOPE
Operational procedures for `ha-agent`. For architecture / topology / entity inventory see `HA_SNAPSHOT.md`.

---

## FIRST CHECKS (start of session)

```bash
# 1. Confirm HA is up
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.86.15:8123

# 2. Confirm direct shell to HA works (openclaw → HA add-on container a0d7b954-ssh)
ssh -o BatchMode=yes -i ~/.ssh/openclaw_ha -p 22222 laguna@192.168.86.15 'hostname && ls /config/packages/'

# 3. Run digest (compact last 10 events, bot-friendly — still via ELK's socha for API access)
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha digest'

# 4. Check active automations
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha automations'
```

> **Two-path access rule:**
> - **API queries** (states, automations, logbook, service calls) → openclaw → ELK → `socha` (uses `HA_TOKEN`)
> - **Shell / YAML edits** (packages, config inspection) → openclaw → HA direct via `~/.ssh/openclaw_ha`
>
> Aliases (`ssh elk`, `ssh ha`) only work interactively on operator's WSL; on openclaw always use explicit key + user@host.

---

## AUTOMATION MANAGEMENT

### List all automations
```bash
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha automations'
```
Output format: `<state> | automation.<id> | <friendly_name>` — look for `unavailable` entries that should be `on`.

### Read a package file (YAML source of truth)
```bash
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha config motion_lights.yaml'
```
Package files live at `/config/packages/*.yaml` on HA. Known files: `motion_lights.yaml`, `garden_lights.yaml`, `hue_motion_v1.yaml.disabled` (not loaded).

### Reload automations after editing a package file
```bash
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha call automation reload'
# Full restart (CONFIRM FIRST — disruptive):
# ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
#     '/home/jimpanse/soc-core/bin/socha restart'
```

### Edit a package file (from openclaw, preferred for agent-side edits)
```bash
# Direct openclaw → HA (no ELK hop)
ssh -i ~/.ssh/openclaw_ha -p 22222 laguna@192.168.86.15 \
    'cat /config/packages/motion_lights.yaml'

# Or interactive shell for multi-step edits:
ssh -i ~/.ssh/openclaw_ha -p 22222 laguna@192.168.86.15
# inside: vi /config/packages/motion_lights.yaml, then exit
# Then reload automations via socha (above)

# From operator's rawmeo-desktop WSL, the alias `ssh ha` also works (key ~/.ssh/homeos)
```

> The `openclaw_ha` key lands in HA add-on container `a0d7b954-ssh`. `/config/` is visible; `ha` CLI is NOT available in that container (no API-token scope) — use `socha call` via ELK for any `ha core *` equivalent.

---

## SERVICE CALLS (ALWAYS CONFIRM FIRST)

Rule: never call a service that controls a physical actuator without operator confirmation.

```bash
# Turn on a light
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha call light.turn_on light.<entity_id>'

# Turn off a light
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha call light.turn_off light.<entity_id>'

# Trigger an automation
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha call automation.trigger automation.<id>'
```

Verify first with `socha state <entity>` — if the light is already in the desired state, do nothing and tell the operator.

---

## TROUBLESHOOTING

| Symptom | Fix |
|---------|-----|
| `socha` returns empty | Check `HA_TOKEN` in `/home/jimpanse/soc-core/conf/soc.conf`; confirm `curl http://192.168.86.15:8123` returns 200 |
| HA unreachable on `:8123` | Check from pihole/ELK first (rule out WSL/openclaw-side network issue); if truly down, SSH to `.86.15` and inspect `ha core info` |
| HA SSH prompt for password | Addon container `a0d7b954-ssh` authorized_keys differs from system `~/.ssh` — fix via HA add-on config UI |
| Automation not triggering | `socha automations` → check last_triggered + state; `socha logbook automation.<id> 6` to see why |
| Entity `unavailable` | Integration is down; check HA UI logbook, restart the specific integration (not the whole HA) |
| `socha call` fails | Double-check exact `<domain.service>` and `<entity_id>` (copy from `socha states` output) |
| HA restart needed | Use `socha restart` — **always confirm with operator first** |
| Motion automation fires twice | Likely a `.bak`/`.bak2` duplicate loaded — check `socha packages` for dup active files |
| `automation.*_2` entries in `unavailable` state | Stale duplicate — candidate for removal from YAML (disable first, delete later) |
| Hue bridge switch stuck `on` / `off` | Reload Hue integration in HA UI; do not force-toggle `switch.automation_*` |

---

## ESCALATION TO SOC AGENT

Hand off to the SOC agent (context root `/home/clown/.openclaw/workspace/`) if:

- HA device is making unexpected network connections (check Suricata)
- HA traffic baseline > 500 events/hr (network anomaly, not HA problem)
- New unknown device appears at `.86.15` / `.86.16` in NetAlertX
- Any IP reputation or threat-intel question
- Suricata rule tuning, `soc_config.json` edits, NetAlertX DB changes

Never cross into those areas directly — that is SOC-only.

---

## CHANGE LOG

- **2026-04-14:** Bootstrap. `ha-agent` split out of SOC main agent. `socha` ownership moved here. `elk_to_ha_ed25519` key reassigned to this agent. Live data: 88 lights, 25 automations (13 healthy + 12 unavailable), 3 package files (`motion_lights.yaml`, `garden_lights.yaml`, `hue_motion_v1.yaml.disabled`).
