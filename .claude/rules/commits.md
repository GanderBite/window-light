# Commit messages

Every commit in this repository follows Conventional Commits 1.0.0 and names the issue it belongs to. A hook checks each commit before it is made and rejects a message that breaks this format.

## Format

```
<type>[(<scope>)][!]: #<issue> <description>

[body]

[footers]
```

## Header

- **type** is required, lowercase, and one of:

  | Type | Use it when the commit |
  |---|---|
  | `feat` | adds a capability the user can notice |
  | `fix` | repairs a bug |
  | `docs` | changes documentation only |
  | `style` | changes formatting only, with no change in behaviour |
  | `refactor` | restructures code without changing behaviour |
  | `perf` | makes something faster or lighter without changing behaviour |
  | `test` | adds or corrects tests only |
  | `build` | changes the Xcode project, packages or build settings |
  | `ci` | changes continuous-integration configuration |
  | `chore` | does maintenance that fits no other type |
  | `revert` | undoes an earlier commit |

- A commit that adds a capability must be `feat`. A commit that repairs a bug must be `fix`. Never hide either under another type.
- **scope** is optional. It is one noun naming the part of the codebase the commit touches, in parentheses: `feat(domain):`, `fix(import):`. Letters, digits, `.`, `_`, `/` and `-` only.
- **`!`** directly before the colon marks a breaking change: `refactor(application)!:`.
- **issue** is required. It is the number of the GitHub issue the work belongs to, written as `#` and the number, directly after the colon and one space: `feat(domain): #12 …`. Take it from the name of the branch, never from memory. The section on branches says where it is.
- **description** follows the issue number and one space. Write it in the imperative ("add", not "added" or "adds"), say what the commit does, and do not end it with a period.
- The whole header, issue number included, is at most 72 characters.

## Branches

Work happens on a branch that belongs to one issue. Its name is:

```
<type>/<issue>-<name>
```

`<type>` is one of the commit types above, `<issue>` is the issue number, and `<name>` is a few lowercase words joined by hyphens: `feat/12-import-videos`, `fix/31-video-capture-time`. The `/checkout` command creates such a branch from an issue.

- Every commit on the branch carries that branch's issue number. The hook compares the two and rejects a different number.
- A branch without an issue number in its name cannot be committed to. That includes the default branch.
- Branches that `/pr` makes when it splits a large branch keep the beginning of the name, so they carry the same issue number: `feat/12-import-videos-01-capture-time`.

## Body and footers

- One blank line separates the header from the body. The body says why the change was made and what is different from before. It does not retell the diff.
- Footers come after one more blank line, one per line, as `Token: value` or `Token #value`. A token uses hyphens in place of spaces: `Refs: #40`, `Reviewed-by: Name`, `Co-Authored-By: Name <email>`.
- A breaking change is announced by `!` in the header, by a footer `BREAKING CHANGE: <what breaks>`, or by both. `BREAKING CHANGE` is always written in capitals.
- A `feat`, `fix` or breaking commit includes its entry in `CHANGELOG.md`. When no user can notice the change, the commit says so with the footer `Changelog: none (<reason>)`. The rule on the changelog has the details.

## One commit, one purpose

Pull requests here are merged by rebase, so every commit stays in the history and must make sense alone. If the description needs "and", make two commits.

## Examples

```
feat(domain): #12 place pictures in slots by capture time
```

```
fix(import): #31 keep the capture time of videos without metadata

Videos exported from some editors carry no capture time. They were
placed in the Night slot. They now go to the first empty slot.
```

```
refactor(application)!: #18 return wallpapers through one library port

BREAKING CHANGE: WallpaperStore is removed. Adapters now implement
WallpaperLibrary.
```

## How to commit

- Read the issue number from the branch name: `git branch --show-current`.
- Pass the message on the command line with `-m`, or with a heredoc inside `-m "$(cat <<'EOF' … EOF)"`. Never rely on an editor opening.
- To undo a commit, run `git revert --no-commit <commit>` and then commit with a `revert:` header that names what is undone.
