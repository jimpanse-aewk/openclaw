# Integrations

How OpenClaw talks to the rest of the stack. Live-verified 2026-04-18.

## Channel layer

| Channel | Status | Routing | Auth |
|---|---|---|---|
| Telegram `@Clown_ha_bot` (id 8792388733) | enabled, live | supergroup `-1003941975878` → `ha-agent`; everything else → `main` | `TELEGRAM_BOT_TOKEN` via `secrets.env` |
| WhatsApp `+66656899706` | enabled, live (linked) | → `main` (allowlist) | pairing data in `~/.openclaw/credentials/whatsapp/default/` |

Telegram and WhatsApp both poll continuously. WhatsApp restarts on a
~35-minute health-monitor cycle (see `troubleshooting.md`).

## Model layer

Both active agents (`main`, `ha-agent`) call `anthropic/claude-haiku-4-5`.
`trading` inherits the default model but is unbound (parked). The
Haiku→Sonnet upgrade discussed in `HANDOVER.md` is pending a separate
session.

## Home Assistant

Indirect — OpenClaw doesn't call HA REST directly from the gateway process.
The `ha-agent` fires a nested SSH chain:

```
openclaw (gateway)
  └─ ha-agent turn (LLM)
      └─ ssh openclaw → ELK (key ~/.ssh/oced25519)
          └─ /home/jimpanse/soc-core/bin/socha <cmd>
              └─ HA REST @ http://192.168.86.15:8123 (HA_TOKEN in soc.conf)
```

Direct openclaw → HA SSH (`~/.ssh/openclaw_ha` → `laguna@192.168.86.15`,
add-on container `a0d7b954-ssh`) is reserved for shell and YAML edits of
`/config/packages/*.yaml` — the `ha` CLI is not available there.

## SOC stack

The `main` agent pulls pre-digested SOC data every 5 minutes via cron:

```
cron on openclaw:  */5 * * * * /home/clown/soc_sync.sh
   └─ ssh openclaw → ELK (key ~/.ssh/oced25519)
       └─ cat /home/jimpanse/scripts/reports/latest_soc_report.json
   └─ python3 digest → /home/clown/soc_digest.txt (200 tokens)

agent reads on demand:  cat /home/clown/soc_digest.txt
```

Full ELK flow (for reference):

```
Suricata (.86.4) ── eve.json ── Filebeat ── ES (.86.5:9200) ── Kibana
                                               │
                                               ├── soc_report.py (*/15m on ELK)
                                               │     └── latest_soc_report.json
                                               │
                                               └── Kibana dashboards (manual)
NetAlertX ARPSCAN (*/5m inside container on .86.11)
   └── /app/db/app.db ── new_device_alert.py (ELK) ── @Clown_ha_bot
```

Outbound SSH keys on `clown`:

| Key | Target | Used by |
|---|---|---|
| `~/.ssh/oced25519` | ELK `.86.5:22222` (jimpanse) | SOC cron, agent socha calls, soc_sync.sh |
| `~/.ssh/oc_to_suricata_ed25519` | Suricata `.86.4:22222` (jimpanse) | rule reloads, eve.json reads |
| `~/.ssh/openclaw_ha` | HA `.86.15:22222` (laguna) | `ha-agent` YAML edits + shell |
| `~/.ssh/openclaw_elk_ed25519` | (inbound — operator's key) | authorized on clown for operator SSH |

## Local scripts the bot uses

All in `/home/clown/scripts/` (mirrored to `scripts/` in this repo):

- `oc_scan.sh` — `sudo arp-scan` + known-MAC diff. Agent calls on `scan now`.
- `oc_identify.sh` — `sudo nmap -O -sV` wrapper.
- `oc_ports.sh` — `sudo nmap -sV` wrapper.
- `oc_block.sh` — `sudo nft add rule ... drop`. Requires confirmation per SOC safety policy.
- `start-openclaw.sh` — manual fallback launcher (sources secrets.env, execs the binary). Not used by systemd.

`sudo` rules for `clown` are not inspected in this repo — they live in
`/etc/sudoers.d/` on the host. Assume `arp-scan`, `nmap`, and `nft` are
permitted without password prompt.

## MCP servers

None. OpenClaw's gateway has no MCP integrations configured. MCP
servers attached to *Claude Code* (not the bot) live on operator
workstations; unrelated to this bot.

## Ports

| Port | Bind | Purpose |
|---|---|---|
| `22222` | `0.0.0.0` | sshd — operator access + inbound SOC hops from ELK |
| `127.0.0.1:18789` | loopback | OpenClaw gateway (HTTP + token auth) |
| `127.0.0.1:18791` | loopback | OpenClaw browser-control channel |
| `100.69.198.82:*` | Tailscale | ephemeral Tailscale TCP sockets |

Nothing else is publicly exposed. The gateway does not listen on the LAN or
Tailscale addresses; external access goes through Telegram / WhatsApp APIs
pulling from the bot.
