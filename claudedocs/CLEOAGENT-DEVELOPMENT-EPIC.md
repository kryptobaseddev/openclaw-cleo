# CleoAgent Development Epic Plan

**Created**: 2026-02-02
**Status**: Planning
**Epic**: T100-series

## Executive Summary

This plan details the creation of **CleoAgent** - a development environment for OpenClaw+CLEO that enables the production agent to contribute to its own development through a safe self-improvement loop.

---

## Current State

| Component | Value |
|-----------|-------|
| Production LXC | CT 110 @ 10.0.10.20 |
| Domain | openclaw.hoskins.fun |
| Fork Repo | kryptobaseddev/openclaw |
| Integration Repo | kryptobaseddev/openclaw-cleo |
| CLEO Repo | kryptobaseddev/cleo |
| Secrets | Doppler (prd config) |

---

## Target State

| Component | Value |
|-----------|-------|
| Dev LXC | CT 120 @ 10.0.10.30 |
| Dev Domain | cleoagent-dev.hoskins.fun |
| Branch | `develop` (dev), `main` (prod) |
| Secrets | Doppler (dev config) |
| Identity | CleoAgent (Development) |

---

## Phase 1: Infrastructure Foundation

### T100: Provision Development LXC Container
**Priority**: Critical | **Size**: medium

Create new LXC container for CleoAgent development environment.

**Acceptance Criteria**:
- LXC provisioned: CT 120 @ 10.0.10.30
- 4 cores, 8GB RAM, 32GB storage
- Hostname: `cleoagent-dev`
- Docker and dependencies installed

### T101: Configure Dev Network Isolation
**Priority**: Critical | **Size**: small | **Depends**: T100

Firewall rules to isolate dev from prod while allowing external access.

### T102: Set Up Doppler Dev Environment
**Priority**: Critical | **Size**: small

Create `openclaw/dev` config in Doppler with separate tokens.

**Dev-Specific Secrets**:
| Secret | Purpose |
|--------|---------|
| `OPENCLAW_GATEWAY_TOKEN` | Unique for dev |
| `AGENTMAIL_EMAIL` | `cleoagent-dev@agentmail.to` |
| `GITHUB_USERNAME` | For PR creation |
| `GITHUB_PASSWORD` | For PR creation |

---

## Phase 2: Git Branch Strategy

### T103: Establish Git Branching Model
**Priority**: Critical | **Size**: small

```
main (production) ← Deployed to CT 110
  └── develop (development) ← Deployed to CT 120
       └── feature/* (feature branches)
       └── self-improve/* (agent-proposed changes)
```

**GitHub Protection Rules**:
- `main`: Require PR + review + CI
- `develop`: Require PR (auto-merge OK)

### T104: Configure Dev Branch Deployment
**Priority**: Critical | **Size**: medium | **Depends**: T100, T103

Automated deployment from `develop` to CT 120.

---

## Phase 3: CleoAgent Container Setup

### T105: Deploy OpenClaw to Dev Container
**Priority**: High | **Size**: medium | **Depends**: T100, T102, T104

Install OpenClaw from `develop` branch with CLEO integration.

### T106: Apply CleoAgent Branding
**Priority**: High | **Size**: small | **Depends**: T105

| Element | Production | Development |
|---------|------------|-------------|
| Name | OpenClaw+CLEO | CleoAgent (Dev) |
| UI Accent | Default | Yellow/Warning |
| Domain | openclaw.hoskins.fun | cleoagent-dev.hoskins.fun |

### T107: Configure Development SOUL.md
**Priority**: High | **Size**: small | **Depends**: T105

Identity file establishing CleoAgent as development-aware with self-improvement capabilities.

---

## Phase 4: Self-Improvement Loop

### T108: Define Self-Improvement Workflow
**Priority**: High | **Size**: medium | **Depends**: T103, T105

```
IDENTIFY → PROPOSE → REVIEW → VALIDATE → MERGE → TEST → PROMOTE
    ↑         ↑         ↑         ↑         ↑       ↑        ↑
  Agent    Agent    Human     CI      Human   Dev    Human
```

### T109: Create Self-Improvement CLEO Skill
**Priority**: High | **Size**: medium | **Depends**: T108

Commands: `self-improve propose`, `validate`, `submit`, `status`

### T110: Implement GitHub Integration for Agent PRs
**Priority**: High | **Size**: medium | **Depends**: T102, T108

Enable agent to create branches, PRs, add labels.

---

## Phase 5: Safety and Monitoring

### T111: Define Safety Boundaries
**Priority**: High | **Size**: medium

**Forbidden Files** (never modify via self-improvement):
- `src/security/*`, `src/auth/*`, `src/exec/*`
- `*.pem`, `*.key`, credentials
- `SECURITY.md` rules

### T112: Set Up Monitoring and Alerting
**Priority**: High | **Size**: medium | **Depends**: T105

Health checks, error rate monitoring, alerting.

### T113: Implement Audit Logging
**Priority**: High | **Size**: small | **Depends**: T110

Log all self-improvement actions for accountability.

### T114: Create Rollback Procedures
**Priority**: High | **Size**: small | **Depends**: T105, T111

Code revert, deployment rollback, container restore.

---

## Phase 6: Testing and Validation

### T115: Create Test Suite for Self-Improvements
**Priority**: Medium | **Size**: medium | **Depends**: T108, T110

CI pipeline: security scan, tests, forbidden file checks.

### T116: Define Burn-in Period Requirements
**Priority**: Medium | **Size**: small | **Depends**: T115

| Change Type | Minimum Time |
|-------------|--------------|
| Documentation | 1 hour |
| Skill changes | 24 hours |
| Core changes | 72 hours |
| Security changes | 1 week |

---

## Phase 7: Documentation

### T117: Document CleoAgent Architecture
**Priority**: Medium | **Size**: medium | **Depends**: All

Architecture, setup guide, troubleshooting, FAQ.

### T118: Create Operator Runbook
**Priority**: Medium | **Size**: small | **Depends**: T117

Quick reference for common operations.

---

## Phase 8: Communication

### T119: Configure Dev Communication Channels
**Priority**: Low | **Size**: small | **Depends**: T105

Separate or prefixed (`[DEV]`) messages.

### T120: Set Up Cross-Agent Communication
**Priority**: Low | **Size**: medium | **Depends**: T105, T106

Production ↔ Dev task coordination via CLEO Nexus.

---

## Implementation Waves

### Wave 1 (Foundation)
- T100: Provision LXC
- T102: Doppler dev config
- T103: Git branching

### Wave 2 (Deployment)
- T101: Network isolation
- T104: Deploy pipeline
- T105: OpenClaw install

### Wave 3 (Identity)
- T106: Branding
- T107: SOUL.md
- T108: Self-improvement workflow
- T111: Safety boundaries

### Wave 4 (Automation)
- T109: Self-improvement skill
- T110: GitHub integration
- T112: Monitoring
- T113: Audit logging

### Wave 5 (Validation)
- T114: Rollback procedures
- T115: Test suite
- T116: Burn-in requirements

### Wave 6 (Documentation)
- T117: Documentation
- T118: Runbook
- T119: Communication
- T120: Cross-agent

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Dev environment uptime | 99% |
| Self-improvement PR success rate | 80% |
| Time to deploy to dev | < 10 min |
| Security incidents from self-improvement | 0 |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Agent modifies forbidden files | CI validation, safety rules |
| Dev changes break production | Isolated environments, testing |
| Circular self-improvement | Human review gate |
| Doppler token leak | Audit logging, rotation |
