#!/usr/bin/env bash
#
# OpenClaw Gateway Configuration Generator
# Generates secure openclaw.json configuration with sensible defaults
#
# Usage:
#   ./generate-gateway-config.sh [OPTIONS]
#
# Options:
#   --output-dir <path>   Config output directory (default: ~/.openclaw)
#   --model <model>       Primary AI model (default: anthropic/claude-opus-4-5)
#   --bind <mode>         Network binding: loopback|lan|tailnet (default: loopback)
#   --sandbox <mode>      Sandbox mode: off|all (default: all)
#   --channels            Enable channel configuration prompts
#   --telegram-token <t>  Telegram bot token
#   --discord-token <t>   Discord bot token
#   --heartbeat <mins>    Heartbeat interval in minutes (default: 30, 0=disable)
#   --dry-run             Show config without writing
#   --help                Show this help
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# Defaults
DEFAULT_OUTPUT_DIR="${HOME}/.openclaw"
DEFAULT_MODEL="anthropic/claude-opus-4-5"
DEFAULT_BIND="loopback"
DEFAULT_SANDBOX="all"
DEFAULT_HEARTBEAT=30
DEFAULT_PORT=18789

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

die() { log_error "$*"; exit 1; }

# =============================================================================
# Utility Functions
# =============================================================================

usage() {
    cat << EOF
OpenClaw Gateway Configuration Generator v${SCRIPT_VERSION}

Usage:
  ${SCRIPT_NAME} [OPTIONS]

Options:
  --output-dir <path>   Config directory (default: ~/.openclaw)
  --model <model>       Primary AI model (default: ${DEFAULT_MODEL})
  --bind <mode>         Network binding: loopback|lan|tailnet (default: ${DEFAULT_BIND})
  --sandbox <mode>      Sandbox mode: off|all (default: ${DEFAULT_SANDBOX})
  --workspace-access    Workspace access: none|ro|rw (default: rw)
  --telegram-token <t>  Telegram bot token (optional)
  --discord-token <t>   Discord bot token (optional)
  --heartbeat <mins>    Heartbeat interval (default: ${DEFAULT_HEARTBEAT}, 0=disable)
  --interactive         Prompt for missing values
  --dry-run             Show config without writing
  --force               Overwrite existing config
  --help                Show this help

Generated Files:
  - openclaw.json       Main configuration (JSON5 format)
  - .env                Environment variables template
  - exec-approvals.json Execution allowlist (if exec node)

Security Notes:
  - Gateway token auto-generated (32 bytes)
  - File permissions set to 600
  - Loopback binding by default (most secure)
  - Pairing DM policy by default

EOF
    exit 0
}

generate_token() {
    openssl rand -hex 32
}

# =============================================================================
# Configuration Generation
# =============================================================================

generate_config() {
    local output_dir=$1
    local gateway_token
    gateway_token=$(generate_token)

    # Build heartbeat config
    local heartbeat_config
    if [[ $HEARTBEAT -eq 0 ]]; then
        heartbeat_config='"0m"'
    else
        heartbeat_config="\"${HEARTBEAT}m\""
    fi

    # Build channel configs
    local telegram_config=""
    local discord_config=""

    if [[ -n "${TELEGRAM_TOKEN:-}" ]]; then
        telegram_config=$(cat << TELEGRAMEOF
    "telegram": {
      "enabled": true,
      "botToken": "\${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "pairing",
      "groups": {
        "*": { "requireMention": true }
      },
      "groupPolicy": "allowlist",
      "streamMode": "partial"
    },
TELEGRAMEOF
)
    else
        telegram_config=$(cat << TELEGRAMEOF
    "telegram": {
      "enabled": false,
      "dmPolicy": "pairing"
      // To enable: set TELEGRAM_BOT_TOKEN in .env
    },
TELEGRAMEOF
)
    fi

    if [[ -n "${DISCORD_TOKEN:-}" ]]; then
        discord_config=$(cat << DISCORDEOF
    "discord": {
      "enabled": true,
      "token": "\${DISCORD_BOT_TOKEN}",
      "dm": {
        "enabled": true,
        "allowFrom": []
      },
      "guilds": {
        // Add your guild ID here:
        // "YOUR_GUILD_ID": {
        //   "users": ["YOUR_USER_ID"],
        //   "requireMention": true
        // }
      }
    }
DISCORDEOF
)
    else
        discord_config=$(cat << DISCORDEOF
    "discord": {
      "enabled": false
      // To enable: set DISCORD_BOT_TOKEN in .env and configure guilds
    }
DISCORDEOF
)
    fi

    # Generate main config
    cat << CONFIGEOF
{
  // OpenClaw Gateway Configuration
  // Generated: $(date -Iseconds)
  // Version: ${SCRIPT_VERSION}

  "gateway": {
    "mode": "local",
    "bind": "${BIND}",
    "port": ${DEFAULT_PORT},
    "auth": {
      "mode": "token",
      "token": "${gateway_token}",
      "allowTailscale": true
    },
    "trustedProxies": ["127.0.0.1"],
    "controlUi": {
      "allowInsecureAuth": false,
      "dangerouslyDisableDeviceAuth": false
    },
    "nodes": {
      "browser": {
        "mode": "off"  // Enable if you need browser automation
      }
    }
  },

  "agent": {
    "model": "${MODEL}",
    "workspace": "${output_dir}/workspace",
    "thinkingDefault": "high",
    "timeoutSeconds": 1800,
    "heartbeat": {
      "every": ${heartbeat_config}
    }
  },

  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "${SANDBOX}",
        "scope": "agent",
        "workspaceAccess": "${WORKSPACE_ACCESS}"
      },
      "model": {
        "primary": "${MODEL}",
        "fallbacks": ["anthropic/claude-sonnet-4", "openai/gpt-4o"]
      },
      "memorySearch": {
        "enabled": true,
        "provider": "auto"
      },
      "compaction": {
        "memoryFlush": {
          "enabled": true,
          "softThresholdTokens": 4000
        }
      }
    }
  },

  "channels": {
${telegram_config}
${discord_config}
  },

  "session": {
    "dmScope": "per-channel-peer",
    "reset": {
      "mode": "idle",
      "idleMinutes": 240
    }
  },

  "tools": {
    "profile": "coding",
    "elevated": {
      "allowFrom": []  // Add trusted agent IDs for elevated access
    }
  },

  "skills": {
    "entries": {},
    "load": {
      "watch": true,
      "extraDirs": ["${output_dir}/skills"]
    }
  },

  "logging": {
    "file": "/tmp/openclaw/openclaw.log",
    "redactSensitive": "tools"
  },

  "discovery": {
    "mdns": {
      "mode": "minimal"
    }
  }
}
CONFIGEOF
}

generate_env_file() {
    cat << ENVEOF
# OpenClaw Environment Variables
# Generated: $(date -Iseconds)
#
# IMPORTANT: Add your API keys below and keep this file secure (chmod 600)
#

# Required: Anthropic API Key for Claude models
# Get from: console.anthropic.com
ANTHROPIC_API_KEY=

# Memory Search: Pick one for semantic memory retrieval
# OpenAI: platform.openai.com/api-keys
OPENAI_API_KEY=
# Google AI: aistudio.google.com/apikey
GOOGLE_API_KEY=

# Search & Social
# Brave Search API: brave.com/search/api/
BRAVE_API_KEY=
# Moltbook: AI agent social network (moltbook.com)
MOLTBOOK_API_KEY=

# Email Identity: For autonomous account signups & verification
# AgentMail: agentmail.to/dashboard
AGENTMAIL_API_KEY=
AGENTMAIL_EMAIL=

# Gateway Configuration
OPENCLAW_GATEWAY_BIND=${BIND}
OPENCLAW_GATEWAY_PORT=${DEFAULT_PORT}

# Channel Tokens (set these if enabling Telegram/Discord)
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN:-}
DISCORD_BOT_TOKEN=${DISCORD_TOKEN:-}

# Keyring password for secure credential storage
GOG_KEYRING_PASSWORD=$(generate_token)

# XDG config home (for systemd services)
XDG_CONFIG_HOME=${OUTPUT_DIR}
ENVEOF
}

generate_exec_approvals() {
    cat << EXECEOF
{
  "version": 1,
  "defaultPolicy": "deny",
  "description": "OpenClaw exec allowlist - permits safe binaries only",
  "generated": "$(date -Iseconds)",
  "allowlist": [
    {
      "binary": "/usr/bin/git",
      "args": ["*"],
      "comment": "Git version control"
    },
    {
      "binary": "/usr/bin/gh",
      "args": ["*"],
      "comment": "GitHub CLI"
    },
    {
      "binary": "/usr/bin/npm",
      "args": ["install", "run", "test", "build", "ci", "audit"],
      "comment": "NPM package manager (safe commands only)"
    },
    {
      "binary": "/usr/local/bin/pnpm",
      "args": ["install", "run", "test", "build", "add", "remove"],
      "comment": "pnpm package manager"
    },
    {
      "binary": "/usr/local/bin/cleo",
      "args": ["*"],
      "comment": "CLEO task management"
    },
    {
      "binary": "/usr/bin/jq",
      "args": ["*"],
      "comment": "JSON processing (safe bin)"
    },
    {
      "binary": "/usr/bin/grep",
      "args": ["*"],
      "comment": "Pattern matching (safe bin)"
    },
    {
      "binary": "/usr/bin/sort",
      "args": ["*"],
      "comment": "Sorting (safe bin)"
    },
    {
      "binary": "/usr/bin/uniq",
      "args": ["*"],
      "comment": "Deduplication (safe bin)"
    },
    {
      "binary": "/usr/bin/head",
      "args": ["*"],
      "comment": "Head (safe bin)"
    },
    {
      "binary": "/usr/bin/tail",
      "args": ["*"],
      "comment": "Tail (safe bin)"
    },
    {
      "binary": "/usr/bin/wc",
      "args": ["*"],
      "comment": "Word count (safe bin)"
    },
    {
      "binary": "/usr/bin/cat",
      "args": ["*"],
      "comment": "Concatenate (safe bin)"
    },
    {
      "binary": "/usr/bin/ls",
      "args": ["*"],
      "comment": "List directory (safe bin)"
    },
    {
      "binary": "/usr/bin/find",
      "args": ["*"],
      "comment": "Find files"
    },
    {
      "binary": "/usr/bin/curl",
      "args": ["-s", "-S", "-L", "-o", "-O", "-X", "-H", "-d"],
      "comment": "HTTP client (limited flags)"
    },
    {
      "binary": "/usr/bin/docker",
      "args": ["ps", "logs", "inspect", "images", "stats"],
      "comment": "Docker (read-only operations)"
    }
  ],
  "denylist": [
    {
      "pattern": "rm -rf /",
      "comment": "Prevent root deletion"
    },
    {
      "pattern": "rm -rf /*",
      "comment": "Prevent recursive root deletion"
    },
    {
      "pattern": "chmod 777",
      "comment": "Prevent permission loosening"
    },
    {
      "pattern": "curl * | bash",
      "comment": "Prevent pipe-to-shell attacks"
    },
    {
      "pattern": "wget * | bash",
      "comment": "Prevent pipe-to-shell attacks"
    },
    {
      "pattern": ":(){ :|:& };:",
      "comment": "Prevent fork bomb"
    },
    {
      "pattern": "> /dev/sda",
      "comment": "Prevent disk destruction"
    },
    {
      "pattern": "mkfs",
      "comment": "Prevent filesystem destruction"
    },
    {
      "pattern": "dd if=",
      "comment": "Prevent low-level disk operations"
    }
  ]
}
EXECEOF
}

# =============================================================================
# Main Functions
# =============================================================================

write_config_files() {
    local output_dir=$1

    log_info "Creating directory structure..."
    mkdir -p "${output_dir}"/{workspace,memory,skills,credentials,config}

    # Generate and write main config
    local config_file="${output_dir}/openclaw.json"
    if [[ -f "$config_file" && $FORCE != true ]]; then
        die "Config exists: ${config_file}. Use --force to overwrite"
    fi

    log_info "Generating openclaw.json..."
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would write to ${config_file}:"
        generate_config "$output_dir"
    else
        generate_config "$output_dir" > "$config_file"
        chmod 600 "$config_file"
        log_success "Created: ${config_file}"
    fi

    # Generate .env file
    local env_file="${output_dir}/.env"
    log_info "Generating .env template..."
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would write to ${env_file}"
    else
        generate_env_file > "$env_file"
        chmod 600 "$env_file"
        log_success "Created: ${env_file}"
    fi

    # Generate exec approvals
    local exec_file="${output_dir}/exec-approvals.json"
    log_info "Generating exec-approvals.json..."
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would write to ${exec_file}"
    else
        generate_exec_approvals > "$exec_file"
        chmod 600 "$exec_file"
        log_success "Created: ${exec_file}"
    fi

    # Set directory permissions
    if [[ $DRY_RUN != true ]]; then
        chmod 700 "$output_dir"
        chmod 700 "${output_dir}/credentials"
        log_success "Set secure permissions (700/600)"
    fi
}

interactive_setup() {
    echo ""
    echo "=== Interactive Configuration ==="
    echo ""

    # Model selection
    read -rp "Primary AI model [${MODEL}]: " input_model
    MODEL="${input_model:-$MODEL}"

    # Binding
    read -rp "Network binding (loopback/lan/tailnet) [${BIND}]: " input_bind
    BIND="${input_bind:-$BIND}"

    # Sandbox
    read -rp "Sandbox mode (off/all) [${SANDBOX}]: " input_sandbox
    SANDBOX="${input_sandbox:-$SANDBOX}"

    # Telegram
    read -rp "Telegram bot token (leave empty to skip): " input_telegram
    TELEGRAM_TOKEN="${input_telegram:-}"

    # Discord
    read -rp "Discord bot token (leave empty to skip): " input_discord
    DISCORD_TOKEN="${input_discord:-}"

    echo ""
}

# =============================================================================
# Argument Parsing
# =============================================================================

OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
MODEL="$DEFAULT_MODEL"
BIND="$DEFAULT_BIND"
SANDBOX="$DEFAULT_SANDBOX"
WORKSPACE_ACCESS="rw"
TELEGRAM_TOKEN=""
DISCORD_TOKEN=""
HEARTBEAT=$DEFAULT_HEARTBEAT
INTERACTIVE=false
DRY_RUN=false
FORCE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --model)
                MODEL="$2"
                shift 2
                ;;
            --bind)
                BIND="$2"
                shift 2
                ;;
            --sandbox)
                SANDBOX="$2"
                shift 2
                ;;
            --workspace-access)
                WORKSPACE_ACCESS="$2"
                shift 2
                ;;
            --telegram-token)
                TELEGRAM_TOKEN="$2"
                shift 2
                ;;
            --discord-token)
                DISCORD_TOKEN="$2"
                shift 2
                ;;
            --heartbeat)
                HEARTBEAT="$2"
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
            --force)
                FORCE=true
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
    echo "║  OpenClaw Gateway Configuration Generator v${SCRIPT_VERSION}          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    if [[ $INTERACTIVE == true ]]; then
        interactive_setup
    fi

    log_info "Configuration:"
    log_info "  Output directory: ${OUTPUT_DIR}"
    log_info "  Model: ${MODEL}"
    log_info "  Binding: ${BIND}"
    log_info "  Sandbox: ${SANDBOX}"
    log_info "  Workspace access: ${WORKSPACE_ACCESS}"
    log_info "  Heartbeat: ${HEARTBEAT}m"
    log_info "  Telegram: $([ -n "$TELEGRAM_TOKEN" ] && echo 'configured' || echo 'disabled')"
    log_info "  Discord: $([ -n "$DISCORD_TOKEN" ] && echo 'configured' || echo 'disabled')"
    echo ""

    write_config_files "$OUTPUT_DIR"

    echo ""
    log_success "Configuration generated successfully!"
    echo ""
    log_info "Next steps:"
    log_info "  1. Edit ${OUTPUT_DIR}/.env and add your ANTHROPIC_API_KEY"
    log_info "  2. Review ${OUTPUT_DIR}/openclaw.json"
    log_info "  3. Configure channels if needed"
    log_info "  4. Run: openclaw gateway"
    echo ""
    log_info "Security reminders:"
    log_info "  - Keep .env and openclaw.json secure (chmod 600)"
    log_info "  - Never commit API keys to version control"
    log_info "  - Use pairing mode for DMs (default)"
    echo ""

    # Output JSON for automation
    cat << EOF
{
  "success": true,
  "config_dir": "${OUTPUT_DIR}",
  "config_file": "${OUTPUT_DIR}/openclaw.json",
  "env_file": "${OUTPUT_DIR}/.env",
  "exec_approvals": "${OUTPUT_DIR}/exec-approvals.json",
  "gateway_token_generated": true
}
EOF
}

main "$@"
