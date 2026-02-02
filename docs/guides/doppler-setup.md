# Doppler Secrets Management Setup

Complete guide to configuring Doppler for OpenClaw secret management.

---

## Overview

Doppler provides centralized, encrypted secrets management for OpenClaw. This eliminates the need for `.env` files and provides audit logging, role-based access control, and automatic synchronization.

**Sign up**: [doppler.com/join?invite=CA07141D](https://doppler.com/join?invite=CA07141D)

---

## Prerequisites

- Doppler account (free tier works)
- Email verified
- Admin access to create projects

---

## Step 1: Create Account

1. Visit [doppler.com/join?invite=CA07141D](https://doppler.com/join?invite=CA07141D)
2. Sign up with email or GitHub
3. Verify email address
4. Complete onboarding

---

## Step 2: Create Project

1. Click **+ Create Project** in dashboard
2. **Project Name**: `openclaw`
3. **Description**: "OpenClaw AI Assistant Secrets"
4. Click **Create Project**

---

## Step 3: Create Config

Doppler uses **configs** as environment containers (dev, staging, prd).

1. Inside `openclaw` project, click **+ Add Config**
2. **Config Name**: `prd` (production)
3. **Environment**: Production
4. Click **Create Config**

---

## Step 4: Add Required Secrets

Navigate to `openclaw` → `prd` config and add these secrets:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `ANTHROPIC_API_KEY` | Claude API key | [console.anthropic.com](https://console.anthropic.com) → API Keys |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway authentication token | Generate: `openssl rand -hex 32` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token (optional) | See [Telegram Integration Guide](telegram-integration.md) |
| `DISCORD_BOT_TOKEN` | Discord bot token (optional) | See [Discord Integration Guide](discord-integration.md) |

### Example Values

```bash
# Generate a secure gateway token
openssl rand -hex 32
# Example output: a7f3c8e1b2d4f6a8c0e2d4f6a8b0c2d4e6f8a0c2e4f6a8b0c2d4e6f8a0c2d4e6

# Add to Doppler:
OPENCLAW_GATEWAY_TOKEN=a7f3c8e1b2d4f6a8c0e2d4f6a8b0c2d4e6f8a0c2e4f6a8b0c2d4e6f8a0c2d4e6
```

### Adding Secrets in UI

1. Click **+ Add Secret**
2. **Name**: `ANTHROPIC_API_KEY`
3. **Value**: Paste your API key
4. Click **Save**
5. Repeat for all required secrets

---

## Step 5: Create Service Token

Service tokens allow the OpenClaw container to fetch secrets automatically.

### Option A: Web UI

1. Navigate to `openclaw` → `prd` → **Access** tab
2. Click **Generate Token**
3. **Token Name**: `openclaw-container`
4. **Environment**: `prd`
5. **Expiration**: None (or set expiry if preferred)
6. Click **Generate**
7. **Copy the token immediately** (shown only once)

Format: `dp.st.prd.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

### Option B: CLI (Advanced)

```bash
# Install Doppler CLI
curl -Ls https://cli.doppler.com/install.sh | sh

# Login
doppler login

# Create service token
doppler configs tokens create openclaw-container --project openclaw --config prd --plain

# Copy output token
```

---

## Step 6: Use Service Token in Installer

When running the OpenClaw installer, provide the service token:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)" -- --doppler-token dp.st.prd.XXXXX
```

The installer will:
1. Install Doppler CLI in the container
2. Configure it with your service token
3. Automatically pull secrets at runtime
4. No `.env` files created

---

## Step 7: Verify Configuration

After installation completes:

```bash
# SSH into OpenClaw container
pct enter <CTID>

# Test Doppler connection
doppler secrets --project openclaw --config prd

# Should output your secrets (redacted)
```

---

## Alternative: CLI Login (Interactive)

For development/testing, use interactive login instead of service tokens:

```bash
# Inside container
doppler login

# Select project and config
doppler setup --project openclaw --config prd

# Verify
doppler secrets
```

**Warning**: CLI login uses personal credentials. Service tokens are recommended for production.

---

## Secret Rotation

### Rotate Gateway Token

```bash
# Generate new token
openssl rand -hex 32

# Update in Doppler UI or CLI
doppler secrets set OPENCLAW_GATEWAY_TOKEN=NEW_TOKEN --project openclaw --config prd

# Restart OpenClaw
docker restart openclaw
```

### Rotate API Keys

1. Generate new key in provider console (Anthropic, Telegram, Discord)
2. Update secret in Doppler
3. Restart OpenClaw (secrets auto-refresh on restart)

---

## Security Best Practices

| Practice | Rationale |
|----------|-----------|
| **Never commit tokens** | Service tokens grant full access to secrets |
| **Use service tokens in containers** | Personal tokens expire/rotate |
| **Set token expiration** | Limits blast radius if compromised |
| **Enable audit logs** | Track who accessed what secrets |
| **Use least-privilege tokens** | Limit to specific project/config |

---

## Troubleshooting

### Error: "Invalid token"

**Cause**: Token expired or malformed

**Fix**:
```bash
# Regenerate service token
doppler configs tokens create openclaw-container-new --project openclaw --config prd --plain

# Update installer command with new token
```

### Error: "Project not found"

**Cause**: Token lacks access to `openclaw` project

**Fix**: Verify token was created with `--project openclaw` flag

### Secrets not updating

**Cause**: Container using cached secrets

**Fix**:
```bash
# Force refresh
docker restart openclaw

# Verify latest secrets
doppler secrets --project openclaw --config prd
```

---

## Advanced: Multiple Environments

For dev/staging/prod separation:

```bash
# Create additional configs
doppler configs create dev --project openclaw
doppler configs create staging --project openclaw

# Use different tokens per environment
doppler configs tokens create dev-token --project openclaw --config dev
doppler configs tokens create staging-token --project openclaw --config staging

# Run installer with env-specific token
bash install.sh -- --doppler-token dp.st.dev.XXXXX
```

---

## Next Steps

- [Telegram Integration](telegram-integration.md) - Configure Telegram bot
- [Discord Integration](discord-integration.md) - Configure Discord bot
- [Reverse Proxy Setup](reverse-proxy.md) - Secure external access

---

## References

- [Doppler Documentation](https://docs.doppler.com/)
- [Service Tokens Guide](https://docs.doppler.com/docs/service-tokens)
- [CLI Reference](https://docs.doppler.com/docs/cli)
