# HA_QUICK.md — ha-agent session-start card
Read this FIRST every session.
Last sync: 2026-04-14 (bootstrap)

---

## CURRENT STATE

| | |
|---|---|
| HA host | 192.168.86.15:8123 (HTTP 200 live-verified 2026-04-14) |
| HA version | 2026.4.2 |
| **Direct SSH from openclaw** | `ssh -i ~/.ssh/openclaw_ha -p 22222 laguna@192.168.86.15` (landing: add-on container `a0d7b954-ssh`) |
| SSH fallback (from ELK) | `~/.ssh/elk_to_ha_ed25519` → same target |
| API tool | `socha` on ELK (`/home/jimpanse/soc-core/bin/socha`) |
| Config packages | `/config/packages/` (motion_lights.yaml, garden_lights.yaml) |
| Active automations | 13 healthy ON, 12 `unavailable` (needs investigation) |
| Light entities | 88 |

---

## FIRST THREE COMMANDS

```bash
# 1. Direct HA shell (fastest check; openclaw → HA, no ELK hop)
ssh -o BatchMode=yes -i ~/.ssh/openclaw_ha -p 22222 laguna@192.168.86.15 \
    'hostname && ls /config/packages/'

# 2. Entity/automation digest (API path via ELK's socha)
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha digest'

# 3. Active automations
ssh -p 22222 -i ~/.ssh/oced25519 jimpanse@192.168.86.5 \
    '/home/jimpanse/soc-core/bin/socha automations'
```

---

## TOP OPEN ITEMS

1. ⏳ **12 `unavailable` automations** — decide for each: fix integration, disable, or delete. Candidates: `entrance_wiz_motion`, `wash_area_light_motion`, `garden_light_tapo(_off)`, `voice_*` (3), `staircase_motion_entryway_bedroom`, `garage_entryway_motion`, `aqara_motion_garage_and_entry`, `motion_outdoor_garage_2`, `motion_bathroom_downstairs_2`.
2. ⏳ Clean up `motion_lights.yaml.bak` / `.bak2` siblings in `/config/packages/` — confirm not loaded, then archive.
3. ⏳ Confirm `automation.*_2` duplicates aren't shadowing their `_1` counterparts.
4. ⏳ Validate `hue_motion_v1.yaml.disabled` is truly unloaded (no residual entities).
5. ⏳ Document full integration list — next session run and capture from HA UI (socha has no `integrations` subcommand).

---

## KNOWN NORMAL

- **3am device polling bursts** from HA to `.86.1`/`.86.40`/`.86.41` → SCHEDULED polling, **do not alert** (SOC agent's job anyway).
- **~130 events/hr** in Suricata from HA → SOC agent baseline, not our concern.
- **`.86.15` vs `.86.16` MAC churn** in NetAlertX → `.86.15` is current, `.86.16` is archived (reprovision 2026-04-13).
- **`switch.automation_*` entries** are Hue Bridge automation toggles (not HA-native automations). Leave them alone unless asked.

---

## BOUNDARY REMINDER

- **Network security, NetAlertX, Suricata, Pi-hole, ES** → SOC agent (`/home/clown/.openclaw/workspace/`)
- **Home automation, entities, service calls, YAML packages** → THIS agent (ha-agent)

Never cross the boundary. When in doubt, escalate.
