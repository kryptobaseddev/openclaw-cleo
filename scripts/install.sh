#!/usr/bin/env bash
#
# OpenClaw LXC Installer for Proxmox VE
#
# Run this ONE-LINER in Proxmox VE Shell:
#   bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)"
#
# Or with options:
#   bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)" -- --advanced
#
# This script creates an LXC container with:
#   - Debian 12 base
#   - Docker + Docker Compose
#   - Node.js 22 + pnpm
#   - Doppler CLI for secrets management
#   - OpenClaw built from kryptobaseddev/openclaw fork
#
# Requirements:
#   - Proxmox VE 7.0+ or 8.x
#   - Internet connectivity
#   - ~10GB storage for container
#

set -Eeuo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_VERSION="1.0.0"
FORK_REPO="https://github.com/kryptobaseddev/openclaw.git"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main"

# Terminal colors
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;32m")
CL=$(echo "\033[m")
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD=" "

# Default settings
CT_TYPE=1  # 1 = Unprivileged
PW=""
CT_ID=""
HN="openclaw"
DISK_SIZE="32"
CORE_COUNT="4"
RAM_SIZE="8192"
BRG="vmbr0"
NET="dhcp"
GATE=""
APT_CACHER=""
APT_CACHER_IP=""
DISABLEIP6="no"
MTU=""
SD=""
NS=""
MAC=""
VLAN=""
SSH="no"
VERB="no"
DOPPLER_TOKEN=""
ADVANCED="no"

# =============================================================================
# Helper Functions
# =============================================================================

msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; }

header_info() {
    clear
    cat <<"EOF"
   ____                   ________
  / __ \____  ___  ____  / ____/ /___ __      __
 / / / / __ \/ _ \/ __ \/ /   / / __ `/ | /| / /
/ /_/ / /_/ /  __/ / / / /___/ / /_/ /| |/ |/ /
\____/ .___/\___/_/ /_/\____/_/\__,_/ |__/|__/
    /_/

EOF
    echo -e "${BL}OpenClaw LXC Installer for Proxmox VE${CL}"
    echo -e "${YW}Version: ${SCRIPT_VERSION}${CL}"
    echo ""
}

cleanup() {
    popd >/dev/null 2>&1 || true
    rm -rf "${TEMP_DIR:-}" 2>/dev/null || true
}

trap cleanup EXIT

error_handler() {
    local exit_code="$?"
    local line_no="$1"
    local bash_lineno="${2:-}"
    local last_command="${3:-}"
    local func_trace="${4:-}"
    msg_error "Error on line ${line_no}: exit code ${exit_code}"
    msg_error "Command: ${last_command}"
    cleanup
    exit "${exit_code}"
}

trap 'error_handler ${LINENO} "$BASH_LINENO" "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

# Check if running on Proxmox
check_proxmox() {
    if ! command -v pveversion &>/dev/null; then
        msg_error "This script must be run on a Proxmox VE host"
        exit 1
    fi

    PROXMOX_VER=$(pveversion | grep "pve-manager" | cut -d'/' -f2 | cut -d'-' -f1)
    msg_ok "Proxmox VE ${PROXMOX_VER} detected"
}

# Get next available CT ID
get_next_ctid() {
    local ctid=100
    while pct status "$ctid" &>/dev/null; do
        ((ctid++))
    done
    echo "$ctid"
}

# Download Debian template if needed
download_template() {
    local template_storage="${1:-local}"
    local template_name="debian-12-standard_12.7-1_amd64.tar.zst"

    if pveam list "$template_storage" | grep -q "$template_name"; then
        msg_ok "Template already available"
        return 0
    fi

    msg_info "Downloading Debian 12 template"
    pveam update >/dev/null 2>&1
    pveam download "$template_storage" "$template_name" >/dev/null 2>&1
    msg_ok "Template downloaded"
}

# =============================================================================
# User Prompts
# =============================================================================

default_settings() {
    CT_ID=$(get_next_ctid)
    msg_info "Using default settings"
    msg_ok "Container ID: ${CT_ID}"
    msg_ok "Hostname: ${HN}"
    msg_ok "Disk Size: ${DISK_SIZE}GB"
    msg_ok "CPU Cores: ${CORE_COUNT}"
    msg_ok "RAM: ${RAM_SIZE}MB"
    msg_ok "Bridge: ${BRG}"
    msg_ok "Network: DHCP"
    echo ""
}

advanced_settings() {
    echo -e "${YW}Advanced Settings${CL}"
    echo ""

    # Container ID
    local default_ctid
    default_ctid=$(get_next_ctid)
    read -r -p "Container ID [${default_ctid}]: " CT_ID
    CT_ID="${CT_ID:-$default_ctid}"

    # Hostname
    read -r -p "Hostname [${HN}]: " input
    HN="${input:-$HN}"

    # Disk Size
    read -r -p "Disk Size in GB [${DISK_SIZE}]: " input
    DISK_SIZE="${input:-$DISK_SIZE}"

    # CPU Cores
    read -r -p "CPU Cores [${CORE_COUNT}]: " input
    CORE_COUNT="${input:-$CORE_COUNT}"

    # RAM
    read -r -p "RAM in MB [${RAM_SIZE}]: " input
    RAM_SIZE="${input:-$RAM_SIZE}"

    # Network Bridge
    read -r -p "Network Bridge [${BRG}]: " input
    BRG="${input:-$BRG}"

    # Static IP or DHCP
    read -r -p "Static IP (leave empty for DHCP): " NET
    NET="${NET:-dhcp}"

    if [[ "$NET" != "dhcp" ]]; then
        read -r -p "Gateway IP: " GATE
    fi

    # Doppler Token
    echo ""
    echo -e "${YW}Doppler Secrets Management${CL}"
    echo "Get a service token from: https://dashboard.doppler.com"
    read -r -p "Doppler Service Token (optional): " DOPPLER_TOKEN

    # SSH Access
    read -r -p "Enable SSH? [y/N]: " ssh_choice
    if [[ "${ssh_choice,,}" == "y" ]]; then
        SSH="yes"
    fi

    echo ""
    msg_ok "Advanced settings configured"
}

# =============================================================================
# Container Creation
# =============================================================================

create_container() {
    msg_info "Creating LXC Container"

    # Build pct create command
    local pct_cmd="pct create ${CT_ID} local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    pct_cmd+=" --hostname ${HN}"
    pct_cmd+=" --cores ${CORE_COUNT}"
    pct_cmd+=" --memory ${RAM_SIZE}"
    pct_cmd+=" --swap 2048"
    pct_cmd+=" --rootfs local-lvm:${DISK_SIZE}"
    pct_cmd+=" --unprivileged ${CT_TYPE}"
    pct_cmd+=" --features nesting=1"
    pct_cmd+=" --onboot 1"

    # Network configuration
    if [[ "$NET" == "dhcp" ]]; then
        pct_cmd+=" --net0 name=eth0,bridge=${BRG},ip=dhcp"
    else
        pct_cmd+=" --net0 name=eth0,bridge=${BRG},ip=${NET}/24,gw=${GATE}"
    fi

    # Execute
    eval "$pct_cmd" >/dev/null 2>&1

    msg_ok "Container ${CT_ID} created"
}

start_container() {
    msg_info "Starting Container"
    pct start "${CT_ID}"
    sleep 5
    msg_ok "Container started"
}

# =============================================================================
# Container Setup
# =============================================================================

setup_container() {
    msg_info "Configuring Container"

    # Wait for network
    local max_attempts=30
    local attempt=0
    while ! pct exec "${CT_ID}" -- ping -c1 google.com &>/dev/null; do
        ((attempt++))
        if [[ $attempt -ge $max_attempts ]]; then
            msg_error "Network not available after ${max_attempts} attempts"
            exit 1
        fi
        sleep 2
    done

    msg_ok "Network ready"

    # Update system
    msg_info "Updating system packages"
    pct exec "${CT_ID}" -- bash -c "apt-get update -qq && apt-get upgrade -y -qq" >/dev/null 2>&1
    msg_ok "System updated"

    # Install base packages
    msg_info "Installing base packages"
    pct exec "${CT_ID}" -- bash -c "apt-get install -y -qq curl wget git ca-certificates gnupg lsb-release jq socat build-essential" >/dev/null 2>&1
    msg_ok "Base packages installed"

    # Install Node.js 22
    msg_info "Installing Node.js 22"
    pct exec "${CT_ID}" -- bash -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y -qq nodejs" >/dev/null 2>&1
    pct exec "${CT_ID}" -- bash -c "corepack enable && corepack prepare pnpm@latest --activate" >/dev/null 2>&1
    msg_ok "Node.js 22 installed"

    # Install Docker
    msg_info "Installing Docker"
    pct exec "${CT_ID}" -- bash -c '
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl enable docker
        systemctl start docker
    ' >/dev/null 2>&1
    msg_ok "Docker installed"

    # Install GitHub CLI
    msg_info "Installing GitHub CLI"
    pct exec "${CT_ID}" -- bash -c '
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt-get update -qq
        apt-get install -y -qq gh
    ' >/dev/null 2>&1
    msg_ok "GitHub CLI installed"

    # Install Doppler CLI
    msg_info "Installing Doppler CLI"
    pct exec "${CT_ID}" -- bash -c '
        apt-get install -y -qq apt-transport-https
        curl -sLf --retry 3 --tlsv1.2 --proto "=https" "https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key" | gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | tee /etc/apt/sources.list.d/doppler-cli.list
        apt-get update -qq
        apt-get install -y -qq doppler
    ' >/dev/null 2>&1
    msg_ok "Doppler CLI installed"

    # Configure Doppler if token provided
    if [[ -n "${DOPPLER_TOKEN}" ]]; then
        msg_info "Configuring Doppler authentication"
        pct exec "${CT_ID}" -- bash -c "
            echo '${DOPPLER_TOKEN}' > /root/.doppler-token
            chmod 600 /root/.doppler-token
            doppler configure set token '${DOPPLER_TOKEN}' --scope /root
        " >/dev/null 2>&1
        msg_ok "Doppler configured"
    fi

    # Clone and build OpenClaw
    msg_info "Cloning OpenClaw fork"
    pct exec "${CT_ID}" -- bash -c "
        git clone --depth 1 ${FORK_REPO} /opt/openclaw
        cd /opt/openclaw
        pnpm install
    " >/dev/null 2>&1
    msg_ok "OpenClaw cloned"

    msg_info "Building OpenClaw"
    pct exec "${CT_ID}" -- bash -c "
        cd /opt/openclaw
        pnpm build
    " >/dev/null 2>&1
    msg_ok "OpenClaw built"

    msg_info "Building Docker image"
    pct exec "${CT_ID}" -- bash -c "
        cd /opt/openclaw
        docker build -t openclaw:local .
    " >/dev/null 2>&1
    msg_ok "Docker image built"

    # Create OpenClaw directories
    msg_info "Creating OpenClaw directories"
    pct exec "${CT_ID}" -- bash -c "
        mkdir -p /root/.openclaw/{config,workspace,memory,skills,credentials}
        chmod 700 /root/.openclaw
        chmod 700 /root/.openclaw/credentials
    " >/dev/null 2>&1
    msg_ok "Directories created"

    # Enable SSH if requested
    if [[ "$SSH" == "yes" ]]; then
        msg_info "Enabling SSH"
        pct exec "${CT_ID}" -- bash -c "
            apt-get install -y -qq openssh-server
            sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
            systemctl enable ssh
            systemctl start ssh
        " >/dev/null 2>&1
        msg_ok "SSH enabled"
    fi

    # Enable systemd linger
    pct exec "${CT_ID}" -- bash -c "loginctl enable-linger root 2>/dev/null || true" >/dev/null 2>&1
}

# =============================================================================
# Completion
# =============================================================================

show_completion() {
    local ip_addr
    ip_addr=$(pct exec "${CT_ID}" -- hostname -I 2>/dev/null | awk '{print $1}')

    echo ""
    echo -e "${GN}╔═══════════════════════════════════════════════════════════════╗${CL}"
    echo -e "${GN}║                   OpenClaw Installation Complete              ║${CL}"
    echo -e "${GN}╚═══════════════════════════════════════════════════════════════╝${CL}"
    echo ""
    echo -e "  ${YW}Container ID:${CL}  ${CT_ID}"
    echo -e "  ${YW}Hostname:${CL}      ${HN}"
    echo -e "  ${YW}IP Address:${CL}    ${ip_addr:-'DHCP - check pct exec ${CT_ID} -- hostname -I'}"
    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${YW}Next Steps:${CL}"
    echo ""
    echo "  1. Enter the container:"
    echo -e "     ${GN}pct enter ${CT_ID}${CL}"
    echo ""

    if [[ -z "${DOPPLER_TOKEN}" ]]; then
        echo "  2. Configure Doppler (get token from dashboard.doppler.com):"
        echo -e "     ${GN}doppler configure set token dp.st.prod.XXXXX --scope /root${CL}"
        echo ""
        echo "  3. Set your secrets in Doppler dashboard:"
        echo "     - ANTHROPIC_API_KEY"
        echo "     - OPENCLAW_GATEWAY_TOKEN (generate: openssl rand -hex 32)"
        echo "     - TELEGRAM_BOT_TOKEN (optional)"
        echo "     - DISCORD_BOT_TOKEN (optional)"
        echo ""
        echo "  4. Start OpenClaw:"
        echo -e "     ${GN}cd /opt/openclaw && doppler run -- docker compose up -d${CL}"
    else
        echo "  2. Set your secrets in Doppler dashboard:"
        echo "     - ANTHROPIC_API_KEY"
        echo "     - OPENCLAW_GATEWAY_TOKEN (generate: openssl rand -hex 32)"
        echo "     - TELEGRAM_BOT_TOKEN (optional)"
        echo "     - DISCORD_BOT_TOKEN (optional)"
        echo ""
        echo "  3. Start OpenClaw:"
        echo -e "     ${GN}cd /opt/openclaw && doppler run -- docker compose up -d${CL}"
    fi

    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${YW}NGINX Proxy Manager Configuration:${CL}"
    echo "  Domain: openclaw.yourdomain.com"
    echo "  Forward Host: ${ip_addr:-10.0.10.x}"
    echo "  Forward Port: 18789"
    echo "  Enable: Websockets Support, Block Common Exploits"
    echo "  SSL: Request Let's Encrypt certificate"
    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${YW}Useful Commands:${CL}"
    echo "  View logs:     docker logs openclaw-gateway-1"
    echo "  Check status:  docker ps | grep openclaw"
    echo "  Health check:  curl http://localhost:18789/health"
    echo "  Enter shell:   pct enter ${CT_ID}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    header_info
    check_proxmox

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --advanced)
                ADVANCED="yes"
                shift
                ;;
            --doppler-token)
                DOPPLER_TOKEN="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Download template
    download_template "local"

    # Get settings
    if [[ "$ADVANCED" == "yes" ]]; then
        advanced_settings
    else
        echo ""
        echo -e "Use ${YW}--advanced${CL} for custom settings"
        echo ""
        default_settings
    fi

    # Confirm
    echo ""
    read -r -p "Create OpenClaw LXC container? [Y/n]: " confirm
    if [[ "${confirm,,}" == "n" ]]; then
        msg_error "Installation cancelled"
        exit 0
    fi

    echo ""

    # Create and configure container
    create_container
    start_container
    setup_container

    # Show completion info
    show_completion
}

main "$@"
