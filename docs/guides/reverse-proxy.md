# Reverse Proxy Setup with NGINX Proxy Manager

Secure external access to OpenClaw with SSL/TLS and WebSocket support.

---

## Overview

A reverse proxy provides:
- **SSL/TLS encryption** (HTTPS)
- **WebSocket support** (required for OpenClaw Control UI)
- **Rate limiting** and DDoS protection
- **Centralized access control**
- **Let's Encrypt** automatic certificate renewal

---

## Prerequisites

- **Domain name** pointing to your public IP
- **Port forwarding** configured (80, 443)
- **NGINX Proxy Manager** installed (or alternative proxy)
- **OpenClaw** running and accessible on LAN

---

## Option 1: NGINX Proxy Manager (Recommended)

### Installation

#### Proxmox LXC (tteck script)

```bash
# Run in Proxmox VE Shell
bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/ct/nginxproxymanager.sh)"
```

#### Docker Compose

```yaml
version: '3'
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
    ports:
      - 80:80
      - 443:443
      - 81:81  # Admin UI
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
```

Start:
```bash
docker-compose up -d
```

---

### Initial Setup

1. Access admin UI: `http://<proxy-ip>:81`
2. **Default credentials**:
   - Email: `admin@example.com`
   - Password: `changeme`
3. **Change password immediately**
4. Update admin email

---

### Configure Proxy Host for OpenClaw

1. **Login** to NGINX Proxy Manager UI
2. **Proxy Hosts** → **Add Proxy Host**

#### Details Tab

| Field | Value |
|-------|-------|
| **Domain Names** | `openclaw.yourdomain.com` |
| **Scheme** | `http` |
| **Forward Hostname/IP** | `10.0.10.50` (OpenClaw container IP) |
| **Forward Port** | `18789` |
| **Cache Assets** | ❌ Off |
| **Block Common Exploits** | ✅ On |
| **Websockets Support** | ✅ **On** (CRITICAL) |

**Screenshot placeholder**: `![Proxy Host Details](../assets/npm-proxy-details.png)`

#### SSL Tab

| Field | Value |
|-------|-------|
| **SSL Certificate** | Request a new SSL Certificate |
| **Force SSL** | ✅ On |
| **HTTP/2 Support** | ✅ On |
| **HSTS Enabled** | ✅ On |
| **HSTS Subdomains** | ✅ On (if using subdomains) |
| **Email** | Your email for Let's Encrypt |
| **Agree to ToS** | ✅ Yes |

Click **Save**

**Screenshot placeholder**: `![SSL Configuration](../assets/npm-ssl-config.png)`

---

### Verify Configuration

1. Wait 30-60 seconds for Let's Encrypt issuance
2. Open browser: `https://openclaw.yourdomain.com`
3. Should show OpenClaw login (no SSL errors)
4. Check WebSocket: Control UI should load properly

#### Test WebSocket

```bash
# Install wscat
npm install -g wscat

# Test WebSocket connection
wscat -c wss://openclaw.yourdomain.com/ws

# Should connect successfully
```

---

### Advanced Configuration

#### Rate Limiting

Add custom NGINX config to prevent brute-force:

**Advanced Tab** → **Custom Nginx Configuration**:

```nginx
limit_req_zone $binary_remote_addr zone=openclaw_limit:10m rate=10r/s;
limit_req zone=openclaw_limit burst=20 nodelay;

# Rate limit login endpoint
location /api/auth/login {
    limit_req zone=openclaw_limit burst=5 nodelay;
    proxy_pass http://10.0.10.50:18789;
}
```

#### IP Allowlist

Restrict access to specific IPs:

```nginx
allow 1.2.3.4;      # Your home IP
allow 5.6.7.8;      # Office IP
deny all;           # Block everyone else
```

#### Custom Headers

```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

---

## Option 2: Traefik (Alternative)

### Docker Compose

```yaml
version: '3'
services:
  traefik:
    image: traefik:v2.10
    command:
      - --api.dashboard=true
      - --providers.docker=true
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.le.acme.email=your@email.com
      - --certificatesresolvers.le.acme.storage=/acme.json
      - --certificatesresolvers.le.acme.httpchallenge.entrypoint=web
    ports:
      - 80:80
      - 443:443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./acme.json:/acme.json

  openclaw:
    image: openclaw/openclaw:latest
    labels:
      - traefik.enable=true
      - traefik.http.routers.openclaw.rule=Host(`openclaw.yourdomain.com`)
      - traefik.http.routers.openclaw.entrypoints=websecure
      - traefik.http.routers.openclaw.tls.certresolver=le
      - traefik.http.services.openclaw.loadbalancer.server.port=18789
```

---

## Option 3: Caddy (Simplest)

### Caddyfile

```caddy
openclaw.yourdomain.com {
    reverse_proxy 10.0.10.50:18789

    # Caddy handles SSL automatically via Let's Encrypt
    # WebSocket support built-in
}
```

Start Caddy:
```bash
caddy run --config Caddyfile
```

---

## DNS Configuration

### Cloudflare (Recommended)

1. Add **A Record**:
   - Name: `openclaw`
   - Content: Your public IP
   - Proxy status: **DNS only** (gray cloud)
   - TTL: Auto

**Why DNS only?** Cloudflare proxy breaks WebSockets unless you have paid plan with WebSocket support.

### Other DNS Providers

| Provider | Record Type | Host | Value |
|----------|-------------|------|-------|
| **Namecheap** | A | `openclaw` | `1.2.3.4` |
| **GoDaddy** | A | `openclaw` | `1.2.3.4` |
| **Route53** | A | `openclaw.yourdomain.com` | `1.2.3.4` |

---

## Port Forwarding

Configure on your router:

| External Port | Internal IP | Internal Port | Protocol |
|---------------|-------------|---------------|----------|
| 80 | NGINX Proxy Manager IP | 80 | TCP |
| 443 | NGINX Proxy Manager IP | 443 | TCP |

**Example**: If NPM is at `10.0.10.100`:
- `80 → 10.0.10.100:80`
- `443 → 10.0.10.100:443`

---

## Security Best Practices

| Practice | Rationale |
|----------|-----------|
| **Force SSL** | Prevent MITM attacks |
| **HSTS** | Browser remembers HTTPS-only |
| **Rate limiting** | Prevent brute-force |
| **IP allowlist** | Restrict to known IPs |
| **WebSocket security** | Validate origin headers |
| **Regular updates** | Patch vulnerabilities |
| **Fail2Ban** | Block repeated login failures |

---

## Troubleshooting

### SSL certificate failed

**Cause**: Let's Encrypt rate limit or DNS not propagated

**Fix**:
```bash
# Check DNS propagation
dig openclaw.yourdomain.com

# Verify port 80 accessible externally
curl -I http://openclaw.yourdomain.com

# Check NGINX Proxy Manager logs
docker logs nginx-proxy-manager
```

### WebSocket connection fails

**Cause**: Websockets Support not enabled or proxy timeout too short

**Fix**:
1. Proxy Host → Edit → **Details** → Enable **Websockets Support**
2. Add custom config (Advanced tab):
```nginx
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
```

### 502 Bad Gateway

**Cause**: OpenClaw container not running or wrong IP/port

**Fix**:
```bash
# Verify OpenClaw running
docker ps | grep openclaw

# Test direct connection from proxy
curl http://10.0.10.50:18789

# Check NGINX error log
tail -f /data/logs/proxy-host-1_error.log
```

### HSTS too early

**Cause**: Certificate not issued yet

**Fix**: Wait for SSL certificate issuance before enabling HSTS

---

## Monitoring

### NGINX Proxy Manager Logs

```bash
# Access logs
tail -f /data/logs/proxy-host-1_access.log

# Error logs
tail -f /data/logs/proxy-host-1_error.log
```

### Certificate Expiry

NGINX Proxy Manager auto-renews Let's Encrypt certificates 30 days before expiry.

Check renewal logs:
```bash
docker logs nginx-proxy-manager | grep renew
```

---

## Alternative: Tailscale (VPN)

For secure access without exposing ports:

```bash
# Install on OpenClaw container
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up

# Install on client devices
# Access via: http://100.x.x.x:18789
```

**Pros**: No port forwarding, end-to-end encryption, no domain needed
**Cons**: Requires Tailscale on all client devices

---

## Next Steps

- [Telegram Integration](telegram-integration.md) - Configure Telegram bot
- [Discord Integration](discord-integration.md) - Configure Discord bot
- [Doppler Setup](doppler-setup.md) - Secret management

---

## References

- [NGINX Proxy Manager Docs](https://nginxproxymanager.com/guide/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Caddy Documentation](https://caddyserver.com/docs/)
