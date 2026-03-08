# OpenClaw Automation Strategy: Bootstrap + PyInfra

## Why this strategy fits your current repo

From the current repo state, your install work is already strong in three areas:

- A reproducible manual runbook with known edge cases (`openclaw-install-runbook.md`)
- A one-shot shell installer that codifies the runbook (`install-openclaw.sh`)
- Session notes that explicitly call out the need for idempotence, modularity, provider flexibility, and safer secret handling (`2026.03.07-16.55.md`)

Given that baseline, the best next step is **not** a total rewrite. It's a staged architecture:

1. Keep shell for first-boot bootstrap (works on a fresh VM with minimal assumptions)
2. Move ongoing configuration into PyInfra (idempotent, testable, host-aware)
3. Drive both from inventory/config files so each agent can differ by role

---

## Recommendation (short version)

Use a **hybrid model**:

- **`bootstrap.sh`** (very small shell script)
  - Ensures Python 3 + pipx (or uv) + git are present
  - Creates base directories and permissions (`~/.secrets`, config roots)
  - Installs/updates PyInfra runtime

- **PyInfra deploys** as source of truth
  - `deploy/hosts.py` and group data for host roles (`ocdev01`, `ocdev02`, etc.)
  - Operations for OpenClaw install/config
  - Optional modules for Docker/Tailscale/Ansible/Ollama

This gives you the zero-dependency reliability of shell plus the repeatability and composability you want for a fleet.

---

## Suggested repo layout

```text
ocdev/
├── bootstrap.sh
├── pyproject.toml
├── deploy/
│   ├── inventory.py
│   ├── deploy.py
│   ├── openclaw.py
│   └── modules/
│       ├── docker.py
│       ├── tailscale.py
│       ├── ansible.py
│       └── ollama.py
├── config/
│   ├── agents/
│   │   ├── ocdev01.yaml
│   │   └── ocdev02.yaml
│   └── schemas/
├── secrets.example.env
└── docs/
    └── migration-plan.md
```

---

## Migration plan (safe + incremental)

### Phase 1: Stabilize current shell script

Before moving to PyInfra, make `install-openclaw.sh` safer:

- Add `--non-interactive` mode that fails if key is absent (no prompt in CI)
- Avoid passing secrets on command line; load from `~/.secrets/openclaw.env`
- Add dry-run verification commands section
- Split into functions (`install_openclaw`, `configure_provider`, `verify_health`)

### Phase 2: Introduce PyInfra for read-only checks first

Implement a `deploy/checks.py` that only asserts state:

- `openclaw --version` present
- `gateway.mode == local`
- `tools.profile == full`
- auth profile file exists and permissions are strict

This gives confidence without changing machines yet.

### Phase 3: Move config writes into PyInfra

Port these from shell into PyInfra operations:

- config set commands
- auth file render
- doctor/repair trigger (guarded)
- service status checks

### Phase 4: Modularize services

Create optional deploy modules toggled by host data:

- `enable_docker`
- `enable_tailscale`
- `enable_ansible`
- `enable_ollama`

### Phase 5: Fleet workflows

Add CI validation for inventories and a single command per host:

```bash
pyinfra deploy/inventory.py deploy/deploy.py --limit ocdev01
```

---

## PyInfra design choices for your use case

1. **Use host/group data for role specialization**  
   Keep one deploy code path; vary behavior with inventory data.

2. **Keep secrets off-repo by default**  
   Read from environment or `~/.secrets/*.env`, fail hard if missing.

3. **Treat OpenClaw provider auth as strategy-specific logic**  
   Your session notes already show provider differences are real and easy to get wrong.

4. **Prefer idempotent file render + command guards**  
   Example: only run `doctor --repair` when required files/services are missing.

5. **Version your agent configs**  
   Add `config_version` and explicit migration notes as fields evolve.

---

## What to keep vs replace

- Keep: `openclaw-install-runbook.md` as canonical troubleshooting reference
- Keep: `install-openclaw.sh` as emergency fallback/bootstrap-only installer
- Add: PyInfra deploy layer for day-2 and fleet operations
- Eventually replace: one-shot shell as primary day-to-day method

---

## Immediate next actions (practical)

1. Add a tiny `bootstrap.sh` that installs PyInfra runtime only.
2. Create first PyInfra deploy that configures **just** OpenClaw core settings.
3. Move one optional module (Docker) into PyInfra to validate pattern.
4. Add a `make check` target to run lint + inventory validation.
5. Keep fallback path documented: “If PyInfra fails, run `install-openclaw.sh`.”

---

## Bottom line

Yes—PyInfra is a strong fit for what you're building. The best approach is **shell for bootstrap, PyInfra for state management**. That balances reliability on fresh rebuilds with the flexibility and idempotence you need for multi-agent growth.
