FINAL OPENCLAW ARCHITECTURE

Current live agent stack
ops_manager = infrastructure / home assistant / pihole / netalertx / suricata / elastic / tnas
trading = markets / catalysts / x-twitter sentiment / risk
mind = neuroscience-first thinking / psychology / philosophy
coding = scripts / debugging / implementation

Secrets
/home/clown/.config/openclaw/secrets.env

Systemd service
/home/clown/.config/systemd/user/openclaw.service

Executable
/home/clown/.npm-global/bin/openclaw

Gateway command
/home/clown/.npm-global/bin/openclaw gateway --force

Service control
systemctl --user status openclaw --no-pager
systemctl --user restart openclaw
journalctl --user -u openclaw -f --no-pager

Active agents
/home/clown/.openclaw/agents/coding/agent/system.md
/home/clown/.openclaw/agents/mind/agent/system.md
/home/clown/.openclaw/agents/ops_manager/agent/system.md
/home/clown/.openclaw/agents/trading/agent/system.md

Retired agents
/home/clown/.openclaw/agents_retired/main
/home/clown/.openclaw/agents_retired/boss

Canonical smart-home data
/home/clown/smarthome_canonical/ha_entities_clean.json
/home/clown/smarthome_canonical/ha_lights_clean.json
/home/clown/smarthome_canonical/ha_motion_sensors_clean.json
/home/clown/smarthome_canonical/smarthome_truth_table.yaml
/home/clown/smarthome_canonical/control_map_clean.json

Home Assistant motion package
/config/packages/hue_motion_v1.yaml

Architecture
YOU
├── ops_manager
├── trading
├── mind
└── coding

