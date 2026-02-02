# OpenClaw Permissions Fix

**Task**: T005
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

Successfully fixed permission issues preventing OpenClaw Gateway from accessing schema and device directories. All files in ~/.openclaw are now owned by uid 1000:1000 (node user inside container), and required directories (devices, workspace, canvas) have been created with correct permissions.

## Problem Analysis

The OpenClaw container runs as uid 1000 (node user), but the host directory `/root/.openclaw` and its contents were owned by root (uid 0). When mounted into the container at `/home/node/.openclaw`, the node process could not create required directories like `devices/`, resulting in:
- `EACCES: permission denied, mkdir '/home/node/.openclaw/devices'`
- Schema loading failures
- WebSocket connection errors

## Implementation Steps

### 1. Initial Permission Audit
Checked current ownership of host directory:
```bash
ls -la ~/.openclaw/
```
Result: Mixed ownership - some directories owned by root, some by 1000:1000

### 2. Recursive Ownership Fix
Applied correct ownership recursively to entire .openclaw directory:
```bash
chown -R 1000:1000 ~/.openclaw/
```

### 3. Directory Structure Creation
Ensured all required directories exist with correct permissions:
```bash
mkdir -p ~/.openclaw/devices ~/.openclaw/workspace ~/.openclaw/canvas
chown -R 1000:1000 ~/.openclaw/
```

### 4. Container Restart
Restarted container to pick up permission changes:
```bash
docker restart openclaw-openclaw-gateway-1
```

### 5. Verification
Confirmed:
- All directories now owned by 1000:1000 on host
- Inside container, all directories show as node:node (correct)
- Container logs show clean startup with no permission errors
- Gateway service starts successfully

## Results

### Before Fix
```
drwxr-xr-x 10 root root 4096 Feb  2 04:34 .openclaw
drwxr-xr-x  2 root root 4096 Feb  2 03:38 config
drwxr-xr-x  2 root root 4096 Feb  2 03:38 credentials
[EACCES errors in logs]
```

### After Fix
```
drwxr-xr-x 11 1000 1000 4096 Feb  2 04:41 .openclaw
drwxr-xr-x  2 1000 1000 4096 Feb  2 03:38 config
drwxr-xr-x  2 1000 1000 4096 Feb  2 03:38 credentials
drwxr-xr-x  2 1000 1000 4096 Feb  2 04:41 devices
[clean startup logs]
```

### Container View (Inside)
```
drwxr-xr-x 11 node node 4096 Feb  2 04:41 .openclaw
drwxr-xr-x  2 node node 4096 Feb  2 04:41 devices
drwxr-xr-x  3 node node 4096 Feb  2 04:19 workspace
drwxr-xr-x  2 node node 4096 Feb  2 04:23 canvas
```

## Success Criteria Met

- ✅ All files in ~/.openclaw owned by 1000:1000
- ✅ devices, workspace, canvas directories exist
- ✅ No permission errors in container logs after restart
- ✅ Container running stable
- ✅ Gateway service listening on ws://0.0.0.0:18789

## Remaining Issues

The following warnings in logs are unrelated to permissions and need separate fixes:
1. **Proxy headers warning**: "Proxy headers detected from untrusted address" - requires trustedProxies configuration
2. **Token mismatch**: "unauthorized: gateway token mismatch" - authentication issue requiring tokenized dashboard URL

These are configuration issues, not permission problems, and are outside the scope of this task.

## References

- Epic: T001 (OpenClaw Installation)
- Task: T005 (Permissions Fix)
- Container: openclaw-openclaw-gateway-1
- Mount: /root/.openclaw → /home/node/.openclaw
- Process UID: 1000 (node user)
