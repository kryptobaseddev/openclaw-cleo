# AgentMail Configuration for OpenClaw LXC

**Task**: T027
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

Successfully configured AgentMail integration on the OpenClaw LXC container (10.0.10.20). Updated docker-compose.yml with AgentMail environment variables, configured Doppler secrets, and restarted containers with the new configuration.

## Implementation Details

### 1. Docker Compose Update

**Modified**: `/opt/openclaw/docker-compose.yml`

Added AgentMail environment variables to both services:

```yaml
services:
  openclaw-gateway:
    environment:
      AGENTMAIL_API_KEY: ${AGENTMAIL_API_KEY}
      AGENTMAIL_EMAIL: ${AGENTMAIL_EMAIL}

  openclaw-cli:
    environment:
      AGENTMAIL_API_KEY: ${AGENTMAIL_API_KEY}
      AGENTMAIL_EMAIL: ${AGENTMAIL_EMAIL}
```

### 2. Doppler Configuration

**Secrets Set**:
- `AGENTMAIL_API_KEY`: `${AGENTMAIL_API_KEY}` (pre-configured)
- `AGENTMAIL_EMAIL`: `openclawcleo@agentmail.to`

### 3. Container Restart

Restarted both containers using Doppler-injected environment:

```bash
cd /opt/openclaw && doppler run -- docker compose up -d
```

**Result**:
- `openclaw-openclaw-gateway-1`: Recreated and running
- `openclaw-openclaw-cli-1`: Recreated and running

### 4. Verification

**Environment Variables Confirmed**:
```
AGENTMAIL_API_KEY=${AGENTMAIL_API_KEY}
AGENTMAIL_EMAIL=openclawcleo@agentmail.to
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
```

**Container Status**:
- Gateway: Up and running
- Ports: 18789-18790 exposed
- Network: LAN accessible (0.0.0.0)

## Git Status

Resolved merge conflict between local ANTHROPIC_API_KEY changes and upstream AgentMail additions. Final docker-compose.yml includes both sets of environment variables.

## Testing Recommendations

1. **Email Reception Test**: Send test email to `openclawcleo@agentmail.to` and verify reception via AgentMail API
2. **Gateway Health Check**: Verify OpenClaw gateway responds at `http://10.0.10.20:18789`
3. **Integration Test**: Test end-to-end email → gateway → processing workflow

## Configuration Files

### Primary Files
- `/opt/openclaw/docker-compose.yml` - Container definitions with AgentMail vars
- Doppler project - Secret management (AGENTMAIL_API_KEY, AGENTMAIL_EMAIL)

### Backup
- `/opt/openclaw/docker-compose.yml.bak` - Pre-AgentMail backup

## References

- **Task**: T027 - Configure AgentMail integration on OpenClaw LXC
- **Epic**: T001 - OpenClaw Setup
- **AgentMail Service**: openclawcleo@agentmail.to
- **System IP**: 10.0.10.20
