---
description: Close a Fulcrum session cleanly — settle the tree, make work recoverable, restore the base if ad-hoc, write a handoff. Prevents dirty-branch / lost-context mix-ups.
---

# /fulcrum-close

Close this session so nothing is left dirty, orphaned, or lost. Work in order.

## 1. Settle the working tree

- Run `git status --short`.
- If there's real uncommitted work: stage and commit it with a conventional-commit message (`type(scope): message`, **no AI / Claude / Anthropic attribution**). Group logically; don't dump unrelated changes into one commit.
- If some changes are scratch/experiments, tell me what they are and ask before discarding. **Never end on a dirty tree, and never stash or `reset --hard` silently.**

## 2. Make it recoverable + lane hygiene

- Push the branch: `git push -u origin HEAD`.
  - **In a Conductor workspace:** that branch IS the review unit — pushing readies the diff/PR. Don't merge from here unless I ask.
  - **Ad-hoc CLI in a repo's primary checkout** (the `~/ConceptDev/Projects/<repo>` folder, not a `~/conductor/workspaces/` lane): after pushing, return it to `main` — `git checkout main` — so it's clean for Conductor.
- If anything is **deliberately held** (unmerged branch, deferred item, blocker), say so explicitly: what, and why.

## 3. Handoff (this is what prevents context loss)

You don't carry session memory across workspaces, so put the handoff where the next session will find it:
- In a Conductor workspace, write it to `.context/handoff.md` (Conductor's gitignored handoff folder).
- Otherwise, give it to me inline and offer to save `.claude/HANDOFF.md`.

Keep it tight and factual:
- **Done this session** — commits / PRs (with numbers + links).
- **State now** — repo, branch, clean/dirty, what's merged vs open.
- **Next / owed** — the most important thing to pick up; anything waiting on me (decision gates).
- **Unverified / uncertain** — anything you couldn't confirm.

## Rules

- **Truth > agreement** — report what actually happened, including what failed or was skipped.
- No AI / Claude / Anthropic attribution anywhere (commits, PRs, docs).
- If nothing meaningful happened (quick question, read-only exploration), say so and skip the ceremony.
- Keep the summary under ~20 lines. Brevity is the point.
