#!/usr/bin/env bash
#
# OpenClaw LXC Installer for Proxmox VE
# Powered by CLEO Task Management
#
# Run this ONE-LINER in Proxmox VE Shell:
#   bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)"
#
# Or with options:
#   bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)" -- --advanced
#

set -Eeuo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_VERSION="1.2.0"
FORK_REPO="https://github.com/kryptobaseddev/openclaw.git"

# Debian version configuration
# Debian 13 (Trixie) requires Proxmox VE 9.x with pve-container 6.0.10+
# For older Proxmox versions, uncomment Debian 12 lines below
DEBIAN_VERSION="13"
DEBIAN_TEMPLATE="debian-13-standard_13.1-2_amd64.tar.zst"
# For Debian 12 (broader compatibility):
# DEBIAN_VERSION="12"
# DEBIAN_TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"

# Terminal colors
YW='\033[33m'
BL='\033[36m'
RD='\033[01;31m'
GN='\033[1;32m'
CL='\033[m'
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
HOLD=" "

# Default settings
CT_TYPE=1
CT_ID=""
HN="openclaw"
DISK_SIZE="32"
CORE_COUNT="4"
RAM_SIZE="8192"
BRG="vmbr0"
NET="dhcp"
GATE=""
STORAGE=""
TEMPLATE_STORAGE=""
SSH="no"
VERB="no"
DOPPLER_TOKEN=""
ADVANCED="no"

# Logging
LOG_FILE="/tmp/openclaw-install-$$.log"

# =============================================================================
# Helpers
# =============================================================================

# Spinner for visual feedback
SPINNER_PID=""
spinner() {
    local chars="/-\|"
    local spin_i=0
    printf "\e[?25l"  # Hide cursor
    while true; do
        printf "\r \e[36m%s\e[0m" "${chars:spin_i++%${#chars}:1}"
        sleep 0.1
    done
}

msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}...   "
    spinner &
    SPINNER_PID=$!
}

msg_ok() {
    if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then
        kill $SPINNER_PID > /dev/null 2>&1
    fi
    printf "\e[?25h"  # Show cursor
    echo -e "\r ${CM} ${GN}$1${CL}                    "
}

msg_error() {
    if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then
        kill $SPINNER_PID > /dev/null 2>&1
    fi
    printf "\e[?25h"  # Show cursor
    echo -e "\r ${CROSS} ${RD}$1${CL}                    "
}

# Execute command with logging - shows output on failure
run_cmd() {
    local desc="$1"
    shift
    if ! "$@" >> "$LOG_FILE" 2>&1; then
        msg_error "$desc failed"
        echo -e "${RD}Last 20 lines of log:${CL}"
        tail -20 "$LOG_FILE"
        return 1
    fi
    return 0
}

# Execute command in container with logging
run_in_ct() {
    local desc="$1"
    shift
    if ! pct exec "${CT_ID}" -- bash -c "$*" >> "$LOG_FILE" 2>&1; then
        msg_error "$desc failed"
        echo -e "${RD}Last 20 lines of log:${CL}"
        tail -20 "$LOG_FILE"
        return 1
    fi
    return 0
}

header_info() {
    clear
    echo ""
    echo -e "${BL}╔════════════════════════════════════════════════════════╗${CL}"
    echo -e "${BL}║                                                        ║${CL}"
    echo -e "${BL}║${CL}   ___  ____  _____ _   _  ____ _        ___        __  ${BL}║${CL}"
    echo -e "${BL}║${CL}  / _ \|  _ \| ____| \ | |/ ___| |      / \ \      / /  ${BL}║${CL}"
    echo -e "${BL}║${CL} | | | | |_) |  _| |  \| | |   | |     / _ \ \ /\ / /   ${BL}║${CL}"
    echo -e "${BL}║${CL} | |_| |  __/| |___| |\  | |___| |___ / ___ \ V  V /    ${BL}║${CL}"
    echo -e "${BL}║${CL}  \___/|_|   |_____|_| \_|\____|_____/_/   \_\_/\_/     ${BL}║${CL}"
    echo -e "${BL}║                                                        ║${CL}"
    echo -e "${BL}║${CL}                    ${YW}powered by${CL}                          ${BL}║${CL}"
    echo -e "${BL}║                                                        ║${CL}"
    echo -e "${BL}║${CL}            ${GN}___ _    ___ ___${CL}                            ${BL}║${CL}"
    echo -e "${BL}║${CL}           ${GN}/ __| |  | __/ _ \\${CL}                           ${BL}║${CL}"
    echo -e "${BL}║${CL}          ${GN}| (__| |__| _| (_) |${CL}                          ${BL}║${CL}"
    echo -e "${BL}║${CL}           ${GN}\___|____|___\___/${CL}                           ${BL}║${CL}"
    echo -e "${BL}║                                                        ║${CL}"
    echo -e "${BL}║${CL}        LXC Installer v${SCRIPT_VERSION} for Proxmox VE            ${BL}║${CL}"
    echo -e "${BL}╚════════════════════════════════════════════════════════╝${CL}"
    echo ""
}

cleanup() {
    popd >/dev/null 2>&1 || true
}
trap cleanup EXIT

error_handler() {
    local exit_code="$?"
    local line_no="$1"
    msg_error "Error on line ${line_no}: exit code ${exit_code}"
    exit "${exit_code}"
}
trap 'error_handler ${LINENO}' ERR

# =============================================================================
# Checks
# =============================================================================

check_proxmox() {
    if ! command -v pveversion &>/dev/null; then
        msg_error "This script must be run on a Proxmox VE host"
        exit 1
    fi
    local ver
    ver=$(pveversion | grep "pve-manager" | cut -d'/' -f2 | cut -d'-' -f1)
    msg_ok "Proxmox VE ${ver} detected"
}

get_next_ctid() {
    local ctid=100
    while pct status "$ctid" &>/dev/null; do
        ((ctid++))
    done
    echo "$ctid"
}

check_template() {
    # Auto-detect template storage if not set
    if [[ -z "$TEMPLATE_STORAGE" ]]; then
        TEMPLATE_STORAGE=$(auto_select_template_storage)
    fi

    if pveam list "$TEMPLATE_STORAGE" 2>/dev/null | grep -q "$DEBIAN_TEMPLATE"; then
        msg_ok "Template available: ${DEBIAN_TEMPLATE}"
        return 0
    fi
    msg_info "Downloading Debian ${DEBIAN_VERSION} template"
    pveam update >/dev/null 2>&1 || true
    if ! pveam download "$TEMPLATE_STORAGE" "$DEBIAN_TEMPLATE"; then
        msg_error "Failed to download template"
        echo "Try manually: pveam download ${TEMPLATE_STORAGE} ${DEBIAN_TEMPLATE}"
        exit 1
    fi
    msg_ok "Template downloaded"
}

check_storage() {
    if [[ -z "$STORAGE" ]]; then
        return 0  # Will be selected in settings
    fi
    if ! pvesm status -storage "$STORAGE" &>/dev/null; then
        msg_error "Storage '$STORAGE' not found"
        echo "Available storage:"
        pvesm status | tail -n +2 | awk '{print "  - " $1}'
        exit 1
    fi
}

# Get available storages that support rootdir (for containers)
get_available_storages() {
    pvesm status 2>/dev/null | tail -n +2 | awk '$2 == "active" {print $1}'
}

# Get available bridges
get_available_bridges() {
    ip -o link show type bridge 2>/dev/null | awk -F': ' '{print $2}' | sort
}

# Auto-select best storage for containers
auto_select_storage() {
    local storages
    storages=$(get_available_storages)

    # Prefer local-lvm, then local-zfs, then first available
    for preferred in "local-lvm" "local-zfs" "local"; do
        if echo "$storages" | grep -qx "$preferred"; then
            echo "$preferred"
            return
        fi
    done

    # Return first available
    echo "$storages" | head -1
}

# Auto-select template storage (prefer local)
auto_select_template_storage() {
    local storages
    storages=$(get_available_storages)

    for preferred in "local" "local-lvm"; do
        if echo "$storages" | grep -qx "$preferred"; then
            echo "$preferred"
            return
        fi
    done

    echo "$storages" | head -1
}

# Interactive storage selection
select_storage() {
    local storages storage_array
    storages=$(get_available_storages)

    if [[ -z "$storages" ]]; then
        msg_error "No active storage found"
        exit 1
    fi

    echo -e "\n${YW}Available Storage:${CL}"
    local i=1
    while IFS= read -r storage; do
        local size_info
        size_info=$(pvesm status -storage "$storage" 2>/dev/null | tail -1 | awk '{printf "%.1fGB free", $5/1024/1024}')
        echo -e "  ${GN}${i})${CL} ${storage} (${size_info})"
        storage_array[i]="$storage"
        ((i++))
    done <<< "$storages"

    echo ""
    local default_storage
    default_storage=$(auto_select_storage)
    read -r -p "Select storage [${default_storage}]: " choice

    if [[ -z "$choice" ]]; then
        STORAGE="$default_storage"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ -n "${storage_array[$choice]}" ]]; then
        STORAGE="${storage_array[$choice]}"
    else
        STORAGE="$choice"
    fi

    # Verify selection
    if ! pvesm status -storage "$STORAGE" &>/dev/null; then
        msg_error "Invalid storage: $STORAGE"
        exit 1
    fi
}

# Interactive bridge selection
select_bridge() {
    local bridges bridge_array
    bridges=$(get_available_bridges)

    if [[ -z "$bridges" ]]; then
        BRG="vmbr0"
        return
    fi

    echo -e "\n${YW}Available Network Bridges:${CL}"
    local i=1
    while IFS= read -r bridge; do
        echo -e "  ${GN}${i})${CL} ${bridge}"
        bridge_array[i]="$bridge"
        ((i++))
    done <<< "$bridges"

    echo ""
    read -r -p "Select bridge [vmbr0]: " choice

    if [[ -z "$choice" ]]; then
        BRG="vmbr0"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ -n "${bridge_array[$choice]}" ]]; then
        BRG="${bridge_array[$choice]}"
    else
        BRG="$choice"
    fi
}

# Interactive CTID selection with auto-detection
select_ctid() {
    local next_id existing_ids
    next_id=$(get_next_ctid)
    existing_ids=$(pct list 2>/dev/null | tail -n +2 | awk '{print $1}' | sort -n | tr '\n' ' ')

    echo -e "\n${YW}Container ID Selection:${CL}"
    echo -e "  Next available: ${GN}${next_id}${CL}"
    if [[ -n "$existing_ids" ]]; then
        echo -e "  Existing IDs: ${existing_ids}"
    fi
    echo ""
    read -r -p "Container ID [${next_id}]: " choice

    if [[ -z "$choice" ]]; then
        CT_ID="$next_id"
    else
        CT_ID="$choice"
    fi

    # Verify not in use
    if pct status "$CT_ID" &>/dev/null; then
        msg_error "Container ID ${CT_ID} is already in use"
        select_ctid  # Recursive retry
    fi
}

# =============================================================================
# Settings
# =============================================================================

default_settings() {
    echo ""
    echo -e "${YW}Quick Setup Mode${CL} - Use ${BL}--advanced${CL} for more options"
    echo ""

    # Auto-detect settings
    CT_ID=$(get_next_ctid)
    STORAGE=$(auto_select_storage)
    TEMPLATE_STORAGE=$(auto_select_template_storage)
    BRG="vmbr0"

    # Show what we detected
    echo -e "  ${YW}Container ID:${CL}  ${GN}${CT_ID}${CL} (next available)"
    echo -e "  ${YW}Hostname:${CL}      ${HN}"
    echo -e "  ${YW}Storage:${CL}       ${STORAGE}"
    echo -e "  ${YW}Disk Size:${CL}     ${DISK_SIZE}GB"
    echo -e "  ${YW}CPU Cores:${CL}     ${CORE_COUNT}"
    echo -e "  ${YW}RAM:${CL}           ${RAM_SIZE}MB"
    echo -e "  ${YW}Bridge:${CL}        ${BRG}"
    echo -e "  ${YW}Network:${CL}       DHCP"
    echo ""

    # Quick customization option
    read -r -p "Customize these settings? [y/N]: " customize
    if [[ "${customize,,}" == "y" ]]; then
        echo ""
        select_ctid
        select_storage
        TEMPLATE_STORAGE=$(auto_select_template_storage)

        read -r -p "Hostname [${HN}]: " input
        HN="${input:-$HN}"

        read -r -p "Enable SSH? [y/N]: " ssh_choice
        [[ "${ssh_choice,,}" == "y" ]] && SSH="yes"
    fi

    echo ""
    msg_ok "Settings configured"
}

advanced_settings() {
    echo -e "${YW}Advanced Settings${CL}"
    echo ""

    # Container ID with smart selection
    select_ctid

    read -r -p "Hostname [${HN}]: " input
    HN="${input:-$HN}"

    # Storage with interactive selection
    select_storage
    TEMPLATE_STORAGE=$(auto_select_template_storage)

    read -r -p "Disk Size GB [${DISK_SIZE}]: " input
    DISK_SIZE="${input:-$DISK_SIZE}"

    read -r -p "CPU Cores [${CORE_COUNT}]: " input
    CORE_COUNT="${input:-$CORE_COUNT}"

    read -r -p "RAM MB [${RAM_SIZE}]: " input
    RAM_SIZE="${input:-$RAM_SIZE}"

    # Bridge with interactive selection
    select_bridge

    echo ""
    echo -e "${YW}Network Configuration${CL}"
    read -r -p "Static IP (empty=DHCP): " NET
    NET="${NET:-dhcp}"

    if [[ "$NET" != "dhcp" ]]; then
        read -r -p "Gateway IP: " GATE
    fi

    echo ""
    echo -e "${YW}Optional Features${CL}"
    echo -e "  ${BL}Note:${CL} Doppler auth requires manual 'doppler login' after install"
    read -r -p "Enable SSH? [y/N]: " ssh_choice
    [[ "${ssh_choice,,}" == "y" ]] && SSH="yes"

    echo ""
    msg_ok "Settings configured"
}

# =============================================================================
# Container Creation
# =============================================================================

create_container() {
    msg_info "Creating LXC Container ${CT_ID}"

    local template="${TEMPLATE_STORAGE}:vztmpl/${DEBIAN_TEMPLATE}"
    local net_config

    if [[ "$NET" == "dhcp" ]]; then
        net_config="name=eth0,bridge=${BRG},ip=dhcp"
    else
        net_config="name=eth0,bridge=${BRG},ip=${NET}/24,gw=${GATE}"
    fi

    # Run pct create with visible output for debugging
    if ! pct create "${CT_ID}" "${template}" \
        --hostname "${HN}" \
        --cores "${CORE_COUNT}" \
        --memory "${RAM_SIZE}" \
        --swap 2048 \
        --rootfs "${STORAGE}:${DISK_SIZE}" \
        --unprivileged "${CT_TYPE}" \
        --features "nesting=1" \
        --onboot 1 \
        --net0 "${net_config}"; then
        msg_error "Failed to create container"
        echo ""
        echo "Debug info:"
        echo "  Template: ${template}"
        echo "  Storage: ${STORAGE}"
        echo "  Network: ${net_config}"
        exit 1
    fi

    msg_ok "Container ${CT_ID} created"
}

start_container() {
    msg_info "Starting Container"
    if ! pct start "${CT_ID}"; then
        msg_error "Failed to start container"
        exit 1
    fi
    sleep 3
    msg_ok "Container started"
}

wait_for_network() {
    msg_info "Waiting for network"
    local max=30
    local i=0
    while ! pct exec "${CT_ID}" -- ping -c1 -W2 google.com &>/dev/null; do
        ((i++))
        if [[ $i -ge $max ]]; then
            msg_error "Network timeout after ${max} attempts"
            echo "Try: pct exec ${CT_ID} -- cat /etc/network/interfaces"
            exit 1
        fi
        sleep 2
    done
    msg_ok "Network ready"
}

# =============================================================================
# Setup Inside Container
# =============================================================================

setup_base() {
    msg_info "Updating system"
    if ! run_in_ct "System update" "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"; then
        exit 1
    fi
    msg_ok "System updated"

    msg_info "Installing base packages"
    if ! run_in_ct "Base packages" "DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget git ca-certificates gnupg lsb-release jq socat build-essential"; then
        exit 1
    fi
    msg_ok "Base packages installed"
}

setup_nodejs() {
    msg_info "Installing Node.js 24"
    if ! run_in_ct "Node.js setup" "curl -fsSL https://deb.nodesource.com/setup_24.x | bash -"; then
        exit 1
    fi
    if ! run_in_ct "Node.js install" "DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs"; then
        exit 1
    fi
    # Enable corepack with auto-download (no prompts)
    if ! run_in_ct "pnpm setup" "COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack enable && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack prepare pnpm@latest --activate"; then
        exit 1
    fi
    msg_ok "Node.js 24 installed"
}

setup_docker() {
    msg_info "Installing Docker"
    if ! run_in_ct "Docker setup" '
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl enable docker
        systemctl start docker
    '; then
        exit 1
    fi
    msg_ok "Docker installed"
}

setup_github_cli() {
    msg_info "Installing GitHub CLI"
    if ! run_in_ct "GitHub CLI" '
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y gh
    '; then
        exit 1
    fi
    msg_ok "GitHub CLI installed"
}

setup_doppler() {
    msg_info "Installing Doppler CLI"
    if ! run_in_ct "Doppler CLI" '
        DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https
        curl -sLf --retry 3 --tlsv1.2 --proto "=https" "https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key" | gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" > /etc/apt/sources.list.d/doppler-cli.list
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y doppler
    '; then
        exit 1
    fi
    msg_ok "Doppler CLI installed"

    # Create Doppler setup helper script
    msg_info "Creating Doppler setup helper"
    pct exec "${CT_ID}" -- bash -c 'cat > /usr/local/bin/setup-doppler << "SCRIPT"
#!/bin/bash
# OpenClaw Doppler Configuration Helper
# Usage: setup-doppler dp.st.prd.xxxxxxxxxxxx

set -e

if [[ -z "$1" ]]; then
    echo "Usage: setup-doppler <doppler-service-token>"
    echo ""
    echo "To get a token:"
    echo "  1. Go to https://dashboard.doppler.com"
    echo "  2. Select your project and config (e.g., openclaw/prd)"
    echo "  3. Click Access > Generate Service Token"
    echo "  4. Copy the token (starts with dp.st.)"
    exit 1
fi

TOKEN="$1"

# Validate format
if [[ ! "$TOKEN" =~ ^dp\.st\.[a-z]+\.[A-Za-z0-9]+$ ]]; then
    echo "Error: Invalid token format"
    echo "Expected: dp.st.{env}.{token}"
    echo "Example:  dp.st.prd.xxxxxxxxxxxx"
    exit 1
fi

# Configure token (prevent history leakage)
export HISTIGNORE="doppler*:echo*:printf*"
printf "%s" "$TOKEN" | doppler configure set token --scope /opt/openclaw

# Verify
echo ""
echo "Verifying configuration..."
if doppler secrets --only-names --scope /opt/openclaw >/dev/null 2>&1; then
    echo "Success! Doppler is configured."
    echo ""
    echo "Available secrets:"
    doppler secrets --only-names --scope /opt/openclaw
    echo ""
    echo "To start OpenClaw:"
    echo "  cd /opt/openclaw && doppler run -- docker compose up -d"
else
    echo "Warning: Could not verify token. Please check:"
    echo "  - Token is valid and not expired"
    echo "  - Token has access to the correct project/config"
    echo "  - Network connectivity to Doppler API"
fi
SCRIPT
chmod +x /usr/local/bin/setup-doppler
'
    msg_ok "Doppler helper created: /usr/local/bin/setup-doppler"
}

setup_openclaw() {
    msg_info "Cloning OpenClaw fork (this may take a minute)"
    if ! run_in_ct "Git clone" "git clone --depth 1 ${FORK_REPO} /opt/openclaw"; then
        exit 1
    fi
    msg_ok "OpenClaw cloned"

    msg_info "Installing dependencies (this may take 2-3 minutes)"
    echo -e "  ${BL}Log: tail -f ${LOG_FILE}${CL}"
    if ! run_in_ct "pnpm install" "cd /opt/openclaw && pnpm install --reporter=append-only 2>&1"; then
        msg_error "Dependency installation failed"
        echo ""
        echo -e "${YW}Troubleshooting:${CL}"
        echo "  1. Check the log: tail -50 ${LOG_FILE}"
        echo "  2. Try manually: pct exec ${CT_ID} -- bash -c 'cd /opt/openclaw && pnpm install'"
        echo "  3. Check memory: pct exec ${CT_ID} -- free -h"
        exit 1
    fi
    msg_ok "Dependencies installed"

    msg_info "Building OpenClaw"
    if ! run_in_ct "pnpm build" "cd /opt/openclaw && pnpm build 2>&1"; then
        msg_error "Build failed - check log: ${LOG_FILE}"
        exit 1
    fi
    msg_ok "OpenClaw built"

    msg_info "Building Docker image (this may take 3-5 minutes)"
    echo -e "  ${BL}Log: tail -f ${LOG_FILE}${CL}"
    if ! run_in_ct "Docker build" "cd /opt/openclaw && docker build -t openclaw:local . 2>&1"; then
        msg_error "Docker build failed - check log: ${LOG_FILE}"
        exit 1
    fi
    msg_ok "Docker image built"
}

setup_directories() {
    msg_info "Creating directories"
    pct exec "${CT_ID}" -- bash -c "
        mkdir -p /root/.openclaw/{config,workspace,memory,skills,credentials}
        chmod 700 /root/.openclaw
        chmod 700 /root/.openclaw/credentials
    "
    msg_ok "Directories created"
}

setup_ssh() {
    if [[ "$SSH" == "yes" ]]; then
        msg_info "Enabling SSH"
        if ! run_in_ct "SSH setup" '
            DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server
            sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
            systemctl enable ssh
            systemctl start ssh
        '; then
            msg_error "SSH setup failed"
            # Non-fatal, continue
        else
            msg_ok "SSH enabled"
        fi
    fi
}

# =============================================================================
# Completion
# =============================================================================

show_completion() {
    local ip_addr
    ip_addr=$(pct exec "${CT_ID}" -- hostname -I 2>/dev/null | awk '{print $1}')

    echo ""
    echo -e "${GN}╔═══════════════════════════════════════════════════════════════╗${CL}"
    echo -e "${GN}║              OpenClaw Installation Complete!                  ║${CL}"
    echo -e "${GN}╚═══════════════════════════════════════════════════════════════╝${CL}"
    echo ""
    echo -e "  ${YW}Container ID:${CL}  ${CT_ID}"
    echo -e "  ${YW}Hostname:${CL}      ${HN}"
    echo -e "  ${YW}IP Address:${CL}    ${ip_addr:-'Check: pct exec ${CT_ID} -- hostname -I'}"
    echo -e "  ${YW}Install Log:${CL}   ${LOG_FILE}"
    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${YW}Next Steps:${CL}"
    echo ""
    echo "  1. Enter the container:"
    echo -e "     ${GN}pct enter ${CT_ID}${CL}"
    echo ""
    echo "  2. Authenticate with Doppler (interactive login):"
    echo -e "     ${GN}doppler login${CL}"
    echo ""
    echo "  3. Configure Doppler project:"
    echo -e "     ${GN}doppler setup${CL}"
    echo "     (Select your project and config, e.g., 'openclaw' / 'prd')"
    echo ""
    echo "  4. Ensure these secrets exist in your Doppler project:"
    echo "     - ANTHROPIC_API_KEY (required)"
    echo "     - OPENCLAW_GATEWAY_TOKEN (generate: openssl rand -hex 32)"
    echo "     - TELEGRAM_BOT_TOKEN (optional)"
    echo "     - DISCORD_BOT_TOKEN (optional)"
    echo ""
    echo "  5. Start OpenClaw:"
    echo -e "     ${GN}cd /opt/openclaw && doppler run -- docker compose up -d${CL}"
    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${YW}NGINX Proxy Manager:${CL}"
    echo "  Domain: openclaw.yourdomain.com"
    echo "  Forward: ${ip_addr:-'<container-ip>'}:18789"
    echo "  Enable: Websockets, SSL"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Initialize log
    : > "$LOG_FILE"
    echo "OpenClaw Installer Log - $(date)" >> "$LOG_FILE"
    echo "======================================" >> "$LOG_FILE"

    header_info

    # Parse args
    while [[ $# -gt 0 ]]; do
        case $1 in
            --advanced) ADVANCED="yes"; shift ;;
            --storage) STORAGE="$2"; shift 2 ;;
            --verbose) VERB="yes"; shift ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --advanced     Interactive mode with all settings"
                echo "  --storage NAME Pre-select storage (e.g., local-lvm)"
                echo "  --verbose      Show detailed output"
                echo "  --help         Show this help"
                exit 0
                ;;
            *) shift ;;
        esac
    done

    check_proxmox
    check_storage  # Only validates if --storage was provided
    check_template

    if [[ "$ADVANCED" == "yes" ]]; then
        advanced_settings
    else
        default_settings
    fi

    echo ""
    read -r -p "Create OpenClaw LXC container? [Y/n]: " confirm
    if [[ "${confirm,,}" == "n" ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""

    create_container
    start_container
    wait_for_network

    setup_base
    setup_nodejs
    setup_docker
    setup_github_cli
    setup_doppler
    setup_openclaw
    setup_directories
    setup_ssh

    show_completion
}

main "$@"
