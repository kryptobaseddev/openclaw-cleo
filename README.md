# OpenClaw-CLEO

**Super-powered OpenClaw installer for Proxmox, powered by CLEO task management.**

A comprehensive automation framework for deploying [OpenClaw](https://github.com/openclaw/openclaw) personal AI assistant on self-hosted infrastructure with enterprise-grade security.

---

## Prerequisites

Before installation, ensure you have:

| Requirement | Details |
|-------------|---------|
| **Proxmox VE 8.1+** | Primary tested platform (LXC container host) |
| **Reverse Proxy** | NGINX Proxy Manager recommended for SSL/WebSocket support |
| **Doppler Account** | Secrets management - [Sign up with referral](https://doppler.com/join?invite=CA07141D) |
| **Domain Name** | For external access (optional but recommended) |
| **10GB+ Storage** | For LXC container and dependencies |

### Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| **Proxmox VE** | ✅ Primary | Fully tested on v8.1+ |
| LXD | 🟡 Community | Compatible but not officially tested |
| Incus | 🟡 Community | Compatible but not officially tested |
| Vultr, Kamatera, Kinsta | 🟡 Community | VPS providers with LXC support |
| DigitalOcean, Linode | 🟡 Community | Docker-based deployments |
| TrueNAS SCALE | 🟡 Community | LXC support via Apps |
| Unraid | 🟡 Community | Docker deployment |

---

## Quick Start

### Proxmox VE Shell (One-Liner)

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)"
```

With advanced options:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)" -- --advanced
```

With Doppler token pre-configured:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)" -- --doppler-token dp.st.prd.XXXXX
```

**See detailed installation guide**: [Installation Documentation](docs/guides/installation.md) *(coming soon)*

---

## What Gets Installed

| Component | Version | Purpose |
|-----------|---------|---------|
| Debian | 12 | LXC base OS |
| Node.js | 22 | Runtime |
| pnpm | Latest | Package manager |
| Docker | Latest | Container runtime |
| Doppler CLI | Latest | Secrets management |
| OpenClaw | Fork | AI assistant ([kryptobaseddev/openclaw](https://github.com/kryptobaseddev/openclaw)) |

---

## Post-Install Configuration

After installation completes, configure the following:

### 1. Doppler Secrets Management

Set up centralized secrets management (no `.env` files):

📘 **[Doppler Setup Guide](docs/guides/doppler-setup.md)**

**Required Secrets**:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `ANTHROPIC_API_KEY` | Claude API key | [console.anthropic.com](https://console.anthropic.com) |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth token | `openssl rand -hex 32` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot (optional) | See Telegram guide below |
| `DISCORD_BOT_TOKEN` | Discord bot (optional) | See Discord guide below |

### 2. Communication Channels

Enable Telegram and/or Discord for remote control:

- 📱 **[Telegram Integration Guide](docs/guides/telegram-integration.md)**
- 💬 **[Discord Integration Guide](docs/guides/discord-integration.md)**

### 3. Secure External Access

Configure reverse proxy for HTTPS and WebSocket support:

- 🔒 **[Reverse Proxy Setup (NGINX Proxy Manager)](docs/guides/reverse-proxy.md)**

---

## Features

- **One-liner Proxmox installer** - tteck-style LXC provisioning
- **Doppler secrets management** - No .env files, centralized secrets
- **CLEO task integration** - RCSD/IVTR lifecycle protocols
- **NGINX Proxy Manager** - Secure external access with SSL
- **Built from fork** - Uses [kryptobaseddev/openclaw](https://github.com/kryptobaseddev/openclaw)
- **Multi-channel support** - Telegram and Discord bots
- **Docker-based** - Isolated runtime environment

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     PROXMOX HOST                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           OpenClaw LXC Container                     │   │
│  │                                                       │   │
│  │  ┌─────────────┐    ┌──────────────────────────┐    │   │
│  │  │ Doppler CLI │───▶│ Secrets from Doppler     │    │   │
│  │  └─────────────┘    │ - ANTHROPIC_API_KEY      │    │   │
│  │         │           │ - GATEWAY_TOKEN          │    │   │
│  │         ▼           │ - TELEGRAM_BOT_TOKEN     │    │   │
│  │  ┌─────────────┐    └──────────────────────────┘    │   │
│  │  │   Docker    │                                     │   │
│  │  │  Container  │◀─── Built from fork                 │   │
│  │  │  (OpenClaw) │     kryptobaseddev/openclaw         │   │
│  │  └──────┬──────┘                                     │   │
│  │         │ :18789                                     │   │
│  └─────────┼────────────────────────────────────────────┘   │
│            │                                                 │
│            ▼                                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         NGINX Proxy Manager                          │   │
│  │         SSL/TLS Termination                          │   │
│  │         Rate Limiting                                │   │
│  └─────────────────────────────────────────────────────┘   │
│            │                                                 │
└────────────┼─────────────────────────────────────────────────┘
             │
             ▼
        External Access
        https://openclaw.yourdomain.com
```

---

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/install.sh` | **Main installer** - Run in Proxmox VE Shell |
| `scripts/provision-lxc.sh` | Manual LXC container provisioning |
| `scripts/setup-docker-deps.sh` | Install Docker, Node.js, dependencies |
| `scripts/generate-gateway-config.sh` | Generate OpenClaw configuration |
| `scripts/openclaw-full-setup.sh` | Master orchestration script |

---

## CLEO Integration

This project includes a CLEO skill for OpenClaw, enabling task management with RCSD/IVTR lifecycle protocols.

```bash
# Inside OpenClaw, the CLEO skill provides:
cleo find "query"           # Task discovery
cleo show T1234             # Task details
cleo complete T1234         # Complete tasks
cleo session start/end      # Session management
```

See [skills/cleo/SKILL.md](skills/cleo/SKILL.md) for full documentation.

---

## Documentation

### Setup Guides
- [Doppler Integration](docs/guides/doppler-setup.md) - Secrets management configuration
- [Telegram Integration](docs/guides/telegram-integration.md) - Telegram bot setup
- [Discord Integration](docs/guides/discord-integration.md) - Discord bot setup
- [Reverse Proxy Setup](docs/guides/reverse-proxy.md) - NGINX Proxy Manager configuration

### Reference Documentation
- [OpenClaw Research (2026)](claudedocs/OPENCLAW-RESEARCH-2026.md) - Research findings
- [Setup Plan](claudedocs/OPENCLAW-SETUP-PLAN.md) - Detailed deployment plan
- [Doppler Integration Guide](claudedocs/DOPPLER-INTEGRATION.md) - Technical deep-dive

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Container won't start** | Check Proxmox logs: `pct status <CTID>` |
| **Doppler authentication fails** | Verify service token: `doppler secrets --project openclaw --config prd` |
| **WebSocket connection fails** | Enable WebSocket support in reverse proxy |
| **Docker build fails** | Check internet connectivity and disk space |

**Full troubleshooting**: *(coming soon)*

---

## Requirements

- **Proxmox VE** 7.0+ or 8.x
- **10GB+ storage** for LXC container
- **Internet connectivity**
- **Doppler account** (free tier works) - [Sign up here](https://doppler.com/join?invite=CA07141D)

---

## Related Projects

- [OpenClaw](https://github.com/openclaw/openclaw) - The AI assistant
- [kryptobaseddev/openclaw](https://github.com/kryptobaseddev/openclaw) - Our fork
- [CLEO](https://github.com/kryptobaseddev/cleo) - Task management for AI agents

---

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. *(coming soon)*

---

## License

MIT License - See [LICENSE](LICENSE)

---

## Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/kryptobaseddev/openclaw-cleo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kryptobaseddev/openclaw-cleo/discussions)
