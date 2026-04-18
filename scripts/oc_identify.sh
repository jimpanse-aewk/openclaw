#!/bin/bash
IP="$1"
if [[ -z "$IP" ]]; then echo "Usage: oc_identify.sh <IP>"; exit 1; fi
echo "=== Identify $IP ==="
sudo nmap -O -sV --open -T4 "$IP" 2>/dev/null | grep -E "open|OS details|MAC|Device type|Running"
