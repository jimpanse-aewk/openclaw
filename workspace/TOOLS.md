# TOOLS.md — SOC Command Reference
Last updated: 2026-04-14 (HA split out to `ha-agent`)

---

## ⚠️ CRITICAL RULES — READ FIRST

**SSH — always full path + key (no aliases in scripts):**
```
OpenClaw → ELK:       ssh -i /home/clown/.ssh/oced25519 jimpanse@192.168.86.5
OpenClaw → Suricata:  ssh -p 22222 -i /home/clown/.ssh/oc_to_suricata_ed25519 jimpanse@192.168.86.4
ELK → Pi-hole:        ssh -p 22222 -i ~/.ssh/elk_to_pihole_ed25519 cookiehacker@192.168.86.11
ELK → Suricata:       ssh -p 22222 -i ~/.ssh/elk_to_pi5_ed25519 jimpanse@192.168.86.4
SOC bin:              /home/jimpanse/soc-core/bin/  ← NOT in PATH on non-interactive SSH
Primary config:       ~/scripts/config/soc_config.json on ELK
Credentials:          ~/soc-core/conf/soc.conf on ELK  (VT_KEY, AbuseIPDB, Telegram)
```

**Data rules — hard stops:**
1. NEVER answer from memory about IPs, devices, or events
2. NEVER run soccheck-ip on an IP unless it appeared in output you JUST retrieved
3. ALWAYS fetch live data first — answer only from that output
4. IP not in current report → say so and STOP
5. HA questions → delegate to `ha-agent`, do not call `socha` yourself

---

> ⚠️ For device last-connection queries → always use socdevice-show, NOT socprofile. These are different tools. socprofile = Suricata history. socdevice-show = NetAlertX last connection.

## SOC COMMAND MAP

| User says | Run this |
|-----------|----------|
| `status soc` / `score` / `is network clean` | `cat /home/clown/soc_digest.txt` |
| `show devices` / `who is on network` | `ssh ELK "/home/jimpanse/soc-core/bin/socdevices"` |
| `check <IP>` — ONLY if IP in current report | `ssh ELK "/home/jimpanse/soc-core/bin/soccheck-ip-cached <IP>"` |
| `profile <IP>` / `what has X been doing` | `ssh ELK "/home/jimpanse/soc-core/bin/socprofile <IP> --quick"` |
| `last seen <IP>` / `when was X online` / `when did X connect` / `is X online` | `ssh ELK "/home/jimpanse/soc-core/bin/socdevice-show <IP>"` |
| `report soc` / `full report` | `ssh ELK "cat ~/scripts/reports/latest_soc_report.json | python3 -m json.tool | head -80"` |
| `do refresh soc` | `ssh ELK "python3 ~/scripts/soc_report.py"` |
| `do reload suricata` | `ssh SURICATA "sudo systemctl restart suricata"` |
| `status tailscale` | `ssh ELK "/home/jimpanse/soc-core/bin/soctailscale"` |
| `last domains` / `what did X browse` | `ssh ELK "/home/jimpanse/soc-core/bin/socpihole --client <IP> --clean"` |
| `where did X connect` / `destinations for X` | `ssh ELK "/home/jimpanse/soc-core/bin/socdest <IP>"` |
| `show cache` / `reputation cache` | `ssh ELK "/home/jimpanse/soc-core/bin/soccache"` |
| `scan now` / `who is online` | `/home/clown/scripts/oc_scan.sh` |
| `identify <IP>` / `what is <IP>` | `/home/clown/scripts/oc_identify.sh <IP>` |
| `ports <IP>` / `open ports <IP>` | `/home/clown/scripts/oc_ports.sh <IP>` |
| `block <IP>` | CONFIRM FIRST → `/home/clown/scripts/oc_block.sh <IP>` |

---

## DELEGATED — HA AGENT

The following tools belong to `ha-agent` and are **not** available to this (SOC) agent:

- `socha` — all subcommands: `logbook`, `digest`, `state`, `states`, `automations`, `config`, `packages`, `call`, `restart`
- Direct HA API calls to `192.168.86.15:8123`
- Reads/edits of `/config/packages/*.yaml` (motion_lights, garden_lights, etc.)
- `HA_TOKEN` in `~/soc-core/conf/soc.conf` on ELK
- SSH hop `ELK → HA` via `elk_to_ha_ed25519` / `laguna@192.168.86.15`

**If the user asks about HA automations, entity states, lights, or motion sensors → respond:**
> That's handled by `ha-agent`. I only see HA as a network device (traffic, new-device alerts).

**What THIS agent may do with HA:**
- Treat `.86.15` as a network device in NetAlertX / Suricata baselines
- Alert on HA traffic anomalies (events/hr > 500, new MAC at .86.15, LAN→LAN pivot)
- Never open a socha/HA-API connection

---

## WHEN TO RUN soccheck-ip-cached
ALL three must be true:
1. IP appeared in output you just retrieved
2. IP is NOT in KNOWN SAFE list below
3. User asked to check it OR IP looks suspicious

Always use `soccheck-ip-cached` (not `soccheck-ip`) — 7-day cache, saves API quota.

---

## KNOWN SAFE — NEVER FLAG, NEVER CHECK

**Internal IPs:**
`.86.1` google-router | `.86.4` suricata | `.86.5` ELK | `.86.11` pihole | `.86.15` homeassistant
`.86.91` samsung-livingroom | `.86.120` tapo110M-1 | `.86.121` tapo110m-2 | `.86.202` openclaw
`.86.207` rawmeo-desktop | `.86.235` nest-wifi-point | `.86.102` ring-doorbell-2 | `.86.226` nest-guesthouse
`127.0.0.1` localhost | `100.76.105.56` Tailscale-rawmeo

**External IPs (confirmed safe):**
`171.5.18.205`, `171.5.25.136` — own (Triple T Broadband TH)
`68.183.90.120` — Tailscale DERP relay (DigitalOcean India)
`172.237.72.79` — Akamai/Linode CDN
`208.103.161.x` — Notion Labs (websocket port 443)
`172.172.255.218` — Microsoft Azure
`199.165.136.x` — Amazon AWS (Notion backend)
`205.147.105.30` — Host Virtual HK
`167.54.156.43` — Shared Services Canada CDN
 — Host Virtual HK
 — Shared Services Canada CDN

**Signatures — never escalate:**
- STUN Binding Request/Response — Tailscale (suppressed weight=0)
- ET LOCAL Non-PiHole DNS resolver bypassed — Ring/Nest hardcode 8.8.8.8 (noise)
- ET LOCAL Unencrypted HTTP to external IP — IoT traffic (noise)
- ET HUNTING Telegram API Domain — own bot (noise)
- ET INFO Go-http-client — Tailscale/Go apps (noise)
- ET USER_AGENTS Steam — gaming (noise)
- Alibaba CDN / aliyuncs.com — OPPO telemetry (noise)
- ntp.wiz.world — Tapo plugs NTP (trusted)
- tplinknbu.com — Tapo TP-Link cloud (trusted)
- openrouter.ai — operator AI tools (noise)
- Grab/Sinch/Taobao — Thailand app traffic (noise)
- ET POLICY External IP Lookup (myip.opendns.com) — NetAlertX external IP check (suppressed)

---

## DEVICES THAT LOOK SUSPICIOUS BUT AREN'T

| Device | Why it looks weird | Reality |
|--------|--------------------|---------|
| rawmeo-desktop (.207) | May show as "New" after idle | Same machine, not suspicious |
| samsung-livingroom (.91) | IoT chatter, was triggering sweep rule | Normal |
| tapo110M (.120/.121) | TP-Link cloud telemetry | Normal |
| nest-wifi-point (.235) | Google telemetry | Normal |
| homeassistant (.15) | 3am bursts to .86.1/.86.40/.86.41 | Scheduled device polling |
| pihole (.11) | myip.opendns.com every ~5min | NetAlertX external IP check |
| rawmeo-notebook (.12) | Same user as .207 | Different IP when on WiFi |
| android-oppo (.19) | UC Browser telemetry, aliyuncs.com | aewsa's phone — KNOWN SAFE |

---

## NORMAL BASELINES (score LOW=2 is clean)
- Pi-hole: ~870 alerts/hr
- rawmeo-desktop: ~710 alerts/hr
- homeassistant: ~70 alerts/hr
- STUN: ~2700/hr (always suppressed)
- Anomaly threshold: risk >2.65σ or alerts >3700/hr

---

## RED FLAGS — INVESTIGATE IMMEDIATELY
- Any device on ports: 4444, 6667, 1337, 31337, 9001
- NXDOMAIN rate >30 on idle device
- Session >1 hour to unknown external IP
- New device appearing at 3am
- Large upload (>100MB) to non-CDN IP
- Device contacting Tor endpoints

---

## AUTONOMOUS INVESTIGATION CHAIN
When oc_scan.sh reports ANY `!!!` unknown device — run ALL without waiting:

1. `grep -i "<MAC first 3 octets>" /usr/share/arp-scan/ieee-oui.txt` — vendor
2. `/home/clown/scripts/oc_identify.sh <IP>` — fingerprint
3. `/home/clown/scripts/oc_ports.sh <IP>` — open ports
4. `ssh ELK "/home/jimpanse/soc-core/bin/socprofile <IP> --quick"` — Suricata history
5. `ssh ELK "/home/jimpanse/soc-core/bin/socpihole --client <IP> --clean"` — DNS history
6. `cat /home/clown/soc_digest.txt | grep <IP>` — in current SOC report?

Verdict format: Device type | Vendor | Ports | DNS | Suricata hits | Owner | → KNOWN_SAFE / MONITOR / INVESTIGATE / BLOCK
Label everything: Confirmed / Inferred / Uncertain

---

## TUNING COMMANDS

```bash
# Add IP to ignore_ips
ssh elk "python3 -c \"
import json
with open('/home/jimpanse/scripts/config/soc_config.json') as f: cfg=json.load(f)
cfg['filters']['ignore_ips'].append('192.168.86.X')
with open('/home/jimpanse/scripts/config/soc_config.json','w') as f: json.dump(cfg,f,indent=2)
print('done')\""

# Add signature to noise (weight=1)
ssh elk "python3 -c \"
import json
with open('/home/jimpanse/scripts/config/soc_config.json') as f: cfg=json.load(f)
cfg['filters']['noise_signatures'].append('SIGNATURE NAME HERE')
with open('/home/jimpanse/scripts/config/soc_config.json','w') as f: json.dump(cfg,f,indent=2)
print('done')\""
```

---

## TROUBLESHOOTING

| Symptom | Fix |
|---------|-----|
| Stale reports | `ssh elk "crontab -l"` — check */15 entries |
| soc_report.py fails | `ssh elk "tail -20 ~/scripts/reports/soc_report.log"` |
| Password prompt on ssh elk | Check `~/.ssh/config` on OpenClaw |
| Suricata rules not loading | `ssh suricata "sudo systemctl restart suricata"` |
| OpenClaw not responding | `openclaw gateway --force > /tmp/oc.log 2>&1 & sleep 3 && openclaw health` |
| Score stuck HIGH | `ssh elk "grep -A10 suppressed ~/scripts/config/soc_config.json"` |
| Bot invents data | Wipe sessions: `echo '{}' > ~/.openclaw/agents/main/sessions/sessions.json` then restart |
| soccheck-ip not found | Use full path: `/home/jimpanse/soc-core/bin/soccheck-ip` |
| No new device alerts | Check `devIsNew` flag in NetAlertX DB directly |
| Tailscale summary fails | Verify Pi-hole has `tailscale`+`jq`, check key `elk_to_pihole_ed25519` |
| socdevices shows 0 alerts | NetAlertX SSH failing |
| ES aggregation error on src_ip | Field is text — use `match_phrase`, not terms aggregation |
| TOTAL_EVENTS=0 in socprofile | Wrong IP or device not on Suricata interface |
| soccheck-ip hitting API quota | Use `soccheck-ip-cached` — 7-day TTL |
| HA / socha issue of any kind | **Delegate to `ha-agent`** — not this agent's scope |

---

## TUNING HISTORY

**sid:9000006 — ET LOCAL Rapid internal port sweep**
DISABLED 2026-04-05. False-firing on Samsung TV, Tapo, Nest. Zero hits expected.

**lateral_movement.py**
Fixed 2026-04-05. Loads all 27 devices from known_devices.json. Was hardcoded 5 IPs.

**Overlap scoring**
Fixed 2026-04-05. Excludes trusted_external_ips + RFC1918. Was scoring own IP 171.5.18.205 as +2.

**Score history**
HIGH(7) → LOW(2) on 2026-04-05 via 6 fixes. LOW(2) = confirmed normal baseline.

**Timezone**
Normalized 2026-04-06. UTC internally, Asia/Bangkok (ICT) for human output.

**socha (HA tool) — DELEGATED**
Added 2026-04-07. ELK → HA SSH key: `elk_to_ha_ed25519`. HA addon authorized_keys configured. **Ownership moved to `ha-agent` on 2026-04-14.** SOC agent no longer uses this tool.

---

## BACKUP
Script: `soc_backup_windows.ps1` + `soc_backup.sh`
Run from: rawmeo-desktop (Windows PowerShell)
Output: `C:\Users\pierr\soc_backups\soc_backup_TIMESTAMP.tar.gz`
Covers: ELK (soc-core, scripts, config, keys), Suricata rules, Pi-hole, OpenClaw workspace
Retention: last 3 on OpenClaw, unlimited on Windows

---

## RISK SCORING REFERENCE

| Trigger | Points |
|---------|--------|
| Real Suricata alerts (>10) | +3 |
| Noise alerts (>100) | +1 |
| Watchlist domain hit | +3 |
| Unknown external IP in pihole+suricata | +2 |
| External DNS client (bypass) | +2 |
| Unknown rare domains | +1 |

| Score | Level | Action |
|-------|-------|--------|
| 0–1 | CLEAN | Nothing |
| 2–3 | LOW | Normal, review next day |
| 4 | MEDIUM | Telegram alert, run srep |
| 5+ | HIGH | Telegram alert, investigate now |
