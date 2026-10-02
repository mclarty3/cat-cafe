---
name: commit-split
description: Commit and push in this repo's branch layout. Design-doc changes (docs/) go to main through a temporary worktree; prototype work goes to ryan; then main is merged into ryan. Use whenever the user asks to commit or push, especially when both docs/ and code changed.
---

# Commit split

Branch layout: `main` holds the **design docs only** (`docs/`). `ryan` holds the Godot prototype, branched from `main`.
`darren` is a teammate's branch: never touch it. Only commit or push when the user asks.

## 0. Look first
```bash
git branch --show-current          # expect: ryan
git status --short
git fetch -q
```
- **Never commit `scenes/main.tscn`** if its only change is stripped `uid=` attributes. Godot keeps re-saving it.
  Leave it out of every commit.
- Sort changes into **design docs** (`docs/**`) and **everything else**. Slice docs (`CAFE_SLICE.md`,
  `DUNGEON_SLICE.md`, `README.md`, `CLAUDE.md`) are "everything else": they stay on `ryan`.

## 1. Design docs → main (only if `docs/` changed)
Use a temporary worktree so the user's `ryan` working copy is never switched or disturbed:

```bash
git diff --quiet origin/main HEAD -- docs/ && echo "ok: ryan's committed docs match main"
W="<scratchpad>/main-wt"
git worktree add -q "$W" main
cp <each changed docs file> "$W/docs/"      # quote paths: "docs/Decision Log.md"
cd "$W" && git add docs && git commit -F - <<'EOF'
<message>
EOF
git push origin main
cd - && git worktree remove "$W"
git checkout -- <the same docs files>         # they now come back in via the merge in step 3
```
If the check fails (`main`'s docs have moved on independently), stop and merge or rebase carefully instead of
copying files over.

## 2. Everything else → ryan
```bash
git add -A -- . ':!scenes/main.tscn'
git commit -F - <<'EOF'
<message>
EOF
```

## 3. Sync and push
```bash
git merge --no-edit main                      # brings the docs commit into ryan; never rebase ryan (it's pushed)
git push origin ryan
git fetch -q && git status -sb | head -1      # confirm ryan == origin/ryan
```
Plain pushes only. If a push is rejected, investigate; don't force-push.

## Messages
A short imperative subject, a blank line, then a few bullets on what and why. End with the attribution trailer
the harness specifies. Report the commit hashes, what went where, and anything deliberately left out (usually
`scenes/main.tscn`).
