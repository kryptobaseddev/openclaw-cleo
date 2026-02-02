# Current OpenClaw Installation State Assessment

**Task**: T005
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

OpenClaw is NOT currently installed or running. The project repository exists at `/mnt/projects/openclaw` but contains only the installation scripts and documentation. No Docker container, configuration, or deployment exists on this system. Doppler CLI is installed but not authenticated.

---

## Findings

### 1. Docker Status

**Container Status**: No OpenClaw containers exist
```
CONTAINER ID   IMAGE                     STATUS
f08481a542e7   postgis/postgis:16-3.4    Up 23 hours (healthy)
8320d20f0679   redis:7.4-alpine          Up 23 hours (healthy)
```

- Docker daemon: ✅ Running (v29.2.0)
- OpenClaw container: ❌ Does not exist
- OpenClaw image: ❌ Not built

**Key Evidence**: `docker logs openclaw` returned "No such container: openclaw"

### 2. OpenClaw Configuration

**Directory Status**: No installation directory exists
```bash
/opt/openclaw/ → Does not exist
/mnt/projects/openclaw/ → Contains only installer scripts/docs
```

- Installation target: ❌ `/opt/openclaw` not found
- Source repository: ✅ Present at `/mnt/projects/openclaw/openclaw-src/`
- Docker Compose: ✅ Exists at `openclaw-src/docker-compose.yml`
- Dockerfile: ✅ Exists at `openclaw-src/Dockerfile`

**Expected Configuration**:
- Gateway mode: Not configured (no openclaw.json)
- Ports: Expected 18789 (gateway), 18790 (bridge)
- Workspace: Expected at `/home/node/.openclaw/workspace`

### 3. Doppler Secrets Management

**Status**: Installed but not authenticated
```bash
/usr/bin/doppler v3.75.2
Error: Invalid Auth token
```

- Doppler CLI: ✅ Installed
- Authentication: ❌ No valid token configured
- Project setup: ❌ Not configured for `openclaw` project

**Required Secrets** (from docs):
- `ANTHROPIC_API_KEY` - Claude API key
- `OPENCLAW_GATEWAY_TOKEN` - Gateway auth token
- `TELEGRAM_BOT_TOKEN` - Telegram bot (optional)
- `DISCORD_BOT_TOKEN` - Discord bot (optional)

### 4. Project Structure Analysis

**Current State**:
```
/mnt/projects/openclaw/
├── openclaw-src/          # OpenClaw source code (cloned)
│   ├── docker-compose.yml # Container orchestration
│   ├── Dockerfile         # Image definition
│   └── [source code]
├── scripts/               # Installation automation
│   ├── install.sh
│   ├── provision-lxc.sh
│   ├── setup-docker-deps.sh
│   └── openclaw-full-setup.sh
├── docs/                  # Documentation
└── claudedocs/            # Research outputs
```

**Docker Compose Configuration**:
- Service: `openclaw-gateway` (not running)
- Image: `openclaw:local` (not built)
- Environment variables: From Doppler or `.env` (not configured)
- Bind mode: `${OPENCLAW_GATEWAY_BIND:-lan}` (default: lan)
- Ports: `18789:18789`, `18790:18790`

### 5. Network/Access Status

**Current Ports**: None exposed for OpenClaw
```bash
0.0.0.0:5432 → PostgreSQL (retail-arbitrage project)
0.0.0.0:6379 → Redis (retail-arbitrage project)
```

- OpenClaw gateway (18789): ❌ Not exposed
- OpenClaw bridge (18790): ❌ Not exposed
- UI access: ❌ No service running

---

## Blockers Identified

| Blocker | Impact | Required Action |
|---------|--------|----------------|
| **No Docker image built** | Cannot run container | Build from `openclaw-src/Dockerfile` |
| **No Doppler authentication** | Cannot fetch secrets | Authenticate with service token or CLI login |
| **No secrets configured** | Container won't start | Add ANTHROPIC_API_KEY + GATEWAY_TOKEN to Doppler |
| **No .env fallback** | Local dev blocked | Either use Doppler or create `.env` file |
| **No container deployed** | No services running | Run `docker compose up` with proper env vars |

---

## Root Cause Analysis

**Why is OpenClaw not accessible?**

1. **Installation never completed**: The installer scripts exist but haven't been executed
2. **This is a development/documentation repository**: Not a live deployment
3. **Expected workflow**: Run `scripts/install.sh` → Provisions LXC → Builds image → Starts container

**What's the intended deployment model?**

According to README and scripts:
- **Target**: Proxmox LXC container (not this host directly)
- **Installer**: `scripts/install.sh` creates LXC, then runs setup inside container
- **Current system**: Development workstation with installer source code

---

## Recommended Actions

### Option A: Full Installation (Intended Workflow)

**Prerequisites**:
1. Doppler service token: `doppler configs tokens create openclaw-container --project openclaw --config prd --plain`
2. Verify Anthropic API key in Doppler `openclaw/prd` config

**Execute**:
```bash
cd /mnt/projects/openclaw
bash scripts/install.sh --doppler-token dp.st.prd.XXXXX
```

**Result**: Provisions LXC container with full OpenClaw installation

### Option B: Local Development Setup (Quick Test)

**Prerequisites**:
1. Authenticate Doppler: `cd /mnt/projects/openclaw/openclaw-src && doppler login`
2. Setup project: `doppler setup --project openclaw --config prd`

**Execute**:
```bash
cd /mnt/projects/openclaw/openclaw-src
docker build -t openclaw:local .
doppler run -- docker compose up openclaw-gateway
```

**Result**: Runs OpenClaw locally with Doppler secrets

### Option C: Manual .env Setup (No Doppler)

**Create `.env` file**:
```bash
cd /mnt/projects/openclaw/openclaw-src
cat > .env <<'EOF'
ANTHROPIC_API_KEY=sk-ant-XXXXX
OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_CONFIG_DIR=/opt/openclaw
OPENCLAW_WORKSPACE_DIR=/opt/openclaw/workspace
EOF
```

**Execute**:
```bash
docker build -t openclaw:local .
docker compose up openclaw-gateway
```

---

## Next Steps for T001 Epic

1. **Decide deployment target**:
   - Proxmox LXC (intended) → Use `scripts/install.sh`
   - Local Docker (testing) → Use Option B or C above

2. **Configure Doppler**:
   - Create project: `openclaw`
   - Create config: `prd`
   - Add secrets: `ANTHROPIC_API_KEY`, `OPENCLAW_GATEWAY_TOKEN`
   - Generate service token

3. **Build and deploy**:
   - Execute chosen installation option
   - Verify container starts: `docker logs openclaw`
   - Test gateway access: `curl http://localhost:18789`

4. **Configure UI access**:
   - Set gateway bind mode: `lan` or `all`
   - Configure reverse proxy if needed
   - Test from web browser

---

## References

- Epic: T001 (OpenClaw UI Setup and Verification)
- Task: T005 (Current State Assessment)
- Documentation: `/mnt/projects/openclaw/docs/guides/`
- Source: `/mnt/projects/openclaw/openclaw-src/`
