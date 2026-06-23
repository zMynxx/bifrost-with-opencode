#!/usr/bin/env python3
"""
Post-install fixup for gentle-ai workspace install.

gentle-ai install --scope=workspace writes to .config/opencode/ (hardcoded).
Canonical config lives in .opencode/.  Syncs assets there, merges config,
fixes path refs, removes staged files.
"""

import json
import os
import shutil
import sys
import filecmp

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GENTLE_DIR = os.path.join(REPO_ROOT, ".config", "opencode")
GENTLE_CONFIG = os.path.join(GENTLE_DIR, "opencode.json")
OPCODE_CONFIG = os.path.join(REPO_ROOT, ".opencode", "opencode.json")
DOT_OPENCODE = os.path.join(REPO_ROOT, ".opencode")
AGENTS_MD_SRC = os.path.join(GENTLE_DIR, "AGENTS.md")
AGENTS_MD_DST = os.path.join(REPO_ROOT, "AGENTS.md")


def _ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def _sync_dir(src, dst, label):
    if not os.path.isdir(src):
        return 0
    _ensure_dir(dst)
    count = 0
    for name in os.listdir(src):
        s = os.path.join(src, name)
        d = os.path.join(dst, name)
        if os.path.isfile(s):
            if not os.path.exists(d) or not filecmp.cmp(s, d, shallow=False):
                shutil.copy2(s, d)
                count += 1
        elif os.path.isdir(s):
            for root, dirs, files in os.walk(s):
                rel = os.path.relpath(root, src)
                target_dir = os.path.join(dst, rel)
                _ensure_dir(target_dir)
                for f in files:
                    sf = os.path.join(root, f)
                    df = os.path.join(target_dir, f)
                    if not os.path.exists(df) or not filecmp.cmp(sf, df, shallow=False):
                        shutil.copy2(sf, df)
                        count += 1
    if count:
        print(f"   Synced {count} file(s) to .opencode/{label}/")
    return count


def _rm_staging(label, path):
    if os.path.isfile(path):
        os.remove(path)
        print(f"   Removed staging: .config/opencode/{label}")
    elif os.path.isdir(path):
        shutil.rmtree(path)
        print(f"   Removed staging: .config/opencode/{label}/")


def _fix_paths(obj, old, new):
    text = json.dumps(obj)
    if old not in text:
        return None
    return json.loads(text.replace(old, new))


def main():
    if not os.path.exists(GENTLE_DIR):
        print(f"gentle config dir not found at {GENTLE_DIR} - nothing to fixup")
        return
    if not os.path.exists(GENTLE_CONFIG):
        print(f"gentle config not found at {GENTLE_CONFIG} - nothing to fixup")
        return

    stage_items = []

    if os.path.isfile(AGENTS_MD_SRC):
        if not os.path.exists(AGENTS_MD_DST) or not filecmp.cmp(AGENTS_MD_SRC, AGENTS_MD_DST, shallow=False):
            shutil.copy2(AGENTS_MD_SRC, AGENTS_MD_DST)
            print("   Synced AGENTS.md -> project root")
        stage_items.append(("AGENTS.md", AGENTS_MD_SRC))

    for name in ("commands", "plugins", "prompts", "skills"):
        src = os.path.join(GENTLE_DIR, name)
        dst = os.path.join(DOT_OPENCODE, name)
        _sync_dir(src, dst, name)
        stage_items.append((name, src))

    if not os.path.exists(OPCODE_CONFIG):
        print(f"opencode config not found at {OPCODE_CONFIG}")
        sys.exit(1)

    with open(GENTLE_CONFIG) as f:
        gentle_cfg = json.load(f)

    with open(OPCODE_CONFIG) as f:
        opencode_cfg = json.load(f)

    old_ref = ".config/opencode/"
    new_ref = ".opencode/"
    config_changed = False

    if "agent" in gentle_cfg:
        for name, agent in gentle_cfg["agent"].items():
            prompt = agent.get("prompt", "")
            for old in ("~/.config/opencode/", ".config/opencode/"):
                if old in prompt:
                    agent["prompt"] = prompt.replace(old, new_ref)
                    config_changed = True

    gentle_agents = gentle_cfg.get("agent", {})
    merged_agents = {**gentle_agents, **opencode_cfg.get("agent", {})}
    if merged_agents:
        opencode_cfg["agent"] = merged_agents
        count = sum(1 for k in gentle_agents if k in opencode_cfg.get("agent", {}))
        print(f"   Merged {len(gentle_agents)} agent definition(s) ({count} overridden by .opencode/opencode.json)")

    gentle_mcp = gentle_cfg.get("mcp", {})
    if gentle_mcp:
        merged_mcp = {**gentle_mcp, **opencode_cfg.get("mcp", {})}
        opencode_cfg["mcp"] = merged_mcp
        count = sum(1 for k in gentle_mcp if k in opencode_cfg.get("mcp", {}))
        print(f"   Merged {len(gentle_mcp)} MCP server(s) ({count} overridden by .opencode/opencode.json)")

    result = _fix_paths(opencode_cfg, old_ref, new_ref)
    if result is not None:
        opencode_cfg = result
        config_changed = True

    if "agent" in opencode_cfg:
        for name, agent in opencode_cfg["agent"].items():
            prompt = agent.get("prompt", "")
            if old_ref in prompt:
                agent["prompt"] = prompt.replace(old_ref, new_ref)
                config_changed = True

    with open(OPCODE_CONFIG, "w") as f:
        json.dump(opencode_cfg, f, indent=2)
        f.write("\n")

    if config_changed:
        print(f"   Fixed {old_ref} -> {new_ref} path references")

    print(f"Updated {OPCODE_CONFIG}")

    for label, path in stage_items:
        _rm_staging(label, path)
    if os.path.isfile(GENTLE_CONFIG):
        os.remove(GENTLE_CONFIG)
        print("   Removed staging opencode.json")

    if os.path.isdir(GENTLE_DIR) and not os.listdir(GENTLE_DIR):
        os.rmdir(GENTLE_DIR)
        print("   Removed empty .config/opencode/")


if __name__ == "__main__":
    main()
