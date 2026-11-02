#!/bin/bash
# custom_mac.sh - inherits H, P, AU, TH from init_mac.sh
# put your custom script here
# to send output back:
#   echo "$OUTPUT" | curl -s -X POST "http://$H:$P/store/custom" \
#        -H "Authorization: $AU" -H "Content-Type: text/plain" -H "X-Target: $TH" \
#        --data-binary @- >/dev/null 2>&1
