# HA_SNAPSHOT.md — rawmeo Home Assistant architecture
Last updated: 2026-04-14 (ha-agent bootstrap)
Operator: jimpanse / rawmeo / pierr
HA host: 192.168.86.15:8123

---

## ACCESS

| Method | From | Command |
|--------|------|---------|
| **Direct SSH (openclaw → HA)** — preferred for shell/YAML ops | openclaw | `ssh -i ~/.ssh/openclaw_ha -p 22222 laguna@192.168.86.15` |
| `socha` API tool — preferred for entity/automation queries | openclaw → ELK | `ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 '/home/jimpanse/soc-core/bin/socha <cmd>'` |
| Direct SSH (ELK → HA) — fallback | ELK | `ssh -p 22222 -i ~/.ssh/elk_to_ha_ed25519 laguna@192.168.86.15` |
| Operator SSH alias (`ha`) | rawmeo-desktop WSL | `ssh ha` (config alias, key `~/.ssh/homeos`) |
| Web UI | any | `http://192.168.86.15:8123` |
| API token | ELK | `HA_TOKEN` in `/home/jimpanse/soc-core/conf/soc.conf` (also `HA_HOST`, `HA_PORT`) |
| Telegram | operator | `/ha_*` commands — see OPENCLAW_HANDOVER.md for routing caveat (prefix routing not supported natively) |

**Landing target:** all `laguna@192.168.86.15` SSH paths land in the HA OS add-on container `a0d7b954-ssh`. `/config/` is bind-mounted into that container; `ha` CLI is **not** available (no API-token scope).
**HA version:** `2026.4.2` (live-read 2026-04-14 from `/config/.HA_VERSION`).

---

## SOCHA COMMANDS (ELK binary, called via `ssh elk '...'`)

| Command | Purpose |
|---------|---------|
| `socha logbook <entity> [hours]` | Full event log for an entity (default 24h) |
| `socha digest <entity> [hours]` | Compact 10-line bot-friendly log |
| `socha state <entity>` | Current state of one entity |
| `socha states [filter]` | List all states (default filter `light`) |
| `socha automations [filter]` | List automations + last-triggered + state |
| `socha config [filename]` | Read `/config/packages/<file>` |
| `socha packages` | List package filenames |
| `socha call <domain.service> <entity>` | Call HA service — **CONFIRM FIRST** |
| `socha restart` | Reload HA automations — **CONFIRM FIRST, disruptive** |

**Read-only (run freely):** `logbook`, `digest`, `state`, `states`, `automations`, `config`, `packages`
**Confirm first:** `call`, `restart`, any YAML edit

---

## CONFIG FILES (on HA host at `/config/`)

| File | Purpose |
|------|---------|
| `/config/packages/motion_lights.yaml` | Motion-triggered lighting automations (+ `.bak`, `.bak2` siblings) |
| `/config/packages/garden_lights.yaml` | Garden/outdoor lighting schedules (sunset ON / sunrise OFF) |
| `/config/packages/hue_motion_v1.yaml.disabled` | Deprecated — disabled, not loaded |
| `/config/.storage/` | Integration state — **do not edit directly** |
| `/config/configuration.yaml` | Master config |

Package files live-verified 2026-04-14 via `socha packages`.

---

## ENTITY DOMAIN INVENTORY (live snapshot 2026-04-14)

Domain counts from `socha states` (default filter = `light`):

| Domain | Count | Notes |
|--------|-------|-------|
| `light` | 88 | Hue bridges x2, Tapo L530 x3, WiZ, Yeelink, Aqara-driven lights |
| `scene` | 12 | Hue scenes |
| `switch` | 6 | Hue Bridge automation toggles (`switch.automation_*`) |
| `automation` | 6 | Visible under `states` filter (full list below is from `socha automations`) |
| `select` | 3 | |

Other domains (`binary_sensor`, `sensor`, `person`, `zone`, …) are not in the default `light`-filter slice — query with `socha states <domain>` when needed.

### Key HA entities (known from TOOLS.md + live `automations` list)
- **Motion sensors:** `binary_sensor.bedroom_mainbathroom_motion`, `binary_sensor.entrance_bedroom_motion` (variant: `entrance_downstairs_motion`), `binary_sensor.bedroom_clothes_motion`, `binary_sensor.bathroom_downstairs_motion`
- **Lights (motion-driven):** `light.bedroom_mainbathroom`, `light.entryway_bedroom`, `light.bedroom_clothes`, `light.bathroom_downstairs`, `light.garden_tapo`, `light.wiz_entrance`, `light.aussenlampen`
- **Garden:** `automation.garden_lights_on_sunset`, `automation.garden_lights_off_sunrise`

---

## ACTIVE AUTOMATIONS (from `socha automations` 2026-04-14)

### ON / healthy (8 automations + 5 Hue bridge switches)
- `automation.garden_lights_on_sunset` — Garden Lights ON
- `automation.garden_lights_off_sunrise` — Garden Lights OFF
- `automation.motion_bathroom_downstairs` — Motion - Bathroom Downstairs
- `automation.motion_bedroom_clothes` — Motion - Bedroom Clothes
- `automation.motion_bedroom_entryway` — Motion - Bedroom Entryway
- `automation.motion_bedroom_main_bathroom_3` — Motion - Bedroom Main Bathroom
- `automation.motion_entrance_downstairs` — Motion - Entrance Downstairs
- `automation.motion_outdoor_garage` — Motion - Outdoor Garage
- `switch.automation_wohnzimmer_b`, `switch.automation_kuche`, `switch.automation_hue_dimmer_switch_3`, `switch.automation_hue_dimmer_switch_5`, `switch.automation_6_wohnzimmer` — Hue Bridge automations

### UNAVAILABLE (exist but entity not reachable — investigate before touching)
- `automation.entrance_wiz_motion`, `automation.wash_area_light_motion`
- `automation.garden_light_tapo`, `automation.garden_light_tapo_off`
- `automation.voice_chill_scene`, `automation.voice_lightstrip_on`, `automation.voice_hotword_debug_notification`
- `automation.staircase_motion_entryway_bedroom`
- `automation.garage_entryway_motion`, `automation.aqara_motion_garage_and_entry`
- `automation.motion_outdoor_garage_2`, `automation.motion_bathroom_downstairs_2`
- (Total live-observed: ~25 automations, split roughly 13 healthy vs 12 unavailable.)

---

## INTEGRATIONS / DEVICE ECOSYSTEMS (inferred from entities)

- **Philips Hue** — 2 bridges (see NET_SNAPSHOT `.86.70`/`.86.72`): `light.hue_*`, scene control, dimmer switches 3/5/6
- **TP-Link Tapo (L530)** — `light.garden_tapo` + bedroom bulbs (.86.179–181)
- **WiZ** — `light.wiz_entrance`, `light.wash_area_light` (.86.111/.112/.174)
- **Yeelink (Xiaomi)** — `light.aussenlampen` and 7+ color bulbs (.86.170/.171/.175–178/.182)
- **Aqara** — `aqara-hub-m2-0283` (.86.204) drives binary_sensor motion entities
- **Sonos** — `light.kitchen_crossfade` event visible in digest; Sonos speakers .86.40/.41/.43/.248
- **Voice** — `automation.voice_*` (all unavailable; integration inactive)

Run `socha config motion_lights.yaml` / `socha config garden_lights.yaml` for ground truth on how each automation is wired.

---

## NORMAL BASELINES

| Metric | Normal |
|--------|--------|
| HA events/hr (as seen by Suricata) | ~130 (SOC-agent baseline — do not tune from here) |
| HA HTTP endpoint | `:8123` returns HTTP 200 |
| 3am bursts to `.86.1`/`.40`/`.41` | Scheduled device polling (Sonos + gateway) — NORMAL |
| HA offline window | Rare; if `:8123` unreachable → check SSH to `.86.15`, then HA add-on status |
| Motion → light latency | Sub-second (immediate `light.turn_on` call via `automation.motion_*`) |

---

## KNOWN ANOMALIES / HISTORY

- **HA IP drifted** `.86.16 → .86.15` (reprovision 2026-04-13). Stale `.86.16` row still present in NetAlertX but archived. Current MAC `2c:cf:67:f4:60:08`, Raspberry Pi vendor.
- **SSH access** via HA OS add-on container `a0d7b954-ssh` — authorized_keys are **separate** from system `~/.ssh`. Key rotation must go through the add-on config UI.
- **Key on ELK**: `elk_to_ha_ed25519` (authorized 2026-04-07, verified 2026-04-14).
- **Operator key**: `~/.ssh/homeos` (used by alias `ha` on rawmeo-desktop WSL).
- **Mid-audit outage** 2026-04-14 am: `.86.15:8123` + SSH 22222 briefly refused during SSH audit pass. Back to HTTP 200 by HA bootstrap (this session).
- **SOC relationship**: SOC agent treats HA purely as a network device. Do not expect SOC to investigate HA automation failures — that's this agent's job.
- **Deprecated package**: `/config/packages/hue_motion_v1.yaml.disabled` kept as-is; not loaded by HA.
- **Two `.bak` motion_lights siblings** (`motion_lights.yaml.bak`, `.bak2`) — previous-version rollback points, do not edit.
