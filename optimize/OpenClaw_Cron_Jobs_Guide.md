Here is the cleaned-up version in proper markdown format, with consistent spacing, no trailing spaces on lines, and no unnecessary blank lines:

```markdown
# OpenClaw Cron Jobs Guide: The Complete Walkthrough

This document provides a comprehensive guide to scheduling and managing cron jobs within the OpenClaw Gateway. OpenClaw features a built-in scheduler where jobs persist across restarts and can deliver output to various communication channels.

---

## 1. Core Concepts

OpenClaw cron jobs run **inside the Gateway**, not the AI model itself. The Gateway persists these jobs and "wakes" the agent at the scheduled time.

### Schedule Types

| Type    | Description                                                  |
|---------|--------------------------------------------------------------|
| **at**    | A one-shot timestamp for single-run tasks.                   |
| **every** | An interval-based schedule (defined in milliseconds internally). |
| **cron**  | A standard 5-field cron expression with timezone support.    |

### Session Management

- **Main Session:** Runs within your existing heartbeat context. Best for reminders and context-aware tasks where conversation history is needed.
- **Isolated Session:** Runs in a fresh session (`cron:<jobId>`). There is no conversation carry-over, which keeps the main chat free of clutter.

### Delivery and Overrides

- **Delivery Modes:** Jobs can "announce" output to WhatsApp, Telegram, Slack, or Discord. "None" runs the job silently.
- **Model Overrides:** You can specify a different model per job (e.g., cheap models for simple tasks, Opus for deep analysis) and set thinking levels.

---

## 2. Syntax and Operators

OpenClaw uses **croner** for parsing. If no timezone is specified, it defaults to the Gateway host's local TZ.

### The 5-Field Expression

`minute hour day-of-month month day-of-week`

### Common Operators

- `*` : Any/every value.
- `/` : Step values (e.g., `*/5` for every 5th).
- `,` : Value list (e.g., `1,15`).
- `-` : Range (e.g., `1-5` for Mon–Fri).

### Schedule Examples

| Expression      | Frequency            |
|-----------------|----------------------|
| `* * * * *`     | Every minute         |
| `*/5 * * * *`   | Every 5 minutes      |
| `0 * * * *`     | Top of every hour    |
| `0 0 * * *`     | Daily at midnight    |
| `0 7 * * *`     | Daily at 7 AM        |
| `0 8 * * 1-5`   | Weekdays at 8 AM     |
| `0 9 * * 1`     | Every Monday at 9 AM |

---

## 3. CLI Management

Commands for managing jobs via the OpenClaw terminal interface.

### Adding Jobs

**One-Shot Reminder (Main Session):**

```bash
openclaw cron add \
  --name "Reminder" \
  --at "2026-02-01T16:00:00Z" \
  --session main \
  --system-event "Reminder: check the cron docs draft" \
  --wake now --delete-after-run
```

**Recurring Isolated Job (Slack Delivery):**

```bash
openclaw cron add \
  --name "Morning brief" \
  --cron "0 7 * * *" \
  --tz "America/Los_Angeles" \
  --session isolated \
  --message "Summarize overnight updates." \
  --announce \
  --channel slack --to "channel:CHANNELID"
```

### Management Commands

| Command                           | Purpose                           |
|-----------------------------------|-----------------------------------|
| `openclaw cron list`              | List all jobs and status          |
| `openclaw cron run <jobId>`       | Force-run a job immediately       |
| `openclaw cron edit <jobId>`      | Update an existing job's parameters |
| `openclaw cron runs --id <jobId>` | View execution history            |
| `openclaw cron rm <jobId>`        | Delete a job                      |

---

## 4. Delivery Targets

Isolated jobs can deliver directly to connected channels without requiring a heartbeat for delivery.

- **WhatsApp / iMessage / Signal:** `--to "+15551234567"`
- **Discord:** `--to "channel: 123456789"`
- **Slack:** `--to "channel: C1234567890"`
- **Telegram:** `--to "-1001234567890:topic:123"`

---

## 5. Cron vs. Heartbeat

| Feature     | Heartbeat                     | Cron Job                          |
|-------------|-------------------------------|-----------------------------------|
| **Session** | Main (shared context)         | Main or Isolated                  |
| **Timing**  | Regular interval (default 30m)| Exact time / cron expression      |
| **Context** | Full conversation history     | Fresh per run (isolated)          |
| **Batching**| Multiple checks in one turn   | One task per job                  |
| **Best For**| Reactive monitoring           | Proactive, time-specific tasks    |

**Rule of Thumb:** Heartbeats are for "checking if anything needs attention"; Cron jobs are for "doing a specific thing at a specific time".

---

## 6. Troubleshooting & Best Practices

### Common Issues

- **Nothing runs:** Ensure `cron.enabled: true` in config and the Gateway is running continuously.
- **Job Delaying:** Failed jobs use exponential backoff (30s, 1m, 5m, 15m, 60m) until success.
- **Silent Main Jobs:** Main session jobs require heartbeats to be enabled.

### Best Practices

1. **Set Timezones Explicitly:** Use `--tz` instead of relying on host detection.
2. **Cost Control:** Use cheaper models for simple tasks and `--model opus` for deep analysis.
3. **Clean Chat:** Use **Isolated Sessions** for frequent or noisy tasks to avoid cluttering the main conversation.
4. **Reliability:** Prefer the **CLI** (`openclaw cron add`) over chat-created jobs for better reliability.
5. **Persistence:** Jobs are stored at `~/.openclaw/cron/jobs.json`.

---

## 7. JSON API Tool Call Shapes

When an agent creates or updates jobs via the Gateway API, it uses these specific JSON structures:

**One-Shot (Main Session):**

```json
{
  "name": "Reminder",
  "schedule": {
    "kind": "at",
    "at": "2026-02-01T16:00:00Z"
  },
  "sessionTarget": "main",
  "wakeMode": "now",
  "payload": {
    "kind": "systemEvent",
    "text": "Reminder text"
  },
  "deleteAfterRun": true
}
```

**Recurring (Isolated Session):**

```json
{
  "name": "Morning brief",
  "schedule": {
    "kind": "cron",
    "expr": "0 7 * * *",
    "tz": "America/Los_Angeles"
  },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Summarize updates."
  },
  "delivery": {
    "mode": "announce",
    "channel": "slack"
  }
}
```

---

## 8. Configuration & Storage Paths

- **Job Persistence:** `~/.openclaw/cron/jobs.json`
- **Run History:** `~/.openclaw/cron/runs/`
- **Gateway Config:** Set `cron.enabled: true` and `maxConcurrentRuns` (default 1)
- **Environment Override:** Use `OPENCLAW_SKIP_CRON=1` to disable all jobs via environment variables

---

## 9. Error Recovery (Backoff Logic)

OpenClaw uses a specific retry sequence if a job fails:

- **Sequence:** 30s → 1m → 5m → 15m → 60m
- **Reset:** Backoff resets only after the next successful run
- **One-Shot Exception:** One-shot jobs do **not** retry; they simply disable upon failure

---

## 10. Full API Method List

The Gateway exposes the following methods for programmatic control:

- `cron.list`
- `cron.add`
- `cron.update`
- `cron.remove`
- `cron.run` (Immediate force-run)
- `cron.runs` (History)
- `cron.status`

This combined with the previous sections constitutes the **entire** content of the manual.
```

Copy-paste this block directly — it should render cleanly with no extra trailing spaces or blank lines.
