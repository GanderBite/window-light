#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os
import shutil
import subprocess

import review_queue

SECONDS_A_TOOL_MAY_TAKE = 20
EXIT_CODE_THAT_SHOWS_THE_MESSAGE_TO_CLAUDE = 2
FORMATTER = "swiftformat"
LINTER = "swiftlint"


class ToolDidNotRun(Exception):
    pass


def is_swift_file_of_the_project(file_path, project):
    if not file_path.endswith(".swift") or not os.path.isfile(file_path):
        return False
    relative_path = os.path.relpath(os.path.realpath(file_path), project)
    return not relative_path.startswith(os.pardir)


def run(command, project):
    try:
        return subprocess.run(
            command, cwd=project, capture_output=True, text=True, encoding="utf-8", timeout=SECONDS_A_TOOL_MAY_TAKE
        )
    except (OSError, subprocess.SubprocessError, UnicodeDecodeError) as failure:
        raise ToolDidNotRun("{tool} did not run: {failure}".format(tool=command[0], failure=failure))


def format_in_place(file_path, project):
    finished = run([FORMATTER, file_path, "--quiet"], project)
    if finished.returncode != 0:
        raise ToolDidNotRun(
            "{tool} could not format the file: {output}".format(
                tool=FORMATTER, output=(finished.stderr or finished.stdout).strip()
            )
        )


def lint_findings(file_path, project):
    finished = run([LINTER, "lint", "--quiet", "--force-exclude", file_path], project)
    findings = [line for line in finished.stdout.splitlines() if line.strip()]
    if finished.returncode != 0 and not findings:
        raise ToolDidNotRun(
            "{tool} could not lint the file: {output}".format(tool=LINTER, output=finished.stderr.strip())
        )
    return [finding.replace(project + os.sep, "") for finding in findings]


def report(relative_path, findings):
    lines = ["{path} was written and formatted, and SwiftLint found this in it:".format(path=relative_path), ""]
    lines += ["- " + finding for finding in findings]
    lines += ["", "Change the code so each finding is gone. Do not switch a rule off to get past it."]
    return "\n".join(lines)


def main():
    payload = json.load(sys.stdin)
    file_path = (payload.get("tool_input") or {}).get("file_path") or ""
    project = review_queue.project_directory(payload)
    if not is_swift_file_of_the_project(file_path, project):
        return 0
    missing_tools = [tool for tool in (FORMATTER, LINTER) if shutil.which(tool) is None]
    if missing_tools:
        sys.stderr.write(
            "{tools} not installed, so the file was neither formatted nor linted. "
            "Install with: brew install {arguments}\n".format(
                tools=" and ".join(missing_tools), arguments=" ".join(missing_tools)
            )
        )
        return 1
    try:
        format_in_place(file_path, project)
        findings = lint_findings(file_path, project)
    except ToolDidNotRun as failure:
        sys.stderr.write(str(failure) + "\n")
        return 1
    if findings:
        sys.stderr.write(report(os.path.relpath(os.path.realpath(file_path), project), findings) + "\n")
        return EXIT_CODE_THAT_SHOWS_THE_MESSAGE_TO_CLAUDE
    return 0


if __name__ == "__main__":
    sys.exit(main())
