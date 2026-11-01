---
name: git-commit
description: Commit with the attribution of the model that did the work — the exact provider build id as the author, the vendor's no-reply email, a Co-authored-by trailer when human-directed, and the model as author via git -c when autonomous. Use before any git commit.
metadata:
  area: process
  files: .agents/skills/git-commit/
---

# Git commit

Every commit records which model did the work and which vendor it belongs to:
the exact provider build id as the author name, and that vendor's no-reply email.

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
- [references/examples.md](references/examples.md) — command examples,
  including an unknown vendor, an amend, and a repository without the wrapper.

The script's `--help` lists the vendor mapping; `--vendor` covers anything else.
Any other argument is passed to `git commit`.
