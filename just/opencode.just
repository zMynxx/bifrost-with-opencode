# ── OpenCode + Claude + Gentle-AI ─────────────

# First-time setup: start stack (config auto-seeded by discover-models.py on first run)
setup:
    just up
    echo ""
    echo "✅ Stack is up at http://localhost:8080"

# Install .opencode npm dependencies (opencode-with-claude plugin, etc.)
opencode-deps:
    npm --prefix .opencode install
    echo "✅ .opencode dependencies installed"

# Install the opencode-with-claude plugin (legacy — now declared in .opencode/package.json)
claude-plugin-install:
    just opencode-deps

# Authenticate with Claude Max (one-time OAuth login)
claude-login:
    npm install -g @anthropic-ai/claude-code
    claude login

# Check Claude authentication status
claude-status:
    claude auth status

# Start stack and launch OpenCode
opencode:
    just up
    echo "→ Stack is up"
    echo "→ Headroom proxy at http://localhost:8787 (compresses LLM traffic)"
    echo "→ Bifrost at http://localhost:8080"
    echo "→ Gentle-AI available (run 'just gentle-ai-doctor' to check)"
    echo ""
    opencode

# (obsolete — discover-models.py auto-seeds from example templates)

# ── Gentle-AI (Spec-Driven Development) ───────

# Install gentle-ai CLI via Homebrew
gentle-ai-install:
    brew tap Gentleman-Programming/homebrew-tap
    brew trust --formula gentleman-programming/tap/gentle-ai
    brew install gentle-ai

# Set up gentle-ai for this project (workspace-scoped so config stays local)
gentle-ai-setup:
    -gentle-ai install --scope=workspace --agent opencode --sdd-mode multi --channel stable
    python3 just/gentle-ai-fixup.py
    echo "✅ Gentle-AI configured for this project (agents merged into .opencode/opencode.json)"
    echo "→ Run 'just gentle-ai-sdd-init' to initialize SDD context"

# Initialize SDD context (detects stack, testing, activates Strict TDD Mode)
gentle-ai-sdd-init:
    @echo "Run this command inside your AI agent:"
    @echo "  /sdd-init"
    @echo ""
    @echo "Or from CLI: gentle-ai skill-registry refresh"

# Refresh the skill registry (after installing/removing skills)
gentle-ai-skill-registry:
    gentle-ai skill-registry refresh

# Health check your gentle-ai ecosystem
gentle-ai-doctor:
    gentle-ai doctor

# Sync gentle-ai config and profiles
gentle-ai-sync profile="":
    gentle-ai sync {{profile}}

# Create an OpenCode SDD profile with per-phase models via Bifrost
# Usage: just gentle-ai-profile name="default" design="gpt-4o" implement="gpt-4o-mini" explore="gpt-4o-mini"
gentle-ai-profile name="default" design="gpt-4o" implement="gpt-4o-mini" explore="gpt-4o-mini":
    gentle-ai sync --profile {{name}}:github-copilot/{{design}}
    gentle-ai sync --profile-phase {{name}}:sdd-design:github-copilot/{{design}}
    gentle-ai sync --profile-phase {{name}}:sdd-implement:github-copilot/{{implement}}
    gentle-ai sync --profile-phase {{name}}:sdd-explore:github-copilot/{{explore}}
    echo "✅ SDD profile '{{name}}' created with Bifrost models"
    echo "→ Press Tab in OpenCode to switch profiles"
