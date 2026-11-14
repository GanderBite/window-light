---
description: Commit the changes that are not committed yet. Reads the difference from HEAD, groups it into logical commits that follow the commit rules, and creates them. With --push, also pushes the branch to GitHub
argument-hint: "[--push] [extra context]"
model: sonnet
---

Turn the changes that are not committed yet into commits, one commit per purpose.

`.claude/rules/commits.md` says how a commit is cut and how its message is written. `.claude/rules/changelog.md` says which commits need a changelog entry. Read both now unless they are already in your context, and follow them exactly.

Arguments: $ARGUMENTS

- `--push` pushes the branch to GitHub after the commits are made.
- Anything else is context. It can give reasons for the commit messages, or narrow the job: `only the hooks` commits those changes and leaves every other change as it is.

## 1. Check that commits can be made

1. Find the branch with `git branch --show-current`. Its name has the form `<type>/<issue>-<name>`. If it holds no issue number, stop: a commit must name its issue. That includes the default branch and a checkout with no branch. Tell the user to start from an issue with `/checkout <issue number>`.
2. Look at `git status`. Stop and say so if a merge, a rebase, a cherry-pick or a revert is in progress, or if a file has a conflict that is not resolved.
3. Stop and ask the user if a file is staged but is no longer in the working tree. Step 4 empties the staging area, and that file's content would be lost.
4. Remember where the branch is now: `git rev-parse HEAD`.
5. If there is nothing to commit, say so. With `--push`, go to step 6. Otherwise stop.

## 2. Read the changes

```
git status --porcelain --untracked-files=all
git diff HEAD
```

- `git diff HEAD` shows every change to a file git already knows, staged or not.
- It shows no new file. `git status` lists them one by one. Read each new file. For a binary file or one a tool writes, it is enough to know what it is.
- Read the code around a change where the difference alone does not explain it.
- Read what the issue asks for: `gh issue view <issue> --json title,body`. It is the reason the branch exists. If `gh` cannot answer, go on without it.

Changes that are staged are regrouped with all the others. What gets committed is what is in the working tree.

### What stays out

Leave a file out of every commit, and name it in the final report, when it is one of these:

- something that holds a secret: a key, a token, a password, an `.env` file;
- something only this computer needs or a build writes: `.DS_Store`, `xcuserdata`, `DerivedData`, `.build`, `.claude/settings.local.json`;
- something the arguments excluded.

Do not edit `.gitignore` to hide such a file. Say in the report that it is not ignored.

## 3. Group the changes

Divide the changes into groups. Each group becomes one commit.

- **One purpose per group.** If the header of a commit would need "and", it is two groups.
- **A group makes sense alone.** Pull requests are merged by rebase, so every commit stays in the history. Do not cut apart changes that only work together, and do not make one commit per file.
- **Order by dependency**, lowest first, so no commit needs one that comes after it. The layers give the usual order: `Domain`, `Application`, `Infrastructure`, `Presentation`, `Features`, and last the part that connects them.
- **Mechanical changes go first, in a group of their own**: renames, moves and formatting.
- **Tests travel with the code they test.**
- **A rule, a hook and the setting that switches it on travel together** when one is useless without the others.
- Keep one file's changes in one group unless they clearly serve different purposes.

Choose the type of each commit by what that commit does, from the table in `.claude/rules/commits.md`. The type of the branch does not decide it. A group that adds a capability is `feat` and a group that repairs a bug is `fix`, however small.

### The changelog

- A changelog entry that is already in the difference travels with the group it describes. When `CHANGELOG.md` holds entries for several groups, each group takes only its own lines.
- A `feat`, `fix` or breaking group with no entry in the difference: decide by the rule whether a user can notice the change.
  - If a user can, write the entry as the **Add** part of `.claude/commands/changelog.md` describes, and put it in that group. This is the only edit to the change this command makes.
  - If no user can, the commit ends with the footer `Changelog: none (<reason>)`.

## 4. Create the commits

Empty the staging area first, so each commit holds its group and nothing else. This changes no file:

```
git reset --quiet
```

Then, for each group, lowest first:

1. **Stage the group, in a command of its own.**
   - Whole files: `git add -- <paths>`. Name a deleted file the same way, and name both the old and the new path of a file that moved.
   - Part of a file: write `git diff HEAD -- <file>` to a temporary file outside the repository, keep only this group's hunks in it, and stage it with `git apply --cached --recount <patch>`. When one hunk holds lines of two groups, remove the other group's `+` lines and turn its `-` lines into unchanged lines. Never use `git add -p`: it asks questions.
2. **Check what is staged**: `git diff --cached --stat`, and `git diff --cached` after staging part of a file. It must be the group, whole and alone.
3. **Commit, in a command of its own, one commit per command:**

   ```
   git commit -m "$(cat <<'EOF'
   <type>[(<scope>)]: #<issue> <description>

   <body>

   <footers>
   EOF
   )"
   ```

   - Type the whole message into the command, with the issue number from the branch name. Never build it from a variable or from another command.
   - The header is at most 72 characters, issue number included.
   - The body says why the change was made and what is different from before. It does not retell the difference. Leave it out when the header says everything.

A hook checks every commit before it is made. It reads the message from the command and looks at what is staged at that moment, which is why staging and committing are separate commands. When it refuses a commit, it says why. Correct the message or the staged files and commit again. Never look for a way around the hook.

If a commit cannot be made, stop. The commits made so far stay. Leave the rest uncommitted, and do not push.

## 5. Check that nothing was lost

```
git status --short
git log --oneline <HEAD from step 1>..HEAD
```

`git status` must show only the files that step 2 left out. If it shows anything else, a change was missed: put it in a commit of its own or explain in the report why it stays.

## 6. Push

Only with `--push`, and only when every planned commit was made.

1. List what will go to GitHub: `git log --oneline HEAD --not --remotes=origin`. That is every commit of the branch GitHub does not have, including ones made before this run. If the list is empty, there is nothing to push. Say so.
2. Push the branch:

   ```
   git push --set-upstream origin <branch>
   ```

3. If GitHub rejects the push, the branch there holds commits this copy does not have. Stop and say so. Do not force the push, and do not pull or rebase to make it fit.

## 7. Report

One row per commit made, in order:

| Commit | Header | Files |
|---|---|---|

Then, in a few lines:

- the files that were left out, and why;
- any changelog entry this command wrote;
- whether the branch was pushed, and how many commits went. Without `--push`, say that the commits exist only on this computer.

## Limits

- Do not change the content of the change. The only exception is a missing changelog entry.
- Do not amend, squash, reorder or rewrite a commit that already exists.
- Do not stash, discard or restore anything in the working tree.
- Do not push without `--push`, and never force a push.
- Do not open a pull request. `/pr` does that.
