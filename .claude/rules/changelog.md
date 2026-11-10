# Changelog

`CHANGELOG.md` at the root of the repository tells the people who use the app what each version changes. A reader should learn in a few seconds whether to update and what will feel different. It is written for users first and developers second.

Every change a user can notice gets its entry in the same commit as the change. A hook refuses a `feat`, `fix` or breaking commit that does not include `CHANGELOG.md`.

## When an entry is needed

- The app can do something new.
- Something the app already did now behaves, looks or reads differently.
- A bug that reached a released version is fixed.
- Something is removed, or will be removed in a later version.
- A security or privacy problem is fixed.
- Any of the Mac matters listed below changes.

## When no entry is needed

- Refactoring, tests, continuous integration, build settings, documentation and dependency updates, unless they change what a user experiences.
- A change to something that is still under `Unreleased`. Edit the entry that is already there. No user ever saw the earlier state, so a bug fixed before release gets no `Fixed` line.
- A step toward a capability the user cannot reach yet. The entry is written in the commit that makes it reachable.

A `feat` or `fix` commit that needs no entry says so in a footer of its message, with the reason:

```
Changelog: none (not reachable by users yet)
```

## Mac matters that always get an entry

- **System requirements.** A higher minimum macOS version, or Macs that are no longer supported. This goes in a bold line directly under the version header, before any heading.
- **Permissions and privacy.** A new question from the system, or anything new that leaves the Mac. Say what it is for.
- **The user's data.** Anything that moves, converts or resets wallpapers, settings or remembered original wallpapers.
- **Keyboard shortcuts and menus.** Any shortcut or menu item that is added, changed or removed.
- **Getting the app.** Any change in how the app is obtained or updated.

## Format

The file follows Keep a Changelog and Semantic Versioning.

```
# Changelog

All notable changes to Window Light are recorded here.
The format follows Keep a Changelog, and versions follow Semantic Versioning.

## [Unreleased]

### Added
- Fill an empty slot with a picture relit for that time of day

## [1.1.0] - 2027-02-03

**Requires macOS 28 or later** (previously 27).

### Added
- Choose which moment of a video becomes the picture (#41)

### Changed
- The clock schedule now starts from the times you used last

### Fixed
- Restore left a second display unchanged when it had the same name as the first (#38, thanks @contributor)

[Unreleased]: https://github.com/OWNER/REPOSITORY/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/OWNER/REPOSITORY/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/OWNER/REPOSITORY/releases/tag/v1.0.0
```

- `## [Unreleased]` comes first and collects changes between releases. Released versions follow, newest first.
- A version header is `## [<version>] - <date>`, with the date as year-month-day.
- Headings appear in this order, and only when they have entries: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.
- Each entry is one line that starts with `- `.
- The bottom of the file links every version to its comparison with the version before it. The first version links to its release tag. Tags are named `v<version>`.
- A released section is never rewritten, except to correct a mistake in it.

## Versions

- **Major** (`2.0.0`): something users had set up stops working or has to be done again.
- **Minor** (`1.1.0`): the app can do something new.
- **Patch** (`1.0.1`): fixes only.

## Wording

- Write the outcome for the user, not the work in the code. "Fixed a crash when a video without sound was imported" is an entry. "Refactor FrameExtractor" is not.
- Use the product's words from `docs/features`: wallpaper, picture, slot, schedule, apply, restore.
- Never name a type, a module or a layer.
- One entry for one change the user notices, however many commits it took.
- Say where the user finds it when that is not obvious: `Settings → General`.
- Link the issue or pull request in parentheses at the end, and thank a contributor from outside the project: `(#38, thanks @contributor)`.
- Do not end a one-sentence entry with a period.

## Keeping it up to date

The `/changelog` command brings `Unreleased` up to date from the commits since the changelog last changed, and `/changelog release <version>` turns `Unreleased` into a released version.
