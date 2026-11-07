#!/bin/bash
# Hermetic checks: no daemon required except compose config/bake --print (client-side).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
fail=0
note() { printf 'check: %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }

# versions export (also exercises provenance)
eval "$(tooling/versions.sh --export)"

# 1. shellcheck every shell script we own
if command -v shellcheck >/dev/null 2>&1; then
    mapfile -t shell_files < <(find base/rootfs tooling tests -type f \( -name '*.sh' -o -path '*/run' -o -path '*/finish' \) | sort)
    # s6 scripts use the with-contenv shebang; lint as bash and silence SC1008.
    if [ "${#shell_files[@]}" -gt 0 ]; then
        shellcheck -s bash -e SC1008 -- "${shell_files[@]}" || bad "shellcheck"
    fi
else
    note "shellcheck not installed; skipped"
fi

# 2. markdown relative links
python3 - <<'PY' || bad "markdown links"
import os,re,subprocess,sys
files=subprocess.check_output(['git','ls-files'],text=True).split()
broken=[]
for f in files:
    if not f.endswith('.md'): continue
    try: t=open(f,encoding='utf-8',errors='replace').read()
    except OSError: continue
    for m in re.finditer(r'\[[^\]]*\]\(([^)\s]+)\)',t):
        link=m.group(1).split('#')[0]
        if not link or link.startswith(('http://','https://','mailto:','#')): continue
        p=os.path.normpath(os.path.join(os.path.dirname(f),link))
        if not os.path.exists(p): broken.append(f'{f}:{t[:m.start()].count(chr(10))+1} -> {link}')
if broken:
    print('\n'.join('BROKEN '+b for b in broken)); sys.exit(1)
PY

# 3. compose config for every profile (image refs come from the export)
for p in $(tooling/stacks.sh --profiles); do
    docker compose --profile "$p" config >/dev/null 2>&1 || bad "compose profile $p"
done

# 4. bake definition resolves
tooling/bake.sh --print >/dev/null 2>&1 || bad "bake --print"

# 5. no host values in the generic core
if grep -rnE '\$\{HOME\}' base/compose.yml stacks/*/compose.yml compose/common.yml 2>/dev/null; then
    bad "host path in generic core"
fi

# 6. no digest/version literals outside versions.env
if grep -rnE 'sha256:[0-9a-f]{64}|29\.8\.1|0\.13\.6|3\.2\.3\.0' base stacks/*/image tooling 2>/dev/null | grep -v 'versions.env'; then
    bad "pin literal outside versions.env"
fi

# 7. stack module contract
tooling/stacks.sh --check || bad "stack manifests"

# 8. unit and contract tests
for t in tests/unit/*.sh tests/contract/*.sh; do
    [ -x "$t" ] || continue
    "$t" || bad "$t"
done

# 9. generated reference and .env.example drift
tooling/generate.sh --check || bad "generated reference drift"

# 10. every documented make target exists (ignore the prose false positives)
# shellcheck disable=SC2013
for target in $(grep -rhoE '\bmake [a-z][a-z0-9-]+' docs README.md AGENTS.md .agents 2>/dev/null \
                | awk '{print $2}' | sort -u | grep -vE '^(or|surface)$'); do
    grep -qE "^${target}:" makefile || bad "documented make target missing: ${target}"
done

# 11. every canonical knob appears in the generated environment reference
# shellcheck disable=SC2013
for key in $(awk -F= '/^[A-Z_][A-Z0-9_]*=/{print $1}' config/knobs.env); do
    grep -q "\`${key}\`" docs/reference/environment.md || bad "knob missing from generated reference: ${key}"
done

if [ "$fail" -ne 0 ]; then
    echo "check FAILED" >&2
    exit 1
fi
echo "check OK"
