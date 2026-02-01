#!/usr/bin/env bash
#
# OpenClaw LXC Provisioning Script for Proxmox
# Creates and configures LXC containers for Gateway and Exec Node deployments
#
# Usage:
#   ./provision-lxc.sh gateway [OPTIONS]
#   ./provision-lxc.sh exec-node [OPTIONS]
#   ./provision-lxc.sh --help
#
# Options:
#   --ctid <id>         Container ID (default: auto-assign)
#   --ip <address>      Static IP (default: gateway=10.0.10.50, exec=10.0.10.51)
#   --gateway <ip>      Network gateway (default: 10.0.10.1)
#   --storage <name>    Proxmox storage (default: local-lvm)
#   --template <path>   Container template (default: auto-download Debian 12)
#   --dry-run           Show commands without executing
#   --force             Overwrite existing container
#
# Requirements:
#   - Run on Proxmox host as root
#   - pct, pvesm, wget available
#   - Network bridge vmbr0 configured
#

set -euo pipefail

# =============================================================================
# Configuration Defaults
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# Container profiles
declare -A GATEWAY_PROFILE=(
    [hostname]="openclaw-gateway"
    [cores]=4
    [memory]=8192
    [swap]=2048
    [rootfs]=32
    [ip]="10.0.10.50"
    [description]="OpenClaw Gateway - AI reasoning and channel management"
)

declare -A EXEC_NODE_PROFILE=(
    [hostname]="openclaw-exec"
    [cores]=8
    [memory]=16384
    [swap]=4096
    [rootfs]=64
    [ip]="10.0.10.51"
    [description]="OpenClaw Exec Node - Code execution and toolchains"
)

# Network defaults
DEFAULT_GATEWAY="10.0.10.1"
DEFAULT_NETMASK="24"
DEFAULT_BRIDGE="vmbr0"
DEFAULT_DNS="10.0.10.1"

# Storage defaults
DEFAULT_STORAGE="local-lvm"
DEFAULT_TEMPLATE_STORAGE="local"
DEBIAN_TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
TEMPLATE_URL="http://download.proxmox.com/images/system/${DEBIAN_TEMPLATE}"

# =============================================================================
# Logging and Output
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    log_error "$*"
    exit 1
}

# =============================================================================
# Utility Functions
# =============================================================================

usage() {
    cat << EOF
OpenClaw LXC Provisioning Script v${SCRIPT_VERSION}

Usage:
  ${SCRIPT_NAME} <profile> [OPTIONS]

Profiles:
  gateway       Create Gateway LXC (4 cores, 8GB RAM, reasoning/channels)
  exec-node     Create Exec Node LXC (8 cores, 16GB RAM, code execution)

Options:
  --ctid <id>         Container ID (default: auto-assign next available)
  --ip <address>      Static IP address (default: profile-specific)
  --gateway <ip>      Network gateway IP (default: ${DEFAULT_GATEWAY})
  --storage <name>    Proxmox storage for rootfs (default: ${DEFAULT_STORAGE})
  --template <path>   Path to container template (default: auto-download)
  --bridge <name>     Network bridge (default: ${DEFAULT_BRIDGE})
  --dns <ip>          DNS server (default: ${DEFAULT_DNS})
  --dry-run           Show commands without executing
  --force             Overwrite existing container with same CTID
  --help              Show this help message

Examples:
  # Create Gateway with defaults
  ${SCRIPT_NAME} gateway

  # Create Exec Node with custom IP
  ${SCRIPT_NAME} exec-node --ip 10.0.10.52

  # Dry run to see what would be executed
  ${SCRIPT_NAME} gateway --dry-run

  # Create with specific CTID
  ${SCRIPT_NAME} exec-node --ctid 200 --force

EOF
    exit 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root on a Proxmox host"
    fi
}

check_proxmox() {
    if ! command -v pct &> /dev/null; then
        die "pct command not found. This script must be run on a Proxmox host"
    fi
    if ! command -v pvesm &> /dev/null; then
        die "pvesm command not found. This script must be run on a Proxmox host"
    fi
}

get_next_ctid() {
    local max_ctid=99
    while read -r ctid; do
        if [[ $ctid -gt $max_ctid ]]; then
            max_ctid=$ctid
        fi
    done < <(pct list 2>/dev/null | tail -n +2 | awk '{print $1}')
    echo $((max_ctid + 1))
}

check_ctid_available() {
    local ctid=$1
    if pct status "$ctid" &>/dev/null; then
        return 1
    fi
    return 0
}

check_ip_available() {
    local ip=$1
    # Check if IP is already assigned to another container
    local configs
    configs=$(find /etc/pve/lxc -name "*.conf" 2>/dev/null || true)
    for conf in $configs; do
        if grep -q "ip=${ip}/" "$conf" 2>/dev/null; then
            log_warn "IP ${ip} may already be assigned (found in ${conf})"
            return 1
        fi
    done
    return 0
}

ensure_template() {
    local template_storage=$1
    local template_path="${template_storage}:vztmpl/${DEBIAN_TEMPLATE}"

    # Check if template exists
    if pvesm list "$template_storage" 2>/dev/null | grep -q "$DEBIAN_TEMPLATE"; then
        log_info "Template already exists: ${template_path}"
        echo "$template_path"
        return 0
    fi

    log_info "Downloading Debian 12 template..."
    local download_dir="/var/lib/vz/template/cache"
    mkdir -p "$download_dir"

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would download: ${TEMPLATE_URL}"
        echo "${template_storage}:vztmpl/${DEBIAN_TEMPLATE}"
        return 0
    fi

    wget -q --show-progress -O "${download_dir}/${DEBIAN_TEMPLATE}" "$TEMPLATE_URL" || \
        die "Failed to download template from ${TEMPLATE_URL}"

    log_success "Template downloaded successfully"
    echo "${template_storage}:vztmpl/${DEBIAN_TEMPLATE}"
}

check_storage() {
    local storage=$1
    if ! pvesm status -storage "$storage" &>/dev/null; then
        die "Storage '${storage}' not found. Available: $(pvesm status | tail -n +2 | awk '{print $1}' | tr '\n' ' ')"
    fi
}

# =============================================================================
# Main Provisioning Function
# =============================================================================

create_container() {
    local profile_name=$1
    local -n profile=$2

    local ctid=${CTID:-$(get_next_ctid)}
    local ip=${IP:-${profile[ip]}}
    local hostname=${profile[hostname]}
    local cores=${profile[cores]}
    local memory=${profile[memory]}
    local swap=${profile[swap]}
    local rootfs_size=${profile[rootfs]}
    local description=${profile[description]}

    log_info "=== OpenClaw LXC Provisioning ==="
    log_info "Profile: ${profile_name}"
    log_info "CTID: ${ctid}"
    log_info "Hostname: ${hostname}"
    log_info "IP: ${ip}/${DEFAULT_NETMASK}"
    log_info "Cores: ${cores}"
    log_info "Memory: ${memory}MB"
    log_info "Swap: ${swap}MB"
    log_info "Rootfs: ${rootfs_size}GB"
    log_info "Storage: ${STORAGE}"
    log_info "================================="

    # Validations
    if [[ $FORCE != true ]]; then
        if ! check_ctid_available "$ctid"; then
            die "Container ${ctid} already exists. Use --force to overwrite"
        fi
    else
        if ! check_ctid_available "$ctid"; then
            log_warn "Container ${ctid} exists, will be destroyed (--force)"
            if [[ $DRY_RUN != true ]]; then
                pct stop "$ctid" 2>/dev/null || true
                pct destroy "$ctid" --purge 2>/dev/null || true
            fi
        fi
    fi

    check_ip_available "$ip" || log_warn "Proceeding anyway..."
    check_storage "$STORAGE"

    # Ensure template
    local template
    if [[ -n "${TEMPLATE:-}" ]]; then
        template="$TEMPLATE"
    else
        template=$(ensure_template "$TEMPLATE_STORAGE")
    fi

    # Build pct create command
    local pct_cmd=(
        pct create "$ctid" "$template"
        --hostname "$hostname"
        --cores "$cores"
        --memory "$memory"
        --swap "$swap"
        --rootfs "${STORAGE}:${rootfs_size}"
        --net0 "name=eth0,bridge=${BRIDGE},ip=${ip}/${DEFAULT_NETMASK},gw=${GATEWAY_IP}"
        --nameserver "$DNS"
        --unprivileged 1
        --features "nesting=1"
        --onboot 1
        --start 0
        --description "$description"
    )

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would execute:"
        echo "  ${pct_cmd[*]}"
        log_info "[DRY-RUN] Would configure SSH and enable linger"
        return 0
    fi

    log_info "Creating container..."
    "${pct_cmd[@]}" || die "Failed to create container"

    log_success "Container ${ctid} created successfully"

    # Post-creation configuration
    log_info "Configuring container..."

    # Start container
    log_info "Starting container..."
    pct start "$ctid" || die "Failed to start container"

    # Wait for container to be ready
    log_info "Waiting for container to be ready..."
    sleep 5

    # Enable SSH access
    log_info "Configuring SSH..."
    pct exec "$ctid" -- bash -c "
        apt-get update -qq
        apt-get install -y -qq openssh-server curl
        sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        systemctl enable ssh
        systemctl restart ssh
    " || log_warn "SSH configuration may need manual intervention"

    # Get container IP for verification
    local container_ip
    container_ip=$(pct exec "$ctid" -- hostname -I 2>/dev/null | awk '{print $1}')

    log_success "==================================="
    log_success "Container provisioned successfully!"
    log_success "==================================="
    log_info "CTID: ${ctid}"
    log_info "Hostname: ${hostname}"
    log_info "IP Address: ${container_ip:-$ip}"
    log_info ""
    log_info "Next steps:"
    log_info "  1. SSH into container: ssh root@${ip}"
    log_info "  2. Run setup script: ./setup-docker-deps.sh"
    log_info "  3. Configure OpenClaw: ./generate-gateway-config.sh"
    log_info ""
    log_info "Container control:"
    log_info "  pct enter ${ctid}     # Enter container shell"
    log_info "  pct stop ${ctid}      # Stop container"
    log_info "  pct start ${ctid}     # Start container"

    # Output JSON for automation
    cat << EOF

{
  "success": true,
  "ctid": ${ctid},
  "hostname": "${hostname}",
  "ip": "${ip}",
  "profile": "${profile_name}",
  "storage": "${STORAGE}"
}
EOF
}

# =============================================================================
# Argument Parsing
# =============================================================================

PROFILE=""
CTID=""
IP=""
GATEWAY_IP="$DEFAULT_GATEWAY"
STORAGE="$DEFAULT_STORAGE"
TEMPLATE_STORAGE="$DEFAULT_TEMPLATE_STORAGE"
TEMPLATE=""
BRIDGE="$DEFAULT_BRIDGE"
DNS="$DEFAULT_DNS"
DRY_RUN=false
FORCE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            gateway)
                PROFILE="gateway"
                shift
                ;;
            exec-node)
                PROFILE="exec-node"
                shift
                ;;
            --ctid)
                CTID="$2"
                shift 2
                ;;
            --ip)
                IP="$2"
                shift 2
                ;;
            --gateway)
                GATEWAY_IP="$2"
                shift 2
                ;;
            --storage)
                STORAGE="$2"
                shift 2
                ;;
            --template)
                TEMPLATE="$2"
                shift 2
                ;;
            --bridge)
                BRIDGE="$2"
                shift 2
                ;;
            --dns)
                DNS="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                die "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done

    if [[ -z "$PROFILE" ]]; then
        die "Profile required. Use 'gateway' or 'exec-node'. See --help for usage."
    fi
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    parse_args "$@"

    if [[ $DRY_RUN != true ]]; then
        check_root
    fi
    check_proxmox

    case $PROFILE in
        gateway)
            create_container "gateway" GATEWAY_PROFILE
            ;;
        exec-node)
            create_container "exec-node" EXEC_NODE_PROFILE
            ;;
        *)
            die "Unknown profile: ${PROFILE}"
            ;;
    esac
}

main "$@"
