---
description: Open pull requests for the checked-out branch into the default branch. Measures the change, splits a large branch into a stack of small logical branches with git-spice, and gives each pull request a short description and an importance label
argument-hint: "[draft] [single] [extra context]"
---

Open pull requests on GitHub for the branch that is checked out. A small branch becomes one pull request. A large one is split into a stack of small branches, each with a pull request of its own, managed with `git-spice`.

Arguments: $ARGUMENTS

- `draft` opens every pull request as a draft.
- `single` opens one pull request whatever the size, and skips steps 4 and 5.
- Anything else is context for the descriptions.

The target is always the repository's default branch. The issue the work belongs to is read from the branch name.

## 1. Check that pull requests can be opened

1. Run `gh auth status`. If `gh` is missing or not signed in, stop and say what the user has to do.
2. Run `git-spice --version`. If it is missing, stop and tell the user to install git-spice. Call the tool `git-spice`, never `gs`: on a Mac `gs` can be a different program.
3. Run `git-spice auth status`. If it is not logged in, stop and ask the user to run `git-spice auth login` themselves and choose the CLI method, which reuses the `gh` login. That command asks questions, so you cannot run it for them.
4. Find the branch with `git branch --show-current`, and the target with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
5. Stop if the checked-out branch is the target. A pull request needs a branch of its own.
6. Read the issue number from the branch name, which has the form `<type>/<issue>-<name>`. If the name holds no issue number, stop: every pull request must say which issue it closes. Tell the user to start from an issue with `/checkout <issue number>`.
7. Read the issue: `gh issue view <issue> --json number,title,body,state,url`. If it does not exist, stop and say so. If it is closed, say so in the final report.
8. Make sure git-spice knows the repository and the branch. Both commands are safe to repeat:

   ```
   git-spice repo init --trunk <target> --remote origin
   git-spice branch track --base <target>
   ```

9. Run `git fetch origin <target>`, then list the commits the branch carries: `git log --reverse origin/<target>..HEAD`. Stop if there are none.
10. Look at `git status`. Changes that are not committed are not part of any pull request. Do not commit them. If the branch has to be split, stop here and ask the user to commit or stash them first, because splitting needs a clean working tree.
11. Check whether the branch already has a pull request: `gh pr view --json number,url,state,isDraft`. Remember the answer for steps 5 and 8.

## 2. Understand the change

Read the code, not only the commit messages.

1. Read the whole difference: `git diff origin/<target>...HEAD`. Read the files around it where the difference alone does not explain itself.
2. Read the commit messages for the reasons the author gave.
3. Read what the issue asks for. It is the reason the branch exists.
4. If the change belongs to a feature, read that feature's file in `docs/features`.
5. Work out two things before you write anything:
   - **What**: what the code does now.
   - **Why**: what was missing, wrong or in the way before this change.

Then check the branch against the project rules:

- If the change does something the issue does not ask for, or leaves out something it does ask for, say so in the final report.
- If the change is one a user can notice and `CHANGELOG.md` is not in the difference, stop and say so. `.claude/rules/changelog.md` decides what a user can notice.
- If a commit header does not follow `.claude/rules/commits.md`, say which one in your final report.

## 3. Measure the change

```
git diff --shortstat origin/<target>...HEAD
git diff --numstat origin/<target>...HEAD
```

Work out three numbers and keep them for the final report:

- **Inserted** and **deleted** lines in total.
- **Lines to review**: inserted plus deleted, leaving out files no one reviews line by line. Those are files a tool writes (`*.xcodeproj/project.pbxproj`, `Package.resolved`, the `Contents.json` files of asset catalogs) and binary files, which `--numstat` shows with `-`.

## 4. Decide: one pull request or a stack

A reviewer reads a small pull request properly and skims a large one. The limit is **400 lines to review** per pull request.

Open **one** pull request when both are true:

- the lines to review are 400 or fewer;
- the branch has one purpose, so one title can describe all of it.

Otherwise **split** it. Two exceptions keep a large change whole. Say so in the final report when you use one:

- the argument `single` was given;
- the change cannot be divided without leaving a branch that does not build, as with one mechanical rename across many files.

### Plan the split

Divide the change into groups. Each group becomes one branch and one pull request.

- **One purpose per group.** A reviewer should be able to hold the whole group in mind.
- **Order by dependency**, lowest first, so every branch builds on the ones below it. This project's layers give the usual order: `Domain`, `Application`, `Infrastructure`, `Presentation`, `Features`, and last the part that connects them.
- **Mechanical changes go first, in a group of their own**: renames, moves and formatting. They are large and quick to review, and they keep the later groups small.
- **Tests travel with the code they test.**
- **The `CHANGELOG.md` entry travels with the group that makes the change reachable by users.**
- **Each group is 400 lines to review or fewer** where the change allows it. A group that cannot be made smaller stays as it is.
- **Every branch builds and passes its tests without the branches above it.**
- Keep one file's changes in one group unless they clearly serve different purposes.

Name the branches `<branch>-<two-digit number>-<short-name>`, for example `import-videos-01-capture-time`. Do not put a `/` after the original branch name: git cannot hold a branch and a folder of branches with the same name.

Show the user the plan as a table with the order, the branch name, the purpose in a few words and the lines to review, and ask them to confirm. Change nothing until they do.

## 5. Build the stack

Skip this step for a single pull request.

**When the existing commits already match the groups, in order,** split the branch at those commits. The original branch name stays on the last group:

```
git-spice branch split --at <last commit of group 1>:<name 1> --at <last commit of group 2>:<name 2>
```

**Otherwise rebuild the change as a stack.** The original branch is left untouched and serves as the reference.

1. Bring the original branch up to date with the target, so that its difference from the target is exactly its own change: `git-spice repo sync`, then `git-spice branch restack`. If that stops on a conflict you cannot resolve with certainty, stop and tell the user.
2. Check out the target: `git-spice trunk`.
3. For each group, lowest first:
   - Bring in that group's changes from the original branch and stage them. For whole files use `git checkout <original> -- <paths>`, and `git rm` for files the change deletes. For part of a file, take the right hunks from `git diff HEAD <original> -- <file>` and stage them with `git apply --cached`.
   - Create the branch on top of the current one, with one commit:

     ```
     git-spice branch create <name> -m "<commit header>" -m "<body>"
     ```

     The message follows `.claude/rules/commits.md`. A `feat` or `fix` commit whose group does not hold the changelog entry ends with the footer `Changelog: none (<reason>)`, as `.claude/rules/changelog.md` describes.
   - Build the branch and run its tests when the project has a build. Fix the grouping if a branch does not stand alone.
4. Prove nothing was lost or invented: `git diff <original> HEAD` on the top branch must print nothing. If it prints anything, correct the stack before going on.
5. Show the result with `git-spice log short`.

If the original branch already had a pull request, that pull request is now replaced by the stack. Do not close it. Tell the user in the final report, so they can close it.

## 6. Write a title and a description for each pull request

Do this once per branch, from that branch's own difference. In a stack that is `git diff <branch below>...<branch>`.

**Title.** One line in the form of a commit header from `.claude/rules/commits.md`: `<type>[(<scope>)][!]: #<issue> <description>`, at most 72 characters. It names the one purpose of that pull request.

**Description.** It has two sections, and a third only when a diagram helps. Nothing else: no greeting, no summary of the summary, no checklist, no closing remarks.

```
## What

## Why

## Diagram
```

- **What.** What the code in this pull request does. Three to six bullets, one line each. Each bullet names a behaviour, not a file.
- **Why.** Why the change was needed. One to three sentences. Name the feature or acceptance criterion it serves when there is one (`F06`, `AC-F06-07`). The section always ends with a line of its own that names the issue:
  - `Closes #<issue>` on a single pull request, and on the top pull request of a stack, which completes the work;
  - `Part of #<issue>` on every other pull request of a stack, so that merging it does not close the issue early.

Keep it short and exact:

- Every sentence carries a fact a reviewer needs. Cut any sentence that could be removed without losing one.
- No adjectives that judge the work ("robust", "clean", "comprehensive"), no filler ("this PR aims to", "it is worth noting"), no account of how you worked.
- Say it once. Do not repeat the title in **What**, or **What** in **Why**.
- Use the product's words from `docs/features` and the names that are in the code.
- Do not list the changed files. The reviewer can see them.
- The description stands alone. Do not point to a conversation or a local file.
- Do not describe the stack. git-spice adds a comment to each pull request that shows its place in the stack.

### The diagram

Add the **Diagram** section only when a picture shows the change more clearly than the bullets do:

- a job passes through three or more parts, such as a feature, a use case, a port and an adapter: use `sequenceDiagram`;
- data is turned from one form into another in several steps, or a decision has several branches: use `flowchart TD`;
- something moves between named states: use `stateDiagram-v2`.

Add none for a change inside one type, a rename, a configuration change or a fix of a few lines.

Keep a diagram readable:

- at most about twelve boxes or participants; draw the part that changed, not the whole app;
- label with the names used in the code and the product's words;
- put any label that holds punctuation or brackets in double quotes;
- no colours and no styling;
- no text around it beyond one line saying what it shows.

Write it in a fenced block whose first line is ```` ```mermaid ````, so GitHub draws it.

## 7. Choose the importance label for each pull request

Every pull request carries exactly one of four labels. The label tells the reviewer how much depends on getting this change right, and so how closely to read it. In a stack, each pull request is judged by its own difference, so the labels usually differ.

| Label | The pull request | Examples |
|---|---|---|
| `critical` | changes how the core of the product behaves, or could lose or expose something of the user's | a business rule or invariant in `Domain`; how the user's wallpapers and settings are stored or converted; what the app changes on the Mac, such as applying or restoring a wallpaper; what leaves the Mac; access the app asks for; a breaking change |
| `high` | changes behaviour a user can notice outside those areas, or changes how layers work together | a new capability; a use case; a port or the errors it defines; an adapter; a new dependency; a change to what the hooks or the automatic checks enforce |
| `medium` | changes how the code is built without changing what it does, beyond a trivial edit | a refactor across several files; tests; build settings; interface text or layout with no change in logic |
| `low` | cannot change behaviour | removing a log, an unused variable or dead code; formatting; a rename inside one file; documentation |

How to choose:

- Judge each change in the difference, and take the **highest** level any one of them reaches. One changed rule in `Domain` makes the whole pull request `critical`, however small the rest is.
- Judge by what the code does, not by the commit type or the number of lines. A one-line change to a business rule is `critical`. A thousand-line rename is `medium`.
- Between two levels, choose the higher.

The labels exist in the repository. If `gh label list` does not show one of them, create it before use:

| Label | Color | Description |
|---|---|---|
| `critical` | `B60205` | Changes core domain behaviour, user data, or what the app changes on the Mac. Review every line. |
| `high` | `D93F0B` | Changes behaviour users notice, or a use case, port or adapter. Review carefully. |
| `medium` | `FBCA04` | Internal change of limited reach: refactor, tests, build, interface text. Normal review. |
| `low` | `0E8A16` | No change in behaviour: dead code, logs, formatting, docs. A quick look is enough. |

```
gh label create <label> --color <color> --description "<description>"
```

## 8. Submit with git-spice

Write each description to a temporary file outside the repository. Then submit each branch, lowest first, adding `--draft` when asked:

```
git-spice branch submit --branch <name> --title "<title>" --body "$(cat <file>)" --label <label> --no-prompt
```

git-spice pushes the branch, opens the pull request against the branch below it (the target for the lowest one), and adds a comment that shows the stack.

For a pull request that existed before this run, `branch submit` pushes the new commits but keeps the old title and description. Bring it up to date, and leave it with only the label you chose:

```
gh pr edit <number> --title "<title>" --body-file <file> --add-label <label>
gh pr edit <number> --remove-label <each of the other three labels it carries>
```

Never push by hand and never force a push yourself.

## 9. Report

Report in this form, one row per pull request, lowest first:

| Pull request | Branch | Into | Label | Inserted | Deleted |
|---|---|---|---|---|---|

Then, in a few lines:

- the totals for the whole change: inserted, deleted and lines to review, and which files were left out of the lines to review;
- one sentence per label on why that level;
- for a stack: that the original branch is unchanged, and whether an older pull request now needs closing;
- anything from steps 1 and 2 the user should know;
- for a stack, what to do as it is reviewed: after a pull request is merged, `git-spice repo sync` removes the merged branch and moves the rest onto the target, and `git-spice stack submit` updates the open pull requests.

## Limits

- Do not merge, approve or close anything.
- Do not change the content of the change. Splitting re-cuts the same lines into branches. It never edits, adds or drops one.
- Do not delete or rewrite the original branch.
