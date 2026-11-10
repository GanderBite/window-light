#!/usr/bin/env python3
import json
import os
import re
import sys

CONTEXT_LIMIT = 10000
SUPPORTED_EVENTS = ("SubagentStart", "SessionStart")
RULES_DIRECTORY = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rules")
FRONTMATTER = re.compile(r"\A---\n.*?\n---\n", re.DOTALL)


def read_event_name():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return SUPPORTED_EVENTS[0]
    event_name = payload.get("hook_event_name")
    return event_name if event_name in SUPPORTED_EVENTS else SUPPORTED_EVENTS[0]


def rule_as_context(rule_file_name):
    rule_path = os.path.join(RULES_DIRECTORY, rule_file_name)
    with open(rule_path, encoding="utf-8") as rule_file:
        rule_text = FRONTMATTER.sub("", rule_file.read()).strip()
    heading = (
        "MANDATORY PROJECT RULE from .claude/rules/{name}. "
        "It applies to all work in this repository and overrides your defaults.\n\n"
    ).format(name=rule_file_name)
    context = heading + rule_text
    if len(context) <= CONTEXT_LIMIT:
        return context
    read_in_full = (
        "\n\nThis rule is cut off here. Read .claude/rules/{name} in full before you do any work."
    ).format(name=rule_file_name)
    return context[: CONTEXT_LIMIT - len(read_in_full)] + read_in_full


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: inject-rule.py <rule file name>\n")
        return 1
    event_name = read_event_name()
    try:
        context = rule_as_context(os.path.basename(sys.argv[1]))
    except OSError as failure:
        sys.stderr.write("Rule could not be loaded: {failure}\n".format(failure=failure))
        return 1
    json.dump(
        {"hookSpecificOutput": {"hookEventName": event_name, "additionalContext": context}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
