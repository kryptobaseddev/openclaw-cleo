<!-- CLEO:START -->
@.cleo/templates/AGENT-INJECTION.md
<!-- CLEO:END -->

# OpenClaw & CleoBot Project

## Mission

Develop and deploy autonomous AI assistant platforms with CLEO orchestration and task management. This project manages two parallel systems:

1. **OpenClaw** (Current/Production) - Custom fork maintained at https://github.com/kryptobaseddev/openclaw
2. **CleoBot** (New/Testing) - Next-generation platform built from https://github.com/CleoAgent/cleobot using Docker and GHCR

Our goal is to integrate CLEO's multi-agent coordination system with both platforms for structured task execution, research workflows, and systematic project management, while migrating from OpenClaw to CleoBot.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ This Development Machine (Claude Code)                     │
│   - Source: /mnt/projects/openclaw                         │
│   - CLEO installed locally                                 │
│   - Skills, agents, installer scripts                      │
└──────────────┬──────────────────────────────┬───────────────┘
               │ SSH / Web                    │ SSH / Web
               ▼                              ▼
┌──────────────────────────────┐  ┌──────────────────────────────┐
│ OpenClaw (CT 110)            │  │ CleoBot (CT 111)             │
│ 10.0.10.20                   │  │ 10.0.10.21                   │
├──────────────────────────────┤  ├──────────────────────────────┤
│ Status: PRODUCTION           │  │ Status: TESTING              │
│ Source: kryptobaseddev fork  │  │ Source: CleoAgent/cleobot    │
│ Domain: openclaw.hoskins.fun │  │ Domain: cleobot.hoskins.fun  │
│ Docker: custom build         │  │ Docker: GHCR images          │
│ CLEO: Installed              │  │ CLEO: To be integrated       │
└──────────────────────────────┘  └──────────────────────────────┘
```

## Server Overview

| Property | OpenClaw (Current) | CleoBot (New) |
|----------|-------------------|---------------|
| **Status** | Production | Testing/Development |
| **Hostname** | `openclaw` | `cleobot` |
| **LXC CT** | 110 | 111 |
| **IP Address** | 10.0.10.20 | 10.0.10.21 |
| **Domain** | openclaw.hoskins.fun | cleobot.hoskins.fun |
| **Backend** | http://10.0.10.20:18789 | http://10.0.10.21:18789 |
| **Source Repo** | [kryptobaseddev/openclaw](https://github.com/kryptobaseddev/openclaw) | [CleoAgent/cleobot](https://github.com/CleoAgent/cleobot) |
| **Build Method** | Custom Docker build | Docker + GHCR images |
| **Credentials File** | `.openclaw-creds.env` | `.cleobot-creds.env` |
| **CLEO Integration** | ✅ Installed | 🚧 Planned |

---

## OpenClaw (10.0.10.20) - Production

### Connection Details

Credentials stored in `.openclaw-creds.env` (gitignored):

| Property | Value |
|----------|-------|
| Domain | openclaw.hoskins.fun |
| LXC IP | 10.0.10.20 |
| Backend | http://10.0.10.20:18789 |
| SSH User | root |
| SSH Host | 10.0.10.20 |
| Web | Use tokenized URL from `.openclaw-creds.env` |

### Quick SSH Access
```bash
# Load credentials and SSH to OpenClaw
source .openclaw-creds.env
sshpass -p "$OPENCLAW_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@$OPENCLAW_LXC_IP
```

### Container Management
```bash
# Check Docker containers
docker ps -a

# View gateway logs
docker logs -f openclaw-openclaw-gateway-1

# Restart gateway
docker restart openclaw-openclaw-gateway-1

# Check permissions (should be 1000:1000)
ls -la ~/.openclaw/
```

### Integration Status

#### Completed
- [x] LXC container provisioned (CT 110, 10.0.10.20)
- [x] Docker and OpenClaw gateway running
- [x] CLEO CLI installed in container (v0.79.1)
- [x] CLEO skill deployed to `/root/.openclaw/skills/cleo/`
- [x] Workspace CLAUDE.md configured with CLEO reference
- [x] Permissions fixed (1000:1000 for node user)
- [x] Workspace path corrected (`/home/node/.openclaw/workspace`)

#### Pending Integration
- [ ] Test CLEO commands from OpenClaw agent
- [ ] Configure multi-agent orchestration
- [ ] Set up automated task synchronization
- [ ] Enable CLEO session management in OpenClaw

### Key Directories

| Location | Purpose |
|----------|---------|
| `/root/.openclaw/` | OpenClaw config and data |
| `/root/.openclaw/workspace/` | Agent workspace (host path) |
| `/home/node/.openclaw/workspace/` | Agent workspace (container path) |
| `/root/.openclaw/skills/cleo/` | CLEO skill installation |
| `/root/.cleo/` | CLEO CLI installation |

---

## CleoBot (10.0.10.21) - Testing

### Connection Details

Credentials stored in `.cleobot-creds.env` (gitignored):

| Property | Value |
|----------|-------|
| Domain | cleobot.hoskins.fun |
| LXC IP | 10.0.10.21 |
| Backend | http://10.0.10.21:18789 |
| SSH User | root |
| SSH Host | 10.0.10.21 |

### Quick SSH Access
```bash
# Load credentials and SSH to CleoBot
source .cleobot-creds.env
sshpass -p "$CLEOBOT_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@$CLEOBOT_LXC_IP
```

### Container Management
```bash
# Check Docker containers
docker ps -a

# View gateway logs (container name may differ from OpenClaw)
docker logs -f <cleobot-container-name>

# Pull latest GHCR images
docker pull ghcr.io/cleoagent/cleobot:latest

# Check permissions (should be 1000:1000)
ls -la ~/.cleobot/
```

### Integration Status

#### Completed
- [x] LXC container provisioned (CT 111, 10.0.10.21)
- [x] Docker environment configured
- [x] CleoBot source from GHCR available

#### Pending Integration
- [ ] Deploy CleoBot containers from GHCR
- [ ] Install CLEO CLI in CleoBot container
- [ ] Configure CLEO skill deployment
- [ ] Set up workspace with CLEO reference
- [ ] Test CleoBot gateway and agent functionality
- [ ] Migrate configurations from OpenClaw
- [ ] Performance comparison testing
- [ ] Production cutover planning

### Key Directories (Planned)

| Location | Purpose |
|----------|---------|
| `/root/.cleobot/` | CleoBot config and data |
| `/root/.cleobot/workspace/` | Agent workspace (host path) |
| `/home/node/.cleobot/workspace/` | Agent workspace (container path) |
| `/root/.cleobot/skills/cleo/` | CLEO skill installation |
| `/root/.cleo/` | CLEO CLI installation |

---

## Local Development (This Machine)

### Key Directories

| Location | Purpose |
|----------|---------|
| `/mnt/projects/openclaw/` | Local development (this repo) |
| `/mnt/projects/openclaw/skills/cleo/` | CLEO skill source |
| `/mnt/projects/openclaw/scripts/` | Installer scripts for both servers |
| `/mnt/projects/openclaw/.openclaw-creds.env` | OpenClaw credentials (gitignored) |
| `/mnt/projects/openclaw/.cleobot-creds.env` | CleoBot credentials (gitignored) |

---

## Common Issues

### Permission Denied Errors
Both OpenClaw and CleoBot containers run as uid 1000 (node user). Host files must be owned by 1000:1000:
```bash
# OpenClaw
chown -R 1000:1000 ~/.openclaw/

# CleoBot
chown -R 1000:1000 ~/.cleobot/
```

### Workspace Path Mismatch
Config shows host path but container uses `/home/node/.*`:
```bash
# OpenClaw
jq '.agents.defaults.workspace = "/home/node/.openclaw/workspace"' ~/.openclaw/openclaw.json > /tmp/fix.json
mv /tmp/fix.json ~/.openclaw/openclaw.json
chown 1000:1000 ~/.openclaw/openclaw.json
docker restart openclaw-openclaw-gateway-1

# CleoBot (adjust container name)
jq '.agents.defaults.workspace = "/home/node/.cleobot/workspace"' ~/.cleobot/cleobot.json > /tmp/fix.json
mv /tmp/fix.json ~/.cleobot/cleobot.json
chown 1000:1000 ~/.cleobot/cleobot.json
docker restart <cleobot-container-name>
```

### Token Mismatch
Use the tokenized URLs from credential files for web access.

### Wrong Server Connection
Ensure you're using the correct credential file and IP address:
- **OpenClaw**: 10.0.10.20 (`.openclaw-creds.env`)
- **CleoBot**: 10.0.10.21 (`.cleobot-creds.env`)

---

## CLEO Commands (in LXC)

```bash
# After SSH into either LXC container
cleo --version              # Verify installation
cleo session list           # Check sessions
cleo dash                   # Project overview
cleo find "query"           # Search tasks
```

---

## Development Workflow

### 1. Local Development
Edit skills, scripts, docs in `/mnt/projects/openclaw/`

### 2. Deploy to Servers
```bash
# Deploy to OpenClaw (production)
source .openclaw-creds.env
scp -r ./skills/cleo/ root@$OPENCLAW_LXC_IP:/root/.openclaw/skills/

# Deploy to CleoBot (testing)
source .cleobot-creds.env
scp -r ./skills/cleo/ root@$CLEOBOT_LXC_IP:/root/.cleobot/skills/
```

### 3. Test on Both Servers
```bash
# Test on OpenClaw
source .openclaw-creds.env
sshpass -p "$OPENCLAW_SSH_PASSWORD" ssh root@$OPENCLAW_LXC_IP "cleo --version"

# Test on CleoBot
source .cleobot-creds.env
sshpass -p "$CLEOBOT_SSH_PASSWORD" ssh root@$CLEOBOT_LXC_IP "cleo --version"
```

### 4. Document
Update session notes in `claudedocs/agent-outputs/`

---

## Migration Strategy

### Phase 1: Parallel Operation (Current)
- OpenClaw remains in production
- CleoBot runs in testing environment
- Both systems receive CLEO integration work
- Performance and feature comparison

### Phase 2: CleoBot Validation
- Feature parity verification
- Performance benchmarking
- Stability testing under load
- CLEO orchestration testing

### Phase 3: Cutover (Planned)
- Backup OpenClaw configuration
- Migrate agent configurations to CleoBot
- Update DNS/routing if needed
- Run both systems briefly for validation
- Decommission OpenClaw or archive

---

## Related Documentation

- Session summaries: `claudedocs/agent-outputs/SESSION-SUMMARY-*.md`
- CLEO integration research: `claudedocs/agent-outputs/T006-cleo-integration-research.md`
- Permissions fix: `claudedocs/agent-outputs/T005-permissions-fix.md`
- CLI install: `claudedocs/agent-outputs/T024-cleo-cli-install.md`
- Workspace config: `claudedocs/agent-outputs/T026-workspace-config.md`
