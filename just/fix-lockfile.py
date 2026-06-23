#!/usr/bin/env python3
"""Post-process skills.lock: rewrite runtime + source_path after skil-lock lock ."""

import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "skills.lock"

with open(path) as f:
    content = f.read()

content = content.replace("    runtime: claude\n", "    runtime: universal\n")
content = content.replace("source_path: .claude/skills/", "source_path: .agents/skills/")

with open(path, "w") as f:
    f.write(content)

print(f"  ✓ Fixed {path}")
