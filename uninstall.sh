#!/usr/bin/env bash
# ==============================================================================
# XCDPI Uninstaller Script
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

echo -e "${YELLOW}[!] Uninstalling XCDPI...${RESET}"

# 1. Clean running ciadpi processes & iptables rules
echo -e "${CYAN} -> Cleaning active proxy processes and iptables rules...${RESET}"
sudo pkill -9 -f "ciadpi" 2>/dev/null || pkill -9 -f "ciadpi" 2>/dev/null || true
if command -v iptables &>/dev/null; then
    sudo iptables -t nat -D OUTPUT -p tcp -m multiport --dports 80,443 -m owner ! --uid-owner nobody -j REDIRECT --to-ports 1080 2>/dev/null || true
    sudo iptables -t nat -D OUTPUT -p tcp -m multiport --dports 80,443 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports 1080 2>/dev/null || true
fi

# Reset desktop system proxy if set
if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.system.proxy mode 'none' 2>/dev/null || true
fi
if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key "ProxyType" "0" 2>/dev/null || true
elif command -v kwriteconfig5 &>/dev/null; then
    kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "ProxyType" "0" 2>/dev/null || true
fi

# 2. Remove binary symlinks
LOCAL_BIN="$HOME/.local/bin/xcdpi"
if [ -L "$LOCAL_BIN" ] || [ -f "$LOCAL_BIN" ]; then
    echo -e "${CYAN} -> Removing '$LOCAL_BIN'...${RESET}"
    rm -f "$LOCAL_BIN"
fi

USR_LOCAL_BIN="/usr/local/bin/xcdpi"
if [ -L "$USR_LOCAL_BIN" ] || [ -f "$USR_LOCAL_BIN" ]; then
    echo -e "${CYAN} -> Removing '$USR_LOCAL_BIN'...${RESET}"
    sudo rm -f "$USR_LOCAL_BIN" 2>/dev/null || true
fi

# 3. Prompt user for user data folder removal
echo -e "\n${YELLOW}Remove user configuration directory (~/.xcdpi)? (y/n) [Default: y]:${RESET} "
read -rp "" del_choice
del_choice=${del_choice:-y}

if [[ "$del_choice" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.xcdpi"
    echo -e "${CYAN} -> Removed directory '$HOME/.xcdpi'.${RESET}"
fi

echo -e "\n${GREEN}${BOLD}[✓] XCDPI has been completely uninstalled from your system.${RESET}\n"
