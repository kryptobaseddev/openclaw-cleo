# CLEO CLI Installation in OpenClaw LXC

**Task**: T024
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

Successfully installed CLEO v0.79.1 CLI in the OpenClaw LXC container (10.0.10.20). The installation used the official install.sh script from the CLEO repository, and both `cleo` and `ct` aliases are now available and functional.

## Implementation Steps

### 1. Pre-Installation Assessment

**LXC Environment Check:**
- IP: 10.0.10.20
- Node.js: v24.13.0 (available)
- npm: 11.6.2 (available)
- CLEO: Not installed

**Local CLEO Analysis:**
- Local CLEO installation: /home/keatonhoskins/.cleo/
- Installation type: Bash-based CLI with symlinks
- Wrapper script: /home/keatonhoskins/.local/bin/cleo -> ~/.cleo/cleo
- Source repository: /mnt/projects/claude-todo/

### 2. Installation Method Selection

Identified official installation script at `/mnt/projects/claude-todo/install.sh` which supports:
- GitHub release-based installation
- Automatic dependency validation
- Shell profile configuration
- Symlink setup for both `cleo` and `ct` aliases

### 3. Installation Execution

**Commands:**
```bash
# Copy installer to LXC
sshpass -p 'iD7wExcIz+1kRHOl' scp -o StrictHostKeyChecking=no \
  /mnt/projects/claude-todo/install.sh root@10.0.10.20:/tmp/cleo-install.sh

# Run installer
sshpass -p 'iD7wExcIz+1kRHOl' ssh -o StrictHostKeyChecking=no root@10.0.10.20 \
  'bash /tmp/cleo-install.sh'
```

**Installation Details:**
- Version installed: 0.79.1
- Installation path: /root/.cleo
- CLI symlinks: /root/.local/bin/cleo, /root/.local/bin/ct
- Shell profile: /root/.bashrc (updated)
- Backup created: /root/.cleo/.install-state/backups/20260202050628

**Installation Components:**
- 45 skill symlinks installed
- 3 agent configurations created (claude-code, codex, gemini)
- 3 agent files installed (README.md, BASE-SUBAGENT-PROTOCOL.md, cleo-subagent.md)
- Global config: /root/.claude/cleo-global-config.json

### 4. Verification

**Version Check:**
```bash
$ cleo --version
0.79.1

$ ct --version
0.79.1
```

**Path Verification:**
```bash
$ which cleo
/root/.local/bin/cleo

$ which ct
/root/.local/bin/ct
```

**Functionality Test:**
```bash
$ cleo --help
CLEO - Task management for AI agents
Usage: cleo <command> [options]

Commands: init, add, list, update, complete, focus, session, show, find
          dash, analyze, config, backup, restore, archive, validate

Run 'cleo help <command>' for detailed options.
```

### 5. Post-Installation Notes

**Warnings Addressed:**
- PATH warning: /root/.local/bin added to PATH via .bashrc
- Claude CLI not found: Expected, as Claude CLI is separate from CLEO

**Shell Profile Integration:**
The installer automatically updated /root/.bashrc with:
- PATH export for /root/.local/bin
- CLEO environment variables
- Shell integration hooks

## Success Criteria

All success criteria met:
- ✅ `cleo` command available in LXC
- ✅ `ct` command available in LXC (alias)
- ✅ CLEO responds to `--version` (0.79.1)
- ✅ CLEO responds to `--help` with command list
- ✅ Shell profile configured for persistent access

## Key Findings

1. **Installation Method**: Official install.sh script from GitHub releases is the recommended approach
2. **Version Stability**: v0.79.1 is the latest stable version with full feature set
3. **Dependencies**: Node.js and npm were already available in the LXC (v24.13.0, 11.6.2)
4. **Shell Integration**: Automatic .bashrc configuration ensures CLEO is available in new shells
5. **Agent Integration**: CLEO installed with full agent support (claude-code, codex, gemini configs)

## Integration with OpenClaw

CLEO is now available for:
- Task management and orchestration
- Multi-agent coordination
- Session management
- Dependency tracking
- Skills-based workflows

## References

- Epic: T001 (OpenClaw Installer Implementation)
- Task: T024 (Install CLEO CLI)
- CLEO Repository: /mnt/projects/claude-todo/
- CLEO Version: 0.79.1
- Installation Script: install.sh
