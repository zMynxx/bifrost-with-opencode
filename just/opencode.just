# ── OpenCode + Claude + Gentle-AI ─────────────

# First-time setup: start stack + init bifrost-cli config
setup:
    just up
    echo "Initializing bifrost-cli config..."
    just init-cli
    echo ""
    echo "✅ Stack is up at http://localhost:8080"

# Install the opencode-with-claude plugin globally
claude-plugin-install:
    npm install -g opencode-with-claude
    echo "✅ opencode-with-claude plugin installed"

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
    echo "→ Launching OpenCode via bifrost-cli..."
    echo ""
    #PATH="$HOME/.bifrost/bin:$PATH" bifrost
    bifrost

# Init bifrost-cli user config (~/.bifrost/)
init-cli:
    mkdir -p ~/.bifrost
    cp -n bifrost/bifrost-cli-config.example.json ~/.bifrost/config.json 2>/dev/null && echo "Created ~/.bifrost/config.json" || echo "~/.bifrost/config.json already exists"
    cp -n bifrost/bifrost-cli-state.example.json ~/.bifrost/state.json 2>/dev/null && echo "Created ~/.bifrost/state.json" || echo "~/.bifrost/state.json already exists"
    echo "Config ready at ~/.bifrost/"

# ── Gentle-AI (Spec-Driven Development) ───────

# Install gentle-ai CLI via Homebrew
gentle-ai-install:
    brew tap Gentleman-Programming/homebrew-tap
    brew trust --formula gentleman-programming/tap/gentle-ai
    brew install gentle-ai

# Set up gentle-ai for this project (workspace-scoped so config stays local)
gentle-ai-setup:
    gentle-ai install --scope=workspace
    echo "✅ Gentle-AI configured for this project"
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
    gentle-ai sync --profile {{name}}:github-models/{{design}}
    gentle-ai sync --profile-phase {{name}}:sdd-design:github-models/{{design}}
    gentle-ai sync --profile-phase {{name}}:sdd-implement:github-models/{{implement}}
    gentle-ai sync --profile-phase {{name}}:sdd-explore:github-models/{{explore}}
    echo "✅ SDD profile '{{name}}' created with Bifrost models"
    echo "→ Press Tab in OpenCode to switch profiles"
