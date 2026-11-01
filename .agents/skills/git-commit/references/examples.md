# Examples

All commands run from the repository root; `agent-commit.sh` is in this skill's
`scripts/` directory. Installed globally, the path is
`~/.agents/skills/git-commit/scripts/agent-commit.sh`.

## Human-directed

The human asked for the change; keep their identity and add the trailer:

```bash
.agents/skills/git-commit/scripts/agent-commit.sh \
    --model DeepSeek-V4.1-Flash-1017 -m "Add the Claude Code stack"
```

Result:

```
Author:    Aram SEMO <aram.semo@asemo.pro>
Trailer:   Co-authored-by: DeepSeek-V4.1-Flash-1017 <noreply@deepseek.com>
```

## Autonomous

The agent initiated the work; commit as the model for that commit only:

```bash
.agents/skills/git-commit/scripts/agent-commit.sh \
    --model DeepSeek-V4.1-Flash-1017 --autonomous -m "Refresh dependencies"
```

`.git/config` is untouched; the author and committer are
`DeepSeek-V4.1-Flash-1017 <noreply@deepseek.com>`.

## A model whose vendor is not in the table

```bash
.agents/skills/git-commit/scripts/agent-commit.sh \
    --model qwen3.5:9b --vendor noreply@localhost -m "..."
```

## Amending

`git commit` arguments pass through, so the same wrapper handles an amend:

```bash
.agents/skills/git-commit/scripts/agent-commit.sh \
    --model DeepSeek-V4.1-Flash-1017 --amend -m "New subject" -m "New body"
```

The old message is replaced by the arguments; the wrapper adds the trailer to
the new message.

## Without the wrapper

In a repository that does not have this skill installed, apply the same rule
directly:

```bash
# human-directed
git commit --trailer "Co-authored-by: DeepSeek-V4.1-Flash-1017 <noreply@deepseek.com>" -m "..."

# autonomous
git -c user.name="DeepSeek-V4.1-Flash-1017" \
    -c user.email="noreply@deepseek.com" commit -m "..."
```

## Mini logical commits

Stage and commit one intent at a time; each commit gets its own attribution:

```bash
git status
git diff

# first intent: the fix
git add -p
.agents/skills/git-commit/scripts/agent-commit.sh \
    --model DeepSeek-V4.1-Flash-1017 -m "fix: ..."

# second intent: its documentation, committed separately
git add README.md
.agents/skills/git-commit/scripts/agent-commit.sh \
    --model DeepSeek-V4.1-Flash-1017 -m "docs: ..."
```

Do not `git add -A` a tree that mixes intents; the per-commit attribution is
part of the point.

## Verify

```bash
git log -1 --format='%an <%ae>%n%B'
```
