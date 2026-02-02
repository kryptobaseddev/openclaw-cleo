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

SCRIPT_VERSION="1.4.2"
FORK_REPO="https://github.com/kryptobaseddev/openclaw.git"

# Debian version - auto-detected based on Proxmox version
# Debian 13 requires PVE 9.x, Debian 12 for PVE 8.x
DEBIAN_VERSION=""
DEBIAN_TEMPLATE=""

detect_debian_version() {
    local pve_major
    pve_major=$(pveversion | grep -oP 'pve-manager/\K[0-9]+' | head -1)

    if [[ "$pve_major" -ge 9 ]]; then
        DEBIAN_VERSION="13"
        DEBIAN_TEMPLATE="debian-13-standard_13.1-2_amd64.tar.zst"
    else
        DEBIAN_VERSION="12"
        DEBIAN_TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
    fi
}

# Terminal colors (using $'...' for proper escape interpretation)
YW=$'\033[33m'
BL=$'\033[36m'
RD=$'\033[01;31m'
GN=$'\033[1;32m'
CL=$'\033[m'
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
HOLD=" "

# Default settings
# CT_TYPE: 0=privileged (required for Docker), 1=unprivileged
CT_TYPE=0
CT_ID=""
HN="openclaw"
PW=""
PW_GENERATED="no"
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
DOPPLER_MODE="manual"
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
    # Always set locale to prevent warnings in subsequent commands
    if ! pct exec "${CT_ID}" -- bash -c "export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; $*" >> "$LOG_FILE" 2>&1; then
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
    # Use Proxmox API to get next available ID (most reliable)
    local nextid
    nextid=$(pvesh get /cluster/nextid 2>/dev/null)

    if [[ -n "$nextid" && "$nextid" =~ ^[0-9]+$ ]]; then
        echo "$nextid"
        return
    fi

    # Fallback: scan existing containers/VMs
    local ctid=100
    while pct status "$ctid" &>/dev/null || qm status "$ctid" &>/dev/null; do
        ((ctid++))
    done
    echo "$ctid"
}

check_template() {
    # Auto-detect template storage if not set
    if [[ -z "$TEMPLATE_STORAGE" ]]; then
        TEMPLATE_STORAGE=$(auto_select_template_storage)
    fi

    # Validate we have a storage
    if [[ -z "$TEMPLATE_STORAGE" ]]; then
        msg_error "No template storage found"
        echo "Available storages:"
        pvesm status | tail -n +2 | awk '{print "  - " $1}'
        echo ""
        echo "Try: pveam download local ${DEBIAN_TEMPLATE}"
        exit 1
    fi

    msg_ok "Using Debian ${DEBIAN_VERSION} (${DEBIAN_TEMPLATE})"

    if pveam list "$TEMPLATE_STORAGE" 2>/dev/null | grep -q "$DEBIAN_TEMPLATE"; then
        msg_ok "Template available on ${TEMPLATE_STORAGE}"
        return 0
    fi

    msg_info "Downloading Debian ${DEBIAN_VERSION} template to ${TEMPLATE_STORAGE}"
    pveam update >/dev/null 2>&1 || true
    if ! pveam download "$TEMPLATE_STORAGE" "$DEBIAN_TEMPLATE"; then
        msg_error "Failed to download template"
        echo ""
        echo "Try manually: pveam download ${TEMPLATE_STORAGE} ${DEBIAN_TEMPLATE}"
        echo "Or check: pveam available | grep debian"
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
    # Get storages that support rootdir content (for containers)
    local storages
    storages=$(pvesm status -content rootdir 2>/dev/null | tail -n +2 | awk '{print $1}')

    # Fallback to all storages if none support rootdir
    if [[ -z "$storages" ]]; then
        storages=$(pvesm status 2>/dev/null | tail -n +2 | awk '{print $1}')
    fi

    echo "$storages"
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

# Auto-select template storage (must support vztmpl content)
auto_select_template_storage() {
    local storages

    # Get storages that support vztmpl (templates)
    storages=$(pvesm status -content vztmpl 2>/dev/null | tail -n +2 | awk '{print $1}')

    # If no vztmpl-capable storage, fall back to any storage
    if [[ -z "$storages" ]]; then
        storages=$(pvesm status 2>/dev/null | tail -n +2 | awk '{print $1}')
    fi

    # Prefer 'local' for templates
    for preferred in "local" "local-lvm"; do
        if echo "$storages" | grep -qx "$preferred"; then
            echo "$preferred"
            return
        fi
    done

    # Return first available
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

configure_password() {
    echo ""
    echo -e "${YW}Root Password Configuration${CL}"
    read -r -p "Set custom password? [y/N]: " custom_pw

    if [[ "${custom_pw,,}" == "y" ]]; then
        while true; do
            read -r -s -p "Enter root password: " pw1
            echo ""
            read -r -s -p "Confirm root password: " pw2
            echo ""

            if [[ -z "$pw1" ]]; then
                echo -e "${RD}Password cannot be empty${CL}"
                continue
            fi

            if [[ "$pw1" != "$pw2" ]]; then
                echo -e "${RD}Passwords do not match. Please try again.${CL}"
                continue
            fi

            PW="$pw1"
            PW_GENERATED="no"
            echo -e "${GN}Custom password set${CL}"
            break
        done
    else
        PW=$(openssl rand -base64 12)
        PW_GENERATED="yes"
        echo -e "${GN}Password will be auto-generated${CL}"
    fi
}

default_settings() {
    echo ""
    echo -e "${YW}Quick Setup Mode${CL} - Use ${BL}--advanced${CL} for more options"
    echo ""

    # Auto-detect settings
    CT_ID=$(get_next_ctid)
    STORAGE=$(auto_select_storage)
    TEMPLATE_STORAGE=$(auto_select_template_storage)
    BRG="vmbr0"

    # Generate secure random password for root
    PW=$(openssl rand -base64 12)
    PW_GENERATED="yes"

    # Fallback for storage if empty
    if [[ -z "$STORAGE" ]]; then
        STORAGE="local-lvm"
    fi

    # Show what we detected
    echo -e "  ${YW}Container ID:${CL}  ${GN}${CT_ID}${CL} (next available)"
    echo -e "  ${YW}Hostname:${CL}      ${HN}"
    echo -e "  ${YW}Storage:${CL}       ${STORAGE:-local-lvm}"
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

        read -r -p "Disk Size GB [${DISK_SIZE}]: " input
        DISK_SIZE="${input:-$DISK_SIZE}"

        read -r -p "CPU Cores [${CORE_COUNT}]: " input
        CORE_COUNT="${input:-$CORE_COUNT}"

        read -r -p "RAM MB [${RAM_SIZE}]: " input
        RAM_SIZE="${input:-$RAM_SIZE}"

        echo ""
        echo -e "${YW}Network Configuration${CL}"
        read -r -p "Static IP (empty=DHCP): " net_input
        NET="${net_input:-dhcp}"

        if [[ "$NET" != "dhcp" ]]; then
            read -r -p "Gateway IP: " GATE
        fi

        echo ""
        read -r -p "Enable SSH? [y/N]: " ssh_choice
        [[ "${ssh_choice,,}" == "y" ]] && SSH="yes"

        configure_password
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

    configure_password

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
        --password "${PW}" \
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

setup_locale_immediate() {
    msg_info "Configuring locales (CRITICAL: must be first)"
    # This runs IMMEDIATELY after container starts, before ANY other apt commands
    if ! pct exec "${CT_ID}" -- bash -c '
        # Update package lists without warnings
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq >/dev/null 2>&1

        # Install locales package
        apt-get install -y locales >/dev/null 2>&1

        # Enable en_US.UTF-8
        sed -i "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
        locale-gen en_US.UTF-8 >/dev/null 2>&1
        update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

        # Set for ALL sessions (PAM reads /etc/environment)
        echo "LANG=en_US.UTF-8" >> /etc/environment
        echo "LC_ALL=en_US.UTF-8" >> /etc/environment

        # Also set in bash.bashrc as backup for interactive shells
        echo "export LANG=en_US.UTF-8" >> /etc/bash.bashrc
        echo "export LC_ALL=en_US.UTF-8" >> /etc/bash.bashrc
    ' >> "$LOG_FILE" 2>&1; then
        msg_error "Locale setup failed (non-fatal)"
        # Non-fatal, continue
    else
        msg_ok "Locales configured"
    fi
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
    # Enable corepack and pre-cache pnpm (non-interactive)
    if ! run_in_ct "pnpm setup" 'export COREPACK_ENABLE_DOWNLOAD_PROMPT=0 && corepack enable && corepack install --global pnpm@latest'; then
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

    # Configure Doppler with service token if provided
    if [[ -n "$DOPPLER_TOKEN" ]]; then
        msg_info "Configuring Doppler with service token"
        if run_in_ct "Doppler configure" "printf '%s' '$DOPPLER_TOKEN' | doppler configure set token --scope /opt/openclaw"; then
            msg_ok "Doppler configured non-interactively"
            DOPPLER_MODE="token"
        else
            msg_error "Doppler token configuration failed - will require manual setup"
            DOPPLER_MODE="manual"
        fi
    fi

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
    if ! run_in_ct "pnpm install" "export COREPACK_ENABLE_DOWNLOAD_PROMPT=0 && cd /opt/openclaw && pnpm install --reporter=append-only 2>&1"; then
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
            sed -i "s/#PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
            sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
            systemctl enable ssh
            systemctl restart ssh
        '; then
            msg_error "SSH setup failed"
            # Non-fatal, continue
        else
            msg_ok "SSH enabled"
        fi
    fi
}

validate_installation() {
    msg_info "Validating installation"
    local validation_failed=0
    local checks_passed=0
    local total_checks=5

    # Check Docker
    if pct exec "${CT_ID}" -- docker --version &>/dev/null; then
        checks_passed=$((checks_passed + 1))
    else
        echo -e "\n  ${CROSS} Docker not responding"
        validation_failed=$((validation_failed + 1))
    fi

    # Check Node.js
    if pct exec "${CT_ID}" -- node --version &>/dev/null; then
        checks_passed=$((checks_passed + 1))
    else
        echo -e "\n  ${CROSS} Node.js not installed"
        validation_failed=$((validation_failed + 1))
    fi

    # Check pnpm
    if pct exec "${CT_ID}" -- pnpm --version &>/dev/null; then
        checks_passed=$((checks_passed + 1))
    else
        echo -e "\n  ${CROSS} pnpm not available"
        validation_failed=$((validation_failed + 1))
    fi

    # Check Docker image exists
    if pct exec "${CT_ID}" -- docker images openclaw:local --format "{{.Repository}}" | grep -q openclaw; then
        checks_passed=$((checks_passed + 1))
    else
        echo -e "\n  ${CROSS} Docker image 'openclaw:local' not found"
        validation_failed=$((validation_failed + 1))
    fi

    # Check OpenClaw directory
    if pct exec "${CT_ID}" -- test -d /opt/openclaw; then
        checks_passed=$((checks_passed + 1))
    else
        echo -e "\n  ${CROSS} OpenClaw directory missing"
        validation_failed=$((validation_failed + 1))
    fi

    # Check SSH if enabled
    if [[ "$SSH" == "yes" ]]; then
        total_checks=$((total_checks + 1))
        if pct exec "${CT_ID}" -- systemctl is-active ssh &>/dev/null; then
            checks_passed=$((checks_passed + 1))

            # Try SSH connectivity test
            local ip_addr
            ip_addr=$(pct exec "${CT_ID}" -- hostname -I 2>/dev/null | awk '{print $1}')
            if [[ -n "$ip_addr" ]]; then
                if timeout 3 nc -z "$ip_addr" 22 &>/dev/null; then
                    echo -e "  ${CM} SSH port 22 accessible on ${ip_addr}"
                else
                    echo -e "\n  ${YW}⚠${CL} SSH service active but port 22 not reachable from Proxmox host"
                    echo -e "    This is normal if firewall rules are in place"
                fi
            fi
        else
            echo -e "\n  ${CROSS} SSH service not active"
            validation_failed=$((validation_failed + 1))
        fi
    fi

    if [[ $validation_failed -eq 0 ]]; then
        msg_ok "All ${total_checks} validation checks passed"
    else
        msg_error "${validation_failed} of ${total_checks} validation checks failed"
        echo ""
        echo -e "${YW}Troubleshooting:${CL}"
        echo "  - Check installation log: ${LOG_FILE}"
        echo "  - Verify container is running: pct status ${CT_ID}"
        echo "  - Check container console: pct enter ${CT_ID}"
    fi
}

# =============================================================================
# Completion
# =============================================================================

show_completion() {
    local ip_addr
    ip_addr=$(pct exec "${CT_ID}" -- hostname -I 2>/dev/null | awk '{print $1}')

    # Generate a gateway token for the user
    local gateway_token
    gateway_token=$(openssl rand -hex 32)

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
    echo -e "${YW}Root Credentials:${CL}"
    echo -e "  ${YW}Username:${CL}      root"
    if [[ "$PW_GENERATED" == "yes" ]]; then
        echo -e "  ${YW}Password:${CL}      ${GN}${PW}${CL}"
        echo ""
        echo -e "  ${RD}IMPORTANT: Save this password now! It will not be shown again.${CL}"
    else
        echo -e "  ${YW}Password:${CL}      (your configured password)"
    fi
    echo ""

    if [[ "$SSH" == "yes" ]]; then
        echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
        echo ""
        echo -e "${YW}SSH Access:${CL}"
        echo -e "  ${GN}ssh root@${ip_addr}${CL}"
        echo ""
    fi

    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${RD}REQUIRED: Add these secrets to Doppler before starting OpenClaw${CL}"
    echo ""
    echo -e "  ${YW}ANTHROPIC_API_KEY${CL}        Your Anthropic API key (required)"
    echo -e "  ${YW}OPENCLAW_GATEWAY_TOKEN${CL}   ${GN}${gateway_token}${CL}"
    echo -e "  ${YW}OPENCLAW_CONFIG_DIR${CL}      /root/.openclaw"
    echo -e "  ${YW}OPENCLAW_WORKSPACE_DIR${CL}   /root/.openclaw/workspace"
    echo ""
    echo -e "  ${BL}Optional:${CL}"
    echo -e "  ${YW}TELEGRAM_BOT_TOKEN${CL}       For Telegram integration"
    echo -e "  ${YW}DISCORD_BOT_TOKEN${CL}        For Discord integration"
    echo ""
    echo -e "  ${RD}Copy the OPENCLAW_GATEWAY_TOKEN above - it won't be shown again!${CL}"
    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${YW}Setup Steps:${CL}"
    echo ""
    echo "  1. Enter the container:"
    echo -e "     ${GN}pct enter ${CT_ID}${CL}"
    echo ""

    if [[ "$DOPPLER_MODE" == "token" ]]; then
        echo "  2. Doppler is already configured with service token"
        echo ""
        echo "  3. Add the secrets above to your Doppler project"
        echo ""
        echo "  4. Start OpenClaw:"
        echo -e "     ${GN}cd /opt/openclaw${CL}"
        echo -e "     ${GN}doppler run -- docker compose up -d${CL}"
    else
        echo "  2. Configure Doppler (secrets manager):"
        echo ""
        echo "     Option A - Interactive login:"
        echo -e "       ${GN}cd /opt/openclaw${CL}"
        echo -e "       ${GN}doppler login${CL}"
        echo -e "       ${GN}doppler setup${CL}  # Select project: openclaw, config: prd"
        echo ""
        echo "     Option B - Service token (from /opt/openclaw directory):"
        echo -e "       ${GN}cd /opt/openclaw${CL}"
        echo -e "       ${GN}setup-doppler dp.st.prd.xxxxxxxxxxxx${CL}"
        echo "       (Get token from: doppler.com → Project → Access → Service Tokens)"
        echo ""
        echo "  3. Add the secrets listed above to your Doppler project"
        echo "     (doppler.com → Project → Secrets)"
        echo ""
        echo "  4. Start OpenClaw:"
        echo -e "     ${GN}doppler run -- docker compose up -d${CL}"
    fi

    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${YW}Reverse Proxy Setup (for external access):${CL}"
    echo ""
    echo "  Configure your reverse proxy (NGINX, Traefik, Caddy, etc.):"
    echo ""
    echo -e "  ${YW}Domain:${CL}      openclaw.yourdomain.com"
    echo -e "  ${YW}Backend:${CL}     http://${ip_addr:-'<container-ip>'}:18789"
    echo -e "  ${YW}Protocol:${CL}    HTTP/HTTPS with WebSocket support"
    echo ""
    echo "  NGINX Proxy Manager settings:"
    echo "    - Scheme: http"
    echo "    - Forward Hostname/IP: ${ip_addr:-'<container-ip>'}"
    echo "    - Forward Port: 18789"
    echo "    - Enable: Websockets Support, Block Common Exploits"
    echo "    - SSL: Request new certificate with Force SSL"
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
            --doppler-token) DOPPLER_TOKEN="$2"; shift 2 ;;
            --verbose) VERB="yes"; shift ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --advanced            Interactive mode with all settings"
                echo "  --storage NAME        Pre-select storage (e.g., local-lvm)"
                echo "  --doppler-token TOKEN Pre-configure Doppler secrets manager with service token"
                echo "                        (Get from: doppler.com → Project → Access → Service Tokens)"
                echo "  --verbose             Show detailed output"
                echo "  --help                Show this help"
                echo ""
                echo "Examples:"
                echo "  $0                                        # Quick setup with prompts"
                echo "  $0 --advanced                             # Full interactive setup"
                echo "  $0 --doppler-token dp.st.prd.xxxxx        # Automated Doppler config"
                exit 0
                ;;
            *) shift ;;
        esac
    done

    check_proxmox
    detect_debian_version
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

    # CRITICAL: Set locale IMMEDIATELY - before ANY other commands
    # This prevents locale warnings in all subsequent operations
    setup_locale_immediate

    setup_base
    setup_nodejs
    setup_docker
    setup_github_cli
    setup_doppler
    setup_openclaw
    setup_directories
    setup_ssh

    # Validate installation
    validate_installation

    show_completion
}

main "$@"
