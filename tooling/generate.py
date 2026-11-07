#!/usr/bin/env python3
"""Generate the reference pages and .env.example from the single sources."""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check" in sys.argv


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def write_if_changed(path, content):
    full = os.path.join(ROOT, path)
    old = None
    if os.path.exists(full):
        with open(full, encoding="utf-8") as f:
            old = f.read()
    if old == content:
        return True
    if CHECK:
        print(f"generate: {path} is stale", file=sys.stderr)
        return False
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(content)
    return True


def knobs():
    sections = []
    entries = []
    section = "Deployment"
    for raw in read("config/knobs.env").splitlines():
        line = raw.rstrip()
        if line.startswith("# --- ") and line.endswith(" ---"):
            section = line[6:-4].strip()
        elif not line or line.startswith("#"):
            continue
        elif "=" in line:
            key, rest = line.split("=", 1)
            value, _, desc = rest.partition("#")
            entries.append((section, key.strip(), value.strip(), desc.strip()))
    for section in dict.fromkeys(e[0] for e in entries):
        sections.append((section, [e for e in entries if e[0] == section]))
    return sections


def env_example(sections):
    out = ["# Deployment values. Generated from config/knobs.env; do not edit.",
           "# Copy to .env (gitignored). Versions and image references come from",
           "# versions.env, not from this file.", ""]
    for section, items in sections:
        out.append(f"# --- {section} ---")
        for _, key, value, _ in items:
            out.append(f"{key}={value}")
        out.append("")
    return "\n".join(out)


def environment(sections):
    out = ["# Environment", "",
           "Generated from `config/knobs.env`; do not edit.", "",
           "| Variable | Default | Meaning |", "|---|---|---|"]
    for _, items in sections:
        for _, key, value, desc in items:
            out.append(f"| `{key}` | `{value or '-'}` | {desc or '-'} |")
    return "\n".join(out) + "\n"


def versions():
    vals = {}
    for line in read("versions.env").splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            vals[k] = v
    out = ["# Versions", "", "Generated from `versions.env`; do not edit.", "",
           "| Pin | Value |", "|---|---|"]
    for key in ["BASE_VERSION", "AGENT_CONTRACT", "DEBIAN_REF", "S6_OVERLAY_VERSION",
                "DOCKER_VERSION", "UV_VERSION", "NODE_REF", "OPENCODE_VERSION",
                "DSH_VERSION", "CLAUDE_VERSION", "PNPM_VERSION", "LICENSES"]:
        out.append(f"| `{key}` | `{vals.get(key, '')}` |")
    return "\n".join(out) + "\n"


def manifests():
    rows = []
    for name in sorted(os.listdir(os.path.join(ROOT, "stacks"))):
        path = os.path.join(ROOT, "stacks", name, "stack.yaml")
        if not os.path.isfile(path):
            continue
        fields = {}
        for line in open(path, encoding="utf-8"):
            if ":" in line and not line.startswith(" "):
                k, v = line.split(":", 1)
                fields[k.strip()] = v.strip()
        rows.append((name, fields.get("title", name), fields.get("version_key", "")))
    out = ["# Stacks", "", "Generated from `stacks/*/stack.yaml`; do not edit.", "",
           "| Id | Title | Version key |", "|---|---|---|"]
    for row in rows:
        out.append(f"| `{row[0]}` | {row[1]} | `{row[2]}` |")
    return "\n".join(out) + "\n"


def targets():
    proc = subprocess.run([os.path.join(ROOT, "tooling", "bake.sh"), "--print", "all"],
                          cwd=ROOT, capture_output=True, text=True)
    data = json.loads(proc.stdout or "{}")
    out = ["# Build targets", "", "Generated from the bake definition; do not edit.", "",
           "| Target | Tags |", "|---|---|"]
    for name in sorted(data.get("target", {})):
        tags = data["target"][name].get("tags", [])
        out.append(f"| `{name}` | {', '.join(f'`{t}`' for t in tags) or '-'} |")
    return "\n".join(out) + "\n"


def checks():
    out = ["# Checks", "", "Generated from the make surface; do not edit.", "",
           "| Command | Purpose |", "|---|---|",
           "| `make check` | hermetic contract suite |",
           "| `make test` | base image test stage |",
           "| `make test-node22` | Node 22 base test stage |",
           "| `make test-dsh` | dsh integration test (credentials required) |",
           "| `make generate-check` | reference and .env.example drift |",
           "| `make smoke PROFILE=<id>` | running-stack probes |"]
    return "\n".join(out) + "\n"


def main():
    sections = knobs()
    ok = True
    for path, content in [
        (".env.example", env_example(sections)),
        ("docs/reference/environment.md", environment(sections)),
        ("docs/reference/versions.md", versions()),
        ("docs/reference/stacks.md", manifests()),
        ("docs/reference/targets.md", targets()),
        ("docs/reference/checks.md", checks()),
    ]:
        ok = write_if_changed(path, content) and ok
    if CHECK:
        print("generate --check OK" if ok else "generate --check FAILED", file=sys.stderr)
        return 0 if ok else 1
    print("generated reference and .env.example")
    return 0


if __name__ == "__main__":
    sys.exit(main())
