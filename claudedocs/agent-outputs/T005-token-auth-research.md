# OpenClaw Gateway Token Authentication Research

**Task**: T005
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

OpenClaw gateway requires a token to be configured in `~/.openclaw/openclaw.json` under `gateway.auth.token`. The token is passed via WebSocket connection parameters (NOT HTTP headers) or URL query parameter `?token=...`. The current installation has no token configured, causing the "unauthorized: gateway token missing" error when accessing via reverse proxy.

## Authentication Architecture

### Token Storage & Configuration

**Location**: `~/.openclaw/openclaw.json`

```json
{
  "gateway": {
    "mode": "local",
    "auth": {
      "token": "<48-char-hex-string>"
    },
    "trustedProxies": ["10.0.0.0/8"]
  }
}
```

**Token Generation**: 24 random bytes encoded as hex (48 characters)
```javascript
// From /app/dist/commands/onboard-helpers.js
crypto.randomBytes(24).toString("hex")
```

**Environment Variable Fallback**:
- `OPENCLAW_GATEWAY_TOKEN`
- `CLAWDBOT_GATEWAY_TOKEN` (legacy)

### Authentication Flow

**Source**: `/app/dist/gateway/server/ws-connection/message-handler.js`

1. **WebSocket Handshake**: First message MUST be `connect` method with params
2. **Token Passed In**: `connectParams.auth.token` (NOT HTTP header)
3. **Validation**: `/app/dist/gateway/auth.js` → `authorizeGatewayConnect()`
4. **Local Bypass**: Loopback connections from trusted proxies skip auth if Host header is local

### Token Delivery Mechanisms

#### 1. URL Query Parameter (Recommended for Web UI)
```
https://openclaw.hoskins.fun?token=50730561075f70a79be516e876f5c435fe7afdbc24877259
```

**Implementation**: `/app/dist/commands/dashboard.js`
```javascript
const authedUrl = token ? `${links.httpUrl}?token=${encodeURIComponent(token)}` : links.httpUrl;
```

#### 2. WebSocket Connect Parameters (Programmatic)
```json
{
  "type": "req",
  "method": "connect",
  "params": {
    "auth": {
      "token": "50730561075f70a79be516e876f5c435fe7afdbc24877259"
    },
    "client": { "id": "control-ui", "mode": "ui", "version": "..." },
    "minProtocol": 1,
    "maxProtocol": 1
  }
}
```

#### 3. Control UI Settings Modal
From error message hint: "paste token in Control UI settings"
- Settings accessible in Control UI
- Token can be entered manually if URL parameter not used

### Error Messages & Causes

**Source**: `/app/dist/gateway/server/ws-connection/message-handler.js` → `formatGatewayAuthFailureMessage()`

| Error | Reason Code | Cause |
|-------|-------------|-------|
| `unauthorized: gateway token missing (open a tokenized dashboard URL or paste token in Control UI settings)` | `token_missing` | No `connectParams.auth.token` provided |
| `unauthorized: gateway token mismatch (...)` | `token_mismatch` | Token provided doesn't match `gateway.auth.token` |
| `unauthorized: gateway token not configured on gateway (set gateway.auth.token)` | `token_missing_config` | No token in config file or env vars |

### Reverse Proxy Considerations

**Source**: `/app/dist/gateway/server/ws-connection/message-handler.js` (lines 95-115)

#### Trusted Proxy Detection

OpenClaw checks:
1. `X-Forwarded-For` header presence
2. Remote address against `gateway.trustedProxies` array
3. Host header (`localhost`, `127.0.0.1`, `::1`, or `*.ts.net`)

**Critical Logic**:
```javascript
// If proxy headers present but remote address NOT trusted → NOT local
const hasProxyHeaders = Boolean(forwardedFor || realIp);
const remoteIsTrustedProxy = isTrustedProxyAddress(remoteAddr, trustedProxies);
const hasUntrustedProxyHeaders = hasProxyHeaders && !remoteIsTrustedProxy;

// Warning logged if proxy headers detected from untrusted source
if (hasUntrustedProxyHeaders) {
  logWsControl.warn("Proxy headers detected from untrusted address. " +
    "Connection will not be treated as local. " +
    "Configure gateway.trustedProxies to restore local client detection behind your proxy.");
}
```

#### Required Configuration for Reverse Proxy

**Config Path**: `~/.openclaw/openclaw.json`

```json
{
  "gateway": {
    "trustedProxies": [
      "10.0.0.0/8",       // LXC subnet
      "127.0.0.1",        // Local loopback
      "::1"               // IPv6 loopback
    ]
  }
}
```

**Headers Expected**:
- `X-Forwarded-For`: Client's original IP
- `X-Real-IP`: Alternative to X-Forwarded-For
- `X-Forwarded-Host`: Original Host header

**WebSocket Upgrade**: Standard WebSocket upgrade headers (`Connection: Upgrade`, `Upgrade: websocket`)

### Authentication Modes

**Source**: `/app/dist/gateway/auth.js` → `resolveGatewayAuth()`

| Mode | Config Key | Priority |
|------|-----------|----------|
| `token` | `gateway.auth.token` | Default, recommended |
| `password` | `gateway.auth.password` | Alternative, prompts on every connect |
| Tailscale Serve | `gateway.auth.allowTailscale` | Auto-enabled for Tailscale Serve mode |

**Mode Selection**:
```javascript
const mode = authConfig.mode ?? (password ? "password" : "token");
```

## Current Installation Analysis

### Observed Config
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

### Missing Elements
1. ✗ `gateway.auth.token` not set
2. ✗ `gateway.trustedProxies` not configured
3. ✓ `gateway.mode = "local"` correctly set

### Why Error Occurs
1. Reverse proxy (Traefik at 10.0.x.x) forwards requests to LXC 10.0.10.20:8989
2. OpenClaw sees connection from loopback (Docker internal)
3. BUT: No token in config → `token_missing_config` check fails
4. Local bypass doesn't apply because auth not configured at all
5. WebSocket connection rejected with 1008 close code

## CLI Commands

### Generate Dashboard URL with Token
```bash
# From inside LXC container
docker exec openclaw-openclaw-gateway-1 node /app/dist/cli.js dashboard

# Output:
# Dashboard URL: http://localhost:8989?token=<generated-token>
```

**Note**: This command reads the token from config if present, generates URL with token parameter.

### Configuration Commands
```bash
# Interactive configuration wizard
docker exec -it openclaw-openclaw-gateway-1 node /app/dist/cli.js configure

# Gateway-specific configuration
docker exec -it openclaw-openclaw-gateway-1 node /app/dist/cli.js configure gateway

# Doctor command (health check + fix suggestions)
docker exec -it openclaw-openclaw-gateway-1 node /app/dist/cli.js doctor
```

## Solution Requirements

### 1. Generate Token
Use OpenClaw's token generation algorithm:
```bash
node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
```

### 2. Update Config File
Add to `~/.openclaw/openclaw.json`:
```json
{
  "gateway": {
    "mode": "local",
    "auth": {
      "token": "<generated-48-char-hex>"
    },
    "trustedProxies": [
      "10.0.0.0/8",
      "127.0.0.1",
      "::1"
    ]
  }
}
```

### 3. Restart Gateway
```bash
docker restart openclaw-openclaw-gateway-1
```

### 4. Access Options

#### Option A: Tokenized URL (Recommended)
```
https://openclaw.hoskins.fun?token=<token-from-config>
```

#### Option B: Manual Entry
1. Visit `https://openclaw.hoskins.fun`
2. Click Settings in Control UI
3. Paste token from config file

### 5. Verify Traefik Configuration
Ensure Traefik forwards headers:
```yaml
# In Traefik dynamic config
http:
  middlewares:
    openclaw-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-For: "{{ .Request.RemoteAddr }}"
          X-Real-IP: "{{ .Request.RemoteAddr }}"
          X-Forwarded-Proto: "https"
          X-Forwarded-Host: "openclaw.hoskins.fun"
```

## Security Considerations

### Token Security
- **Length**: 48 hex chars (192 bits entropy) = strong
- **Storage**: File-based (`~/.openclaw/openclaw.json`) with filesystem permissions
- **Transmission**: HTTPS + WSS (encrypted in transit)
- **URL Parameter Warning**: Logs/history exposure noted in code comments

**From source** (`/app/dist/gateway/server-http.js`):
```javascript
logHooks.warn("Hook token provided via query parameter is deprecated for security reasons. " +
  "Tokens in URLs appear in logs, browser history, and referrer headers. " +
  "Use Authorization: Bearer <token> or X-OpenClaw-Token header instead.");
```

**Note**: This warning is for HTTP API hooks, not WebSocket connections. WebSocket auth uses connect params, not HTTP headers.

### Recommended Setup
1. Generate strong token (24 random bytes)
2. Store in config file only (not env vars if shared host)
3. Use HTTPS + WSS for external access
4. Configure `trustedProxies` to prevent auth bypass
5. Rotate token periodically

## Testing Checklist

- [ ] Token generated using crypto.randomBytes(24).toString("hex")
- [ ] Config file updated with token
- [ ] trustedProxies includes LXC subnet (10.0.0.0/8)
- [ ] Gateway container restarted
- [ ] URL with token parameter accessible: `https://openclaw.hoskins.fun?token=...`
- [ ] WebSocket connection succeeds (no 1008 close)
- [ ] Control UI loads and connects
- [ ] Manual token entry works via Settings modal

## References

### Source Files Analyzed
- `/app/dist/gateway/auth.js` - Authentication logic
- `/app/dist/gateway/server/ws-connection/message-handler.js` - WebSocket handshake & errors
- `/app/dist/gateway/net.js` - Proxy detection & trusted IP logic
- `/app/dist/commands/dashboard.js` - Dashboard URL generation
- `/app/dist/commands/configure.gateway.js` - Interactive config wizard
- `/app/dist/commands/onboard-helpers.js` - Token generation utility

### Configuration Schema
```typescript
interface OpencLawConfig {
  gateway?: {
    mode?: "local" | "remote";
    auth?: {
      token?: string;        // 48-char hex
      password?: string;     // Alternative to token
      mode?: "token" | "password";
      allowTailscale?: boolean;
    };
    trustedProxies?: string[];  // IP/CIDR array
    bind?: "loopback" | "tailnet" | "auto" | "lan" | "custom";
    customBindHost?: string;
    controlUi?: {
      basePath?: string;
    };
  };
}
```

### Related Tasks
- **Epic**: T001 - OpenClaw gateway token configuration
- **Task**: T005 - Create OpenClaw Gateway configuration generator
- **Next Steps**: Implement config generator script + documentation

---

## Conclusion

The authentication mechanism is **well-designed and secure**:
1. Strong token generation (192-bit entropy)
2. Constant-time comparison (`timingSafeEqual`)
3. Proxy-aware with explicit trust configuration
4. Multiple delivery mechanisms (URL param, WebSocket param, manual entry)

**Root Cause**: Missing `gateway.auth.token` in config file.

**Resolution**: Add token to config + configure `trustedProxies` + restart gateway.

**Next Task**: Create automated configuration generator script that handles token generation, config updates, and container restart in one command.
