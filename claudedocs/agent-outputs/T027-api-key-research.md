# OpenClaw API Key Configuration Research

**Task**: T027-api-key
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

OpenClaw requires API keys to be configured in `auth-profiles.json` within each agent's directory. The Anthropic API key is already available in Doppler and can be configured using either the CLI onboard wizard or by manually creating the auth-profiles.json file.

---

## Key Findings

### 1. API Key Location
- **Error**: `No API key found for provider "anthropic"`
- **Expected Path**: `/home/node/.openclaw/agents/main/agent/auth-profiles.json`
- **Current State**: File does not exist (directory exists but only contains `sessions/` subdirectory)

### 2. Anthropic API Key Availability
```bash
# API key is stored in Doppler:
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
```

### 3. Auth Resolution Flow
OpenClaw resolves authentication in this order:
1. **auth-profiles.json** - Profile-based auth (profiles by ID)
2. **Environment variables** - `ANTHROPIC_OAUTH_TOKEN` or `ANTHROPIC_API_KEY`
3. **models.json** - Custom provider API keys
4. **Fallback error** - Throws "No API key found" if all fail

Source: `/app/dist/agents/model-auth.js`

### 4. auth-profiles.json Structure
```json
{
  "version": 1,
  "profiles": {
    "anthropic:manual": {
      "type": "api_key",
      "provider": "anthropic",
      "apiKey": "sk-ant-api03-..."
    }
  },
  "order": {
    "anthropic": ["anthropic:manual"]
  },
  "lastGood": {},
  "usageStats": {}
}
```

**Valid credential types**:
- `api_key` - API key authentication
- `oauth` - OAuth token authentication
- `token` - Session token authentication

### 5. Configuration Methods

#### Method 1: Non-Interactive CLI (Recommended)
```bash
docker exec openclaw-openclaw-gateway-1 node dist/index.js onboard \
  --non-interactive \
  --accept-risk \
  --auth-choice setup-token \
  --anthropic-api-key "sk-ant-api03-..."
```

#### Method 2: Interactive Wizard
```bash
docker exec -it openclaw-openclaw-gateway-1 node dist/index.js onboard
# Follow prompts to configure authentication
```

#### Method 3: Manual File Creation
```bash
# Create auth-profiles.json directly
mkdir -p ~/.openclaw/agents/main/agent
cat > ~/.openclaw/agents/main/agent/auth-profiles.json <<'EOF'
{
  "version": 1,
  "profiles": {
    "anthropic:manual": {
      "type": "api_key",
      "provider": "anthropic",
      "apiKey": "${ANTHROPIC_API_KEY}"
    }
  }
}
EOF
chmod 600 ~/.openclaw/agents/main/agent/auth-profiles.json
```

#### Method 4: Environment Variable (Temporary)
```bash
# Add to docker-compose.yml under openclaw-gateway service:
environment:
  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
```

### 6. Docker Compose Configuration
Current docker-compose.yml does NOT pass `ANTHROPIC_API_KEY` to containers. Environment variables observed:
- `CLAUDE_AI_SESSION_KEY`
- `CLAUDE_WEB_SESSION_KEY`
- `CLAUDE_WEB_COOKIE`

These are for Claude web session auth, not API key auth.

### 7. CLI Commands Available
```bash
# Agent management
openclaw agents list           # List configured agents
openclaw agents add <id>       # Add new isolated agent

# Configuration
openclaw configure             # Interactive config wizard
openclaw onboard               # Full setup wizard
openclaw models                # Model configuration

# Auth-related files found in container
/app/dist/agents/auth-profiles.js
/app/dist/agents/auth-profiles/profiles.js
/app/dist/agents/auth-profiles/store.js
/app/dist/agents/auth-profiles/oauth.js
```

---

## Recommended Solution

**Use Method 3 (Manual File Creation) with Doppler integration:**

```bash
# On the OpenClaw host (10.0.10.20)
cd /opt/openclaw

# Get API key from Doppler and create auth-profiles.json
export ANTHROPIC_API_KEY=$(doppler secrets get ANTHROPIC_API_KEY --plain)

# Create auth profile as the correct user (uid 1000)
docker exec openclaw-openclaw-gateway-1 bash -c "
mkdir -p /home/node/.openclaw/agents/main/agent
cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json <<EOF
{
  \"version\": 1,
  \"profiles\": {
    \"anthropic:manual\": {
      \"type\": \"api_key\",
      \"provider\": \"anthropic\",
      \"apiKey\": \"${ANTHROPIC_API_KEY}\"
    }
  }
}
EOF
chmod 600 /home/node/.openclaw/agents/main/agent/auth-profiles.json
chown node:node /home/node/.openclaw/agents/main/agent/auth-profiles.json
"

# Verify
docker exec openclaw-openclaw-gateway-1 cat /home/node/.openclaw/agents/main/agent/auth-profiles.json | jq .
```

**Why this approach:**
1. Uses existing Doppler secret management
2. No interactive prompts required
3. Creates file with correct permissions and ownership
4. Follows OpenClaw's expected structure
5. Immediate effect (no restart needed for auth profiles)

---

## Alternative: Environment Variable Method

**Add to docker-compose.yml:**
```yaml
services:
  openclaw-gateway:
    environment:
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
```

**Add to .env or Doppler:**
```bash
# Already exists in Doppler, just ensure it's in the .env file
doppler secrets download --no-file --format env | grep ANTHROPIC_API_KEY >> /opt/openclaw/.env
```

**Then restart:**
```bash
docker compose restart openclaw-gateway
```

---

## Implementation Priority

1. **Immediate**: Manual file creation (Method 3) - No restart required
2. **Long-term**: Add to docker-compose.yml environment - Survives container recreation
3. **Optional**: Run `openclaw onboard` if full reconfiguration needed

---

## References

- Epic: T001
- Error Source: `/app/dist/agents/model-auth.js`
- Auth Store: `/home/node/.openclaw/agents/main/agent/auth-profiles.json`
- Profile Manager: `/app/dist/agents/auth-profiles/profiles.js`
- CLI Documentation: https://docs.openclaw.ai/cli
- Doppler Secret: `ANTHROPIC_API_KEY` (already configured)
