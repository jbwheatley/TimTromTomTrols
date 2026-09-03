#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
repo="$PWD"
classpath="$repo/.claude/scala-semantic-classpath.txt"
log="$(mktemp)"
backup="$(mktemp)"
trap 'rm -f "$log" "$backup"' EXIT

if [ -f "$repo/.mcp.json" ]; then cp "$repo/.mcp.json" "$backup"; fi

echo "==> Installing the MCP launcher and caching the server jar..." >&2
sbt -batch mcpClientConfig > "$log" 2>&1 || { cat "$log" >&2; exit 1; }

echo "==> Writing the classpath (compiles first; this takes a moment)..." >&2
sbt -batch writeSemanticClasspath > "$log" 2>&1 || { cat "$log" >&2; exit 1; }

python3 - "$classpath" "$repo" "$backup" <<'PY'
import json, os, re, sys

classpath, repo, backup = sys.argv[1:4]

generated = os.path.join(repo, ".mcp.json")
with open(generated) as handle:
    config = json.load(handle)

server = config["mcpServers"]["scala-semantic"]
flags = [a for a in server.get("args", []) if a.startswith("-")]
server["args"] = [repo, classpath] + flags

plugins = open(os.path.join(repo, "project", "plugins.sbt")).read()
pinned = re.search(r'sbt-scalasemantic-mcp"\s*%\s*"([^"]+)"', plugins)
if pinned:
    server.setdefault("env", {})["SCALASEMANTIC_VERSION"] = "v" + pinned.group(1)

try:
    with open(backup) as handle:
        merged = json.load(handle)
except (OSError, ValueError):
    merged = {}
merged.setdefault("mcpServers", {})["scala-semantic"] = server
with open(generated, "w") as handle:
    json.dump(merged, handle, indent=2)
    handle.write("\n")

entries = [line for line in open(classpath).read().splitlines() if line.strip()]
outputs = [e for e in entries if "/target/" in e and not e.endswith(".jar")]
print("classpath: %d entries, %d module outputs -> %s"
      % (len(entries), len(outputs), classpath))
print("config:    %s" % generated)
print("\nReconnect the server in Claude Code (/mcp) to pick this up.")
PY
