# MEMORY.md — Long-Term Memory
⚠️ Load in MAIN SESSION only. Do NOT expose in group chats.

## CORE ARCHITECTURE
- ELK (86.5): Elasticsearch + soc-core — intelligence + reporting
- Suricata (86.4): IDS sensor — feeds ELK via eve.json + Filebeat
- Pi-hole (86.11): DNS filter + NetAlertX device DB + Tailscale source of truth
- Home Assistant (86.15): automation brain — working well, low maintenance
- OpenClaw (86.8): me — Haiku agent, Telegram bot (@Clown_ha_bot)

## SYSTEM RULES
- ELK/Suricata do heavy processing — agent reads digests, not raw logs
- soc_digest.txt = 200-token pre-digested summary — use this for status checks
- soccheck-ip-cached preferred over soccheck-ip — saves API quota (1000/day AbuseIPDB, 500/day VT)
- never trust risk score alone — correlate before escalating
- prefer reversible actions

## TUNING HISTORY (what was fixed and why)
- 2026-04-05: Score HIGH(7)→LOW(2) via 6 fixes:
  1. sid:9000006 disabled (sweep rule too broad, fired on Samsung/Tapo/Nest)
  2. lateral_movement.py: dynamic device list from known_devices.json (was hardcoded 5 IPs)
  3. overlap scoring: excludes trusted_external_ips + RFC1918 (was scoring own IP +2)
  4. trusted_domains: added elk, ntp.wiz.world, tplinknbu.com
  5. noise_signatures: added Ring/Nest DNS bypass, unencrypted HTTP, .world TLD
  6. Bot hardening: anti-hallucination rules in system.md + TOOLS.md rewrite
- 2026-04-04: Tailscale DERP (68.183.90.120) confirmed safe, added to trusted_external_ips
- 2026-04-04: SOC v3 upgrade: lateral movement detection, MAC baseline, TLS mismatch, socbaseline

## KNOWN PATTERNS (save API calls)
- STUN/DERP traffic = Tailscale, always normal
- Pi-hole high volume = normal (870/hr baseline)
- rawmeo-desktop may show as "New" after idle — same machine, not suspicious
- Samsung TV + Tapo plugs + Nest wifi generate IoT chatter — all expected
- HA 3am bursts = scheduled device polling
- Pi-hole myip.opendns.com = NetAlertX IP check (every 5min)
- Hue duplicates in HA — known issue, low priority

## USER PREFERENCES
- Bro: short, structured, technical
- action-first, no fluff, cost-aware
- prefers Telegram for remote control

## OPENCLAW CONFIG
- Model: claude-haiku-4-5 (cost-aware)
- NEVER run `openclaw reset` — deletes everything
- Safe restart: `openclaw gateway --force > /tmp/oc.log 2>&1 & sleep 3 && openclaw health`
- Session wipe: `echo '{}' > ~/.openclaw/agents/main/sessions/sessions.json`
