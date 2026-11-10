#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os

import review_queue

SUPPORTED_EVENTS = ("Stop", "SubagentStop")
MOST_FILES_LISTED = 30

REVIEW = """Design review required by the project rules, before you finish.

You changed these Swift files:
{files}

Hooks already checked their comments, imports, `try!` and empty `catch` blocks. Read each file again and check what no hook can check:

1. Layers (.claude/rules/architecture.md). Every business decision is in Domain. Use cases only coordinate. Adapters only translate, implement a port, and use nothing from Application except ports and their errors. Features and views hold no business rule, and no view calls a use case directly.
2. Rich domain objects (.claude/rules/system-design.md). No type is only stored properties with its rules written somewhere else. No invalid instance can be created. State changes through methods named for what the business does.
3. Deep modules (.claude/rules/system-design.md). No method only forwards to another. No caller has to call methods in a fixed order or know how a module works inside. Each interface is simpler than what it hides.
4. Validation and errors (.claude/rules/validation-and-errors.md). Domain throws its own errors for "could this state ever be valid?". Application checks "is this allowed or possible now?" and recovers from, maps or passes on every domain error. Every framework error is mapped to the port's error inside the adapter. No failure is swallowed, and none can crash the app.

Fix every violation you find now. If there is none, say so in one sentence and finish."""


def main():
    payload = json.load(sys.stdin)
    changed_files = review_queue.take_changed_files(payload)
    if payload.get("stop_hook_active") or not changed_files:
        return 0
    project = review_queue.project_directory(payload)
    listed = ["- " + os.path.relpath(file_path, project) for file_path in changed_files[:MOST_FILES_LISTED]]
    if len(changed_files) > MOST_FILES_LISTED:
        listed.append("- and {} more".format(len(changed_files) - MOST_FILES_LISTED))
    event_name = payload.get("hook_event_name")
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": event_name if event_name in SUPPORTED_EVENTS else SUPPORTED_EVENTS[0],
                "additionalContext": REVIEW.format(files="\n".join(listed)),
            }
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
