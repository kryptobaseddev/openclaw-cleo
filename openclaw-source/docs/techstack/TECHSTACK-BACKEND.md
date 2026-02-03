# OpenClaw Backend Technology Stack

**Related**: [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) | [techstack.json](techstack.json)

---

## Runtime Environment

| Component | Technology | Version | Notes |
|-----------|------------|---------|-------|
| **Platform** | Node.js | 22+ (min 22.12.0) | Corepack enabled |
| **Language** | TypeScript | 5.9.3 | Strict mode |
| **Module System** | ESM | ES2023 target | No CommonJS |
| **Entry Point** | `openclaw.mjs` | - | CLI binary |

---

## HTTP Frameworks

### Express.js 5.2.1
- **Purpose**: Primary HTTP framework
- **Usage**: Browser control server, routing, middleware
- **Configuration**: Minimal, used alongside native http module

### Hono 4.11.7
- **Purpose**: Lightweight alternative framework
- **Usage**: API endpoints, middleware
- **Notes**: Pinned to exact version for stability

### Native HTTP Module
- **Purpose**: Base server for gateway
- **Usage**: WebSocket upgrade, raw HTTP handling

---

## WebSocket Server

### ws 8.19.0

**Features**:
- Custom binary/JSON frame protocol with versioning
- Client-server duplex RPC
- Per-client state tracking with UUID connection IDs
- Broadcast system with slow-client detection (`dropIfSlow`)
- Handshake timeout management
- Health state versioning

**Gateway Methods (Server-to-Client RPC)**:
- Chat operations (send, receive, stream)
- Agent command execution
- Model management
- Session management
- Plugin operations
- Channel management
- Webhook handling

**Events**:
- `health.*` - Gateway health state changes
- `presence.*` - Client/node presence updates
- `agent.*` - Agent lifecycle events
- Channel-specific events

---

## Database & Persistence

### SQLite (Node.js Built-in)

**Location**: `/src/memory/sqlite.ts`

**Schema**:
```sql
-- Core tables
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE files (path TEXT PRIMARY KEY, mtime INTEGER, size INTEGER);
CREATE TABLE chunks (
  id INTEGER PRIMARY KEY,
  path TEXT,
  source TEXT,
  content TEXT,
  embedding TEXT,  -- JSON array
  start_line INTEGER,
  end_line INTEGER
);
CREATE TABLE embedding_cache (
  hash TEXT PRIMARY KEY,
  embedding TEXT,
  updated_at INTEGER
);

-- Indexes
CREATE INDEX idx_chunks_path ON chunks(path);
CREATE INDEX idx_chunks_source ON chunks(source);
CREATE INDEX idx_embedding_cache_updated ON embedding_cache(updated_at);

-- Optional FTS5 for full-text search
CREATE VIRTUAL TABLE chunks_fts USING fts5(content, content=chunks, content_rowid=id);
```

### sqlite-vec 0.1.7-alpha.2

**Purpose**: Vector similarity search for semantic memory

**Features**:
- Vector operations on embedding columns
- Cosine similarity calculations
- Efficient nearest-neighbor queries

---

## Validation & Schema

| Library | Version | Purpose |
|---------|---------|---------|
| **Zod** | 4.3.6 | TypeScript schema validation |
| **@sinclair/typebox** | 0.34.48 | JSON schema generation |
| **AJV** | 8.17.1 | JSON schema validation |

---

## HTTP Client

### undici 7.20.0

**Purpose**: High-performance HTTP client

**Features**:
- Connection pooling
- HTTP/2 support
- Lower memory footprint than native fetch

---

## Gateway Server Architecture

### Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| **Port** | 18789 | Main gateway port |
| **Bridge Port** | 18790 | Secondary bridge |
| **Bind Modes** | loopback | `loopback`, `lan`, `tailnet`, `auto` |

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/chat/completions` | POST | OpenAI-compatible chat API |
| `/v1/responses` | POST | OpenResponses API |
| `/__openclaw__/canvas/` | GET | Canvas host |
| WebSocket | - | Real-time bidirectional RPC |

### Concurrency Control
- Lane-based request handling
- Per-client connection limits
- Slow-client detection and dropping

---

## Authentication & Security

### Gateway Auth Modes

| Mode | Description |
|------|-------------|
| **Token** | Bearer token in Authorization header |
| **Password** | HMAC-based password validation |
| **Tailscale** | Native Tailscale WHOIS identity |
| **Device Token** | Device-to-gateway trust |
| **Loopback** | Auto-allow for 127.0.0.1 |

### Credential Management

| Location | Purpose |
|----------|---------|
| `~/.openclaw/credentials/` | Encrypted credential storage |
| `~/.openclaw/sessions/` | Pi agent sessions |
| Environment variables | Override support (OPENCLAW_*) |

### TLS Support
- Custom TLS runtime loading
- Certificate pinning for remote gateways
- SSH tunneling support

---

## Media Processing

| Library | Version | Purpose |
|---------|---------|---------|
| **Sharp** | 0.34.5 | Image processing |
| **pdfjs-dist** | 5.4.624 | PDF parsing |
| **JSZip** | 3.10.1 | Archive handling |
| **@mozilla/readability** | - | Content extraction |
| **file-type** | 21.3.0 | File type detection |
| **Playwright Core** | 1.58.1 | Browser automation |

### Media Pipeline
- Image understanding (multimodal vision)
- Audio transcription
- Link extraction
- Media compression
- Concurrent processing with configurable limits

---

## CLI & TUI Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| **Commander.js** | 14.0.3 | CLI argument parsing |
| **@clack/prompts** | 1.0.0 | Interactive prompts |
| **chalk** | 5.6.2 | Terminal colors |
| **osc-progress** | 0.3.0 | Progress indicators |
| **tslog** | 4.10.2 | Structured logging |

---

## Serialization

| Library | Version | Purpose |
|---------|---------|---------|
| **JSON5** | 2.2.3 | Extended JSON support |
| **YAML** | 2.8.2 | Configuration files |
| **markdown-it** | 14.1.0 | Markdown parsing |

---

## File & Process Management

| Library | Version | Purpose |
|---------|---------|---------|
| **proper-lockfile** | 4.1.2 | Prevent concurrent instances |
| **tar** | 7.5.7 | Archive operations |
| **chokidar** | 5.0.0 | File watching |
| **croner** | 10.0.1 | Cron scheduling |
| **@lydell/node-pty** | 1.2.0-beta.3 | PTY handling |

---

## Deployment Targets

### Docker

```dockerfile
# Base image
FROM node:22-bookworm

# Additional tools
RUN curl -fsSL https://bun.sh/install | bash
RUN apt-get install -y jq

# Run as non-root
USER node

# Default: gateway on loopback
CMD ["node", "dist/index.js", "gateway", "--bind", "loopback"]
```

### Other Targets
- **Fly.io**: Configured via `fly.toml`
- **LXC/Proxmox**: Via `scripts/install.sh`
- **Native Apps**: macOS, iOS, Android

---

## Key Source Files

| File | LOC | Purpose |
|------|-----|---------|
| `src/gateway/server.ts` | ~800 | Gateway server setup |
| `src/memory/sqlite.ts` | ~400 | SQLite wrapper |
| `src/agents/pi-embedded-runner/run.ts` | 910 | Agent execution |
| `src/agents/system-prompt.ts` | 629 | Prompt builder |
| `src/agents/bash-tools.exec.ts` | 1627 | Shell execution |

---

## Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| **Startup Time** | <2s | With warm cache |
| **Memory (Idle)** | ~150MB | Gateway only |
| **Memory (Active)** | ~500MB | With agent sessions |
| **WebSocket Latency** | <10ms | Local network |
| **Max Connections** | ~1000 | Per gateway instance |

---

## Related Documentation

- [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) - High-level overview
- [TECHSTACK-AGENTS.md](TECHSTACK-AGENTS.md) - Agent architecture
- [TECHSTACK-EXTENSIONS.md](TECHSTACK-EXTENSIONS.md) - Plugin system
