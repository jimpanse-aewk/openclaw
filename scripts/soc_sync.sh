#!/bin/bash
# Fetch full JSON
ssh -i /home/clown/.ssh/oced25519 -o StrictHostKeyChecking=no \
    -o ConnectTimeout=5 \
    jimpanse@192.168.86.5 \
    "cat /home/jimpanse/scripts/reports/latest_soc_report.json" \
    > /home/clown/latest_soc_report.json 2>/dev/null

# Pre-digest to tiny summary for agent
python3 << 'PYEOF'
import json
with open('/home/clown/latest_soc_report.json') as f:
    r = json.load(f)
a = r.get('alert_stats', {})
ph = r.get('pihole_api_stats', {})
lines = [
    f"generated:{r['generated_at_utc']}",
    f"risk:{r['risk_level']} score:{r['risk_score']}",
    f"breakdown:{';'.join(r.get('risk_breakdown',['none']))}",
    f"alerts real:{a.get('real',0)} noise:{a.get('noise',0)} suppressed:{a.get('suppressed',0)}",
    f"rare_domains:{len(r.get('rare_domains',[]))}",
    f"watchlist:{len(r.get('watchlist_hits',[]))}",
    f"new_devices:{len(r.get('new_devices',{}))}",
    f"pihole queries:{ph.get('total_queries',0)} blocked:{ph.get('blocked',0)} pct:{ph.get('percent_blocked',0)}%",
    f"top_real_alerts:{';'.join([x['signature'] for x in r.get('top_suricata_alerts',[]) if x['signature'] not in r.get('_suppressed_sigs',[]) and x['signature'] not in r.get('_noise_sigs',[])][:3]) or 'none'}",
    f"external_clients:{';'.join(r.get('external_clients',[])) or 'none'}",
]
with open('/home/clown/soc_digest.txt', 'w') as f:
    f.write('\n'.join(lines))
PYEOF
