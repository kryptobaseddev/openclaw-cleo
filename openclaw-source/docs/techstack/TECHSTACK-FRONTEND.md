# OpenClaw Frontend Technology Stack

**Related**: [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) | [techstack.json](techstack.json)

---

## Framework

### Lit 3.3.2 (Web Components)

**Type**: LitElement-based web components with Shadow DOM

**Architecture**:
- Custom elements with TypeScript decorators
- Reactive properties via `@state` and `@property`
- CSS-in-JS through Lit's `css` template tag
- Shadow DOM for style encapsulation

**Key Decorators**:
```typescript
@customElement('openclaw-app')
class OpenClawApp extends LitElement {
  @state() private viewState: AppViewState;
  @property({ type: String }) theme = 'dark';

  static styles = css`
    :host { display: block; }
  `;
}
```

**Entry Point**: `ui/src/main.ts` → `<openclaw-app>`

---

## Build Tool

### Vite 7.3.1

**Configuration** (`ui/vite.config.ts`):

| Setting | Value |
|---------|-------|
| **Dev Port** | 5173 (strict) |
| **Output** | `../dist/control-ui` |
| **Base Path** | `OPENCLAW_CONTROL_UI_BASE_PATH` env |
| **Sourcemaps** | Enabled in production |

**Optimizations**:
- Pre-optimizes Lit directives (`lit/directives/repeat.js`)
- Tree-shaking for production builds
- Asset hashing

**Commands**:
```bash
pnpm ui:dev      # Dev server on :5173
pnpm ui:build    # Production build
pnpm ui:preview  # Preview production build
```

---

## Styling

### Approach: Vanilla CSS with Design Tokens

**No frameworks used**: No Tailwind, no CSS-in-JS libraries (beyond Lit's css tag), no CSS modules.

### Design Token System

**CSS Custom Properties** (`:root` scope):

```css
/* Colors */
--bg: #0d0d0d;
--bg-accent: #1a1a1a;
--bg-elevated: #252525;
--text: #e0e0e0;
--text-strong: #ffffff;
--text-muted: #888888;

/* Semantic Colors */
--ok: #22c55e;
--warn: #eab308;
--danger: #ef4444;
--info: #3b82f6;

/* Accent Colors */
--accent: #ff5c5c;           /* OpenClaw red */
--accent-hover: #ff7070;
--accent-muted: #ff5c5c80;
--accent-subtle: #ff5c5c20;
--accent-glow: 0 0 20px #ff5c5c40;

/* Secondary */
--secondary: #14b8a6;        /* Teal */

/* Typography */
--font-sans: 'Space Grotesk', system-ui, sans-serif;
--font-mono: 'JetBrains Mono', monospace;

/* Spacing */
--spacing-xs: 4px;
--spacing-sm: 8px;
--spacing-md: 16px;
--spacing-lg: 24px;
--spacing-xl: 32px;

/* Border Radius */
--radius-sm: 4px;
--radius-md: 8px;
--radius-lg: 12px;
--radius-xl: 16px;

/* Transitions */
--duration-fast: 100ms;
--duration-normal: 200ms;
--duration-slow: 300ms;
--ease-out: cubic-bezier(0.16, 1, 0.3, 1);

/* Shadows */
--shadow-sm: 0 1px 2px rgba(0,0,0,0.3);
--shadow-md: 0 4px 6px rgba(0,0,0,0.4);
--shadow-lg: 0 10px 15px rgba(0,0,0,0.5);
```

### Typography

| Font | Weights | Usage |
|------|---------|-------|
| **Space Grotesk** | 400-700 | Primary UI text |
| **JetBrains Mono** | 400-500 | Code, monospace |

**Source**: Google Fonts

### Theme Support

- Light/dark mode via CSS variables
- `color-scheme` meta tag
- User preference detection

### CSS File Organization

```
ui/styles/
├── base.css              # Design tokens, reset, typography
├── layout.css            # Grid, flexbox, responsive
├── layout.mobile.css     # Mobile-specific adjustments
├── components.css        # Reusable classes (.card, .stat)
├── config.css            # Form/config UI
├── chat.css              # Chat layout
└── chat/
    ├── sidebar.css       # Chat sidebar
    ├── grouped.css       # Message grouping
    ├── text.css          # Text rendering
    └── tool-cards.css    # Tool invocation cards
```

---

## State Management

### Pattern: Monolithic Lit Component + Controllers

**Architecture**:
- Single root `LitElement` (`app.ts`) manages global state
- `@state` decorator for reactive properties
- Domain-specific controllers in `ui/controllers/`
- Business logic isolated in helper files

**Controllers** (`ui/controllers/`):
- `agents.ts` - Agent management
- `channels.ts` - Channel configuration
- `chat.ts` - Chat operations
- `config.ts` - Settings
- `devices.ts` - Device pairing
- `sessions.ts` - Session management
- `skills.ts` - Skill installation

**No External Libraries**: No Redux, Zustand, MobX, or similar.

**View State Type**:
```typescript
interface AppViewState {
  currentTab: TabId;
  chatMessages: Message[];
  channels: ChannelConfig[];
  agents: Agent[];
  // ... etc
}
```

---

## UI Components

### Custom Web Components

| Component | File | Purpose |
|-----------|------|---------|
| `<openclaw-app>` | `app.ts` | Root application |
| `<resizable-divider>` | `components/resizable-divider.ts` | Draggable split pane |

### View Components

Pure function exports using `html` template literals:

```typescript
// views/chat-view.ts
export function renderChatView(state: ChatState): TemplateResult {
  return html`
    <div class="chat-container">
      ${state.messages.map(m => renderMessage(m))}
    </div>
  `;
}
```

**No Component Library**: No shadcn/ui, Radix, Material Design, or similar.

---

## TypeScript Configuration

**`ui/tsconfig.json`**:

| Setting | Value |
|---------|-------|
| **Target** | ES2022 |
| **Module** | ESNext |
| **Module Resolution** | Bundler |
| **Strict** | true |
| **Experimental Decorators** | true |
| **useDefineForClassFields** | false |
| **DOM Types** | ES2022 + DOM + DOM.Iterable |

---

## Control UI Features

### Dashboard Tabs

| Tab | Purpose |
|-----|---------|
| **Chat** | Message interface with streaming |
| **Channels** | Discord, Slack, Telegram, etc. config |
| **Agents** | Agent management, file browsing |
| **Skills** | Skill installation |
| **Logs** | Gateway logs |
| **Config** | Settings |
| **Debug** | Developer tools |

### Chat Features

- Message grouping and streaming indicators
- Markdown rendering with syntax highlighting
- Tool invocation cards
- Image attachments and drag-drop
- Focus mode toggle
- Session management with collapsible sidebar
- Thinking level indicators
- Auto-scroll-to-bottom

### Channel Configuration

Supported channels in UI:
- Discord
- Slack
- Telegram
- Signal
- iMessage
- WhatsApp
- Matrix
- Google Chat
- Nostr
- Microsoft Teams
- Mattermost
- LINE
- Zalo

---

## Testing

### Vitest 4.0.18

**Configuration**: `ui/vitest.config.ts`

**Test Types**:
- Unit tests (`.test.ts`)
- Browser tests (`.browser.test.ts`)

### Playwright 1.58.1

**Purpose**: Browser-based visual regression testing

**Screenshots**: `ui/__screenshots__/`

### @vitest/browser-playwright

**Purpose**: Headless browser test runner

---

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| **lit** | 3.3.2 | Web component framework |
| **marked** | 17.0.1 | Markdown parser |
| **DOMPurify** | 3.3.1 | HTML sanitization |
| **@noble/ed25519** | - | Cryptographic signing |

### Notable Absences

- No React, Vue, Angular
- No Tailwind CSS
- No CSS-in-JS (beyond Lit's css)
- No CSS modules
- No UI component libraries
- No external state management

---

## Build Output

| Artifact | Location |
|----------|----------|
| **HTML** | `dist/control-ui/index.html` |
| **JS Bundle** | `dist/control-ui/assets/*.js` |
| **CSS** | `dist/control-ui/assets/*.css` |
| **Assets** | `dist/control-ui/assets/` |

---

## Directory Structure

```
ui/
├── index.html              # Entry HTML
├── vite.config.ts          # Vite configuration
├── tsconfig.json           # TypeScript config
├── package.json            # UI package
├── src/
│   ├── main.ts             # Entry point
│   ├── app.ts              # Root component
│   ├── app-render.ts       # Tab rendering
│   ├── app-channels.ts     # Channel logic
│   ├── app-chat.ts         # Chat logic
│   ├── app-gateway.ts      # Gateway connection
│   └── ...
├── components/
│   └── resizable-divider.ts
├── controllers/
│   ├── agents.ts
│   ├── channels.ts
│   ├── chat.ts
│   └── ...
├── views/
│   ├── chat-view.ts
│   ├── channels-view.ts
│   └── ...
└── styles/
    ├── base.css
    ├── layout.css
    ├── components.css
    └── chat/
        └── ...
```

---

## Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| **Bundle Size** | ~200KB | Gzipped |
| **First Paint** | <500ms | Vite dev server |
| **TTI** | <1s | Production build |
| **Lighthouse Score** | 90+ | Performance |

---

## Related Documentation

- [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) - High-level overview
- [TECHSTACK-BACKEND.md](TECHSTACK-BACKEND.md) - Backend details
- [TECHSTACK-AGENTS.md](TECHSTACK-AGENTS.md) - Agent architecture
