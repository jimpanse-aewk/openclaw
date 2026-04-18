#!/bin/bash
IP="$1"
if [[ -z "$IP" ]]; then echo "Usage: oc_ports.sh <IP>"; exit 1; fi
echo "=== Open ports on $IP ==="
sudo nmap -sV --open -T4 "$IP" 2>/dev/null | grep -E "open|MAC"
