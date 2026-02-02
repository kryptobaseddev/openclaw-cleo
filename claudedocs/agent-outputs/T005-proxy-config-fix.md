# Trusted Proxy Configuration Fix

**Task**: T005
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

Successfully added NPM proxy IP (10.0.10.8) to gateway trustedProxies configuration and restarted the gateway container. Configuration change was detected automatically and gateway reloaded.

## Implementation Steps

### 1. Retrieved Current Configuration
```bash
sshpass -p 'iD7wExcIz+1kRHOl' ssh -o StrictHostKeyChecking=no root@10.0.10.20 'cat ~/.openclaw/openclaw.json'
```

**Before**:
```json
"trustedProxies": [
  "10.0.10.0/24",
  "127.0.0.1",
  "172.16.0.0/12"
]
```

### 2. Updated Configuration
```bash
sshpass -p 'iD7wExcIz+1kRHOl' ssh -o StrictHostKeyChecking=no root@10.0.10.20 'jq ".gateway.trustedProxies = [\"10.0.10.0/24\", \"127.0.0.1\", \"172.16.0.0/12\", \"10.0.10.8\"]" ~/.openclaw/openclaw.json > /tmp/openclaw.json && mv /tmp/openclaw.json ~/.openclaw/openclaw.json && chown 1000:1000 ~/.openclaw/openclaw.json'
```

**After**:
```json
"trustedProxies": [
  "10.0.10.0/24",
  "127.0.0.1",
  "172.16.0.0/12",
  "10.0.10.8"
]
```

### 3. Restarted Gateway Container
```bash
docker restart openclaw-openclaw-gateway-1
```

Container restarted successfully. Status: Up 8 seconds

### 4. Verified Configuration Reload

Gateway logs show automatic config reload:
```
2026-02-02T04:50:22.520Z [reload] config change detected; evaluating reload (agents.defaults.compaction, gateway.trustedProxies)
2026-02-02T04:50:22.521Z [reload] config change requires gateway restart (gateway.trustedProxies)
2026-02-02T04:50:22.524Z [gateway] received SIGUSR1; restarting
2026-02-02T04:50:36.486Z [gateway] listening on ws://0.0.0.0:18789 (PID 7)
```

### 5. Verified Warnings Resolved

Checked logs before and after restart:
- **Before restart** (4:49:XX): Multiple "Proxy headers detected from untrusted address" warnings
- **After restart** (4:50:36+): No new proxy warnings detected

## Results

- ✅ Configuration updated successfully
- ✅ Gateway container restarted
- ✅ Config change detected and reloaded automatically
- ✅ No proxy warnings after restart
- ✅ Container running normally

## Technical Details

**Target System**: 10.0.10.20
**Container**: openclaw-openclaw-gateway-1
**Config File**: ~/.openclaw/openclaw.json
**Added IP**: 10.0.10.8 (NPM proxy)

## References

- Epic: T001
- Task: T005
