# OpenClaw LXC Container State Assessment

**Task**: T005-lxc-state
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

The OpenClaw LXC container (10.0.10.20) has Docker running and containers deployed, but the gateway is in a crash-restart loop due to missing configuration. The infrastructure is working (Docker, networking, volumes, Doppler secrets), but `openclaw setup` has not been run to create the required `openclaw.json` configuration file.

## Findings

### 1. Docker Status: RUNNING

Docker service is active and running properly:
- **Service**: active (running) since 03:51:27 UTC
- **Runtime**: ~25 minutes uptime
- **No issues detected** with Docker daemon

### 2. Container Status: CRASH LOOP

Two containers exist from image `openclaw:local`:

| Container | Status | Issue |
|-----------|--------|-------|
| `openclaw-openclaw-gateway-1` | Restarting (1) every ~60s | Missing config |
| `openclaw-openclaw-cli-1` | Exited (1) 20 minutes ago | Missing config |

**Gateway logs** (repeated every minute):
```
Missing config. Run `openclaw setup` or set gateway.mode=local (or pass --allow-unconfigured).
```

### 3. OpenClaw Configuration: MISSING

**Directory structure exists but config file is missing:**

```bash
/root/.openclaw/
├── config/         # EMPTY
├── credentials/    # EMPTY
├── memory/
├── skills/
└── workspace/
```

**Critical finding**: No `openclaw.json` file exists at:
- `/root/.openclaw/openclaw.json` ❌
- `/opt/openclaw/openclaw.json` ❌

### 4. Services Status: NO WEB SERVER

**Listening ports:**
- Port 22: SSH (working - we're connected)
- Port 25: Mail (localhost only)
- **Port 18789**: NOT listening (gateway not running)
- **Port 18790**: NOT listening (bridge not running)

No gateway service is accessible because the container crashes before binding ports.

### 5. Doppler Status: CONFIGURED AND WORKING

Doppler is properly configured and secrets are available:

**From project directory (`/opt/openclaw`):**
```bash
doppler secrets  # SUCCESS - returns secrets
```

**Key secrets available:**
- `ANTHROPIC_API_KEY`: Configured (sk-ant-api03-...)
- `OPENCLAW_GATEWAY_TOKEN`: Configured (861bed3d...)
- `OPENCLAW_CONFIG_DIR`: `/root/.openclaw`
- `OPENCLAW_WORKSPACE_DIR`: `/root/.openclaw/workspace`
- `DOPPLER_PROJECT`: backend
- `DOPPLER_CONFIG`: prd

### 6. Volume Mounts: CORRECT

Docker Compose configuration shows proper volume mounting:
```yaml
volumes:
  - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
  - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
```

**Actual mounts verified:**
- Host: `/root/.openclaw` → Container: `/home/node/.openclaw` ✓
- Host: `/root/.openclaw/workspace` → Container: `/home/node/.openclaw/workspace` ✓

**Environment variables properly set:**
- Container receives: `OPENCLAW_GATEWAY_TOKEN`
- Container HOME: `/home/node` (correct for volume mounts)

### 7. Root Cause Identified

The gateway container expects a configuration file at `/home/node/.openclaw/openclaw.json` (inside container), which maps to `/root/.openclaw/openclaw.json` (on host).

**Problem chain:**
1. No `openclaw.json` file exists on host
2. Volume mount propagates empty directory to container
3. Gateway process starts, looks for config, finds none
4. Gateway exits with code 1 (missing config error)
5. Docker restart policy triggers, loop repeats

**The error message tells us exactly what to do:**
> "Run `openclaw setup` or set gateway.mode=local (or pass --allow-unconfigured)"

## Error Identification

**Primary blocker**: Missing configuration file prevents gateway startup.

**Specific error**: `Missing config. Run 'openclaw setup' or set gateway.mode=local`

**Error frequency**: Every ~60 seconds (restart loop interval)

**No other errors detected**:
- No network errors
- No permission errors
- No Doppler secret errors
- No Docker daemon errors
- No port binding conflicts

## Next Steps Required

### Option 1: Run Setup (Recommended)

Run the OpenClaw setup wizard to create proper configuration:

```bash
ssh root@10.0.10.20
cd /opt/openclaw
node dist/index.js setup --non-interactive --mode local
```

This will create `/root/.openclaw/openclaw.json` with proper gateway configuration.

### Option 2: Manual Configuration

Create minimal config file manually:

```bash
ssh root@10.0.10.20
cat > /root/.openclaw/openclaw.json << 'EOF'
{
  "gateway": {
    "mode": "local"
  },
  "agents": {
    "defaults": {
      "workspace": "/root/.openclaw/workspace"
    }
  }
}
EOF
```

### Option 3: Allow Unconfigured Mode

Modify docker-compose.yml to add `--allow-unconfigured` flag (not recommended for production).

## Technical Details

### System Information

- **LXC Container**: 10.0.10.20
- **OS**: Debian-based (systemd)
- **Docker Version**: Active and healthy
- **OpenClaw Version**: 2026.1.30 (63b13c7)
- **Installation Path**: `/opt/openclaw/`

### Network Configuration

- **SSH Access**: Working (port 22)
- **Gateway Port**: 18789 (not bound - container not running)
- **Bridge Port**: 18790 (not bound - container not running)
- **Gateway Bind**: LAN mode configured in docker-compose

### Dependencies Status

| Dependency | Status |
|------------|--------|
| Docker | ✓ Running |
| Doppler | ✓ Configured with secrets |
| OpenClaw Image | ✓ Built (openclaw:local) |
| Volume Mounts | ✓ Configured correctly |
| Environment Variables | ✓ Loaded from Doppler |
| Configuration File | ✗ Missing (blocker) |

## References

- Epic: T001
- Related: T005
- System: 10.0.10.20 (openclaw LXC container)
- Deployment: Docker Compose with Doppler integration
