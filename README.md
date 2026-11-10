# Window Light

Window Light is a free, open-source Mac app that turns your own pictures and videos into a wallpaper that changes through the day.

You choose two to eight images or videos. The app gives each one a time of day, from dawn to night, and builds a single wallpaper out of them. You apply it once and quit the app. From then on macOS changes the picture by itself, following the sun where you live or the clock times you set.

## Status

Early development. There is no release yet.

## What it will do

- Build a wallpaper from two to eight of your own images or videos.
- Place each picture in a time of day by the time it was taken, and let you rearrange freely.
- Follow the sun (the default) or fixed clock times.
- Apply to all displays or to the ones you choose, and put your earlier wallpaper back when you ask.
- Optionally fill times of day you have no picture for, using Apple's Image Playground on Macs that support it.

Nothing keeps running after you quit, and the app collects no data.

## Requirements

- macOS 27 or later.
- Xcode, to build from source. Build instructions will be added with the first code.

## Contributing

Contributions are welcome.

- Open pull requests against the `main` branch.
- Pull requests are merged with "Rebase and merge", so keep each commit meaningful on its own.
- Do not add pictures, videos or other material you don't own, including anything made by Apple.

## Working with Claude Code

The repository carries its own [Claude Code](https://claude.com/claude-code) configuration in `.claude/`. Everyone who works on the project with Claude gets the same rules, the same checks and the same commands. The only things to set up are the plugins and the tools listed at the end of this section.

```
.claude/
├── settings.json   switches on the hooks and the plugins
├── rules/          what the code, the commits and the changelog must look like
├── hooks/          scripts that check Claude's work against the rules
│   └── tests/      the hooks' own tests
├── commands/       the project's slash commands
└── skills/         knowledge Claude loads when a task calls for it
lefthook.yml        runs the same checks from git, for commits made by hand
```

### Rules

A rule is a short document that says how something in this project is done. Claude reads every rule at the start of a session, and they outrank its defaults. They are written for people as well: read them before you contribute.

| Rule | What it says |
|---|---|
| [`architecture.md`](.claude/rules/architecture.md) | The app has five layers: `Domain`, `Application`, `Infrastructure`, `Presentation` and `Features`. The rule says what each layer holds, which layers it may import, and where new code goes. |
| [`system-design.md`](.claude/rules/system-design.md) | Domain objects own their rules and cannot be invalid. Modules hide a lot of work behind a small interface. A failure never crashes the app, never disappears and never leaves data half changed. |
| [`validation-and-errors.md`](.claude/rules/validation-and-errors.md) | Which layer checks what, which errors each layer defines, and how a failure travels from a framework to a state on screen. |
| [`comments.md`](.claude/rules/comments.md) | Swift code carries no comments. The names in the code explain it. |
| [`commits.md`](.claude/rules/commits.md) | Every commit follows Conventional Commits and names its issue: `feat(domain): #12 place pictures in slots`. Every branch belongs to one issue: `feat/12-import-videos`. |
| [`changelog.md`](.claude/rules/changelog.md) | What goes into `CHANGELOG.md`, how an entry is worded for the people who use the app, and how versions are numbered. |

### Hooks

A hook is a script that Claude Code runs at a fixed moment. The hooks here refuse work that breaks a rule, before it is written or committed. They check what Claude does. Commits you make by hand are checked by the same scripts through git, as the next section says.

| Hook | Runs | What it enforces |
|---|---|---|
| `check-commit.py` | before Claude runs a shell command | A commit made with `git` or `git-spice` has a message in the required form: an allowed type, the issue number of the branch, a header of at most 72 characters. The branch name carries an issue number. The message is written out in the command, so no editor opens and nothing is hidden in a variable. A `feat`, `fix` or breaking commit includes `CHANGELOG.md`, or says why not in a `Changelog: none (<reason>)` footer. A plain `git revert` is refused, because it writes a message of its own. |
| `check-swift-source.py` | before Claude writes or edits a Swift file | No comments in any Swift file, tests included, apart from directives a tool reads. Outside tests: no import that the file's layer may not know, no `try!` and no empty `catch`. Only what the change adds is judged, never what was already in the file. |
| `review-design-rules.py` | when Claude is about to finish | If Swift files were changed, Claude has to read them once more and check what no script can check: business rules in the right layer, rich domain objects, deep modules, and errors mapped at each boundary. |
| `inject-rule.py` | when Claude starts a subagent | The subagent receives all six rules, so delegated work follows them too. |

`review_queue.py` is shared by two of the hooks. It remembers which Swift files a session changed, so the design review covers exactly those.

The hooks have tests. Run them after you change a hook, a rule or `settings.json`:

```
python3 .claude/hooks/tests/test_hooks.py
```

### Git hooks

A commit made by hand in a terminal never passes through Claude Code, so [lefthook](https://lefthook.dev) runs the same two checks from git. `lefthook.yml` at the root of the repository connects them:

| Git hook | Runs | What it enforces |
|---|---|---|
| `commit-msg` | when git has the message of a commit | The same as `check-commit.py` above: the form of the message, the issue number of the branch, and the changelog for a `feat`, `fix` or breaking commit. A message written in an editor is fine here. |
| `pre-commit` | before git makes a commit that holds Swift files | The same as `check-swift-source.py` above, on the files as they are staged. |

Git hooks are not part of a clone. Switch them on once, in your copy of the repository:

```
brew install lefthook
lefthook install
```

Two limits are worth knowing. `git commit --no-verify` skips both checks, and nothing forces anyone to run `lefthook install`. The design review and the rules given to subagents have no counterpart in git.

### Commands

A command is a task Claude carries out the same way every time. Type it in Claude Code. Together the commands cover the path from an issue to a pull request:

| Command | What it does |
|---|---|
| `/checkout <issue>` | Starts work on a GitHub issue. Reads the issue, then creates and checks out its branch from the default branch, named `<type>/<issue>-<name>`. |
| `/commit [--push]` | Commits the changes that are not committed yet. Reads the difference from `HEAD`, groups it into logical commits, one per purpose, and creates them with messages that follow the rules. Writes the changelog entry when a change a user can notice has none. With `--push`, also pushes the branch to GitHub. |
| `/update` | Brings the checked-out branch up to date with the default branch. Rebases it, resolves the conflicts and pushes with `--force-with-lease`. A branch that is part of a git-spice stack is restacked and pushed together with the rest of its stack. |
| `/pr [draft] [single]` | Opens pull requests for the checked-out branch. A change of up to 400 lines to review becomes one pull request. A larger one is split into a stack of small branches with git-spice. Each pull request gets a title, a short description of what and why, and one label that says how closely to review it: `critical`, `high`, `medium` or `low`. |
| `/changelog` | Brings `CHANGELOG.md` up to date from the commits since it last changed. `/changelog <what changed>` adds one entry. `/changelog release <version>` turns `Unreleased` into a released version. |

### Skills

A skill is a set of instructions and reference material that Claude loads only when a task needs it.

| Skill | What it is for |
|---|---|
| [`mac-ui-design`](.claude/skills/mac-ui-design/SKILL.md) | Deciding what a Mac interface should be before it is written: windows, sidebars, toolbars, menus, sheets and settings the way people who use a Mac expect them, Liquid Glass used with restraint, and layout, color, type, motion, accessibility and wording. It is distilled from Apple's Human Interface Guidelines, with one reference file per topic and a review checklist. |

### Plugins

`settings.json` switches on four plugins. Each one is a skill by Paul Hudson that keeps Claude's Swift code current and correct in one area. `mac-ui-design` decides what to build, and these say how to write it.

| Plugin | Area | Source |
|---|---|---|
| `swiftui-pro` | SwiftUI | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) |
| `swiftdata-pro` | SwiftData | [twostraws/SwiftData-Agent-Skill](https://github.com/twostraws/SwiftData-Agent-Skill) |
| `swift-concurrency-pro` | Swift concurrency | [twostraws/Swift-Concurrency-Agent-Skill](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) |
| `swift-testing-pro` | Swift Testing | [twostraws/Swift-Testing-Agent-Skill](https://github.com/twostraws/Swift-Testing-Agent-Skill) |

The settings switch the plugins on. If your Claude Code does not have one of them yet, add its source and install it, once:

```
claude plugin marketplace add twostraws/SwiftUI-Agent-Skill
claude plugin install swiftui-pro@swiftui-agent-skill
```

The name after `@` is the source's repository name in lowercase: `swiftdata-agent-skill`, `swift-concurrency-agent-skill`, `swift-testing-agent-skill`.

### Tools you need

- Python 3, which runs the hooks. macOS with Xcode's command line tools has it.
- [lefthook](https://lefthook.dev), installed in your copy with `lefthook install`. It runs the hooks for commits made by hand.
- The [GitHub CLI](https://cli.github.com) (`gh`), signed in. The commands read issues and open pull requests with it.
- [git-spice](https://abhinav.github.io/git-spice/), signed in with `git-spice auth login`. `/pr` and `/update` manage stacked branches with it.

## License

[MIT](LICENSE). Copyright (c) 2026 Michał Gąsiorek - GanderBite.

Copies and substantial portions of this code must keep the copyright notice and the license text.

Window Light is an independent project and is not affiliated with or endorsed by Apple Inc.
