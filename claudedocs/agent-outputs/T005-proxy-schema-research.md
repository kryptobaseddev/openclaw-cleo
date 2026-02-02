# OpenClaw Proxy Trust and Schema Research

**Task**: T005
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Executive Summary

OpenClaw **does not support auth bypass** for trusted proxies. Token authentication is mandatory for all connections, including those from trusted proxy addresses. The WebSocket disconnections are caused by missing/invalid tokens, and the "Schema unavailable" issue is a permission problem with the `/home/node/.openclaw/devices` directory.

---

## Key Findings

### 1. No Auth Bypass Mode

**Finding**: OpenClaw's gateway authentication cannot be disabled or bypassed for trusted proxies.

**Evidence from source code** (`/app/dist/gateway/auth.js`):

```javascript
export async function authorizeGatewayConnect(params) {
    const { auth, connectAuth, req, trustedProxies } = params;
    const localDirect = isLocalDirectRequest(req, trustedProxies);

    // Tailscale check (only if allowTailscale is true)
    if (auth.allowTailscale && !localDirect) {
        const tailscaleCheck = await resolveVerifiedTailscaleUser({...});
        if (tailscaleCheck.ok) {
            return { ok: true, method: "tailscale", user: tailscaleCheck.user.login };
        }
    }

    // Token auth (ALWAYS required if mode is token)
    if (auth.mode === "token") {
        if (!auth.token) {
            return { ok: false, reason: "token_missing_config" };
        }
        if (!connectAuth?.token) {
            return { ok: false, reason: "token_missing" };
        }
        if (!safeEqual(connectAuth.token, auth.token)) {
            return { ok: false, reason: "token_mismatch" };
        }
        return { ok: true, method: "token" };
    }
    // ... password mode similar
}
```

**Key observations**:
- `isLocalDirectRequest()` detects local connections but **does not bypass auth**
- `gateway.trustedProxies` is used ONLY for IP resolution, not auth bypass
- Token validation is mandatory even when `localDirect === true`
- No configuration option exists to disable auth for trusted sources

### 2. WebSocket Disconnect Root Cause

**Log evidence**:
```
[ws] unauthorized conn=... reason=token_missing
[ws] closed before connect ... code=1008 reason=unauthorized: gateway token missing
```

**Analysis**:
- Nginx Proxy Manager forwards the HTTP request to OpenClaw
- OpenClaw sees proxy headers (`X-Forwarded-For`, `X-Real-IP`)
- `10.0.10.8` (NPM) is NOT in `trustedProxies` list
- Connection gets warning: "Proxy headers detected from untrusted address"
- WebSocket connection attempts without token → rejected with code 1008

**Current config** (`~/.openclaw/openclaw.json`):
```json
{
  "gateway": {
    "mode": "local",
    "auth": {
      "token": "a7a3d116acb2dc822631d15f8c785fdfb54c8c0c09a8d628"
    },
    "trustedProxies": [
      "10.0.10.0/24",
      "127.0.0.1",
      "172.16.0.0/12"
    ]
  }
}
```

**Issue**: NPM at `10.0.10.8` should be recognized as trusted, but the warning still appears. This suggests either:
1. The config hasn't been fully reloaded
2. The CIDR `10.0.10.0/24` isn't matching correctly
3. NPM is forwarding from Cloudflare IPs which aren't in the trusted list

### 3. Schema Unavailable Root Cause

**Log evidence**:
```
[gateway] parse/handle error: Error: EACCES: permission denied, mkdir '/home/node/.openclaw/devices'
[ws] ✗ parse-error error=Error: EACCES: permission denied, mkdir '/home/node/.openclaw/devices'
[ws] closed before connect ... code=1000 reason=n/a
```

**Permission analysis**:
```bash
# Current state
drwxr-xr-x 10 root root 4096 Feb  2 04:34 /home/node/.openclaw/
# Missing directory
ls: cannot access '/home/node/.openclaw/devices': No such file or directory
```

**Root cause**:
- Gateway runs as user `node` (UID 1000)
- `/home/node/.openclaw/` is owned by `root:root`
- `node` user cannot create `devices/` subdirectory
- When WebSocket connects, gateway tries to initialize device directory
- Permission denied → connection drops → schema fails to load

**Why this causes "Schema unavailable"**:
- `/channels` page needs device channel definitions
- Device channels require device registry
- Device registry needs `/home/node/.openclaw/devices/`
- If directory creation fails, no device channels → "Schema unavailable"

### 4. Trusted Proxy Configuration

**Current implementation** (`/app/dist/gateway/auth.js`):

```javascript
export function isLocalDirectRequest(req, trustedProxies) {
    const clientIp = resolveRequestClientIp(req, trustedProxies) ?? "";
    if (!isLoopbackAddress(clientIp)) {
        return false;
    }
    const host = getHostName(req.headers?.host);
    const hostIsLocal = host === "localhost" || host === "127.0.0.1" || host === "::1";
    const hostIsTailscaleServe = host.endsWith(".ts.net");
    const hasForwarded = Boolean(req.headers?.["x-forwarded-for"] ||
                                  req.headers?.["x-real-ip"] ||
                                  req.headers?.["x-forwarded-host"]);
    const remoteIsTrustedProxy = isTrustedProxyAddress(req.socket?.remoteAddress, trustedProxies);

    return (hostIsLocal || hostIsTailscaleServe) && (!hasForwarded || remoteIsTrustedProxy);
}
```

**What `trustedProxies` does**:
- Allows OpenClaw to trust `X-Forwarded-For` header for IP resolution
- Suppresses "untrusted proxy" warnings
- **Does NOT bypass authentication**

**What it doesn't do**:
- Skip token validation
- Allow unauthenticated connections
- Disable WebSocket auth checks

### 5. NPM Proxy Requirements

**Required proxy headers**:
- `X-Forwarded-For` - Client IP address
- `X-Real-IP` - Alternative client IP
- `X-Forwarded-Host` - Original hostname
- `X-Forwarded-Proto` - Original protocol (https)

**WebSocket upgrade headers**:
- `Upgrade: websocket`
- `Connection: Upgrade`
- `Sec-WebSocket-Key`
- `Sec-WebSocket-Version: 13`

**NPM configuration needs**:
1. Add custom locations to forward all proxy headers
2. Enable WebSocket support
3. Pass through `Upgrade` and `Connection` headers
4. Ensure origin header matches OpenClaw's host

### 6. Authentication Methods Available

**From source analysis**:

1. **Token mode** (current):
   - Set `gateway.auth.token` in config
   - Client must send token in WebSocket connection params
   - No bypass for local/proxy connections

2. **Password mode**:
   - Set `gateway.auth.password` in config
   - Client enters password in UI
   - Slightly more user-friendly than token URLs

3. **Tailscale mode**:
   - Requires `allowTailscale: true`
   - Only works with Tailscale Serve proxy
   - Validates against Tailscale WHOIS
   - Still requires fallback token/password for non-Tailscale clients

**No "trust proxy" or "disable auth" mode exists.**

---

## Solutions Analysis

### Option A: Use Tokenized URLs (Current Design)

**How it works**:
```
https://openclaw.hoskins.fun/?gwt=a7a3d116acb2dc822631d15f8c785fdfb54c8c0c09a8d628
```

**Pros**:
- Officially supported
- No code changes needed
- Works with any reverse proxy

**Cons**:
- Token visible in URL bar
- Can't bookmark without token
- Token in browser history

### Option B: Set Token in Control UI Settings

**How it works**:
1. User navigates to `https://openclaw.hoskins.fun/`
2. Opens Control UI settings
3. Pastes gateway token
4. Token stored in browser localStorage

**Pros**:
- Token not in URL
- One-time setup per browser
- Clean URLs

**Cons**:
- Manual setup required
- Must repeat on each device/browser
- Token still visible in browser DevTools

### Option C: Switch to Password Mode

**Configuration**:
```json
{
  "gateway": {
    "auth": {
      "mode": "password",
      "password": "your-secure-password"
    }
  }
}
```

**Pros**:
- More user-friendly
- Can be remembered by browser
- No token in URL

**Cons**:
- Still requires authentication
- Password prompt on first visit
- Same security level as token

### Option D: Deploy Behind Tailscale Serve

**Configuration**:
```json
{
  "gateway": {
    "auth": {
      "mode": "token",
      "token": "fallback-token",
      "allowTailscale": true
    },
    "tailscale": {
      "mode": "serve"
    }
  }
}
```

**Pros**:
- SSO via Tailscale identity
- No manual token/password entry
- Secure by Tailscale auth

**Cons**:
- Requires Tailscale deployment
- All users must be on Tailnet
- Public access not possible

---

## Required Fixes

### Fix 1: Repair Device Directory Permissions

**Problem**: `/home/node/.openclaw/` owned by root, prevents device directory creation

**Solution**:
```bash
# On Docker host
docker exec openclaw-openclaw-gateway-1 chown -R node:node /home/node/.openclaw

# Or fix just devices directory
docker exec openclaw-openclaw-gateway-1 mkdir -p /home/node/.openclaw/devices
docker exec openclaw-openclaw-gateway-1 chown -R node:node /home/node/.openclaw/devices
```

**Impact**: Resolves "Schema unavailable" on `/channels` page

### Fix 2: Update NPM Trusted Proxy Detection

**Problem**: NPM at `10.0.10.8` should be in trusted list but warnings still appear

**Verification needed**:
```bash
# Check if NPM is forwarding Cloudflare IPs
docker logs openclaw-openclaw-gateway-1 | grep "remote="
```

**Potential solution**:
```json
{
  "gateway": {
    "trustedProxies": [
      "10.0.10.0/24",        // NPM server
      "127.0.0.1",
      "172.16.0.0/12",
      "173.245.48.0/20",     // Cloudflare IPs (if needed)
      "103.21.244.0/22",
      "103.22.200.0/22",
      "103.31.4.0/22",
      "141.101.64.0/18",
      "108.162.192.0/18",
      "190.93.240.0/20"
    ]
  }
}
```

### Fix 3: Configure NPM WebSocket Forwarding

**Required NPM config** (Advanced → Custom Nginx Configuration):
```nginx
# WebSocket upgrade
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;

# Proxy headers
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;

# Timeouts for WebSocket
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
```

**NPM → Streams required**:
```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
```

---

## Recommendations

### Immediate Actions

1. **Fix device directory permissions** (5 minutes)
   ```bash
   docker exec openclaw-openclaw-gateway-1 chown -R node:node /home/node/.openclaw
   docker restart openclaw-openclaw-gateway-1
   ```

2. **Configure NPM WebSocket support** (10 minutes)
   - Add custom Nginx config for WebSocket upgrade
   - Verify headers are forwarded correctly

3. **Use Control UI token entry** (user action)
   - Document steps for users to paste token in settings
   - This avoids token in URL while maintaining security

### Medium-term Solution

Create configuration generator script that:
1. Detects proxy type (NPM, Traefik, Caddy, etc.)
2. Generates appropriate config for OpenClaw
3. Generates proxy config snippets
4. Validates WebSocket forwarding

### Long-term Enhancement

**Feature request for OpenClaw**: Add `gateway.auth.trustLocal` option:
```json
{
  "gateway": {
    "auth": {
      "mode": "token",
      "token": "secure-token",
      "trustLocal": true  // NEW: Skip auth for localhost + trustedProxies
    }
  }
}
```

This would require upstream code changes but align with user expectations for home lab deployments.

---

## References

- Epic: T001
- Current config: `~/.openclaw/openclaw.json`
- Source files analyzed:
  - `/app/dist/gateway/auth.js` - Authentication logic
  - `/app/dist/gateway/net.js` - Proxy header handling
  - `/app/dist/gateway/server/ws-connection/message-handler.js` - WebSocket connection handling
  - Container logs: `docker logs openclaw-openclaw-gateway-1`

---

## Actionable Next Steps

1. Fix device directory permissions (immediate)
2. Configure NPM proxy headers correctly
3. Document token setup via Control UI settings
4. Create T006: Configuration generator for proxy deployments
5. Create T007: Validate NPM WebSocket forwarding
6. Create T008: Test schema availability post-fix
