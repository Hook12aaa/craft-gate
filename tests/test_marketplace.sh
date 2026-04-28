#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fail=0

assert_field() {
  local file="$1" field="$2" expected="$3"
  local actual
  actual=$(python3 -c "import json; print(json.load(open('$file')).get('$field',''))")
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $file has $field=$expected"
  else
    echo "FAIL: $file expected $field=$expected, got '$actual'"
    fail=1
  fi
}

assert_nested_field() {
  local file="$1" path="$2" expected="$3"
  local actual
  actual=$(python3 -c "import json; d=json.load(open('$file')); print($path)")
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $file path '$path' = $expected"
  else
    echo "FAIL: $file path '$path' expected $expected, got '$actual'"
    fail=1
  fi
}

assert_field "${PLUGIN_ROOT}/.claude-plugin/plugin.json" "name" "craftsmanship-test"
assert_field "${PLUGIN_ROOT}/.claude-plugin/plugin.json" "version" "0.1.0"
assert_field "${PLUGIN_ROOT}/.claude-plugin/marketplace.json" "name" "craftsmanship-test-local"
assert_nested_field "${PLUGIN_ROOT}/.claude-plugin/marketplace.json" \
  "d['plugins'][0]['name']" "craftsmanship-test"

# Validate JSON parseable
python3 -c "import json; json.load(open('${PLUGIN_ROOT}/.claude-plugin/plugin.json'))" \
  && echo "PASS: plugin.json is valid JSON" || { echo "FAIL: plugin.json invalid JSON"; fail=1; }
python3 -c "import json; json.load(open('${PLUGIN_ROOT}/.claude-plugin/marketplace.json'))" \
  && echo "PASS: marketplace.json is valid JSON" || { echo "FAIL: marketplace.json invalid JSON"; fail=1; }

exit $fail
