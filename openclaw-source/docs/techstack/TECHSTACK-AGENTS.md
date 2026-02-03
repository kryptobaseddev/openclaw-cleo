# OpenClaw AI Agent Architecture

**Related**: [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) | [techstack.json](techstack.json)

---

## Core Framework

### Pi-Agent Libraries

| Package | Version | Purpose |
|---------|---------|---------|
| **@mariozechner/pi-agent-core** | 0.51.1 | Core agentic AI framework |
| **@mariozechner/pi-ai** | 0.51.1 | AI model integration layer |
| **@mariozechner/pi-coding-agent** | 0.51.1 | Code execution agent |
| **@mariozechner/pi-tui** | 0.51.1 | Terminal UI for agents |

---

## Execution Model

### 2-Tier Architecture

```
Tier 0: Orchestrator (ct-orchestrator)
├── Coordinates complex workflows
├── Pre-resolves all tokens/templates
├── Manages sub-agent lifecycle
└── Reads manifest summaries only

Tier 1: Embedded Pi Agent (Universal Executor)
├── Receives fully-resolved prompts
├── Loads skills via protocol injection
├── Executes delegated work
└── Outputs: file + manifest + summary
```

### Agent Lifecycle

1. **Initialization**: Create session with `RunEmbeddedPiAgentParams`
2. **Authentication**: Resolve auth profiles → API keys
3. **Model Resolution**: Discover model from provider config
4. **System Prompt**: Build dynamic prompt based on capabilities
5. **Execution**: Run agent loop with tool availability
6. **Result Processing**: Stream responses, handle tool calls
7. **Completion**: Persist session, record metadata

---

## LLM Providers

### Supported Providers

| Provider | Models | Auth Methods | Features |
|----------|--------|--------------|----------|
| **Anthropic** | Claude 3/3.5 (Opus, Sonnet, Haiku) | API Key, OAuth | Cached prompts, vision, tool use |
| **OpenAI** | GPT-4, GPT-4 Turbo, GPT-3.5, GPT-4o | API Key | Vision, tool use, JSON mode |
| **Google Gemini** | Gemini 2.0, 1.5 Pro/Flash | API Key, OAuth | Thinking mode, vision, long context |
| **AWS Bedrock** | Auto-discovered | AWS Credentials | Cross-region support |
| **GitHub Copilot** | Via token resolution | OAuth token | - |
| **Ollama** | Local models | None | localhost:11434 |
| **Qwen** | Alibaba models | Portal OAuth | - |
| **MiniMax** | Chinese LLM | Portal OAuth | - |
| **Xiaomi Mimo** | FlashAttention models | - | - |
| **Moonshot** | Kimi models | - | - |
| **Venice** | Open models | - | - |

### Model Configuration

| Location | Purpose |
|----------|---------|
| `~/.openclaw/models.json` | Custom model definitions |
| Bundled defaults | In agent directory |

### Authentication Profiles

**Location**: `src/agents/auth-profiles/`

**Features**:
- Multiple auth profiles per provider
- Last-good profile tracking
- Failure/cooldown management
- OAuth fallback support
- External CLI credential sync (`gcloud`, `aws`)

---

## Tool System

### Tool Architecture

Tools defined as `AnyAgentTool` from `@mariozechner/pi-agent-core`:

```typescript
interface AgentTool {
  label: string;           // Human-readable name
  name: string;            // Machine identifier
  description: string;     // Tool documentation
  parameters: JsonSchema;  // Input schema (TypeBox)
  execute: (toolCallId: string, params: unknown) => Promise<AgentToolResult>;
}
```

### Built-in Tools (50+)

#### File & Workspace Tools
| Tool | Purpose |
|------|---------|
| `read` | Read file contents |
| `write` | Create/overwrite files |
| `edit` | Make precise edits |
| `apply_patch` | Apply multi-file patches |
| `grep` | Search file contents |
| `find` | Find files by glob pattern |
| `ls` | List directory contents |

#### Execution Tools
| Tool | Purpose |
|------|---------|
| `exec` | Run shell commands (TTY support) |
| `process` | Manage background sessions |

#### Web Tools
| Tool | Purpose |
|------|---------|
| `web_search` | Brave API search |
| `web_fetch` | Extract readable content from URLs |

#### Browser & UI
| Tool | Purpose |
|------|---------|
| `browser` | Control web browser |
| `canvas` | Present/evaluate canvas content |
| `nodes` | List/notify on paired devices |

#### Communication
| Tool | Purpose |
|------|---------|
| `message` | Send messages + channel actions |
| `sessions_send` | Send to other sessions |
| `telegram_actions` | Telegram-specific actions |
| `discord_actions` | Discord-specific actions |
| `slack_actions` | Slack-specific actions |
| `whatsapp_actions` | WhatsApp-specific actions |

#### Memory
| Tool | Purpose |
|------|---------|
| `memory_search` | Semantic search on MEMORY.md |
| `memory_get` | Snippet read from memory files |

#### System & Meta
| Tool | Purpose |
|------|---------|
| `gateway` | Restart/apply config/updates |
| `agents_list` | List allowed sub-agents |
| `sessions_list` | List other sessions |
| `sessions_history` | Fetch session history |
| `sessions_spawn` | Spawn sub-agent |
| `session_status` | Show status card |
| `image` | Analyze images |

#### Scheduling
| Tool | Purpose |
|------|---------|
| `cron` | Manage cron jobs and wake events |

### Tool Availability

- **Channel-based gating**: Tools filtered by message channel
- **Group-level policies**: Per-channel/group restrictions
- **Policy inheritance**: Sub-agents inherit parent policies
- **Runtime filtering**: Tools filtered at execution time

---

## Memory System

### Architecture

**Two-tool Memory System**:

1. **`memory_search`** - Semantic search
   - Searches `MEMORY.md` + `memory/*.md` files
   - Optional session transcripts
   - Returns top N snippets with paths/line numbers
   - Configurable min score filtering

2. **`memory_get`** - Safe snippet reader
   - Reads specific files from memory directory
   - Supports line ranges
   - Used after `memory_search` to minimize context

### Configuration

| Setting | Value |
|---------|-------|
| **Path** | `~/.openclaw/MEMORY.md` + `~/.openclaw/memory/*.md` |
| **Search Manager** | Lazy-loaded |
| **Providers** | OpenAI embeddings, Google Gemini, Local |

### Features
- Semantic embedding-based matching
- Configurable max results
- Min score thresholds
- Fallback providers
- Session-aware (include/exclude transcripts)

---

## Skills System

### Architecture

Skills are **injected into system prompts** as reusable multi-file guides.

### Skill Loader (`src/agents/skills/workspace.ts`)

**Sources**:
- Bundled skills (from `pi-coding-agent`)
- Managed skills (user-installed)
- Plugin skills (from extensions)
- Environment variable overrides

### Skill Eligibility

- Channel-based filtering
- User role checks
- Configuration guards
- Invocation policy (manual, auto-eligible, auto-run)

### System Prompt Skill Section

```
## Skills (mandatory)
Before replying: scan <available_skills> <description> entries.
- If exactly one skill clearly applies: read its SKILL.md, then follow it.
- If multiple could apply: choose most specific, read/follow it.
- If none clearly apply: do not read any SKILL.md.
Constraints: never read more than one skill up front; only read after selecting.
```

---

## Prompt Management

### Dynamic System Prompt Builder

**Location**: `src/agents/system-prompt.ts` (629 LOC)

**Function**: `buildAgentSystemPrompt(params)`

### Prompt Sections

```
Identity Line
├── Tooling Section (available tools + descriptions)
├── Tool Call Style (narration guidance)
├── Safety Section (constitution-inspired safeguards)
├── CLI Quick Reference
├── Skills (optional, with guidance)
├── Memory Recall (if memory tools available)
├── User Identity (owner numbers if configured)
├── Time Section (timezone + date/time guidance)
├── Workspace (working directory)
├── Documentation (OpenClaw docs path)
├── Sandbox (if sandboxed, explain restrictions)
├── Messaging (message tool + channel config)
├── Voice (TTS hints if available)
├── Reply Tags (channel-specific reply routing)
├── Model Aliases (if configured)
├── Workspace Files (injected context, SOUL.md persona)
├── Group Chat Context (if multi-agent)
├── Silent Replies (when nothing to say)
├── Heartbeats (for polling)
└── Runtime Info (agent/host/model metadata)
```

### Prompt Modes

| Mode | Description |
|------|-------------|
| **full** | Complete system prompt (main agent) |
| **minimal** | Reduced sections (subagents) |
| **none** | Basic identity line only |

---

## Session Management

### Session Structure

**Location**: `~/.openclaw/agents/<agentId>/sessions/`

**Format**: JSONL (JSON Lines) - one message per line

### Session Parameters

```typescript
interface RunEmbeddedPiAgentParams {
  sessionId: string;
  sessionKey?: string;
  sessionFile: string;
  messageChannel?: string;
  messageProvider?: string;
  messageTo?: string;
  messageThreadId?: string | number;

  // Sender context
  senderId?: string;
  senderName?: string;
  senderUsername?: string;
  senderE164?: string;

  // Message handling
  replyToMode?: "off" | "first" | "all";
  hasRepliedRef?: { value: boolean };

  // Execution config
  provider?: string;
  model?: string;
  authProfileId?: string;
  thinkLevel?: ThinkLevel;
  verboseLevel?: VerboseLevel;
  reasoningLevel?: ReasoningLevel;

  // Tools config
  disableTools?: boolean;
  clientTools?: ClientToolDefinition[];
  execOverrides?: ExecToolDefaults;

  // Callbacks
  onPartialReply?: (payload) => void;
  onAssistantMessageStart?: () => void;
  onBlockReply?: (payload) => void;
}
```

### Message Types

- `UserMessage`: User input + attachments
- `AssistantMessage`: Agent output + tool calls
- `ToolResultMessage`: Tool execution results

### Context Management

- **Hard minimum**: 1500 tokens for responses
- **Warn threshold**: 10K tokens remaining
- **Auto-compaction**: When approaching limit
- **Token tracking**: Per provider/model defaults

---

## Sub-Agent System

### Sub-Agent Registry (`src/agents/subagent-registry.ts`)

**Tracking Structure**:
```typescript
interface SubagentRun {
  runId: string;
  childSessionKey: string;
  requesterSessionKey: string;
  task: string;
  createdAt: number;
  startedAt?: number;
  endedAt?: number;
  outcome?: SubagentRunOutcome;
  cleanup: "delete" | "keep";
}
```

### Sub-Agent Lifecycle

1. Parent spawns child via `sessions_spawn`
2. Child runs independently in own session
3. Child completes and sends completion announcement
4. Parent optionally waits for completion
5. Cleanup (delete or keep session files)

---

## Failover Strategy

**Location**: `src/agents/pi-embedded-helpers.ts`

| Failure Type | Action |
|--------------|--------|
| Auth errors | Try next profile |
| Rate limits | Wait + retry |
| Context overflow | Compact session |
| Model not found | Try fallback model |
| Timeout | Retry with shorter timeout |

---

## Sandboxing

**Location**: `src/agents/sandbox/`

| Feature | Options |
|---------|---------|
| **Runtime** | Docker isolation |
| **Workspace Access** | none, ro, rw |
| **Elevated Policies** | ask, auto, full |
| **Browser Bridge** | WebSocket |
| **Observer** | noVNC for visual debugging |

---

## Message Flow

```
User Input
   ↓
[Channel Adapter] (Telegram, Discord, Signal, etc.)
   ↓
Session Manager
   ↓
Context Window Guard (check tokens)
   ↓
Model Resolution (select provider/model)
   ↓
Auth Profile Resolution (get API key)
   ↓
System Prompt Builder (dynamic + skills + memory)
   ↓
runEmbeddedPiAgent()
   ├── Build payloads (tools + context)
   ├── Call LLM API (stream responses)
   ├── Handle tool calls (exec tools)
   ├── Stream results back
   └── Persist to session file
   ↓
[Result Processing]
   ├── Filter by channel capability
   ├── Apply block chunking
   ├── Send via messaging tool
   └── Emit completion event
```

---

## Key Source Files

| File | LOC | Purpose |
|------|-----|---------|
| `pi-embedded-runner/run.ts` | 910 | Main agent execution loop |
| `system-prompt.ts` | 629 | Dynamic system prompt builder |
| `models-config.providers.ts` | 554 | LLM provider discovery |
| `bash-tools.exec.ts` | 1627 | Shell execution tool |
| `tools/memory-tool.ts` | ~200 | Memory search/get tools |
| `tools/message-tool.ts` | 430 | Multi-channel messaging |
| `skills/workspace.ts` | 440 | Skill loading |
| `subagent-registry.ts` | 429 | Sub-agent tracking |
| `context-window-guard.ts` | ~200 | Token budget management |
| `pi-embedded-runner/compact.ts` | 494 | Session compaction |

---

## Related Documentation

- [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) - High-level overview
- [TECHSTACK-BACKEND.md](TECHSTACK-BACKEND.md) - Backend details
- [TECHSTACK-EXTENSIONS.md](TECHSTACK-EXTENSIONS.md) - Plugin system
