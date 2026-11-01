# AGENTS.md

Instructions for AI coding agents working in this repository.

**Read [`.agents/README.md`](.agents/README.md) first** — it has the repository map,
the invariants that are easy to break, and the checks to run. User-facing
documentation lives in [`docs/`](docs/index.md); this file is only the short
version.

Task-specific skills are in [`.agents/skills/`](.agents/skills/): load the one
that matches the job (`work-on-the-image`, `compose-anchors`,
`build-and-publish`, `run-and-debug`, `child-image`) before starting.

## Hard rules

1. The base image contains no CLI: an agent stack lives under `stacks/<name>/`
   and builds `FROM agent-base`.
2. Do not end a Dockerfile with `USER 1000:1000`; `/init` must be PID 1 as root.
3. No host-specific values in the core: no IPs, hostnames, registry paths or
   personal directories outside `examples/`.
4. Compose anchors each own exactly one concern and declare the volumes they
   mount.
5. Comments and docs describe what the code does and why it must — not the
   history of the change or a conversation.
6. Bump `BASE_VERSION` in `docker-bake.hcl` whenever `image/` changes.
7. Keep everything pinned: base image by digest, s6 by version + sha256, CLIs by
   exact version.
8. Record who did the work: commit through `scripts/agent-commit.sh` with the
   model that did it and the correct mode (see below).

## Commit attribution

Every commit records which model did the work and which vendor it belongs to.
The author name is the model id — not the CLI and not the vendor — and the
email is that vendor's no-reply address. Use the wrapper; never edit
`.git/config`, and never pass `user.name`/`user.email` to `git commit` directly.

| Model id (examples) | Vendor email |
|---|---|
| `DeepSeek-V4.1-Flash-1017` | `noreply@deepseek.com` |
| `claude-sonnet-4-5` | `noreply@anthropic.com` |
| `gpt-*`, `o1-*`, `o3-*`, `o4-*`, `chatgpt-*` | `noreply@openai.com` |
| `gemini-*` | `noreply@google.com` |
| `grok-*` | `noreply@x.ai` |
| `mistral-*`, `mixtral-*` | `noreply@mistral.ai` |
| anything else | pass `--vendor` (e.g. `--vendor noreply@localhost`) |

- **Human-directed** (default) — the human asked for the change. The commit
  keeps the repository's configured author and committer and gains a
  `Co-authored-by: <model> <vendor>` trailer:

  ```bash
  scripts/agent-commit.sh --model DeepSeek-V4.1-Flash-1017 -m "Add the Claude Code stack"
  ```

- **Autonomous** — the agent initiated the work. The commit is authored and
  committed by the model for that commit only, so the repository identity is
  untouched:

  ```bash
  scripts/agent-commit.sh --model DeepSeek-V4.1-Flash-1017 --autonomous -m "Refresh dependencies"
  ```

Pass the exact provider build id the session runs (from its configuration),
not a family alias, product, or CLI name: `DeepSeek-V4.1-Flash-1017`,
`claude-sonnet-4-5`, and so on. Decide the
mode per commit, not per session: a human asking for a commit makes that commit
human-directed even if earlier ones were autonomous, and vice versa. The
wrapper skips the trailer when the message already contains one, so an agent
CLI that adds its own co-author line does not duplicate it.

In a repository without `scripts/agent-commit.sh`, apply the same rule
directly: human-directed commits use
`git commit --trailer "Co-authored-by: <model> <vendor>"`, and autonomous
commits use `git -c user.name="<model>" -c user.email="<vendor>" commit`.

## Verify before you finish

```bash
shellcheck image/rootfs/usr/local/bin/* scripts/*.sh
scripts/bake.sh test     # builds the image, runs shellcheck + tool matrix
make smoke               # real container: services, health, tool matrix
```

`make smoke` printing `SKIP` for the rootless daemon is expected on hosts whose
own Docker is rootless.
