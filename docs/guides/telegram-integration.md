# Telegram Bot Integration

Configure Telegram as a communication channel for OpenClaw.

---

## Overview

Telegram integration allows you to:
- Send commands to OpenClaw via direct messages
- Receive proactive notifications (task updates, alerts)
- Approve sensitive operations (financial transactions, deletions)
- Pair multiple users with role-based access

---

## Prerequisites

- Telegram account
- Doppler configured (see [Doppler Setup Guide](doppler-setup.md))
- OpenClaw installed

---

## Step 1: Create Bot with @BotFather

1. Open Telegram and search for `@BotFather`
2. Start conversation with `/start`
3. Create new bot: `/newbot`
4. **Bot Name**: `OpenClaw Assistant` (or your preferred name)
5. **Bot Username**: Must end in `bot` (e.g., `yourname_openclaw_bot`)
6. BotFather will reply with:
   - Bot token (format: `YOUR_BOT_TOKEN_FROM_BOTFATHER`)
   - Link to your bot

**Copy the bot token** - you'll need it for Doppler.

---

## Step 2: Configure Bot Settings (Optional)

Customize your bot with @BotFather:

```
/setdescription - Set bot description
/setabouttext - Set "About" text
/setuserpic - Set profile picture
/setcommands - Set command list for auto-complete
```

### Recommended Commands

```
start - Initialize pairing
help - Show available commands
status - Agent status
tasks - List active tasks
cancel - Cancel current operation
```

---

## Step 3: Add Token to Doppler

1. Login to [Doppler](https://doppler.com)
2. Navigate to `openclaw` → `prd` config
3. Click **+ Add Secret**
4. **Name**: `TELEGRAM_BOT_TOKEN`
5. **Value**: Paste the token from BotFather
6. Click **Save**

### CLI Method

```bash
doppler secrets set TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_FROM_BOTFATHER" \
  --project openclaw --config prd
```

---

## Step 4: Enable in OpenClaw

### During Installation

If using the installer, Telegram is auto-configured when `TELEGRAM_BOT_TOKEN` exists in Doppler.

### Post-Installation Configuration

Edit OpenClaw config:

```bash
# SSH into container
pct enter <CTID>

# Edit config
nano ~/.openclaw/openclaw.json
```

Add Telegram channel:

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing",
      "token": "${TELEGRAM_BOT_TOKEN}"
    }
  }
}
```

Restart OpenClaw:

```bash
docker restart openclaw
```

---

## Step 5: Pair Your Account

1. **Find your bot** in Telegram (search for `@yourname_openclaw_bot`)
2. **Start conversation**: Send `/start`
3. Bot will respond with a **pairing code** (e.g., `PAIR-A7F3C8`)
4. **Enter code** in OpenClaw Control UI:
   - Open browser: `http://<container-ip>:18793`
   - Navigate to **Channels** → **Telegram**
   - Click **Pair User**
   - Enter pairing code
   - Assign role (Owner, Admin, User, Viewer)

**Screenshot placeholder**: `![Pairing Flow](../assets/telegram-pairing.png)`

---

## Step 6: Test Integration

Send a test message to your bot:

```
/status
```

Expected response:
```
✅ OpenClaw Gateway Status
Version: 2026.1
Uptime: 2h 15m
Active Tasks: 3
Last Heartbeat: 2 minutes ago
```

---

## Configuration Options

### DM Policy

Controls who can message the bot:

| Policy | Behavior |
|--------|----------|
| `open` | Anyone can message (not recommended) |
| `pairing` | Only paired users can interact |
| `allowlist` | Only users in allowlist |

**Recommended**: `pairing`

### Role-Based Access

| Role | Permissions |
|------|-------------|
| **Owner** | Full access, can pair users, approve all operations |
| **Admin** | Execute commands, approve non-destructive operations |
| **User** | Read-only, receive notifications |
| **Viewer** | Notifications only, no commands |

---

## Usage Examples

### Check Task Status

```
/tasks

# Response:
📋 Active Tasks (3)
- T1234: Implement feature X [in-progress]
- T1235: Fix bug Y [blocked]
- T1236: Write tests [todo]
```

### Request Operation Approval

When OpenClaw requires approval (financial, destructive operations):

```
🚨 Approval Required

Operation: Delete 47 old backup files
Impact: Free 2.3GB storage
Risk: Medium

Reply:
✅ /approve
❌ /deny
```

### Send Proactive Notifications

OpenClaw can send heartbeat updates:

```
☀️ Morning Brief (8:00 AM)

Overdue Tasks: 2
Pending PRs: 1
GitHub Notifications: 3
Weather: Sunny, 72°F

/details for full report
```

---

## Security Best Practices

| Practice | Rationale |
|----------|-----------|
| **Enable pairing** | Prevents unauthorized access |
| **Limit Owner role** | Only trusted users |
| **Don't share bot token** | Anyone with token controls bot |
| **Rotate token periodically** | Via @BotFather `/token` |
| **Review paired users** | Revoke inactive users |

---

## Troubleshooting

### Bot not responding

**Cause**: Token invalid or bot disabled

**Fix**:
```bash
# Verify token in Doppler
doppler secrets get TELEGRAM_BOT_TOKEN --project openclaw --config prd --plain

# Test token manually
curl https://api.telegram.org/bot<YOUR_TOKEN>/getMe

# Should return bot info
```

### Pairing code expired

**Cause**: Codes expire after 10 minutes

**Fix**:
```
# Request new code
/start

# Or reset pairing in Control UI
```

### Messages not reaching bot

**Cause**: Bot blocked or deleted

**Fix**:
1. Check @BotFather for bot status
2. Unblock bot in Telegram settings
3. Restart conversation with `/start`

---

## Advanced: Multiple Bots

For dev/staging/prod environments:

```bash
# Create separate bots
@BotFather /newbot
  Name: OpenClaw Dev
  Username: yourname_openclaw_dev_bot

# Add to Doppler
doppler secrets set TELEGRAM_BOT_TOKEN="<dev-token>" --project openclaw --config dev
doppler secrets set TELEGRAM_BOT_TOKEN="<prod-token>" --project openclaw --config prd
```

---

## Revoking Access

### Unpair User

1. Control UI → Channels → Telegram → **Paired Users**
2. Select user → **Revoke Access**

### Disable Bot Entirely

```json
{
  "channels": {
    "telegram": {
      "enabled": false
    }
  }
}
```

### Delete Bot

Via @BotFather:
```
/deletebot
```

**Warning**: Cannot be undone. Token will be invalidated.

---

## Next Steps

- [Discord Integration](discord-integration.md) - Add Discord as a channel
- [Reverse Proxy Setup](reverse-proxy.md) - Secure external access
- [Doppler Setup](doppler-setup.md) - Secret management configuration

---

## References

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [BotFather Commands](https://core.telegram.org/bots#botfather)
- [OpenClaw Channels Documentation](https://docs.openclaw.ai/channels/telegram)
