# OpenClaw Build & Developer Tooling

**Related**: [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) | [techstack.json](techstack.json)

---

## Package Manager

### pnpm 10.23.0

**Configuration**:
- Specified via `packageManager` field in `package.json`
- Corepack enabled for reliable distribution
- Lock file: `pnpm-lock.yaml` (frozen in CI)

**Commands**:
```bash
pnpm install              # Install dependencies
pnpm install --frozen-lockfile  # CI install
```

---

## Monorepo Structure

### pnpm Workspaces

**Configuration**: `pnpm-workspace.yaml`

**No orchestration tool**: No Turborepo, Nx, or Lerna.

### Package Layout

```
openclaw-src/
├── ./                    # Root package (main CLI)
├── ./ui                  # Control UI (Vite + Lit)
├── ./packages/*          # Internal packages (clawdbot, moltbot)
├── ./extensions/*        # Plugin packages (32 extensions)
└── ./apps/*              # Native apps (Android, iOS, macOS, web)
```

---

## TypeScript Configuration

### Compiler Settings

| Setting | Value |
|---------|-------|
| **Version** | 5.9.3 |
| **Module** | NodeNext (ESM) |
| **Target** | ES2023 |
| **Strict** | true |
| **Declaration** | true |
| **Compiler Override** | `OPENCLAW_TS_COMPILER=tsc` (default: `tsgo`) |

### Config Files

| File | Purpose |
|------|---------|
| `tsconfig.json` | Main TypeScript config |
| `tsconfig.oxlint.json` | Linting config (includes src + extensions) |

---

## Linting

### Oxlint (Rust-based)

**Configuration**: `.oxlintrc.json`

**Features**:
- Type-aware linting (`--type-aware --tsconfig tsconfig.oxlint.json`)
- Unicorn plugin
- TypeScript plugin
- Oxc plugin
- Bans `any` types

**Commands**:
```bash
pnpm lint          # Type-aware check
pnpm lint:fix      # Auto-fix + format
```

### Swift Linting

| Tool | Purpose |
|------|---------|
| **SwiftLint** | Swift code linting |
| **SwiftFormat** | Swift code formatting |

---

## Formatting

### Oxfmt

**Configuration**: `.oxfmtrc.jsonc`

**Features**:
- Experimental import sorting
- package.json script sorting

**Commands**:
```bash
pnpm format        # Check formatting
pnpm format:fix    # Auto-fix
```

---

## Testing

### Vitest 4.0.18

**Coverage Provider**: V8

**Coverage Thresholds**:
| Metric | Threshold |
|--------|-----------|
| Lines | 70% |
| Functions | 70% |
| Statements | 70% |
| Branches | 55% |

### Worker Configuration

| Environment | Workers |
|-------------|---------|
| **Local** | 4-16 (based on CPU, max 16) |
| **CI** | 2-3 (Windows fewer) |
| **macOS CI** | 1 (prevent OOM) |

### Test Configurations

| Config | Purpose |
|--------|---------|
| `vitest.config.ts` | Main unit + extension + gateway |
| `vitest.e2e.config.ts` | E2E tests |
| `vitest.live.config.ts` | Live API tests (real keys) |
| `vitest.unit.config.ts` | Unit tests only |
| `vitest.extensions.config.ts` | Extension tests |
| `vitest.gateway.config.ts` | Gateway integration |

### Test Commands

```bash
pnpm test           # Parallel test run
pnpm test:watch     # Watch mode
pnpm test:coverage  # Coverage report
pnpm test:ui        # UI package tests
pnpm test:e2e       # E2E tests
pnpm test:live      # Live API tests (OPENCLAW_LIVE_TEST=1)
pnpm test:docker:*  # Docker-based E2E
```

### Playwright 1.58.1

**Purpose**: Browser-based testing

**Integration**: `@vitest/browser-playwright`

---

## Build System

### Build Process

1. TypeScript compilation (`tsc` or `tsgo`)
2. A2UI canvas bundle
3. Hook metadata generation
4. Build info generation
5. Protocol schema generation
6. UI build (Vite)

### Build Commands

```bash
pnpm build              # Full TypeScript + UI build
pnpm ui:build           # Control UI (Vite)
pnpm canvas:a2ui:bundle # A2UI bundle script
pnpm protocol:gen       # Generate protocol schema
pnpm protocol:gen:swift # Generate Swift models
```

### Development Mode

```bash
pnpm dev          # CLI in dev mode
pnpm gateway:dev  # Gateway (skips channels)
pnpm tui:dev      # TUI dev mode
pnpm ui:dev       # Control UI dev server
```

---

## CI/CD

### GitHub Actions

**Workflows**:
| Workflow | Purpose |
|----------|---------|
| `ci.yml` | Main matrix test |
| `docker-release.yml` | Docker image build |
| `install-smoke.yml` | Installation smoke tests |
| `formal-conformance.yml` | Spec validation |
| `labeler.yml` | Label assignment |
| `workflow-sanity.yml` | Workflow checks |

### Test Matrix

| Platform | Notes |
|----------|-------|
| **Ubuntu 24.04** | Blacksmith runners, 4vCPU |
| **Windows 2025** | Serial gateway tests |
| **macOS latest** | 1 worker (prevent OOM) |

### CI Gates

```bash
pnpm tsgo           # Type checking
pnpm build && pnpm lint  # Build + lint
pnpm test           # Vitest tests
pnpm protocol:check # Protocol schema validation
pnpm format         # Code formatting
bunx vitest run     # Bun runtime verification
```

---

## npm Scripts Reference

### Development

| Script | Purpose |
|--------|---------|
| `pnpm dev` | Run CLI in dev mode |
| `pnpm openclaw` | Run CLI from dist |
| `pnpm gateway:dev` | Gateway dev mode |
| `pnpm tui:dev` | TUI dev mode |
| `pnpm ui:dev` | Control UI dev server |

### Building

| Script | Purpose |
|--------|---------|
| `pnpm build` | Full TypeScript + UI build |
| `pnpm ui:build` | Control UI (Vite) |
| `pnpm canvas:a2ui:bundle` | A2UI bundle |
| `pnpm protocol:gen` | Protocol schema |
| `pnpm protocol:gen:swift` | Swift models |

### Testing

| Script | Purpose |
|--------|---------|
| `pnpm test` | Parallel unit/extension/gateway |
| `pnpm test:watch` | Watch mode |
| `pnpm test:coverage` | Coverage report |
| `pnpm test:e2e` | E2E tests |
| `pnpm test:live` | Live API tests |
| `pnpm test:docker:*` | Docker E2E variants |

### Quality

| Script | Purpose |
|--------|---------|
| `pnpm check` | Full check (tsgo + lint + format) |
| `pnpm lint` | Oxlint type-aware check |
| `pnpm lint:fix` | Auto-fix + format |
| `pnpm format` | Oxfmt check |
| `pnpm format:fix` | Oxfmt auto-fix |
| `pnpm tsgo` | Type-check only |

### Native/Platform

| Script | Purpose |
|--------|---------|
| `pnpm android:*` | Android Gradle commands |
| `pnpm ios:*` | iOS Xcode commands |
| `pnpm mac:*` | macOS app packaging |
| `pnpm format:swift` | Swift formatting |

### Release

| Script | Purpose |
|--------|---------|
| `pnpm prepack` | Pre-publish (build + ui:build) |
| `pnpm release:check` | Release validation |
| `pnpm plugins:sync` | Sync plugin versions |
| `pnpm postinstall` | Post-install hook |

---

## Docker

### Dockerfile

```dockerfile
# Base image
FROM node:22-bookworm

# Additional tools
RUN curl -fsSL https://bun.sh/install | bash
RUN apt-get install -y jq

# Build
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
RUN OPENCLAW_PREFER_PNPM=1 pnpm ui:build

# Security: run as non-root
USER node

# Default command
CMD ["node", "dist/index.js", "gateway", "--bind", "loopback"]
```

---

## Runtime Support

### Node.js

- **Required**: 22+ (minimum 22.12.0)
- **Primary runtime** for production

### Bun

- **Optional**: For scripts/dev/tests
- **Not required** for production
- **Tested in CI** alongside Node.js

---

## Package Exports

| Export | Path |
|--------|------|
| **Main** | `dist/index.js` |
| **Plugin SDK** | `dist/plugin-sdk/index.js` |
| **CLI** | `openclaw.mjs` |

---

## Git Hooks

**Location**: `git-hooks/`

**Setup**: `scripts/setup-git-hooks.js`

---

## Dependency Management

### pnpm Patches

**Location**: `patches/`

Selective modifications to dependencies.

### Package Overrides

Via pnpm config for dependency consistency:
- tar
- form-data
- hono
- etc.

---

## Key Infrastructure Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| @mariozechner/pi-* | 0.51.1 | Pi agent core |
| @whiskeysockets/baileys | 7.0.0-rc.9 | WhatsApp Web |
| Express | 5.2.1 | HTTP framework |
| Hono | 4.11.7 | Lightweight server |
| Vitest | 4.0.18 | Testing |
| Playwright | 1.58.1 | Browser testing |
| TypeScript | 5.9.3 | Compilation |
| tsx | - | TypeScript execution |
| Lit | 3.3.2 | Web components |
| Oxlint | - | Linting (Rust) |
| Oxfmt | - | Formatting |

---

## Related Documentation

- [TECHSTACK-OVERVIEW.md](TECHSTACK-OVERVIEW.md) - High-level overview
- [TECHSTACK-BACKEND.md](TECHSTACK-BACKEND.md) - Backend details
- [TECHSTACK-FRONTEND.md](TECHSTACK-FRONTEND.md) - Frontend details
- [TECHSTACK-AGENTS.md](TECHSTACK-AGENTS.md) - Agent architecture
- [TECHSTACK-EXTENSIONS.md](TECHSTACK-EXTENSIONS.md) - Plugin system
