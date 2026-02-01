#!/usr/bin/env bash
#
# OpenClaw Docker and Dependencies Setup Script
# Installs Node.js 22, pnpm, Docker, Docker Compose, and development tools
#
# Usage:
#   ./setup-docker-deps.sh [OPTIONS]
#
# Options:
#   --verify-only    Only verify installed dependencies, don't install
#   --minimal        Skip optional tools (GitHub CLI, build-essential)
#   --skip-docker    Skip Docker installation (for non-container setups)
#   --help           Show this help message
#
# Requirements:
#   - Run inside Debian 12 LXC container
#   - Run as root
#   - Internet connectivity
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# Version requirements
readonly NODE_MAJOR_VERSION=22
readonly PNPM_VERSION="latest"

# =============================================================================
# Logging
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "${CYAN}[STEP]${NC} $*"; }

die() {
    log_error "$*"
    exit 1
}

# =============================================================================
# Utility Functions
# =============================================================================

usage() {
    cat << EOF
OpenClaw Docker and Dependencies Setup v${SCRIPT_VERSION}

Usage:
  ${SCRIPT_NAME} [OPTIONS]

Options:
  --verify-only    Only verify installed dependencies
  --minimal        Skip optional tools (GitHub CLI, build-essential)
  --skip-docker    Skip Docker installation
  --with-cleo      Also install CLEO task management
  --help           Show this help message

This script installs:
  - Node.js ${NODE_MAJOR_VERSION}
  - pnpm package manager
  - Docker and Docker Compose
  - GitHub CLI
  - Build tools (git, curl, jq, build-essential)

EOF
    exit 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root"
    fi
}

check_debian() {
    if [[ ! -f /etc/debian_version ]]; then
        die "This script requires Debian-based Linux"
    fi
}

command_exists() {
    command -v "$1" &> /dev/null
}

version_gte() {
    # Check if version $1 is >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# =============================================================================
# Installation Functions
# =============================================================================

install_base_packages() {
    log_step "Installing base packages..."

    apt-get update -qq || die "apt-get update failed"

    local packages=(
        curl
        wget
        ca-certificates
        gnupg
        lsb-release
        git
        jq
        socat
    )

    if [[ $MINIMAL != true ]]; then
        packages+=(
            build-essential
            python3
            python3-pip
        )
    fi

    apt-get install -y -qq "${packages[@]}" || die "Failed to install base packages"

    log_success "Base packages installed"
}

install_nodejs() {
    log_step "Installing Node.js ${NODE_MAJOR_VERSION}..."

    # Check if already installed with correct version
    if command_exists node; then
        local current_version
        current_version=$(node --version | sed 's/v//' | cut -d. -f1)
        if [[ $current_version -ge $NODE_MAJOR_VERSION ]]; then
            log_success "Node.js v$(node --version | sed 's/v//') already installed"
            return 0
        fi
        log_warn "Node.js ${current_version} found, upgrading to ${NODE_MAJOR_VERSION}..."
    fi

    # Install NodeSource repository
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x" | bash - || \
        die "Failed to add NodeSource repository"

    apt-get install -y -qq nodejs || die "Failed to install Node.js"

    # Verify installation
    local installed_version
    installed_version=$(node --version)
    log_success "Node.js ${installed_version} installed"
}

install_pnpm() {
    log_step "Installing pnpm..."

    if command_exists pnpm; then
        log_success "pnpm $(pnpm --version) already installed"
        return 0
    fi

    # Install pnpm via corepack (Node.js 16.13+)
    if command_exists corepack; then
        corepack enable || die "Failed to enable corepack"
        corepack prepare pnpm@latest --activate || log_warn "corepack prepare failed, trying npm install"
    fi

    # Fallback to npm install
    if ! command_exists pnpm; then
        npm install -g pnpm@latest || die "Failed to install pnpm"
    fi

    log_success "pnpm $(pnpm --version) installed"
}

install_docker() {
    log_step "Installing Docker..."

    if command_exists docker; then
        log_success "Docker $(docker --version | cut -d' ' -f3 | tr -d ',') already installed"
        # Ensure Docker is running
        systemctl enable docker 2>/dev/null || true
        systemctl start docker 2>/dev/null || true
        return 0
    fi

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || \
        die "Failed to install Docker"

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker

    # Verify
    docker --version || die "Docker installation verification failed"
    docker compose version || die "Docker Compose installation verification failed"

    log_success "Docker $(docker --version | cut -d' ' -f3 | tr -d ',') installed"
}

install_github_cli() {
    if [[ $MINIMAL == true ]]; then
        log_info "Skipping GitHub CLI (--minimal mode)"
        return 0
    fi

    log_step "Installing GitHub CLI..."

    if command_exists gh; then
        log_success "GitHub CLI $(gh --version | head -1 | awk '{print $3}') already installed"
        return 0
    fi

    # Add GitHub CLI repository
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" | \
        tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq gh || die "Failed to install GitHub CLI"

    log_success "GitHub CLI $(gh --version | head -1 | awk '{print $3}') installed"
}

install_openclaw() {
    log_step "Installing OpenClaw..."

    if command_exists openclaw; then
        log_success "OpenClaw $(openclaw --version 2>/dev/null || echo 'installed') already present"
        return 0
    fi

    # Install OpenClaw globally via pnpm
    pnpm add -g openclaw@latest || die "Failed to install OpenClaw"

    # Verify
    openclaw --version || log_warn "OpenClaw installed but version check failed"

    log_success "OpenClaw installed"
}

install_cleo() {
    if [[ $WITH_CLEO != true ]]; then
        log_info "Skipping CLEO installation (use --with-cleo to install)"
        return 0
    fi

    log_step "Installing CLEO task management..."

    # Check if CLEO is available as npm package or needs git clone
    if npm search cleo-task 2>/dev/null | grep -q cleo; then
        npm install -g cleo-task || log_warn "CLEO npm install failed"
    else
        log_info "CLEO not found in npm registry, manual installation may be required"
    fi
}

configure_system() {
    log_step "Configuring system settings..."

    # Enable linger for systemd user services (survives logout)
    if command_exists loginctl; then
        loginctl enable-linger root 2>/dev/null || true
        log_info "Enabled systemd linger for root user"
    fi

    # Create OpenClaw directories
    mkdir -p ~/.openclaw/{config,workspace,memory,skills,credentials}
    chmod 700 ~/.openclaw
    chmod 700 ~/.openclaw/credentials

    log_success "System configuration complete"
}

# =============================================================================
# Verification Functions
# =============================================================================

verify_installation() {
    log_step "Verifying installation..."

    local status=0
    local results=()

    # Node.js
    if command_exists node; then
        local node_ver
        node_ver=$(node --version | sed 's/v//')
        local node_major
        node_major=$(echo "$node_ver" | cut -d. -f1)
        if [[ $node_major -ge $NODE_MAJOR_VERSION ]]; then
            results+=("${GREEN}[OK]${NC} Node.js: v${node_ver}")
        else
            results+=("${YELLOW}[WARN]${NC} Node.js: v${node_ver} (expected >= ${NODE_MAJOR_VERSION})")
            status=1
        fi
    else
        results+=("${RED}[FAIL]${NC} Node.js: not installed")
        status=1
    fi

    # pnpm
    if command_exists pnpm; then
        results+=("${GREEN}[OK]${NC} pnpm: $(pnpm --version)")
    else
        results+=("${RED}[FAIL]${NC} pnpm: not installed")
        status=1
    fi

    # Docker
    if [[ $SKIP_DOCKER != true ]]; then
        if command_exists docker; then
            if docker info &>/dev/null; then
                results+=("${GREEN}[OK]${NC} Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')")
            else
                results+=("${YELLOW}[WARN]${NC} Docker: installed but daemon not running")
                status=1
            fi
        else
            results+=("${RED}[FAIL]${NC} Docker: not installed")
            status=1
        fi

        if command_exists docker && docker compose version &>/dev/null; then
            results+=("${GREEN}[OK]${NC} Docker Compose: $(docker compose version --short)")
        else
            results+=("${RED}[FAIL]${NC} Docker Compose: not installed")
            status=1
        fi
    fi

    # GitHub CLI
    if [[ $MINIMAL != true ]]; then
        if command_exists gh; then
            results+=("${GREEN}[OK]${NC} GitHub CLI: $(gh --version | head -1 | awk '{print $3}')")
        else
            results+=("${YELLOW}[WARN]${NC} GitHub CLI: not installed (optional)")
        fi
    fi

    # Git
    if command_exists git; then
        results+=("${GREEN}[OK]${NC} git: $(git --version | awk '{print $3}')")
    else
        results+=("${RED}[FAIL]${NC} git: not installed")
        status=1
    fi

    # jq
    if command_exists jq; then
        results+=("${GREEN}[OK]${NC} jq: $(jq --version)")
    else
        results+=("${RED}[FAIL]${NC} jq: not installed")
        status=1
    fi

    # OpenClaw
    if command_exists openclaw; then
        results+=("${GREEN}[OK]${NC} OpenClaw: installed")
    else
        results+=("${YELLOW}[WARN]${NC} OpenClaw: not installed (run script again)")
    fi

    # Print results
    echo ""
    echo "=== Dependency Verification Report ==="
    for result in "${results[@]}"; do
        echo -e "  $result"
    done
    echo "======================================="
    echo ""

    if [[ $status -eq 0 ]]; then
        log_success "All required dependencies installed and verified"
    else
        log_warn "Some dependencies missing or misconfigured"
    fi

    return $status
}

# =============================================================================
# Argument Parsing
# =============================================================================

VERIFY_ONLY=false
MINIMAL=false
SKIP_DOCKER=false
WITH_CLEO=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --minimal)
                MINIMAL=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --with-cleo)
                WITH_CLEO=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    parse_args "$@"

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  OpenClaw Docker & Dependencies Setup v${SCRIPT_VERSION}              ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    if [[ $VERIFY_ONLY == true ]]; then
        verify_installation
        exit $?
    fi

    check_root
    check_debian

    log_info "Starting dependency installation..."
    log_info "Options: minimal=${MINIMAL}, skip-docker=${SKIP_DOCKER}, with-cleo=${WITH_CLEO}"
    echo ""

    install_base_packages
    install_nodejs
    install_pnpm

    if [[ $SKIP_DOCKER != true ]]; then
        install_docker
    fi

    install_github_cli
    install_openclaw
    install_cleo
    configure_system

    echo ""
    verify_installation

    echo ""
    log_success "Setup complete!"
    echo ""
    log_info "Next steps:"
    log_info "  1. Authenticate GitHub CLI: gh auth login"
    log_info "  2. Run OpenClaw setup: openclaw setup"
    log_info "  3. Generate config: ./generate-gateway-config.sh"
    echo ""

    # Output JSON for automation
    cat << EOF
{
  "success": true,
  "node_version": "$(node --version 2>/dev/null || echo 'n/a')",
  "pnpm_version": "$(pnpm --version 2>/dev/null || echo 'n/a')",
  "docker_version": "$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo 'n/a')",
  "openclaw_installed": $(command_exists openclaw && echo true || echo false)
}
EOF
}

main "$@"
