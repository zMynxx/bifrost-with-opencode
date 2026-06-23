#!/usr/bin/env python3
"""
Bifrost Model Discovery
──────────────────────
Queries Bifrost's /v1/models endpoint across all configured providers,
groups models by provider, and auto-updates CLI config files.

Usage:
  ./discover-models.py                      # list all models
  ./discover-models.py --set-default <id>   # list + set default model
  ./discover-models.py --provider github    # filter by provider name
  ./discover-models.py --json              # raw JSON output
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

BIFROST_URL = os.environ.get("BIFROST_URL", "http://localhost:8080")
CLI_CONFIG_DIR = os.path.expanduser("~/.bifrost")
CLI_CONFIG_PATH = os.path.join(CLI_CONFIG_DIR, "config.json")
CLI_STATE_PATH = os.path.join(CLI_CONFIG_DIR, "state.json")


def fetch_models(base_url: str, provider_filter: str | None = None) -> list[dict]:
    url = f"{base_url.rstrip('/')}/v1/models"
    if provider_filter:
        url += f"?provider={provider_filter}"

    req = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = json.loads(e.read().decode()) if e.code != 404 else {}
    except (urllib.error.URLError, json.JSONDecodeError) as e:
        print(f"❌ Failed to reach Bifrost at {url}: {e}", file=sys.stderr)
        sys.exit(2)

    return body.get("data", body.get("models", []))


def group_by_provider(models: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = {}
    for m in models:
        mid: str = m.get("id", m.get("name", ""))
        if "/" in mid:
            provider, model_name = mid.split("/", 1)
        else:
            provider, model_name = "unknown", mid
        grouped.setdefault(provider, []).append(m)
    return grouped


def read_json(path: str) -> dict:
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {}


def write_json(path: str, data: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"  ✓ Updated {path}")


def update_cli_config(models: list[dict], set_default: str | None = None) -> None:
    model_ids = [m["id"] for m in models if "id" in m]
    providers = sorted(set(m["id"].split("/")[0] for m in models if "/" in m.get("id", "")))

    config = read_json(CLI_CONFIG_PATH)
    config.setdefault("auto_discovered_models", model_ids)
    config.setdefault("available_providers", providers)
    config["discovered_at"] = os.popen("date -u +%Y-%m-%dT%H:%M:%SZ").read().strip()

    if set_default:
        if set_default in model_ids:
            config["default_model"] = set_default
        else:
            print(f"  ⚠ Model '{set_default}' not found in discovered models", file=sys.stderr)
            sys.exit(1)

    write_json(CLI_CONFIG_PATH, config)

    state = read_json(CLI_STATE_PATH)
    for profile_id, sel in state.get("selections", {}).items():
        if set_default:
            sel["model"] = set_default
    if state:
        write_json(CLI_STATE_PATH, state)


def print_models(grouped: dict[str, list[dict]]) -> None:
    total = sum(len(v) for v in grouped.values())
    print(f"\n{'='*60}")
    print(f"  Available Models ({total} total)")
    print(f"{'='*60}\n")

    for provider in sorted(grouped):
        models = grouped[provider]
        print(f"  ── {provider} ({len(models)} models) ──")
        for m in sorted(models, key=lambda x: x.get("id", "")):
            mid = m.get("id", m.get("name", "?"))
            desc = m.get("description", m.get("owned_by", ""))
            extra = f"  — {desc}" if desc else ""
            print(f"    • {mid}{extra}")
        print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Discover and configure models available through Bifrost"
    )
    parser.add_argument(
        "--set-default", "-s", metavar="MODEL_ID",
        help="Set a default model in CLI config (e.g. github-models/claude-sonnet-4.6)"
    )
    parser.add_argument(
        "--provider", "-p", metavar="NAME",
        help="Filter models by provider name (e.g. github, openai)"
    )
    parser.add_argument(
        "--json", "-j", action="store_true",
        help="Output raw JSON instead of formatted display"
    )
    parser.add_argument(
        "--url", metavar="URL", default=BIFROST_URL,
        help=f"Bifrost base URL (default: {BIFROST_URL})"
    )
    args = parser.parse_args()

    models = fetch_models(args.url, args.provider)
    if not models:
        print("  No models returned. Is Bifrost running and configured?", file=sys.stderr)
        sys.exit(1)

    if args.json:
        json.dump({"total": len(models), "data": models}, sys.stdout, indent=2)
        print()
        return

    grouped = group_by_provider(models)
    print_models(grouped)

    print("  Updating CLI config...")
    update_cli_config(models, args.set_default)
    print(f"\n  ✅ Done. {len(models)} models from {len(grouped)} providers synced.\n")


if __name__ == "__main__":
    main()
