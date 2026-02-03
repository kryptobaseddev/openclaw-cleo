# OpenClaw Extension/Plugin System

**Related**: [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) | [techstack.json](techstack.json)

---

## Overview

OpenClaw uses a **plugin-based architecture** with 32 bundled extensions covering messaging channels, authentication providers, memory systems, and tools.

---

## Architecture Layers

```
┌─────────────────────────────────────────┐
│     OpenClawPluginApi (Register)        │ ← Plugin entry point
├─────────────────────────────────────────┤
│   Plugin Loader & Discovery             │ ← Dynamic module loading (jiti)
├─────────────────────────────────────────┤
│   PluginRegistry (Runtime)              │ ← Active plugins + state
├─────────────────────────────────────────┤
│   Bundled Extensions (32 modules)       │ ← Channel, auth, memory, tools
└─────────────────────────────────────────┘
```

---

## Extension Categories

### Channel Extensions (16 Platforms)

| Extension | ID | Features |
|-----------|-----|----------|
| **Discord** | discord | DM, Channel, Thread, Reactions, Polls, Commands |
| **Telegram** | telegram | DM, Channel, Polls, Inline buttons, Commands |
| **Slack** | slack | DM, Channel, Thread, Reactions, File uploads |
| **Signal** | signal | DM, Group |
| **WhatsApp** | whatsapp | DM, Group, Media, Reactions, Polls |
| **iMessage** | imessage | DM, Group, Media |
| **Microsoft Teams** | msteams | DM, Team, Channel, Thread, Reactions |
| **Google Chat** | googlechat | DM, Space, Thread, Reactions |
| **Matrix** | matrix | DM, Room, Thread, Reactions, Commands |
| **Mattermost** | mattermost | DM, Channel, Thread, Reactions |
| **Blue Bubbles** | bluebubbles | DM, Group, Reactions |
| **Nextcloud Talk** | nextcloud-talk | DM, Room |
| **Tlon (Urbit)** | tlon | P2P messaging |
| **LINE** | line | DM, Group |
| **Zalo** | zalo | DM, Group |
| **Zalo User** | zalouser | User-specific |

### Authentication Providers (5)

| Extension | ID | Purpose |
|-----------|-----|---------|
| **Google Antigravity Auth** | google-antigravity-auth | LLM provider authentication |
| **Google Gemini CLI Auth** | google-gemini-cli-auth | Google Gemini API auth |
| **Minimax Portal Auth** | minimax-portal-auth | Minimax LLM provider |
| **Qwen Portal Auth** | qwen-portal-auth | Alibaba Qwen auth |
| **Copilot Proxy** | copilot-proxy | Microsoft Copilot gateway |

### Memory Extensions (2)

| Extension | ID | Purpose |
|-----------|-----|---------|
| **Memory Core** | memory-core | Base memory interface |
| **Memory LanceDB** | memory-lancedb | Vector DB with OpenAI embeddings |

### Tool/Utility Extensions (4)

| Extension | ID | Purpose |
|-----------|-----|---------|
| **LLM Task** | llm-task | Generic JSON task runner |
| **Lobster** | lobster | Typed workflow with approvals |
| **OpenProse** | open-prose | VM skill pack with /prose command |
| **Diagnostics OTEL** | diagnostics-otel | OpenTelemetry tracing |
| **Voice Call** | voice-call | Voice via Twilio/Telnyx |

---

## Plugin Manifest Schema

### openclaw.plugin.json

**Minimal Schema** (Channel):
```json
{
  "id": "discord",
  "channels": ["discord"],
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {}
  }
}
```

**Full Schema** (with UI hints):
```json
{
  "id": "memory-lancedb",
  "kind": "memory",
  "name": "Memory LanceDB",
  "description": "Vector database with LanceDB and OpenAI embeddings",
  "uiHints": {
    "embedding.apiKey": {
      "label": "OpenAI API Key",
      "help": "Your OpenAI API key for embeddings",
      "sensitive": true,
      "placeholder": "sk-..."
    }
  },
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "embedding": {
        "type": "object",
        "properties": {
          "apiKey": { "type": "string" },
          "model": {
            "type": "string",
            "enum": ["text-embedding-3-small", "text-embedding-3-large"]
          }
        },
        "required": ["apiKey"]
      }
    },
    "required": ["embedding"]
  }
}
```

### Schema Fields

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `id` | string | Yes | Unique plugin identifier |
| `name` | string | No | Display name |
| `description` | string | No | Brief description |
| `channels` | string[] | Conditional | Channel IDs (if channel plugin) |
| `providers` | string[] | Conditional | Provider IDs (if auth plugin) |
| `kind` | "memory" | No | Plugin category |
| `skills` | string[] | No | Skill pack paths |
| `uiHints` | object | No | UI metadata for config forms |
| `configSchema` | JSONSchema | No | Config validation schema |

---

## Plugin Loading Flow

### 1. Discovery Phase

**Location**: `src/plugins/discovery.ts`

- Scans bundled extensions in `extensions/`
- Loads `package.json` and `openclaw.plugin.json`
- Registers plugin metadata without executing code

### 2. Manifest Loading

**Location**: `src/plugins/manifest-registry.ts`

- Reads `openclaw.plugin.json` for each plugin
- Validates schema against definition
- Builds plugin metadata registry

### 3. Dynamic Module Loading

**Location**: `src/plugins/loader.ts`

**Loader**: `jiti` (Node module runner)

- Dynamic TypeScript/ESM loading
- Resolves `openclaw/plugin-sdk` alias
- Loads `index.ts` entry point
- Supports `default export` and function modules

### 4. Registration

**Entry Point** (`index.ts`):
```typescript
import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { discordPlugin } from "./src/channel.js";
import { setDiscordRuntime } from "./src/runtime.js";

export default {
  id: "discord",
  name: "Discord",
  description: "Discord channel plugin",
  register(api: OpenClawPluginApi) {
    setDiscordRuntime(api.runtime);
    api.registerChannel({ plugin: discordPlugin });
  }
};
```

### 5. Runtime Activation

Plugin receives `OpenClawPluginApi` and calls registration methods.

---

## Plugin SDK API

### OpenClawPluginApi

```typescript
interface OpenClawPluginApi {
  // Identity
  id: string;
  name: string;
  version?: string;
  description?: string;
  source: "bundled" | "global" | "workspace" | "config";

  // Configuration
  config: OpenClawConfig;
  pluginConfig?: Record<string, unknown>;
  runtime: PluginRuntime;
  logger: PluginLogger;

  // Registration Methods
  registerTool(tool, opts?): void;
  registerHook(events, handler, opts?): void;
  registerHttpHandler(handler): void;
  registerHttpRoute({ path, handler }): void;
  registerChannel(registration | plugin): void;
  registerGatewayMethod(method, handler): void;
  registerCli(registrar, opts?): void;
  registerService(service): void;
  registerProvider(provider): void;
  registerCommand(command): void;

  // Utilities
  resolvePath(input: string): string;
  on<K extends PluginHookName>(hookName, handler, opts?): void;
}
```

### Available Hooks

| Hook | Trigger |
|------|---------|
| `before_agent_start` | Before agent session starts |
| `agent_end` | When agent finishes |
| `before_compaction` | Before context compression |
| `after_compaction` | After context compression |
| `message_received` | Inbound message |
| `message_sending` | Before outbound |
| `message_sent` | After outbound |
| `before_tool_call` | Before tool execution |
| `after_tool_call` | After tool execution |
| `tool_result_persist` | Save tool result |
| `session_start` | Session lifecycle start |
| `session_end` | Session lifecycle end |

---

## Channel Plugin Structure

### ChannelPlugin Interface

```typescript
interface ChannelPlugin<ResolvedAccount> {
  meta: ChannelMeta;
  onboarding?: OnboardingAdapter;
  pairing?: PairingAdapter;
  capabilities: CapabilitiesAdapter;
  configSchema: ConfigSchemaAdapter;
  config: ConfigAdapter<ResolvedAccount>;
  security: SecurityAdapter;
  outbound: OutboundAdapter;
  gateway: GatewayAdapter;
  status?: StatusAdapter;
  directory?: DirectoryAdapter;
  resolver?: ResolverAdapter;
  actions?: ActionsAdapter;
  auth?: AuthAdapter;
  commands?: CommandsAdapter;
  streaming?: StreamingAdapter;
  threading?: ThreadingAdapter;
}
```

### Adapters

| Adapter | Purpose |
|---------|---------|
| **meta** | Channel display metadata |
| **onboarding** | CLI wizard integration |
| **pairing** | User allowlist management |
| **capabilities** | Feature flags (threads, reactions, media, polls) |
| **configSchema** | Configuration shape validation |
| **config** | Account & config management |
| **security** | DM policy and authorization |
| **outbound** | Message sending (text, media, polls) |
| **gateway** | Message receiving & events |
| **status** | Health probes & diagnostics |
| **directory** | User/group discovery |
| **resolver** | Target ID resolution |
| **actions** | Message actions (reactions, pins) |
| **auth** | Login/logout flows |
| **commands** | Channel-specific commands |
| **streaming** | Message coalescing rules |
| **threading** | Thread/reply handling |

---

## Extension Directory Structure

```
extensions/<plugin-id>/
├── index.ts                      # Entry point (exports default plugin)
├── package.json                  # npm metadata + openclaw marker
├── openclaw.plugin.json          # Plugin manifest
├── src/
│   ├── channel.ts               # ChannelPlugin implementation
│   ├── runtime.ts               # Runtime state management
│   ├── config-schema.ts         # Config definitions
│   ├── onboarding.ts            # CLI setup wizard
│   ├── send.ts                  # Outbound message handler
│   ├── monitor.ts               # Inbound message handler
│   ├── probe.ts                 # Health checks
│   └── *.ts                     # Implementation details
├── src/*.test.ts                # Colocated unit tests
└── [optional]
    ├── skills/                  # For skill-pack plugins
    └── docs/                    # Local documentation
```

### package.json Pattern

```json
{
  "name": "@openclaw/discord",
  "version": "2026.2.1",
  "description": "OpenClaw Discord channel plugin",
  "type": "module",
  "devDependencies": {
    "openclaw": "workspace:*"
  },
  "openclaw": {
    "extensions": ["./index.ts"]
  }
}
```

---

## Plugin Configuration

### Configuration File

**Location**: `~/.openclaw/config.json`

```json
{
  "plugins": {
    "enabled": true,
    "allow": ["discord", "slack", "memory-lancedb"],
    "deny": [],
    "load": {
      "paths": []
    },
    "slots": {
      "memory": "memory-lancedb"
    },
    "entries": {
      "discord": {
        "enabled": true,
        "config": {}
      },
      "memory-lancedb": {
        "enabled": true,
        "config": {
          "embedding": {
            "apiKey": "sk-proj-...",
            "model": "text-embedding-3-small"
          }
        }
      }
    },
    "installs": {}
  }
}
```

### PluginsConfig Type

```typescript
interface PluginsConfig {
  enabled?: boolean;
  allow?: string[];
  deny?: string[];
  load?: {
    paths?: string[];
  };
  slots?: {
    memory?: string;
  };
  entries?: Record<string, {
    enabled?: boolean;
    config?: Record<string, unknown>;
  }>;
  installs?: Record<string, {
    source: "npm" | "archive" | "path";
    spec?: string;
    sourcePath?: string;
    installPath?: string;
    version?: string;
    installedAt?: string;
  }>;
}
```

---

## Channel Feature Matrix

| Channel | Direct | Channel | Thread | Media | Reactions | Polls | Commands |
|---------|--------|---------|--------|-------|-----------|-------|----------|
| Discord | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Telegram | ✓ | ✓ | - | ✓ | - | ✓ | ✓ |
| Slack | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Signal | ✓ | ✓ | - | ✓ | - | - | - |
| WhatsApp | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - |
| iMessage | ✓ | ✓ | - | ✓ | - | - | - |
| Blue Bubbles | ✓ | ✓ | - | ✓ | ✓ | - | - |
| Matrix | ✓ | ✓ | ✓ | ✓ | ✓ | - | ✓ |
| Google Chat | ✓ | ✓ | ✓ | ✓ | ✓ | - | ✓ |
| MS Teams | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Mattermost | ✓ | ✓ | ✓ | ✓ | ✓ | - | ✓ |

---

## Channel-Specific Dependencies

| Channel | Library | Version |
|---------|---------|---------|
| **Discord** | discord-api-types | - |
| **Telegram** | @grammyjs | - |
| **Slack** | @slack/web-api | - |
| **WhatsApp** | @whiskeysockets/baileys | 7.0.0-rc.9 |
| **Signal** | signal-utils | 0.21.1 |
| **LINE** | @line/bot-sdk | - |

---

## Integration Patterns

### Pattern 1: Channel Plugin

1. Define `ChannelPlugin<ResolvedAccount>` in `src/channel.ts`
2. Store `PluginRuntime` in `src/runtime.ts`
3. Export plugin definition in `index.ts`
4. Implement adapters: config, security, outbound, gateway, status

### Pattern 2: Memory Plugin

1. Implement vector store interface
2. Provide auto-capture & auto-recall hooks
3. Register hooks in `register()` callback
4. Expose memory API via `PluginRuntime`

### Pattern 3: Authentication Provider

1. Implement `ProviderPlugin` with auth methods
2. Define OAuth or API key flow
3. Return authenticated credentials
4. Register via `api.registerProvider()`

### Pattern 4: Tool/Command

1. Create typed workflow tool
2. Register via `api.registerTool()`
3. Optionally register slash command via `api.registerCommand()`
4. Handle user input & return results

---

## Design Principles

1. **Modular**: Each extension is independent, can be enabled/disabled
2. **TypeScript-first**: Full type safety via plugin-sdk
3. **Async-safe**: All operations support async/await
4. **Configuration-driven**: Behavior controlled via JSON config
5. **Runtime-injectable**: Plugins receive runtime context
6. **Hook-based**: Intercept lifecycle events without modifying core
7. **Isolated Config**: Each plugin owns its config namespace
8. **Discovery-first**: Plugins discovered before registration

---

## Related Documentation

- [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) - High-level overview
- [TECHSTACK-BACKEND.md](TECHSTACK-BACKEND.md) - Backend details
- [TECHSTACK-AGENTS.md](TECHSTACK-AGENTS.md) - Agent architecture
- [TECHSTACK-TOOLING.md](TECHSTACK-TOOLING.md) - Build tools
