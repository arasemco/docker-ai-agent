# Commit attribution

Every commit records which model did the work and which vendor it belongs to.

## Identity

- **Author name:** the exact provider build id — `DeepSeek-V4.1-Flash-1017`,
  `claude-sonnet-4-5`, `gpt-5-codex` — never a CLI, a product, or a family
  alias. `deepseek-flash` is the harness alias, not a build id.
- **Email:** the vendor's no-reply address, derived from the model id:

  | Model id prefix | Email |
  |---|---|
  | `deepseek*` | `noreply@deepseek.com` |
  | `claude*` | `noreply@anthropic.com` |
  | `gpt*`, `o1*`, `o3*`, `o4*`, `chatgpt*` | `noreply@openai.com` |
  | `gemini*` | `noreply@google.com` |
  | `grok*` | `noreply@x.ai` |
  | `mistral*`, `mixtral*` | `noreply@mistral.ai` |
  | anything else | pass `--vendor` (e.g. `--vendor noreply@localhost`) |

## Modes

- **Human-directed** (default) — the human asked for the change. Keep the
  repository's configured author and committer and add:

  ```
  Co-authored-by: <model> <vendor-email>
  ```

- **Autonomous** — the agent initiated the work. Commit as the model, for that
  commit only, through `git -c user.name="<model>" -c user.email="<vendor>"`.

Decide the mode per commit, not per session: a human asking for a commit makes
that commit human-directed even if earlier ones were autonomous, and vice versa.

## Rules

- Never edit `.git/config` and never pass `user.name`/`user.email` to
  `git commit` directly; the wrapper uses `git -c` for autonomous commits.
- Never impersonate the human in autonomous mode.
- Pass the exact provider build id the session runs; the wrapper derives the
  vendor from the model id.
- The wrapper does not duplicate a `Co-authored-by` trailer that is already in
  the message, so a CLI that adds its own line is safe.
- More than one model in a commit: split it by model. If it cannot be split, add
  a second `Co-authored-by` trailer manually — the wrapper adds only its own.
