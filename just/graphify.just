# ─────────────────────────────────────────────
# Graphify — Knowledge Graph for AI Assistants
# ─────────────────────────────────────────────

# Install graphify via uv (one-time)
graphify-install:
    uv tool install graphifyy
    @echo "graphify installed. Run 'just graphify-setup' to register the skill with OpenCode."

# Register the graphify skill with OpenCode (run once per project)
graphify-setup:
    graphify install --platform opencode --project
    graphify opencode install

# Build the knowledge graph for this project
graphify-build:
    graphify .

# Rebuild only changed files (faster after first build)
graphify-update:
    graphify . --update

# Query the knowledge graph
graphify-query query="":
    graphify query "{{query}}"

# Explain a specific node/concept
graphify-explain node="":
    graphify explain "{{node}}"

# Find the shortest path between two nodes
graphify-path from="" to="":
    graphify path "{{from}}" "{{to}}"

# Open the interactive graph visualization in the browser
graphify-ui:
    open graphify-out/graph.html

# Install git hook to auto-rebuild on commit (AST only, no API cost)
graphify-hook:
    graphify hook install

# Upgrade graphify to the latest version
graphify-upgrade:
    uv tool upgrade graphifyy
    graphify install --platform opencode --project
