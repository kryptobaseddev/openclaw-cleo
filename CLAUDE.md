<!-- CLEO:START -->
@.cleo/templates/AGENT-INJECTION.md
<!-- CLEO:END -->

# OpenClaw Project

## Mission

Power OpenClaw with CLEO orchestration and task management. OpenClaw is an autonomous AI assistant platform running in an LXC container on Proxmox. Our goal is to integrate CLEO's multi-agent coordination system with OpenClaw for structured task execution, research workflows, and systematic project management.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ This Development Machine (Claude Code)                     │
│   - Source: /mnt/projects/openclaw                         │
│   - CLEO installed locally                                 │
│   - Skills, agents, installer scripts                      │
└──────────────────────────┬──────────────────────────────────┘
                           │ SSH / Web
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ OpenClaw LXC Container (CT 110 @ 10.0.10.20)               │
│   - Domain: openclaw.hoskins.fun                           │
│   - Docker: openclaw-openclaw-gateway-1                    │
│   - CLEO CLI installed at /root/.cleo                      │
│   - Workspace: /root/.openclaw/workspace                   │
│   - Skills: /root/.openclaw/skills/cleo/                   │
└─────────────────────────────────────────────────────────────┘
```

## Connection Details

Credentials stored in `.openclaw-creds.env` (gitignored):

| Property | Value |
|----------|-------|
| Domain | openclaw.hoskins.fun |
| LXC IP | 10.0.10.20 |
| Backend | http://10.0.10.20:18789 |
| SSH | `ssh root@10.0.10.20` |
| Web | Use tokenized URL from `.openclaw-creds.env` |

### Quick SSH Access
```bash
# Load credentials and SSH
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

## Integration Status

### Completed
- [x] LXC container provisioned (CT 110, 10.0.10.20)
- [x] Docker and OpenClaw gateway running
- [x] CLEO CLI installed in container (v0.79.1)
- [x] CLEO skill deployed to `/root/.openclaw/skills/cleo/`
- [x] Workspace CLAUDE.md configured with CLEO reference
- [x] Permissions fixed (1000:1000 for node user)
- [x] Workspace path corrected (`/home/node/.openclaw/workspace`)

### Pending Integration
- [ ] Test CLEO commands from OpenClaw agent
- [ ] Configure multi-agent orchestration
- [ ] Set up automated task synchronization
- [ ] Enable CLEO session management in OpenClaw

## Key Directories

| Location | Purpose |
|----------|---------|
| `/mnt/projects/openclaw/` | Local development (this repo) |
| `/mnt/projects/openclaw/skills/cleo/` | CLEO skill source |
| `/mnt/projects/openclaw/scripts/` | Installer scripts |
| `/root/.openclaw/` (on LXC) | OpenClaw config and data |
| `/root/.openclaw/workspace/` (on LXC) | Agent workspace |
| `/root/.cleo/` (on LXC) | CLEO CLI installation |

## Common Issues

### Permission Denied Errors
OpenClaw containers run as uid 1000 (node user). Host files must be owned by 1000:1000:
```bash
chown -R 1000:1000 ~/.openclaw/
```

### Workspace Path Mismatch
Config shows host path but container uses `/home/node/.openclaw/`:
```bash
# Fix in openclaw.json
jq '.agents.defaults.workspace = "/home/node/.openclaw/workspace"' ~/.openclaw/openclaw.json > /tmp/fix.json
mv /tmp/fix.json ~/.openclaw/openclaw.json
chown 1000:1000 ~/.openclaw/openclaw.json
docker restart openclaw-openclaw-gateway-1
```

### Token Mismatch
Use the tokenized URL from `.openclaw-creds.env` for web access.

## CLEO Commands (in LXC)

```bash
# After SSH into LXC
cleo --version              # Verify installation
cleo session list           # Check sessions
cleo dash                   # Project overview
cleo find "query"           # Search tasks
```

## Development Workflow

1. **Local Development**: Edit skills, scripts, docs in `/mnt/projects/openclaw/`
2. **Deploy to LXC**: Copy files via SCP or update OpenClaw workspace
3. **Test**: SSH into LXC and verify functionality
4. **Document**: Update session notes in `claudedocs/agent-outputs/`

## Related Documentation

- Session summaries: `claudedocs/agent-outputs/SESSION-SUMMARY-*.md`
- CLEO integration research: `claudedocs/agent-outputs/T006-cleo-integration-research.md`
- Permissions fix: `claudedocs/agent-outputs/T005-permissions-fix.md`
- CLI install: `claudedocs/agent-outputs/T024-cleo-cli-install.md`
- Workspace config: `claudedocs/agent-outputs/T026-workspace-config.md`
