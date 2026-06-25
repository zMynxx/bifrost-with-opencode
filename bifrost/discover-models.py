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
from pathlib import Path
import urllib.request
import urllib.error

from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

REPO_ROOT = Path(__file__).resolve().parent.parent

class Settings(BaseSettings):
    bifrost_url: str = "http://localhost:8080"
    openai_api_key: Optional[str] = None
    anthropic_api_key: Optional[str] = None
    gemini_api_key: Optional[str] = None
    github_api_key: Optional[str] = None
    aws_access_key_id: Optional[str] = None
    aws_secret_access_key: Optional[str] = None
    aws_session_token: Optional[str] = None
    aws_region: Optional[str] = None

    model_config = SettingsConfigDict(
        env_file=[".env", "../.env"],
        extra="ignore",
    )

settings = Settings()
BIFROST_URL = settings.bifrost_url
CLI_CONFIG_DIR = REPO_ROOT / ".bifrost"
CLI_CONFIG_PATH = CLI_CONFIG_DIR / "config.json"
CLI_STATE_PATH = CLI_CONFIG_DIR / "state.json"
CLI_CONFIG_EXAMPLE_PATH = REPO_ROOT / "bifrost" / "bifrost-cli-config.example.json"
CLI_STATE_EXAMPLE_PATH = REPO_ROOT / "bifrost" / "bifrost-cli-state.example.json"
OPENCODE_CONFIG_PATH = REPO_ROOT / ".opencode" / "opencode.json"


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


def seed_from_example(target: Path, example: Path) -> dict:
    if not target.exists() and example.exists():
        data = json.loads(example.read_text())
        write_json(str(target), data)
        return data
    return read_json(str(target))


def update_cli_config(models: list[dict], set_default: str | None = None) -> None:
    model_ids = [m["id"] for m in models if "id" in m]
    providers = sorted(set(m["id"].split("/")[0] for m in models if "/" in m.get("id", "")))

    config = seed_from_example(CLI_CONFIG_PATH, CLI_CONFIG_EXAMPLE_PATH)
    state = seed_from_example(CLI_STATE_PATH, CLI_STATE_EXAMPLE_PATH)

    config["auto_discovered_models"] = model_ids
    config["available_providers"] = providers
    config["discovered_at"] = os.popen("date -u +%Y-%m-%dT%H:%M:%SZ").read().strip()

    if set_default:
        if set_default in model_ids:
            config["default_model"] = set_default
        else:
            print(f"  ⚠ Model '{set_default}' not found in discovered models", file=sys.stderr)
            sys.exit(1)

    write_json(str(CLI_CONFIG_PATH), config)

    for profile_id, sel in state.get("selections", {}).items():
        if set_default:
            sel["model"] = set_default
    write_json(str(CLI_STATE_PATH), state)


def _migrate_model_id(model_id: str, model_ids: list[str]) -> str:
    """Rebind a model/small_model to a matching ID in the discovered list.

    Handles prefix migrations like meridian-claude/ → anthropic/ by matching
    the model name part.
    """
    if model_id in model_ids:
        return model_id
    suffix = model_id.split("/", 1)[-1] if "/" in model_id else model_id
    for mid in model_ids:
        if mid.endswith("/" + suffix) or mid == suffix:
            return mid
    return model_id


PROVIDER_LABELS: dict[str, str] = {
    "openai": "OpenAI",
    "github-copilot": "Copilot",
    "bedrock": "Bedrock",
    "anthropic": "Anthropic",
    "gemini": "Gemini",
}


def _auto_name(model_id: str) -> str:
    if "/" not in model_id:
        return model_id
    provider, name = model_id.split("/", 1)
    label = PROVIDER_LABELS.get(provider, provider)
    return f"{name} [{label}]"


def update_opencode_config(model_ids: list[str]) -> None:
    if not OPENCODE_CONFIG_PATH.exists():
        return

    opencode = read_json(str(OPENCODE_CONFIG_PATH))
    provider = opencode.setdefault("provider", {}).setdefault("openai", {})
    provider.setdefault("name", "Bifrost")
    provider.setdefault("options", {"baseURL": "http://localhost:8080/openai", "apiKey": "dummy"})

    existing = provider.get("models", {})
    provider["models"] = {
        mid: existing[mid] if mid in existing else {"name": _auto_name(mid)}
        for mid in sorted(model_ids)
    }

    for key in ("model", "small_model"):
        old = opencode.get(key)
        if old:
            opencode[key] = _migrate_model_id(old, model_ids)

    write_json(str(OPENCODE_CONFIG_PATH), opencode)


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
        help="Set a default model in CLI config (e.g. github-copilot/gpt-4o-mini)"
    )
    parser.add_argument(
        "--provider", "-p", metavar="NAME",
        help="Filter models by provider name (e.g. github-copilot, openai)"
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

    model_ids = [m["id"] for m in models if "id" in m]

    print("  Updating CLI config...")
    update_cli_config(models, args.set_default)

    print("  Updating OpenCode config...")
    update_opencode_config(model_ids)

    print(f"\n  ✅ Done. {len(models)} models from {len(grouped)} providers synced.\n")


if __name__ == "__main__":
    main()
