---
description: Bring CHANGELOG.md up to date, add one entry, or turn Unreleased into a released version
argument-hint: "[release <version> | <what changed>]"
model: sonnet
---

Maintain `CHANGELOG.md` at the root of this repository.

`.claude/rules/changelog.md` says what belongs in the changelog, how the file is laid out and how an entry is worded. Read it now unless it is already in your context, and follow it exactly.

Arguments: $ARGUMENTS

## Choose what to do

- No arguments: **update**.
- `release <version>`: **release**.
- Anything else: **add**. The arguments describe one change.

## Before anything else

1. If `CHANGELOG.md` does not exist, create it with this content and nothing more:

   ```
   # Changelog

   All notable changes to Window Light are recorded here.
   The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

   ## [Unreleased]
   ```

2. Find the repository's web address with `git remote get-url origin` and turn it into its `https://github.com/<owner>/<repository>` form. If there is no remote, leave the links at the bottom of the file out and say so in your report.

## Update

1. Find where the changelog was last brought up to date: the newest commit that changed it (`git log -1 --format=%H -- CHANGELOG.md`). If there is none, use the newest version tag. If there is none either, start from the first commit.
2. Read every commit after that point (`git log --reverse <point>..HEAD`) and the changes that are not committed yet (`git status`, `git diff HEAD`).
3. For each change, decide by the rule whether a user can notice it. A commit message often names the code and not the outcome. When it does, read the diff, and the feature's file in `docs/features`, until you can say what the user sees.
4. Write the entries under `## [Unreleased]`:
   - Put several commits that make up one change the user notices into one entry.
   - Do not repeat an entry that is already there.
   - When a commit changes or repairs something that is itself still under `Unreleased`, edit or remove that entry. Do not add a `Fixed` line for a bug no user ever had.
5. Make the link for `Unreleased` at the bottom of the file correct.
6. Report in a few lines: the entries you added or changed, and which changes you left out and why.

## Add

1. Decide by the rule whether a user can notice the change described in the arguments. If not, say so and change nothing.
2. Otherwise write one entry for it, in the user's words, under the right heading of `## [Unreleased]`.

## Release

1. Stop and explain, without changing the file, if the version is not of the form `<major>.<minor>.<patch>`, if it is not higher than the newest released version, or if it does not fit what `Unreleased` holds by the rule's section on versions.
2. Do everything under **Update** first, so nothing is missing.
3. Stop and say so if `Unreleased` is still empty.
4. Put `## [<version>] - <today>` directly under a new, empty `## [Unreleased]`, and move every entry under it. Take today's date from `date +%F`.
5. If this version needs a newer macOS or stops supporting some Macs, state that in a bold line directly under the version header.
6. Remove headings that have no entries.
7. Update the links at the bottom:
   - `[Unreleased]: <address>/compare/v<version>...HEAD`
   - `[<version>]: <address>/compare/v<previous version>...v<version>`, or `<address>/releases/tag/v<version>` for the first version.
8. Report the tag name the links expect, `v<version>`.

## Limits

- Change `CHANGELOG.md` only.
- Do not commit, tag, push or create a release on GitHub. The user does that.
