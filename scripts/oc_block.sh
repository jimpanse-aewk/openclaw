#!/bin/bash
IP="$1"
if [[ -z "$IP" ]]; then echo "Usage: oc_block.sh <IP>"; exit 1; fi
sudo nft add rule inet filter input ip saddr "$IP" drop
sudo nft add rule inet filter forward ip saddr "$IP" drop
echo "Blocked: $IP"
