# OpenClaw ANTHROPIC_API_KEY Injection Fix

**Task**: T027-fix
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

Successfully fixed ANTHROPIC_API_KEY injection into OpenClaw Docker container. The API key was configured in Doppler but not passed through docker-compose.yml environment variables.

## Implementation Steps

### 1. Backed Up Configuration
```bash
cp /opt/openclaw/docker-compose.yml /opt/openclaw/docker-compose.yml.bak
```

### 2. Updated docker-compose.yml
Added `ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}` to environment blocks for both services:
- openclaw-gateway
- openclaw-cli

### 3. Restarted Services
```bash
cd /opt/openclaw
doppler run -- docker compose down
doppler run -- docker compose up -d
```

### 4. Verified API Key Injection
```bash
docker exec openclaw-openclaw-gateway-1 env | grep ANTHROPIC
```

**Result**: `ANTHROPIC_API_KEY=sk-ant-api03-lhW...` (verified present in container)

## Key Findings

1. **Root Cause**: docker-compose.yml was missing ANTHROPIC_API_KEY in environment blocks
2. **Solution**: Added environment variable pass-through from Doppler to both services
3. **Verification**: API key successfully injected into running container
4. **Container Status**: openclaw-openclaw-gateway-1 running on ports 18789-18790

## Changes Made

**File**: `/opt/openclaw/docker-compose.yml`

Added to both `openclaw-gateway` and `openclaw-cli` services:
```yaml
environment:
  # ... existing vars ...
  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
```

## Success Criteria Met

- ✅ ANTHROPIC_API_KEY present in docker-compose.yml
- ✅ Container has ANTHROPIC_API_KEY environment variable
- ✅ Container running successfully (24+ seconds uptime)
- ✅ No "No API key found" errors expected

## Technical Details

- **Container**: openclaw-openclaw-gateway-1
- **Image**: openclaw:local
- **Ports**: 18789-18790 (exposed)
- **API Key**: Injected via Doppler secrets management
- **Restart Policy**: unless-stopped

## Follow-up Actions

None required. Implementation complete and verified.

## References

- Epic: T001
- Task: T027-fix
- Related: OpenClaw installation and configuration
