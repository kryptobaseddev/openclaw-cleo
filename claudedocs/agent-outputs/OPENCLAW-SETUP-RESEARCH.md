# OpenClaw Setup Command and Requirements Research

**Task**: Research OpenClaw setup command and requirements
**Date**: 2026-02-02
**Status**: complete

---

## Executive Summary

OpenClaw requires a two-step initialization process: `openclaw setup` (config/workspace initialization) followed by `openclaw onboard` (full wizard). The container is currently failing to start because it requires either a valid config at `~/.openclaw/openclaw.json` with `gateway.mode=local` OR the `--allow-unconfigured` flag. **No Claude API keys or secrets are required for setup** - authentication is handled through OAuth flows during the onboarding wizard.

## Setup Command Options

### `openclaw setup`

**Purpose**: Initialize `~/.openclaw/openclaw.json` and agent workspace

**Usage**:
```bash
openclaw setup [options]
```

**Flags**:
- `--workspace <dir>` - Agent workspace directory (default: `~/.openclaw/workspace`)
  - Stored as `agents.defaults.workspace` in config
- `--wizard` - Run the interactive onboarding wizard
- `--non-interactive` - Run the wizard without prompts
- `--mode <mode>` - Wizard mode: `local` or `remote`
- `--remote-url <url>` - Remote Gateway WebSocket URL
- `--remote-token <token>` - Remote Gateway token (optional)

**Behavior**:
- Creates `~/.openclaw/openclaw.json` if missing
- Sets default workspace path
- Creates workspace directory with bootstrap files
- Creates sessions directory at `~/.openclaw/agents/<agentId>/sessions/`
- Non-destructive: won't overwrite existing config unless values change

**Source**: `src/commands/setup.ts` (lines 27-75)

### `openclaw onboard`

**Purpose**: Full onboarding wizard (recommended first-run experience)

**Usage**:
```bash
openclaw onboard [options]
```

**Key Flags**:
- `--non-interactive` - Skip prompts (requires `--accept-risk`)
- `--accept-risk` - Acknowledge security implications
- `--auth-choice <method>` - Authentication method: `token`, `oauth`, `openai-codex`
- `--flow <type>` - Onboarding flow: `simple`, `advanced`
- `--install-daemon` - Install Gateway as system service (launchd/systemd)
- `--reset` - Clear existing config and workspace
- `--workspace <dir>` - Set workspace directory

**Source**: `src/commands/onboard.ts`, `src/cli/program/register.setup.ts`

---

## Required Configuration

### Minimal Config (Non-Interactive Setup)

The Gateway requires ONE of the following to start:

**Option 1: Config with gateway mode**
```json5
{
  gateway: { mode: "local" }
}
```

**Option 2: Pass flag**
```bash
openclaw gateway --allow-unconfigured
```

**Current Failure**: Container logs show:
```
Missing config. Run `openclaw setup` or set gateway.mode=local (or pass --allow-unconfigured).
```

### Recommended Minimal Config

```json5
{
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace"
    }
  },
  gateway: {
    mode: "local",
    port: 18789,
    bind: "lan"  // For Docker: "lan" (0.0.0.0) or "loopback" (127.0.0.1)
  }
}
```

**File Location**: `~/.openclaw/openclaw.json` (JSON5 format - comments and trailing commas allowed)

### For Multi-Channel Setup

```json5
{
  agents: {
    defaults: { workspace: "~/.openclaw/workspace" }
  },
  channels: {
    whatsapp: {
      allowFrom: ["+15555550123"]  // DM allowlist (pairing mode by default)
    },
    telegram: {
      // Bot token from environment or tokenFile
    },
    discord: {
      // Bot token from environment
    }
  },
  gateway: {
    mode: "local",
    port: 18789,
    bind: "lan"
  }
}
```

---

## Optional Configuration

### Environment Variables

**From `.env.example` and docker-compose.yml**:

| Variable | Purpose | Required | Default | Notes |
|----------|---------|----------|---------|-------|
| `OPENCLAW_GATEWAY_TOKEN` | Gateway authentication token | No | (none) | For `gateway.auth.mode="token"` |
| `CLAUDE_AI_SESSION_KEY` | Anthropic OAuth session | No | (none) | Obtained via onboard wizard |
| `CLAUDE_WEB_SESSION_KEY` | Claude web session (legacy) | No | (none) | Deprecated - use OAuth |
| `CLAUDE_WEB_COOKIE` | Claude web cookie (legacy) | No | (none) | Deprecated - use OAuth |
| `OPENCLAW_CONFIG_DIR` | Config directory mount | No | `~/.openclaw` | Docker volume mapping |
| `OPENCLAW_WORKSPACE_DIR` | Workspace directory mount | No | `~/.openclaw/workspace` | Docker volume mapping |
| `OPENCLAW_GATEWAY_PORT` | Gateway WebSocket port | No | `18789` | Matches docker-compose |
| `OPENCLAW_BRIDGE_PORT` | Bridge port | No | `18790` | For node connections |
| `OPENCLAW_GATEWAY_BIND` | Bind mode | No | `lan` | `auto`, `lan`, `loopback`, `tailnet`, `custom` |
| `OPENCLAW_IMAGE` | Docker image name | No | `openclaw:local` | Built image tag |
| `HOME` | User home directory | Yes | `/home/node` | Set by Docker |
| `TERM` | Terminal type | No | `xterm-256color` | For proper CLI rendering |
| `BROWSER` | Browser command | No | `echo` | Disable browser launch in container |

**Twilio/WhatsApp (Extension Only)**:
- `TWILIO_ACCOUNT_SID` - Twilio account SID (if using Twilio)
- `TWILIO_AUTH_TOKEN` - Twilio auth token
- `TWILIO_WHATSAPP_FROM` - WhatsApp-enabled Twilio number (format: `whatsapp:+1234567890`)

**Note**: OpenClaw uses Baileys (WhatsApp Web protocol) by default - **Twilio is NOT required**.

### Gateway Configuration Schema

**Key Gateway Options** (`gateway` object in config):

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `mode` | `"local"` \| `"remote"` | Gateway operation mode | (required) |
| `port` | number | WebSocket + HTTP port | `18789` |
| `bind` | `"auto"` \| `"lan"` \| `"loopback"` \| `"tailnet"` \| `"custom"` | Network bind mode | `loopback` |
| `customBindHost` | string | Custom IP for `bind="custom"` | - |
| `auth.mode` | `"token"` \| `"password"` | Auth method | (none) |
| `auth.token` | string | Shared token for CLI auth | - |
| `auth.password` | string | Shared password | - |
| `controlUi.enabled` | boolean | Serve Control UI at `/` | `true` |
| `tls.enabled` | boolean | Enable TLS/HTTPS | `false` |
| `reload.mode` | `"off"` \| `"restart"` \| `"hot"` \| `"hybrid"` | Config reload strategy | `hybrid` |

**Source**: `src/config/types.gateway.ts` (lines 1-245)

### Agents Configuration

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `agents.defaults.workspace` | string | Default workspace path | `~/.openclaw/workspace` |
| `agents.defaults.skipBootstrap` | boolean | Skip workspace bootstrap files | `false` |
| `agents.list[].id` | string | Agent identifier | `main` |
| `agents.list[].identity` | object | Per-agent identity/avatar | - |
| `agents.list[].groupChat.mentionPatterns` | string[] | Text triggers for groups | `["@openclaw"]` |

### Channel Configuration

**WhatsApp** (`channels.whatsapp`):
- `allowFrom` - Array of allowed phone numbers (format: `+1234567890`)
- `groups."*".requireMention` - Require @mention in groups (default: `true`)
- Credentials stored at: `~/.openclaw/credentials/whatsapp/<accountId>/creds.json`

**Telegram** (`channels.telegram`):
- Bot token from environment `TELEGRAM_BOT_TOKEN` or `tokenFile`
- `allowFrom` - Array of allowed usernames/IDs
- `groups` - Group allowlist configuration

**Discord** (`channels.discord`):
- Bot token from environment `DISCORD_BOT_TOKEN`
- `guilds` - Server allowlist
- `dm.policy` - `"pairing"` (default) or `"open"`

**Slack** (`channels.slack`):
- OAuth tokens from environment
- Bolt framework integration

### Model Configuration

**No API keys required for setup** - handled by OAuth during onboard:

```json5
{
  models: {
    // Model failover and routing
    defaults: {
      provider: "anthropic",  // or "openai"
      model: "claude-opus-4-5"
    }
  }
}
```

**Authentication Methods**:
1. **OAuth** (recommended) - Set up via `openclaw onboard`
   - Anthropic Claude Pro/Max subscription
   - OpenAI ChatGPT subscription
2. **API Keys** - Via `auth-profiles.json`
3. **Setup Token** - Anthropic session token

**Storage**: `~/.openclaw/agents/<agentId>/agent/auth-profiles.json`

---

## Scriptable Setup (Non-Interactive)

### Option 1: Pre-Create Config File

```bash
# Create config directory
mkdir -p ~/.openclaw

# Write minimal config
cat > ~/.openclaw/openclaw.json <<'EOF'
{
  "gateway": { "mode": "local", "bind": "lan" },
  "agents": { "defaults": { "workspace": "~/.openclaw/workspace" } }
}
EOF

# Run setup to initialize workspace
openclaw setup

# Start gateway
openclaw gateway --port 18789
```

### Option 2: Use `--allow-unconfigured` Flag

```bash
# Skip config requirement
openclaw gateway --allow-unconfigured --bind lan --port 18789
```

### Option 3: Non-Interactive Onboard

```bash
# Full automated onboard (requires auth setup separately)
openclaw onboard \
  --non-interactive \
  --accept-risk \
  --mode local \
  --workspace ~/.openclaw/workspace \
  --install-daemon
```

**Requirements for `--non-interactive`**:
- Must include `--accept-risk` flag
- Authentication must be configured separately (OAuth flow cannot be automated)
- Recommended: Pre-configure channels via config file

---

## Docker-Specific Setup

### Current Container Configuration

**docker-compose.yml Analysis**:

```yaml
services:
  openclaw-gateway:
    image: openclaw:local
    environment:
      HOME: /home/node
      TERM: xterm-256color
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
      CLAUDE_AI_SESSION_KEY: ${CLAUDE_AI_SESSION_KEY}
      # ... other env vars
    volumes:
      - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
    ports:
      - "18789:18789"  # Gateway WS + HTTP
      - "18790:18790"  # Bridge port
    command: [
      "node", "dist/index.js", "gateway",
      "--bind", "${OPENCLAW_GATEWAY_BIND:-lan}",
      "--port", "${OPENCLAW_GATEWAY_PORT:-18789}"
    ]
```

**Missing**: `--allow-unconfigured` flag or mounted config file

### Recommended Docker Setup Workflow

**Step 1: Create config on host**
```bash
mkdir -p /opt/openclaw/config
cat > /opt/openclaw/config/openclaw.json <<'EOF'
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/home/node/.openclaw/workspace"
    }
  }
}
EOF
```

**Step 2: Update docker-compose.yml**
```yaml
environment:
  OPENCLAW_CONFIG_DIR: /opt/openclaw/config
  OPENCLAW_WORKSPACE_DIR: /opt/openclaw/workspace
  OPENCLAW_GATEWAY_TOKEN: "your-secure-token-here"  # Generate via: openssl rand -hex 32
```

**OR** add flag to command:
```yaml
command: [
  "node", "dist/index.js", "gateway",
  "--bind", "lan",
  "--port", "18789",
  "--allow-unconfigured"
]
```

**Step 3: Initialize workspace (one-time)**
```bash
docker exec openclaw-openclaw-gateway-1 openclaw setup
```

---

## Recommended Approach for Automation

### For Install Script Integration

**Priority 1: Minimal Working Setup**
```bash
# 1. Create config directory in container mount
mkdir -p "${OPENCLAW_CONFIG_DIR:-/opt/openclaw/config}"

# 2. Generate gateway token if auth enabled
if [[ -n "$ENABLE_GATEWAY_AUTH" ]]; then
  OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
  export OPENCLAW_GATEWAY_TOKEN
fi

# 3. Write minimal config
cat > "${OPENCLAW_CONFIG_DIR}/openclaw.json" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789
  },
  "agents": {
    "defaults": {
      "workspace": "/home/node/.openclaw/workspace"
    }
  }
}
EOF

# 4. Start container (config will be mounted)
docker-compose up -d

# 5. Wait for gateway to be ready
timeout 30 bash -c 'until docker exec openclaw-openclaw-gateway-1 openclaw health 2>/dev/null; do sleep 2; done'

# 6. Run setup inside container
docker exec openclaw-openclaw-gateway-1 openclaw setup

# 7. Verify
docker exec openclaw-openclaw-gateway-1 openclaw status
```

**Priority 2: Interactive Onboarding (Post-Install)**
```bash
# Provide user instructions for completing setup
cat <<'INSTRUCTIONS'
OpenClaw base system installed successfully!

To complete setup, run the onboarding wizard:
  docker exec -it openclaw-openclaw-gateway-1 openclaw onboard

Or from inside the container:
  docker exec -it openclaw-openclaw-gateway-1 bash
  openclaw onboard

The wizard will guide you through:
  1. Model authentication (Anthropic/OpenAI OAuth)
  2. Channel setup (WhatsApp/Telegram/Discord/etc.)
  3. Skills and workspace configuration

Access Control UI at: http://CONTAINER_IP:18789
INSTRUCTIONS
```

### Validation Gates

```bash
# Check 1: Config exists and is valid
docker exec openclaw-openclaw-gateway-1 test -f /home/node/.openclaw/openclaw.json
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: Config file missing"
fi

# Check 2: Gateway can start
docker exec openclaw-openclaw-gateway-1 openclaw health
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: Gateway not responding"
fi

# Check 3: Workspace initialized
docker exec openclaw-openclaw-gateway-1 test -d /home/node/.openclaw/workspace
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: Workspace not initialized"
fi

# Check 4: Sessions directory exists
docker exec openclaw-openclaw-gateway-1 test -d /home/node/.openclaw/agents
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "WARNING: Agents directory missing (will be created on first use)"
fi
```

---

## Key Findings

1. **`openclaw setup` is non-interactive by default** - safe for automation
   - Only creates config if missing
   - Sets workspace path
   - Initializes directory structure

2. **No secrets required for base setup**
   - Config file only needs `gateway.mode="local"`
   - Authentication handled separately via OAuth
   - API keys optional (OAuth preferred)

3. **`--allow-unconfigured` bypass available**
   - Can start gateway without config file
   - Useful for testing/development
   - Not recommended for production

4. **Container failing due to missing config**
   - Current docker-compose.yml missing config initialization
   - Need to either:
     - Mount pre-created config file
     - Add `--allow-unconfigured` flag
     - Run `openclaw setup` before gateway start

5. **Onboard wizard cannot be fully automated**
   - OAuth flows require user interaction
   - `--non-interactive` mode still needs pre-configured auth
   - Best approach: Install base system, prompt user for onboard

6. **Configuration is strict by default**
   - Unknown keys cause validation failure
   - Gateway refuses to start on invalid config
   - Use `openclaw doctor --fix` for migrations

---

## Configuration Storage Map

| Data Type | Location | Backed Up? | Notes |
|-----------|----------|------------|-------|
| Config | `~/.openclaw/openclaw.json` | Yes | JSON5 format |
| Workspace | `~/.openclaw/workspace/` | Yes | Skills, prompts, memories |
| Credentials | `~/.openclaw/credentials/` | **YES** | WhatsApp, OAuth tokens |
| Sessions | `~/.openclaw/agents/<id>/sessions/` | No | Pi session transcripts |
| Auth Profiles | `~/.openclaw/agents/<id>/agent/auth-profiles.json` | **YES** | Model API keys |
| Logs | `/tmp/openclaw/` | No | Temporary runtime logs |
| Allowlists | `~/.openclaw/credentials/<channel>-allowFrom.json` | Yes | Pairing approvals |

**Docker Note**: All `~/.openclaw` paths resolve to `/home/node/.openclaw` inside container

---

## Documentation References

- Setup command: `docs/cli/setup.md`
- Getting started: `docs/start/getting-started.md`
- Onboarding wizard: `docs/start/onboarding.md`, `docs/start/wizard.md`
- Configuration reference: `docs/gateway/configuration.md`
- Docker setup: `docs/install/docker.md`
- Security defaults: `docs/gateway/security.md`
- Troubleshooting: `docs/gateway/troubleshooting.md`

---

## Actionable Recommendations

### For `install.sh` Script

1. **Add config initialization step** before container start:
   ```bash
   msg_info "Creating OpenClaw configuration"
   mkdir -p "${OPENCLAW_CONFIG_DIR}"
   cat > "${OPENCLAW_CONFIG_DIR}/openclaw.json" <<'EOF'
   {"gateway":{"mode":"local","bind":"lan"},"agents":{"defaults":{"workspace":"~/.openclaw/workspace"}}}
   EOF
   msg_ok "Configuration created"
   ```

2. **OR modify docker-compose command** to include bypass flag:
   ```yaml
   command: ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789", "--allow-unconfigured"]
   ```

3. **Run setup after container starts**:
   ```bash
   msg_info "Initializing OpenClaw workspace"
   docker exec openclaw-openclaw-gateway-1 openclaw setup
   msg_ok "Workspace initialized"
   ```

4. **Provide post-install instructions**:
   ```bash
   cat <<BANNER
   ${GN}OpenClaw installed successfully!${CL}

   Container IP: ${CONTAINER_IP}
   Gateway Port: 18789

   ${YW}Next Steps:${CL}
   1. Complete onboarding:
      docker exec -it openclaw-openclaw-gateway-1 openclaw onboard

   2. Access Control UI:
      http://${CONTAINER_IP}:18789

   3. Check status:
      docker exec openclaw-openclaw-gateway-1 openclaw status
   BANNER
   ```

5. **Optional: Generate gateway token**:
   ```bash
   if [[ "$ENABLE_GATEWAY_AUTH" == "yes" ]]; then
     OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
     echo "Gateway Token: ${OPENCLAW_GATEWAY_TOKEN}" >> /root/openclaw-credentials.txt
     # Update config with token
   fi
   ```

### Testing Validation

Before considering setup complete:
- [ ] Config file exists and is valid JSON
- [ ] Gateway responds to `openclaw health`
- [ ] Workspace directory created with bootstrap files
- [ ] Sessions directory exists
- [ ] Control UI accessible at `http://IP:18789`
- [ ] No errors in `docker logs openclaw-openclaw-gateway-1`

---

## Summary

OpenClaw setup is straightforward and automation-friendly:
- **Core requirement**: Config file with `gateway.mode="local"` OR `--allow-unconfigured` flag
- **No secrets needed**: Authentication via post-install wizard
- **Docker-ready**: Mount config directory, run `openclaw setup`, start gateway
- **Current issue**: Container missing config file, causing restart loop
- **Fix**: Create minimal config before container start or add bypass flag

The recommended approach for `install.sh` is:
1. Create minimal config file in mounted volume
2. Start container with docker-compose
3. Run `openclaw setup` inside container
4. Prompt user to complete `openclaw onboard` for full setup
