# WebSocket Disconnect Debug Research

**Task**: T005
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

WebSocket connections from the public URL `https://openclaw.hoskins.fun?token=a7a3d116acb2dc822631d15f8c785fdfb54c8c0c09a8d628` fail with "token_mismatch" errors even though the token in the URL matches the gateway configuration. The root cause is that the Control UI extracts the token from the URL query parameters and stores it in browser localStorage, but the token is only used when establishing the WebSocket connection IF it's being passed from settings. When accessing via tokenized URL for the first time, there's a potential timing or persistence issue where the WebSocket connection attempt happens before or without the URL token being properly applied.

---

## Problem Analysis

### Observed Behavior

Gateway logs show consistent unauthorized connection attempts:
```
unauthorized conn=<id> remote=10.0.10.8 client=openclaw-control-ui webchat vdev reason=token_mismatch
closed before connect code=1008 reason=unauthorized: gateway token mismatch (open a tokenized dashboard URL or paste token in Control UI settings)
```

### Configuration State

**Gateway Configuration** (`~/.openclaw/openclaw.json`):
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

**Network Configuration**:
- Port 18789: HTTP Control UI (docker-proxy listening)
- Port 18790: WebSocket endpoint (docker-proxy listening)
- NPM proxies both ports from `openclaw.hoskins.fun`

**Proxy Warning** (non-critical but notable):
```
Proxy headers detected from untrusted address. Connection will not be treated as local.
Configure gateway.trustedProxies to restore local client detection behind your proxy.
```

Despite having `trustedProxies` configured, the NPM proxy IP (10.0.10.8) is showing this warning, suggesting the gateway might not be reading the updated config properly or the proxy address needs to be added.

---

## Root Cause Analysis

### Token Flow

1. **URL to Settings** (`/app/ui/src/ui/app-settings.ts` lines 73-88):
   ```typescript
   export function applySettingsFromUrl(host: SettingsHost) {
     if (!window.location.search) return;
     const params = new URLSearchParams(window.location.search);
     const tokenRaw = params.get("token");

     if (tokenRaw != null) {
       const token = tokenRaw.trim();
       if (token && token !== host.settings.token) {
         applySettings(host, { ...host.settings, token });
       }
       params.delete("token");
       shouldCleanUrl = true;
     }
   }
   ```
   - Token is extracted from URL query parameter
   - Saved to settings via `applySettings` → `saveSettings` → localStorage
   - URL is cleaned (token removed from query string)

2. **Settings to WebSocket** (`/app/ui/src/ui/gateway.ts` lines 120-155):
   ```typescript
   let authToken = this.opts.token;

   if (isSecureContext) {
     deviceIdentity = await loadOrCreateDeviceIdentity();
     const storedToken = loadDeviceAuthToken({
       deviceId: deviceIdentity.deviceId,
       role,
     })?.token;
     authToken = storedToken ?? this.opts.token;
   }

   const auth = authToken || this.opts.password
     ? { token: authToken, password: this.opts.password }
     : undefined;
   ```
   - WebSocket client receives token via `opts.token` constructor parameter
   - If device-specific token exists in localStorage, it takes precedence
   - Fallback to `opts.token` if no device token

### The Mismatch

**Token in Gateway Config**: `a7a3d116acb2dc822631d15f8c785fdfb54c8c0c09a8d628`

**Potential Issues**:

1. **Device Token Persistence**: The gateway uses device-based authentication where each browser device generates a unique identity and can receive a device-specific token. If a device token was previously stored for this browser but the gateway was reset or reconfigured, the stored device token would no longer match.

2. **Race Condition**: WebSocket connection might be initiated before `applySettingsFromUrl` completes, especially if:
   - The app initializes WebSocket immediately on load
   - Settings persistence (localStorage) hasn't completed
   - Device identity generation/loading delays the token application

3. **Settings Not Propagated**: The token extracted from URL might not be properly passed to the WebSocket client constructor. Need to verify the app initialization flow connects `applySettingsFromUrl` → WebSocket client instantiation.

---

## Network Architecture

### Port Configuration
- **18789**: HTTP serving Control UI (`/app/dist/control-ui/`)
- **18790**: WebSocket gateway endpoint
- Both ports proxied through NPM at `openclaw.hoskins.fun`

### Proxy Headers
Gateway receives:
- `remote=10.0.10.8` (NPM proxy internal IP)
- `fwd=67.187.175.97, 172.69.34.xxx` (client IP, Cloudflare IP)
- `origin=https://openclaw.hoskins.fun`

The warning about untrusted proxy suggests `10.0.10.8` (NPM proxy) might need to be explicitly added to `trustedProxies`, though this is a secondary issue.

---

## Key Findings

1. **Token extraction works correctly**: Code properly extracts token from URL query parameter
2. **Token persistence works**: Settings are saved to localStorage via `saveSettings`
3. **WebSocket authentication flow is complex**: Uses device identity + device tokens with fallback to shared token
4. **Device token takes precedence**: If a device-specific token exists, it overrides the URL token
5. **Proxy headers warning**: NPM proxy IP not fully trusted (minor issue)
6. **Race condition possible**: Timing between settings application and WebSocket connection unclear

---

## Recommended Solutions

### Solution 1: Clear Browser Storage (Immediate)
**Simplest fix for testing**:
1. Open browser DevTools
2. Application → Storage → Clear site data
3. Reload with tokenized URL: `https://openclaw.hoskins.fun?token=a7a3d116acb2dc822631d15f8c785fdfb54c8c0c09a8d628`

**Why**: Removes any stale device tokens that might be overriding the URL token.

### Solution 2: Add NPM Proxy to Trusted Proxies
**Configuration update**:
```json
{
  "gateway": {
    "trustedProxies": [
      "10.0.10.0/24",
      "10.0.10.8",      // Add NPM proxy explicitly
      "127.0.0.1",
      "172.16.0.0/12"
  ]
}
```

Then restart gateway:
```bash
docker restart openclaw-openclaw-gateway-1
```

**Why**: Ensures gateway properly recognizes connections from the reverse proxy.

### Solution 3: Add Debugging to Token Flow
**For deeper investigation**, add logging to:
1. `applySettingsFromUrl`: Log extracted token value
2. `GatewayBrowserClient.sendConnect`: Log `authToken` value being sent
3. Gateway server auth handler: Log expected vs received token

### Solution 4: Force Token on Each Connection
**Code modification** (if needed):
Modify WebSocket client initialization to always prioritize URL/settings token over device token for Control UI mode.

### Solution 5: Verify App Initialization Order
Check `/app/ui/src/ui/app.ts` and `/app/ui/src/main.ts` to ensure:
1. `applySettingsFromUrl` runs before WebSocket client creation
2. WebSocket client receives updated settings after URL token extraction

---

## Testing Steps

1. **Clear browser storage** (DevTools → Application → Clear site data)
2. **Access tokenized URL**: `https://openclaw.hoskins.fun?token=a7a3d116acb2dc822631d15f8c785fdfb54c8c0c09a8d628`
3. **Check browser console** for errors
4. **Check Network tab** → WS tab to see WebSocket connection attempts
5. **Check gateway logs**: `docker logs openclaw-openclaw-gateway-1 -f`
6. **Verify localStorage**: DevTools → Application → Local Storage → check `openclaw:settings` or similar key

---

## Related Files

### Control UI Source
- `/app/ui/src/ui/app-settings.ts` - URL token extraction
- `/app/ui/src/ui/gateway.ts` - WebSocket client and auth
- `/app/ui/src/ui/app.ts` - App initialization
- `/app/ui/src/ui/device-auth.ts` - Device token storage
- `/app/ui/src/ui/storage.ts` - localStorage persistence

### Gateway Configuration
- `~/.openclaw/openclaw.json` - Gateway config with token and trustedProxies
- Port 18789 (HTTP) and 18790 (WebSocket) mapped to container

### NPM Proxy
- Internal IP: 10.0.10.8
- External: openclaw.hoskins.fun
- Proxies both HTTP and WebSocket upgrade requests

---

## References

- Epic: T001 - Complete OpenClaw installation and access
- Task: T005 - Debug WebSocket disconnect issue
- Gateway logs show "token_mismatch" with "unauthorized: gateway token mismatch"
- Configuration has correct token: `a7a3d116acb2dc822631d15f8c785fdfb54c8c0c09a8d628`
