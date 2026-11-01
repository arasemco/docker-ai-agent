---
name: git-commit
description: Split work into small logical commits, each with the attribution of the model that did it — the exact provider build id as the author, the vendor's no-reply email, a Co-authored-by trailer when human-directed, and the model as author via git -c when autonomous. Use before and while committing.
metadata:
  area: process
  files: .agents/skills/git-commit/
---

# Git commit

Commit small, logical changes, and record on each one which model did the work
and which vendor it belongs to.

## Mini logical commits

- One intent per commit: a fix, a feature, a refactor, a docs change. If you
  cannot describe it in one imperative sentence, split it.
- Stage by path or hunk (`git add -p`); never `git add -A` a mixed tree.
- Keep local or generated files out: check `git status` for `.env`, local
  overlays, volumes and caches.
- Subject: imperative, ≤72 characters, optional `area:` prefix. Body: why, not
  what the diff already says.
- Each commit picks its own attribution; a human-directed and an autonomous
  change never share a commit.

The full loop, grouping rules and message examples are in
[references/workflow.md](references/workflow.md).

## Attribution

The author is the model that did the work; the email is its vendor's no-reply
address. Human-directed commits keep the repository identity and add
`Co-authored-by: <model> <vendor>`; autonomous commits are authored and
committed by the model for that commit only.

The vendor table and the rules are in
[references/attribution.md](references/attribution.md).

## Use the wrapper

`scripts/agent-commit.sh` handles both modes:

```bash
# human-directed: keep the repository identity and add the trailer
.agents/skills/git-commit/scripts/agent-commit.sh \
    --model DeepSeek-V4.1-Flash-1017 -m "..."

# autonomous: the model as author and committer, for this commit only
.agents/skills/git-commit/scripts/agent-commit.sh \
    --model DeepSeek-V4.1-Flash-1017 --autonomous -m "..."
```

Pass the exact build id the session runs, not a family alias. When the skill is
installed globally at `~/.agents/skills/git-commit/`, use the script under that
path.

## References

- [references/attribution.md](references/attribution.md) — identity, vendor
  emails, the two modes, and the rules.
- [references/workflow.md](references/workflow.md) — the mini-commit loop,
  what belongs together, and message conventions.
- [references/examples.md](references/examples.md) — command examples,
  including an unknown vendor, an amend, and a repository without the wrapper.

The script's `--help` lists the vendor mapping; `--vendor` covers anything else.
Any other argument is passed to `git commit`.
