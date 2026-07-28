#!/usr/bin/env bash
# ==============================================================================
# XCDPI - Linux Transparent DPI Bypass & Strategy Scanner Tool v0.1-beta
# Built in pair-programming collaboration with Antigravity AI (Google DeepMind)
# Open-source desynchronization utility for Linux systems
# ==============================================================================

set -o pipefail

# Directories & Configuration
XCDPI_DIR="$HOME/.xcdpi"
mkdir -p "$XCDPI_DIR"

WORKING_CONFIGS_FILE="$XCDPI_DIR/working_configs.txt"
LAST_CONFIG_FILE="$XCDPI_DIR/last_used.conf"
SCAN_LOG_FILE="$XCDPI_DIR/scan.log"

CIADPI_BIN=$(which ciadpi 2>/dev/null || echo "/usr/local/bin/ciadpi")
PROXY_PORT=1080
TEST_PORT=10899

# Global PID tracking for clean session teardown
PROXY_PID=""
TEST_PID=""
TRANSPARENT_ACTIVE=0

# UI Colors & Styles
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

get_local_ip() {
    local ip
    ip=$(ip -4 addr show scope global 2>/dev/null | grep -v 'vbox' | grep -v 'docker' | grep -v 'virbr' | grep inet | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
    if [ -z "$ip" ]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    echo "${ip:-127.0.0.1}"
}

ensure_port_free() {
    local port="$1"
    fuser -k "$port/tcp" 2>/dev/null || true
    sudo fuser -k "$port/tcp" 2>/dev/null || true
    pkill -9 -f "ciadpi" 2>/dev/null || true
    sudo pkill -9 -f "ciadpi" 2>/dev/null || true
    sleep 0.35
}

remove_iptables_rules() {
    if command -v iptables &>/dev/null; then
        echo -e "\r${DIM} -> Cleaning iptables transparent redirection rules...${RESET}"
        sudo iptables -t nat -D OUTPUT -p tcp -m multiport --dports 80,443 -m owner ! --uid-owner nobody -j REDIRECT --to-ports "$PROXY_PORT" 2>/dev/null || true
        sudo iptables -t nat -D OUTPUT -p tcp -m multiport --dports 80,443 -m owner ! --uid-owner 65534 -j REDIRECT --to-ports "$PROXY_PORT" 2>/dev/null || true
    fi
}

stop_dpi_session() {
    stty sane 2>/dev/null || true
    echo -e "\r${YELLOW}[!] Stopping XCDPI and restoring system network settings...${RESET}"
    remove_iptables_rules
    pkill -9 -f "ciadpi" 2>/dev/null || true
    sudo pkill -9 -f "ciadpi" 2>/dev/null || true
    echo -e "\r${GREEN}[✓] XCDPI successfully stopped. Your internet connection is back to normal.${RESET}"
}

# Cleanup handler on EXIT / SIGINT / SIGTERM
cleanup() {
    stty sane 2>/dev/null || true
    echo -e "\r\n${YELLOW}[!] Closing XCDPI, performing cleanup...${RESET}"
    
    # Remove iptables rules if active
    if [ "$TRANSPARENT_ACTIVE" -eq 1 ]; then
        remove_iptables_rules
    fi

    # Kill background proxy process
    if [ -n "$PROXY_PID" ] && kill -0 "$PROXY_PID" 2>/dev/null; then
        echo -e "\r${DIM} -> Terminating DPI proxy process (PID: $PROXY_PID)...${RESET}"
        sudo kill -9 "$PROXY_PID" 2>/dev/null || kill -9 "$PROXY_PID" 2>/dev/null || true
    fi

    # Kill test proxy process if running
    if [ -n "$TEST_PID" ] && kill -0 "$TEST_PID" 2>/dev/null; then
        kill -9 "$TEST_PID" 2>/dev/null || true
    fi

    # Clean temporary files
    rm -f /tmp/xcdpi_test.pid /tmp/xcdpi_main.pid /tmp/xcdpi_err.log 2>/dev/null

    echo -e "\r${GREEN}[✓] XCDPI stopped cleanly. Internet connection restored.${RESET}"
    exit 0
}

trap cleanup EXIT INT TERM

draw_banner() {
    stty sane 2>/dev/null || true
    clear
    echo -e "\r${CYAN}${BOLD}"
    echo -e "\r  ██╗  ██╗  ██████╗██████╗ ██████╗ ██╗"
    echo -e "\r  ╚██╗██╔╝ ██╔════╝██╔══██╗██╔══██╗██║"
    echo -e "\r   ╚███╔╝  ██║     ██║  ██║██████╔╝██║"
    echo -e "\r   ██╔██╗  ██║     ██║  ██║██╔═══╝ ██║"
    echo -e "\r  ██╔╝ ██╗ ╚██████╗██████╔╝██║     ██║"
    echo -e "\r  ╚═╝  ╚═╝  ╚═════╝╚═════╝ ╚═╝     ╚═╝"
    echo -e "\r${WHITE}  --- Linux Transparent DPI Bypass & Strategy Scanner v0.1-beta ---${RESET}"
    echo -e "\r${DIM}  Config Directory: ${XCDPI_DIR}${RESET}\n"
}

show_cli_help() {
    draw_banner
    echo -e "\r${WHITE}${BOLD}Usage:${RESET} xcdpi [OPTIONS]"
    echo -e "\r"
    echo -e "\r${WHITE}${BOLD}Options:${RESET}"
    echo -e "\r  ${CYAN}-y, --start, --auto, start${RESET}    Automatically connect with last working strategy (Non-interactive)"
    echo -e "\r  ${CYAN}-k, --stop, stop${RESET}             Stop active XCDPI session and restore network"
    echo -e "\r  ${CYAN}-d, --domain <domain>${RESET}         Scan 35+ strategies for specified domain and connect"
    echo -e "\r  ${CYAN}-s, --scan${RESET}                   Launch strategy scanner"
    echo -e "\r  ${CYAN}-u, --update${RESET}                 Update XCDPI to latest version"
    echo -e "\r  ${RED}--uninstall${RESET}                  Uninstall XCDPI from system"
    echo -e "\r  ${CYAN}-h, --help${RESET}                   Show this help message"
    echo -e "\r"
    echo -e "\r${WHITE}${BOLD}Examples:${RESET}"
    echo -e "\r  ${YELLOW}xcdpi -y${RESET}                      --> Connects instantly using last working strategy"
    echo -e "\r  ${YELLOW}xcdpi --stop${RESET}                  --> Stops running DPI bypass session"
    echo -e "\r  ${YELLOW}xcdpi -d instagram.com${RESET}        --> Scans strategies for instagram.com and connects"
    echo -e "\r  ${YELLOW}xcdpi${RESET}                         --> Launches interactive CLI menu\n"
}

check_dependencies() {
    if ! command -v curl &>/dev/null; then
        echo -e "\r${RED}[✗] Error: 'curl' binary not found! Please install it (e.g. sudo apt install curl).${RESET}"
        exit 1
    fi

    if [ ! -x "$CIADPI_BIN" ]; then
        echo -e "\r${RED}[✗] Error: 'ciadpi' binary not found!${RESET}"
        echo -e "\r${CYAN}[i] Please ensure ciadpi binary is installed in system PATH or /usr/local/bin/ciadpi.${RESET}"
        exit 1
    fi
}

is_installed_on_system() {
    if [ -f "$HOME/.local/bin/xcdpi" ] || [ -f "/usr/local/bin/xcdpi" ]; then
        return 0
    else
        return 1
    fi
}

# 35+ Universal Desynchronization Strategies
STRATEGIES=(
    # Category 1: TLS Record Split Desync
    "TLS Record Split (1+s)|-s 1+s -r 1+s"
    "Split SNI (Offset 1)|-s 1+s"
    "Split SNI (Offset 2)|-s 2+s"
    "Split Byte 1|-s 1"
    "Split Byte 2|-s 2"
    "Split Byte 3|-s 3"

    # Category 2: Disorder (Out-of-Order Packet Injection)
    "Disorder SNI (Offset 1)|-d 1+s"
    "Disorder SNI (Offset 2)|-d 2+s"
    "Disorder Byte 1|-d 1"
    "Disorder Byte 2|-d 2"

    # Category 3: Out-of-Bound (OOB / Disoob)
    "Disoob SNI (Offset 1)|-q 1+s"
    "Disoob SNI (Offset 2)|-q 2+s"
    "OOB Split SNI (Offset 1)|-o 1+s"
    "OOB Split SNI (Offset 2)|-o 2+s"

    # Category 4: Fake SNI + TTL Distance
    "Fake SNI (google.com) + TTL 1|-s 1+s -n www.google.com -t 1"
    "Fake SNI (google.com) + TTL 2|-s 1+s -n www.google.com -t 2"
    "Fake SNI (google.com) + TTL 3|-s 1+s -n www.google.com -t 3"
    "Fake SNI (google.com) + TTL 4|-s 1+s -n www.google.com -t 4"
    "Fake Packet SNI (google.com) + TTL 3|-f 1+s -n www.google.com -t 3"
    "Fake Packet SNI (bing.com) + TTL 3|-f 1+s -n www.bing.com -t 3"
    "Fake Packet SNI (cloudflare) + TTL 3|-f 1+s -n www.cloudflare.com -t 3"

    # Category 5: Multi-Combination Deep DPI Bypass
    "Split + Fake SNI + TTL 3|-s 1+s -f 1+s -n www.google.com -t 3"
    "Disorder + Fake SNI + TTL 3|-d 1+s -f 1+s -n www.google.com -t 3"
    "Disoob + Fake SNI + TTL 3|-q 1+s -f 1+s -n www.google.com -t 3"
    "OOB Split + Fake SNI + TTL 3|-o 1+s -f 1+s -n www.google.com -t 3"
    "Split SNI + Record Split + TTL 3|-s 1+s -r 1+s -t 3"
    "Disorder SNI + Record Split + TTL 3|-d 1+s -r 1+s -t 3"

    # Category 6: HTTP Header Desynchronization
    "Split SNI + Host Case Mix|-s 1+s -M hcsmix"
    "Disorder SNI + Host Case Mix|-d 1+s -M hcsmix"
    "Split Byte 1 + Host Space|-s 1 -M space"
    "Split Byte 1 + Host Tab|-s 1 -M tab"

    # Category 7: Heuristic Auto Mode
    "Auto Mode (Level 2)|-A t,r,s,n -L 2"
    "Auto Mode (Level 3)|-A t,r,s,n -L 3"
    "Auto Mode (Level 4)|-A t,r,s,n,o -L 4"
    "Auto Mode (Level 5 Deep)|-A t,r,s,n,o -L 5"
)

test_strategy() {
    local name="$1"
    local args="$2"
    local target="$3"

    $CIADPI_BIN -p $TEST_PORT $args &>/dev/null &
    TEST_PID=$!
    
    sleep 0.25

    local res1
    res1=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}" --max-time 2.5 --proxy "socks5h://127.0.0.1:$TEST_PORT" "https://$target" 2>/dev/null || echo "000:0")

    local code1=$(echo "$res1" | cut -d':' -f1)
    local time1=$(echo "$res1" | cut -d':' -f2)

    local is_ok=0
    if [[ "$code1" =~ ^(200|301|302|307|308|400|403|404)$ ]]; then
        is_ok=1
    fi

    if [[ "$target" == *"discord"* ]] && [ "$is_ok" -eq 1 ]; then
        local res2 res3 code2 code3
        res2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2.5 --proxy "socks5h://127.0.0.1:$TEST_PORT" "https://gateway.discord.gg" 2>/dev/null || echo "000")
        res3=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2.5 --proxy "socks5h://127.0.0.1:$TEST_PORT" "https://updates.discord.com/distributions/app/manifests/latest" 2>/dev/null || echo "000")

        code2=$(echo "$res2")
        code3=$(echo "$res3")

        if ! [[ "$code2" =~ ^(200|301|302|307|308|400|403|404)$ ]] || ! [[ "$code3" =~ ^(200|301|302|307|308|400|403|404)$ ]]; then
            is_ok=0
        fi
    fi

    if [ -n "$TEST_PID" ] && kill -0 "$TEST_PID" 2>/dev/null; then
        kill "$TEST_PID" 2>/dev/null
        wait "$TEST_PID" 2>/dev/null
    fi
    TEST_PID=""

    if [ "$is_ok" -eq 1 ]; then
        local ms
        ms=$(python3 -c "print(int(float('$time1') * 1000))" 2>/dev/null || echo "???")
        echo "SUCCESS|$code1|$ms"
    else
        echo "FAILED|$code1|0"
    fi
}

scan_strategies() {
    local target_domain="$1"

    echo -e "\r${YELLOW}[*] Target Host: https://${target_domain}${RESET}"
    echo -e "\r${YELLOW}[*] Testing 35+ DPI Desync Strategies (${#STRATEGIES[@]} strategies)...${RESET}\n"

    declare -a WORKING_STRATEGIES
    declare -a WORKING_NAMES
    declare -a WORKING_LATENCIES

    local count=1
    for item in "${STRATEGIES[@]}"; do
        local name="${item%%|*}"
        local args="${item#*|}"

        printf "\r  ${DIM}[%2d/%2d]${RESET} Testing: ${WHITE}%-40s${RESET} " "$count" "${#STRATEGIES[@]}" "$name"
        
        local test_out
        test_out=$(test_strategy "$name" "$args" "$target_domain")

        local status=$(echo "$test_out" | cut -d'|' -f1)
        local code=$(echo "$test_out" | cut -d'|' -f2)
        local ms=$(echo "$test_out" | cut -d'|' -f3)

        if [ "$status" == "SUCCESS" ]; then
            echo -e "${GREEN}[✓ WORKING]${RESET} (HTTP $code - ${ms}ms)"
            WORKING_STRATEGIES+=("$args")
            WORKING_NAMES+=("$name")
            WORKING_LATENCIES+=("$ms")
        else
            echo -e "${RED}[✗ FAILED]${RESET} (HTTP $code)"
        fi
        ((count++))
    done

    echo -e "\r\n----------------------------------------------------------------------"
    
    if [ ${#WORKING_STRATEGIES[@]} -eq 0 ]; then
        echo -e "\r${RED}${BOLD}[!] No strategy bypassed DPI filtering for ${target_domain}!${RESET}"
        echo -e "\r${YELLOW}[i] Recommendation: Check your network connection or try another target domain.${RESET}"
        read -rp "Press ENTER to continue..."
        return 1
    fi

    echo -e "\r${GREEN}${BOLD}[✓] Working DPI Desync Strategies Found (${#WORKING_STRATEGIES[@]} total):${RESET}\n"

    echo "# XCDPI Working Strategies - $(date '+%Y-%m-%d %H:%M:%S')" > "$WORKING_CONFIGS_FILE"
    echo "# Target Domain: $target_domain" >> "$WORKING_CONFIGS_FILE"
    echo "" >> "$WORKING_CONFIGS_FILE"

    for i in "${!WORKING_STRATEGIES[@]}"; do
        local n="${WORKING_NAMES[$i]}"
        local a="${WORKING_STRATEGIES[$i]}"
        local lat="${WORKING_LATENCIES[$i]}"
        printf "\r  ${CYAN}%2d)${RESET} ${WHITE}%-40s${RESET} ${GREEN}Latency: %4sms${RESET}\n" $((i+1)) "$n" "$lat"
        echo "[$((i+1))] $n | $a | ${lat}ms" >> "$WORKING_CONFIGS_FILE"
    done

    echo -e "\r\n${DIM}Results saved to ${WORKING_CONFIGS_FILE}${RESET}"

    # Auto mode selects strategy 1 if non-interactive mode
    if [ "$AUTO_SELECT_STRATEGY" == "1" ]; then
        choice=1
    else
        echo -e "\r\n${YELLOW}Select strategy number to use [Default: 1]:${RESET} "
        read -r choice
        if [[ -z "$choice" || ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#WORKING_STRATEGIES[@]} ]; then
            choice=1
        fi
    fi

    local selected_idx=$((choice-1))
    SELECTED_NAME="${WORKING_NAMES[$selected_idx]}"
    SELECTED_ARGS="${WORKING_STRATEGIES[$selected_idx]}"

    echo "$SELECTED_NAME|$SELECTED_ARGS" > "$LAST_CONFIG_FILE"

    return 0
}

start_dpi_session() {
    local name="$1"
    local args="$2"

    draw_banner

    echo -e "\r${YELLOW}[*] Verifying Sudo Privileges...${RESET}"
    sudo -v || { echo -e "\r${RED}[✗] Sudo authentication failed!${RESET}"; exit 1; }

    ensure_port_free "$PROXY_PORT"
    remove_iptables_rules

    local err_file="/tmp/xcdpi_err.log"
    rm -f "$err_file"

    # Start ciadpi transparent proxy daemon under user 'nobody'
    sudo -u nobody $CIADPI_BIN -i 0.0.0.0 -p $PROXY_PORT -E $args >/dev/null 2>"$err_file" &
    PROXY_PID=$!

    sleep 0.5

    if ! kill -0 "$PROXY_PID" 2>/dev/null; then
        echo -e "\r${RED}[✗] Error: Failed to launch ciadpi transparent proxy daemon!${RESET}"
        if [ -s "$err_file" ]; then
            echo -e "\r${RED}    Daemon Log: $(cat "$err_file")${RESET}"
        fi
        exit 1
    fi

    # Add iptables REDIRECT rule for TCP ports 80 & 443 excluding user 'nobody'
    sudo iptables -t nat -A OUTPUT -p tcp -m multiport --dports 80,443 -m owner ! --uid-owner nobody -j REDIRECT --to-ports "$PROXY_PORT"
    TRANSPARENT_ACTIVE=1

    draw_banner
    echo -e "\r${GREEN}${BOLD}[✓] XCDPI TRANSPARENT DPI BYPASS ACTIVE!${RESET}\n"
    echo -e "\r  • Strategy : ${CYAN}${name}${RESET}"
    echo -e "\r  • Scope    : ${GREEN}SYSTEM-WIDE (Discord, Spotify, Web Browsers, Apps)${RESET}"
    echo -e "\r  • Method   : ${YELLOW}iptables Transparent Port Redirection (ports 80, 443)${RESET}\n"
    echo -e "\r${GREEN}[i] No browser or proxy configuration is required on your computer.${RESET}"
    echo -e "\r${GREEN}    All system applications are now routing through DPI desynchronization.${RESET}\n"

    echo -e "\r======================================================================"
    echo -e "\r${YELLOW}${BOLD}[!] XCDPI Running... Press [Ctrl+C] or run 'xcdpi --stop' to terminate.${RESET}"
    echo -e "\r${DIM}System network rules and background daemons will clean up on exit.${RESET}"
    echo -e "\r======================================================================\n"

    while true; do
        if ! kill -0 "$PROXY_PID" 2>/dev/null; then
            echo -e "\r${RED}[!] Proxy daemon stopped unexpectedly!${RESET}"
            break
        fi
        sleep 2
    done
}

run_uninstaller() {
    local uninstall_script="$(dirname "${BASH_SOURCE[0]}")/uninstall.sh"
    if [ -f "$uninstall_script" ]; then
        bash "$uninstall_script"
    else
        echo -e "\r${RED}[✗] Error: uninstall.sh not found!${RESET}"
    fi
}

update_xcdpi() {
    draw_banner
    echo -e "\r${YELLOW}[*] Updating XCDPI...${RESET}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -d "$script_dir/.git" ] && command -v git &>/dev/null; then
        echo -e "\r${CYAN} -> Fetching latest commits from repository...${RESET}"
        git -C "$script_dir" pull || true
    fi

    chmod +x "$script_dir/xcdpi.sh" "$script_dir/install.sh" "$script_dir/uninstall.sh" 2>/dev/null || true

    if is_installed_on_system; then
        echo -e "\r${CYAN} -> Re-linking system command binaries...${RESET}"
        bash "$script_dir/install.sh" >/dev/null 2>&1 || true
    fi

    echo -e "\r${GREEN}${BOLD}[✓] XCDPI updated successfully!${RESET}"
    echo -e "\r${DIM}Your saved working strategies (~/.xcdpi) remain intact.${RESET}\n"
    read -rp "Press ENTER to continue..."
}

main() {
    # Parse Command Line Flags
    case "$1" in
        -y|--start|--auto|start)
            check_dependencies
            if [ -f "$LAST_CONFIG_FILE" ]; then
                local last_name=$(cut -d'|' -f1 "$LAST_CONFIG_FILE")
                local last_args=$(cut -d'|' -f2 "$LAST_CONFIG_FILE")
                start_dpi_session "$last_name" "$last_args"
            else
                AUTO_SELECT_STRATEGY=1
                scan_strategies "discord.com"
                if [ $? -eq 0 ]; then
                    start_dpi_session "$SELECTED_NAME" "$SELECTED_ARGS"
                fi
            fi
            exit 0
            ;;
        -k|--stop|stop)
            stop_dpi_session
            exit 0
            ;;
        -d|--domain)
            check_dependencies
            local target_domain=$(echo "$2" | sed -e 's|^https://||' -e 's|^http://||' -e 's|/.*$||')
            target_domain=${target_domain:-discord.com}
            AUTO_SELECT_STRATEGY=1
            scan_strategies "$target_domain"
            if [ $? -eq 0 ]; then
                start_dpi_session "$SELECTED_NAME" "$SELECTED_ARGS"
            fi
            exit 0
            ;;
        -s|--scan)
            check_dependencies
            scan_strategies "${2:-discord.com}"
            if [ $? -eq 0 ]; then
                start_dpi_session "$SELECTED_NAME" "$SELECTED_ARGS"
            fi
            exit 0
            ;;
        -u|--update|update)
            update_xcdpi
            exit 0
            ;;
        --uninstall)
            run_uninstaller
            exit 0
            ;;
        -h|--help|help)
            show_cli_help
            exit 0
            ;;
    esac

    draw_banner
    check_dependencies

    local has_scan=0
    local last_strategy_name=""
    local last_strategy_args=""

    if [ -f "$LAST_CONFIG_FILE" ]; then
        last_strategy_name=$(cut -d'|' -f1 "$LAST_CONFIG_FILE" 2>/dev/null)
        last_strategy_args=$(cut -d'|' -f2 "$LAST_CONFIG_FILE" 2>/dev/null)
        if [ -n "$last_strategy_name" ]; then
            has_scan=1
        fi
    fi

    echo -e "\r${WHITE}${BOLD}XCDPI Menu:${RESET}"
    
    if [ "$has_scan" -eq 1 ]; then
        echo -e "\r  ${CYAN}1)${RESET} Connect with Last Working Strategy (${WHITE}${last_strategy_name}${RESET})"
        echo -e "\r  ${CYAN}2)${RESET} Scan 35+ DPI Desync Strategies & Connect"
    else
        echo -e "\r  ${CYAN}1)${RESET} Scan 35+ DPI Desync Strategies & Connect"
    fi

    if is_installed_on_system; then
        echo -e "\r  ${RED}3)${RESET} Uninstall XCDPI"
    fi

    echo -e "\r  ${YELLOW}u)${RESET} Update XCDPI"
    echo -e "\r  ${CYAN}q)${RESET} Quit\n"

    read -rp "Option [1]: " main_choice
    main_choice=${main_choice:-1}

    if [ "$has_scan" -eq 1 ]; then
        case "$main_choice" in
            1)
                start_dpi_session "$last_strategy_name" "$last_strategy_args"
                ;;
            2)
                echo -e "\r\n${YELLOW}Enter blocked domain to test:${RESET}"
                read -rp "Domain (e.g. discord.com, instagram.com) [Default: discord.com]: " target_input
                target_input=${target_input:-discord.com}
                target_domain=$(echo "$target_input" | sed -e 's|^https://||' -e 's|^http://||' -e 's|/.*$||')

                scan_strategies "$target_domain"
                if [ $? -eq 0 ]; then
                    start_dpi_session "$SELECTED_NAME" "$SELECTED_ARGS"
                fi
                ;;
            3)
                if is_installed_on_system; then
                    run_uninstaller
                    exit 0
                fi
                ;;
            u|U)
                update_xcdpi
                exec "$0" "$@"
                ;;
            q|Q)
                echo -e "\r${YELLOW}Exiting...${RESET}"
                exit 0
                ;;
        esac
    else
        case "$main_choice" in
            1)
                echo -e "\r\n${YELLOW}Enter blocked domain to test:${RESET}"
                read -rp "Domain (e.g. discord.com, instagram.com) [Default: discord.com]: " target_input
                target_input=${target_input:-discord.com}
                target_domain=$(echo "$target_input" | sed -e 's|^https://||' -e 's|^http://||' -e 's|/.*$||')

                scan_strategies "$target_domain"
                if [ $? -eq 0 ]; then
                    start_dpi_session "$SELECTED_NAME" "$SELECTED_ARGS"
                fi
                ;;
            3)
                if is_installed_on_system; then
                    run_uninstaller
                    exit 0
                fi
                ;;
            u|U)
                update_xcdpi
                exec "$0" "$@"
                ;;
            q|Q)
                echo -e "\r${YELLOW}Exiting...${RESET}"
                exit 0
                ;;
        esac
    fi
}

main "$@"
