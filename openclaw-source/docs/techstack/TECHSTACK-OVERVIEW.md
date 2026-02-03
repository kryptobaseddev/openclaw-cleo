# OpenClaw Technology Stack Overview

**Version**: 2026.2
**Last Updated**: 2026-02-03
**Source**: Multi-agent codebase analysis of `/mnt/projects/openclaw/openclaw-src`

---

## Executive Summary

OpenClaw is a **TypeScript/Node.js** AI agent platform with a **WebSocket-based real-time architecture**, **SQLite vector database**, and **Lit web components** for the UI. It supports **16+ messaging channels** and **5+ LLM providers** through a modular **plugin system** with 32 bundled extensions.

---

## Quick Reference

| Layer | Technology | Version |
|-------|------------|---------|
| **Runtime** | Node.js | 22+ |
| **Language** | TypeScript | 5.9.3 |
| **HTTP** | Express + Hono | 5.2.1 / 4.11.7 |
| **WebSocket** | ws | 8.19.0 |
| **Database** | SQLite + sqlite-vec | Built-in |
| **Frontend** | Lit (Web Components) | 3.3.2 |
| **Build** | Vite | 7.3.1 |
| **Package Manager** | pnpm | 10.23.0 |
| **Testing** | Vitest + Playwright | 4.0.18 / 1.58.1 |
| **Linting** | Oxlint (Rust) | - |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OpenClaw Gateway                             │
│                     (Node.js 22 + TypeScript)                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │  WebSocket  │  │    HTTP     │  │   Control   │  │  Browser   │ │
│  │   Server    │  │    API      │  │     UI      │  │  Control   │ │
│  │   (ws)      │  │  (Express)  │  │   (Lit)     │  │(Playwright)│ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘ │
│         │                │                │                │        │
│  ┌──────┴────────────────┴────────────────┴────────────────┴──────┐ │
│  │                      Agent Runtime                              │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │ │
│  │  │ Pi-Agent │  │  Tools   │  │  Skills  │  │  Memory  │       │ │
│  │  │   Core   │  │  (50+)   │  │  System  │  │ (SQLite) │       │ │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │ │
│  └───────┼─────────────┼─────────────┼─────────────┼──────────────┘ │
│          │             │             │             │                │
│  ┌───────┴─────────────┴─────────────┴─────────────┴──────────────┐ │
│  │                    Plugin System (32 Extensions)                │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │ │
│  │  │Discord  │ │Telegram │ │ Slack   │ │WhatsApp │ │  +12    │  │ │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘  │ │
│  └────────────────────────────────────────────────────────────────┘ │
│          │                                                          │
│  ┌───────┴──────────────────────────────────────────────────────┐  │
│  │                    LLM Providers                              │  │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌────────┐ │  │
│  │  │Anthropic│ │ OpenAI  │ │ Gemini  │ │ Bedrock │ │ Ollama │ │  │
│  │  │ Claude  │ │  GPT-4  │ │  2.0    │ │  (AWS)  │ │ (Local)│ │  │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Overview

### Backend Services
- **Gateway Server**: WebSocket + HTTP on port 18789
- **Express/Hono**: REST API endpoints
- **SQLite**: Embedded database with vector search
- **Agent Runtime**: Pi-agent-core execution engine

See: [TECHSTACK-BACKEND.md](TECHSTACK-BACKEND.md)

### Frontend (Control UI)
- **Lit Web Components**: Shadow DOM-based UI
- **Vite**: Fast dev server and build tool
- **Design System**: CSS custom properties with dark/light modes

See: [TECHSTACK-FRONTEND.md](TECHSTACK-FRONTEND.md)

### AI/Agent System
- **Multi-provider LLM**: Anthropic, OpenAI, Google, AWS, local
- **50+ Tools**: File, web, execution, communication, memory
- **Skills System**: Injected prompts with eligibility rules
- **Memory**: Semantic search on MEMORY.md files

See: [TECHSTACK-AGENTS.md](TECHSTACK-AGENTS.md)

### Extension System
- **32 Extensions**: Channels, auth, memory, tools
- **Plugin SDK**: TypeScript-first with hooks
- **16 Messaging Channels**: Discord, Telegram, Slack, WhatsApp, etc.

See: [TECHSTACK-EXTENSIONS.md](TECHSTACK-EXTENSIONS.md)

### Build & Tooling
- **pnpm Workspaces**: Monorepo management
- **Oxlint/Oxfmt**: Rust-based linting and formatting
- **Vitest + Playwright**: Testing with 70% coverage threshold
- **GitHub Actions**: CI/CD with multi-platform matrix

See: [TECHSTACK-TOOLING.md](TECHSTACK-TOOLING.md)

---

## Key Design Principles

1. **TypeScript-First**: Full type safety across the entire codebase
2. **Plugin Architecture**: Extensible without modifying core
3. **Multi-Channel**: Unified interface for 16+ messaging platforms
4. **Multi-Provider**: LLM-agnostic with automatic failover
5. **Real-Time**: WebSocket-based bidirectional communication
6. **Embedded Database**: No external database dependencies
7. **Performance**: Rust-based tooling (Oxlint), optimized builds

---

## Directory Structure

```
openclaw-src/
├── src/                    # Core source code
│   ├── agents/             # Agent runtime, tools, skills
│   ├── channels/           # Messaging channel adapters
│   ├── config/             # Configuration types
│   ├── gateway/            # WebSocket gateway server
│   ├── memory/             # SQLite + vector search
│   ├── plugins/            # Plugin loader and SDK
│   └── ...
├── ui/                     # Control UI (Lit + Vite)
│   ├── src/                # UI source
│   ├── styles/             # CSS design system
│   └── views/              # View components
├── extensions/             # 32 bundled plugins
│   ├── discord/
│   ├── telegram/
│   ├── slack/
│   └── ...
├── apps/                   # Native apps
│   ├── android/
│   ├── ios/
│   └── macos/
├── packages/               # Internal packages
└── scripts/                # Build scripts
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [techstack.json](techstack.json) | Structured JSON for LLM agents |
| [TECHSTACK-BACKEND.md](TECHSTACK-BACKEND.md) | Backend architecture details |
| [TECHSTACK-FRONTEND.md](TECHSTACK-FRONTEND.md) | Frontend/UI details |
| [TECHSTACK-AGENTS.md](TECHSTACK-AGENTS.md) | AI agent architecture |
| [TECHSTACK-EXTENSIONS.md](TECHSTACK-EXTENSIONS.md) | Plugin/extension system |
| [TECHSTACK-TOOLING.md](TECHSTACK-TOOLING.md) | Build and dev tooling |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2026.2 | 2026-02-03 | Initial comprehensive analysis |
