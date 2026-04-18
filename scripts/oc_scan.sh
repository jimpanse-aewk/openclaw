#!/bin/bash
KNOWN_MACS=(
  7c:d9:5c:9d:c9:1a 08:36:c9:29:fe:9b 2c:cf:67:d0:59:5b
  c8:5b:76:c5:1a:4b 7e:1d:ef:f9:86:b0 2c:cf:67:d0:4b:e4
  14:ac:60:ea:6e:bb 2c:cf:67:63:42:a1 2c:cf:67:f4:60:08
  e4:19:c1:71:ba:fc 6c:bf:b5:02:f5:64 d0:ad:08:71:10:c4
  b8:e9:37:3b:4e:2e 34:7e:5c:90:fb:85 54:2a:1b:c3:8f:2e
  90:48:6c:50:1f:ce b0:4a:39:4b:6e:a1 88:57:1d:77:fd:e1
  ec:b5:fa:18:60:ac ec:b5:fa:15:92:ac d0:c2:4e:14:14:c0
  40:a9:cf:f3:59:5b 08:3a:88:25:26:d8 08:3a:88:25:39:59
  08:3a:88:25:34:a2 08:3a:88:25:27:60 98:03:8e:7e:9d:bf
  e0:d3:62:98:09:32 62:d4:94:44:c1:4d 38:05:25:36:23:2c
  bc:ec:a0:1b:9f:d3 14:22:3b:5b:5b:19 b0:e4:d5:4e:5e:61
  cc:f4:11:92:a8:d0 14:22:3b:10:88:c0 18:7f:88:cd:5f:78
  6c:29:90:7b:69:46 6c:29:90:7b:67:68 58:b6:23:c1:7d:e2
  7c:c2:94:59:f1:aa 7c:c2:94:59:c7:ce 3c:6a:d2:f0:af:55
  3c:6a:d2:f0:e7:0b 3c:6a:d2:f0:df:8d 7c:c2:94:59:fe:6c
  2c:cf:67:d0:59:5c
)

LIVE=$(sudo arp-scan --ouifile=/usr/share/arp-scan/ieee-oui.txt -l --interface=enp1s0 2>/dev/null \
  | awk '/^192\.168\.86\.[0-9]/{print $1,$2,$3,$4,$5,$6}')

echo "=== Network scan $(date '+%H:%M:%S') ==="
NEW_COUNT=0
while IFS= read -r LINE; do
  IP=$(echo "$LINE" | awk '{print $1}')
  MAC=$(echo "$LINE" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
  VENDOR=$(echo "$LINE" | awk '{$1=$2=""; print $0}' | sed 's/^ *//')
  FOUND=0
  for K in "${KNOWN_MACS[@]}"; do
    [[ "$MAC" == "$K" ]] && FOUND=1 && break
  done
  if [[ $FOUND -eq 1 ]]; then
    echo "  OK   $IP  $MAC  $VENDOR"
  else
    echo "  !!!  NEW: $IP  $MAC  $VENDOR"
    NEW_COUNT=$((NEW_COUNT+1))
  fi
done <<< "$LIVE"

TOTAL=$(echo "$LIVE" | grep -c "^192")
echo ""
echo "Total: $TOTAL online | Unknown: $NEW_COUNT"
[[ $NEW_COUNT -gt 0 ]] && echo "ACTION: Run autonomous investigation chain on each !!! device"
