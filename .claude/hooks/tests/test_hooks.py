#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HOOKS_DIRECTORY = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLAUDE_DIRECTORY = os.path.dirname(HOOKS_DIRECTORY)
RULES_DIRECTORY = os.path.join(CLAUDE_DIRECTORY, "rules")
SETTINGS_PATH = os.path.join(CLAUDE_DIRECTORY, "settings.json")
CONTEXT_LIMIT = 10000


class HookTestCase(unittest.TestCase):
    def setUp(self):
        self.project = os.path.realpath(tempfile.mkdtemp())
        self.temporary_files = os.path.realpath(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.project, True)
        self.addCleanup(shutil.rmtree, self.temporary_files, True)

    def run_hook(self, script, payload, arguments=()):
        environment = dict(os.environ, CLAUDE_PROJECT_DIR=self.project, TMPDIR=self.temporary_files)
        payload = dict({"session_id": "test-session", "cwd": self.project}, **payload)
        finished = subprocess.run(
            [sys.executable, "-B", os.path.join(HOOKS_DIRECTORY, script)] + list(arguments),
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            env=environment,
        )
        self.assertEqual(finished.returncode, 0, finished.stderr)
        return json.loads(finished.stdout) if finished.stdout.strip() else None

    def refusal_reason(self, output):
        self.assertIsNotNone(output, "the hook allowed what it should have refused")
        decision = output["hookSpecificOutput"]
        self.assertEqual(decision["permissionDecision"], "deny")
        return decision["permissionDecisionReason"]


class CommitHookTestCase(HookTestCase):
    def check(self, command):
        return self.run_hook(
            "check-commit.py",
            {"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": command}},
        )


class RepositoryTestCase(CommitHookTestCase):
    LONG_AGO = "2026-01-01T12:00:00"

    def setUp(self):
        super().setUp()
        self.git("init", "--quiet")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.com")
        self.put("README.md", "readme\n")
        self.put("CHANGELOG.md", "# Changelog\n\n## [Unreleased]\n")
        self.git("add", "-A")
        self.git("commit", "--quiet", "--date", self.LONG_AGO, "-m", "chore: #12 start the project")
        self.git("checkout", "--quiet", "-b", "feat/12-slots")

    def git(self, *arguments):
        subprocess.run(["git", "-C", self.project] + list(arguments), check=True, capture_output=True)

    def put(self, relative_path, content):
        with open(os.path.join(self.project, relative_path), "w", encoding="utf-8") as written:
            written.write(content)

    def change_code(self, stage=True):
        self.put("Slot.swift", "struct Slot {}\n")
        if stage:
            self.git("add", "Slot.swift")

    def change_changelog(self, stage=True):
        self.put("CHANGELOG.md", "# Changelog\n\n## [Unreleased]\n\n### Added\n- Slots\n")
        if stage:
            self.git("add", "CHANGELOG.md")


class ChangelogTests(RepositoryTestCase):
    def test_refuses_noticeable_commits_without_the_changelog(self):
        self.change_code()
        for command in [
            'git commit -m "feat: #12 add slots"',
            'git commit -m "fix(import): #12 keep the capture time"',
            'git commit -m "refactor!: #12 rename the library port"',
            'git commit -m "chore: #12 drop the old format" -m "BREAKING CHANGE: old wallpapers no longer open"',
            'git commit -m "feat: #12 add slots" -m "Changelog: none"',
        ]:
            with self.subTest(command=command):
                self.assertIn("CHANGELOG.md is not part of", self.refusal_reason(self.check(command)))

    def test_allows_noticeable_commit_with_staged_changelog(self):
        self.change_code()
        self.change_changelog()
        self.assertIsNone(self.check('git commit -m "feat: #12 add slots"'))

    def test_allows_commits_no_user_notices_without_the_changelog(self):
        self.change_code()
        for command in [
            'git commit -m "refactor: #12 split the placement steps"',
            'git commit -m "test: #12 cover slot boundaries"',
            'git commit -m "docs: #12 describe the layers"',
            'git commit -m "feat(domain): #12 add slots" -m "Changelog: none (not reachable by users yet)"',
            'git commit -m "fixup! feat: #12 add slots"',
            'git commit --dry-run -m "feat: #12 add slots"',
        ]:
            with self.subTest(command=command):
                self.assertIsNone(self.check(command))

    def test_sees_changelog_staged_by_the_same_command(self):
        self.change_code(stage=False)
        self.change_changelog(stage=False)
        self.assertIsNotNone(self.check('git commit -m "feat: #12 add slots"'))
        self.assertIsNotNone(self.check('git add Slot.swift && git commit -m "feat: #12 add slots"'))
        for command in [
            'git add -A && git commit -m "feat: #12 add slots"',
            'git add Slot.swift CHANGELOG.md && git commit -m "feat: #12 add slots"',
            'git commit -am "feat: #12 add slots"',
            'git commit -m "feat: #12 add slots" -- Slot.swift CHANGELOG.md',
        ]:
            with self.subTest(command=command):
                self.assertIsNone(self.check(command))

    def test_staging_everything_does_not_help_when_the_changelog_is_untouched(self):
        self.change_code(stage=False)
        refusal = self.check('git add -A && git commit -m "feat: #12 add slots"')
        self.assertIn("CHANGELOG.md is not part of", self.refusal_reason(refusal))

    def test_amend_counts_the_changelog_already_in_the_commit(self):
        self.change_code()
        self.change_changelog()
        self.git("commit", "--quiet", "-m", "feat: #12 add slots")
        self.assertIsNone(self.check('git commit --amend -m "feat: #12 add the eight slots"'))

    def test_checks_the_repository_named_with_dash_c(self):
        self.change_code()
        elsewhere = os.path.realpath(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, elsewhere, True)
        payload = {
            "tool_name": "Bash",
            "cwd": elsewhere,
            "tool_input": {"command": 'git -C "{}" commit -m "feat: #12 add slots"'.format(self.project)},
        }
        self.assertIn("CHANGELOG.md is not part of", self.refusal_reason(self.run_hook("check-commit.py", payload)))


class IssueNumberTests(ChangelogTests):
    def test_refuses_header_without_the_issue_number(self):
        self.change_code()
        refusal = self.refusal_reason(self.check('git commit -m "refactor: split the placement steps"'))
        self.assertIn("Put the issue number first", refusal)

    def test_refuses_issue_number_of_another_branch(self):
        self.change_code()
        refusal = self.refusal_reason(self.check('git commit -m "refactor: #7 split the placement steps"'))
        self.assertIn("belongs to issue #12", refusal)

    def test_refuses_commit_on_a_branch_without_an_issue_number(self):
        self.change_code()
        self.git("checkout", "--quiet", "-b", "experiments")
        refusal = self.refusal_reason(self.check('git commit -m "refactor: #12 split the placement steps"'))
        self.assertIn("carries no issue number", refusal)

    def test_new_git_spice_branch_is_judged_by_its_own_name(self):
        self.change_code()
        self.git("checkout", "--quiet", "-b", "experiments")
        allowed = 'git-spice branch create feat/12-slots-01-domain -m "refactor: #12 split the placement steps"'
        self.assertIsNone(self.check(allowed))
        for command in [
            'git-spice branch create slots -m "refactor: #12 split the placement steps"',
            'git-spice branch create -m "refactor: #12 split the placement steps"',
            'git-spice branch create feat/7-other -m "refactor: #12 split the placement steps"',
        ]:
            with self.subTest(command=command):
                self.assertIsNotNone(self.check(command))

    def test_issue_number_counts_toward_the_header_limit(self):
        self.change_code()
        command = 'git commit -m "refactor: #12 ' + "a" * 60 + '"'
        self.assertIn("limit is 72", self.refusal_reason(self.check(command)))


class GitSpiceCommitTests(ChangelogTests):
    def test_refuses_git_spice_commits_that_break_the_rules(self):
        self.change_code()
        refused_commands = {
            'git-spice branch create feat/12-slots-01-domain -m "Add slots"': "does not have the form",
            'gs bc feat/12-slots-01-domain -m "added slots"': "does not have the form",
            'git-spice commit create -m "wip"': "does not have the form",
            'gs b c feat/12-slots-01-domain --message="feat: #12 add slots"': "CHANGELOG.md is not part of",
            'git-spice branch create feat/12-slots-01-domain -m "feat: #12 add slots"': "CHANGELOG.md is not part of",
            "git-spice commit create": "would open an editor",
            'git-spice commit amend -m "Fix it"': "does not have the form",
        }
        for command, expected_explanation in refused_commands.items():
            with self.subTest(command=command):
                self.assertIn(expected_explanation, self.refusal_reason(self.check(command)))

    def test_allows_git_spice_commits_that_follow_the_rules(self):
        self.change_code()
        for command in [
            'git-spice branch create feat/12-slots-01-domain -m "refactor(domain): #12 split the placement steps"',
            'gs bc feat/12-slots-01-domain --target main -m "test(domain): #12 cover slot boundaries"',
            'git-spice branch create feat/12-slots-01-domain -m "feat(domain): #12 add slots" -m "Changelog: none (not reachable by users yet)"',
            "git-spice branch create feat/12-slots-01-domain --no-commit",
            "git-spice commit amend --no-edit",
            "git-spice branch submit --title \"feat: #12 add slots\" --body \"What\" --label high",
            "git-spice stack restack",
            "git-spice log short",
        ]:
            with self.subTest(command=command):
                self.assertIsNone(self.check(command))

    def test_git_spice_commit_with_changelog_staged_is_allowed(self):
        self.change_code()
        self.change_changelog()
        self.assertIsNone(self.check('git-spice branch create feat/12-slots-01-domain -m "feat: #12 add slots"'))


class CommitMessageTests(CommitHookTestCase):

    def test_allows_conventional_messages(self):
        allowed_commands = [
            'git commit -m "feat: #12 add wallpaper library"',
            "git commit -m 'fix(import): #12 keep the capture time of videos'",
            'git commit -am "refactor(application)!: #12 return wallpapers through one port"',
            'git commit --message="docs: #12 describe the layers"',
            'git -C /tmp/elsewhere commit -m "chore: #12 update the ignore list"',
            'git add -A && git commit -m "test(domain): #12 cover slot placement" && git status',
            'GIT_AUTHOR_DATE=now git commit -m "build: #12 add the domain package"',
            'git commit -m "feat: #12 add slots" -m "Slots are the eight times of day."',
            'git commit -m "fixup! feat: #12 add slots"',
            "git commit --amend --no-edit",
            "git commit --fixup=abc1234",
            "git commit -C HEAD~1",
            "git revert --no-commit abc1234",
            "git status && git log --oneline -5",
            "ls -la",
        ]
        for command in allowed_commands:
            with self.subTest(command=command):
                self.assertIsNone(self.check(command))

    def test_allows_conventional_message_in_heredoc_with_trailer(self):
        command = (
            "git commit -m \"$(cat <<'EOF'\n"
            "feat(domain): #12 place pictures in slots by capture time\n"
            "\n"
            "Pictures without a capture time go to the first \"empty\" slot (if any).\n"
            "\n"
            "Co-Authored-By: Claude <noreply@anthropic.com>\n"
            "EOF\n"
            ")\""
        )
        self.assertIsNone(self.check(command))

    def test_allows_conventional_message_from_standard_input(self):
        command = "git commit -F - <<'EOF'\nfix: #12 restore the original wallpaper\nEOF"
        self.assertIsNone(self.check(command))

    def test_allows_conventional_message_from_file(self):
        with open(os.path.join(self.project, "message.txt"), "w", encoding="utf-8") as message_file:
            message_file.write("perf: #12 decode video frames lazily\n")
        self.assertIsNone(self.check("git commit -F message.txt"))

    def test_refuses_messages_that_break_the_format(self):
        refused_commands = {
            'git commit -m "Add README, MIT license and Xcode .gitignore"': "does not have the form",
            'git commit -m "feature: add slots"': "not an allowed type",
            'git commit -m "Feat: add slots"': "lowercase",
            'git commit -m "feat:add slots"': "one space after the colon",
            'git commit -m "feat: #12 add slots."': "period",
            'git commit -m "feat(two words): #12 add slots"': "scope",
            'git commit -m "feat: #12 ' + "a" * 80 + '"': "limit is 72",
            'git commit -m "feat: #12 add slots\nwithout a blank line"': "blank line",
            'git commit -m "feat: #12 add slots" -m "breaking change: slots renamed"': "BREAKING CHANGE",
            'git add . && git commit -m "updated stuff"': "does not have the form",
            'cd app && (git commit -am "wip")': "does not have the form",
            "bash -c 'git commit -m \"wip\"'": "does not have the form",
            '/usr/bin/git -c user.name=x commit -m "wip"': "does not have the form",
        }
        for command, expected_explanation in refused_commands.items():
            with self.subTest(command=command):
                self.assertIn(expected_explanation, self.refusal_reason(self.check(command)))

    def test_refuses_bad_header_inside_heredoc(self):
        command = "git commit -m \"$(cat <<'EOF'\nAdd the wallpaper library\n\nbody\nEOF\n)\""
        self.assertIn("does not have the form", self.refusal_reason(self.check(command)))

    def test_refuses_messages_it_cannot_read(self):
        for command in ['git commit -m "$MESSAGE"', 'git commit -m "$(./make-message.sh)"', "git commit -F missing.txt"]:
            with self.subTest(command=command):
                self.assertIn("cannot be read", self.refusal_reason(self.check(command)))

    def test_refuses_commits_that_would_open_an_editor(self):
        for command in ["git commit", "git commit -a", "git commit --amend"]:
            with self.subTest(command=command):
                self.assertIn("would open an editor", self.refusal_reason(self.check(command)))

    def test_refuses_revert_that_writes_its_own_message(self):
        self.assertIn("--no-commit", self.refusal_reason(self.check("git revert abc1234")))

    def test_ignores_git_commit_mentioned_inside_other_text(self):
        self.assertIsNone(self.check('echo "run git commit later" > notes.txt'))
        self.assertIsNone(self.check('grep -r "git commit -m wip" docs'))


class SwiftSourceTests(HookTestCase):
    def path_of(self, relative_path):
        return os.path.join(self.project, relative_path)

    def existing_file(self, relative_path, content):
        os.makedirs(os.path.dirname(self.path_of(relative_path)), exist_ok=True)
        with open(self.path_of(relative_path), "w", encoding="utf-8") as existing:
            existing.write(content)

    def write(self, relative_path, content):
        return self.run_hook(
            "check-swift-source.py",
            {
                "hook_event_name": "PreToolUse",
                "tool_name": "Write",
                "tool_input": {"file_path": self.path_of(relative_path), "content": content},
            },
        )

    def edit(self, relative_path, old_text, new_text):
        return self.run_hook(
            "check-swift-source.py",
            {
                "hook_event_name": "PreToolUse",
                "tool_name": "Edit",
                "tool_input": {
                    "file_path": self.path_of(relative_path),
                    "old_string": old_text,
                    "new_string": new_text,
                },
            },
        )

    def test_allows_clean_source_in_every_layer(self):
        clean_sources = {
            "Sources/Domain/Slot.swift": "import Foundation\n\nstruct Slot {}\n",
            "Sources/Application/ApplyWallpaper.swift": "import Domain\nimport Foundation\n\nstruct ApplyWallpaper {}\n",
            "Sources/Infrastructure/FileLibrary.swift": "import Application\nimport Domain\nimport AppKit\n",
            "Sources/Presentation/SlotView.swift": "import SwiftUI\nimport Domain\n",
            "Sources/Features/Library/LibraryView.swift": "import SwiftUI\nimport Application\nimport Presentation\n",
            "WindowLight/WindowLightApp.swift": "import SwiftUI\nimport Infrastructure\nimport Features\n",
        }
        for relative_path, content in clean_sources.items():
            with self.subTest(path=relative_path):
                self.assertIsNone(self.write(relative_path, content))

    def test_refuses_imports_a_layer_may_not_know(self):
        forbidden_imports = {
            "Sources/Domain/Slot.swift": "import SwiftUI\n",
            "Sources/Domain/Picture.swift": "import CoreGraphics\n",
            "Sources/Domain/Wallpaper.swift": "import Application\n",
            "Sources/Domain/Schedule.swift": "@preconcurrency import Infrastructure\n",
            "Sources/Domain/Library.swift": "import struct SwiftData.ModelContext\n",
            "Sources/Application/ApplyWallpaper.swift": "import Infrastructure\n",
            "Sources/Application/ImportPictures.swift": "import AppKit\n",
            "Sources/Infrastructure/FileLibrary.swift": "import Features\n",
            "Sources/Presentation/SlotView.swift": "import Application\n",
            "Sources/Features/Library/LibraryView.swift": "import Infrastructure\n",
        }
        for relative_path, content in forbidden_imports.items():
            with self.subTest(path=relative_path):
                self.assertIn("architecture.md", self.refusal_reason(self.write(relative_path, content)))

    def test_refuses_comments(self):
        commented_sources = [
            "// holds the pictures\nstruct Wallpaper {}\n",
            "/// A wallpaper.\nstruct Wallpaper {}\n",
            "struct Wallpaper {\n    /* slots */\n}\n",
            "struct Wallpaper {}\n// MARK: - Placement\n",
            "let limit = 8 // most pictures\n",
        ]
        for content in commented_sources:
            with self.subTest(content=content):
                self.assertIn("comments.md", self.refusal_reason(self.write("Sources/Domain/Wallpaper.swift", content)))

    def test_refuses_comments_in_tests_too(self):
        refusal = self.write("Tests/DomainTests/SlotTests.swift", "import Testing\n// arrange\n")
        self.assertIn("comments.md", self.refusal_reason(refusal))

    def test_does_not_mistake_string_content_for_a_comment(self):
        sources_without_comments = [
            'let address = "https://example.com/a/*b*/"\n',
            'let text = """\n// inside a string\n/* still */\n"""\n',
            'let raw = #"a "quoted" // part"#\n',
            'let joined = "\\(prefix + "//")suffix"\n',
        ]
        for content in sources_without_comments:
            with self.subTest(content=content):
                self.assertIsNone(self.write("Sources/Infrastructure/Links.swift", content))

    def test_allows_tool_directives(self):
        self.assertIsNone(self.write("Package.swift", "// swift-tools-version: 6.2\nimport PackageDescription\n"))
        self.assertIsNone(self.write("Sources/Domain/Slot.swift", "// swiftlint:disable:next identifier_name\nlet x = 1\n"))

    def test_refuses_crashing_and_swallowed_errors_outside_tests(self):
        self.assertIn("try!", self.refusal_reason(self.write("Sources/Infrastructure/Store.swift", "let data = try! load()\n")))
        self.assertIn(
            "swallows",
            self.refusal_reason(self.write("Sources/Infrastructure/Store.swift", "do { try save() } catch {}\n")),
        )
        self.assertIsNone(self.write("Tests/InfrastructureTests/StoreTests.swift", "import Testing\nlet data = try! load()\n"))

    def test_test_targets_may_import_test_framework_and_tested_module(self):
        self.assertIsNone(self.write("Tests/DomainTests/SlotTests.swift", "import Testing\n@testable import Domain\n"))

    def test_edit_is_judged_by_the_file_it_produces(self):
        self.existing_file("Sources/Domain/Slot.swift", "import Foundation\n\nstruct Slot {}\n")
        self.assertIsNone(self.edit("Sources/Domain/Slot.swift", "struct Slot {}", "struct Slot { let name: String }"))
        self.assertIn(
            "architecture.md",
            self.refusal_reason(self.edit("Sources/Domain/Slot.swift", "import Foundation", "import Foundation\nimport SwiftUI")),
        )
        self.assertIn(
            "comments.md",
            self.refusal_reason(self.edit("Sources/Domain/Slot.swift", "struct Slot {}", "struct Slot {} // one time of day")),
        )

    def test_edit_is_not_blamed_for_what_was_already_there(self):
        self.existing_file("Sources/Domain/Slot.swift", "// old note\nimport SwiftUI\n\nstruct Slot {}\n")
        self.assertIsNone(self.edit("Sources/Domain/Slot.swift", "struct Slot {}", "struct Slot { let name: String }"))
        self.assertIsNotNone(self.edit("Sources/Domain/Slot.swift", "struct Slot {}", "// new note\nstruct Slot {}"))

    def test_ignores_files_that_are_not_project_swift_sources(self):
        self.assertIsNone(self.write("docs/notes.md", "// not swift\n"))
        self.assertIsNone(self.write(".build/checkouts/Library/Sources/Domain/File.swift", "// vendored\nimport UIKit\n"))
        outside = os.path.join(self.temporary_files, "Domain", "Outside.swift")
        self.assertIsNone(
            self.run_hook(
                "check-swift-source.py",
                {"tool_name": "Write", "tool_input": {"file_path": outside, "content": "// outside\nimport UIKit\n"}},
            )
        )


@unittest.skipUnless(shutil.which("swiftformat") and shutil.which("swiftlint"), "needs swiftformat and swiftlint")
class FormatAndLintSwiftTests(HookTestCase):
    def setUp(self):
        super().setUp()
        for configuration in (".swiftformat", ".swiftlint.yml"):
            shutil.copy(os.path.join(os.path.dirname(CLAUDE_DIRECTORY), configuration), self.project)

    def after_writing(self, relative_path, content):
        file_path = os.path.join(self.project, relative_path)
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, "w", encoding="utf-8") as written:
            written.write(content)
        environment = dict(os.environ, CLAUDE_PROJECT_DIR=self.project, TMPDIR=self.temporary_files)
        payload = {
            "session_id": "test-session",
            "cwd": self.project,
            "hook_event_name": "PostToolUse",
            "tool_name": "Write",
            "tool_input": {"file_path": file_path, "content": content},
        }
        finished = subprocess.run(
            [sys.executable, "-B", os.path.join(HOOKS_DIRECTORY, "format-and-lint-swift.py")],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            env=environment,
        )
        with open(file_path, encoding="utf-8") as kept:
            return finished, kept.read()

    def test_formats_the_written_file_in_place(self):
        finished, kept = self.after_writing("Domain/Slot.swift", "struct Slot{let name:String}\n")
        self.assertEqual(finished.returncode, 0, finished.stderr)
        self.assertEqual(kept, "struct Slot { let name: String }\n")

    def test_tells_claude_what_the_linter_found(self):
        source = "struct Slot {\n    let name: String?\n    var shown: String { name! }\n}\n"
        finished, _ = self.after_writing("Domain/Slot.swift", source)
        self.assertEqual(finished.returncode, 2)
        self.assertIn("force_unwrapping", finished.stderr)
        self.assertIn("Domain/Slot.swift", finished.stderr)

    def test_leaves_other_files_alone(self):
        for relative_path in ("docs/notes.md", "docs/notes.txt"):
            with self.subTest(path=relative_path):
                finished, kept = self.after_writing(relative_path, "struct Slot{let name:String}\n")
                self.assertEqual(finished.returncode, 0, finished.stderr)
                self.assertEqual(kept, "struct Slot{let name:String}\n")


class GitHookTestCase(RepositoryTestCase):
    def setUp(self):
        super().setUp()
        self.let_git_run("commit-msg", "check-commit.py", '--message-file "$1"')
        self.let_git_run("pre-commit", "check-swift-source.py", "--staged")

    def let_git_run(self, git_hook, script, arguments):
        hook_path = os.path.join(self.project, ".git", "hooks", git_hook)
        with open(hook_path, "w", encoding="utf-8") as hook:
            hook.write(
                '#!/bin/sh\nexec "{python}" -B "{script}" {arguments}\n'.format(
                    python=sys.executable, script=os.path.join(HOOKS_DIRECTORY, script), arguments=arguments
                )
            )
        os.chmod(hook_path, 0o755)

    def commit(self, *arguments, author_date=None, editor=None):
        environment = {name: value for name, value in os.environ.items() if not name.startswith("GIT_")}
        if author_date:
            environment["GIT_AUTHOR_DATE"] = author_date
        if editor:
            environment["GIT_EDITOR"] = editor
        return subprocess.run(
            ["git", "-C", self.project, "commit"] + list(arguments),
            capture_output=True,
            text=True,
            env=environment,
        )

    def assert_committed(self, finished):
        self.assertEqual(finished.returncode, 0, finished.stderr)

    def assert_refused(self, finished, expected_explanation):
        self.assertNotEqual(finished.returncode, 0, "git made a commit the hook should have refused")
        self.assertIn(expected_explanation, finished.stderr)

    def stage(self, relative_path, content):
        os.makedirs(os.path.dirname(os.path.join(self.project, relative_path)), exist_ok=True)
        self.put(relative_path, content)
        self.git("add", relative_path)


class GitCommitMessageTests(GitHookTestCase):
    def test_git_refuses_messages_that_break_the_rules(self):
        self.change_code()
        refused_messages = {
            "Add slots": "does not have the form",
            "refactor: split the placement steps": "Put the issue number first",
            "refactor: #7 split the placement steps": "belongs to issue #12",
            "feat: #12 add slots": "CHANGELOG.md is not part of",
        }
        for message, expected_explanation in refused_messages.items():
            with self.subTest(message=message):
                self.assert_refused(self.commit("-m", message), expected_explanation)

    def test_git_allows_messages_that_follow_the_rules(self):
        allowed_messages = [
            ["-m", "refactor: #12 split the placement steps"],
            ["-m", "feat(domain): #12 add slots", "-m", "Changelog: none (not reachable by users yet)"],
            ["-m", "fixup! feat: #12 add slots"],
        ]
        for number, message in enumerate(allowed_messages):
            with self.subTest(message=message):
                self.stage("Slot{}.swift".format(number), "struct Slot{} {{}}\n".format(number))
                self.assert_committed(self.commit(*message))

    def test_git_refuses_a_commit_on_a_branch_without_an_issue_number(self):
        self.change_code()
        self.git("checkout", "--quiet", "-b", "experiments")
        self.assert_refused(self.commit("-m", "refactor: #12 split the placement steps"), "carries no issue number")

    def test_git_allows_a_noticeable_commit_that_includes_the_changelog(self):
        self.change_code()
        self.change_changelog()
        self.assert_committed(self.commit("-m", "feat: #12 add slots"))

    def test_git_sees_the_changelog_a_commit_of_all_changes_includes(self):
        self.change_code()
        self.change_changelog(stage=False)
        self.assert_committed(self.commit("-a", "-m", "feat: #12 add slots"))

    def test_amending_counts_the_changelog_already_in_the_commit(self):
        self.change_code()
        self.change_changelog()
        self.assert_committed(self.commit("-m", "feat: #12 add slots", author_date=self.LONG_AGO))
        self.stage("Slot.swift", "struct Slot { let name: String }\n")
        self.assert_committed(self.commit("--amend", "-m", "feat: #12 add the eight slots"))

    def test_a_new_commit_does_not_borrow_the_changelog_of_the_last_one(self):
        self.change_code()
        self.change_changelog()
        self.assert_committed(self.commit("-m", "feat: #12 add slots", author_date=self.LONG_AGO))
        self.stage("Schedule.swift", "struct Schedule {}\n")
        self.assert_refused(self.commit("-m", "feat: #12 add schedules"), "CHANGELOG.md is not part of")

    def test_git_judges_the_message_without_the_comments_of_the_editor(self):
        self.change_code()
        editor_path = os.path.join(self.temporary_files, "write-header-directly-above-the-template.sh")
        with open(editor_path, "w", encoding="utf-8") as editor:
            editor.write(
                '#!/bin/sh\n'
                'printf "refactor: #12 split the placement steps\\n" > "$1.written"\n'
                'grep -v "^$" "$1" >> "$1.written"\n'
                'mv "$1.written" "$1"\n'
            )
        os.chmod(editor_path, 0o755)
        self.assert_committed(self.commit("--verbose", editor=editor_path))


class GitSwiftSourceTests(GitHookTestCase):
    HEADER = "refactor: #12 split the placement steps"

    def test_git_refuses_staged_sources_that_break_the_rules(self):
        refused_sources = {
            "Sources/Domain/Slot.swift": ("import SwiftUI\n", "architecture.md"),
            "Sources/Domain/Time Of Day.swift": ("// a time of day\nstruct TimeOfDay {}\n", "comments.md"),
            "Sources/Infrastructure/Store.swift": ("let data = try! load()\n", "try!"),
            "Tests/DomainTests/SlotTests.swift": ("import Testing\n// arrange\n", "comments.md"),
        }
        for relative_path, (content, expected_explanation) in refused_sources.items():
            with self.subTest(path=relative_path):
                self.stage(relative_path, content)
                self.assert_refused(self.commit("-m", self.HEADER), expected_explanation)
                self.git("rm", "--quiet", "--cached", relative_path)

    def test_git_allows_staged_sources_that_follow_the_rules(self):
        self.stage("Sources/Domain/Slot.swift", "import Foundation\n\nstruct Slot {}\n")
        self.stage("Sources/Features/Library/Library View.swift", "import SwiftUI\nimport Application\n")
        self.stage("docs/notes.md", "// not swift\n")
        self.assert_committed(self.commit("-m", self.HEADER))

    def test_git_judges_what_is_staged_and_not_the_working_file(self):
        self.stage("Sources/Domain/Slot.swift", "// one time of day\nstruct Slot {}\n")
        self.put("Sources/Domain/Slot.swift", "struct Slot {}\n")
        self.assert_refused(self.commit("-m", self.HEADER), "comments.md")
        self.git("add", "Sources/Domain/Slot.swift")
        self.put("Sources/Domain/Slot.swift", "// one time of day\nstruct Slot {}\n")
        self.assert_committed(self.commit("-m", self.HEADER))

    def test_git_does_not_blame_a_commit_for_what_was_already_there(self):
        self.stage("Sources/Domain/Slot.swift", "// old note\nimport SwiftUI\n\nstruct Slot {}\n")
        self.assert_committed(self.commit("--no-verify", "-m", self.HEADER))
        self.git("mv", "Sources/Domain/Slot.swift", "Sources/Domain/TimeSlot.swift")
        self.stage("Sources/Domain/TimeSlot.swift", "// old note\nimport SwiftUI\n\nstruct TimeSlot {}\n")
        self.assert_committed(self.commit("-m", self.HEADER))
        self.stage("Sources/Domain/TimeSlot.swift", "// old note\n// new note\nimport SwiftUI\n\nstruct TimeSlot {}\n")
        self.assert_refused(self.commit("-m", self.HEADER), "new note")

    def test_git_allows_deleting_a_source_that_broke_the_rules(self):
        self.stage("Sources/Domain/Slot.swift", "// old note\nstruct Slot {}\n")
        self.assert_committed(self.commit("--no-verify", "-m", self.HEADER))
        self.git("rm", "--quiet", "Sources/Domain/Slot.swift")
        self.assert_committed(self.commit("-m", self.HEADER))


class DesignReviewTests(HookTestCase):
    def write_allowed_source(self, relative_path, agent=None):
        file_path = os.path.join(self.project, relative_path)
        payload = {"tool_name": "Write", "tool_input": {"file_path": file_path, "content": "struct Slot {}\n"}}
        if agent:
            payload["agent_id"] = agent
        self.assertIsNone(self.run_hook("check-swift-source.py", payload))
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, "w", encoding="utf-8") as written:
            written.write("struct Slot {}\n")

    def stop(self, event_name="Stop", agent=None, already_continuing=False):
        payload = {"hook_event_name": event_name, "stop_hook_active": already_continuing}
        if agent:
            payload["agent_id"] = agent
        return self.run_hook("review-design-rules.py", payload)

    def test_stays_silent_when_no_swift_file_changed(self):
        self.assertIsNone(self.stop())

    def test_asks_for_one_review_of_changed_files(self):
        self.write_allowed_source("Sources/Domain/Slot.swift")
        review = self.stop()["hookSpecificOutput"]
        self.assertEqual(review["hookEventName"], "Stop")
        self.assertIn(os.path.join("Sources", "Domain", "Slot.swift"), review["additionalContext"])
        self.assertLess(len(review["additionalContext"]), CONTEXT_LIMIT)
        self.assertIsNone(self.stop())

    def test_does_not_ask_again_while_already_continuing(self):
        self.write_allowed_source("Sources/Domain/Slot.swift")
        self.assertIsNone(self.stop(already_continuing=True))
        self.assertIsNone(self.stop())

    def test_subagent_reviews_only_its_own_files(self):
        self.write_allowed_source("Sources/Domain/Slot.swift", agent="agent-1")
        self.assertIsNone(self.stop())
        review = self.stop("SubagentStop", agent="agent-1")["hookSpecificOutput"]
        self.assertEqual(review["hookEventName"], "SubagentStop")

    def test_refused_and_test_files_need_no_review(self):
        self.run_hook(
            "check-swift-source.py",
            {
                "tool_name": "Write",
                "tool_input": {"file_path": os.path.join(self.project, "Sources/Domain/Slot.swift"), "content": "// x\n"},
            },
        )
        self.assertIsNone(self.stop())


class RuleInjectionTests(HookTestCase):
    def rule_file_names(self):
        return sorted(name for name in os.listdir(RULES_DIRECTORY) if name.endswith(".md"))

    def test_every_rule_fits_into_one_hook_output(self):
        for event_name in ("SessionStart", "SubagentStart"):
            for rule_file_name in self.rule_file_names():
                with self.subTest(event=event_name, rule=rule_file_name):
                    output = self.run_hook("inject-rule.py", {"hook_event_name": event_name}, [rule_file_name])
                    injected = output["hookSpecificOutput"]
                    self.assertEqual(injected["hookEventName"], event_name)
                    self.assertLessEqual(len(injected["additionalContext"]), CONTEXT_LIMIT)
                    self.assertNotIn("cut off", injected["additionalContext"])
                    with open(os.path.join(RULES_DIRECTORY, rule_file_name), encoding="utf-8") as rule_file:
                        self.assertIn(rule_file.read().strip().splitlines()[-1], injected["additionalContext"])

    def test_settings_inject_every_rule_on_subagent_start(self):
        with open(SETTINGS_PATH, encoding="utf-8") as settings_file:
            hooks = json.load(settings_file)["hooks"]
        injected_rules = sorted(
            handler["args"][0]
            for group in hooks["SubagentStart"]
            for handler in group["hooks"]
            if handler["command"].endswith("inject-rule.py")
        )
        self.assertEqual(injected_rules, self.rule_file_names())
        self.assertNotIn("SessionStart", hooks)

    def test_settings_point_at_executable_scripts(self):
        with open(SETTINGS_PATH, encoding="utf-8") as settings_file:
            hooks = json.load(settings_file)["hooks"]
        for groups in hooks.values():
            for group in groups:
                for handler in group["hooks"]:
                    script = handler["command"].replace("${CLAUDE_PROJECT_DIR}/.claude", CLAUDE_DIRECTORY)
                    self.assertTrue(os.access(script, os.X_OK), script)


if __name__ == "__main__":
    unittest.main()
