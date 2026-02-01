# OpenClaw Documentation Research - February 2026

**Research Date**: 2026-02-01
**Documentation Source**: https://docs.openclaw.ai
**Purpose**: Comprehensive setup reference for OpenClaw personal AI assistant

---

## Table of Contents

1. [Installation Requirements](#1-installation-requirements)
2. [Configuration Reference](#2-configuration-reference)
3. [Security Setup](#3-security-setup)
4. [Channel Setup](#4-channel-setup)
5. [Skills System](#5-skills-system)
6. [Session Management](#6-session-management)
7. [Memory System](#7-memory-system)
8. [Browser Automation](#8-browser-automation)
9. [Model Failover](#9-model-failover)
10. [Docker Deployment](#10-docker-deployment)
11. [VPS Deployment (Hetzner/Proxmox)](#11-vps-deployment)
12. [Command Reference](#12-command-reference)

---

## 1. Installation Requirements

### System Requirements

| Component | Requirement |
|-----------|-------------|
| Node.js | >= 22 |
| Package Manager | pnpm |
| Docker | Optional (for containerized/sandboxed setups) |

### Installation Methods

#### Quick Start (macOS App)
The stable approach involves installing OpenClaw.app for menu bar operation, which bundles and manages the Gateway automatically.

#### From Source
```bash
# Clone repository
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# Install dependencies
pnpm install

# Run setup
openclaw setup
# Or via pnpm if no global installation:
pnpm openclaw setup
```

#### Global Installation
```bash
npm install -g openclaw@latest
```

### Directory Structure

```
~/.openclaw/
├── openclaw.json              # Primary configuration (JSON5 format)
├── workspace/                 # Agent workspace
│   ├── AGENTS.md             # Operating instructions
│   ├── SOUL.md               # Persona/instructions
│   ├── TOOLS.md              # Tool configuration
│   ├── IDENTITY.md           # Identity settings
│   ├── USER.md               # User preferences
│   ├── MEMORY.md             # Long-term memory
│   ├── HEARTBEAT.md          # Proactive mode config
│   ├── memory/               # Daily memory logs
│   │   └── YYYY-MM-DD.md
│   └── skills/               # Custom skills (highest priority)
├── credentials/              # Auth tokens and account data
│   ├── oauth.json
│   ├── whatsapp/<accountId>/creds.json
│   └── <channel>-allowFrom.json
├── agents/<agentId>/         # Agent-specific data
│   ├── sessions/*.jsonl      # Session transcripts
│   └── agent/auth-profiles.json
├── skills/                   # Managed/local skills
├── extensions/<pluginId>/    # Plugin storage
├── devices/                  # Device pairing state
│   ├── pending.json
│   └── paired.json
└── memory/<agentId>.sqlite   # Vector memory index

/tmp/openclaw/                # Logs
└── openclaw-YYYY-MM-DD.log
```

### Linux Considerations

Systemd user services may stop on logout. Enable lingering:
```bash
sudo loginctl enable-linger $USER
```

---

## 2. Configuration Reference

### Primary Configuration File

Location: `~/.openclaw/openclaw.json` (JSON5 format)

### Complete Configuration Schema

```json5
{
  // Gateway Configuration
  gateway: {
    mode: "local",                    // "local" | "remote"
    bind: "loopback",                 // "loopback" | "lan" | "tailnet" | "custom"
    port: 18789,                      // WebSocket port
    auth: {
      mode: "token",                  // "token" | "password"
      token: "your-long-random-token",
      password: "${OPENCLAW_GATEWAY_PASSWORD}",  // For password mode
      allowTailscale: true            // Accept Tailscale identity headers
    },
    trustedProxies: ["127.0.0.1"],    // For reverse proxy setups
    controlUi: {
      allowInsecureAuth: false,       // Downgrade to token-only auth
      dangerouslyDisableDeviceAuth: false  // Break-glass only
    },
    nodes: {
      browser: {
        mode: "on"                    // "on" | "off"
      }
    }
  },

  // Agent Configuration
  agent: {
    model: "anthropic/claude-opus-4-5",
    workspace: "~/.openclaw/workspace",
    thinkingDefault: "high",          // "low" | "medium" | "high"
    timeoutSeconds: 1800,
    heartbeat: {
      every: "0m"                     // "0m" to disable, "30m" default
    }
  },

  // Multi-Agent Configuration
  agents: {
    defaults: {
      sandbox: {
        mode: "all",                  // "off" | "all"
        scope: "agent",               // "agent" | "session" | "shared"
        workspaceAccess: "ro",        // "none" | "ro" | "rw"
        browser: {
          allowHostControl: false
        }
      },
      model: {
        primary: "anthropic/claude-opus-4-5",
        fallbacks: ["openai/gpt-4o", "anthropic/claude-sonnet-4"]
      },
      imageModel: "openai/gpt-4o",
      memorySearch: {
        enabled: true,
        provider: "auto"              // "auto" | "local" | "openai" | "gemini"
      },
      compaction: {
        memoryFlush: {
          enabled: true,
          softThresholdTokens: 4000
        }
      }
    },
    list: [
      {
        id: "personal",
        workspace: "~/.openclaw/workspace-personal",
        sandbox: { mode: "off" }
      },
      {
        id: "public",
        workspace: "~/.openclaw/workspace-public",
        sandbox: { mode: "all", workspaceAccess: "none" },
        tools: { deny: ["exec", "process", "browser", "read", "write"] }
      }
    ]
  },

  // Channel Configuration
  channels: {
    whatsapp: {
      enabled: true,
      dmPolicy: "pairing",            // "pairing" | "allowlist" | "open" | "disabled"
      allowFrom: ["+1234567890"],     // Phone numbers
      groups: {
        "*": { requireMention: true }
      },
      groupPolicy: "allowlist",
      groupAllowFrom: []
    },
    telegram: {
      enabled: true,
      botToken: "123:abc",            // Or use TELEGRAM_BOT_TOKEN env
      dmPolicy: "pairing",
      groups: {
        "*": { requireMention: true }
      },
      groupPolicy: "allowlist",
      groupAllowFrom: [],
      streamMode: "partial",          // "partial" | "block" | "off"
      textChunkLimit: 4000,
      historyLimit: 50,
      customCommands: [
        { command: "backup", description: "Git backup" }
      ],
      capabilities: {
        inlineButtons: "allowlist"    // "off" | "dm" | "group" | "all" | "allowlist"
      },
      reactionNotifications: "off",   // "off" | "own" | "all"
      reactionLevel: "off"            // "off" | "ack" | "minimal" | "extensive"
    },
    discord: {
      enabled: true,
      token: "YOUR_BOT_TOKEN",        // Or use DISCORD_BOT_TOKEN env
      dm: {
        enabled: true,
        allowFrom: []                 // User IDs
      },
      guilds: {
        "YOUR_GUILD_ID": {
          users: ["YOUR_USER_ID"],
          requireMention: true,
          channels: {
            help: {
              allow: true,
              requireMention: true
            }
          }
        }
      }
    },
    slack: {
      enabled: false,
      channels: {}
    }
  },

  // Session Configuration
  session: {
    dmScope: "per-channel-peer",      // "main" | "per-peer" | "per-channel-peer" | "per-account-channel-peer"
    reset: {
      mode: "daily",                  // "daily" | "idle"
      atHour: 4,                      // For daily mode
      idleMinutes: 120                // For idle mode
    },
    resetByType: {
      thread: { mode: "daily", atHour: 4 },
      dm: { mode: "idle", idleMinutes: 240 },
      group: { mode: "idle", idleMinutes: 120 }
    },
    resetByChannel: {
      discord: { mode: "idle", idleMinutes: 10080 }
    },
    identityLinks: {
      alice: ["telegram:123456789", "discord:987654321012345678"]
    },
    sendPolicy: {
      rules: [
        { action: "deny", match: { channel: "discord", chatType: "group" } }
      ],
      default: "allow"
    }
  },

  // Tool Configuration
  tools: {
    profile: "coding",                // "minimal" | "coding" | "messaging" | "full"
    allow: ["group:fs", "browser"],
    deny: ["browser"],
    elevated: {
      allowFrom: ["personal-agent-only"]
    },
    byProvider: {
      "google-antigravity": { profile: "minimal" }
    }
  },

  // Skills Configuration
  skills: {
    entries: {
      "skill-name": {
        enabled: true,
        apiKey: "SECRET_KEY",
        env: { ENV_VAR: "value" },
        config: { customField: "value" }
      }
    },
    load: {
      watch: true,
      watchDebounceMs: 250,
      extraDirs: ["/path/to/skills"]
    }
  },

  // Browser Configuration
  browser: {
    enabled: true,
    defaultProfile: "chrome",
    headless: false,
    noSandbox: false,
    attachOnly: false,
    executablePath: "/path/to/browser",
    remoteCdpTimeoutMs: 1500,
    remoteCdpHandshakeTimeoutMs: 3000,
    evaluateEnabled: true,
    profiles: {
      openclaw: { cdpPort: 18800, color: "#FF4500" },
      work: { cdpPort: 18801, color: "#0066CC" },
      remote: { cdpUrl: "http://10.0.0.42:9222", color: "#00AA00" }
    }
  },

  // Logging Configuration
  logging: {
    file: "/tmp/openclaw/openclaw.log",
    redactSensitive: "tools",         // "tools" | "off"
    redactPatterns: ["token-pattern", "hostname"]
  },

  // mDNS Discovery
  discovery: {
    mdns: {
      mode: "minimal"                 // "minimal" | "off" | "full"
    }
  },

  // Auth Configuration
  auth: {
    order: {
      anthropic: ["oauth-profile", "api-key-profile"]
    },
    profiles: [],
    cooldowns: {
      billingBackoffHours: 5
    }
  }
}
```

### Tool Groups Reference

| Group | Tools Included |
|-------|----------------|
| `group:runtime` | exec, bash, process |
| `group:fs` | read, write, edit, apply_patch |
| `group:sessions` | sessions_list, sessions_history, sessions_send, sessions_spawn, session_status |
| `group:memory` | memory_search, memory_get |
| `group:web` | web_search, web_fetch |
| `group:ui` | browser, canvas |
| `group:automation` | cron, gateway |
| `group:messaging` | message |
| `group:nodes` | nodes |
| `group:openclaw` | all built-in OpenClaw tools |

### Tool Profiles

| Profile | Description |
|---------|-------------|
| `minimal` | session_status only |
| `coding` | file system, runtime, sessions, memory, image tools |
| `messaging` | messaging channels, session management, status |
| `full` | no restrictions (default) |

---

## 3. Security Setup

### Gateway Authentication

#### Token Mode (Recommended)
```json5
{
  gateway: {
    auth: {
      mode: "token",
      token: "your-long-random-token"  // Generate with: openssl rand -hex 32
    }
  }
}
```

#### Password Mode
```json5
{
  gateway: {
    auth: {
      mode: "password",
      password: "${OPENCLAW_GATEWAY_PASSWORD}"
    }
  }
}
```

### Network Binding Options

| Bind Mode | Description | Security Level |
|-----------|-------------|----------------|
| `loopback` | localhost only (default) | Highest |
| `lan` | Local network | Requires strong auth + firewall |
| `tailnet` | Tailscale network | Good with Tailscale identity |
| `custom` | Custom binding | Varies |

### DM Policy Options

| Policy | Description |
|--------|-------------|
| `pairing` | Unknown senders receive 1-hour pairing code (default) |
| `allowlist` | Unknown senders blocked |
| `open` | Public access (requires explicit `"*"` in allowlist) |
| `disabled` | Ignore inbound DMs |

### Pairing Commands
```bash
openclaw pairing list <channel>
openclaw pairing approve <channel> <code>
```

### Sandboxing Configuration

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "all",              // "off" | "all"
        scope: "agent",           // "agent" | "session" | "shared"
        workspaceAccess: "ro"     // "none" | "ro" | "rw"
      }
    }
  }
}
```

### Exec Allowlist Format

Allowlists use case-insensitive glob patterns targeting binary paths:
```
~/Projects/**/bin/bird
~/.local/bin/*
/opt/homebrew/bin/rg
```

**Security Policy Levels:**
- `deny`: Blocks all host exec requests
- `allowlist`: Permits only matching commands
- `full`: Allows everything (bypasses approvals)

**Safe Binaries Exception** (stdin-only mode):
`jq`, `grep`, `cut`, `sort`, `uniq`, `head`, `tail`, `tr`, `wc`

### File Permissions

Recommended permissions:
- `~/.openclaw/openclaw.json`: `600`
- `~/.openclaw/`: `700`
- Config files, credentials, session data: `600`
- Directories: `700`

### Security Audit
```bash
openclaw security audit              # Basic audit
openclaw security audit --deep       # Live probing
openclaw security audit --fix        # Auto-remediation
```

### Secure Baseline Configuration

```json5
{
  gateway: {
    mode: "local",
    bind: "loopback",
    port: 18789,
    auth: { mode: "token", token: "your-long-random-token" }
  },
  channels: {
    whatsapp: {
      dmPolicy: "pairing",
      groups: { "*": { requireMention: true } }
    }
  },
  agents: {
    defaults: {
      sandbox: {
        mode: "all",
        scope: "agent",
        workspaceAccess: "ro"
      }
    }
  },
  logging: {
    redactSensitive: "tools"
  }
}
```

---

## 4. Channel Setup

### Telegram Bot Setup

#### 1. Create Bot with BotFather
```
/newbot                    # Creates bot, returns token
/setjoingroups             # Control group addition
/setprivacy                # Manage group message visibility
```

#### 2. Configure Token

**Environment Variable:**
```bash
export TELEGRAM_BOT_TOKEN=your_token_here
```

**Configuration File:**
```json5
{
  channels: {
    telegram: {
      enabled: true,
      botToken: "123:abc",
      dmPolicy: "pairing"
    }
  }
}
```

#### 3. Privacy Mode
Telegram bots default to Privacy Mode. To receive all messages:
- Disable via `/setprivacy` in BotFather, OR
- Add bot as group admin

**Note:** After toggling privacy mode, remove and re-add bot to each group.

#### 4. Group Configuration
```json5
{
  channels: {
    telegram: {
      groups: {
        "*": { requireMention: true }
      },
      groupPolicy: "allowlist",     // "open" | "allowlist" | "disabled"
      groupAllowFrom: []            // User IDs or @usernames
    }
  }
}
```

### Discord Application Setup

#### 1. Developer Portal Configuration

1. Navigate to **Applications** > **New Application**
2. Select **Bot** > **Add Bot**
3. Copy **Bot Token**

#### 2. Enable Privileged Intents

Under **Bot** > **Privileged Gateway Intents**:
- **Message Content Intent** (required)
- **Server Members Intent** (recommended)

#### 3. OAuth2 Permissions

Generate invite URL via **OAuth2** > **URL Generator**:

**Required Scopes:**
- `bot`
- `applications.commands`

**Minimal Bot Permissions:**
- View Channels
- Send Messages
- Read Message History
- Embed Links
- Attach Files
- Add Reactions (recommended)

#### 4. Configure Token

**Environment Variable:**
```bash
export DISCORD_BOT_TOKEN=your_bot_token_here
```

**Configuration File:**
```json5
{
  channels: {
    discord: {
      enabled: true,
      token: "YOUR_BOT_TOKEN"
    }
  }
}
```

#### 5. Obtain Discord IDs

Enable **Developer Mode**: User Settings > Advanced > Developer Mode
Right-click to copy Server ID, Channel ID, User ID.

#### 6. Guild Configuration
```json5
{
  channels: {
    discord: {
      enabled: true,
      dm: { enabled: false },
      guilds: {
        "YOUR_GUILD_ID": {
          users: ["YOUR_USER_ID"],
          requireMention: true,
          channels: {
            help: {
              allow: true,
              requireMention: true
            }
          }
        }
      }
    }
  }
}
```

### Device Pairing Workflow

The gateway manages device pairing for iOS/Android/macOS and headless nodes.

**Commands:**
```bash
openclaw devices list
openclaw devices approve <requestId>
openclaw devices reject <requestId>
```

**State Storage:**
- `~/.openclaw/devices/pending.json` - Temporary, expires after set duration
- `~/.openclaw/devices/paired.json` - Approved devices with auth tokens

---

## 5. Skills System

### Directory Structure & Precedence

1. **Workspace skills** (`<workspace>/skills`) - highest priority
2. **Managed/local skills** (`~/.openclaw/skills`)
3. **Bundled skills** - shipped with installation (lowest priority)

Additional folders via `skills.load.extraDirs`.

### SKILL.md Format

Each skill requires a directory containing a `SKILL.md` file:

```markdown
---
name: skill-name
description: Brief description of what the skill does
homepage: https://example.com
user-invocable: true
disable-model-invocation: false
command-dispatch: tool
command-tool: tool-name
command-arg-mode: raw
metadata: {"openclaw": {"requires": {"bins": ["binary"]}, "emoji": "X", "os": ["darwin", "linux"]}}
---

# Skill Name

Detailed instructions for the model...
```

### Frontmatter Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `name` | string | required | Skill identifier |
| `description` | string | required | Brief description |
| `homepage` | string | optional | URL for macOS UI |
| `user-invocable` | boolean | true | Expose as slash command |
| `disable-model-invocation` | boolean | false | Exclude from model prompt |
| `command-dispatch` | string | - | `tool` for direct dispatch |
| `command-tool` | string | - | Tool name for dispatch |
| `command-arg-mode` | string | - | `raw` for raw arguments |
| `metadata` | JSON | - | Single-line JSON object |

### Metadata Structure

```json
{
  "openclaw": {
    "always": false,
    "emoji": "X",
    "os": ["darwin", "linux"],
    "requires": {
      "bins": ["binary-name"],
      "anyBins": ["alt1", "alt2"],
      "env": ["ENV_VAR"],
      "config": ["setting.path"]
    },
    "primaryEnv": "ENV_VAR",
    "install": {}
  }
}
```

### Skills Configuration

```json5
{
  skills: {
    entries: {
      "skill-name": {
        enabled: true,
        apiKey: "SECRET_KEY",
        env: { ENV_VAR: "value" },
        config: { customField: "value" }
      }
    },
    load: {
      watch: true,
      watchDebounceMs: 250,
      extraDirs: ["/path/to/skills"]
    }
  }
}
```

### ClawHub Registry

```bash
clawhub install <skill-slug>
clawhub update --all
clawhub sync --all
```

Browse: https://clawhub.com

### Token Impact

- Base overhead: ~195 characters (when >=1 skill eligible)
- Per skill: ~97 characters + escaped field lengths
- Rough estimate: ~24 tokens per skill

---

## 6. Session Management

### Session Scoping

**DM Scope Options (`session.dmScope`):**

| Value | Description |
|-------|-------------|
| `main` | All DMs share main session (default) |
| `per-peer` | Isolate by sender ID across channels |
| `per-channel-peer` | Isolate by channel + sender (recommended for shared inboxes) |
| `per-account-channel-peer` | Isolate by account + channel + sender |

### Reset Policies

```json5
{
  session: {
    reset: {
      mode: "daily",      // "daily" | "idle"
      atHour: 4,          // For daily mode (4:00 AM local)
      idleMinutes: 120    // For idle mode
    },
    resetByType: {
      thread: { mode: "daily", atHour: 4 },
      dm: { mode: "idle", idleMinutes: 240 },
      group: { mode: "idle", idleMinutes: 120 }
    },
    resetByChannel: {
      discord: { mode: "idle", idleMinutes: 10080 }
    }
  }
}
```

### Manual Reset Triggers

- `/new` or `/reset` commands
- Custom entries in `resetTriggers`

### Identity Links

Maintain unified sessions across channels:

```json5
{
  session: {
    identityLinks: {
      alice: ["telegram:123456789", "discord:987654321012345678"]
    }
  }
}
```

### Session Commands

```bash
openclaw status                          # Store path and recent sessions
openclaw sessions --json                 # Export all entries
openclaw gateway call sessions.list      # Query running gateway
```

**Chat Commands:**
- `/status` - Check agent reachability
- `/context list` - Show system prompt and workspace files
- `/stop` - Abort current run
- `/compact` - Summarize older context

---

## 7. Memory System

### Memory File Structure

```
~/.openclaw/workspace/
├── MEMORY.md               # Long-term curated memory
└── memory/
    └── YYYY-MM-DD.md       # Daily append-only logs
```

### When to Write Memory

- **MEMORY.md**: Decisions, preferences, durable facts
- **memory/YYYY-MM-DD.md**: Running context, daily notes
- Explicit "remember this" requests should be written

### Vector Memory Search

```json5
{
  agents: {
    defaults: {
      memorySearch: {
        enabled: true,
        provider: "auto",             // "auto" | "local" | "openai" | "gemini"
        extraPaths: ["../team-docs"],
        query: {
          hybrid: {
            enabled: true,
            vectorWeight: 0.7,
            textWeight: 0.3,
            candidateMultiplier: 4
          }
        }
      }
    }
  }
}
```

### Provider Configuration Examples

**Gemini:**
```json5
{
  memorySearch: {
    provider: "gemini",
    model: "gemini-embedding-001",
    remote: {
      apiKey: "YOUR_GEMINI_API_KEY"
    }
  }
}
```

**OpenAI:**
```json5
{
  memorySearch: {
    provider: "openai",
    model: "text-embedding-3-small",
    remote: {
      baseUrl: "https://api.openai.com/v1/",
      apiKey: "YOUR_API_KEY"
    }
  }
}
```

**Local:**
```json5
{
  memorySearch: {
    provider: "local",
    local: {
      modelPath: "hf:ggml-org/embeddinggemma-300M-GGUF/model.gguf"
    }
  }
}
```

### Memory Tools

| Tool | Description |
|------|-------------|
| `memory_search` | Semantic search across memory files |
| `memory_get` | Read specific memory files by path |

### Automatic Memory Flush

```json5
{
  agents: {
    defaults: {
      compaction: {
        memoryFlush: {
          enabled: true,
          softThresholdTokens: 4000,
          systemPrompt: "Session nearing compaction. Store durable memories now."
        }
      }
    }
  }
}
```

---

## 8. Browser Automation

### Browser Configuration

```json5
{
  browser: {
    enabled: true,
    defaultProfile: "chrome",
    headless: false,
    noSandbox: false,
    attachOnly: false,
    executablePath: "/path/to/browser",
    evaluateEnabled: true,
    remoteCdpTimeoutMs: 1500,
    profiles: {
      openclaw: { cdpPort: 18800, color: "#FF4500" },
      work: { cdpPort: 18801, color: "#0066CC" },
      remote: { cdpUrl: "http://10.0.0.42:9222" }
    }
  }
}
```

### Browser Profile Types

1. **OpenClaw-managed**: Dedicated Chromium with isolated user data
2. **Chrome extension relay**: Controls existing Chrome tabs via extension

### CLI Commands

```bash
# Basic operations
openclaw browser status
openclaw browser start
openclaw browser tabs
openclaw browser open https://example.com
openclaw browser snapshot
openclaw browser screenshot --full-page

# Actions (require snapshot refs)
openclaw browser click 12 --double
openclaw browser type 23 "hello" --submit
openclaw browser navigate https://example.com
openclaw browser select 9 OptionA OptionB

# State management
openclaw browser cookies
openclaw browser set offline on
openclaw browser set headers --json '{"X-Debug":"1"}'
openclaw browser set geo 37.7749 -122.4194
openclaw browser set timezone America/New_York
```

### Snapshot Reference System

- **AI snapshot**: Numeric refs (`aria-ref="12"`) for Playwright actions
- **Role snapshot**: Accessibility-tree refs (`e12`) with `getByRole()` resolution
- Refs are NOT stable across navigations; re-run `snapshot` after navigation

### Security Considerations

- Browser control is loopback-only
- Use isolated profile (default: `openclaw`)
- Avoid personal browser profiles
- Disable browser proxy routing when unused: `gateway.nodes.browser.mode="off"`

---

## 9. Model Failover

### Two-Stage Failover Process

1. **Auth profile rotation** within current provider
2. **Model fallback** to next model in `fallbacks` list

### Configuration

```json5
{
  agents: {
    defaults: {
      model: {
        primary: "anthropic/claude-opus-4-5",
        fallbacks: ["openai/gpt-4o", "anthropic/claude-sonnet-4"]
      }
    }
  },
  auth: {
    order: {
      anthropic: ["oauth-profile", "api-key-profile"]
    },
    cooldowns: {
      billingBackoffHours: 5
    }
  }
}
```

### Auth Profile Storage

- Primary: `~/.openclaw/agents/<agentId>/agent/auth-profiles.json`
- Legacy: `~/.openclaw/agent/auth-profiles.json`
- OAuth import: `~/.openclaw/credentials/oauth.json`

### Cooldown Management

Failed profiles enter exponential backoff:
- 1, 5, 25 minutes, then 1 hour (maximum)
- Billing failures: 5 hours starting, doubling per failure, capped at 24 hours

---

## 10. Docker Deployment

### Quick Start

```bash
./docker-setup.sh
```

This automates:
- Building the gateway image
- Running onboarding
- Starting Docker Compose
- Generating authentication tokens

### Manual Setup

```bash
docker build -t openclaw:local -f Dockerfile .
docker compose run --rm openclaw-cli onboard
docker compose up -d openclaw-gateway
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `OPENCLAW_DOCKER_APT_PACKAGES` | Space-separated apt packages to install |
| `OPENCLAW_EXTRA_MOUNTS` | Comma-separated Docker bind mounts |
| `OPENCLAW_HOME_VOLUME` | Named volume for `/home/node` persistence |
| `OPENCLAW_IMAGE` | Docker image name |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway authentication token |
| `OPENCLAW_GATEWAY_BIND` | Network binding mode |
| `OPENCLAW_GATEWAY_PORT` | Gateway port |
| `OPENCLAW_CONFIG_DIR` | Config directory path |
| `OPENCLAW_WORKSPACE_DIR` | Workspace directory path |
| `GOG_KEYRING_PASSWORD` | Keyring password |

### Example with Extra Mounts

```bash
export OPENCLAW_EXTRA_MOUNTS="$HOME/.codex:/home/node/.codex:ro,$HOME/github:/home/node/github:rw"
./docker-setup.sh
```

### Channel Setup in Docker

```bash
docker compose run --rm openclaw-cli channels login           # WhatsApp
docker compose run --rm openclaw-cli channels add --channel telegram --token "<token>"
docker compose run --rm openclaw-cli channels add --channel discord --token "<token>"
```

### Health Check

```bash
docker compose exec openclaw-gateway node dist/index.js health --token "$OPENCLAW_GATEWAY_TOKEN"
```

---

## 11. VPS Deployment (Hetzner/Proxmox)

### Initial Setup

```bash
# As root
apt-get update
apt-get install -y git curl ca-certificates

# Install Docker
curl -fsSL https://get.docker.com | sh

# Verify
docker --version
docker compose version
```

### Repository Setup

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# Create directories
mkdir -p /root/.openclaw
mkdir -p /root/.openclaw/workspace
chown -R 1000:1000 /root/.openclaw
chown -R 1000:1000 /root/.openclaw/workspace
```

### Environment File

Create `.env`:
```bash
OPENCLAW_IMAGE=openclaw:latest
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_CONFIG_DIR=/root/.openclaw
OPENCLAW_WORKSPACE_DIR=/root/.openclaw/workspace
GOG_KEYRING_PASSWORD=$(openssl rand -hex 32)
XDG_CONFIG_HOME=/home/node/.openclaw
```

### Network Configuration

**Loopback-only (default, recommended):**
The compose file binds to `127.0.0.1:18789`. Access remotely via SSH tunnel:
```bash
ssh -N -L 18789:127.0.0.1:18789 root@YOUR_VPS_IP
```

**LAN exposure (requires strong auth + firewall):**
Remove loopback prefix and implement firewall controls.

### Build and Launch

```bash
docker compose build
docker compose up -d openclaw-gateway
```

### Binary Persistence

External binaries must be baked into the image at build time. Runtime installations vanish on restart.

### Verify Installation

```bash
docker compose exec openclaw-gateway which gog
```

### Proxmox-Specific Considerations

For Proxmox LXC containers:
1. Use a privileged container or enable nesting for Docker
2. Ensure adequate memory allocation (minimum 2GB recommended)
3. Configure Tailscale within the container for secure remote access
4. Use persistent storage for `/root/.openclaw` directory

---

## 12. Command Reference

### Gateway Commands

```bash
openclaw gateway                     # Start gateway
openclaw gateway --port 18789        # Specify port
openclaw status                      # Check status
openclaw status --all                # Detailed status
openclaw health --json               # JSON health output
openclaw doctor                      # Diagnostics
```

### Channel Commands

```bash
openclaw channels login              # WhatsApp login
openclaw channels status --probe     # Channel status
openclaw channels add --channel telegram --token "<token>"
openclaw channels add --channel discord --token "<token>"
```

### Device/Pairing Commands

```bash
openclaw devices list
openclaw devices approve <requestId>
openclaw devices reject <requestId>
openclaw pairing list <channel>
openclaw pairing approve <channel> <code>
```

### Browser Commands

```bash
openclaw browser status
openclaw browser start
openclaw browser tabs
openclaw browser open <url>
openclaw browser snapshot
openclaw browser screenshot --full-page
openclaw browser click <ref>
openclaw browser type <ref> "text"
```

### Session Commands

```bash
openclaw sessions --json
openclaw gateway call sessions.list
```

### Security Commands

```bash
openclaw security audit
openclaw security audit --deep
openclaw security audit --fix
```

### Webhook Commands

```bash
openclaw webhooks gmail setup --account you@gmail.com
```

### Chat Slash Commands

| Command | Description |
|---------|-------------|
| `/new`, `/reset` | Reset session |
| `/status` | Check reachability |
| `/context list` | Show system prompt |
| `/stop` | Abort current run |
| `/compact` | Summarize context |
| `/send on/off/inherit` | Control send policy |
| `/model` | Change model |

---

## Changes from Pre-2025 Knowledge

### Major Changes Identified

1. **Node.js Requirement**: Now requires Node.js >= 22 (previously lower versions)

2. **Configuration Format**: Uses JSON5 format for `openclaw.json`, allowing comments and trailing commas

3. **Multi-Agent Architecture**: Full support for multiple agents with independent sandboxing, workspaces, and tool policies

4. **Memory System**: Vector-based semantic search with embedding providers (local, OpenAI, Gemini)

5. **Sandbox Modes**: Three-level sandboxing (`off`, `all`) with configurable workspace access (`none`, `ro`, `rw`)

6. **Session Scoping**: Four DM scope options for session isolation

7. **Tool Profiles**: Pre-defined tool sets (`minimal`, `coding`, `messaging`, `full`)

8. **ClawHub Registry**: Public skills registry at clawhub.com

9. **Browser Automation**: Unified browser tool with profile support and CDP integration

10. **Model Failover**: Two-stage failover with auth profile rotation and model fallback

11. **Security Audit**: Built-in `openclaw security audit` command with auto-remediation

12. **Pairing System**: DM policy options including `pairing` mode with time-limited codes

---

## Quick Start Checklist

1. [ ] Install Node.js >= 22 and pnpm
2. [ ] Clone repository or install globally
3. [ ] Run `openclaw setup`
4. [ ] Create `~/.openclaw/openclaw.json` with basic config
5. [ ] Generate gateway token: `openssl rand -hex 32`
6. [ ] Set up at least one channel (WhatsApp/Telegram/Discord)
7. [ ] Configure security (sandbox mode, allowlists)
8. [ ] Run `openclaw security audit`
9. [ ] Start gateway: `openclaw gateway`
10. [ ] Test with a message

---

*Research conducted: 2026-02-01*
*Documentation source: https://docs.openclaw.ai*
