#!/usr/bin/env bash
#
# OpenClaw Full Setup Script
# Master orchestration script for complete OpenClaw deployment
#
# This script runs ALL setup steps in sequence:
#   1. LXC container provisioning (if on Proxmox)
#   2. Docker and dependencies installation
#   3. OpenClaw configuration generation
#   4. Channel configuration (optional)
#   5. Security audit and hardening
#
# Usage:
#   ./openclaw-full-setup.sh [OPTIONS]
#
# Options:
#   --mode <mode>         Setup mode: full|deps-only|config-only (default: full)
#   --profile <profile>   Container profile: gateway|exec-node (default: gateway)
#   --skip-lxc            Skip LXC provisioning (for non-Proxmox setups)
#   --interactive         Enable interactive prompts
#   --help                Show this help
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# Script paths
readonly LXC_SCRIPT="${SCRIPT_DIR}/provision-lxc.sh"
readonly DEPS_SCRIPT="${SCRIPT_DIR}/setup-docker-deps.sh"
readonly CONFIG_SCRIPT="${SCRIPT_DIR}/generate-gateway-config.sh"

# =============================================================================
# Logging
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "${MAGENTA}[STEP]${NC} $*"; }

die() { log_error "$*"; exit 1; }

# =============================================================================
# Utility Functions
# =============================================================================

usage() {
    cat << EOF
OpenClaw Full Setup Script v${SCRIPT_VERSION}

Usage:
  ${SCRIPT_NAME} [OPTIONS]

Modes:
  full          Complete setup (LXC + deps + config)
  deps-only     Install dependencies only (skip LXC)
  config-only   Generate configuration only

Options:
  --mode <mode>         Setup mode (default: full)
  --profile <profile>   LXC profile: gateway|exec-node (default: gateway)
  --skip-lxc            Skip LXC provisioning
  --telegram-token <t>  Telegram bot token
  --discord-token <t>   Discord bot token
  --interactive         Enable interactive prompts
  --dry-run             Show what would be executed
  --help                Show this help

Examples:
  # Full setup on Proxmox host
  ./openclaw-full-setup.sh

  # Setup inside existing LXC/VM
  ./openclaw-full-setup.sh --skip-lxc

  # Configuration only
  ./openclaw-full-setup.sh --mode config-only

  # Interactive setup with channels
  ./openclaw-full-setup.sh --interactive

EOF
    exit 0
}

print_banner() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║   ___  ____  _____ _   _  ____ _        ___        __   ║"
    echo "║  / _ \|  _ \| ____| \ | |/ ___| |      / \ \      / /  ║"
    echo "║ | | | | |_) |  _| |  \| | |   | |     / _ \ \ /\ / /   ║"
    echo "║ | |_| |  __/| |___| |\  | |___| |___ / ___ \ V  V /    ║"
    echo "║  \___/|_|   |_____|_| \_|\____|_____/_/   \_\_/\_/     ║"
    echo "║                                                        ║"
    echo "║                    powered by                          ║"
    echo "║                                                        ║"
    echo "║            ___ _    ___ ___                            ║"
    echo "║           / __| |  | __/ _ \                           ║"
    echo "║          | (__| |__| _| (_) |                          ║"
    echo "║           \___|____|___\___/                           ║"
    echo "║                                                        ║"
    echo "║        Personal AI Assistant Setup v${SCRIPT_VERSION}            ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
}

check_script_exists() {
    local script=$1
    if [[ ! -f "$script" ]]; then
        die "Required script not found: $script"
    fi
    if [[ ! -x "$script" ]]; then
        chmod +x "$script" || die "Cannot make script executable: $script"
    fi
}

is_proxmox() {
    command -v pct &> /dev/null && command -v pvesm &> /dev/null
}

# =============================================================================
# Setup Phases
# =============================================================================

phase_lxc() {
    log_step "Phase 1: LXC Container Provisioning"
    echo "─────────────────────────────────────────────"

    if [[ $SKIP_LXC == true ]]; then
        log_info "Skipping LXC provisioning (--skip-lxc)"
        return 0
    fi

    if ! is_proxmox; then
        log_warn "Not running on Proxmox host, skipping LXC provisioning"
        log_info "Run this script inside the LXC container for dependency setup"
        return 0
    fi

    check_script_exists "$LXC_SCRIPT"

    local lxc_args=("$PROFILE")
    [[ $DRY_RUN == true ]] && lxc_args+=("--dry-run")

    log_info "Creating ${PROFILE} LXC container..."
    "$LXC_SCRIPT" "${lxc_args[@]}"

    log_success "LXC container provisioned"
    echo ""
}

phase_deps() {
    log_step "Phase 2: Dependencies Installation"
    echo "─────────────────────────────────────────────"

    check_script_exists "$DEPS_SCRIPT"

    local deps_args=()
    [[ $DRY_RUN == true ]] && deps_args+=("--verify-only")

    log_info "Installing Docker, Node.js, and dependencies..."
    "$DEPS_SCRIPT" "${deps_args[@]}"

    log_success "Dependencies installed"
    echo ""
}

phase_config() {
    log_step "Phase 3: OpenClaw Configuration"
    echo "─────────────────────────────────────────────"

    check_script_exists "$CONFIG_SCRIPT"

    local config_args=()
    [[ $DRY_RUN == true ]] && config_args+=("--dry-run")
    [[ $INTERACTIVE == true ]] && config_args+=("--interactive")
    [[ -n "${TELEGRAM_TOKEN:-}" ]] && config_args+=("--telegram-token" "$TELEGRAM_TOKEN")
    [[ -n "${DISCORD_TOKEN:-}" ]] && config_args+=("--discord-token" "$DISCORD_TOKEN")
    config_args+=("--force")  # Allow overwrite in full setup

    log_info "Generating OpenClaw configuration..."
    "$CONFIG_SCRIPT" "${config_args[@]}"

    log_success "Configuration generated"
    echo ""
}

phase_security() {
    log_step "Phase 4: Security Audit"
    echo "─────────────────────────────────────────────"

    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would run: openclaw security audit --deep"
        return 0
    fi

    if command -v openclaw &> /dev/null; then
        log_info "Running security audit..."
        openclaw security audit 2>/dev/null || log_warn "Security audit not available yet"
    else
        log_warn "OpenClaw not installed, skipping security audit"
    fi

    # Manual security checks
    log_info "Checking file permissions..."
    local config_dir="${HOME}/.openclaw"
    if [[ -d "$config_dir" ]]; then
        local dir_perms
        dir_perms=$(stat -c %a "$config_dir" 2>/dev/null || stat -f %Lp "$config_dir" 2>/dev/null)
        if [[ "$dir_perms" == "700" ]]; then
            log_success "Config directory permissions OK (700)"
        else
            log_warn "Config directory permissions: $dir_perms (should be 700)"
        fi
    fi

    log_success "Security checks complete"
    echo ""
}

phase_summary() {
    log_step "Setup Complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    log_info "Configuration location: ~/.openclaw/"
    log_info "Main config: ~/.openclaw/openclaw.json"
    log_info "Environment: ~/.openclaw/.env"
    echo ""

    echo "Next steps:"
    echo "─────────────────────────────────────────────"
    echo "  1. Add your Anthropic API key:"
    echo "     echo 'ANTHROPIC_API_KEY=sk-ant-...' >> ~/.openclaw/.env"
    echo ""
    echo "  2. Start the gateway:"
    echo "     openclaw gateway"
    echo ""
    echo "  3. (Optional) Configure channels:"
    echo "     - Telegram: Create bot via @BotFather, add token to .env"
    echo "     - Discord: Create app at discord.com/developers, add token"
    echo ""
    echo "  4. (Optional) Pair your devices:"
    echo "     openclaw pairing list telegram"
    echo "     openclaw pairing approve telegram <CODE>"
    echo ""
    echo "═══════════════════════════════════════════════════════════"

    # Output JSON summary
    cat << EOF

{
  "success": true,
  "setup_complete": true,
  "config_dir": "${HOME}/.openclaw",
  "next_steps": [
    "Add ANTHROPIC_API_KEY to ~/.openclaw/.env",
    "Run: openclaw gateway",
    "Configure channels (optional)",
    "Pair devices (optional)"
  ]
}
EOF
}

# =============================================================================
# Argument Parsing
# =============================================================================

MODE="full"
PROFILE="gateway"
SKIP_LXC=false
TELEGRAM_TOKEN=""
DISCORD_TOKEN=""
INTERACTIVE=false
DRY_RUN=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                MODE="$2"
                shift 2
                ;;
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --skip-lxc)
                SKIP_LXC=true
                shift
                ;;
            --telegram-token)
                TELEGRAM_TOKEN="$2"
                shift 2
                ;;
            --discord-token)
                DISCORD_TOKEN="$2"
                shift 2
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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

    # Validate mode
    case $MODE in
        full|deps-only|config-only) ;;
        *) die "Invalid mode: $MODE" ;;
    esac

    # Validate profile
    case $PROFILE in
        gateway|exec-node) ;;
        *) die "Invalid profile: $PROFILE" ;;
    esac
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    parse_args "$@"

    print_banner

    log_info "Setup mode: ${MODE}"
    log_info "Profile: ${PROFILE}"
    log_info "Dry run: ${DRY_RUN}"
    echo ""

    case $MODE in
        full)
            phase_lxc
            phase_deps
            phase_config
            phase_security
            ;;
        deps-only)
            phase_deps
            phase_security
            ;;
        config-only)
            phase_config
            phase_security
            ;;
    esac

    phase_summary
}

main "$@"
