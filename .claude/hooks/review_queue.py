import hashlib
import os
import re
import tempfile

UNSAFE_FILE_NAME_CHARACTERS = re.compile(r"[^A-Za-z0-9_-]")


def project_directory(payload):
    return os.path.realpath(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or os.getcwd())


def _safe_name(value, fallback):
    return UNSAFE_FILE_NAME_CHARACTERS.sub("_", str(value or fallback))


def _queue_path(payload):
    project_digest = hashlib.sha256(project_directory(payload).encode("utf-8")).hexdigest()[:12]
    return os.path.join(
        tempfile.gettempdir(),
        "claude-design-review",
        project_digest,
        _safe_name(payload.get("session_id"), "unknown-session"),
        _safe_name(payload.get("agent_id"), "main") + ".txt",
    )


def remember_changed_file(payload, file_path):
    queue_path = _queue_path(payload)
    try:
        os.makedirs(os.path.dirname(queue_path), exist_ok=True)
        with open(queue_path, "a", encoding="utf-8") as queue:
            queue.write(file_path + "\n")
    except OSError:
        return


def take_changed_files(payload):
    queue_path = _queue_path(payload)
    try:
        with open(queue_path, encoding="utf-8") as queue:
            remembered = queue.read().splitlines()
        os.remove(queue_path)
    except OSError:
        return []
    changed_files = []
    for file_path in remembered:
        if file_path and file_path not in changed_files and os.path.isfile(file_path):
            changed_files.append(file_path)
    return changed_files
