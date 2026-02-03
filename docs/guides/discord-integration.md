# Discord Bot Integration

Configure Discord as a communication channel for OpenClaw.

---

## Overview

Discord integration enables:
- Slash commands (`/openclaw status`)
- Proactive notifications in channels
- DM-based pairing for secure operations
- Multi-server support with role-based access

---

## Prerequisites

- Discord account
- Server where you have "Manage Server" permission
- Doppler configured (see [Doppler Setup Guide](doppler-setup.md))
- OpenClaw installed

---

## Step 1: Create Discord Application

1. Visit [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application**
3. **Name**: `OpenClaw` (or your preferred name)
4. Accept Developer ToS
5. Click **Create**

**Screenshot placeholder**: `![Create Application](../assets/discord-create-app.png)`

---

## Step 2: Create Bot User

1. In your application, navigate to **Bot** (left sidebar)
2. Click **Add Bot** → **Yes, do it!**
3. **Bot Username**: `OpenClaw` (can be changed later)
4. Under **Token**, click **Reset Token** (if needed) → **Copy**

**Important**: Copy the token immediately - it's shown only once.

Format: `YOUR_BOT_ID.RANDOM.TOKEN_STRING_HERE`

---

## Step 3: Configure Bot Permissions

### Required Intents

Under **Bot** → **Privileged Gateway Intents**, enable:

| Intent | Required? | Purpose |
|--------|-----------|---------|
| **Presence Intent** | Optional | See user online status |
| **Server Members Intent** | ✅ Yes | Access member list for role checks |
| **Message Content Intent** | ✅ Yes | Read message content for commands |

**Screenshot placeholder**: `![Enable Intents](../assets/discord-intents.png)`

### Bot Permissions

Under **Bot** → **Bot Permissions**, select:

| Permission | Purpose |
|------------|---------|
| Send Messages | Reply to commands |
| Send Messages in Threads | Thread support |
| Embed Links | Rich embeds |
| Attach Files | Send logs, reports |
| Read Message History | Context for conversations |
| Add Reactions | Acknowledge commands |
| Use Slash Commands | `/openclaw` commands |

**Permissions Integer**: `277025770496` (for reference)

---

## Step 4: Add Token to Doppler

1. Login to [Doppler](https://doppler.com)
2. Navigate to `openclaw` → `prd` config
3. Click **+ Add Secret**
4. **Name**: `DISCORD_BOT_TOKEN`
5. **Value**: Paste the token from Discord
6. Click **Save**

### CLI Method

```bash
doppler secrets set DISCORD_BOT_TOKEN="YOUR_DISCORD_BOT_TOKEN" \
  --project openclaw --config prd
```

---

## Step 5: Generate Invite URL

1. In Discord Developer Portal, navigate to **OAuth2** → **URL Generator**
2. **Scopes**: Select `bot` and `applications.commands`
3. **Bot Permissions**: Select same as Step 3 (or copy integer: `277025770496`)
4. **Copy** the generated URL at bottom

Example URL:
```
https://discord.com/api/oauth2/authorize?client_id=1234567890&permissions=277025770496&scope=bot%20applications.commands
```

---

## Step 6: Invite Bot to Server

1. Open the generated URL in a browser
2. **Select Server** from dropdown
3. Click **Authorize**
4. Complete CAPTCHA if prompted
5. Bot will join your server (check member list)

**Screenshot placeholder**: `![Invite Bot](../assets/discord-invite.png)`

---

## Step 7: Enable in OpenClaw

### During Installation

If using the installer, Discord is auto-configured when `DISCORD_BOT_TOKEN` exists in Doppler.

### Post-Installation Configuration

Edit OpenClaw config:

```bash
# SSH into container
pct enter <CTID>

# Edit config
nano ~/.openclaw/openclaw.json
```

Add Discord channel:

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "dmPolicy": "pairing",
      "token": "${DISCORD_BOT_TOKEN}",
      "features": {
        "slashCommands": true,
        "threads": true
      }
    }
  }
}
```

Restart OpenClaw:

```bash
docker restart openclaw
```

---

## Step 8: Pair Your Account

1. **DM the bot**: Right-click bot in member list → **Message**
2. Send: `/start` or `!pair`
3. Bot will respond with your **Discord User ID** and a **pairing code** (e.g., `A1B2C3D4`)

### Option A: CLI Approval (Recommended)

Run the pairing approval command from your server:

```bash
# SSH into your OpenClaw container/server
ssh root@<your-server-ip>

# Approve the pairing code
docker exec openclaw-openclaw-gateway-1 node dist/index.js pairing approve discord <PAIRING_CODE>

# Example:
docker exec openclaw-openclaw-gateway-1 node dist/index.js pairing approve discord A1B2C3D4
```

You should see: `Approved discord sender <your-user-id>.`

### Option B: Control UI

1. Open browser: `http://<container-ip>:18789`
2. Navigate to **Channels** → **Discord**
3. Click **Pair User**
4. Enter pairing code
5. Assign role (Owner, Admin, User, Viewer)

---

## Step 9: Test Integration

### Slash Commands

In any channel where bot has access:

```
/openclaw status
```

Expected response:
```
✅ OpenClaw Gateway Status
Version: 2026.1
Uptime: 3h 42m
Active Tasks: 5
Nodes: 1 connected
```

### DM Commands

In bot DM:

```
!tasks

# Response:
📋 Your Tasks (3)
T1234: Implement OAuth [in-progress]
T1235: Fix memory leak [todo]
T1236: Deploy hotfix [completed]
```

---

## Configuration Options

### DM Policy

| Policy | Behavior |
|--------|----------|
| `open` | Anyone can DM bot |
| `pairing` | Only paired users |
| `server-members` | Only members of authorized servers |

**Recommended**: `pairing`

### Channel Restrictions

Limit bot to specific channels:

```json
{
  "channels": {
    "discord": {
      "allowedChannels": [
        "1234567890",  // #dev-channel ID
        "0987654321"   // #automation ID
      ]
    }
  }
}
```

### Role-Based Access

| Discord Role | OpenClaw Permissions |
|--------------|---------------------|
| **Server Owner** | Full access |
| **Administrator** | Execute commands, approve operations |
| **Moderator** | Read-only |
| **@everyone** | No access (unless paired) |

---

## Usage Examples

### Task Management

```
/openclaw task list
/openclaw task show T1234
/openclaw task complete T1234
```

### Proactive Notifications

Configure OpenClaw to send updates to specific channels:

```json
{
  "channels": {
    "discord": {
      "notifications": {
        "channel": "1234567890",  // #alerts channel ID
        "events": ["task-complete", "error", "approval-needed"]
      }
    }
  }
}
```

Example notification:
```
🚨 Approval Required

Operation: Deploy to production
Branch: main
Commit: a7f3c8e (feat: add new endpoint)

React:
✅ Approve
❌ Deny
```

### Threaded Conversations

OpenClaw can create threads for long-running tasks:

```
/openclaw task start "Refactor authentication"

# Bot creates thread: "Task T1237: Refactor authentication"
# Updates posted to thread:
📝 T1237 started
🔄 T1237: Analyzing dependencies...
✅ T1237: Complete (2h 15m)
```

---

## Security Best Practices

| Practice | Rationale |
|----------|-----------|
| **Enable pairing** | Prevent unauthorized access |
| **Restrict channels** | Limit bot visibility |
| **Don't share token** | Token grants full bot control |
| **Rotate token periodically** | Via Developer Portal |
| **Review paired users** | Revoke inactive users |
| **Use Server Members Intent carefully** | Access to all member data |

---

## Troubleshooting

### Bot offline in server

**Cause**: Token invalid or bot disabled

**Fix**:
```bash
# Verify token in Doppler
doppler secrets get DISCORD_BOT_TOKEN --project openclaw --config prd --plain

# Test token
curl -H "Authorization: Bot <YOUR_TOKEN>" \
  https://discord.com/api/v10/users/@me

# Should return bot user object
```

### Slash commands not appearing

**Cause**: Bot lacks `applications.commands` scope or not registered

**Fix**:
1. Re-invite bot with updated URL (Step 5)
2. Wait 10 minutes for Discord cache
3. Restart Discord client

### Permission errors

**Cause**: Bot role positioned below user roles

**Fix**:
1. Server Settings → Roles
2. Drag **OpenClaw** role above other roles
3. Ensure bot has required permissions in channel

### Message Content Intent error

**Cause**: Intent not enabled in Developer Portal

**Fix**:
1. Developer Portal → Bot → **Privileged Gateway Intents**
2. Enable **Message Content Intent**
3. Restart OpenClaw

---

## Advanced: Multi-Server Support

OpenClaw can manage multiple servers with isolated configs:

```json
{
  "channels": {
    "discord": {
      "servers": {
        "1234567890": {  // Server ID
          "name": "Dev Team",
          "allowedChannels": ["9876543210"],
          "defaultRole": "user"
        },
        "5555555555": {
          "name": "Client Server",
          "allowedChannels": ["6666666666"],
          "defaultRole": "viewer"
        }
      }
    }
  }
}
```

---

## Revoking Access

### Unpair User

1. Control UI → Channels → Discord → **Paired Users**
2. Select user → **Revoke Access**

### Remove from Server

Right-click bot → **Kick** or **Ban**

### Disable Bot

```json
{
  "channels": {
    "discord": {
      "enabled": false
    }
  }
}
```

### Delete Bot Entirely

1. Developer Portal → Your Application
2. **Delete Application** (irreversible)

---

## Next Steps

- [Telegram Integration](telegram-integration.md) - Add Telegram as a channel
- [Reverse Proxy Setup](reverse-proxy.md) - Secure external access
- [Doppler Setup](doppler-setup.md) - Secret management configuration

---

## References

- [Discord Developer Portal](https://discord.com/developers/applications)
- [Discord Bot Guide](https://discord.com/developers/docs/intro)
- [Gateway Intents](https://discord.com/developers/docs/topics/gateway#gateway-intents)
- [Slash Commands](https://discord.com/developers/docs/interactions/application-commands)
