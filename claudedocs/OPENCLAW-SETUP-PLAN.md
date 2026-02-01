# OpenClaw Secure Deployment Plan

**Target Environment**: Proxmox VE 8.1.4 (Dell Precision Tower 7910)
**Architecture**: Tiered Node Isolation with CLEO Integration
**Channels**: Telegram + Discord
**Financial**: Privacy.com Virtual Cards

---

## Phase 1: Infrastructure Provisioning

### 1.1 Create Gateway VM

```bash
# On Proxmox host - Create Debian 12 LXC for Gateway
pct create 150 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname openclaw-gateway \
  --memory 8192 \
  --cores 4 \
  --net0 name=eth0,bridge=vmbr0,ip=10.0.10.50/24,gw=10.0.10.1 \
  --storage local-lvm \
  --rootfs local-lvm:32 \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1

# Start and enter
pct start 150
pct enter 150
```

**Gateway VM Specs:**
| Resource | Value | Rationale |
|----------|-------|-----------|
| Cores | 4 | Pi reasoning + WebSocket handling |
| RAM | 8GB | Memory for model context + sessions |
| Storage | 32GB | Brain persistence + skill cache |
| IP | 10.0.10.50 | Static in your reserved range |

### 1.2 Create Execution Node VM

```bash
# Create separate LXC for code execution
pct create 151 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname openclaw-exec \
  --memory 16384 \
  --cores 8 \
  --net0 name=eth0,bridge=vmbr0,ip=10.0.10.51/24,gw=10.0.10.1 \
  --storage local-lvm \
  --rootfs local-lvm:64 \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1

pct start 151
pct enter 151
```

**Exec Node VM Specs:**
| Resource | Value | Rationale |
|----------|-------|-----------|
| Cores | 8 | Compilation, testing, parallel builds |
| RAM | 16GB | Large project builds, multiple repos |
| Storage | 64GB | Cloned repos, build artifacts |
| IP | 10.0.10.51 | Static, isolated from gateway |

### 1.3 Network Security (Optional Firewall Rules)

```bash
# On Proxmox host - restrict exec node outbound
# Only allow necessary ports
cat >> /etc/pve/firewall/151.fw << 'EOF'
[RULES]
# Allow outbound HTTPS (GitHub, npm, etc)
OUT ACCEPT -p tcp --dport 443
OUT ACCEPT -p tcp --dport 22
# Allow inbound from Gateway only
IN ACCEPT -s 10.0.10.50 -p tcp --dport 18789
# Block everything else from exec node
OUT DROP
EOF
```

---

## Phase 2: Gateway Setup

### 2.1 Install Dependencies (Gateway LXC)

```bash
# Update and install Node.js 22
apt update && apt upgrade -y
apt install -y curl git build-essential

# Install Node.js 22 via NodeSource
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Verify
node --version  # Should be v22.x
npm --version
```

### 2.2 Install OpenClaw

```bash
# Install pnpm
npm install -g pnpm

# Install OpenClaw globally
pnpm add -g openclaw

# Verify installation
openclaw --version
```

### 2.3 Configure Directory Structure

```bash
# Create persistent directories
mkdir -p ~/.openclaw/{config,workspace,memory,skills}

# Set proper permissions
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/config/*  # Will apply after config creation
```

### 2.4 Run Onboarding Wizard

```bash
# Interactive setup - will prompt for:
# - LLM provider (Anthropic recommended)
# - API keys
# - Default model (Claude Opus 4.5 for complex coding)
openclaw onboard --install-daemon
```

### 2.5 Initial Configuration

Create `~/.openclaw/openclaw.json`:

```json
{
  "version": "2026.1",
  "gateway": {
    "host": "127.0.0.1",
    "port": 18789,
    "token": "GENERATE_SECURE_TOKEN_HERE"
  },
  "model": {
    "provider": "anthropic",
    "model": "claude-opus-4-5-20251101",
    "apiKey": "${ANTHROPIC_API_KEY}"
  },
  "sandbox": {
    "mode": "all",
    "workspaceAccess": "rw"
  },
  "exec": {
    "security": "allowlist",
    "ask": "on-miss"
  },
  "logging": {
    "level": "info",
    "redactSensitive": "tools"
  },
  "heartbeat": {
    "enabled": true,
    "intervalMinutes": 30
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing"
    },
    "discord": {
      "enabled": true,
      "dmPolicy": "pairing"
    }
  }
}
```

Generate a secure gateway token:
```bash
openssl rand -hex 32
# Copy output to "token" field above
```

---

## Phase 3: Execution Node Setup

### 3.1 Install Dependencies (Exec Node LXC)

```bash
# Same Node.js setup as Gateway
apt update && apt upgrade -y
apt install -y curl git build-essential jq

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
npm install -g pnpm
```

### 3.2 Install Development Tools

```bash
# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
  tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt update && apt install -y gh

# Common build tools
apt install -y python3 python3-pip golang-go

# Authenticate GitHub CLI
gh auth login
```

### 3.3 Install CLEO

```bash
# Clone CLEO to exec node
git clone https://github.com/YOUR_CLEO_REPO ~/.cleo

# Or if CLEO is npm-based:
pnpm add -g cleo-cli

# Verify
cleo --version
```

### 3.4 Install OpenClaw Node Runner

```bash
# Install node runner
pnpm add -g openclaw

# Register as execution node
openclaw node install --name "exec-node-01" --gateway ws://10.0.10.50:18789

# This will prompt for the gateway token
```

### 3.5 Configure Exec Allowlist

Create `~/.openclaw/exec-approvals.json` on the Exec Node:

```json
{
  "version": 1,
  "defaultPolicy": "deny",
  "allowlist": [
    {
      "binary": "/usr/bin/git",
      "args": ["*"],
      "comment": "Git operations"
    },
    {
      "binary": "/usr/bin/gh",
      "args": ["*"],
      "comment": "GitHub CLI"
    },
    {
      "binary": "/usr/bin/npm",
      "args": ["install", "run", "test", "build"],
      "comment": "NPM safe commands only"
    },
    {
      "binary": "/usr/local/bin/pnpm",
      "args": ["install", "run", "test", "build"],
      "comment": "pnpm safe commands only"
    },
    {
      "binary": "/usr/local/bin/cleo",
      "args": ["*"],
      "comment": "CLEO task management"
    },
    {
      "binary": "/usr/bin/jq",
      "args": ["*"],
      "comment": "JSON processing"
    },
    {
      "binary": "/usr/bin/grep",
      "args": ["*"],
      "comment": "Pattern matching"
    },
    {
      "binary": "/usr/bin/sort",
      "args": ["*"],
      "comment": "Safe bin"
    },
    {
      "binary": "/usr/bin/uniq",
      "args": ["*"],
      "comment": "Safe bin"
    }
  ],
  "denylist": [
    {
      "pattern": "rm -rf /*",
      "comment": "Prevent destructive operations"
    },
    {
      "pattern": "chmod 777",
      "comment": "Prevent permission loosening"
    },
    {
      "pattern": "curl | bash",
      "comment": "Prevent pipe-to-shell attacks"
    }
  ]
}
```

---

## Phase 4: Security Hardening

### 4.1 Run Security Audit

```bash
# On Gateway - run built-in audit
openclaw security audit --deep

# Auto-fix common issues
openclaw security audit --deep --fix
```

### 4.2 Configure Sandbox Policy

Update `~/.openclaw/openclaw.json` sandbox section:

```json
{
  "sandbox": {
    "mode": "all",
    "workspaceAccess": "rw",
    "sessionScope": true,
    "networkAccess": {
      "allowed": [
        "api.anthropic.com",
        "api.github.com",
        "registry.npmjs.org",
        "api.telegram.org",
        "discord.com",
        "gateway.discord.gg"
      ]
    }
  }
}
```

### 4.3 Set Up Tailscale VPN (Recommended)

```bash
# On both Gateway and Exec Node
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up

# Enable Tailscale SSH (no raw SSH keys needed)
tailscale up --ssh

# Get Tailscale IPs
tailscale ip -4
```

Update Gateway to use Tailscale for node communication:
```json
{
  "nodes": {
    "exec-node-01": {
      "host": "100.x.x.x",  // Tailscale IP
      "port": 18789
    }
  }
}
```

### 4.4 Optional: Guardrails Proxy

For maximum prompt injection protection:

```bash
# Create separate LXC for guardrails (10.0.10.52)
# Install Glitch or OpenGuardrails

# Point OpenClaw to guardrail proxy
# In openclaw.json:
{
  "model": {
    "baseUrl": "http://10.0.10.52:8080/v1"
  }
}
```

---

## Phase 5: Channel Integration

### 5.1 Telegram Setup

1. **Create Bot via @BotFather**
   - Open Telegram, search @BotFather
   - Send `/newbot`
   - Name: `OpenClaw Assistant`
   - Username: `your_openclaw_bot`
   - Copy the token

2. **Configure in OpenClaw**
   ```bash
   openclaw channel add telegram \
     --token "YOUR_BOT_TOKEN" \
     --dm-policy pairing
   ```

3. **Pair Your Account**
   - Message your bot in Telegram
   - Bot will send pairing code
   - Enter code in Control UI

### 5.2 Discord Setup

1. **Create Discord Application**
   - Go to https://discord.com/developers/applications
   - New Application → Name: `OpenClaw`
   - Bot → Add Bot → Copy Token
   - Enable: Message Content Intent, Server Members Intent

2. **Configure in OpenClaw**
   ```bash
   openclaw channel add discord \
     --token "YOUR_BOT_TOKEN" \
     --dm-policy pairing
   ```

3. **Invite Bot to Server**
   - OAuth2 → URL Generator
   - Scopes: `bot`, `applications.commands`
   - Permissions: Send Messages, Read Message History, Add Reactions
   - Use generated URL to invite

---

## Phase 6: CLEO Skill Integration

### 6.1 Create CLEO Skill Directory

```bash
mkdir -p ~/.openclaw/skills/cleo
```

### 6.2 Create Skill Definition

Create `~/.openclaw/skills/cleo/SKILL.md`:

```markdown
---
name: cleo
description: |
  CLEO Task Management System integration.
  Provides access to RCSD/IVTR lifecycle protocols,
  task discovery, session management, and orchestration.
version: 1.0.0
author: keaton
tools:
  - exec
triggers:
  - task
  - cleo
  - rcsd
  - epic
  - orchestrate
---

# CLEO Task Management Skill

You have access to the CLEO task management system via the `cleo` CLI.
CLEO implements a 2-tier subagent architecture with RCSD/IVTR lifecycle protocols.

## RCSD Pipeline (Setup Phase)
- **Research**: Information gathering and investigation
- **Consensus**: Multi-stakeholder decisions
- **Specification**: Requirements documentation
- **Decomposition**: Task breakdown into atomic units

## Execution Phase
- **Implementation**: Code and deliverable creation
- **Contribution**: Work attribution and PRs
- **Release**: Version management

## Essential Commands

### Task Discovery (ALWAYS use these for efficiency)
```bash
cleo find "query"           # Fuzzy search (minimal context)
cleo find --id 1234         # ID search
cleo show T1234             # Full task details
```

### Session Management (REQUIRED workflow)
```bash
cleo session list           # Check existing sessions FIRST
cleo session status         # Current session
cleo session start --scope epic:T001 --auto-focus --name "Work"
cleo session end --note "Progress summary"
```

### Task Operations
```bash
cleo add "Task title"       # Create task
cleo add "Subtask" --parent T001  # Create subtask
cleo complete T1234         # Complete task
cleo focus set T1234        # Set active task
cleo next                   # Get next suggested task
```

### Orchestration
```bash
cleo orchestrator start --epic T001    # Initialize orchestration
cleo orchestrator analyze T001         # Dependency waves
cleo orchestrator spawn T002           # Generate spawn prompt
```

## Lifecycle Enforcement

CLEO enforces RCSD progression. You cannot spawn implementation tasks
until research/consensus/specification stages are complete.

## Output Requirements

When working on CLEO tasks:
1. MUST set focus before starting: `cleo focus set T1234`
2. MUST complete task when done: `cleo complete T1234`
3. SHOULD use `cleo find` over `cleo list` (99% less context)

## Error Handling

Check exit codes after every command:
- 0 = success
- 4 = E_NOT_FOUND (use `cleo find` to verify)
- 38 = E_FOCUS_REQUIRED (add --auto-focus)
- 100 = E_SESSION_DISCOVERY_MODE (run `cleo session list` first)
```

### 6.3 Install Additional Skills

```bash
# Clone awesome-openclaw-skills
git clone https://github.com/VoltAgent/awesome-openclaw-skills ~/openclaw-skills

# Link useful skills
ln -s ~/openclaw-skills/github ~/.openclaw/skills/
ln -s ~/openclaw-skills/github-pr ~/.openclaw/skills/
```

### 6.4 Verify Skill Loading

```bash
openclaw skill list
# Should show: cleo, github, github-pr
```

---

## Phase 7: Financial Setup (Privacy.com)

### 7.1 Create Dedicated Virtual Cards

In Privacy.com, create cards with these settings:

| Card Purpose | Merchant Lock | Per-Transaction Limit | Monthly Limit |
|--------------|---------------|----------------------|---------------|
| AI API Costs | Anthropic | $50 | $200 |
| Cloud Services | AWS/GCP/DO | $100 | $500 |
| Dev Tools | GitHub/Vercel | $25 | $100 |
| One-Time Purchases | First merchant | Single-use | N/A |

### 7.2 Configure in OpenClaw

Create `~/.openclaw/config/financial.json` (mode 600):

```json
{
  "cards": {
    "ai_api": {
      "last4": "1234",
      "purpose": "LLM API costs only",
      "monthlyLimit": 200
    },
    "cloud": {
      "last4": "5678",
      "purpose": "Cloud infrastructure",
      "monthlyLimit": 500
    }
  },
  "transactionPolicy": {
    "requireApproval": true,
    "thresholdUSD": 25,
    "notifyChannel": "telegram"
  }
}
```

### 7.3 Set Transaction Consent Policy

In `openclaw.json`:

```json
{
  "financial": {
    "enabled": true,
    "configPath": "~/.openclaw/config/financial.json",
    "consentPolicy": {
      "requireApproval": "always",
      "approvalChannel": "telegram",
      "timeoutMinutes": 30
    }
  }
}
```

---

## Phase 8: Heartbeat Configuration

### 8.1 Create SOUL.md (Agent Personality)

Create `~/.openclaw/workspace/SOUL.md`:

```markdown
# OpenClaw Assistant - Keaton's Agent

## Identity
I am Keaton's autonomous AI assistant, running on a self-hosted Proxmox environment.
I manage coding tasks, system automation, and proactive notifications.

## Primary Responsibilities
1. **Code Assistance**: PR reviews, feature implementation, repository management
2. **Task Management**: CLEO integration for RCSD/IVTR workflows
3. **Proactive Monitoring**: Email, calendar, and project status briefings
4. **Financial Oversight**: Virtual card management with approval workflows

## Communication Style
- Concise and technical
- Proactive about potential issues
- Always request approval for financial or destructive operations
- Use CLEO task IDs when referencing work

## Boundaries
- Never execute financial transactions without explicit approval
- Always use exec allowlist - never bypass sandbox
- Escalate security concerns immediately via Telegram
```

### 8.2 Create HEARTBEAT.md (Autonomous Tasks)

Create `~/.openclaw/workspace/HEARTBEAT.md`:

```markdown
# Heartbeat Tasks

## Morning Brief (8:00 AM)
- Check CLEO for overdue tasks: `cleo list --status overdue`
- Summarize pending PRs: `gh pr list --state open`
- Weather and calendar integration (if configured)
- Send summary to Telegram

## Hourly Checks
- Monitor GitHub notifications: `gh api notifications`
- Check for urgent CLEO tasks: `cleo find --priority high`
- Verify exec node health

## Nightly Maintenance (2:00 AM)
- Archive completed CLEO tasks: `cleo archive`
- Clean up workspace temp files
- Summarize day's accomplishments

## On-Demand
- PR review when mentioned in Discord
- Task creation when message contains "TODO:" or "TASK:"
- Research when asked about unfamiliar topics
```

### 8.3 Start Gateway Daemon

```bash
# Start as daemon
openclaw gateway start --daemon

# Check status
openclaw gateway status

# View logs
journalctl -u openclaw-gateway -f
```

---

## Phase 9: Verification Checklist

### 9.1 Infrastructure
- [ ] Gateway LXC running (10.0.10.50)
- [ ] Exec Node LXC running (10.0.10.51)
- [ ] Tailscale connected on both
- [ ] Firewall rules applied (if configured)

### 9.2 Security
- [ ] `openclaw security audit --deep` passes
- [ ] Gateway token set (not default)
- [ ] Exec allowlist configured
- [ ] Sensitive files have 600 permissions

### 9.3 Channels
- [ ] Telegram bot created and paired
- [ ] Discord bot invited and paired
- [ ] DM policy set to "pairing"

### 9.4 CLEO Integration
- [ ] CLEO skill installed
- [ ] `cleo --version` works on exec node
- [ ] Test: `openclaw exec "cleo find test"`

### 9.5 Financial
- [ ] Privacy.com cards created
- [ ] Card limits configured
- [ ] Approval workflow tested

### 9.6 Heartbeat
- [ ] SOUL.md created
- [ ] HEARTBEAT.md created
- [ ] Daemon running
- [ ] First heartbeat received

---

## Quick Reference

### Start Services
```bash
# Gateway
openclaw gateway start --daemon

# Check exec node connection
openclaw node status exec-node-01
```

### Common Operations
```bash
# View Control UI
# Open browser: http://10.0.10.50:18793

# Check agent status
openclaw status

# Test CLEO skill
openclaw skill run cleo "cleo dash"

# Emergency stop
openclaw gateway stop
```

### Troubleshooting
```bash
# Gateway logs
journalctl -u openclaw-gateway -f

# Node connection issues
openclaw node ping exec-node-01

# Skill loading
openclaw skill list --verbose

# Reset to clean state (careful!)
openclaw reset --config-only
```

---

## Maintenance

### Weekly
- Review exec approval logs
- Check virtual card usage
- Audit CLEO task completions

### Monthly
- Update OpenClaw: `pnpm update -g openclaw`
- Review and prune skills
- Rotate gateway token
- Check Proxmox backups

---

## References

- OpenClaw Docs: https://docs.openclaw.ai/
- Security Guide: https://docs.openclaw.ai/security
- Exec Approvals: https://docs.openclaw.ai/tools/exec-approvals
- Nodes: https://docs.molt.bot/nodes
- CLEO: Your local CLEO documentation
