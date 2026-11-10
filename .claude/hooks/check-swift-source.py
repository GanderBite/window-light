#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import collections
import json
import os
import re
import subprocess

import review_queue

LAYERS = ("Domain", "Application", "Infrastructure", "Presentation", "Features")
ONLY_ALLOWED_IMPORTS = {
    "Domain": ("Swift", "Foundation"),
    "Application": ("Swift", "Foundation", "Domain"),
}
FORBIDDEN_IMPORTS = {
    "Infrastructure": ("Presentation", "Features"),
    "Presentation": ("Application", "Infrastructure", "Features"),
    "Features": ("Infrastructure",),
}
WHAT_A_LAYER_MAY_IMPORT = {
    "Domain": "Domain may import only Foundation and the Swift standard library",
    "Application": "Application may import only Domain and Foundation",
    "Infrastructure": "Infrastructure must never import Presentation or Features",
    "Presentation": "Presentation must never import Application, Infrastructure or Features",
    "Features": "Features must never import Infrastructure",
}
GENERATED_OR_VENDORED_DIRECTORIES = (".build", ".swiftpm", "DerivedData", "Pods", "Carthage")

TOOL_DIRECTIVE_COMMENT = re.compile(r"^//\s*(swift-tools-version:|swiftlint:|swiftformat:|sourcery:)")
IMPORT_STATEMENT = re.compile(
    r"^[ \t]*(?:@[A-Za-z_]\w*(?:\([^)\n]*\))?[ \t]+)*"
    r"(?:(?:public|package|internal|fileprivate|private)[ \t]+)?"
    r"import[ \t]+"
    r"(?:(?:typealias|struct|class|enum|protocol|let|var|func)[ \t]+)?"
    r"([A-Za-z_]\w*)",
    re.MULTILINE,
)
CRASHING_TRY = re.compile(r"\btry!")
EMPTY_CATCH = re.compile(r"\bcatch\b[^{}\n]*\{\s*\}")
STAGED_OPTION = "--staged"
STATUS_OF_AN_ADDED_FILE = "A"
STATUS_OF_A_RENAMED_FILE = "R"
WRITING = (
    "written",
    "Change the code so it follows the rules and write it again. "
    "Do not get around this check by writing the file another way.",
)
COMMITTING = (
    "committed",
    "Change the code so it follows the rules, stage it and commit again.",
)

Violation = collections.namedtuple("Violation", "identity line explanation")


def end_of_block_comment(source, start):
    depth = 0
    position = start
    while position < len(source):
        if source.startswith("/*", position):
            depth += 1
            position += 2
        elif source.startswith("*/", position):
            depth -= 1
            position += 2
            if depth == 0:
                return position
        else:
            position += 1
    return len(source)


def end_of_interpolation(source, start):
    depth = 1
    position = start
    while position < len(source) and depth:
        character = source[position]
        if character in '"#':
            end_of_nested_literal = end_of_string_literal(source, position)
            if end_of_nested_literal is not None:
                position = end_of_nested_literal
                continue
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
        position += 1
    return position


def end_of_string_literal(source, start):
    position = start
    while source.startswith("#", position):
        position += 1
    raw_string_hashes = "#" * (position - start)
    if not source.startswith('"', position):
        return None
    spans_lines = source.startswith('"""', position)
    quote = '"""' if spans_lines else '"'
    closing_delimiter = quote + raw_string_hashes
    escape_prefix = "\\" + raw_string_hashes
    position += len(quote)
    while position < len(source):
        if source.startswith(closing_delimiter, position):
            return position + len(closing_delimiter)
        if source.startswith(escape_prefix, position):
            escaped = position + len(escape_prefix)
            if source.startswith("(", escaped):
                position = end_of_interpolation(source, escaped + 1)
            else:
                position = escaped + 1
            continue
        if source[position] == "\n" and not spans_lines:
            return position
        position += 1
    return len(source)


def separate_code_from_comments(source):
    code = []
    comments = []
    position = 0
    line = 1
    while position < len(source):
        if source.startswith("//", position):
            end = source.find("\n", position)
            end = len(source) if end == -1 else end
            comments.append((line, source[position:end].strip()))
            position = end
            continue
        if source.startswith("/*", position):
            end = end_of_block_comment(source, position)
            comment = source[position:end]
            comments.append((line, comment))
            code.append("\n" * comment.count("\n"))
            line += comment.count("\n")
            position = end
            continue
        if source[position] in '"#':
            end = end_of_string_literal(source, position)
            if end is not None:
                literal = source[position:end]
                code.append('""' + "\n" * literal.count("\n"))
                line += literal.count("\n")
                position = end
                continue
        if source[position] == "\n":
            line += 1
        code.append(source[position])
        position += 1
    return "".join(code), comments


def line_of(code, offset):
    return code.count("\n", 0, offset) + 1


def comment_violations(comments):
    violations = []
    for line, comment in comments:
        if TOOL_DIRECTIVE_COMMENT.match(comment):
            continue
        shown = " ".join(comment.split())
        shown = shown if len(shown) <= 80 else shown[:77] + "..."
        violations.append(
            Violation(
                ("comment", " ".join(comment.split())),
                line,
                "comment `{shown}`. Comments are not allowed. Say it through the names in the code "
                "(.claude/rules/comments.md).".format(shown=shown),
            )
        )
    return violations


def import_violations(code, layer):
    violations = []
    for statement in IMPORT_STATEMENT.finditer(code):
        module = statement.group(1)
        only_allowed = ONLY_ALLOWED_IMPORTS.get(layer)
        breaks_the_layer = (
            module not in only_allowed if only_allowed else module in FORBIDDEN_IMPORTS.get(layer, ())
        )
        if breaks_the_layer:
            violations.append(
                Violation(
                    ("import", module),
                    line_of(code, statement.start(1)),
                    "`import {module}` in the {layer} layer. {allowed} (.claude/rules/architecture.md).".format(
                        module=module, layer=layer, allowed=WHAT_A_LAYER_MAY_IMPORT[layer]
                    ),
                )
            )
    return violations


def error_handling_violations(code):
    violations = []
    for crashing_try in CRASHING_TRY.finditer(code):
        violations.append(
            Violation(
                ("try!",),
                line_of(code, crashing_try.start()),
                "`try!` crashes the app when the call fails. Handle the error or pass it on "
                "(.claude/rules/system-design.md).",
            )
        )
    for empty_catch in EMPTY_CATCH.finditer(code):
        violations.append(
            Violation(
                ("empty catch",),
                line_of(code, empty_catch.start()),
                "empty `catch` swallows the failure. Recover, map the error or pass it on "
                "(.claude/rules/validation-and-errors.md).",
            )
        )
    return violations


def violations_in(source, layer, is_test):
    code, comments = separate_code_from_comments(source)
    violations = comment_violations(comments)
    if not is_test:
        if layer:
            violations += import_violations(code, layer)
        violations += error_handling_violations(code)
    return violations


def violations_introduced(before, after):
    already_present = collections.Counter(violation.identity for violation in before)
    introduced = []
    for violation in after:
        if already_present[violation.identity] > 0:
            already_present[violation.identity] -= 1
        else:
            introduced.append(violation)
    return sorted(introduced, key=lambda violation: violation.line)


def read_existing_file(file_path):
    try:
        with open(file_path, encoding="utf-8") as existing_file:
            return existing_file.read()
    except (OSError, UnicodeDecodeError):
        return ""


def source_before_and_after(tool_name, tool_input):
    before = read_existing_file(tool_input["file_path"])
    if tool_name == "Write":
        return before, tool_input.get("content") or ""
    after = before
    for edit in tool_input.get("edits") or [tool_input]:
        old_text = edit.get("old_string") or ""
        new_text = edit.get("new_string") or ""
        if old_text == "":
            if after:
                return None
            after = new_text
        elif old_text not in after:
            return None
        elif edit.get("replace_all"):
            after = after.replace(old_text, new_text)
        else:
            after = after.replace(old_text, new_text, 1)
    return before, after


def place_in_project(file_path, project):
    relative_path = os.path.relpath(os.path.realpath(file_path), project)
    if relative_path.startswith(os.pardir):
        return None
    directories = relative_path.split(os.sep)[:-1]
    if any(directory in GENERATED_OR_VENDORED_DIRECTORIES for directory in directories):
        return None
    is_test = any(directory.endswith("Tests") for directory in directories)
    layer = next((directory for directory in directories if directory in LAYERS), None)
    return relative_path, layer, is_test


def refusal(relative_path, violations, action=WRITING):
    what_was_stopped, what_to_do_next = action
    lines = [
        "This change to {path} breaks the project rules, so it was not {stopped}.".format(
            path=relative_path, stopped=what_was_stopped
        ),
        "",
    ]
    lines += [
        "- line {line}: {explanation}".format(line=violation.line, explanation=violation.explanation)
        for violation in violations
    ]
    lines += ["", what_to_do_next]
    return "\n".join(lines)


def git_output(repository, *arguments):
    try:
        finished = subprocess.run(
            ["git", "-C", repository] + list(arguments), capture_output=True, text=True, encoding="utf-8", timeout=10
        )
    except (OSError, subprocess.SubprocessError, UnicodeDecodeError):
        return None
    return finished.stdout if finished.returncode == 0 else None


def staged_swift_files(repository):
    listing = git_output(
        repository, "diff", "--cached", "--name-status", "-z", "--find-renames", "--diff-filter=AMR"
    )
    fields = [field for field in (listing or "").split("\0") if field]
    staged = []
    position = 0
    while position < len(fields):
        status = fields[position]
        paths_of_this_file = 2 if status.startswith(STATUS_OF_A_RENAMED_FILE) else 1
        paths = fields[position + 1 : position + 1 + paths_of_this_file]
        position += 1 + paths_of_this_file
        if not paths or not paths[-1].endswith(".swift"):
            continue
        path_in_last_commit = None if status == STATUS_OF_AN_ADDED_FILE else paths[0]
        staged.append((path_in_last_commit, paths[-1]))
    return staged


def refusal_for_staged_sources(repository):
    refusals = []
    for path_in_last_commit, path in staged_swift_files(repository):
        place = place_in_project(os.path.join(repository, path), repository)
        staged_source = git_output(repository, "show", ":" + path)
        if place is None or staged_source is None:
            continue
        relative_path, layer, is_test = place
        source_in_last_commit = (
            git_output(repository, "show", "HEAD:" + path_in_last_commit) if path_in_last_commit else None
        )
        introduced = violations_introduced(
            violations_in(source_in_last_commit or "", layer, is_test), violations_in(staged_source, layer, is_test)
        )
        if introduced:
            refusals.append(refusal(relative_path, introduced, COMMITTING))
    return "\n\n".join(refusals)


def check_what_git_is_committing():
    top_of_working_tree = git_output(os.getcwd(), "rev-parse", "--show-toplevel")
    if top_of_working_tree is None:
        return 0
    refused = refusal_for_staged_sources(os.path.realpath(top_of_working_tree.strip()))
    if refused:
        sys.stderr.write(refused + "\n")
        return 1
    return 0


def main():
    if sys.argv[1:] == [STAGED_OPTION]:
        return check_what_git_is_committing()
    payload = json.load(sys.stdin)
    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or ""
    if not file_path.endswith(".swift"):
        return 0
    place = place_in_project(file_path, review_queue.project_directory(payload))
    if place is None:
        return 0
    relative_path, layer, is_test = place
    sources = source_before_and_after(payload.get("tool_name"), tool_input)
    if sources is None:
        return 0
    before, after = sources
    introduced = violations_introduced(
        violations_in(before, layer, is_test), violations_in(after, layer, is_test)
    )
    if introduced:
        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": refusal(relative_path, introduced),
                }
            },
            sys.stdout,
        )
        return 0
    if not is_test:
        review_queue.remember_changed_file(payload, os.path.realpath(file_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
