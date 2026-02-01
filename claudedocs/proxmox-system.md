# Keaton's Proxmox VE Setup Reference

## Hardware & System
- **Host**: Dell Precision Tower 7910
- **CPU**: 72 cores (2x Intel Xeon E5-2699 v3 @ 2.30GHz)
- **RAM**: 141.54 GiB total
- **Storage**: 2TB NVMe drives + 8TB ZFS pools + smaller SSDs
- **Version**: pve-manager/8.1.4, Kernel 6.5.13-1-pve
- **Boot**: EFI mode

## Network Configuration
- **Proxmox IP**: 10.0.10.5:8006
- **External Access**: https://proxmox.hoskins.fun (via NPM)
- **Network Range**: 10.0.10.x/24
- **Reserved IPs**: 10.0.10.2-100 (static assignments)
- **DNS**: 10.0.10.1 (router) + 10.0.10.11 (Technitium)
- **Hostname**: proxmox.hoskins.myds.me

## Storage Setup
- **Primary**: LVM-thin (currently used for most VMs/LXCs)
- **Available**: ZFS pools (8TB) - underutilized, wants to learn better management
- **Note**: Storage optimization needed

## Authentication & Access
- **Users**: root (primary), keaton
- **2FA**: Google Authenticator TOTP enabled
- **Access Method**: Web UI primarily, console when needed

## Current VMs/LXCs
**LXC Containers (mostly tteck scripts):**
- Plex server
- AMP game server  
- Tautulli
- Heimdall dashboard
- Docker
- Technitium DNS
- Overseerr
- Nginx Proxy Manager (NPM)
- Home Assistant OS

**Virtual Machines:**
- Blue Iris (Windows 10)

## Deployment Preferences
- **Primary Tool**: tteck Proxmox Helper Scripts
- **Container OS**: Debian-based LXCs preferred
- **IP Assignment**: Static IPs in reserved range (10.0.10.2-100)

## Current Gaps/Priorities
- No backup strategy configured
- Limited networking knowledge (basic setup only)
- Storage management needs improvement (ZFS underutiliz