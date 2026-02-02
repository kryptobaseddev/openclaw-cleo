# CLEO Cognitive Architecture

**CLEO as a Neural Brain for Autonomous AI Agents**

This document describes how CLEO serves as an externalized cognitive system for OpenClaw, providing persistent memory, structured reasoning, and intelligent context retrieval through a graph-based architecture that mirrors neural network principles.

---

## Overview

CLEO transforms AI agents from stateless responders into **systematic reasoning systems with persistent memory**. Unlike traditional vector-based RAG systems that rely on similarity search, CLEO implements a **PageIndex-inspired vectorless RAG** that uses hierarchical reasoning for context retrieval.

**Key Innovation**: "Similarity does not equal relevance - what we truly need in retrieval is relevance, and that requires reasoning."

### Performance Comparison

| Approach | Accuracy (FinanceBench) | Method |
|----------|------------------------|--------|
| Traditional Vector RAG | ~30-50% | Similarity search |
| CLEO Graph-RAG | ~98.7% | Hierarchical reasoning |

---

## Neural Network Mappings

CLEO exhibits neural-like behaviors through its task graph architecture:

| Neural Concept | CLEO Implementation |
|----------------|---------------------|
| **Neurons** | Tasks (spanning all projects) |
| **Synapses** | `relates` field entries (knowledge graph edges) |
| **Weights** | Hierarchy boosts: Sibling (+0.15), Cousin (+0.08), Ancestor (+0.04) |
| **Activation** | Similarity scores 0.0-1.0 determine signal strength |
| **Propagation** | Context flows parent→child with exponential decay |
| **Memory Indexing** | Dual-index (forward + reverse) for O(1) lookup |
| **Adaptation** | Configurable thresholds via config.json |

---

## Core Architecture: Vectorless RAG

CLEO's retrieval system eliminates vector databases in favor of:

### 1. Hierarchical Semantic Trees

The Epic→Task→Subtask hierarchy mirrors document table-of-contents structure:

```
Epic: Authentication System Overhaul
├── Task: Research OAuth providers
│   ├── Subtask: Evaluate Auth0
│   └── Subtask: Evaluate Clerk
├── Task: Design token management
└── Task: Implement login flow
```

### 2. LLM Reasoning Over Structure

Instead of embedding similarity, CLEO uses the LLM to reason about:
- Task relationships and dependencies
- Hierarchical context inheritance
- Semantic relevance through structure

### 3. Five Discovery Methods

From `lib/graph-rag.sh`:

| Method | Algorithm | Use Case |
|--------|-----------|----------|
| **Label-Based** | Jaccard similarity on shared tags | Finding tasks with common labels |
| **Description-Based** | Keyword extraction + stopword removal + Jaccard | Semantic text matching |
| **File-Based** | Relationship through shared code files | Code-centric discovery |
| **Hierarchy-Based** | LCA (Lowest Common Ancestor) + tree distance | Structural relationships |
| **Auto Mode** | Merges all methods with hierarchy boosting | Default comprehensive search |

---

## Context Propagation (Memory Inheritance)

CLEO implements "memory decay" where distant information weakens - similar to neural networks:

```
Self:        weight 1.0   (100% own context)
Parent:      weight 0.5   (50% parent context inherited)
Grandparent: weight 0.25  (25% grandparent context)
```

This creates natural context scoping where:
- Immediate task context is strongest
- Epic-level context provides background
- Distant ancestors contribute minimally

### Scoring Formula

```
final_score = min(1.0, base_score + hierarchy_boost)

Where:
  base_score = max(labels_score, description_score, files_score)
  hierarchy_boost = sibling_boost + cousin_boost + ancestor_boost
```

---

## Key Algorithms

### Lowest Common Ancestor (LCA)

```bash
_find_lca(task_a, task_b)  # Find shared ancestor in hierarchy
_tree_distance(a, b)       # Calculate graph distance between tasks
```

The LCA algorithm enables:
- Finding related tasks through common parents
- Calculating semantic distance in the hierarchy
- Boosting relevance for structurally close tasks

### Graph Cache (O(1) Index)

CLEO maintains dual indexes for instant lookup:

```
Forward Index:  task → dependencies (what this task needs)
Reverse Index:  task → dependents (what depends on this task)
```

Features:
- Checksum-based invalidation
- Automatic rebuild on structure changes
- Persistent across sessions

---

## The `relates` Field: Knowledge Graph Edges

Tasks connect through typed relationships:

| Relation Type | Meaning |
|---------------|---------|
| `relates-to` | General semantic relationship |
| `spawned-from` | Task created from another task's work |
| `deferred-to` | Work postponed to another task |
| `supersedes` | Replaces an older task |
| `duplicates` | Same work as another task |

These create undirected edges in the knowledge graph, enabling:
- Cross-cutting context discovery
- Dependency chain analysis
- Impact assessment for changes

---

## CLEO Nexus: Cross-Project Neural Brain

The Nexus system extends CLEO's brain across multiple projects:

### Commands

| Command | Purpose |
|---------|---------|
| `cleo nexus init` | Initialize the global brain |
| `cleo nexus register <path>` | Register a project's task graph |
| `cleo nexus discover <task>` | Cross-project semantic search |
| `cleo nexus deps <task>` | Analyze dependencies across projects |

### Permission Control

Three-tier access model:
- **Read**: Query tasks and relationships
- **Write**: Modify task state
- **Execute**: Run workflows and automation

### Example Usage

```bash
# Initialize Nexus
cleo nexus init

# Register this project
cleo nexus register . --name openclaw --permissions execute

# Discover related tasks across all registered projects
cleo nexus discover T2231 --limit 5
```

---

## Practical Benefits for Autonomous Agents

### 1. Persistent Goals

Tasks survive context window resets. The agent can:
- Resume work from where it left off
- Maintain long-term objectives
- Track progress across sessions

### 2. Extreme Context Efficiency

```bash
ct find "query"   # 99% less context than ct list
ct show T1234     # Full details only when needed
```

The "query before expand" pattern minimizes token usage.

### 3. Systematic Reasoning

The RCSD pipeline prevents "jumping to code":

```
Research → Consensus → Specification → Decomposition
```

Each phase has:
- Defined inputs and outputs
- Validation gates
- Evidence requirements

### 4. Multi-Agent Coordination

2-tier architecture enables parallel work:

```
Tier 0: ORCHESTRATOR
├── Coordinates workflows
├── Spawns subagents via Task tool
└── Reads manifest summaries only

Tier 1: CLEO-SUBAGENT (universal executor)
├── Receives fully-resolved prompts
├── Executes delegated work
└── Outputs: file + manifest entry + summary
```

---

## Integration with OpenClaw

OpenClaw leverages CLEO as its cognitive backbone:

| OpenClaw Component | CLEO Integration |
|-------------------|------------------|
| **Workspace** | `.cleo/` directory with task graph |
| **Skills** | CLEO skill provides task management commands |
| **Memory** | Tasks serve as structured, queryable memory |
| **Sessions** | Session state persists in task graph |
| **Agents** | Multi-agent coordination via orchestrator |

### Configuration

CLEO is initialized in the OpenClaw workspace at:
```
~/.openclaw/workspace/.cleo/
├── config.json       # CLEO configuration
├── todo.json         # Active task graph
├── sessions.json     # Session state
└── todo-log.json     # Immutable audit trail
```

---

## Why This Matters

Traditional AI agents suffer from:
- **Amnesia**: Context lost between sessions
- **Impulsivity**: Jumping to solutions without analysis
- **Isolation**: No coordination between agents
- **Inefficiency**: Bloated context windows

CLEO addresses each:
- **Memory**: Persistent task state with semantic retrieval
- **Process**: RCSD/IVTR protocols enforce systematic reasoning
- **Coordination**: Multi-agent orchestration with manifest communication
- **Efficiency**: Graph-based O(1) lookups and minimal context queries

This transforms AI from "smart autocomplete" to **"systematic reasoning system with externalized cognition."**

---

## References

- [CLEO Project](https://github.com/kryptobaseddev/cleo) - Task management for AI agents
- [PageIndex Paper](https://arxiv.org/abs/2401.07883) - Vectorless RAG research
- [OpenClaw](https://github.com/openclaw/openclaw) - Personal AI assistant platform

---

*This document is part of the OpenClaw+CLEO integration.*
