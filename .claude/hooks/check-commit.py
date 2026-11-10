#!/usr/bin/env python3
import collections
import json
import os
import re
import subprocess
import sys

TYPES = ("feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert")
HEADER_LIMIT = 72
HEADER = re.compile(r"^(?P<type>[A-Za-z]+)(?:\((?P<scope>[^()]*)\))?(?P<breaking>!)?: (?P<description>.*)$")
SCOPE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$")
AUTOSQUASH_PREFIX = re.compile(r"^(fixup|squash|amend)! ")
ISSUE_BEFORE_DESCRIPTION = re.compile(r"^#(?P<issue>[0-9]+) (?P<description>.*)$")
ISSUE_IN_BRANCH_NAME = re.compile(r"^[a-z]+/(?P<issue>[0-9]+)-[a-z0-9]")
BREAKING_CHANGE_FOOTER = re.compile(r"^breaking[ -]change\b", re.IGNORECASE)
CORRECT_BREAKING_CHANGE_FOOTER = re.compile(r"^BREAKING[ -]CHANGE: \S")
HEREDOC_FED_TO_CAT = re.compile(
    r"\A\s*cat\s*<<(?P<strip_tabs>-?)\s*(?P<quote>['\"]?)(?P<delimiter>[A-Za-z_][A-Za-z0-9_]*)(?P=quote)[ \t]*\n"
    r"(?P<body>.*?)\n[ \t]*(?P=delimiter)\s*\Z",
    re.DOTALL,
)
VARIABLE_EXPANSION = re.compile(r"\$(\{[^}]*\}|[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-])")
ENVIRONMENT_ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
WORDS_BEFORE_A_COMMAND = ("{", "!", "if", "then", "else", "elif", "do", "while", "until", "time", "command", "exec", "builtin", "noglob", "nocorrect", "env")
SHELLS = ("sh", "bash", "zsh", "dash")
GIT_OPTIONS_WITH_A_VALUE = ("-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env")
COMMIT_OPTIONS_WITH_A_VALUE = ("author", "date", "cleanup", "template", "trailer", "pathspec-from-file", "target")
GIT_SPICE_PROGRAMS = ("git-spice", "gs")
GIT_SPICE_COMMANDS_THAT_COMMIT = {
    ("branch", "create"): "git-spice branch create",
    ("commit", "create"): "git-spice commit",
    ("commit", "amend"): "git-spice amend",
}
GIT_SPICE_ALIASES = {"b": "branch", "c": "commit", "a": "amend"}
GIT_SPICE_SHORTHANDS = {"bc": ("branch", "create"), "cc": ("commit", "create"), "ca": ("commit", "amend")}
MENTIONS_A_COMMITTING_PROGRAM = re.compile(r"git|(?<![\w./-])gs(?![\w-])")
COMMIT_OPTIONS_REUSING_A_MESSAGE = ("reuse-message", "reedit-message", "fixup", "squash")
REVERT_OPTIONS_MAKING_NO_COMMIT = ("--no-commit", "--abort", "--quit", "--skip")
CHANGELOG = "CHANGELOG.md"
TYPES_A_USER_NOTICES = ("feat", "fix")
BREAKING_CHANGE_ANNOUNCEMENT = re.compile(r"^BREAKING[ -]CHANGE: ", re.MULTILINE)
NO_CHANGELOG_ENTRY_FOOTER = re.compile(r"^Changelog: none \(.*\S.*\)[ \t]*$", re.MULTILINE)
ADD_OPTIONS_STAGING_EVERYTHING = ("-A", "--all", "-u", "--update", ".", ":/", "*")
MESSAGE_FILE_OPTION = "--message-file"
DEFAULT_COMMENT_CHARACTER = "#"
SCISSORS_AFTER_THE_COMMENT_CHARACTER = " ------------------------ >8 ------------------------"

Word = collections.namedtuple("Word", "text is_literal")


class SimpleCommand:
    def __init__(self):
        self.words = []
        self.heredocs = []


def read_heredoc_delimiter(script, position):
    strips_tabs = script.startswith("-", position)
    if strips_tabs:
        position += 1
    while position < len(script) and script[position] in " \t":
        position += 1
    start = position
    while position < len(script) and script[position] not in " \t\n;&|()<>":
        position += 1
    return script[start:position].replace("'", "").replace('"', "").replace("\\", ""), strips_tabs, position


def read_heredoc_bodies(script, position, pending_heredocs):
    bodies = []
    for delimiter, strips_tabs in pending_heredocs:
        body_lines = []
        while position < len(script):
            end_of_line = script.find("\n", position)
            end_of_line = len(script) if end_of_line == -1 else end_of_line
            line = script[position:end_of_line]
            position = min(end_of_line + 1, len(script))
            if (line.lstrip("\t") if strips_tabs else line) == delimiter:
                break
            body_lines.append(line.lstrip("\t") if strips_tabs else line)
        bodies.append("\n".join(body_lines))
    return bodies, position


def skip_double_quoted(script, position):
    while position < len(script):
        character = script[position]
        if character == "\\":
            position += 2
        elif character == '"':
            return position + 1
        elif script.startswith("$(", position):
            _, position = read_command_substitution(script, position + 2)
        else:
            position += 1
    return len(script)


def read_command_substitution(script, start):
    depth = 1
    position = start
    pending_heredocs = []
    while position < len(script):
        character = script[position]
        if character == "\\":
            position += 2
        elif character == "'":
            closing_quote = script.find("'", position + 1)
            position = len(script) if closing_quote == -1 else closing_quote + 1
        elif character == '"':
            position = skip_double_quoted(script, position + 1)
        elif script.startswith("<<", position) and not script.startswith("<<<", position):
            delimiter, strips_tabs, position = read_heredoc_delimiter(script, position + 2)
            pending_heredocs.append((delimiter, strips_tabs))
        elif character == "\n" and pending_heredocs:
            _, position = read_heredoc_bodies(script, position + 1, pending_heredocs)
            pending_heredocs = []
        elif character == "(":
            depth += 1
            position += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return script[start:position], position + 1
            position += 1
        else:
            position += 1
    return script[start:], len(script)


def text_printed_by(substituted_command):
    heredoc = HEREDOC_FED_TO_CAT.match(substituted_command)
    if heredoc is None:
        return None
    body = heredoc.group("body")
    if heredoc.group("strip_tabs"):
        body = "\n".join(line.lstrip("\t") for line in body.split("\n"))
    return body.rstrip("\n")


def read_double_quoted(script, position):
    parts = []
    is_literal = True
    while position < len(script):
        character = script[position]
        if character == '"':
            return "".join(parts), is_literal, position + 1
        if character == "\\" and position + 1 < len(script) and script[position + 1] in '"\\$`\n':
            if script[position + 1] != "\n":
                parts.append(script[position + 1])
            position += 2
        elif script.startswith("$(", position):
            substituted_command, position = read_command_substitution(script, position + 2)
            printed = text_printed_by(substituted_command)
            if printed is None:
                is_literal = False
            else:
                parts.append(printed)
        elif character == "`":
            closing_backtick = script.find("`", position + 1)
            position = len(script) if closing_backtick == -1 else closing_backtick + 1
            is_literal = False
        elif character == "$" and VARIABLE_EXPANSION.match(script, position):
            position = VARIABLE_EXPANSION.match(script, position).end()
            is_literal = False
        else:
            parts.append(character)
            position += 1
    return "".join(parts), is_literal, len(script)


def read_ansi_c_quoted(script, position):
    escapes = {"n": "\n", "t": "\t", "\\": "\\", "'": "'", '"': '"'}
    parts = []
    while position < len(script):
        character = script[position]
        if character == "'":
            return "".join(parts), position + 1
        if character == "\\" and position + 1 < len(script):
            parts.append(escapes.get(script[position + 1], script[position + 1]))
            position += 2
        else:
            parts.append(character)
            position += 1
    return "".join(parts), len(script)


class ShellScript:
    def __init__(self, script):
        self.script = script
        self.position = 0
        self.commands = []
        self.command = SimpleCommand()
        self.word_parts = None
        self.word_is_literal = True
        self.skips_next_word = False
        self.pending_heredocs = []

    def add_to_word(self, text, is_literal=True):
        if self.word_parts is None:
            self.word_parts = []
            self.word_is_literal = True
        self.word_parts.append(text)
        self.word_is_literal = self.word_is_literal and is_literal

    def end_word(self):
        if self.word_parts is None:
            return
        if self.skips_next_word:
            self.skips_next_word = False
        else:
            self.command.words.append(Word("".join(self.word_parts), self.word_is_literal))
        self.word_parts = None

    def end_command(self):
        self.end_word()
        self.skips_next_word = False
        if self.command.words or self.command.heredocs:
            self.commands.append(self.command)
        self.command = SimpleCommand()

    def drop_file_descriptor_number(self):
        if self.word_parts is not None and "".join(self.word_parts).isdigit():
            self.word_parts = None
        else:
            self.end_word()

    def read_redirection(self):
        script = self.script
        if script.startswith("<<<", self.position):
            self.end_word()
            self.position += 3
            self.skips_next_word = True
        elif script.startswith("<<", self.position):
            self.end_word()
            delimiter, strips_tabs, self.position = read_heredoc_delimiter(script, self.position + 2)
            self.pending_heredocs.append((self.command, delimiter, strips_tabs))
        elif script.startswith("<(", self.position) or script.startswith(">(", self.position):
            _, self.position = read_command_substitution(script, self.position + 2)
            self.add_to_word("", is_literal=False)
        else:
            self.drop_file_descriptor_number()
            while self.position < len(script) and script[self.position] in "<>|":
                self.position += 1
            if script.startswith("&", self.position):
                self.position += 1
                while self.position < len(script) and (script[self.position].isdigit() or script[self.position] == "-"):
                    self.position += 1
            else:
                self.skips_next_word = True

    def read_dollar(self):
        script = self.script
        if script.startswith("$'", self.position):
            text, self.position = read_ansi_c_quoted(script, self.position + 2)
            self.add_to_word(text)
        elif script.startswith("$(", self.position):
            substituted_command, self.position = read_command_substitution(script, self.position + 2)
            printed = text_printed_by(substituted_command)
            self.add_to_word(printed or "", is_literal=printed is not None)
        elif VARIABLE_EXPANSION.match(script, self.position):
            self.position = VARIABLE_EXPANSION.match(script, self.position).end()
            self.add_to_word("", is_literal=False)
        else:
            self.add_to_word("$")
            self.position += 1

    def read_newline(self):
        self.end_word()
        self.position += 1
        if self.pending_heredocs:
            bodies, self.position = read_heredoc_bodies(
                self.script, self.position, [(delimiter, strips_tabs) for _, delimiter, strips_tabs in self.pending_heredocs]
            )
            for (owner, _, _), body in zip(self.pending_heredocs, bodies):
                owner.heredocs.append(body)
            self.pending_heredocs = []
        self.end_command()

    def simple_commands(self):
        script = self.script
        while self.position < len(script):
            character = script[self.position]
            if character == "\\":
                if script.startswith("\\\n", self.position):
                    self.position += 2
                else:
                    self.add_to_word(script[self.position + 1 : self.position + 2])
                    self.position += 2
            elif character == "'":
                closing_quote = script.find("'", self.position + 1)
                closing_quote = len(script) if closing_quote == -1 else closing_quote
                self.add_to_word(script[self.position + 1 : closing_quote])
                self.position = closing_quote + 1
            elif character == '"':
                text, is_literal, self.position = read_double_quoted(script, self.position + 1)
                self.add_to_word(text, is_literal)
            elif character == "$":
                self.read_dollar()
            elif character == "`":
                closing_backtick = script.find("`", self.position + 1)
                self.position = len(script) if closing_backtick == -1 else closing_backtick + 1
                self.add_to_word("", is_literal=False)
            elif character == "#" and self.word_parts is None:
                end_of_line = script.find("\n", self.position)
                self.position = len(script) if end_of_line == -1 else end_of_line
            elif character in " \t":
                self.end_word()
                self.position += 1
            elif character == "\n":
                self.read_newline()
            elif character in "<>":
                self.read_redirection()
            elif script.startswith("&>", self.position):
                self.end_word()
                self.position += 1
                self.read_redirection()
            elif character in ";&|()":
                self.end_command()
                self.position += 1
            else:
                self.add_to_word(character)
                self.position += 1
        self.end_command()
        return self.commands


def git_subcommand(words):
    index = 0
    while index < len(words) and (
        words[index].text in WORDS_BEFORE_A_COMMAND or ENVIRONMENT_ASSIGNMENT.match(words[index].text)
    ):
        index += 1
    if index >= len(words):
        return None, [], None
    program = os.path.basename(words[index].text)
    if program in SHELLS or program == "eval":
        return program, words[index + 1 :], None
    if program in GIT_SPICE_PROGRAMS:
        return git_spice_subcommand(words[index + 1 :])
    if program != "git":
        return None, [], None
    index += 1
    directory = None
    while index < len(words) and words[index].text.startswith("-"):
        if words[index].text == "-C" and index + 1 < len(words):
            directory = words[index + 1].text
        index += 2 if words[index].text in GIT_OPTIONS_WITH_A_VALUE else 1
    if index >= len(words):
        return None, [], None
    return "git " + words[index].text, words[index + 1 :], directory


def git_spice_subcommand(words):
    directory = None
    index = 0
    while index < len(words) and words[index].text.startswith("-"):
        if words[index].text in ("-C", "--dir") and index + 1 < len(words):
            directory = words[index + 1].text
            index += 1
        elif words[index].text.startswith("--dir="):
            directory = words[index].text[len("--dir=") :]
        index += 1
    if index >= len(words):
        return None, [], None
    first = words[index].text
    if first in GIT_SPICE_SHORTHANDS:
        names = GIT_SPICE_SHORTHANDS[first]
        arguments = words[index + 1 :]
    elif index + 1 < len(words):
        group = GIT_SPICE_ALIASES.get(first, first)
        second = words[index + 1].text
        action = "create" if second == "c" else GIT_SPICE_ALIASES.get(second, second)
        names = (group, action)
        arguments = words[index + 2 :]
    else:
        return None, [], None
    return GIT_SPICE_COMMANDS_THAT_COMMIT.get(names), arguments, directory


def script_given_to_shell(program, arguments):
    if program == "eval":
        return " ".join(argument.text for argument in arguments)
    for index, argument in enumerate(arguments):
        if re.match(r"^-[a-z]*c$", argument.text) and index + 1 < len(arguments):
            return arguments[index + 1].text
    return None


class CommitArguments:
    def __init__(self, arguments, heredocs, working_directory, amends=False):
        self.messages = []
        self.message_file = None
        self.reuses_a_message = False
        self.amends = amends
        self.keeps_the_message = False
        self.is_a_dry_run = False
        self.includes_every_tracked_change = False
        self.paths = []
        self.heredocs = heredocs
        self.working_directory = working_directory
        self.arguments = arguments
        self.index = 0
        self.read()

    def next_value(self):
        self.index += 1
        return self.arguments[self.index] if self.index < len(self.arguments) else None

    def read_long_option(self, argument):
        name, has_value, value = argument.text[2:].partition("=")
        attached_value = Word(value, argument.is_literal) if has_value else None
        if name == "message":
            self.messages.append(attached_value or self.next_value())
        elif name in ("file", "message-file"):
            self.message_file = attached_value or self.next_value()
        elif name in COMMIT_OPTIONS_REUSING_A_MESSAGE:
            self.reuses_a_message = True
            if not has_value:
                self.next_value()
        elif name == "amend":
            self.amends = True
        elif name == "no-edit":
            self.keeps_the_message = True
        elif name in ("dry-run", "no-commit"):
            self.is_a_dry_run = True
        elif name == "all":
            self.includes_every_tracked_change = True
        elif name in COMMIT_OPTIONS_WITH_A_VALUE and not has_value:
            self.next_value()

    def read_short_options(self, argument):
        cluster = argument.text[1:]
        for offset, flag in enumerate(cluster):
            attached = cluster[offset + 1 :]
            attached_value = Word(attached, argument.is_literal) if attached else None
            if flag == "m":
                self.messages.append(attached_value or self.next_value())
                return
            if flag == "F":
                self.message_file = attached_value or self.next_value()
                return
            if flag in "Cc":
                self.reuses_a_message = True
                if not attached:
                    self.next_value()
                return
            if flag == "t":
                if not attached:
                    self.next_value()
                return
            if flag in "Su":
                return
            if flag == "a":
                self.includes_every_tracked_change = True

    def read(self):
        while self.index < len(self.arguments):
            argument = self.arguments[self.index]
            if argument.text == "--":
                self.paths += [path.text for path in self.arguments[self.index + 1 :]]
                return
            if argument.text.startswith("--"):
                self.read_long_option(argument)
            elif argument.text.startswith("-") and len(argument.text) > 1:
                self.read_short_options(argument)
            else:
                self.paths.append(argument.text)
            self.index += 1

    def message_from_file(self):
        if self.message_file is None or not self.message_file.is_literal:
            return None
        if self.message_file.text == "-":
            return self.heredocs[0] if self.heredocs else None
        try:
            with open(os.path.join(self.working_directory, self.message_file.text), encoding="utf-8") as message_file:
                return message_file.read()
        except (OSError, UnicodeDecodeError):
            return None

    def needs_no_new_message(self):
        return self.reuses_a_message or self.is_a_dry_run or (self.amends and self.keeps_the_message)


FORMAT_REMINDER = (
    "Required format (.claude/rules/commits.md):\n"
    "  <type>[(<scope>)][!]: #<issue> <description>\n"
    "  types: " + ", ".join(TYPES) + "\n"
    "  example: feat(domain): #12 place pictures in slots by capture time"
)
UNREADABLE_MESSAGE = (
    "The commit message cannot be read from this command, so it cannot be checked. "
    "Pass the whole message literally with -m, or with -m \"$(cat <<'EOF' ... EOF)\". "
    "Do not build it from variables or other commands.\n\n" + FORMAT_REMINDER
)
MISSING_MESSAGE = (
    "This commit has no message on the command line and would open an editor. "
    "Pass the message with -m.\n\n" + FORMAT_REMINDER
)
UNREADABLE_MESSAGE_FILE = "The commit message could not be read from the file git wrote it to, so it cannot be checked."
REVERT_WITHOUT_MESSAGE = (
    "`git revert` writes a message that is not a conventional commit. "
    "Run `git revert --no-commit <commit>` and then `git commit -m \"revert: <what is undone>\"`.\n\n"
    + FORMAT_REMINDER
)


def problems_with_issue_number(issue_in_header, branch):
    problems = []
    if issue_in_header is None:
        problems.append(
            "Put the issue number first, directly after the colon and one space: "
            "`<type>[(<scope>)][!]: #<issue> <description>`."
        )
    if branch is None:
        return problems
    issue_of_branch = ISSUE_IN_BRANCH_NAME.match(branch)
    if issue_of_branch is None:
        problems.append(
            "The branch `{}` carries no issue number. Commit on a branch named `<type>/<issue>-<name>`. "
            "The /checkout command creates one from an issue.".format(branch or "(no name given)")
        )
    elif issue_in_header is not None and issue_in_header != issue_of_branch.group("issue"):
        problems.append(
            "The header names issue #{}, but the branch `{}` belongs to issue #{}.".format(
                issue_in_header, branch, issue_of_branch.group("issue")
            )
        )
    return problems


def problems_in_header(header, branch):
    parsed = HEADER.match(header)
    if parsed is None:
        if re.match(r"^[A-Za-z]+(\([^()]*\))?!?:\S", header):
            return ["Put exactly one space after the colon."]
        return ["The header does not have the form `<type>[(<scope>)][!]: #<issue> <description>`."]
    problems = []
    commit_type = parsed.group("type")
    if commit_type not in TYPES:
        if commit_type.lower() in TYPES:
            problems.append("Write the type in lowercase: `{}`.".format(commit_type.lower()))
        else:
            problems.append("`{}` is not an allowed type. Use one of: {}.".format(commit_type, ", ".join(TYPES)))
    scope = parsed.group("scope")
    if scope is not None and not SCOPE.match(scope):
        problems.append("The scope must be one noun made of letters, digits, `.`, `_`, `/` or `-`.")
    with_issue = ISSUE_BEFORE_DESCRIPTION.match(parsed.group("description"))
    problems += problems_with_issue_number(with_issue.group("issue") if with_issue else None, branch)
    description = with_issue.group("description") if with_issue else parsed.group("description")
    if not description.strip():
        problems.append("The description after the colon is missing.")
    elif description != description.strip():
        problems.append("Put exactly one space after the colon and none at the end of the header.")
    elif description.endswith("."):
        problems.append("Do not end the description with a period.")
    if len(header) > HEADER_LIMIT:
        problems.append("The header has {} characters. The limit is {}.".format(len(header), HEADER_LIMIT))
    return problems


def problems_in_message(message, branch):
    lines = message.strip("\n").split("\n")
    header = lines[0]
    if AUTOSQUASH_PREFIX.match(header):
        return []
    problems = problems_in_header(header, branch)
    if len(lines) > 1 and lines[1].strip():
        problems.append("Leave one blank line between the header and the body.")
    for line in lines[1:]:
        if BREAKING_CHANGE_FOOTER.match(line) and not CORRECT_BREAKING_CHANGE_FOOTER.match(line):
            problems.append("Write the breaking-change footer exactly as `BREAKING CHANGE: <what breaks>`.")
            break
    return problems


def refusal_for_message(message, branch):
    problems = problems_in_message(message, branch)
    if not problems:
        return None
    header = message.strip("\n").split("\n")[0]
    return "\n".join(
        ["This commit message does not follow Conventional Commits, so the commit was not made.", "", "Header: " + header]
        + ["- " + problem for problem in problems]
        + ["", FORMAT_REMINDER]
    )


def git_output(directory, *arguments):
    try:
        finished = subprocess.run(
            ["git", "-C", directory] + list(arguments), capture_output=True, text=True, timeout=5
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return finished.stdout if finished.returncode == 0 else None


def names_the_changelog(paths):
    return any(os.path.basename(path) == CHANGELOG for path in paths)


def changelog_is_part_of(commit, repository, arguments_of_earlier_adds):
    staged = git_output(repository, "diff", "--cached", "--name-only")
    if staged is None:
        return True
    if commit.amends:
        staged += git_output(repository, "show", "--name-only", "--format=", "HEAD") or ""
    if CHANGELOG in staged.splitlines():
        return True
    state_in_working_tree = (git_output(repository, "status", "--porcelain", "--", ":/" + CHANGELOG) or "").strip()
    if not state_in_working_tree:
        return False
    if names_the_changelog(commit.paths):
        return True
    if commit.includes_every_tracked_change and not state_in_working_tree.startswith("??"):
        return True
    return any(
        argument in ADD_OPTIONS_STAGING_EVERYTHING or names_the_changelog([argument])
        for argument in arguments_of_earlier_adds
    )


def what_a_user_notices(message):
    header = message.strip("\n").split("\n")[0]
    parsed = HEADER.match(header)
    if parsed is None or AUTOSQUASH_PREFIX.match(header):
        return None
    if NO_CHANGELOG_ENTRY_FOOTER.search(message):
        return None
    if parsed.group("breaking") or BREAKING_CHANGE_ANNOUNCEMENT.search(message):
        return "a breaking change"
    if parsed.group("type") in TYPES_A_USER_NOTICES:
        return "a `{}` commit".format(parsed.group("type"))
    return None


def refusal_for_missing_changelog(message, commit, repository, arguments_of_earlier_adds):
    noticed = what_a_user_notices(message)
    if noticed is None or changelog_is_part_of(commit, repository, arguments_of_earlier_adds):
        return None
    return refusal_naming_the_missing_changelog(noticed)


def refusal_naming_the_missing_changelog(noticed):
    return (
        "This is {noticed}, which changes something a user can notice, but {changelog} is not part of "
        "the commit, so the commit was not made.\n\n"
        "Add the entry under `## [Unreleased]` as .claude/rules/changelog.md says (the /changelog command "
        "does this), stage {changelog} and commit again.\n\n"
        "If no user can notice this change, say so in a footer of the commit message:\n"
        "  Changelog: none (<reason>)"
    ).format(noticed=noticed, changelog=CHANGELOG)


def checked_out_branch(repository):
    current_branch = git_output(repository, "branch", "--show-current")
    return current_branch.strip() or None if current_branch is not None else None


def branch_receiving_the_commit(commit, repository, creates_branch):
    if creates_branch:
        return commit.paths[0] if commit.paths else ""
    return checked_out_branch(repository)


def comment_character(repository):
    configured = (git_output(repository, "config", "--get", "core.commentChar") or "").strip()
    return configured if len(configured) == 1 else DEFAULT_COMMENT_CHARACTER


def message_git_will_record(text_of_message_file, comment_character):
    recorded_lines = []
    for line in text_of_message_file.split("\n"):
        if line == comment_character + SCISSORS_AFTER_THE_COMMENT_CHARACTER:
            break
        if not line.startswith(comment_character):
            recorded_lines.append(line)
    return "\n".join(recorded_lines).strip("\n")


def git_is_amending_the_last_commit(repository):
    author_date_git_gives_this_commit = os.environ.get("GIT_AUTHOR_DATE", "")
    author_date_of_the_last_commit = (git_output(repository, "log", "-1", "--format=%at") or "").strip()
    return bool(author_date_of_the_last_commit) and author_date_git_gives_this_commit.startswith(
        "@" + author_date_of_the_last_commit + " "
    )


def changelog_is_in_the_commit_git_is_recording(repository):
    files_in_the_commit = git_output(repository, "diff", "--cached", "--name-only")
    if files_in_the_commit is None:
        return True
    if git_is_amending_the_last_commit(repository):
        files_in_the_commit += git_output(repository, "show", "--name-only", "--format=", "HEAD") or ""
    return CHANGELOG in files_in_the_commit.splitlines()


def refusal_for_commit_git_is_recording(message_file_path, repository):
    try:
        with open(message_file_path, encoding="utf-8") as message_file:
            message = message_git_will_record(message_file.read(), comment_character(repository))
    except (OSError, UnicodeDecodeError):
        return UNREADABLE_MESSAGE_FILE
    refusal = refusal_for_message(message, checked_out_branch(repository))
    if refusal:
        return refusal
    noticed = what_a_user_notices(message)
    if noticed is None or changelog_is_in_the_commit_git_is_recording(repository):
        return None
    return refusal_naming_the_missing_changelog(noticed)


def refusal_for_commit(arguments, heredocs, working_directory, arguments_of_earlier_adds, program="git commit"):
    commit = CommitArguments(arguments, heredocs, working_directory, program == "git-spice amend")
    branch = branch_receiving_the_commit(commit, working_directory, program == "git-spice branch create")
    if commit.messages:
        subject = commit.messages[0]
        if subject is None or not subject.is_literal:
            return UNREADABLE_MESSAGE
        paragraphs = [subject.text] + [paragraph.text for paragraph in commit.messages[1:] if paragraph is not None]
        message = "\n\n".join(paragraphs)
    elif commit.message_file is not None:
        message = commit.message_from_file()
        if message is None:
            return UNREADABLE_MESSAGE
    elif commit.needs_no_new_message():
        return None
    else:
        return MISSING_MESSAGE
    if commit.is_a_dry_run:
        return refusal_for_message(message, branch)
    return refusal_for_message(message, branch) or refusal_for_missing_changelog(
        message, commit, working_directory, arguments_of_earlier_adds
    )


def refusal_for_revert(arguments):
    for argument in arguments:
        if argument.text in REVERT_OPTIONS_MAKING_NO_COMMIT or re.match(r"^-[a-zA-Z]*n[a-zA-Z]*$", argument.text):
            return None
    return REVERT_WITHOUT_MESSAGE


def refusal_for_script(script, working_directory, nesting=0):
    arguments_of_earlier_adds = []
    for command in ShellScript(script).simple_commands():
        program, arguments, git_directory = git_subcommand(command.words)
        repository = os.path.join(working_directory, git_directory) if git_directory else working_directory
        refusal = None
        if program == "git add":
            arguments_of_earlier_adds += [argument.text for argument in arguments]
        elif program in ("git commit", "git-spice commit", "git-spice amend", "git-spice branch create"):
            refusal = refusal_for_commit(arguments, command.heredocs, repository, arguments_of_earlier_adds, program)
        elif program == "git revert":
            refusal = refusal_for_revert(arguments)
        elif program in SHELLS + ("eval",) and nesting < 3:
            nested_script = script_given_to_shell(program, arguments)
            if nested_script:
                refusal = refusal_for_script(nested_script, working_directory, nesting + 1)
        if refusal:
            return refusal
    return None


def answer_git(refusal):
    if refusal:
        sys.stderr.write(refusal + "\n")
        return 1
    return 0


def main():
    if len(sys.argv) == 3 and sys.argv[1] == MESSAGE_FILE_OPTION:
        return answer_git(refusal_for_commit_git_is_recording(sys.argv[2], os.getcwd()))
    payload = json.load(sys.stdin)
    script = (payload.get("tool_input") or {}).get("command") or ""
    if not MENTIONS_A_COMMITTING_PROGRAM.search(script):
        return 0
    try:
        refusal = refusal_for_script(script, payload.get("cwd") or os.getcwd())
    except Exception:
        refusal = UNREADABLE_MESSAGE if re.search(r"\b(git|gs)\b[^\n;|&]*\b(commit|revert|create|amend)\b", script) else None
    if refusal:
        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": refusal,
                }
            },
            sys.stdout,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
