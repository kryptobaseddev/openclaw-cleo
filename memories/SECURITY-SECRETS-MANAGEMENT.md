# Security Memory: Secrets Management

**Memory ID**: SECURITY-001
**Created**: 2026-02-02
**Priority**: CRITICAL
**Category**: Security, Self-Improvement

---

## Incident Summary

On 2026-02-02, I (OpenClaw) inadvertently exposed the `ANTHROPIC_API_KEY` by running a command that dumped environment variables. The output was logged to my session file, creating a security vulnerability.

**Root Cause**: Executed `env` or similar command without filtering sensitive data from output.

**Impact**: API key exposed in session logs, required key rotation.

---

## CRITICAL RULES (MUST FOLLOW)

### 1. NEVER Output Environment Variables

```bash
# FORBIDDEN - These commands expose secrets
env
printenv
export
set | grep -i key
echo $ANTHROPIC_API_KEY
cat /proc/self/environ
```

**If you need to check environment**: Only check for PRESENCE, never VALUE:
```bash
# SAFE - Only checks existence
[ -n "$ANTHROPIC_API_KEY" ] && echo "API key is set" || echo "API key missing"
```

### 2. NEVER Log, Echo, or Display Secrets

- Never include secrets in command output
- Never write secrets to files (except designated secure storage)
- Never include secrets in error messages
- Never include secrets in tool results or responses

### 3. Doppler is the ONLY Secrets Source

All secrets are managed through **Doppler**:

| Secret | Purpose | Access Method |
|--------|---------|---------------|
| `ANTHROPIC_API_KEY` | Claude API access | Via Doppler injection only |
| `AGENTMAIL_API_KEY` | AgentMail API | Via Doppler injection only |
| `AGENTMAIL_EMAIL` | Agent email identity | Via Doppler injection only |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth | Via Doppler injection only |

**Doppler injects secrets at container startup**. Never query or display them.

### 4. Safe Patterns for Secret Operations

```bash
# SAFE: Check if Doppler is configured
doppler configure

# SAFE: List secret NAMES only (not values)
doppler secrets --only-names

# SAFE: Use secrets without displaying
doppler run -- <command>

# UNSAFE: This displays secret values!
doppler secrets  # Shows values - DON'T USE
```

### 5. If You Need to Verify API Access

```bash
# SAFE: Test API without showing key
curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-haiku-20240307","max_tokens":10,"messages":[{"role":"user","content":"test"}]}' \
  | jq '.type // .error.type'
# Returns "message" if working, error type if not
```

---

## Self-Improvement Protocol

When I make a security mistake:

1. **Immediately recognize** the exposure
2. **Report** to the user with full transparency
3. **Clean up** any exposed data (delete logs, etc.)
4. **Recommend remediation** (key rotation, etc.)
5. **Create a memory** (like this one) to prevent recurrence
6. **Update CLEO tasks** to track the fix

---

## Memory Triggers

Load this memory when:
- Running shell commands that might access environment
- Debugging authentication or API issues
- Working with configuration files
- Anytime "secret", "key", "token", "password", "credential" appears in context

---

## Related Resources

- Doppler Documentation: https://docs.doppler.com/
- CLEO Security Protocols: See CLEO skill documentation
- OpenClaw Security: https://docs.openclaw.ai/security

---

## Verification Checklist

Before executing any command, verify:

- [ ] Does this command output environment variables? **DON'T RUN**
- [ ] Does this command log sensitive data? **DON'T RUN**
- [ ] Am I checking secret VALUE vs PRESENCE? **Check presence only**
- [ ] Is there a safer alternative? **Use it**

---

*This memory was created as part of the self-improvement loop to prevent security incidents.*
