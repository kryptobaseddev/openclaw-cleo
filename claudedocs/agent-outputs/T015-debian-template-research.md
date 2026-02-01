# Debian 13 (Trixie) LXC Template Research for Proxmox

**Task**: T015
**Date**: 2026-02-01
**Status**: complete

---

## Summary

Debian 13 (Trixie) LXC templates ARE officially available for Proxmox. The official template was released on September 7, 2025, and the current version is `debian-13-standard_13.1-2_amd64.tar.zst`. This template is production-ready on Proxmox VE 9.x with pve-container version 6.0.10 or later.

---

## Research Findings

### 1. Is Debian 13 (Trixie) Currently Available?

**YES** - The official Debian 13 LXC template is available in the Proxmox template repository.

- **Release Date**: September 7, 2025
- **Official Source**: http://download.proxmox.com/images/system/
- **Availability**: Via `pveam` (Proxmox VE Appliance Manager)

### 2. Correct Template Filename Format

**Current Official Template**:
```
debian-13-standard_13.1-2_amd64.tar.zst
```

**Filename Pattern**:
```
debian-{major}-standard_{major}.{minor}-{revision}_{arch}.tar.zst
```

**Download Commands**:
```bash
# Update template list
pveam update

# List available Debian templates
pveam available -section system | grep debian

# Download to local storage
pveam download local debian-13-standard_13.1-2_amd64.tar.zst
```

### 3. Latest Stable Debian Version Template

| Debian Version | Template Filename | Status |
|---------------|-------------------|--------|
| Debian 13 (Trixie) | `debian-13-standard_13.1-2_amd64.tar.zst` | Current/Latest |
| Debian 12 (Bookworm) | `debian-12-standard_12.x-x_amd64.tar.zst` | Previous Stable |

### 4. Proxmox Compatibility Matrix

| Proxmox Version | Debian 13 Support | Required pve-container |
|-----------------|-------------------|------------------------|
| PVE 9.x | Full Support | 6.0.10+ |
| PVE 8.x | Limited Support | 5.3.1+ (fixes applied) |

**Important**: Proxmox VE 9 is the primary target for Debian 13 support. PVE 8.x users may experience issues and should ensure they have the latest pve-container package.

---

## Production Readiness Assessment

### Ready for Production: YES (with caveats)

**Requirements for Production Use**:

1. **Proxmox VE 9.x recommended** - Full native support
2. **Updated packages** - Ensure pve-container >= 6.0.10
3. **Run pveam update** - Refresh template list before download

### Known Issues (Resolved)

| Issue | Resolution |
|-------|------------|
| "unsupported debian version '13.1'" | Fixed in pve-container 6.0.10 (PVE 9) / 5.3.1 (PVE 8) |
| DHCP client issues | Fixed with isc-dhcp-client and ifupdown2 pre-installed |
| systemd-networkd-wait-online delays | Disabled by default in official template |
| Template version 13.1-1 not found | Superseded by 13.1-2 |

### Pre-flight Checklist

```bash
# 1. Verify Proxmox version
pveversion

# 2. Update package lists
apt update && apt upgrade -y

# 3. Verify pve-container version (need >= 6.0.10 for PVE 9)
dpkg -l | grep pve-container

# 4. Update template index
pveam update

# 5. Verify Debian 13 template availability
pveam available -section system | grep debian-13

# 6. Download template
pveam download local debian-13-standard_13.1-2_amd64.tar.zst
```

---

## Alternative Options

### Community Template (if official unavailable)

**Provider**: gyptazy.com
**Filename**: `debian-13-standard_13.0-0_amd64.tar.zst`
**URL**: https://cdn.gyptazy.com/proxmox/lxc_container/debian-13-standard_13.0-0_amd64.tar.zst
**SHA256**: `a543bb56db53200c81649a92cd385164d51df6c8d9ac5393b8bf15bed890d9aa`

**Note**: Use official template when possible. Community template is based on upgraded Debian 12.

### Build Your Own (DAB Method)

```bash
# Install Debian Appliance Builder
apt-get install dab

# Create and build template
mkdir debian-13-standard && cd debian-13-standard
wget https://git.proxmox.com/git/dab-pve-appliances.git/plain/debian-13-standard/dab.conf
dab init
dab bootstrap
dab finalize

# Copy to template cache
cp debian-13-standard_*.tar.zst /var/lib/vz/template/cache/
```

---

## Recommendations

### For New Deployments

1. **Use Official Template**: `debian-13-standard_13.1-2_amd64.tar.zst`
2. **Target Platform**: Proxmox VE 9.x
3. **Verify Updates**: Ensure system fully updated before container creation

### For Existing Debian 12 Containers

Consider in-place upgrade rather than migration:
- Less downtime
- Preserves configurations
- Community scripts available for automated upgrades

---

## References

- [Proxmox Forum: Debian 13 LXC Template](https://forum.proxmox.com/threads/debian-13-lxc-template.169469/)
- [Proxmox Forum: Debian 13 Trixie LXC Container Image](https://forum.proxmox.com/threads/debian-13-trixie-lxc-container-image-for-proxmox-8-and-proxmox-9.170210/)
- [Proxmox Forum: Debian 13.1 Template Fix](https://forum.proxmox.com/threads/debian-13-1-lxc-template-fails-to-create-start-fix.171435/)
- [Proxmox Forum: Template Download Issue](https://forum.proxmox.com/threads/trying-to-download-debian-13-template-gives-debian-13-standard_13-1-1_amd64-tar-zst-not-found.173175/)
- [gyptazy: Community Debian 13 Template](https://gyptazy.com/blog/debian-13-trixie-final-lxc-container-image-for-proxmox8-proxmox-9/)
- [Proxmox Template Repository](http://download.proxmox.com/images/system/)

---

## Key Takeaway

**Use this template filename**:
```
debian-13-standard_13.1-2_amd64.tar.zst
```

**Debian 13 is production-ready** on Proxmox VE 9.x with updated packages.
