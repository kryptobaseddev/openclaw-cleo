# Server Credentials Quick Reference

## Two Separate Servers

We maintain **TWO parallel bot systems** - do not confuse them:

### OpenClaw (Production)
- **IP**: 10.0.10.20
- **Hostname**: `openclaw`
- **Container**: `openclaw-openclaw-gateway-1`
- **Credentials**: See `.openclaw-creds.env`
- **Status**: Production/Stable
- **Source**: https://github.com/kryptobaseddev/openclaw

### CleoBot (Testing)
- **IP**: 10.0.10.21
- **Hostname**: `cleobot`
- **Container**: `cleobot-cleobot-gateway-1`
- **Credentials**: See `.cleobot-creds.env`
- **Status**: Testing/Development
- **Source**: https://github.com/CleoAgent/cleobot

---

## For Bot Administrators

### If Your Bot Needs to Connect to OpenClaw (10.0.10.20)

```bash
# Load credentials
source .openclaw-creds.env

# Connection details
Host: 10.0.10.20
User: root
Password: ${OPENCLAW_SSH_PASSWORD}
Port: 22

# Test command
sshpass -p "${OPENCLAW_SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no root@10.0.10.20 "hostname"
# Expected: openclaw
```

### If Your Bot Needs to Connect to CleoBot (10.0.10.21)

```bash
# Load credentials
source .cleobot-creds.env

# Connection details
Host: 10.0.10.21
User: root
Password: ${CLEOBOT_SSH_PASSWORD}
Port: 22

# Test command
sshpass -p "${CLEOBOT_SSH_PASSWORD}" ssh -o StrictHostKeyChecking=no root@10.0.10.21 "hostname"
# Expected: cleobot
```

---

## Common Bot Configuration Issues

### Authentication Failures

**Symptom**: "Password authentication failed" or "Permission denied"

**Diagnosis**:
1. Verify which server IP your bot is connecting to (10.0.10.20 or 10.0.10.21)
2. Check that you're using the matching credential file
3. Ensure password is exactly correct (no trailing spaces/newlines)

**Fix**:
```bash
# Verify which server
ssh -v root@<IP> 2>&1 | grep "Connecting to"

# Test with correct credentials
# For OpenClaw (10.0.10.20):
source .openclaw-creds.env
sshpass -p "$OPENCLAW_SSH_PASSWORD" ssh root@10.0.10.20 "hostname"

# For CleoBot (10.0.10.21):
source .cleobot-creds.env
sshpass -p "$CLEOBOT_SSH_PASSWORD" ssh root@10.0.10.21 "hostname"
```

### Wrong Server Configuration

**Symptom**: Bot connects but behaves unexpectedly

**Cause**: Bot configured for OpenClaw but connecting to CleoBot (or vice versa)

**Fix**: Ensure bot configuration matches intended server:
- If bot should use **OpenClaw** → configure with `.openclaw-creds.env` values
- If bot should use **CleoBot** → configure with `.cleobot-creds.env` values

### SSH Logs Show Failures

Check authentication logs on the target server:
```bash
# On OpenClaw (10.0.10.20)
ssh root@10.0.10.20 "journalctl -u ssh -n 20 --no-pager | grep Failed"

# On CleoBot (10.0.10.21)
ssh root@10.0.10.21 "journalctl -u ssh -n 20 --no-pager | grep Failed"
```

Look for patterns:
- Multiple failures from same IP = wrong password
- Failures from unexpected IPs = bot misconfigured
- "Host key verification failed" = SSH known_hosts issue

---

## Environment Variables for Bots

### OpenClaw Bot Configuration
```bash
export BOT_SSH_HOST="10.0.10.20"
export BOT_SSH_USER="root"
export BOT_SSH_PASSWORD="<from .openclaw-creds.env>"
export BOT_BACKEND_URL="http://10.0.10.20:18789"
export BOT_WEB_URL="<from .openclaw-creds.env>"
```

### CleoBot Bot Configuration
```bash
export BOT_SSH_HOST="10.0.10.21"
export BOT_SSH_USER="root"
export BOT_SSH_PASSWORD="<from .cleobot-creds.env>"
export BOT_BACKEND_URL="http://10.0.10.21:18789"
export BOT_WEB_URL="<from .cleobot-creds.env>"
```

---

## Credential File Locations

| File | Purpose | Gitignored |
|------|---------|------------|
| `.openclaw-creds.env` | OpenClaw (10.0.10.20) credentials | ✅ Yes |
| `.cleobot-creds.env` | CleoBot (10.0.10.21) credentials | ✅ Yes |

**Never commit these files to git** - they are gitignored for security.

---

## Security Notes

1. **Passwords are different** between the two servers
2. **Both use root user** for SSH (uid 0)
3. **Docker containers run as node user** (uid 1000)
4. **SSH is password-auth enabled** on both servers
5. **No fail2ban** currently active on either server

---

## For Developers

See `CLAUDE.md` for comprehensive documentation including:
- Architecture diagrams
- Docker container management
- CLEO integration status
- Migration strategy
- Development workflows

---

## Quick Test Script

Save as `test-servers.sh`:
```bash
#!/bin/bash

echo "=== Testing Server Connections ==="

# Test OpenClaw
echo ""
echo "OpenClaw (10.0.10.20):"
source .openclaw-creds.env
if sshpass -p "$OPENCLAW_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@10.0.10.20 "hostname" &>/dev/null; then
    echo "✅ Connection successful"
else
    echo "❌ Connection failed"
fi

# Test CleoBot
echo ""
echo "CleoBot (10.0.10.21):"
source .cleobot-creds.env
if sshpass -p "$CLEOBOT_SSH_PASSWORD" ssh -o StrictHostKeyChecking=no root@10.0.10.21 "hostname" &>/dev/null; then
    echo "✅ Connection successful"
else
    echo "❌ Connection failed"
fi
```

Usage:
```bash
chmod +x test-servers.sh
./test-servers.sh
```
