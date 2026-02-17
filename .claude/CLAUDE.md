<!-- CLEO:START -->
@.cleo/templates/AGENT-INJECTION.md
<!-- CLEO:END -->

# OpenClaw Deployment — Project Instructions

## Architecture

```
Local Machine (Claude Code)        LXC Container (Production)
/mnt/projects/openclaw/            10.0.10.20 (CT 110)
- Source: upstream v2026.2.15      - Docker: openclaw:local
- optimize/ reference docs         - Gateway: port 18789
- .cleo/ task management           - Telegram: @cleoagent_bot
- .openclaw-creds.env              - Config: /root/.openclaw/
```

## SSH Access to OpenClaw LXC

Credentials are in `.openclaw-creds.env` (gitignored). Always source before SSH:

```bash
source /mnt/projects/openclaw/.openclaw-creds.env
sshpass -p "$OPENCLAW_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@$OPENCLAW_LXC_IP "<command>"
```

For SCP:
```bash
source /mnt/projects/openclaw/.openclaw-creds.env
sshpass -p "$OPENCLAW_SSH_PASSWORD" scp root@$OPENCLAW_LXC_IP:/remote/path /local/path
```

**Environment variables provided by .openclaw-creds.env:**
- `OPENCLAW_SSH_PASSWORD` — root SSH password for LXC
- `OPENCLAW_LXC_IP` — LXC IP address (10.0.10.20)
- `OPENCLAW_GATEWAY_TOKEN` — gateway auth token

## Key Paths on LXC (10.0.10.20)

| Path | Purpose |
|------|---------|
| `/opt/openclaw/` | OpenClaw source + Docker build |
| `/opt/openclaw/.env` | Environment variables (chmod 600) |
| `/opt/openclaw/docker-compose.yml` | Docker compose config |
| `/root/.openclaw/openclaw.json` | Gateway + agent config (owned 1000:1000) |
| `/root/.openclaw/workspace/` | Agent workspace (owned 1000:1000) |
| `/root/.openclaw/skills/cleo/` | CLEO skill |
| `/root/.openclaw/cron/jobs.json` | Cron job definitions |

## Container Management

```bash
# Check status
docker ps
docker logs openclaw-openclaw-gateway-1 --tail 30

# Restart
cd /opt/openclaw && docker compose restart

# Rebuild from source
cd /opt/openclaw && docker compose down && docker build -t openclaw:local . && docker compose up -d

# OpenClaw CLI (inside container)
docker exec openclaw-openclaw-gateway-1 npx openclaw <command> --token <gateway-token>
```

## Permissions

Container runs as uid 1000 (node). Config and workspace files must be owned by 1000:1000:
```bash
chown -R 1000:1000 /root/.openclaw/
```

## Current Configuration

- **Version**: v2026.2.15
- **Primary model**: anthropic/claude-haiku-4-5
- **Heartbeat**: every 1h (Haiku)
- **Cron**: health check (4h), maintenance (daily 3AM)
- **Secrets**: via Doppler + .env
- **Channels**: Telegram (@cleoagent_bot)

## Git Workflow

- `origin` = kryptobaseddev/openclaw-cleo (our fork)
- `upstream` = openclaw/openclaw (upstream source)
- `main` branch tracks upstream releases
- Custom deployment files stay untracked or in `.claude/`
- Contributions: branch from main, PR against upstream

## Optimization Reference

Reference docs in `optimize/` directory — 10 guides covering token management, model routing, security hardening, cron jobs, skills security, and platform deployment.

## Active Epic

**T081**: OpenClaw v2026.2.15 Optimization & Hardening
Resume with: `ct session start --scope epic:T081 --auto-focus`

## CleoBot (Future)

- **LXC**: CT 111, 10.0.10.21
- **Credentials**: `.cleobot-creds.env`
- **Status**: Development/planned
- **SSH**: Same pattern as OpenClaw but with `$CLEOBOT_*` vars
