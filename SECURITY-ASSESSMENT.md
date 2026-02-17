# OpenClaw LXC Security Assessment

**Date**: 2026-02-16
**Target**: OpenClaw Gateway (CT 110, 10.0.10.20)
**Scope**: Docker deployment, configuration, network exposure, secrets management
**Type**: Assessment and documentation (no changes made)

---

## Security Baseline Score

**Overall: 4 / 10** (Needs Improvement)

| Category | Score | Notes |
|----------|-------|-------|
| Container isolation | 3/10 | No security_opt, cap_drop, or resource limits |
| Secrets management | 2/10 | Plaintext API keys in world-readable .env |
| Network exposure | 5/10 | Ports bound to 0.0.0.0, but LXC provides some isolation |
| User privileges | 7/10 | Container runs as non-root (node, uid 1000) |
| Exec security | 5/10 | Commands set to "auto" (no explicit approval required) |
| Trusted proxies | 6/10 | Reasonable scope but includes broad subnets |
| Skill surface area | 5/10 | All bundled skills present, large attack surface |

---

## Findings

### CRITICAL

#### C1: Plaintext API Keys in World-Readable .env File

**Location**: `/opt/openclaw/.env`
**Permissions**: `644` (world-readable)

The `.env` file contains plaintext API keys for multiple providers and is readable by any user on the LXC host:

- `ANTHROPIC_API_KEY` (sk-ant-api03-...)
- `OPENAI_API_KEY` (sk-proj-...)
- `MOONSHOT_API_KEY` (sk-...)
- `GOOGLE_API_KEY` (AIza...)
- `BRAVE_API_KEY`
- `AGENTMAIL_API_KEY`
- `GITHUB_PASSWORD` (plaintext)
- `TELEGRAM_BOT_TOKEN`
- `OPENCLAW_GATEWAY_TOKEN`

**Risk**: Any process or user on the LXC can read all API keys. A single compromise of the container host exposes every integrated service.

**Recommendation**:
1. Immediately restrict file permissions: `chmod 600 /opt/openclaw/.env`
2. Consider migrating to Docker secrets or a secrets manager (Doppler is already partially configured)
3. Rotate all exposed keys after restricting access

#### C2: Gateway Auth Token Duplicated in openclaw.json

**Location**: `/root/.openclaw/openclaw.json` -> `gateway.auth.token` and `gateway.remote.token`

The gateway authentication token (`a7a3d1...`) is present in the JSON config file in addition to the `.env` file. The `OPENCLAW_GATEWAY_TOKEN` in `.env` is a different value (`861bed...`), meaning two tokens may be valid simultaneously or one is stale.

**Risk**: Token confusion increases the attack surface. If the JSON-embedded token is not required, it is an unnecessary exposure.

**Recommendation**: Determine which token is authoritative, remove the other, ensure tokens are only stored in one location.

---

### HIGH

#### H1: No Docker Security Options Applied

**Finding**: The container has no security hardening applied:

| Setting | Current | Recommended |
|---------|---------|-------------|
| `security_opt` | null (none) | `no-new-privileges:true` |
| `cap_drop` | null (none) | `ALL` (then add back only needed) |
| `read_only` | false | true (with tmpfs for writable dirs) |
| `memory` limit | 0 (unlimited) | Set appropriate limit (e.g., 2G) |
| `cpu_quota` | 0 (unlimited) | Set appropriate limit |
| `pids_limit` | null (unlimited) | Set limit (e.g., 256) |

**Risk**: The container runs with full default Linux capabilities. A container escape or vulnerability in Node.js could be leveraged to escalate privileges on the host.

**Recommendation**: Add to `docker-compose.yml` under the gateway service:
```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE
deploy:
  resources:
    limits:
      memory: 2G
      cpus: '2.0'
      pids: 256
```

#### H2: Ports Bound to 0.0.0.0 (All Interfaces)

**Finding**: Both gateway ports are exposed on all interfaces:
- `18789/tcp -> 0.0.0.0:18789` (gateway API)
- `18790/tcp -> 0.0.0.0:18790` (bridge)

The Docker port bindings specify no HostIp restriction.

**Risk**: Any network-reachable host can attempt to connect to the gateway. While the LXC sits on a private subnet (10.0.10.0/24) and the gateway requires a token, binding to all interfaces is unnecessary.

**Recommendation**: Bind to the LXC IP only:
```yaml
ports:
  - "10.0.10.20:18789:18789"
  - "10.0.10.20:18790:18790"
```

#### H3: No INPUT Firewall Rules on LXC

**Finding**: The INPUT chain policy is ACCEPT with no rules. All inbound traffic to any port is accepted.

**Risk**: No defense in depth. If a service binds an unexpected port, it is immediately accessible.

**Recommendation**: Add iptables rules to restrict inbound access:
```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -s 10.0.10.0/24 -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -s 10.0.10.0/24 -p tcp --dport 18789 -j ACCEPT
iptables -A INPUT -s 10.0.10.0/24 -p tcp --dport 18790 -j ACCEPT
iptables -A INPUT -j DROP
```

---

### MEDIUM

#### M1: Trusted Proxies Include Broad Subnets

**Finding**: `gateway.trustedProxies` in openclaw.json:
```json
["10.0.10.0/24", "127.0.0.1", "172.16.0.0/12", "10.0.10.8"]
```

**Risk**: `172.16.0.0/12` covers the entire Docker default range (172.16.0.0 - 172.31.255.255). While Docker bridge networks fall in this range, trusting the entire /12 is broader than necessary.

**Recommendation**: Narrow to the specific Docker bridge subnet:
```json
["10.0.10.0/24", "127.0.0.1", "172.18.0.0/16", "10.0.10.8"]
```
Or even better, determine the exact bridge subnet (`docker network inspect openclaw_default`) and use that CIDR.

#### M2: Command Execution Set to "auto" Mode

**Finding**: In openclaw.json:
```json
"commands": {
  "native": "auto",
  "nativeSkills": "auto"
}
```

**Risk**: "auto" mode allows the agent to execute commands and skills without explicit user approval. For a production deployment, this grants the AI agent unrestricted command execution.

**Recommendation**: For production hardening, consider setting to `"confirm"` or implementing an allowlist of permitted commands. Evaluate whether the agent genuinely needs unrestricted execution for its use case.

#### M3: Large Skill Surface Area

**Finding**: 50+ skills installed in `/opt/openclaw/skills/`, including:
- System interaction: `tmux`, `coding-agent`, `imsg`, `bluebubbles`
- External services: `slack`, `trello`, `notion`, `discord`, `spotify-player`
- Sensitive operations: `1password`, `github`, `clawhub`, `skill-creator`

Only the custom `cleo` skill is in `/root/.openclaw/skills/`. All others are bundled defaults.

**Risk**: Each skill is a potential attack vector. Skills like `1password`, `github`, and `coding-agent` could be abused if the agent is compromised or receives malicious instructions.

**Recommendation**: Disable unused skills. If skills like `1password`, `voice-call`, `slack` are not in active use, remove or disable them to reduce the attack surface.

#### M4: GitHub Credentials Are Username/Password (Not Token-Scoped)

**Finding**: `.env` contains both `GITHUB_PAT` and `GITHUB_PASSWORD`. The password field contains what appears to be a plaintext password rather than a scoped token.

**Risk**: A plaintext GitHub password grants full account access, unlike a PAT which can be scoped to specific permissions.

**Recommendation**: Use only fine-grained Personal Access Tokens with minimum required scopes. Remove the `GITHUB_PASSWORD` if not strictly required.

---

### LOW

#### L1: Container Restart Policy Could Mask Issues

**Finding**: `restart: unless-stopped` is configured.

**Risk**: If the container enters a crash loop due to a security event, it will restart automatically, potentially re-exposing a vulnerability and masking the incident.

**Recommendation**: Consider `restart: on-failure` with a `max-retries` limit, combined with monitoring/alerting on container restarts.

#### L2: No Health Check Defined

**Finding**: No `healthcheck` directive in docker-compose.yml.

**Risk**: Docker cannot distinguish between a healthy and unhealthy container. Compromised or hung processes will not be detected.

**Recommendation**: Add a health check:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:18789/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

#### L3: No Docker Logging Limits

**Finding**: No logging configuration in docker-compose.yml.

**Risk**: Unlimited logs could fill the disk, causing denial of service. Logs may also contain sensitive data without rotation.

**Recommendation**:
```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

---

## What's Already Good

1. **Non-root container user**: The gateway runs as `node` (uid 1000), not root. This is a strong baseline.
2. **Init process**: `init: true` is set, ensuring proper signal handling and zombie reaping.
3. **Dedicated Docker network**: Uses `openclaw_default` bridge network rather than host networking.
4. **Not privileged**: Container is not running in privileged mode (`Privileged: false`).
5. **Environment variable injection**: Secrets are passed via environment variables from `.env` rather than baked into the image. The pattern is correct, just the file permissions need tightening.
6. **Gateway token authentication**: The gateway requires a token for API access, preventing unauthenticated use.
7. **LXC isolation layer**: Running inside an LXC container provides an additional isolation boundary beyond Docker.
8. **Private subnet**: The LXC is on 10.0.10.0/24, not directly exposed to the internet.

---

## Recommended Action Priority

| Priority | Action | Effort |
|----------|--------|--------|
| 1 | Restrict `.env` permissions to 600 | small |
| 2 | Resolve gateway token duplication | small |
| 3 | Add `security_opt`, `cap_drop` to docker-compose | small |
| 4 | Bind ports to specific IP (10.0.10.20) | small |
| 5 | Add INPUT chain firewall rules | small |
| 6 | Narrow trustedProxies CIDR | small |
| 7 | Add resource limits (memory, CPU, pids) | small |
| 8 | Review and disable unused skills | medium |
| 9 | Replace GitHub password with scoped PAT | small |
| 10 | Evaluate command execution approval mode | medium |
| 11 | Add health check and logging limits | small |
| 12 | Migrate secrets to Doppler or Docker secrets | medium |
