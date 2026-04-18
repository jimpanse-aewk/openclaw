# TOOLS.md — ha-agent command reference
Last updated: 2026-04-14 (bootstrap)

---

## ⚠️ CRITICAL RULES — READ FIRST

**SSH — always full path + key (no aliases in scripts):**
```
OpenClaw → HA direct: ssh -i /home/clown/.ssh/openclaw_ha -p 22222 laguna@192.168.86.15   # shell + YAML edits
OpenClaw → ELK:       ssh -p 22222 -i /home/clown/.ssh/oced25519 jimpanse@192.168.86.5     # for socha API path
ELK → HA (fallback):  ssh -p 22222 -i /home/jimpanse/.ssh/elk_to_ha_ed25519 laguna@192.168.86.15
socha binary:         /home/jimpanse/soc-core/bin/socha (on ELK, not PATH under non-interactive SSH)
Token:                HA_TOKEN in /home/jimpanse/soc-core/conf/soc.conf (on ELK)
HA landing container: a0d7b954-ssh (HA add-on) — /config/ mounted, `ha` CLI NOT available
```

**Data rules — hard stops:**
1. NEVER answer from memory about entity states, automation IDs, or HA YAML contents
2. ALWAYS fetch live data via `socha` before answering — answer only from that output
3. For service calls: verify current state first, then confirm with operator, then execute
4. Entity not in `socha states` / `socha automations` → say so and STOP
5. SOC questions → redirect to `main` agent; do not touch any `soc*` binary except `socha`

---

## HA COMMAND MAP

All commands run as `ssh -p 22222 -i /home/clown/.ssh/oced25519 jimpanse@192.168.86.5 '/home/jimpanse/soc-core/bin/socha <args>'`. Shortened below as `SOCHA <args>`.

| User says | Run this |
|-----------|----------|
| `ha status` / `ha digest` / `what's happening` | `SOCHA digest` |
| `ha logbook [entity] [hours]` / `recent activity` | `SOCHA logbook <entity> <hours>` |
| `which lights are on` / `ha states` / `ha lights` | `SOCHA states light` |
| `ha state <entity>` / `is X on` | `SOCHA state <entity_id>` |
| `ha automations` / `list automations` | `SOCHA automations` |
| `show bedroom automations` | `SOCHA automations bedroom` |
| `ha packages` / `list config files` | `SOCHA packages` |
| `show motion config` / `ha config motion_lights` | `SOCHA config motion_lights.yaml` |
| `show garden config` | `SOCHA config garden_lights.yaml` |
| `turn on <light>` / `ha call light.turn_on <entity>` | `SOCHA call light.turn_on <entity>` — **CONFIRM FIRST** |
| `turn off <light>` | `SOCHA call light.turn_off <entity>` — **CONFIRM FIRST** |
| `trigger <automation>` | `SOCHA call automation.trigger automation.<id>` — **CONFIRM FIRST** |
| `ha reload` / `reload automations` | `SOCHA call automation.reload` — **CONFIRM FIRST** |
| `ha restart` | `SOCHA restart` — **CONFIRM FIRST, disruptive** |

**socha read-only (run freely):** `logbook`, `digest`, `state`, `states`, `automations`, `config`, `packages`
**socha confirm first:** `call` (any service), `restart`, any YAML edit

---

## KNOWN ENTITIES (from HA_SNAPSHOT.md — re-verify with `socha states`)

**Motion sensors:**
- `binary_sensor.bedroom_mainbathroom_motion`
- `binary_sensor.entrance_bedroom_motion` / `binary_sensor.entrance_downstairs_motion`
- `binary_sensor.bedroom_clothes_motion`
- `binary_sensor.bathroom_downstairs_motion`

**Motion-driven lights:**
- `light.bedroom_mainbathroom`, `light.entryway_bedroom`, `light.bedroom_clothes`
- `light.bathroom_downstairs`
- `light.garden_tapo`, `light.wiz_entrance`, `light.aussenlampen`

**Garden automations:**
- `automation.garden_lights_on_sunset`
- `automation.garden_lights_off_sunrise`

**Motion automations (active):**
- `automation.motion_bathroom_downstairs`
- `automation.motion_bedroom_clothes`
- `automation.motion_bedroom_entryway`
- `automation.motion_bedroom_main_bathroom_3`
- `automation.motion_entrance_downstairs`
- `automation.motion_outdoor_garage`

**Hue Bridge automation switches** (bridge-owned, not HA-native):
- `switch.automation_wohnzimmer_b`, `switch.automation_kuche`
- `switch.automation_hue_dimmer_switch_3`, `switch.automation_hue_dimmer_switch_5`
- `switch.automation_6_wohnzimmer`

---

## TROUBLESHOOTING

| Symptom | Fix |
|---------|-----|
| `socha` returns empty | Check `HA_TOKEN` in soc.conf on ELK; confirm `curl http://192.168.86.15:8123` returns 200 |
| HA unreachable `:8123` | Check from pihole + ELK (rule out network-side issue); if truly down, SSH to HA and run `ha core info` |
| HA SSH password prompt | Addon container `a0d7b954-ssh` authorized_keys separate from system — fix via HA add-on config UI |
| Automation not triggering | `SOCHA automations` → check state + last_triggered; `SOCHA logbook automation.<id> 6` |
| Entity `unavailable` | Integration down — check HA UI logbook, reload that integration only |
| `socha call` fails | Double-check exact `<domain.service>` and `<entity_id>` from `SOCHA states` |
| Motion fires twice | Duplicate package loaded — `SOCHA packages` to check for `.bak` siblings |
| Need full restart | `SOCHA restart` — **CONFIRM FIRST** |
| SOC question arrived here | Redirect user to `main` agent — do not touch SOC tools |

---

## RED FLAGS — HA SIDE ONLY (network-side goes to SOC)

- Automation `unavailable` that was `on` yesterday → integration regression
- Motion sensor stuck `on` → sensor-side fault, not a security concern
- Light state diverges from HA UI → Hue bridge out-of-sync, reload Hue integration
- `.bak`/`.bak2` package file accidentally active → delete and reload

---

## BACKUP
Package files live at `/config/packages/` on HA. For full HA snapshot use HA's native backup UI (don't try to scp `/config/` — permissions will bite you).
