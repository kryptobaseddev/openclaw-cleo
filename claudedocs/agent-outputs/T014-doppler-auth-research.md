# Doppler CLI Authentication Research for Automated Container Setup

**Task**: T014
**Date**: 2026-02-01
**Status**: complete

---

## Summary

This research documents Doppler CLI authentication methods with a focus on headless/non-interactive container environments like Proxmox LXC. The key finding is that **Service Tokens** are the recommended approach for automated deployments, with `doppler configure set token --scope` being the preferred method for persistent configuration in VMs and containers.

---

## Table of Contents

1. [Authentication Methods Overview](#1-authentication-methods-overview)
2. [Service Tokens vs Personal Tokens](#2-service-tokens-vs-personal-tokens)
3. [Non-Interactive Configuration](#3-non-interactive-configuration)
4. [Recommended Approach for LXC Container Setup](#4-recommended-approach-for-lxc-container-setup)
5. [Updated install.sh Implementation](#5-updated-installsh-implementation)
6. [Post-Install Manual Steps](#6-post-install-manual-steps)
7. [Security Best Practices](#7-security-best-practices)
8. [References](#8-references)

---

## 1. Authentication Methods Overview

Doppler provides several authentication mechanisms:

### 1.1 Interactive Login (`doppler login`)

- **Use case**: Local development on machines with browser access
- **How it works**: Opens browser for OAuth authentication, copies auth code to clipboard
- **Scope**: Creates a personal token scoped to a directory (default `/` or specified via `--scope`)
- **NOT suitable for**: Headless servers, containers, CI/CD, automated scripts

```bash
# Interactive - requires browser
doppler login
doppler login --scope=/opt/openclaw
```

### 1.2 Service Tokens

- **Use case**: Production environments, VMs, containers, CI/CD
- **How it works**: Pre-generated token with access to a specific project/config
- **Scope**: Restricted to a single project and config (e.g., `openclaw/prd`)
- **Token format**: `dp.st.prd.xxxxxxxxxxxx` or `dp.st.dev.xxxxxxxxxxxx`

```bash
# Generate via CLI (requires prior doppler login)
doppler configs tokens create token-name --plain

# Generate with expiration
doppler configs tokens create token-name --plain --max-age 1h
```

### 1.3 OIDC Authentication (Service Account Identities)

- **Use case**: CI/CD platforms with OIDC support (GitHub Actions, GitLab CI)
- **Requires**: Team or Enterprise plan
- **How it works**: Uses platform's OIDC tokens for dynamic authentication

```bash
doppler oidc login --scope=. --identity=<identity-uuid> --token=$CI_OIDC_TOKEN
```

---

## 2. Service Tokens vs Personal Tokens

| Feature | Service Token | Personal Token |
|---------|--------------|----------------|
| Access Scope | Single project/config | All user-accessible projects |
| Creation | Dashboard or CLI | `doppler login` |
| Revocation | Per token | Per user session |
| Best For | Production, automation | Local development |
| Token Format | `dp.st.{env}.xxx` | N/A (stored in config) |
| Requires Login | To create, not to use | Yes, always |

**Recommendation**: Always use **Service Tokens** for container/VM deployments because:
- They restrict access to a single project/config
- They don't require interactive login
- They can be revoked independently
- They support expiration policies

---

## 3. Non-Interactive Configuration

### 3.1 Three Ways to Use Service Tokens

#### Option 1: Persisted Service Token (RECOMMENDED for VMs/Containers)

Best for virtual machines and containers where the token should persist across restarts:

```bash
# Prevent token from appearing in shell history
export HISTIGNORE='doppler*'

# Configure token scoped to application directory
echo 'dp.st.prd.xxxx' | doppler configure set token --scope /opt/openclaw

# Now doppler run works without additional arguments
cd /opt/openclaw
doppler run -- ./start.sh
```

**Key points:**
- Token is stored in `~/.doppler/.doppler.yaml`
- Persists across reboots
- Only works from the specified scope directory or children
- User must have HOME environment variable set

#### Option 2: Environment Variable

Best for ephemeral environments or when multiple configs are needed:

```bash
export HISTIGNORE='export DOPPLER_TOKEN*'
export DOPPLER_TOKEN='dp.st.prd.xxxx'

doppler run -- your-command-here
```

**Docker usage:**
```bash
docker run -e DOPPLER_TOKEN='dp.st.prd.xxxx' your-app
```

#### Option 3: Command-line Argument

For one-off commands:

```bash
doppler run --token='dp.st.prd.xxxx' -- your-command-here
```

### 3.2 Non-Interactive Project Setup

If you have a `doppler.yaml` file in your project:

```yaml
# doppler.yaml
setup:
  - project: openclaw
    config: prd
```

Then run:
```bash
doppler setup --no-interactive
```

This configures the project without prompts, but still requires a valid token to be configured first.

---

## 4. Recommended Approach for LXC Container Setup

### 4.1 Architecture Decision

For the OpenClaw LXC installer, we recommend:

1. **Install Doppler CLI** during container creation (current behavior)
2. **DO NOT attempt to configure token** during install (too many failure modes)
3. **Provide clear post-install instructions** for token configuration
4. **Support optional pre-configuration** via `--doppler-token` flag for experienced users

### 4.2 Why Token Configuration Should Be Manual

1. **Token Generation Requires Dashboard Access**: Users must first create a Service Token in the Doppler dashboard
2. **Project/Config Scoping**: The token must match the correct project and config
3. **Security**: Tokens passed as command-line arguments can leak in logs
4. **Validation**: We cannot validate the token during install without network access to Doppler API
5. **Recovery**: If configuration fails, manual correction is simpler

### 4.3 Recommended Flow

```
1. User creates Doppler project (manual, dashboard)
2. User generates Service Token (manual, dashboard)
3. User runs LXC installer (automated)
4. User configures Doppler token (semi-automated, one command)
5. User starts OpenClaw (automated with doppler run)
```

---

## 5. Updated install.sh Implementation

### 5.1 Current Issues in install.sh

```bash
# Current code (PROBLEMATIC)
if [[ -n "${DOPPLER_TOKEN}" ]]; then
    msg_info "Configuring Doppler"
    pct exec "${CT_ID}" -- bash -c "
        echo '${DOPPLER_TOKEN}' > /root/.doppler-token    # Unnecessary file
        chmod 600 /root/.doppler-token
        doppler configure set token '${DOPPLER_TOKEN}' --scope /root  # Wrong scope
    "
    msg_ok "Doppler configured"
fi
```

**Problems:**
1. Creates unnecessary `.doppler-token` file
2. Scopes to `/root` instead of `/opt/openclaw` where the app lives
3. Token in single quotes inside double-quoted heredoc may cause shell expansion issues
4. No validation of token format

### 5.2 Recommended Updated Code

```bash
setup_doppler() {
    msg_info "Installing Doppler CLI"
    pct exec "${CT_ID}" -- bash -c '
        apt-get install -y apt-transport-https
        curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
            "https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key" | \
            gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] \
            https://packages.doppler.com/public/cli/deb/debian any-version main" | \
            tee /etc/apt/sources.list.d/doppler-cli.list
        apt-get update
        apt-get install -y doppler
    ' >/dev/null 2>&1
    msg_ok "Doppler CLI installed"

    # Only configure if token provided
    if [[ -n "${DOPPLER_TOKEN}" ]]; then
        # Validate token format (dp.st.xxx.xxxxxxxx)
        if [[ ! "${DOPPLER_TOKEN}" =~ ^dp\.st\.[a-z]+\.[A-Za-z0-9]+$ ]]; then
            msg_error "Invalid Doppler token format. Expected: dp.st.{env}.{token}"
            msg_info "Skipping Doppler configuration - configure manually after install"
            return
        fi

        msg_info "Configuring Doppler token"
        # Use printf to avoid shell expansion issues and history leakage
        pct exec "${CT_ID}" -- bash -c "
            export HISTIGNORE='doppler*:echo*'
            printf '%s' '${DOPPLER_TOKEN}' | doppler configure set token --scope /opt/openclaw
        "

        if pct exec "${CT_ID}" -- bash -c "doppler configure get token --scope /opt/openclaw" >/dev/null 2>&1; then
            msg_ok "Doppler configured for /opt/openclaw"
        else
            msg_error "Doppler configuration may have failed - verify manually"
        fi
    fi
}
```

### 5.3 Alternative: Create a Doppler Setup Script

Create a helper script inside the container:

```bash
setup_doppler_helper() {
    msg_info "Creating Doppler setup helper"
    pct exec "${CT_ID}" -- bash -c 'cat > /usr/local/bin/setup-doppler << "SCRIPT"
#!/bin/bash
# OpenClaw Doppler Configuration Helper
# Usage: setup-doppler dp.st.prd.xxxxxxxxxxxx

set -e

if [[ -z "$1" ]]; then
    echo "Usage: setup-doppler <doppler-service-token>"
    echo ""
    echo "To get a token:"
    echo "  1. Go to https://dashboard.doppler.com"
    echo "  2. Select your project and config (e.g., openclaw/prd)"
    echo "  3. Click Access > Generate Service Token"
    echo "  4. Copy the token (starts with dp.st.)"
    exit 1
fi

TOKEN="$1"

# Validate format
if [[ ! "$TOKEN" =~ ^dp\.st\.[a-z]+\.[A-Za-z0-9]+$ ]]; then
    echo "Error: Invalid token format"
    echo "Expected: dp.st.{env}.{token}"
    echo "Example:  dp.st.prd.xxxxxxxxxxxx"
    exit 1
fi

# Configure token
export HISTIGNORE="doppler*:echo*:printf*"
printf "%s" "$TOKEN" | doppler configure set token --scope /opt/openclaw

# Verify
echo ""
echo "Verifying configuration..."
if doppler secrets --only-names --scope /opt/openclaw >/dev/null 2>&1; then
    echo "Success! Doppler is configured."
    echo ""
    echo "Available secrets:"
    doppler secrets --only-names --scope /opt/openclaw
    echo ""
    echo "To start OpenClaw:"
    echo "  cd /opt/openclaw && doppler run -- docker compose up -d"
else
    echo "Warning: Could not verify token. Please check:"
    echo "  - Token is valid and not expired"
    echo "  - Token has access to the correct project/config"
    echo "  - Network connectivity to Doppler API"
fi
SCRIPT
chmod +x /usr/local/bin/setup-doppler
'
    msg_ok "Doppler helper created: setup-doppler"
}
```

---

## 6. Post-Install Manual Steps

### 6.1 Complete User Instructions

```
DOPPLER SETUP INSTRUCTIONS
==========================

Step 1: Create Doppler Account and Project (if not done)
---------------------------------------------------------
1. Go to https://dashboard.doppler.com
2. Create a new project called "openclaw"
3. You'll have environments: dev, stg, prd

Step 2: Add Required Secrets
----------------------------
In Doppler dashboard, add these secrets to your config (e.g., prd):

  ANTHROPIC_API_KEY       (required) Your Anthropic API key
  OPENCLAW_GATEWAY_TOKEN  (required) Generate: openssl rand -hex 32
  TELEGRAM_BOT_TOKEN      (optional) For Telegram integration
  DISCORD_BOT_TOKEN       (optional) For Discord integration

Step 3: Generate Service Token
------------------------------
1. In Doppler dashboard, go to your project
2. Select the config (e.g., "prd")
3. Click "Access" tab
4. Click "Generate" under Service Tokens
5. Name it "openclaw-lxc"
6. Copy the token (starts with dp.st.prd.)

Step 4: Configure Doppler in Container
--------------------------------------
Method A - Using helper script:
  pct enter <container-id>
  setup-doppler dp.st.prd.xxxxxxxxxxxx

Method B - Manual configuration:
  pct enter <container-id>
  export HISTIGNORE='doppler*'
  echo 'dp.st.prd.xxxxxxxxxxxx' | doppler configure set token --scope /opt/openclaw

Step 5: Verify Configuration
----------------------------
  cd /opt/openclaw
  doppler secrets --only-names

Step 6: Start OpenClaw
----------------------
  cd /opt/openclaw
  doppler run -- docker compose up -d
```

### 6.2 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Error: token not found" | Run `doppler configure set token --scope /opt/openclaw` |
| "Error: 401 Unauthorized" | Token may be expired or revoked; generate new one |
| "Error: project not found" | Token doesn't have access to specified project |
| "Unable to connect to Doppler" | Check network/firewall; try `ping api.doppler.com` |

---

## 7. Security Best Practices

### 7.1 Token Handling

```bash
# GOOD: Prevent history logging
export HISTIGNORE='doppler*:*DOPPLER*'
echo "$TOKEN" | doppler configure set token --scope /opt/openclaw

# BAD: Token visible in history
doppler configure set token dp.st.prd.xxx --scope /opt/openclaw

# GOOD: Use pipe to avoid command-line argument exposure
printf '%s' "$TOKEN" | doppler configure set token --scope /opt/openclaw

# BAD: Token as argument (visible in ps, /proc, logs)
doppler run --token=dp.st.prd.xxx -- command
```

### 7.2 Token Scope

- Use the most restrictive scope possible
- Scope to `/opt/openclaw` rather than `/root` or `/`
- Different applications should use different tokens

### 7.3 Token Rotation

```bash
# Create new token
NEW_TOKEN=$(doppler configs tokens create gateway-v2 --plain --project openclaw --config prd)

# Update configuration
echo "$NEW_TOKEN" | doppler configure set token --scope /opt/openclaw

# Verify new token works
doppler secrets --only-names --scope /opt/openclaw

# Revoke old token (in dashboard or CLI)
doppler configs tokens revoke gateway-v1 --yes --project openclaw --config prd
```

### 7.4 Ephemeral Tokens for CI/CD

```bash
# Generate short-lived token
TOKEN=$(doppler configs tokens create ci-deploy --plain --max-age 5m)

# Use immediately
DOPPLER_TOKEN=$TOKEN ./deploy.sh

# Token auto-expires after 5 minutes
```

---

## 8. References

### Official Documentation

- [Doppler CLI Guide](https://docs.doppler.com/docs/cli)
- [Doppler Service Tokens](https://docs.doppler.com/docs/service-tokens)
- [Doppler Install CLI](https://docs.doppler.com/docs/install-cli)

### Related Project Files

- `/mnt/projects/openclaw/scripts/install.sh` - LXC installer script
- `/mnt/projects/openclaw/claudedocs/DOPPLER-INTEGRATION.md` - Integration guide

### Key Commands Reference

```bash
# Install Doppler CLI (Debian/Ubuntu)
curl -sLf https://cli.doppler.com/install.sh | sh

# Interactive login (local dev only)
doppler login

# Configure service token (production/containers)
echo 'dp.st.prd.xxx' | doppler configure set token --scope /path/to/app

# Run command with secrets injected
doppler run -- your-command

# Verify token configuration
doppler configure get token --scope /path/to/app

# List available secrets
doppler secrets --only-names

# Generate new service token
doppler configs tokens create name --plain --project PROJECT --config CONFIG

# Generate ephemeral token
doppler configs tokens create name --plain --max-age 1h
```

---

## Conclusion

For the OpenClaw LXC installer:

1. **DO**: Install Doppler CLI during container setup
2. **DO**: Create a helper script (`setup-doppler`) for easy configuration
3. **DO**: Provide clear post-install documentation
4. **DO**: Support optional `--doppler-token` flag for automation
5. **DON'T**: Require Doppler token during initial install
6. **DON'T**: Use `doppler login` in headless environments
7. **DON'T**: Store tokens in plain text files (use `doppler configure set token`)

The recommended approach separates the "install dependencies" phase (automated) from the "configure secrets" phase (semi-manual with helper script), providing a robust and user-friendly experience.
