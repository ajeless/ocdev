#!/usr/bin/env bash
# install-openclaw.sh
# Non-interactive OpenClaw install for Debian 13 (trixie)
# Verified: 2026-03-06 | OpenClaw 2026.3.2
#
# Usage:
#   ANTHROPIC_API_KEY=sk-ant-... bash install-openclaw.sh
#
# Or set the key interactively (prompted if not in env):
#   bash install-openclaw.sh

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
OPENCLAW_MODEL="${OPENCLAW_MODEL:-anthropic/claude-sonnet-4-6}"
OPENCLAW_USER="${OPENCLAW_USER:-$(whoami)}"
NPM_GLOBAL_BIN="/home/${OPENCLAW_USER}/.npm-global/bin"
OPENCLAW_BIN="${NPM_GLOBAL_BIN}/openclaw"

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*"; exit 1; }

# ─── API Key ──────────────────────────────────────────────────────────────────
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  read -rsp "Anthropic API key (input hidden): " ANTHROPIC_API_KEY
  echo
fi

[[ -z "$ANTHROPIC_API_KEY" ]] && error "ANTHROPIC_API_KEY is required."

# ─── Step 1: Install OpenClaw ─────────────────────────────────────────────────
info "Installing OpenClaw..."
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt

# ─── Step 2: Load PATH for this session ───────────────────────────────────────
info "Loading PATH..."
export PATH="${NPM_GLOBAL_BIN}:$PATH"

[[ -x "$OPENCLAW_BIN" ]] || error "openclaw not found at $OPENCLAW_BIN after install."
info "OpenClaw version: $("$OPENCLAW_BIN" --version)"

# ─── Step 3: Fix PATH system-wide ─────────────────────────────────────────────
info "Adding openclaw to /etc/environment..."
if ! grep -q "\.npm-global/bin" /etc/environment 2>/dev/null; then
  echo "PATH=\"${NPM_GLOBAL_BIN}:\$PATH\"" | sudo tee -a /etc/environment > /dev/null
  info "Added to /etc/environment."
else
  warn "Already present in /etc/environment, skipping."
fi

# ─── Step 4: Gateway mode ─────────────────────────────────────────────────────
info "Setting gateway.mode to local..."
"$OPENCLAW_BIN" config set gateway.mode local

# ─── Step 5: Tools profile ────────────────────────────────────────────────────
info "Setting tools.profile to full..."
"$OPENCLAW_BIN" config set tools.profile full

# ─── Step 6: Exec allowlist ───────────────────────────────────────────────────
info "Adding exec allowlist..."
"$OPENCLAW_BIN" approvals allowlist add "**"

# ─── Step 7: Default model ────────────────────────────────────────────────────
info "Setting default model to ${OPENCLAW_MODEL}..."
"$OPENCLAW_BIN" config set agents.defaults.model "$OPENCLAW_MODEL"

# ─── Step 8: Write API key ────────────────────────────────────────────────────
info "Writing auth-profiles.json..."
mkdir -p "/home/${OPENCLAW_USER}/.openclaw/agents/main/agent"
cat > "/home/${OPENCLAW_USER}/.openclaw/agents/main/agent/auth-profiles.json" << EOF
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "${ANTHROPIC_API_KEY}"
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

# ─── Step 9: Doctor --repair ──────────────────────────────────────────────────
info "Running openclaw doctor --repair..."
"$OPENCLAW_BIN" doctor --repair || warn "Doctor reported issues — check output above."

# ─── Step 10: Start gateway ───────────────────────────────────────────────────
info "Starting OpenClaw gateway..."
"$OPENCLAW_BIN" gateway start || "$OPENCLAW_BIN" gateway restart

# ─── Step 11: Verify ──────────────────────────────────────────────────────────
info "Verifying..."
sleep 3
"$OPENCLAW_BIN" gateway status

echo ""
info "Dashboard URL:"
"$OPENCLAW_BIN" dashboard --no-open

echo ""
info "Install complete. Open the dashboard URL in a browser to connect."