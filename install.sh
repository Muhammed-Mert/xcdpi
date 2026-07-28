#!/usr/bin/env bash
# ==============================================================================
# XCDPI Installer Script
# ==============================================================================

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'
DIM='\033[2m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCDPI_SRC="$SCRIPT_DIR/xcdpi.sh"

echo -e "${CYAN}[*] Installing XCDPI...${RESET}"

if [ ! -f "$XCDPI_SRC" ]; then
    echo -e "${YELLOW}[!] Error: xcdpi.sh not found!${RESET}"
    exit 1
fi

chmod +x "$XCDPI_SRC"

# Target directory (~/.local/bin)
TARGET_DIR="$HOME/.local/bin"
mkdir -p "$TARGET_DIR"

ln -sf "$XCDPI_SRC" "$TARGET_DIR/xcdpi"

echo -e "${GREEN}[✓] XCDPI installed successfully!${RESET}"
echo -e "${CYAN}    Path: $TARGET_DIR/xcdpi${RESET}"
echo -e "${YELLOW}    Usage: Run 'xcdpi' in your terminal.${RESET}"
echo -e "${DIM}    (Ensure ~/.local/bin is in your PATH. E.g., add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to ~/.bashrc)${RESET}\n"
