---
name: cleo
description: |
  CLEO Task Management System integration for AI agents.
  Provides structured task discovery, session management, and workflow orchestration
  with RCSD/IVTR lifecycle protocols for systematic project execution.
version: 1.0.0
author: keaton
homepage: https://github.com/your-repo/cleo
user-invocable: true
disable-model-invocation: false
metadata: {"openclaw": {"requires": {"bins": ["cleo"]}, "emoji": "T", "os": ["darwin", "linux"]}}
---

# CLEO Task Management Skill

You have access to the **CLEO** task management system via the `cleo` CLI. CLEO implements a 2-tier subagent architecture with RCSD/IVTR lifecycle protocols for systematic project execution.

## RCSD Pipeline (Setup Phase)

| Stage | Purpose | Output |
|-------|---------|--------|
| **Research** | Information gathering and investigation | Research documents |
| **Consensus** | Multi-stakeholder decisions | Decision records |
| **Specification** | Requirements documentation | Specification docs |
| **Decomposition** | Task breakdown into atomic units | Task tree |

## Execution Phase

| Stage | Purpose | Output |
|-------|---------|--------|
| **Implementation** | Code and deliverable creation | Working code |
| **Contribution** | Work attribution and PRs | Merged PRs |
| **Release** | Version management | Tagged releases |

---

## Essential Commands

### Task Discovery (ALWAYS use these for context efficiency)

```bash
# Fuzzy search - returns minimal fields (99% less context than list)
cleo find "query"

# ID search - finds tasks by partial ID
cleo find --id 1234

# Full task details - use after find
cleo show T1234

# List children of a parent task
cleo list --parent T001
```

**CRITICAL**: Use `cleo find` instead of `cleo list` for discovery. The `list` command includes full notes arrays which bloat context significantly.

### Session Management (REQUIRED workflow)

Sessions track work context and enable multi-agent coordination.

```bash
# Check existing sessions FIRST
cleo session list

# Check current session status
cleo session status

# Start new session with scope and focus
cleo session start --scope epic:T001 --auto-focus --name "Work Session"

# OR start with specific task focus
cleo session start --scope task:T003 --focus T003 --name "Task Session"

# End session with notes
cleo session end --note "Completed implementation of feature X"
```

**Session Protocol**:
1. ALWAYS check `cleo session list` before starting new session
2. Resume existing session if appropriate: `cleo session resume <id>`
3. End sessions properly with notes

### Task Operations

```bash
# Create task under epic
cleo add "Task title" --parent T001

# Create with priority
cleo add "Urgent fix" --parent T001 --priority high

# Complete task with notes
cleo complete T1234 --notes "Implemented feature. Tests passing."

# Set active task focus
cleo focus set T1234

# Show current focus
cleo focus show

# Get next suggested task
cleo next
```

### Project Overview

```bash
# Dashboard with stats
cleo dash

# Analyze dependencies and waves
cleo analyze T001

# Check context window usage
cleo context
```

---

## Exit Code Handling

CLEO commands return specific exit codes. **NEVER ignore exit codes**.

| Exit | Code | Meaning | Fix |
|:----:|------|---------|-----|
| 0 | Success | Operation completed | Proceed |
| 1 | E_GENERAL | Generic error | Check message |
| 2 | E_USAGE | Invalid arguments | Check command syntax |
| 3 | E_CONFIG | Configuration error | Verify .cleo/config.json |
| 4 | E_NOT_FOUND | Task not found | Use `cleo find` to verify |
| 6 | E_VALIDATION | Validation error | Check field lengths |
| 10 | E_PARENT_NOT_FOUND | Parent task missing | Verify parent exists |
| 11 | E_DEPTH_EXCEEDED | Max depth 3 reached | Restructure hierarchy |
| 12 | E_SIBLING_LIMIT | Max 7 siblings | Split into subtasks |
| 38 | E_FOCUS_REQUIRED | No focus set | Add `--auto-focus` or `cleo focus set` |
| 100 | E_SESSION_DISCOVERY | No scope provided | Run `cleo session list` first |

### Error Response Format

All errors return JSON with fix suggestions:
```json
{
  "success": false,
  "error": {
    "code": "E_NOT_FOUND",
    "message": "Task T999 not found",
    "fix": "cleo find T999"
  }
}
```

---

## Output Requirements

When working on CLEO tasks as an agent:

1. **MUST** set focus before starting work:
   ```bash
   cleo focus set T1234
   ```

2. **MUST** complete task when done:
   ```bash
   cleo complete T1234 --notes "Description of work done"
   ```

3. **SHOULD** use `cleo find` over `cleo list` (99% less context)

4. **SHOULD** link research to tasks:
   ```bash
   cleo research link T1234 <research-id>
   ```

5. **MUST NOT** fabricate task IDs - verify with `cleo exists T1234`

---

## Orchestrator Commands

For complex multi-task workflows:

```bash
# Initialize orchestration session
cleo orchestrator start --epic T001

# Analyze dependency waves
cleo orchestrator analyze T001

# Get parallel-safe tasks (no blockers)
cleo orchestrator ready --epic T001

# Get next task to spawn
cleo orchestrator next --epic T001

# Generate spawn prompt for subagent
cleo orchestrator spawn T002
```

---

## Shell Escaping

**CRITICAL**: Escape `$` characters in notes to prevent shell interpretation:

```bash
# CORRECT
cleo update T001 --notes "Price: \$395"

# WRONG - $395 interpreted as variable
cleo update T001 --notes "Price: $395"
```

---

## Quick Reference Card

```bash
# Discovery
cleo find "query"           # Search tasks
cleo show T1234             # Task details

# Session
cleo session list           # List sessions
cleo session status         # Current session
cleo session start --scope epic:T001 --auto-focus --name "Name"
cleo session end --note "Summary"

# Tasks
cleo add "Title" --parent T001
cleo complete T1234 --notes "Done"
cleo focus set T1234
cleo next

# Overview
cleo dash                   # Dashboard
cleo context                # Context usage
```

---

## Common Workflows

### Starting Work on an Epic

```bash
# 1. Check existing sessions
cleo session list

# 2. Start or resume session
cleo session start --scope epic:T001 --auto-focus --name "Feature Work"

# 3. Get first task
cleo next

# 4. Focus and work
cleo focus set T002
# ... do work ...

# 5. Complete and continue
cleo complete T002 --notes "Implemented X"
cleo next
```

### Creating Subtasks

```bash
# Find parent task
cleo find "authentication"
cleo show T005

# Create subtasks
cleo add "Implement login form" --parent T005 --priority high
cleo add "Add session validation" --parent T005
cleo add "Write auth tests" --parent T005
```

### Ending a Session

```bash
# Complete current task
cleo complete T007 --notes "Finished implementation"

# Archive completed tasks
cleo archive

# End session with summary
cleo session end --note "Completed auth feature. 3 tasks done, PR #42 ready for review."
```
