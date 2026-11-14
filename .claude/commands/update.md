---
description: Bring the checked-out branch up to date with the default branch. Rebases it, resolves the conflicts and pushes with --force-with-lease. A branch that is part of a git-spice stack is updated together with the rest of its stack
argument-hint: "[extra context]"
model: sonnet
---

Bring the branch that is checked out up to date with the repository's default branch, by rebasing it onto the newest commit of that branch. Resolve the conflicts on the way, and update the copy on GitHub.

A branch that stands alone is rebased with git. A branch that is part of a stack is never rebased with git alone: `git-spice` restacks the whole stack, so the branches above and below stay in step.

Arguments: $ARGUMENTS

Anything given is context for resolving conflicts.

## 1. Check that the branch can be updated

1. Find the branch with `git branch --show-current`, and the default branch with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
2. Stop if no branch is checked out, or if the checked-out branch is the default branch. There is nothing to rebase.
3. Look at `git status`. Stop and say so if a rebase, a merge, a cherry-pick or a revert is already in progress.
4. Stop if a file git knows has changes that are not committed: `git status --porcelain --untracked-files=no` must print nothing. Tell the user to commit them first, for example with `/commit`. Do not stash them.
5. Remember where the branch is now: `git rev-parse HEAD`. The final report names this commit, so the user can go back to it.
6. Run `git fetch origin`.

## 2. See whether the branch is part of a stack

1. If `git rev-parse --verify --quiet refs/spice/data` prints nothing, git-spice was never used in this copy of the repository. The branch stands alone. Go to step 3.
2. Otherwise ask git-spice. Call the tool `git-spice`, never `gs`:

   ```
   git-spice log short --json --no-prompt
   ```

   It prints one line per branch of the current stack. Find the line with `"current":true`. The branch is **part of a stack** when that line names a branch other than the default branch under `down`, or names any branch under `ups`. Go to step 4.
3. When there is no such line, or the line has the default branch under `down` and nothing under `ups`, the branch stands alone. Go to step 3.

## 3. A branch that stands alone

1. If the branch is on GitHub, remember where its copy there is: `git rev-parse origin/<branch>`. Then make sure that copy holds nothing this copy lacks: `git log --oneline HEAD..origin/<branch>` must print nothing. If it prints commits, stop and say so. Either someone else pushed to the branch, and the push in step 7 would remove their work, or an earlier `/update` rebased the branch here and did not push it. The user decides which it is.
2. If `git merge-base --is-ancestor origin/<default> HEAD` succeeds, the branch already holds every commit of the default branch. Say so and stop. Nothing is rebased and nothing is pushed.
3. Rebase:

   ```
   git rebase origin/<default>
   ```

4. Each time the rebase stops on a conflict, resolve it as step 5 says, then go on without an editor:

   ```
   GIT_EDITOR=true git rebase --continue
   ```

Then go to step 6.

## 4. A branch that is part of a stack

1. Run `git-spice auth status`. If it is not logged in, stop and ask the user to run `git-spice auth login` themselves. That command asks questions, so you cannot run it for them.
2. Bring in the default branch:

   ```
   git-spice repo sync --no-prompt
   ```

   This also removes the branches whose pull requests were merged, and moves the branches above them onto the default branch. If the branch you started on was removed this way, its work is merged. Say so and stop.
3. Restack the whole stack:

   ```
   git-spice stack restack --no-prompt
   ```

4. Each time it stops on a conflict, resolve it as step 5 says, then let git-spice go on with the rest of the stack:

   ```
   git-spice rebase continue --no-edit --no-prompt
   ```

   Never use `git rebase --continue` here. git-spice would not restack the branches that are still waiting.
5. Check the result with `git-spice log short --no-prompt`. The branch you started on must be checked out again, and no branch may be marked as needing a restack. If one is, run the command of point 3 again.

Then go to step 6.

## 5. Resolve a conflict

A conflict means the default branch and one commit of this branch changed the same lines. The result has to keep what both of them meant.

1. List the files: `git diff --name-only --diff-filter=U`.
2. Understand both sides before you edit anything:
   - The commit being replayed: `git show REBASE_HEAD`. In a conflicted file its lines are the lower part, after `=======`.
   - What the default branch did to the file: `git log -p REBASE_HEAD..HEAD -- <file>`. Its lines are the upper part, marked `HEAD`.
3. Edit the file so that both changes hold. Do not take one side whole unless the other side's change is already contained in it.
   - Two additions at the same place: keep both, in the order the file calls for. In `CHANGELOG.md`, keep every entry under the heading it belongs to, as `.claude/rules/changelog.md` orders them.
   - One side changed a file and the other deleted or moved it: find out why, and carry the change over to where the code lives now.
   - A file a tool writes, such as `project.pbxproj` or `Package.resolved`: keep the entries of both sides.
4. Make sure no conflict marker is left: `git diff --check` reports them. Then stage the file with `git add -- <file>`.
5. If nothing is left of the commit because the default branch already holds its change, the commit is dropped. Name it in the report. For a branch that stands alone, drop it with `git rebase --skip`. In a stack, `git-spice rebase continue` drops it by itself.

Note each conflict for the report: the file, the commit, and in one line how it was resolved.

**When you cannot tell what the right result is,** do not guess. That is the case when both sides changed the same rule in ways that cannot both hold. Put things back with `git rebase --abort`, or `git-spice rebase abort` in a stack, and stop. Tell the user which file and which two changes are in conflict. Push nothing. In a stack, the branches restacked before the conflict stay restacked on this computer. Say which ones.

## 6. Check the result

1. Compare the commits before and after:

   ```
   git range-diff origin/<default> <HEAD from step 1> HEAD
   ```

   Every commit of the branch must still be there with its header, unless step 5 dropped it. A commit that had a conflict shows as changed, or as one commit removed and one added under the same header. Any other commit must show as unchanged.
2. If a conflict was resolved, and the project has a build or tests, build it and run them. In a stack, do this on the top branch, which holds every change: `git-spice top --no-prompt`, and afterwards `git switch <branch>` to return. If something fails that passed before, the resolution is wrong. Push nothing. Report what fails, and give the user the command of step 7 to run once it is put right, because the branch is already rebased on this computer and a second `/update` would stop at the first check.

## 7. Update GitHub

**A branch that stands alone.** If the branch is on GitHub, which `git ls-remote --heads origin <branch>` shows, push it:

```
git push --force-with-lease=<branch>:<commit of origin/<branch> from step 3> origin <branch>
```

Naming the commit makes git refuse the push when the branch on GitHub has moved since step 3, even if something fetched in between.

If the branch is not on GitHub, push nothing and say so. `/commit --push` or `/pr` puts it there.

**A stack.** Let git-spice push every branch of the stack that has a pull request, and update those pull requests:

```
git-spice stack submit --update-only --no-prompt
```

In both cases the push replaces commits on GitHub, and it is refused when GitHub holds commits this copy never saw. If it is refused, stop and say so. Never use `--force`, with git or with git-spice.

## 8. Report

In a few lines:

- the branch, and for a stack every branch that was restacked;
- how many commits of the default branch it now holds that it did not hold before;
- each conflict: the file, the commit, and how it was resolved;
- any commit that was dropped because nothing was left of it;
- what was pushed, or why nothing was;
- the commit the branch pointed to before, from step 1.

## Limits

- Do not merge the default branch into the branch. The branch is rebased, so the history stays a straight line.
- Do not change what a commit does or says beyond what a conflict requires. Do not squash, reorder or drop a commit, except one of which nothing was left.
- Do not stash or discard anything.
- Do not push the default branch.
- Do not open, merge or close a pull request.
