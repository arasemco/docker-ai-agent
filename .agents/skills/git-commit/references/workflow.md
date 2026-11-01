# Mini logical commits

One commit per intent keeps history readable and `git log` useful.

## Loop

1. Read the tree: `git status`, `git diff`, `git diff --cached`.
2. List the intents in the working tree. One commit per intent; if two files
   serve different intents, split them.
3. Stage one intent: `git add <paths>` or `git add -p`.
4. Commit it with the wrapper and the mode that matches that change:
   - **human-directed** — the human asked for it: keep their identity and add
     the model as co-author;
   - **autonomous** — the agent initiated it: commit as the model.
5. Verify: `git show --stat` and `git log -1 --format='%h %an <%ae>%n%B'`.
6. Repeat for the next intent.

## What belongs together

- A fix with its test; a behavior with its docs.
- A refactor on its own; a dependency bump on its own.
- Formatting changes on their own, not mixed with behavior.
- If splitting would leave the build broken, keep one commit and explain in the
  body why it cannot be split.

## What to keep out

- `.env`, local compose overlays, volumes, caches, generated files.
- Files from another task.
- Anything already committed; re-check `git status` after each commit.

## Messages

- Subject: imperative, ≤72 characters; `area: summary` when it helps.
- Body: why the change is needed and any non-obvious choice. No “as discussed”,
  no restating the diff.
- One commit = one reviewable unit.

Example:

```
fix(compose): mount the global agent file read-only

The claude and opencode services were writing to the same file; mount it ro
like the other shared inputs.
```

## Attribution per commit

- **Human-directed:** author and committer are the human; the trailer is
  `Co-authored-by: <model> <vendor>`.
- **Autonomous:** author and committer are the model.
- If two models contributed to one commit, split it by model. If it cannot be
  split, add a second `Co-authored-by` trailer manually with that model's vendor
  email — the wrapper adds only its own.

See [attribution.md](attribution.md) for the identity table and rules.
