# CLEO Skill Integration Research

**Task**: T006
**Epic**: T001
**Date**: 2026-02-01
**Status**: complete

---

## Summary

Research confirms that a CLEO skill exists in the local OpenClaw project at `/mnt/projects/openclaw/skills/cleo/SKILL.md`, but the skill is **NOT deployed to the OpenClaw LXC container**. OpenClaw has a skills system that loads markdown-based skills from `~/.openclaw/skills/`, but CLEO CLI is not installed in the container, and the CLEO skill has not been synced to the workspace.

---

## Key Findings

### 1. Local CLEO Skill Exists

**Location**: `/mnt/projects/openclaw/skills/cleo/SKILL.md`

**Content Summary**:
- Complete 291-line skill definition for CLEO task management
- Documented RCSD/IVTR lifecycle protocols
- Essential commands: `cleo find`, `cleo show`, `cleo add`, `cleo complete`
- Session management protocols
- Exit code handling with error JSON format
- Orchestrator commands for multi-agent coordination
- Shell escaping guidelines

**Metadata**:
```yaml
metadata: {"openclaw": {"requires": {"bins": ["cleo"]}, "emoji": "T", "os": ["darwin", "linux"]}}
```

The skill declares a binary requirement for `cleo` CLI on darwin/linux platforms.

### 2. OpenClaw Skills System Architecture

**Skills Location in Container**: `~/.openclaw/skills/` (empty directory found)

**Source Code Evidence**:
- OpenClaw loads skills from workspace: `buildWorkspaceSkillSnapshot`, `loadWorkspaceSkillEntries`, `syncSkillsToWorkspace`
- Supports markdown-based skills (`.md` format)
- Has bundled skills allowlist system
- Skills can declare binary requirements via metadata

**Extension Examples Found**:
- `lobster` - Multi-step workflow system with approval checkpoints
- `open-prose` - 20+ prose examples and compiler
- 30+ extensions in `openclaw-src/extensions/` directory

### 3. CLEO CLI Not Installed in LXC

**Verification**:
```bash
root@10.0.10.20: which cleo 2>/dev/null || which ct 2>/dev/null
Result: CLEO CLI not found
```

The required `cleo` binary is missing from the container PATH.

### 4. OpenClaw Workspace Configuration

**Workspace Location**: `~/.openclaw/workspace/`

**Files Present**:
- `AGENTS.md` (7869 bytes)
- `BOOTSTRAP.md` (1470 bytes)
- `HEARTBEAT.md` (168 bytes)
- `IDENTITY.md` (635 bytes)
- `SOUL.md` (1673 bytes)
- `TOOLS.md` (860 bytes)
- `USER.md` (481 bytes)
- `.git/` (workspace is version controlled)

**Missing**:
- `CLAUDE.md` - Not found in workspace
- No CLEO skill synced to `~/.openclaw/skills/`

### 5. OpenClaw Configuration

**Config Path**: `~/.openclaw/openclaw.json`

**Relevant Settings**:
```json
{
  "agents": {
    "defaults": {
      "workspace": "/root/.openclaw/workspace"
    }
  },
  "gateway": {
    "mode": "local",
    "auth": { "token": "a7a3d116acb2dc822631d15f8c785fdfb54c8c0c09a8d628" }
  }
}
```

No explicit skills configuration found. Default workspace is `/root/.openclaw/workspace`.

### 6. Skills Loading Implementation

**Code Path**: `/app/dist/agents/skills.js`

**Functions**:
- `resolveSkillConfig` - Resolve skill configuration
- `resolveSkillsInstallPreferences` - Handle skill installation (npm, pnpm, yarn, bun)
- `buildWorkspaceSkillsPrompt` - Build prompt from workspace skills
- `syncSkillsToWorkspace` - Sync skills to workspace directory

**Install Preferences**:
```javascript
preferBrew: true (default)
nodeManager: "npm" | "pnpm" | "yarn" | "bun"
```

---

## Critical Gaps for CLEO Integration

### Gap 1: CLEO CLI Installation
**Issue**: Binary requirement `cleo` not met
**Impact**: Skill cannot execute commands
**Required Action**: Install CLEO CLI in LXC container

### Gap 2: Skill Not Synced
**Issue**: CLEO skill exists locally but not in `~/.openclaw/skills/`
**Impact**: OpenClaw cannot load or use the skill
**Required Action**: Copy skill to workspace or configure skill path

### Gap 3: No Workspace CLAUDE.md
**Issue**: Standard agent injection point missing
**Impact**: CLEO context not available to OpenClaw agents
**Required Action**: Create/configure workspace CLAUDE.md with CLEO injection

### Gap 4: Skill Integration Testing
**Issue**: No evidence of skill loading verification
**Impact**: Unknown if OpenClaw can parse/execute CLEO skill format
**Required Action**: Test skill loading and command execution

---

## OpenClaw Skills System Context

**Extension Model**: OpenClaw uses a modular extension system with 30+ bundled extensions

**Skill Format**: Markdown files with YAML frontmatter metadata

**Integration Points**:
1. Workspace skills directory (`~/.openclaw/skills/`)
2. Workspace configuration files (`AGENTS.md`, `TOOLS.md`, etc.)
3. Binary requirements via metadata (`requires.bins`)
4. Platform filtering (`os: ["darwin", "linux"]`)

**Example Skill Structure** (from lobster):
```markdown
# Skill Name

Description and when to use it.

## Usage
...
```

---

## Recommendations

### Phase 1: Environment Setup
1. Install CLEO CLI in OpenClaw LXC container
2. Verify `cleo --version` works in container
3. Initialize CLEO in container workspace

### Phase 2: Skill Deployment
1. Copy `/mnt/projects/openclaw/skills/cleo/SKILL.md` to `~/.openclaw/skills/cleo/SKILL.md`
2. Verify OpenClaw skill loading with `openclaw skills status`
3. Test skill invocation from OpenClaw agent

### Phase 3: Orchestration Integration
1. Create workspace `CLAUDE.md` with CLEO injection reference
2. Configure default orchestrator to use CLEO for task management
3. Test multi-agent coordination via CLEO session management

### Phase 4: Documentation
1. Document CLEO skill installation for OpenClaw
2. Add CLEO workflow examples to OpenClaw docs
3. Create troubleshooting guide for skill integration

---

## Technical Details

### CLEO Binary Installation Options

**Option A: Global Install**
```bash
npm install -g @keaton/cleo
# or
git clone https://github.com/keatonhoskins/cleo.git /opt/cleo
ln -s /opt/cleo/bin/cleo /usr/local/bin/cleo
```

**Option B: Container-specific Install**
```bash
# Inside LXC
cd ~/.openclaw
git clone https://github.com/keatonhoskins/cleo.git .cleo-install
ln -s ~/.openclaw/.cleo-install/bin/cleo /usr/local/bin/cleo
```

### Skill Sync Command Pattern

Based on OpenClaw architecture:
```bash
# Manual sync
cp /mnt/projects/openclaw/skills/cleo/SKILL.md ~/.openclaw/skills/cleo/

# Automatic sync (if supported)
openclaw skills sync --source /mnt/projects/openclaw/skills
```

---

## References

- Local CLEO Skill: `/mnt/projects/openclaw/skills/cleo/SKILL.md`
- OpenClaw Skills Code: `/app/dist/agents/skills.js`
- OpenClaw Extensions: `/mnt/projects/openclaw/openclaw-src/extensions/`
- Workspace: `~/.openclaw/workspace/`
- Epic: T001 (OpenClaw Autonomous AI Assistant Setup)
- Task: T006 (Create CLEO skill for OpenClaw integration)

---

## Next Steps

1. Install CLEO CLI in LXC container (T007 - suggested)
2. Deploy CLEO skill to OpenClaw workspace (T008 - suggested)
3. Configure CLAUDE.md with CLEO context (T009 - suggested)
4. Test CLEO-orchestrated workflow in OpenClaw (T010 - suggested)
