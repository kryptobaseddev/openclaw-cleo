# OpenClaw-CLEO

**Super-powered OpenClaw installer for Proxmox, powered by CLEO task management.**

A comprehensive automation framework for deploying [OpenClaw](https://github.com/openclaw/openclaw) personal AI assistant on self-hosted infrastructure with enterprise-grade security.

## Features

- **One-liner Proxmox installer** - tteck-style LXC provisioning
- **Doppler secrets management** - No .env files, centralized secrets
- **CLEO task integration** - RCSD/IVTR lifecycle protocols
- **NGINX Proxy Manager** - Secure external access with SSL
- **Built from fork** - Uses [kryptobaseddev/openclaw](https://github.com/kryptobaseddev/openclaw)

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
bash -c "$(wget -qLO - https://raw.githubusercontent.com/kryptobaseddev/openclaw-cleo/main/scripts/install.sh)" -- --doppler-token dp.st.prod.XXXXX
```

### What Gets Installed

| Component | Version | Purpose |
|-----------|---------|---------|
| Debian | 12 | LXC base OS |
| Node.js | 22 | Runtime |
| pnpm | Latest | Package manager |
| Docker | Latest | Container runtime |
| Doppler CLI | Latest | Secrets management |
| OpenClaw | Fork | AI assistant |

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

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/install.sh` | **Main installer** - Run in Proxmox VE Shell |
| `scripts/provision-lxc.sh` | Manual LXC container provisioning |
| `scripts/setup-docker-deps.sh` | Install Docker, Node.js, dependencies |
| `scripts/generate-gateway-config.sh` | Generate OpenClaw configuration |
| `scripts/openclaw-full-setup.sh` | Master orchestration script |

## Doppler Setup

1. Create account at [doppler.com](https://doppler.com)
2. Create project: `openclaw`
3. Create config: `prd` (production)
4. Add secrets:
   - `ANTHROPIC_API_KEY` - Your Anthropic API key
   - `OPENCLAW_GATEWAY_TOKEN` - Generate with `openssl rand -hex 32`
   - `TELEGRAM_BOT_TOKEN` - From @BotFather (optional)
   - `DISCORD_BOT_TOKEN` - From Discord Developer Portal (optional)
5. Create service token for the container

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

## NGINX Proxy Manager

Configure a proxy host:

| Setting | Value |
|---------|-------|
| Domain | `openclaw.yourdomain.com` |
| Forward Host | Container IP (e.g., `10.0.10.50`) |
| Forward Port | `18789` |
| Websockets | ✅ Enabled |
| Block Exploits | ✅ Enabled |
| SSL | ✅ Let's Encrypt |

## Documentation

- [Doppler Integration Guide](claudedocs/DOPPLER-INTEGRATION.md)
- [OpenClaw Research (2026)](claudedocs/OPENCLAW-RESEARCH-2026.md)
- [Setup Plan](claudedocs/OPENCLAW-SETUP-PLAN.md)

## Requirements

- **Proxmox VE** 7.0+ or 8.x
- **10GB+ storage** for LXC container
- **Internet connectivity**
- **Doppler account** (free tier works)

## Related Projects

- [OpenClaw](https://github.com/openclaw/openclaw) - The AI assistant
- [kryptobaseddev/openclaw](https://github.com/kryptobaseddev/openclaw) - Our fork
- [CLEO](https://github.com/kryptobaseddev/cleo) - Task management for AI agents

## License

MIT License - See [LICENSE](LICENSE)
