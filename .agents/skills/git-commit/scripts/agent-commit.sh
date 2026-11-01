#!/usr/bin/env bash
# =============================================================================
# agent-commit.sh — commit as the model that did the work, with its vendor mail.
#
# The author name is the model id, not the CLI and not the vendor:
# `DeepSeek-V4.1-Flash-1017`, `claude-sonnet-4-5`, ... The email is the vendor's no-reply
# address derived from the model id (see VENDOR below).
#
# Human-directed (default): the human asked for the change. The commit keeps
# the repository's configured author and committer and gains a
# `Co-authored-by: <model> <vendor>` trailer.
#
# Autonomous (--autonomous): the agent initiated the work. The commit is
# authored and committed by the model, for that commit only, through `git -c`;
# the repository's own identity is never modified.
#
# Usage:
#   agent-commit.sh --model DeepSeek-V4.1-Flash-1017 -m "Add the thing"
#   agent-commit.sh --model claude-sonnet-4-5 --autonomous -m "..."
#   agent-commit.sh --model qwen3.5:9b --vendor noreply@localhost -m "..."
#
# Any argument other than --model/--vendor/--autonomous is passed to git commit.
# =============================================================================
set -euo pipefail

die() {
    printf 'agent-commit: %s\n' "$*" >&2
    exit 2
}

usage() {
    cat <<'EOF'
usage: agent-commit.sh --model <model-id> [--vendor <email>] [--autonomous]
                               [git commit args]

  --model ID      the exact provider build that did the work, verbatim as the
                  author name (DeepSeek-V4.1-Flash-1017, claude-sonnet-4-5, ...);
                  not a family alias, CLI or product
  --vendor EMAIL  vendor no-reply email; derived from the model id by default
  --autonomous    the agent initiated the work: commit as the model
                  (default: the human directed it, so keep their identity and
                  add a Co-authored-by trailer)

Vendor emails derived from the model id:
  deepseek*                  noreply@deepseek.com
  claude*                    noreply@anthropic.com
  gpt*, o1*, o3*, o4*, chatgpt*  noreply@openai.com
  gemini*                    noreply@google.com
  grok*                      noreply@x.ai
  mistral*, mixtral*         noreply@mistral.ai
Anything else needs --vendor (for example --vendor noreply@localhost).

Examples:
  agent-commit.sh --model DeepSeek-V4.1-Flash-1017 -m "Add the Claude Code stack"
  agent-commit.sh --model DeepSeek-V4.1-Flash-1017 --autonomous -m "Refresh deps"

Any other argument is passed to `git commit`.
EOF
}

model=""
vendor=""
autonomous=0
args=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --model)
            [ "$#" -ge 2 ] || die "--model needs a value"
            model="$2"
            shift 2
            ;;
        --vendor)
            [ "$#" -ge 2 ] || die "--vendor needs a value"
            vendor="$2"
            shift 2
            ;;
        --autonomous)
            autonomous=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            args+=("$@")
            break
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

[ -n "$model" ] || die "--model is required (the exact model id, e.g. DeepSeek-V4.1-Flash-1017)"

if [ -z "$vendor" ]; then
    lower="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        deepseek*)                        vendor="noreply@deepseek.com" ;;
        claude*)                          vendor="noreply@anthropic.com" ;;
        gpt*|o1*|o3*|o4*|chatgpt*)        vendor="noreply@openai.com" ;;
        gemini*)                          vendor="noreply@google.com" ;;
        grok*)                            vendor="noreply@x.ai" ;;
        mistral*|mixtral*)                vendor="noreply@mistral.ai" ;;
        *)
            die "no vendor email known for '${model}'; pass --vendor <email> (for example --vendor noreply@localhost)"
            ;;
    esac
fi

case "$vendor" in
    *@*) ;;
    *) die "--vendor is not an email address: '${vendor}'" ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git work tree"

if [ "$autonomous" -eq 1 ]; then
    # Author and committer for this commit only; .git/config is untouched.
    exec git -c "user.name=${model}" -c "user.email=${vendor}" commit "${args[@]}"
fi

# Human-directed: keep the configured identity and add the co-author trailer.
# Skip it when the caller already supplied one (some CLIs add their own).
trailer="Co-authored-by: ${model} <${vendor}>"
for arg in "${args[@]}"; do
    case "$arg" in
        *[Cc]o-authored-by:*) exec git commit "${args[@]}" ;;
    esac
done

exec git commit --trailer "${trailer}" "${args[@]}"
