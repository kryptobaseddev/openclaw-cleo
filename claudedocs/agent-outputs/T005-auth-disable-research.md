# OpenClaw Gateway Authentication Disable Research

**Task**: T005
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

OpenClaw Gateway authentication **cannot be completely disabled** when binding to non-loopback addresses. The authentication system is hardcoded as a security requirement. However, there are **two practical solutions** for your use case with Nginx Proxy Manager authentication.

## Key Findings

### 1. Authentication is Mandatory for Non-Loopback Binds

**Source**: `/app/dist/gateway/server-runtime-config.js`

```javascript
if (!isLoopbackHost(bindHost) && !hasSharedSecret) {
    throw new Error(`refusing to bind gateway to ${bindHost}:${params.port} without auth
        (set gateway.auth.token/password, or set OPENCLAW_GATEWAY_TOKEN/OPENCLAW_GATEWAY_PASSWORD)`);
}
```

**Finding**: The gateway REQUIRES either a token or password when binding to any non-loopback address (0.0.0.0, your LAN IP, etc.). This is a security constraint that cannot be bypassed through configuration.

### 2. Authentication Bypass Only Works for Loopback

**Source**: `/app/dist/gateway/auth.js` - `assertGatewayAuthConfigured()`

```javascript
export function assertGatewayAuthConfigured(auth) {
    if (auth.mode === "token" && !auth.token) {
        if (auth.allowTailscale) {
            return; // ← ONLY bypass path
        }
        throw new Error("gateway auth mode is token, but no token was configured");
    }
}
```

**Finding**: The ONLY way to skip token requirement is:
- Set `gateway.auth.allowTailscale = true`
- AND bind to `loopback` (127.0.0.1)
- This allows Tailscale Serve to authenticate via Tailscale headers instead

This does NOT help with your Nginx Proxy Manager setup.

### 3. Current Configuration

**File**: `~/.openclaw/openclaw.json`

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

**Environment Variables** (from container):
```
OPENCLAW_GATEWAY_TOKEN=861bed3d1a3eefe978317679055b8e617dbb1918a1c46ae3158f712e08c7b03e
```

**Finding**: Token is configured in TWO places (config file + env var). The environment variable takes precedence.

### 4. Browser Token Persistence Issue

**From logs**: All failed connections show `reason=token_missing`

```
[ws] unauthorized conn=... client=openclaw-control-ui webchat reason=token_missing
code=1008 reason=unauthorized: gateway token missing
(open a tokenized dashboard URL or paste token in Control UI settings)
```

**Finding**: The browser is NOT saving the token. The Control UI expects to receive the token via:
1. URL parameter (tokenized dashboard URL)
2. Manual paste in Settings

The token is NOT persisted in browser localStorage/cookies by default for security reasons.

## Configuration Options Available

### Option 1: No Auth Disable Flag

**Searched for**:
- `gateway.auth.enabled = false`
- `gateway.auth.disabled = true`
- `noAuth`, `allowAnonymous`, `publicAccess`, `skipAuth`, `bypassAuth`

**Finding**: NO such configuration options exist in the codebase.

### Option 2: Empty/Null Token

**What happens**: The gateway startup validation would throw an error:

```javascript
throw new Error("gateway auth mode is token, but no token was configured");
```

**Finding**: Cannot use empty string or null as token. It's validated at startup.

### Option 3: Trusted Proxy Bypass

**Configuration**: `gateway.trustedProxies` array

**What it does**: Allows the gateway to read `X-Forwarded-For` headers from trusted reverse proxies.

**What it DOESN'T do**: Does NOT bypass authentication. It only affects IP resolution for logging and Tailscale auth.

## Recommended Solutions

### Solution 1: Generate Tokenized URL (Browser-Friendly)

**Steps**:
1. Generate a permanent dashboard URL with embedded token
2. Bookmark this URL or use it as the "default" behind NPM
3. Browser automatically sends token on each connection

**Implementation**:
```bash
# Inside the container
docker exec openclaw-openclaw-gateway-1 /app/node_modules/.bin/openclaw gateway-status

# Look for the "Tokenized URL" output
# Example: http://10.0.10.20:18789/?token=<token>
```

**Nginx Proxy Manager Setup**:
- Proxy: `https://openclaw.hoskins.fun` → `http://10.0.10.20:18789/?token=<token>`
- This way NPM authenticates users, then forwards to OpenClaw with token

**Pros**:
- No browser manual token entry
- Works seamlessly with NPM auth
- Token is in URL (hidden in browser address bar once SPA loads)

**Cons**:
- Token visible in browser history/bookmarks (acceptable for home network)

### Solution 2: Control UI Settings Token Paste

**Current behavior**: Users must manually paste token in Control UI settings.

**How to find token**:
```bash
# Option 1: Read from config
cat ~/.openclaw/openclaw.json | jq -r '.gateway.auth.token'

# Option 2: Read from environment
docker exec openclaw-openclaw-gateway-1 env | grep OPENCLAW_GATEWAY_TOKEN
```

**Steps**:
1. User authenticates via NPM Access List
2. Control UI loads (currently shows 1008 error)
3. User clicks Settings → paste token → save
4. Token saved in browser localStorage for future sessions

**Pros**:
- Token not in URL
- One-time setup per browser

**Cons**:
- Manual step for each new browser/device
- Users need to find/copy token

### Solution 3: Change Docker Bind + Use Loopback (Most Secure)

**Architecture**:
```
Internet → NPM (443) → localhost:18789 (OpenClaw)
          ↑
     Handles auth & SSL
```

**Docker Compose Change**:
```yaml
ports:
  - "127.0.0.1:18789:18789"  # Only bind to localhost
```

**Benefits**:
- Gateway only accessible via NPM (cannot bypass)
- Still requires token (security defense-in-depth)
- NPM becomes the ONLY entry point

**Configuration**:
```json
{
  "gateway": {
    "bind": "loopback",
    "auth": {
      "token": "<keep-token>"
    }
  }
}
```

**Note**: Even with loopback bind, token is still required. The `allowTailscale` bypass only works for Tailscale Serve authentication mode.

## Authentication Flow Diagram

```
Browser Request
    ↓
Nginx Proxy Manager (Access List auth)
    ↓
https://openclaw.hoskins.fun
    ↓
OpenClaw Gateway (10.0.10.20:18789)
    ↓
WebSocket Upgrade
    ↓
Check connectAuth.token
    ↓
├─ Token present & valid → Allow connection
└─ Token missing/invalid → Close(1008, "unauthorized")
```

## References

**Source Files**:
- `/app/dist/gateway/auth.js` - Authentication logic
- `/app/dist/gateway/server-runtime-config.js` - Bind security checks
- `/app/dist/gateway/server-broadcast.js` - WebSocket 1008 close
- `/app/dist/commands/configure.gateway-auth.js` - Config builder

**Documentation**:
- `README.md` mentions token in `~/.openclaw/openclaw.json (gateway.auth.token)`
- Environment variables: `OPENCLAW_GATEWAY_TOKEN`, `OPENCLAW_GATEWAY_PASSWORD`

**Config Schema**:
```typescript
gateway.auth {
  mode: "token" | "password"
  token?: string
  password?: string
  allowTailscale?: boolean  // Only for Tailscale Serve mode
}
```

## Conclusion

**Answer**: OpenClaw gateway authentication **cannot be disabled** when binding to non-loopback addresses. This is by design for security.

**Best Solution**: Use Solution 1 (Tokenized URL) - Generate a permanent URL with embedded token, use that as your NPM proxy target. This gives you:
- NPM handles user authentication
- OpenClaw token embedded in URL (automatic)
- No manual token paste needed
- Works seamlessly

**Alternative**: Use Solution 2 (Settings token) if you prefer token not in URL, but requires one-time manual paste per browser.

---

## Actionable Next Steps

1. Generate tokenized URL: `docker exec openclaw-openclaw-gateway-1 /app/node_modules/.bin/openclaw gateway-status`
2. Update NPM proxy target to include `?token=<token>` in URL
3. Test browser connection through NPM → should work without 1008 error
4. (Optional) Change docker bind to `127.0.0.1:18789:18789` for defense-in-depth
