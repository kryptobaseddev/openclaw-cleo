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

SCRIPT_VERSION="1.1.0"
FORK_REPO="https://github.com/kryptobaseddev/openclaw.git"

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
STORAGE="local-lvm"
TEMPLATE_STORAGE="local"
SSH="no"
VERB="no"
DOPPLER_TOKEN=""
ADVANCED="no"

# =============================================================================
# Helpers
# =============================================================================

msg_info() { echo -e " ${HOLD} ${YW}$1...${CL}"; }
msg_ok() { echo -e " ${CM} ${GN}$1${CL}"; }
msg_error() { echo -e " ${CROSS} ${RD}$1${CL}"; }

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
    local template="debian-12-standard_12.7-1_amd64.tar.zst"
    if pveam list "$TEMPLATE_STORAGE" 2>/dev/null | grep -q "$template"; then
        msg_ok "Template available"
        return 0
    fi
    msg_info "Downloading Debian 12 template"
    pveam update >/dev/null 2>&1 || true
    if ! pveam download "$TEMPLATE_STORAGE" "$template"; then
        msg_error "Failed to download template"
        exit 1
    fi
    msg_ok "Template downloaded"
}

check_storage() {
    if ! pvesm status -storage "$STORAGE" &>/dev/null; then
        msg_error "Storage '$STORAGE' not found"
        echo "Available storage:"
        pvesm status | tail -n +2 | awk '{print "  - " $1}'
        exit 1
    fi
}

# =============================================================================
# Settings
# =============================================================================

default_settings() {
    CT_ID=$(get_next_ctid)
    echo ""
    echo -e "Use ${YW}--advanced${CL} for custom settings"
    echo ""
    msg_ok "Container ID: ${CT_ID}"
    msg_ok "Hostname: ${HN}"
    msg_ok "Disk Size: ${DISK_SIZE}GB"
    msg_ok "CPU Cores: ${CORE_COUNT}"
    msg_ok "RAM: ${RAM_SIZE}MB"
    msg_ok "Bridge: ${BRG}"
    msg_ok "Storage: ${STORAGE}"
    msg_ok "Network: DHCP"
    echo ""
}

advanced_settings() {
    echo -e "${YW}Advanced Settings${CL}"
    echo ""

    local default_ctid
    default_ctid=$(get_next_ctid)
    read -r -p "Container ID [${default_ctid}]: " CT_ID
    CT_ID="${CT_ID:-$default_ctid}"

    read -r -p "Hostname [${HN}]: " input
    HN="${input:-$HN}"

    read -r -p "Disk Size GB [${DISK_SIZE}]: " input
    DISK_SIZE="${input:-$DISK_SIZE}"

    read -r -p "CPU Cores [${CORE_COUNT}]: " input
    CORE_COUNT="${input:-$CORE_COUNT}"

    read -r -p "RAM MB [${RAM_SIZE}]: " input
    RAM_SIZE="${input:-$RAM_SIZE}"

    read -r -p "Network Bridge [${BRG}]: " input
    BRG="${input:-$BRG}"

    read -r -p "Storage [${STORAGE}]: " input
    STORAGE="${input:-$STORAGE}"

    read -r -p "Static IP (empty=DHCP): " NET
    NET="${NET:-dhcp}"

    if [[ "$NET" != "dhcp" ]]; then
        read -r -p "Gateway IP: " GATE
    fi

    echo ""
    echo -e "${YW}Doppler Secrets Management${CL}"
    read -r -p "Doppler Token (optional): " DOPPLER_TOKEN

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

    local template="${TEMPLATE_STORAGE}:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
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
    pct exec "${CT_ID}" -- bash -c "apt-get update && apt-get upgrade -y" >/dev/null 2>&1
    msg_ok "System updated"

    msg_info "Installing base packages"
    pct exec "${CT_ID}" -- bash -c "apt-get install -y curl wget git ca-certificates gnupg lsb-release jq socat build-essential" >/dev/null 2>&1
    msg_ok "Base packages installed"
}

setup_nodejs() {
    msg_info "Installing Node.js 22"
    pct exec "${CT_ID}" -- bash -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash -" >/dev/null 2>&1
    pct exec "${CT_ID}" -- bash -c "apt-get install -y nodejs" >/dev/null 2>&1
    pct exec "${CT_ID}" -- bash -c "corepack enable && corepack prepare pnpm@latest --activate" >/dev/null 2>&1
    msg_ok "Node.js 22 installed"
}

setup_docker() {
    msg_info "Installing Docker"
    pct exec "${CT_ID}" -- bash -c '
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl enable docker
        systemctl start docker
    ' >/dev/null 2>&1
    msg_ok "Docker installed"
}

setup_github_cli() {
    msg_info "Installing GitHub CLI"
    pct exec "${CT_ID}" -- bash -c '
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
        apt-get update
        apt-get install -y gh
    ' >/dev/null 2>&1
    msg_ok "GitHub CLI installed"
}

setup_doppler() {
    msg_info "Installing Doppler CLI"
    pct exec "${CT_ID}" -- bash -c '
        apt-get install -y apt-transport-https
        curl -sLf --retry 3 --tlsv1.2 --proto "=https" "https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key" | gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" > /etc/apt/sources.list.d/doppler-cli.list
        apt-get update
        apt-get install -y doppler
    ' >/dev/null 2>&1
    msg_ok "Doppler CLI installed"

    if [[ -n "${DOPPLER_TOKEN}" ]]; then
        msg_info "Configuring Doppler"
        pct exec "${CT_ID}" -- bash -c "
            echo '${DOPPLER_TOKEN}' > /root/.doppler-token
            chmod 600 /root/.doppler-token
            doppler configure set token '${DOPPLER_TOKEN}' --scope /root
        "
        msg_ok "Doppler configured"
    fi
}

setup_openclaw() {
    msg_info "Cloning OpenClaw fork (this may take a minute)"
    pct exec "${CT_ID}" -- bash -c "git clone --depth 1 ${FORK_REPO} /opt/openclaw" >/dev/null 2>&1
    msg_ok "OpenClaw cloned"

    msg_info "Installing dependencies (this may take 2-3 minutes)"
    pct exec "${CT_ID}" -- bash -c "cd /opt/openclaw && pnpm install" >/dev/null 2>&1
    msg_ok "Dependencies installed"

    msg_info "Building OpenClaw"
    pct exec "${CT_ID}" -- bash -c "cd /opt/openclaw && pnpm build" >/dev/null 2>&1
    msg_ok "OpenClaw built"

    msg_info "Building Docker image (this may take 3-5 minutes)"
    pct exec "${CT_ID}" -- bash -c "cd /opt/openclaw && docker build -t openclaw:local ." >/dev/null 2>&1
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
        pct exec "${CT_ID}" -- bash -c "
            apt-get install -y openssh-server
            sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
            systemctl enable ssh
            systemctl start ssh
        " >/dev/null 2>&1
        msg_ok "SSH enabled"
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
    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${YW}Next Steps:${CL}"
    echo ""
    echo "  1. Enter the container:"
    echo -e "     ${GN}pct enter ${CT_ID}${CL}"
    echo ""

    if [[ -z "${DOPPLER_TOKEN}" ]]; then
        echo "  2. Configure Doppler:"
        echo -e "     ${GN}doppler configure set token dp.st.prod.XXXXX --scope /root${CL}"
        echo ""
        echo "  3. Set secrets in Doppler dashboard:"
    else
        echo "  2. Set secrets in Doppler dashboard:"
    fi
    echo "     - ANTHROPIC_API_KEY"
    echo "     - OPENCLAW_GATEWAY_TOKEN (generate: openssl rand -hex 32)"
    echo "     - TELEGRAM_BOT_TOKEN (optional)"
    echo "     - DISCORD_BOT_TOKEN (optional)"
    echo ""

    if [[ -z "${DOPPLER_TOKEN}" ]]; then
        echo "  4. Start OpenClaw:"
    else
        echo "  3. Start OpenClaw:"
    fi
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
    header_info

    # Parse args
    while [[ $# -gt 0 ]]; do
        case $1 in
            --advanced) ADVANCED="yes"; shift ;;
            --doppler-token) DOPPLER_TOKEN="$2"; shift 2 ;;
            --storage) STORAGE="$2"; shift 2 ;;
            --verbose) VERB="yes"; shift ;;
            *) shift ;;
        esac
    done

    check_proxmox
    check_storage
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
