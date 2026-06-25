# ─────────────────────────────────────────────────────
# Bifrost + OpenTelemetry + ClickHouse + Headroom
# ─────────────────────────────────────────────────────

# Use Podman socket (not Docker Desktop)
export DOCKER_HOST := "unix:///var/folders/8m/8m1bs90921dgjnrq48v931p80000gp/T/podman/podman-machine-default-api.sock"
export DOCKER_CONFIG := "/tmp"

# ── Modular Justfiles ────────────────────────────────
# Import recipes from submodules

import 'just/docker.just'
import 'just/bifrost.just'
import 'just/otel.just'
import 'just/headroom.just'
import 'just/opencode.just'
import 'just/diagnostics.just'
import 'just/skills.just'
import 'just/graphify.just'

# ── Default: Fuzzy Finder Selector ───────────────────

# List all available recipes (for fuzzy finder)
_default:
    @just --list --unsorted 2>/dev/null | \
      grep -v "^#" | \
      grep -v "^\s*$" | \
      sed 's/:.*//' | \
      sed 's/\s*#.*//' | \
      fzf --prompt="⚡ just " --height=40% --reverse --border --info=inline | \
      xargs -I {} just {}

# ── Aliases ──────────────────────────────────────────

alias d := down
alias u := up
alias l := logs
alias p := ps
alias t := test
alias s := setup
alias o := opencode
