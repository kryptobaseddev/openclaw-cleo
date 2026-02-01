# Doppler CLI Integration Guide

**Purpose**: Secrets management for OpenClaw self-hosted deployment
**Target Environment**: Debian 12 LXC containers on Proxmox
**Integration Points**: Docker Compose, systemd services, NGINX Proxy Manager

---

## Table of Contents

1. [Installation](#1-installation)
2. [Authentication](#2-authentication)
3. [Docker Integration](#3-docker-integration)
4. [Systemd Integration](#4-systemd-integration)
5. [NGINX Proxy Manager](#5-nginx-proxy-manager)
6. [Security Best Practices](#6-security-best-practices)
7. [OpenClaw-Specific Configuration](#7-openclaw-specific-configuration)

---

## 1. Installation

### Debian 12 Installation (Recommended)

```bash
# Install prerequisites
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Add Doppler's GPG key
curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
  'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
  sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg

# Add Doppler's apt repository
echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | \
  sudo tee /etc/apt/sources.list.d/doppler-cli.list

# Install Doppler CLI
sudo apt-get update && sudo apt-get install -y doppler

# Verify installation
doppler --version
```

### Alternative: Shell Script Installation

For CI/CD environments or quick setup:

```bash
(curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh || \
  wget -t 3 -qO- https://cli.doppler.com/install.sh) | sh
```

### Update Doppler CLI

```bash
doppler update
# Or via apt
sudo apt-get update && sudo apt-get upgrade doppler
```

---

## 2. Authentication

### Service Token Authentication (Non-Interactive)

Service tokens provide read-only access to a specific config within a project. They are the recommended method for production environments.

#### Creating Service Tokens

**Via Dashboard:**
1. Navigate to Project -> Config -> Access tab
2. Click "Generate"
3. Provide a name (e.g., `openclaw-gateway-prod`)
4. Optionally set write access or expiration
5. Copy the token (shown only once)

**Via CLI:**
```bash
# Interactive setup first (on dev machine)
doppler login
doppler setup

# Create service token
doppler configs tokens create openclaw-gateway --plain

# Create with expiration (ephemeral)
doppler configs tokens create temp-token --plain --max-age 1h

# Specify project and config inline
doppler configs tokens create gateway-prod \
  --project openclaw \
  --config prd \
  --plain
```

#### Token Format

Service tokens follow the pattern: `dp.st.<env>.<random>`
Example: `dp.st.prd.xxxxxxxxxxxxxxxxxxxx`

#### Configuring Service Token for Non-Interactive Use

**Method 1: Scoped Directory Configuration (Recommended for VMs)**

```bash
# Prevent token from appearing in bash history
export HISTIGNORE='doppler*'

# Scope to application directory
echo 'dp.st.prd.xxxx' | doppler configure set token --scope /opt/openclaw

# Verify configuration
doppler configure get token --scope /opt/openclaw

# Now doppler run works without additional args in that directory
cd /opt/openclaw
doppler run -- ./start.sh
```

**Method 2: Environment Variable**

```bash
# Prevent export from appearing in history
export HISTIGNORE='export DOPPLER_TOKEN*'
export DOPPLER_TOKEN='dp.st.prd.xxxxxxxxxxxx'

# Use with doppler run
doppler run -- your-command-here
```

**Method 3: Command Argument (One-off)**

```bash
doppler run --token='dp.st.prd.xxxx' -- your-command-here
```

---

## 3. Docker Integration

### Method 1: Environment Variable Passthrough

The simplest approach for Docker Compose. Define which environment variables to pass through.

**docker-compose.yml:**
```yaml
version: "3.8"

services:
  openclaw-gateway:
    build: .
    container_name: openclaw-gateway
    restart: unless-stopped
    environment:
      - ANTHROPIC_API_KEY
      - GATEWAY_TOKEN
      - TELEGRAM_BOT_TOKEN
      - DISCORD_BOT_TOKEN
      - DATABASE_URL
    ports:
      - "18789:18789"
      - "18793:18793"
    volumes:
      - ./data:/app/data
```

**Run with Doppler:**
```bash
doppler run -- docker compose up -d
```

**Important:** You must update the `environment` list when adding new secrets to Doppler.

### Method 2: Embed Doppler CLI in Dockerfile

For containers that need to fetch secrets at runtime.

**Dockerfile:**
```dockerfile
FROM node:22-bookworm-slim

# Install Doppler CLI
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates curl gnupg \
    && curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
       'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
       gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | \
       tee /etc/apt/sources.list.d/doppler-cli.list \
    && apt-get update && apt-get install -y doppler \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .
RUN npm install

# Doppler injects secrets at runtime
ENTRYPOINT ["doppler", "run", "--"]
CMD ["npm", "start"]
```

**docker-compose.yml:**
```yaml
version: "3.8"

services:
  openclaw-gateway:
    build: .
    container_name: openclaw-gateway
    restart: unless-stopped
    environment:
      - DOPPLER_TOKEN
    ports:
      - "18789:18789"
```

**Run:**
```bash
DOPPLER_TOKEN="dp.st.prd.xxxx" docker compose up -d
```

### Method 3: Docker Run with Process Substitution

For one-off container runs without modifying the image.

```bash
docker run \
  --env-file <(doppler secrets download --no-file --format docker) \
  your-image:latest
```

### Method 4: Multiple Services with Separate Configs

For microservices requiring different Doppler configs.

**docker-compose.yml:**
```yaml
version: "3.8"

services:
  gateway:
    build: ./gateway
    environment:
      - DOPPLER_TOKEN=${DOPPLER_TOKEN_GATEWAY}

  exec-node:
    build: ./exec-node
    environment:
      - DOPPLER_TOKEN=${DOPPLER_TOKEN_EXEC}
```

**Run:**
```bash
DOPPLER_TOKEN_GATEWAY="$(doppler configs tokens create --project openclaw --config gateway-prd gateway-token --plain --max-age 1h)" \
DOPPLER_TOKEN_EXEC="$(doppler configs tokens create --project openclaw --config exec-prd exec-token --plain --max-age 1h)" \
docker compose up -d
```

---

## 4. Systemd Integration

### Basic Service File

**`/etc/systemd/system/openclaw-gateway.service`:**
```ini
[Unit]
Description=OpenClaw Gateway Service
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=openclaw
Group=openclaw

# CRITICAL: Set HOME for Doppler token discovery
Environment="HOME=/opt/openclaw"
WorkingDirectory=/opt/openclaw

# Option A: Use scoped token (configured via doppler configure set token)
ExecStart=/usr/bin/doppler run -- /opt/openclaw/bin/gateway

# Option B: Use environment variable for token
# Environment="DOPPLER_TOKEN=dp.st.prd.xxxx"
# ExecStart=/usr/bin/doppler run -- /opt/openclaw/bin/gateway

Restart=on-failure
RestartSec=10

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/opt/openclaw/data

[Install]
WantedBy=multi-user.target
```

### Key Considerations for systemd

1. **Set HOME Environment Variable**: Doppler requires `HOME` to locate cached tokens.

2. **Avoid Type=notify**: If your application uses systemd notify, Doppler will block the notification. Use `Type=simple` instead.

3. **Set WorkingDirectory**: The working directory must match where `doppler configure set token --scope` was run.

4. **Use Absolute Paths**: Always use full paths for both `doppler` and your application.

### Docker Compose with systemd

**`/etc/systemd/system/openclaw-compose.service`:**
```ini
[Unit]
Description=OpenClaw Docker Compose Stack
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
Environment="HOME=/root"
WorkingDirectory=/opt/openclaw

# Configure token once: doppler configure set token --scope /opt/openclaw
ExecStart=/usr/bin/doppler run -- /usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down

Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
```

### Reload and Enable

```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw-gateway
sudo systemctl start openclaw-gateway
sudo systemctl status openclaw-gateway
```

### Troubleshooting systemd Issues

```bash
# View detailed logs
sudo journalctl -u openclaw-gateway -f

# Check service status
sudo systemctl status --full --lines=50 openclaw-gateway

# Verify Doppler token is accessible
sudo -u openclaw -H bash -c 'cd /opt/openclaw && doppler secrets'
```

---

## 5. NGINX Proxy Manager

### Docker Compose Setup

**`/opt/nginx-proxy-manager/docker-compose.yml`:**
```yaml
version: "3.8"

services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "81:81"  # Admin interface
    environment:
      TZ: "America/Denver"
      # Database credentials from Doppler
      - DB_MYSQL_HOST
      - DB_MYSQL_PORT
      - DB_MYSQL_USER
      - DB_MYSQL_PASSWORD
      - DB_MYSQL_NAME
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    networks:
      - proxy-network

  mariadb:
    image: jc21/mariadb-aria:latest
    container_name: npm-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD
      - MYSQL_DATABASE
      - MYSQL_USER
      - MYSQL_PASSWORD
    volumes:
      - ./mysql:/var/lib/mysql
    networks:
      - proxy-network

networks:
  proxy-network:
    driver: bridge
```

### Doppler Project Configuration

Create these secrets in Doppler (project: `nginx-proxy`, config: `prd`):

| Secret Name | Description |
|-------------|-------------|
| DB_MYSQL_HOST | `mariadb` (container name) |
| DB_MYSQL_PORT | `3306` |
| DB_MYSQL_USER | `npm` |
| DB_MYSQL_PASSWORD | Generated strong password |
| DB_MYSQL_NAME | `npm` |
| MYSQL_ROOT_PASSWORD | Generated root password |
| MYSQL_DATABASE | `npm` |
| MYSQL_USER | `npm` |
| MYSQL_PASSWORD | Same as DB_MYSQL_PASSWORD |

### Start with Doppler

```bash
cd /opt/nginx-proxy-manager
doppler run --project nginx-proxy --config prd -- docker compose up -d
```

### Configuring Proxy Hosts for OpenClaw

1. **Access Admin Interface**: Navigate to `http://<server-ip>:81`
2. **Default Credentials**: admin@example.com / changeme
3. **Add Proxy Host**:
   - Domain: `openclaw.yourdomain.com`
   - Scheme: `http`
   - Forward Hostname/IP: `openclaw-gateway` (container name) or `10.0.10.50`
   - Forward Port: `18793` (Control UI) or `18789` (Gateway API)
   - Enable "Block Common Exploits"
4. **SSL Tab**:
   - Request new SSL certificate
   - Enable "Force SSL"
   - Enable "HTTP/2 Support"
   - Enable "HSTS Enabled"

### Network Configuration for Container Communication

If OpenClaw runs in a separate Docker network, connect NGINX Proxy Manager:

```yaml
# In openclaw docker-compose.yml
networks:
  default:
    name: openclaw-network
  proxy-network:
    external: true

services:
  gateway:
    networks:
      - default
      - proxy-network
```

---

## 6. Security Best Practices

### Token Management

| Practice | Implementation |
|----------|----------------|
| Use Service Tokens in Production | Never use CLI/Personal tokens in live environments |
| Scope Tokens to Specific Configs | Create separate tokens for gateway, exec-node, etc. |
| Set Token Expiration | Use `--max-age` for CI/CD and temporary access |
| Rotate Tokens Periodically | Monthly rotation recommended |
| Prevent History Leakage | `export HISTIGNORE='doppler*'` |

### Token Rotation Strategy

1. Generate new service token
2. Update deployment configuration
3. Test with new token in staging
4. Deploy to production
5. Revoke old token after confirming new token works

```bash
# Create new token
NEW_TOKEN=$(doppler configs tokens create gateway-prd-v2 --plain)

# Update systemd service
sudo sed -i "s/dp.st.prd.OLD/dp.st.prd.NEW/" /etc/systemd/system/openclaw.service
sudo systemctl daemon-reload
sudo systemctl restart openclaw

# After verification, revoke old token
doppler configs tokens revoke gateway-prd-v1 --yes
```

### Ephemeral Tokens for CI/CD

```bash
# Token expires after 5 minutes
TOKEN=$(doppler configs tokens create ci-deploy --plain --max-age 5m)

# Use in deployment script
DOPPLER_TOKEN=$TOKEN ./deploy.sh
```

### Secrets File Security

When secrets must be written to files (e.g., TLS certificates):

```bash
# Use ephemeral mount (recommended)
doppler run --mount /etc/ssl/private/openclaw.key --mount-template tls-key.tmpl -- nginx

# Or download with restricted permissions
doppler secrets get TLS_KEY --plain > /tmp/key.pem
chmod 600 /tmp/key.pem
# Use immediately, then delete
rm /tmp/key.pem
```

### Environment Variable Safety

Avoid these dangerous environment variable names that could enable code execution:

- `LD_PRELOAD`
- `NODE_OPTIONS`
- `PYTHONWARNINGS`
- `DYLD_INSERT_LIBRARIES`

Use file mounts instead of environment variables for maximum security.

---

## 7. OpenClaw-Specific Configuration

### Project Structure in Doppler

**Project: `openclaw`**

| Config | Purpose | Tokens |
|--------|---------|--------|
| `dev` | Local development | Personal token |
| `stg` | Staging environment | `gateway-stg`, `exec-stg` |
| `prd` | Production | `gateway-prd`, `exec-prd` |

### Recommended Secrets

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `ANTHROPIC_API_KEY` | Claude API access | `sk-ant-...` |
| `GATEWAY_TOKEN` | Inter-node authentication | `openssl rand -hex 32` output |
| `TELEGRAM_BOT_TOKEN` | Telegram channel integration | From @BotFather |
| `DISCORD_BOT_TOKEN` | Discord channel integration | From Discord Developer Portal |
| `GH_TOKEN` | GitHub CLI authentication | `gh auth token` output |
| `DATABASE_URL` | If using external database | `postgres://...` |

### Gateway LXC Setup

```bash
# Install Doppler
# (Use installation commands from Section 1)

# Create application directory
sudo mkdir -p /opt/openclaw
sudo chown openclaw:openclaw /opt/openclaw
cd /opt/openclaw

# Configure service token (run as openclaw user)
sudo -u openclaw -H bash
export HISTIGNORE='doppler*'
echo 'dp.st.prd.xxxx' | doppler configure set token --scope /opt/openclaw

# Verify
doppler secrets --project openclaw --config prd
```

### Exec Node LXC Setup

```bash
# Same installation process
# Use different service token scoped to exec config
echo 'dp.st.prd.yyyy' | doppler configure set token --scope /opt/openclaw-exec
```

### Integration with openclaw.json

Instead of hardcoding API keys:

**Before (insecure):**
```json
{
  "model": {
    "apiKey": "sk-ant-xxxxx"
  }
}
```

**After (with Doppler):**
```json
{
  "model": {
    "apiKey": "${ANTHROPIC_API_KEY}"
  }
}
```

Then run: `doppler run -- openclaw gateway start`

### Complete Deployment Command

```bash
# Gateway LXC
cd /opt/openclaw
doppler run -- openclaw gateway start --daemon

# Or with Docker Compose
doppler run -- docker compose up -d
```

---

## Quick Reference

### Essential Commands

```bash
# Check configured token
doppler configure get token

# List all secrets (names only)
doppler secrets --only-names

# Get specific secret
doppler secrets get ANTHROPIC_API_KEY --plain

# Download all secrets as .env
doppler secrets download --no-file --format env

# Run command with secrets
doppler run -- your-command

# Create service token
doppler configs tokens create name --plain

# List service tokens
doppler configs tokens

# Revoke service token
doppler configs tokens revoke name --yes
```

### Troubleshooting

```bash
# Debug mode
doppler run --debug -- your-command

# Check CLI configuration
doppler configure debug

# Verify project/config selection
doppler setup

# Test token validity
doppler secrets --project openclaw --config prd
```

---

## Sources

- [Doppler CLI Installation Guide](https://docs.doppler.com/docs/install-cli)
- [Doppler Service Tokens](https://docs.doppler.com/docs/service-tokens)
- [Doppler Docker Compose Integration](https://docs.doppler.com/docs/docker-compose)
- [Doppler Secrets Access Guide](https://docs.doppler.com/docs/accessing-secrets)
- [Doppler Container Environment Variables](https://docs.doppler.com/docs/docker-container-env-vars)
- [NGINX Proxy Manager Setup Guide](https://nginxproxymanager.com/setup/)
- [NGINX Proxy Manager GitHub](https://github.com/NginxProxyManager/nginx-proxy-manager)
- [Doppler Community: systemd Integration](https://community.doppler.com/t/need-help-using-doppler-from-a-systemd-service-ubuntu/713)
- [Doppler Community: systemd Type=notify Issue](https://community.doppler.com/t/doppler-with-systemd-problem/1233)
- [Doppler Token Rotation Best Practices](https://community.doppler.com/t/whats-the-de-facto-standard-to-auto-rotate-dopplers-service-token/1934)
