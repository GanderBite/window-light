---
description: Start work on a GitHub issue. Reads the issue and creates and checks out a branch named <type>/<issue>-<name> from the default branch
argument-hint: "<issue number>"
model: sonnet
---

Start work on an issue of this repository by creating its branch.

Arguments: $ARGUMENTS

The argument is an issue number, with or without `#`. If it is missing or is not a number, stop and ask for it.

## 1. Read the issue

1. Run `gh auth status`. If `gh` is missing or not signed in, stop and say what the user has to do.
2. Read the issue:

   ```
   gh issue view <number> --json number,title,body,labels,state,url
   ```

3. If there is no such issue, stop and say so. Do not create a branch for an issue that does not exist.
4. If the issue is closed, stop, say so, and ask the user whether to go on.

## 2. See whether the issue already has a branch

Look for a branch whose name holds this issue number, on this computer and on GitHub:

```
git fetch origin
git branch --all --list "*/<number>-*"
```

If one exists, check it out with `git switch <branch>`, report that, and stop. One issue has one branch. Branches that end in a two-digit number and a short name, such as `feat/12-import-videos-01-capture-time`, are parts of a split made by `/pr`. They are not a second branch for the issue, so check out the one without that ending.

## 3. Choose the name

The branch name is:

```
<type>/<number>-<name>
```

**type** says what kind of work the issue asks for. It is one of the commit types in `.claude/rules/commits.md`. Choose it from the issue's labels first:

| Label on the issue | Type |
|---|---|
| `bug` | `fix` |
| `enhancement` | `feat` |
| `documentation` | `docs` |

With none of these labels, or with labels that disagree, read the title and the description and choose by the table of types in `.claude/rules/commits.md`. An issue that asks for a capability a user can notice is `feat`, even when most of its work is internal.

**name** says what the issue is about, in the words of its title:

- two to five words, lowercase, joined by hyphens;
- letters and digits only, with no accents and no punctuation;
- the subject, not the action: `import-videos`, not `add-support-for-importing-videos`;
- no issue number and no type in it, since both are already in the branch name.

Examples: `feat/12-import-videos`, `fix/31-video-capture-time`, `docs/7-build-instructions`.

## 4. Create the branch

1. Find the default branch: `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
2. Bring it up to date: `git fetch origin <default>`.
3. Create the branch from it and check it out:

   ```
   git switch --no-track -c <type>/<number>-<name> origin/<default>
   ```

   Changes that are not committed come along to the new branch. If git refuses because they would be overwritten, stop and tell the user. Do not stash or discard anything.

## 5. Report

In a few lines:

- the branch that is now checked out;
- the issue's title and address;
- what the issue asks for, in one or two sentences;
- whether changes that were not committed came along;
- that every commit on this branch starts its description with `#<number>`, as `.claude/rules/commits.md` says.

## Limits

- Do not change the issue: no comment, no assignee, no label.
- Do not commit, push or open a pull request.
