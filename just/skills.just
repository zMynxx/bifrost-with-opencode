# ── Skill Management (npx skills + skil-lock) ──

# ── npx skills (Agent Skills CLI) ─────────────────

# Add skills from a source (e.g. just skill-add obra/superpowers)
skill-add source="":
    npx skills add '{{source}}'

# Add all skills from a source to all agents (e.g. just skill-add-all obra/superpowers)
skill-add-all source="":
    npx skills add '{{source}}' --all

# List installed skills
skill-list:
    npx skills list

# List globally installed skills
skill-list-global:
    npx skills list -g

# Remove installed skills (interactive)
skill-remove:
    npx skills remove

# Update skills to latest versions
skill-update:
    npx skills update

# Search for skills (e.g. just skill-search typescript)
skill-search query="":
    npx skills find '{{query}}'

# ── skil-lock (Skill Behavior Lock) ──────────────

# Install skil-lock binary
skil-lock-install:
    #!/usr/bin/env bash
    set -euo pipefail
    OS=$(uname -s | tr A-Z a-z)
    ARCH=$(uname -m | sed s/x86_64/amd64/ | sed s/aarch64/arm64/)
    curl -sL "https://github.com/skills-lock/skil-lock/releases/download/v0.2.2/skil-lock_0.2.2_${OS}_${ARCH}.tar.gz" | tar -xz
    mkdir -p ~/.local/bin
    mv skil-lock ~/.local/bin/
    echo "✅ skil-lock v0.2.2 installed to ~/.local/bin/"
    echo "   Ensure ~/.local/bin is on your PATH"

# Regenerate skills.lock from .agents/skills/
skil-lock-lock:
    #!/usr/bin/env bash
    set -euo pipefail
    # skil-lock only scans .claude/skills/ and .codex/skills/, so we proxy
    cp -r .agents/skills .claude/skills
    skil-lock lock .
    just/fix-lockfile.py
    rm -rf .claude/skills
    echo "✅ skills.lock updated — $(grep -c 'runtime:' skills.lock) skills"

# Run skil-lock CI (check for drift against lockfile)
skil-lock-ci:
    skil-lock ci .

# List all skills with their capability surface
skil-lock-list:
    skil-lock list .

# Print JSON behavior report of all skills
skil-lock-scan:
    skil-lock scan .

# Full workflow: lock then CI check
skil-lock-sync:
    just skil-lock-lock
    just skil-lock-ci
