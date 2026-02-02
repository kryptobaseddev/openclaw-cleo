# OpenClaw Gateway Configuration Fix

**Task**: T005-fix
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

Successfully resolved OpenClaw gateway crash-restart loop by creating the required configuration file, setting gateway mode to local, and fixing file permissions. The gateway is now running stably on ports 18789 and 18790.

## Problem Analysis

The gateway container was in a continuous crash-restart loop with the error message:
```
Missing config. Run `openclaw setup` or set gateway.mode=local (or pass --allow-unconfigured).
```

Root causes identified:
1. Missing `/root/.openclaw/openclaw.json` configuration file
2. Missing `gateway.mode` setting in configuration
3. Incorrect file permissions preventing container from reading config
4. Missing canvas and cron directories with correct ownership

## Implementation Steps

### 1. Created Configuration File
```bash
cd /opt/openclaw && ./openclaw.mjs setup
```
Result: Created `~/.openclaw/openclaw.json` with basic configuration

### 2. Added Gateway Mode Setting
Updated configuration to include required gateway mode:
```json
{
  "agents": {
    "defaults": {
      "workspace": "/root/.openclaw/workspace"
    }
  },
  "gateway": {
    "mode": "local"
  },
  "meta": {
    "lastTouchedVersion": "2026.1.30",
    "lastTouchedAt": "2026-02-02T04:19:49.267Z"
  }
}
```

### 3. Fixed File Permissions
The container runs as user `node` (uid 1000), but config directory was owned by root with restrictive permissions:
```bash
chmod -R 755 /root/.openclaw
chmod 644 /root/.openclaw/openclaw.json
```

### 4. Created Required Directories
Created and set ownership for canvas and cron directories:
```bash
mkdir -p /root/.openclaw/canvas /root/.openclaw/cron
chown -R 1000:1000 /root/.openclaw/canvas /root/.openclaw/cron
```

### 5. Restarted Container
```bash
docker restart openclaw-openclaw-gateway-1
```

## Verification

### Container Status
```
CONTAINER ID   IMAGE            STATUS         PORTS
1b3a1bbd5979   openclaw:local   Up 18 seconds  0.0.0.0:18789-18790->18789-18790/tcp
```

### Service Status (from logs)
- ✅ Gateway listening on ws://0.0.0.0:18789 (PID 7)
- ✅ Heartbeat started
- ✅ Agent model: anthropic/claude-opus-4-5
- ✅ Canvas host mounted at http://0.0.0.0:18789/__openclaw__/canvas/
- ✅ Browser control service ready (profiles=2)
- ✅ Log file: /tmp/openclaw/openclaw-2026-02-02.log

### Network Status
```
LISTEN 0.0.0.0:18789  (gateway)
LISTEN 0.0.0.0:18790  (bridge)
```

### HTTP Response
```bash
curl http://localhost:18789/
```
Returns OpenClaw Control UI HTML (200 OK)

## Key Findings

1. **Configuration Requirements**: OpenClaw gateway requires explicit `gateway.mode` setting, not just a config file
2. **Permission Model**: Container runs as uid 1000 (node user), requires read access to host-mounted config directory
3. **Directory Structure**: Gateway expects canvas and cron directories to exist with proper ownership
4. **Port Mapping**: Gateway exposes two ports - 18789 (gateway) and 18790 (bridge)
5. **Startup Dependencies**: All services (heartbeat, canvas, browser control) start successfully when config is properly configured

## Success Criteria Met

- ✅ Config file exists at `~/.openclaw/openclaw.json`
- ✅ Container is running (not restarting)
- ✅ Gateway responds to HTTP requests
- ✅ Ports 18789 and 18790 are listening
- ✅ No error messages in logs
- ✅ All gateway services started successfully

## References

- Epic: T001
- Related: T005
- System: OpenClaw on LXC 10.0.10.20
- Documentation: OpenClaw Gateway Configuration
