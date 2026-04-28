#!/usr/bin/env bash
# Reads raw text from stdin, emits a Claude Code hook JSON response
# with the text placed in additionalContext. Uses python3 for JSON escaping
# so every control character is handled correctly.
#
# Usage: some_text | hooks/lib/emit-context.sh <hook-event-name>
set -euo pipefail

event_name="${1:-UnknownEvent}"

# Read stdin into a bash variable first so it is not consumed by the Python heredoc.
content="$(cat)"

HOOK_EVENT_NAME="$event_name" HOOK_CONTENT="$content" python3 - <<'PY'
import json, os, sys
event_name = os.environ["HOOK_EVENT_NAME"]
content = os.environ["HOOK_CONTENT"]

# Claude Code plugin hooks expect hookSpecificOutput when invoked under
# ${CLAUDE_PLUGIN_ROOT}; bare hooks (e.g. Copilot CLI) use a flat shape.
if os.environ.get("CLAUDE_PLUGIN_ROOT") and not os.environ.get("COPILOT_CLI"):
    out = {
        "hookSpecificOutput": {
            "hookEventName": event_name,
            "additionalContext": content,
        }
    }
else:
    out = {"additionalContext": content}

print(json.dumps(out))
PY
