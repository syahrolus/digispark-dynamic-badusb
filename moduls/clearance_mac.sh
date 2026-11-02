#!/bin/bash
# clearance_mac.sh - wipe execution traces, inherits H, P, AU, TH from init_mac.sh

# ── Shell history files ───────────────────────────────────
> ~/.zsh_history        2>/dev/null
> ~/.bash_history       2>/dev/null
> ~/.local/share/fish/fish_history 2>/dev/null
history -c             2>/dev/null

# ── DNS cache ─────────────────────────────────────────────
dscacheutil -flushcache                          2>/dev/null
killall -HUP mDNSResponder                       2>/dev/null

# ── Recent items ──────────────────────────────────────────
rm -rf ~/Library/Application\ Support/com.apple.sharedfilelist/ 2>/dev/null
osascript -e 'tell application "System Events" to delete every login item' 2>/dev/null

# ── Quarantine events (tracks downloaded files) ───────────
sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* \
    "DELETE FROM LSQuarantineEvent;" 2>/dev/null

# ── Terminal history / saved state ───────────────────────
rm -rf ~/Library/Saved\ Application\ State/com.apple.Terminal.savedState/ 2>/dev/null

# ── Temp files ────────────────────────────────────────────
rm -rf /tmp/tmp.* /tmp/*.sh                      2>/dev/null

# ── Unified log (requires admin) ─────────────────────────
log erase --all                                  2>/dev/null
