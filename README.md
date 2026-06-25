# Bifrost with OpenCode

A local AI development stack that unifies multiple LLM providers behind a single gateway — optimized for [OpenCode](https://opencode.ai/) (or any OpenAI-compatible client).

```
OpenCode  →  Headroom  →  Bifrost  →  OpenAI / Google Gemini / GitHub Copilot
                                      →  AWS Bedrock
                                      →  Anthropic (via opencode-with-claude plugin)

Graphify  →  knowledge graph of your codebase  →  queryable by any AI assistant
```

**Why this exists:** AI coding assistants are rapidly becoming the primary interface to a codebase, but every agent has different provider requirements, API keys sprawl across projects, and observability is nonexistent. This repo centralises everything — one config, one `docker compose up`, one telemetry pipeline — so your AI setup is reproducible, auditable, and dead simple to onboard.

**Everything lives in this repo.** There are no global agent configs, no globally installed skills, no external setup scripts to run on every machine. Clone it, `just setup`, and you have a fully self-contained AI development environment — providers, agents, skills, prompts, observability, and policies — all tracked in version control.

---

## Motivation

AI agent tooling is evolving fast, but the plumbing around it is fragmented:

- **API key sprawl** — every project (OpenCode, Claude Code, Cline, Continue, etc.) needs its own set of provider keys
- **Provider routing** — Anthropic requires OAuth on desktop, OpenAI uses API keys, Bedrock needs AWS creds — each with different client libraries and auth flows
- **No SDD/TDD discipline** — AI agents happily generate code but rarely follow a spec-first, test-first workflow without explicit scaffolding
- **No observability** — prompt/response telemetry, cost tracking, and latency profiling are bolted on after the fact (if at all)
- **Context budgets** — large context windows are expensive; compression is rarely built in
- **Reproducibility** — AI setups are tribal knowledge, not code

This repo solves all of that by providing a **local, Docker Compose-based AI gateway stack** with a full **Spec-Driven Development (SDD) + TDD** workflow — all contained in-repo, nothing installed globally.

---

## Architecture

The request path through the stack:

```
┌─────────────┐     ┌──────────────┐     ┌──────────┐
│  OpenCode   │────▶│   Headroom   │────▶│  Bifrost │
│  (or any    │     │  Context     │     │  Gateway │
│  OpenAI-    │     │  Compression │     │  Router  │
│  compatible │     │  Proxy       │     │          │
│  client)    │     └──────────────┘     └────┬─────┘
└─────────────┘                               │
                                              │
                    ┌─────────────────────────┼──────────────────┐
                    │
                    ▼
              ┌──────────┐
              │  OpenAI  │
              │  Gemini  │
              │  GitHub  │
              │  Copilot │
              │  AWS     │
              │  Bedrock │
              └──────────┘

(Anthropic is accessed directly by OpenCode via the opencode-with-claude plugin — not routed through Bifrost)

┌──────────┐
│ OpenTelemetry + ClickHouse
│ (traces, metrics, logs)
└──────────┘
```

### Services

| Service | Role | Port |
|---|---|---|
| **Bifrost** | AI gateway — routes requests to any provider (OpenAI, Anthropic, Gemini, Bedrock, GitHub Copilot) | `8080` |
| **Headroom** | Context compression proxy — sits between your client and Bifrost, compresses LLM traffic | `8787` |

| **OpenTelemetry Collector** | Receives OTLP traces/metrics/logs from Bifrost and exports them to ClickHouse | `4317`, `4318` |
| **ClickHouse** | Columnar telemetry database — stores all AI interaction traces, metrics, and logs | `8123`, `9000` |
| **Graphify** | Knowledge graph — maps code, docs, and assets into a queryable graph for AI assistants | local (uv tool) |

---

## Providers

Configured in [`bifrost/config.json`](bifrost/config.json). Each provider reads its API key from the corresponding environment variable:

| Provider | Auth Method | Env Variable |
|---|---|---|
| **OpenAI** | API key | `OPENAI_API_KEY` |
| **Google Gemini** | API key | `GEMINI_API_KEY` |
| **GitHub Copilot** | Fine-grained PAT | `GITHUB_API_KEY` |
| **AWS Bedrock** | IAM credentials | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` |
| **Anthropic** (via opencode-with-claude plugin) | OAuth session via `claude login` | `ANTHROPIC_API_KEY` |

Anthropic is accessed through the `opencode-with-claude` plugin, which routes directly to Anthropic's API using your Claude Max/Pro OAuth session. See the plugin's README for setup details.

---

## Getting Started

A step-by-step walkthrough from zero to a fully running AI development environment.

### 0. Prerequisites

| Tool | Required? | Install |
|---|---|---|
| [Docker](https://docker.com) | **Yes** — runs the gateway stack | `brew install docker` (macOS) or [docker.com](https://docker.com) |
| [just](https://github.com/casey/just) | **Yes** — command runner | `brew install just` |
| [OpenCode](https://opencode.ai/) | For the AI agent workspace | `brew install opencode` or [opencode.ai](https://opencode.ai) |
| Node.js 18+ | For skills CLI + plugins | `brew install node` |
| [uv](https://docs.astral.sh/uv/) | For Graphify (Python tool runner) | `brew install uv` or `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) | For SDD workflow (optional) | `brew install gentle-ai` or `just gentle-ai-install` |

### 1. Clone and Configure

```bash
git clone <repo-url> && cd bifrost-with-opencode

# Copy environment templates (one per scope — secrets stay local)
cp .env.example .env
cp bifrost/.env.example bifrost/.env
# (meridian directory was removed — Anthropic is handled by the opencode-with-claude plugin)
cp opentelemetry/.env.example opentelemetry/.env
```

### 2. Add Your API Keys

Edit `bifrost/.env` and fill in at least one provider key:

```bash
OPENAI_API_KEY=sk-...           # OpenAI
GEMINI_API_KEY=...               # Google Gemini
GITHUB_API_KEY=github_pat_...    # GitHub Copilot (fine-grained PAT)
AWS_ACCESS_KEY_ID=...            # AWS Bedrock (optional — needs region too)
```

Don't touch `.opencode/opencode.json` — it's already wired to route through Bifrost.

Bifrost will auto-discover which providers have keys and route to the first available one. No config file edits needed.

### 3. Start the Stack

```bash
just up
```

This launches all services via `docker compose`:

| Service | Ready when |
|---|---|
| Bifrost | `http://localhost:8080/health` returns 200 |
| Headroom | `http://localhost:8787/health` returns 200 |

| ClickHouse | Port `8123` responds |
| OpenTelemetry | Ports `4317`/`4318` accept traffic |

First startup pulls images — grab a coffee. Subsequent starts are instant.

### 4. Verify the Gateway

```bash
# Send a test request — routes to the first configured provider
just test

# Test a specific provider/model
just test model="openai/gpt-4o-mini"
just test model="gemini/gemini-2.0-flash"
just test model="github-copilot/gpt-4o"

# List all available models across all providers
just discover-models
```

### 5. Install OpenCode Dependencies

The `opencode-with-claude` plugin and other OpenCode dependencies are declared in `.opencode/package.json`:

```bash
just opencode-deps
```

This installs everything locally — no global npm packages needed.

### 6. Launch OpenCode

OpenCode is already pre-configured in `.opencode/opencode.json` to point at `http://localhost:8080/openai` — the Bifrost OpenAI-compatible endpoint. No setup needed.

```bash
just opencode
```

Inside OpenCode, the stack of installed skills and SDD agents is available immediately. Run `/` to see available slash commands.

### 7. (Optional) Install Agent Skills

The repo uses `npx skills` to install AI agent behaviours locally (not globally):

```bash
# Install the superpowers skill suite
just skill-add obra/superpowers

# Lock current capabilities into version control
just skil-lock-lock

# List installed skills
just skill-list
```

All skills land in `.agents/skills/` — committed to the repo, visible in PRs.

### 8. (Optional) Enable Spec-Driven Development

For structured spec-first development with gentle-ai:

```bash
# Install gentle-ai (one-time)
just gentle-ai-install

# Configure workspace-scoped SDD
just gentle-ai-setup

# Create an SDD profile with per-phase models
just gentle-ai-profile name="default" design="gpt-4o" implement="gpt-4o-mini"
```

Then in OpenCode, run `/sdd-init` to start your first SDD change.

### What's Next?

| You want to... | Run this |
|---|---|
| Check all services are healthy | `just check` |
| Open the Bifrost dashboard | `just ui` |
| Watch real-time logs | `just logs` |
| See AI interaction traces | `just traces` |
| Use Headroom compression | Point your client at `http://localhost:8787/v1` |
| Tear everything down | `just down` (keeps volumes) or `just reset` (full cleanup) |
| Use Anthropic models | Install and enable `opencode-with-claude` plugin (already configured) |
| Use Anthropic directly (no Bifrost) | Add Anthropic provider in OpenCode via `opencode-with-claude` plugin — see Step 5 |

---

## Per-Scope Configuration

Each service has its own `.env` file with a corresponding `.env.example`:

| Scope | File | What it controls |
|---|---|---|
| **Root** | [`.env`](.env.example) | Shared defaults: Bifrost UI auth, ClickHouse, Headroom, provider key references |
| **Bifrost** | [`bifrost/.env`](bifrost/.env.example) | Provider API keys (OpenAI, Gemini, GitHub Copilot, AWS Bedrock) |
| **OpenTelemetry** | [`opentelemetry/.env`](opentelemetry/.env.example) | OTLP endpoints, ClickHouse connection, batch tuning, memory limits |

This separation means you can commit `.env.example` templates for each service without exposing secrets. The root `.env` holds shared defaults; service-specific `.env` files hold credentials and tuning.

---

## Command Reference (`just`)

The [`justfile`](justfile) imports modular recipes from [`just/`](just/):

### Docker Lifecycle
```bash
just up       # Start all services
just down     # Stop (keep volumes)
just reset    # Full teardown (removes volumes)
just ps       # Container status
just logs     # Tail logs (default: bifrost)
```

### Bifrost
```bash
just test                   # Send a test chat completion
just refresh                 # Rebuild Bifrost with fresh config
just discover-models         # List all models from all providers
just discover-models model="github-copilot/gpt-4o-mini"  # Set default model
```

### Headroom (Context compression)
```bash
just headroom-health        # Ping the proxy
just headroom-stats         # Compression stats
just headroom-test          # Test chat through compressed proxy
```

### Observability
```bash
just traces           # Recent AI interaction traces
just traces-count     # Total stored traces
just schema           # Show telemetry tables in ClickHouse
```

### Gentle-AI (SDD)
```bash
just gentle-ai-install        # Install gentle-ai via Homebrew
just gentle-ai-setup           # Configure for this project (workspace-scoped)
just gentle-ai-sdd-init        # Initialize SDD context
just gentle-ai-doctor          # Health check the ecosystem
just gentle-ai-profile         # Create SDD profile with per-phase models
```

### OpenCode
```bash
just opencode-deps             # Install .opencode npm deps (opencode-with-claude plugin, etc.)
just opencode                  # Launch OpenCode (starts stack first)
```

### Graphify (Knowledge Graph)
```bash
just graphify-install          # Install graphify via uv (one-time)
just graphify-setup            # Register skill with OpenCode + install always-on instructions
just graphify-build            # Build knowledge graph for this project
just graphify-update           # Re-extract only changed files (fast incremental rebuild)
just graphify-query query="…"  # Query the graph in natural language
just graphify-explain node="…" # Explain a specific node/concept
just graphify-path from="…" to="…"  # Shortest path between two nodes
just graphify-ui               # Open interactive graph visualization in browser
just graphify-hook             # Auto-rebuild graph on every git commit (AST, no API cost)
just graphify-upgrade          # Upgrade to latest version + refresh skill
```

### Diagnostics
```bash
just check            # Health check all services
just ui               # Open Bifrost dashboard
```

---

## Skills Management

The repo uses [`npx skills`](https://code.claude.com/docs/en/skills) (the Agent Skills CLI) to install and manage AI agent behaviours, and [`skil-lock`](https://github.com/skills-lock/skil-lock) to version-control their capabilities.

All skills are installed to `.agents/skills/` — **not globally**. The entire skill ecosystem is self-contained in the repo: install, lock, and validate without touching `~/.claude/skills/` or any other global location.

```bash
# Install skills from a source
just skill-add obra/superpowers

# List installed
just skill-list

# Lock current capabilities (scans .agents/skills/, generates skills.lock)
just skil-lock-lock

# CI check — verify installed skills match the lockfile
just skil-lock-ci
```

The [`.skil-lock.yaml`](.skil-lock.yaml) policy file controls what locked skills are allowed to do:
- **`mode: warn`** — violations are warnings, not blocks
- **`shell_commands` require approval** — no skill runs arbitrary shell commands without a prompt
- **`protected_paths`** — `.env`, `.pem`, `secrets/`, `.key` are off-limits

Results are tracked in two files:

| File | Purpose |
|---|---|
| [`skills-lock.json`](skills-lock.json) | Skill registry — source, version, hash for every installed skill |
| [`skills.lock`](skills.lock) | Generated capability manifest — per-skill `shell_commands`, `network_urls`, `file_reads`, `file_writes`, tool usage, and bundled script hashes |

The lockfile is **committed to the repo** — PR reviewers see capability deltas inline when skills change.

---

## Skills

Installed under `.agents/skills/` from `obra/superpowers`, `mattpocock/skills`, and `dietrichgebert/ponytail`:

| Skill | Source | Purpose |
|---|---|---|
| `brainstorming` | obra/superpowers | Creative work — explores intent, requirements, design before implementing |
| `dispatching-parallel-agents` | obra/superpowers | Fan out independent tasks to parallel sub-agents |
| `executing-plans` | obra/superpowers | Execute written plans in isolated sessions with review checkpoints |
| `finishing-a-development-branch` | obra/superpowers | Guide completion — merge, PR, or cleanup |
| `grill-me` | mattpocock/skills | Stress-test plans and designs through relentless questioning |
| `ponytail` | dietrichgebert/ponytail | Force the laziest working solution — YAGNI, stdlib first, no over-engineering |
| `receiving-code-review` | obra/superpowers | Handle review feedback with technical rigor, not performative agreement |
| `requesting-code-review` | obra/superpowers | Verify work meets requirements before merging |
| `subagent-driven-development` | obra/superpowers | Execute implementation plans via independent sub-agents |
| `systematic-debugging` | obra/superpowers | Root-cause-first debugging protocol |
| `test-driven-development` | obra/superpowers | Write tests before implementation code |
| `using-git-worktrees` | obra/superpowers | Isolate feature work in separate workspaces |
| `using-superpowers` | obra/superpowers | Meta-skill for finding and loading skills |
| `verification-before-completion` | obra/superpowers | Run verification commands before claiming work is done |
| `writing-plans` | obra/superpowers | Create multi-step implementation plans |
| `writing-skills` | obra/superpowers | Create, edit, and verify AI agent skills |

---

## Project Layout

```
.
├── .agents/                 # Local agent skills (ponytail, grill-me, etc.)
│   └── skills/              #    Skill definitions (SKILL.md per skill)
├── .opencode/               # ★ Single config directory — everything OpenCode needs
│   ├── opencode.json        #    Provider, agents, permissions, MCP servers, TUI
│   ├── tui.json             #    Terminal UI config
│   ├── commands/            #    SDD slash commands (sdd-new, sdd-ff, ...)
│   ├── plugins/             #    OpenCode plugins (model-variants, skill-registry)
│   ├── prompts/sdd/         #    SDD phase prompts (init → archive)
│   └── skills/              #    SDD skill implementations
├── AGENTS.md                # AI agent persona + Engram protocol
├── .sisyphus/               # Sisyphus orchestrator runtime & plans
├── .weave/                  # Weave runtime
├── .atl/                    # Local AI runtime state
├── bifrost/
│   ├── .env.example         # Provider API key template
│   ├── config.json          # Gateway routing, auth, provider config
│   └── discover-models.py   # Auto-discover models from all providers
├── clickhouse/
│   └── init.sql             # Database bootstrap (CREATE DATABASE otel)
├── just/
│   ├── docker.just          # Docker compose lifecycle
│   ├── bifrost.just         # Gateway commands, model discovery, testing
│   ├── headroom.just        # Context compression proxy
│   ├── otel.just            # OpenTelemetry + ClickHouse queries
│   ├── opencode.just        # OpenCode + Gentle-AI SDD setup
│   ├── skills.just          # npx skills + skil-lock management
│   └── diagnostics.just     # Health checks, UI shortcuts
├── opentelemetry/
│   ├── .env.example         # OTLP receiver, ClickHouse export, batch tuning
│   └── otel-collector-config.yaml
├── agent/                   # Alternative agent workspace (skills, etc.)
├── docker-compose.yaml      # All services in one compose file
├── justfile                 # Entry point, imports just/*.just
├── .env.example             # Root shared defaults
├── .skil-lock.yaml          # Skill behaviour policy (mode, protections)
├── skills-lock.json         # Skill registry (source, version, hash per skill)
└── skills.lock              # Generated capability manifest (per-skill actions)
```

---

## Connecting Other Clients

Any OpenAI-compatible client can use the stack by pointing at:

```
http://localhost:8080/v1   # Bifrost (direct)
http://localhost:8787/v1   # Headroom (compressed)
```

For OpenCode, the provider is already configured in `.opencode/opencode.json`:

```json
{
  "provider": {
    "openai": {
      "name": "Bifrost",
      "options": {
        "baseURL": "http://localhost:8080/openai",
        "apiKey": "dummy"
      }
    }
  }
}
```

For the Bifrost CLI (`bifrost`), copy the example configs:

```bash
cp bifrost/bifrost-cli-config.example.json bifrost-cli-config.json
cp bifrost/bifrost-cli-state.example.json bifrost-cli-state.json
```

---

## Telemetry

Every AI interaction is traced through OpenTelemetry:

1. Bifrost emits OTLP traces/metrics/logs via its `otel` plugin
2. The OpenTelemetry Collector receives them (gRPC on `4317`, HTTP on `4318`)
3. Data is exported to ClickHouse for durable storage (72h TTL)
4. Query traces directly:

```bash
just traces          # Last 10 traces
just traces-count    # Total trace count
just schema          # List telemetry tables
```

---

## Gentle-AI: Spec-Driven Development

Beyond the gateway stack, this repo comes with a full **Spec-Driven Development (SDD)** lifecycle powered by [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai).

SDD is a structured, multi-phase workflow that disciplines AI agents into producing verified, spec-aligned code:

```
sdd-init  →  sdd-explore  →  sdd-propose  →  sdd-design
→  sdd-spec  →  sdd-tasks  →  sdd-apply  →  sdd-verify
→  sdd-archive
```

Each phase is implemented as an OpenCode sub-agent defined in [`.opencode/opencode.json`](.opencode/opencode.json):

| Phase | Agent | What it does |
|---|---|---|
| **sdd-init** | `sdd-init` | Bootstrap SDD context and project configuration |
| **sdd-explore** | `sdd-explore` | Investigate codebase, think through ideas |
| **sdd-propose** | `sdd-propose` | Create change proposals from explorations |
| **sdd-design** | `sdd-design` | Write technical design from proposals |
| **sdd-spec** | `sdd-spec` | Write detailed specifications from designs |
| **sdd-tasks** | `sdd-tasks` | Break specs into atomic implementation tasks |
| **sdd-apply** | `sdd-apply` | Implement code changes from task definitions |
| **sdd-verify** | `sdd-verify` | Validate implementation against specs |
| **sdd-archive** | `sdd-archive` | Archive completed change artifacts |

Phase prompts live in [`.opencode/prompts/sdd/`](.opencode/prompts/sdd/) and are read by the agents via file-reference pointers in the agent config. This means the SDD workflow is **self-contained in the repo** — no global skill registry entries, no external prompt dependencies.

SDD is paired with **strict TDD** enforcement: the `sdd-apply` phase runs tests before writing implementation code, and the `sdd-verify` phase validates behaviour against the spec, not just test coverage.

The orchestrator agent (`gentle-orchestrator` in `.opencode/opencode.json`) coordinates the SDD pipeline — it delegates each phase to the appropriate sub-agent, maintains a thin conversation thread, and never does inline work itself.

```bash
# Install gentle-ai (one-time)
just gentle-ai-install

# Set up for this project (workspace-scoped)
just gentle-ai-setup

# Initialize SDD context — then inside OpenCode, run: /sdd-init
just gentle-ai-sdd-init

# Create an SDD profile with per-phase models
just gentle-ai-profile name="default" design="gpt-4o" implement="gpt-4o-mini"
```

---

## Graphify: Knowledge Graph for Your Codebase

[Graphify](https://github.com/safishamsi/graphify) turns your code, docs, SQL schemas, and any other assets into a queryable knowledge graph — giving AI assistants a structural map of the project instead of forcing them to grep through files.

Type `/graphify .` in OpenCode and get:

```
graphify-out/
├── graph.html       # interactive browser visualization — click nodes, filter, search
├── GRAPH_REPORT.md  # highlights: key concepts, surprising connections, suggested questions
└── graph.json       # full graph — query anytime without re-reading files
```

### Setup (one-time)

```bash
# Install the tool
just graphify-install

# Register the skill with OpenCode and install always-on graph instructions
just graphify-setup
```

### Build and Query

```bash
# Build the graph for this project
just graphify-build

# Incremental update (only changed files — fast)
just graphify-update

# Query in natural language
just graphify-query query="what connects Bifrost to the OpenTelemetry collector?"

# Open interactive visualization
just graphify-ui

# Auto-rebuild on every git commit (AST-only, no API cost)
just graphify-hook
```

### Current Graph (pre-built)

This repo ships with a pre-built graph. Current stats:

| Metric | Value |
|---|---|
| Nodes | 500 |
| Edges | 536 |
| Communities | 95 |
| Key god nodes | `agent`, `task`, `bash`, `read`, `edit` |

Notable communities detected: **Core Infrastructure Services** (Bifrost, Headroom, Meridian, OTel, ClickHouse), **SDD Pipeline Skills** (explore → propose → spec → design → tasks → apply → verify → archive), **OpenCode Config & Permissions**, **Multi-Platform AI Tool References**, **Engram Memory Service**, **Systematic Debugging Skills**.

Open `graphify-out/graph.html` in any browser for the interactive visualization, or query directly:

```bash
just graphify-query query="what connects Bifrost to the OpenTelemetry collector?"
just graphify-query query="how does the SDD pipeline flow from spec to apply?"
```

### Team Workflow

`graphify-out/` is committed to the repo so every team member starts with a map. Only local artifacts are excluded:

```
graphify-out/cost.json   ← local only (.gitignore'd)
graphify-out/cache/      ← optional, .gitignore'd to keep repo lean
```

One person runs `just graphify-build` and commits `graphify-out/`. Everyone else pulls and their AI assistant reads the graph immediately. Run `just graphify-hook` to keep it current after each commit.

---

## Everything Lives in This Repo

No global installations required beyond foundational tooling (Docker, just, Node.js):

| Component | Where it lives | Global? |
|---|---|---|
| Provider config | `bifrost/config.json` | No |
| OpenCode workspace | `.opencode/opencode.json` | No |
| Agent definitions + SDD prompts | `.opencode/opencode.json` + `.opencode/prompts/sdd/` | No |
| Agent skills | `.agents/skills/` | No |
| Skill lock/capabilities | `skills.lock`, `skills-lock.json`, `.skil-lock.yaml` | No |
| Docker compose | `docker-compose.yaml` | No |
| Just recipes | `justfile` + `just/*.just` | No |
| Per-scope env templates | `*/.env.example` | No |
| OpenCode plugin | `npm install -g opencode-with-claude` (one-time) | Yes (npm) |
| gentle-ai | `brew install gentle-ai` (one-time) | Yes (brew) |
| graphify | `uv tool install graphifyy` (one-time) | Yes (uv tool) |
| graphify skill + graph | `graphify-out/`, `.agents/skills/graphify/` | No |

The intent: **clone → copy env files → `just up`** and your entire AI development environment is ready. The only globally installed packages are the launchers themselves; all configuration, skills, prompts, and policies are repo-local and version-controlled.

---

## Verified Paths

Confirmed working on 2026-06-24 (Anthropic-only machine, no other provider keys):

| Path | Status | Notes |
|---|---|---|
| ClickHouse traces | ✅ | `just traces` and `just traces-count` work correctly |
| Prefix cache (Anthropic) | ✅ | 98.8% token cache hit rate observed |

**Caveats found:**
- Headroom compression does **not** trigger on short messages — minimum threshold is 500 tokens (`min_tokens_to_crush: 500` in Headroom config). Compression will activate automatically in real OpenCode sessions with larger context.
- `just test` uses `github-copilot/gpt-4o-mini` as default model — use `just test model="openai/gpt-4o-mini"` for specific models.

## TODO

- [ ] **Verify Headroom compaction (direct Anthropic, no Bifrost)** — confirm compression works when OpenCode talks to Anthropic directly via the `opencode-with-claude` plugin (bypassing Bifrost entirely). Requires a live OpenCode session with the plugin configured to proxy through `http://localhost:8787`. Check compression stats with `just headroom-stats` after a multi-turn conversation.
- [ ] **Full end-to-end smoke test** — fresh clone on a clean machine: follow the README from `git clone` through `just up` → `just check` → `just opencode` and confirm everything works with no undocumented steps.
- [ ] **Verify non-Anthropic providers** — OpenAI, Gemini, GitHub Copilot, and Bedrock paths are untested on this machine (no valid keys). Verify on a machine with full provider access using `just test model="openai/gpt-4o-mini"` etc.

---

## License

MIT
