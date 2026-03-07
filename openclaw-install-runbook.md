# OpenClaw Install Runbook
## Debian 13 (trixie) — Headless / Non-Interactive

Verified: 2026-03-06 | OpenClaw 2026.3.2 | ocdev01 + ocdev02 (clean clone)

---

## Complete Non-Interactive Install (copy-paste ready)

```bash
# 1. Install OpenClaw (no wizard, no prompts)
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt

# 2. Load PATH for current session (installer adds to .bashrc but doesn't reload)
source ~/.bashrc

# 3. Fix PATH system-wide (prevents PATH dropping in new terminals)
echo 'PATH="/home/ocdev/.npm-global/bin:$PATH"' | sudo tee -a /etc/environment

# 4. Set gateway mode (required — gateway won't start without this)
openclaw config set gateway.mode local

# 5. Set tools profile to full (default is "messaging" — exec/file tools disabled)
openclaw config set tools.profile full

# 6. Add exec allowlist
openclaw approvals allowlist add "**"

# 7. Set default model
openclaw config set agents.defaults.model anthropic/claude-sonnet-4-6

# 8. Write API key (do not paste key into termbin or chat)
mkdir -p ~/.openclaw/agents/main/agent
cat > ~/.openclaw/agents/main/agent/auth-profiles.json << 'EOF'
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "YOUR_API_KEY_HERE"
    }
  },
  "usageStats": {
    "anthropic:default": {
      "errorCount": 0,
      "lastUsed": 0
    }
  }
}
EOF

# 9. Run doctor to fix service + state issues
openclaw doctor --repair

# 10. Start gateway
openclaw gateway start

# 11. Verify
openclaw gateway status
openclaw dashboard --no-open
```

---

## Step-by-Step Breakdown

### Step 1 — Install OpenClaw

```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt
```

**What it does:**
- Installs Node.js v22 via NodeSource if not present
- Installs OpenClaw via npm to `~/.npm-global`
- Adds `~/.npm-global/bin` to `~/.bashrc`
- Skips interactive wizard (`--no-onboard --no-prompt`)

**Known issue:** Installer shows a PATH warning even though it adds the line to `.bashrc`. Warning is a false alarm — the line is written, just not loaded yet.

---

### Step 2 — Load PATH

```bash
source ~/.bashrc
```

The installer adds the PATH to `.bashrc` but the current terminal session doesn't pick it up automatically. Run this or open a new terminal.

---

### Step 3 — Fix PATH system-wide

```bash
echo 'PATH="/home/ocdev/.npm-global/bin:$PATH"' | sudo tee -a /etc/environment
```

Without this, `openclaw` drops from PATH every time you open a new terminal. `/etc/environment` is loaded by PAM for all sessions.

---

### Step 4 — Set gateway mode

```bash
openclaw config set gateway.mode local
```

**Critical.** Gateway will refuse to start without this set. Not configured by the headless install — only the interactive wizard sets it.

---

### Step 5 — Set tools profile

```bash
openclaw config set tools.profile full
```

Default is `"messaging"` — exec, file, and browser tools are all disabled. Must be set to `full` for the agent to run shell commands or read/write files.

---

### Step 6 — Add exec allowlist

```bash
openclaw approvals allowlist add "**"
```

Separate from tools profile — both are required. Allowlist controls which binaries can be executed.

---

### Step 7 — Set model

```bash
openclaw config set agents.defaults.model anthropic/claude-sonnet-4-6
```

---

### Step 8 — Write API key

The API key is **not** stored in the main config (`openclaw.json`). It lives in a separate file:

```
~/.openclaw/agents/main/agent/auth-profiles.json
```

Create it manually:

```bash
mkdir -p ~/.openclaw/agents/main/agent
cat > ~/.openclaw/agents/main/agent/auth-profiles.json << 'EOF'
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "YOUR_API_KEY_HERE"
    }
  },
  "usageStats": {
    "anthropic:default": {
      "errorCount": 0,
      "lastUsed": 0
    }
  }
}
EOF
```

**Watch out:** The `type` field must be `"api_key"` (underscore). Using `"api-key"` (hyphen) silently fails with a warning and the profile is ignored.

---

### Step 9 — Run doctor --repair

```bash
openclaw doctor --repair
```

This handles several things the headless install skips:
- Creates missing session store directories
- Installs the systemd user service
- Sets gateway token if missing
- Reports any remaining config issues

Run this **after** setting all config values — it overwrites some config on completion.

---

### Step 10 — Start gateway

```bash
openclaw gateway start
```

Or if already installed as a service:

```bash
openclaw gateway restart
```

---

### Step 11 — Verify

```bash
openclaw gateway status
```

Look for: `Runtime: running` and `RPC probe: ok`

Get dashboard URL:
```bash
openclaw dashboard --no-open
```

Open in browser — if you see "Health OK", the install is complete.

---

## Known Pain Points

| # | Issue | Fix |
|---|-------|-----|
| 1 | `tools.profile` defaults to `"messaging"` | `openclaw config set tools.profile full` |
| 2 | PATH not active in current session after install | `source ~/.bashrc` |
| 3 | PATH drops in new terminals | Add to `/etc/environment` |
| 4 | `gateway.mode` unset — gateway won't start | `openclaw config set gateway.mode local` |
| 5 | Exec allowlist separate from tools profile | Both required — `approvals allowlist add "**"` |
| 6 | API key not in main config — needs separate file | Write `auth-profiles.json` manually |
| 7 | `type: "api-key"` (hyphen) silently fails | Must be `"api_key"` (underscore) |
| 8 | `openclaw gateway install` fails on fresh headless install | Run `openclaw doctor --repair` instead |
| 9 | GitHub skill requires Homebrew on Linux | Pre-install `gh` via apt |
| 10 | `openclaw configure` wizard hangs in some TTY contexts | Use `--no-onboard --no-prompt` flags |
| 11 | Session store dir missing on headless install | `doctor --repair` creates it |
| 12 | PATH warning in installer output is a false alarm | Line is written to `.bashrc`; just source it |

---

## Environment

| Item | Value |
|------|-------|
| OS | Debian GNU/Linux 13.3 (trixie) |
| Hypervisor | KVM via virt-manager 4.1.0 |
| VM specs | 8 vCPU, 16GB RAM, qcow2, SPICE |
| OpenClaw | 2026.3.2 |
| Model | anthropic/claude-sonnet-4-6 |
| Verified | 2026-03-06 |