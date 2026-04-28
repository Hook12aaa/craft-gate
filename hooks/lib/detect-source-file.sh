#!/usr/bin/env bash
# Source-file path detector for the craftsmanship-test plugin.
# Source this file after sourcing config.sh (or .craftsmanship-test.sh).
#
# Exposes:
#   craft_path_triggers <path>   -> exit 0 if path matches a source-code glob

if ! declare -p CRAFT_SOURCE_GLOBS >/dev/null 2>&1; then
  echo "ERROR: source config.sh before sourcing detect-source-file.sh" >&2
  exit 1
fi

# Convert a **-style glob to an extended regex suitable for grep -E.
# **/ -> (.*/)?   (zero or more path segments)
# *   -> [^/]*    (any chars within one segment)
# .   -> \.       (literal dot)
_glob_to_regex() {
  local glob="$1"
  printf '%s' "$glob" \
    | sed "s/\./\\\\./g" \
    | sed "s|\*\*/|ANYPATH_SEP|g" \
    | sed "s|\*|[^/]*|g" \
    | sed "s|ANYPATH_SEP|(.*/)?|g"
}

craft_path_triggers() {
  local path="$1"
  # Empty CRAFT_SOURCE_GLOBS = disabled (project override sentinel)
  [ "${#CRAFT_SOURCE_GLOBS[@]}" -eq 0 ] && return 1
  local glob
  for glob in "${CRAFT_SOURCE_GLOBS[@]}"; do
    local regex
    regex=$(_glob_to_regex "$glob")
    if echo "$path" | grep -qE "^${regex}$"; then
      return 0
    fi
  done
  return 1
}
