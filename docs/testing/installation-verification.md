# OpenClaw Installation Verification Procedure

**Version**: 1.0.0
**Date**: 2026-02-01
**Purpose**: End-to-end verification checklist for OpenClaw LXC container installation

---

## Prerequisites

- Proxmox VE host with completed installation (using `scripts/install.sh`)
- Container ID and IP address (from installation output)
- SSH access or console access via `pct enter <CTID>`

---

## Verification Checklist

### 1. System Access

**From Proxmox Host:**
```bash
# Check container status
pct status <CTID>
# Expected: status: running

# Enter container console
pct enter <CTID>
```

**Via SSH (if enabled):**
```bash
# Test SSH connection
ssh root@<CONTAINER_IP>
# Expected: successful login prompt
```

**Expected Result**: Access granted to container shell

---

### 2. System Information

```bash
# Check OS version
cat /etc/os-release | grep PRETTY_NAME
# Expected: Debian GNU/Linux 12 (bookworm) or 13 (trixie)

# Check kernel
uname -r
# Expected: Proxmox kernel version (e.g., 6.8.x-x-pve)

# Check hostname
hostname
# Expected: openclaw (or custom hostname)
```

---

### 3. Node.js Verification

```bash
# Check Node.js version
node -v
# Expected: v24.x.x

# Check npm version
npm -v
# Expected: 10.x.x or higher

# Check npx availability
npx -v
# Expected: 10.x.x or higher

# Verify Node.js works
node -e "console.log('Node.js operational')"
# Expected: Node.js operational
```

---

### 4. Docker Verification

```bash
# Check Docker service status
systemctl status docker
# Expected: active (running)

# Check Docker version
docker --version
# Expected: Docker version 25.x.x or higher

# Check Docker Compose plugin
docker compose version
# Expected: Docker Compose version v2.x.x

# Verify Docker works
docker ps
# Expected: Empty container list (no errors)

# Check Docker images
docker images
# Expected: openclaw:local image present
```

**Expected Image:**
```
REPOSITORY   TAG      IMAGE ID       CREATED          SIZE
openclaw     local    <hash>         <timestamp>      <size>
```

---

### 5. GitHub CLI Verification

```bash
# Check GitHub CLI version
gh --version
# Expected: gh version 2.x.x or higher

# Check gh auth status (will show not authenticated, expected)
gh auth status
# Expected: "You are not logged into any GitHub hosts"
```

---

### 6. Doppler CLI Verification

```bash
# Check Doppler CLI version
doppler --version
# Expected: doppler version 3.x.x or higher

# Check Doppler helper script
ls -lh /usr/local/bin/setup-doppler
# Expected: -rwxr-xr-x 1 root root <size> <date> /usr/local/bin/setup-doppler

# Verify helper is executable
file /usr/local/bin/setup-doppler
# Expected: /usr/local/bin/setup-doppler: Bourne-Again shell script, ASCII text executable

# Check helper content (first 5 lines)
head -5 /usr/local/bin/setup-doppler
# Expected: Script header with usage instructions
```

---

### 7. OpenClaw Installation Verification

```bash
# Check installation directory
ls -la /opt/openclaw
# Expected: Directory exists with openclaw project files

# Check key directories
ls -d /opt/openclaw/{src,dist,scripts,node_modules}
# Expected: All directories present

# Check package.json
cat /opt/openclaw/package.json | grep '"name"'
# Expected: "name": "openclaw"

# Check built distribution
ls -lh /opt/openclaw/dist/
# Expected: Compiled JavaScript files

# Check Dockerfile
ls -lh /opt/openclaw/Dockerfile
# Expected: -rw-r--r-- 1 root root <size> <date> /opt/openclaw/Dockerfile

# Verify Docker image
docker images openclaw:local
# Expected: Image listed with recent creation date
```

---

### 8. Dependencies Verification

```bash
# Change to project directory
cd /opt/openclaw

# Check node_modules exists
ls -d node_modules
# Expected: node_modules/

# Count installed packages
ls node_modules | wc -l
# Expected: 100+ directories

# Verify key dependencies
ls node_modules/{typescript,tsx,commander,@anthropic-ai}
# Expected: All directories present
```

---

### 9. Configuration Readiness

```bash
# Check for configuration files
ls -la /opt/openclaw | grep -E '\.(env|config)'
# Expected: May show .env.example but no .env (expected - user must configure)

# Check for Doppler configuration
ls -la /opt/openclaw | grep doppler
# Expected: No doppler.yaml yet (expected - user must configure)

# Verify setup helper is available
which setup-doppler
# Expected: /usr/local/bin/setup-doppler
```

---

### 10. Resource Verification

```bash
# Check CPU allocation
nproc
# Expected: Number of cores assigned (default: 4)

# Check memory allocation
free -h | grep Mem
# Expected: Total memory assigned (default: 8GB)

# Check disk usage
df -h /
# Expected: Sufficient space available (default: 32GB total)
```

---

## Post-Installation Configuration Steps

After verification passes, user must complete:

### 1. Doppler Configuration

```bash
# Run Doppler setup helper
setup-doppler <your-doppler-service-token>

# Or manual configuration:
doppler login
doppler setup
```

### 2. GitHub Authentication (if using private repos)

```bash
gh auth login
```

### 3. Start OpenClaw Services

```bash
cd /opt/openclaw
doppler run -- docker compose up -d
```

---

## Troubleshooting

### Container Won't Start
```bash
# Check Proxmox logs
pct list | grep <CTID>
journalctl -u pve-container@<CTID> -n 50
```

### Docker Not Running
```bash
systemctl restart docker
systemctl status docker
```

### Node.js Not Found
```bash
which node
# If not found, reinstall:
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt-get install -y nodejs
```

### Missing OpenClaw Files
```bash
# Re-clone repository
cd /opt && rm -rf openclaw
git clone https://github.com/kryptobaseddev/openclaw.git
cd openclaw
npm install
npm run build
```

### Doppler Helper Not Found
```bash
# Recreate helper script
cat > /usr/local/bin/setup-doppler << 'EOF'
#!/bin/bash
# Doppler Service Token Configuration Helper
# Usage: setup-doppler dp.st.prd.xxxxxxxxxxxx

TOKEN="$1"
if [[ -z "$TOKEN" ]]; then
    echo "Usage: setup-doppler <doppler-service-token>"
    exit 1
fi
cd /opt/openclaw
export HISTIGNORE="doppler*:echo*:printf*"
printf "%s" "$TOKEN" | doppler configure set token --scope /opt/openclaw
echo "✓ Doppler configured for /opt/openclaw"
EOF
chmod +x /usr/local/bin/setup-doppler
```

---

## Automated Verification Script

Save as `/opt/openclaw/scripts/verify-install.sh`:

```bash
#!/bin/bash
# OpenClaw Installation Verification Script
set -e

echo "=== OpenClaw Installation Verification ==="
echo

echo "1. System Info"
cat /etc/os-release | grep PRETTY_NAME
hostname
echo

echo "2. Node.js"
node -v
npm -v
echo

echo "3. Docker"
docker --version
docker compose version
systemctl is-active docker
echo

echo "4. GitHub CLI"
gh --version
echo

echo "5. Doppler CLI"
doppler --version
ls -lh /usr/local/bin/setup-doppler
echo

echo "6. OpenClaw Installation"
ls -d /opt/openclaw
ls -d /opt/openclaw/{src,dist,scripts,node_modules}
echo

echo "7. Docker Image"
docker images openclaw:local
echo

echo "=== Verification Complete ==="
echo "Next steps:"
echo "  1. Configure Doppler: setup-doppler <token>"
echo "  2. Start services: cd /opt/openclaw && doppler run -- docker compose up -d"
```

Make executable:
```bash
chmod +x /opt/openclaw/scripts/verify-install.sh
```

Run verification:
```bash
/opt/openclaw/scripts/verify-install.sh
```

---

## Success Criteria

Installation is complete and verified when:

- ✅ Container is running
- ✅ Node.js v24.x installed and operational
- ✅ Docker service active with openclaw:local image
- ✅ GitHub CLI installed
- ✅ Doppler CLI installed with setup helper
- ✅ OpenClaw cloned to /opt/openclaw
- ✅ Dependencies installed (node_modules exists)
- ✅ Project built (dist/ directory exists)
- ✅ All system resources allocated correctly

User configuration pending:
- ⏳ Doppler authentication (requires service token)
- ⏳ GitHub authentication (optional, for private repos)
- ⏳ Service startup (after Doppler config)

---

## Notes

- This verification can be run immediately after `scripts/install.sh` completes
- SSH access requires password or key setup during installation
- Doppler configuration is intentionally left for user to prevent token exposure
- Docker image build may take 5-10 minutes depending on host resources
- Default resource allocation: 4 CPU cores, 8GB RAM, 32GB disk
