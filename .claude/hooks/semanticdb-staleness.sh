#!/usr/bin/env bash
input=$(cat)
python3 - "$input" <<'PY'
import sys, json, os, glob, re, hashlib

project = os.environ.get("CLAUDE_PROJECT_DIR", "")
repo = project or "."
if not os.path.isdir(repo):
    sys.exit(0)

warnings = []

INDEX_DIRS = glob.glob(
    os.path.join(repo, "target", "out", "jvm", "scala-*", "*", "*meta"))

def indexes_for(source):
    relative = os.path.relpath(source, repo)
    candidates = (
        os.path.join(d, "META-INF", "semanticdb", relative + ".semanticdb")
        for d in INDEX_DIRS
    )
    return [c for c in candidates if os.path.exists(c)]

def matches_content(source, indexes):
    digest = hashlib.md5(open(source, "rb").read()).hexdigest().upper().encode()
    return any(digest in open(i, "rb").read() for i in indexes)

def is_nested_build(path):
    return any(
        os.path.exists(os.path.join(path, definition))
        for definition in ("build.sbt", "build.mill", "build.mill.scala")
    )

SOURCE_ROOTS = [
    root for root in glob.glob(os.path.join(repo, "*", "src"))
    if not is_nested_build(os.path.dirname(root))
]

stale, indexed_any = [], False
for source_root in SOURCE_ROOTS:
    for directory, dirs, files in os.walk(source_root):
        dirs[:] = [
            d for d in dirs
            if d != "target" and not is_nested_build(os.path.join(directory, d))
        ]
        for name in files:
            if not name.endswith(".scala"):
                continue
            source = os.path.join(directory, name)
            indexes = indexes_for(source)
            if not indexes:
                stale.append(source)
                continue
            indexed_any = True
            if os.path.getmtime(source) <= max(os.path.getmtime(i) for i in indexes):
                continue
            if not matches_content(source, indexes):
                stale.append(source)

if indexed_any and stale:
    shown = [os.path.relpath(p, repo) for p in sorted(stale)[:10]]
    more = "" if len(stale) <= 10 else "\n  ... and %d more" % (len(stale) - 10)
    warnings.append(
        "SemanticDB index is STALE: %d Scala source(s) changed since they were last "
        "compiled, so the answer above may predate them. Verify against source before "
        "acting on anything touching these, and treat an empty find_usages as unproven "
        "rather than as proof nothing calls the symbol. Run `sbt Test/compile` "
        "to refresh.\n  %s%s" % (len(stale), "\n  ".join(shown), more)
    )

def classpath_file():
    try:
        with open(os.path.join(project or ".", ".mcp.json")) as handle:
            config = json.load(handle)
    except (OSError, ValueError):
        return None
    server = config.get("mcpServers", {}).get("scala-semantic", {})
    for arg in server.get("args", []):
        if isinstance(arg, str) and arg.endswith(".txt"):
            return arg
    return None

path = classpath_file()
if path and os.path.exists(path):
    with open(path) as handle:
        entries = [
            e.strip()
            for line in handle.read().splitlines()
            for e in line.split(os.pathsep)
            if e.strip()
        ]
    problems = []

    absent = [
        e for e in entries
        if not os.path.exists(e) and not os.path.abspath(e).startswith(os.path.abspath(repo))
    ]
    if absent:
        problems.append(
            "%d of %d entries no longer exist on disk (dependencies moved or the "
            "cache was cleared)" % (len(absent), len(entries))
        )

    try:
        build = open(os.path.join(repo, "build.sbt")).read()
    except OSError:
        build = ""
    assigned = re.search(r'scalaVersion\s*:=\s*(?:"([^"]+)"|(\w+))', build)
    declared = assigned.group(1) if assigned else None
    if assigned and not declared:
        named = re.search(r'val\s+%s\s*=\s*"([^"]+)"' % re.escape(assigned.group(2)), build)
        declared = named.group(1) if named else None
    if declared:
        want = "scala-" + declared
        pinned = {m for e in entries for m in re.findall(r"scala-\d[^/\\]*", e)}
        if pinned and want not in pinned:
            problems.append(
                "entries pin %s but build.sbt declares %s"
                % ("/".join(sorted(pinned)), declared)
            )

    for definition in ("build.sbt", os.path.join("project", "plugins.sbt")):
        full = os.path.join(repo, definition)
        if os.path.exists(full) and os.path.getmtime(full) > os.path.getmtime(path):
            problems.append("%s is newer than the classpath snapshot" % definition)

    if problems:
        warnings.append(
            "scala-semantic CLASSPATH is out of date (%s). The presentation-compiler "
            "overlay silently degrades to the stale on-disk index for anything it "
            "cannot reach. Regenerate with `scripts/gen-semantic-classpath.sh`.\n  - %s"
            % (os.path.basename(path), "\n  - ".join(problems))
        )

if warnings:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "\n\n".join(warnings),
        }
    }))
PY
