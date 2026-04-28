#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${PLUGIN_ROOT}/hooks/lib/detect-project-type.sh"

PASS=0
FAIL=0

assert_eq() {
  local expected="$1" actual="$2" name="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'PASS %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL %s: expected "%s", got "%s"\n' "$name" "$expected" "$actual" >&2
    FAIL=$((FAIL + 1))
  fi
}

run_case() {
  local dir="$1"; shift
  craft_detect_project_type "$dir" | tr -d '\n'
}

TMPDIRS=()
cleanup() {
  for td in "${TMPDIRS[@]:-}"; do
    [ -n "$td" ] && [ -d "$td" ] && rm -rf "$td"
  done
  return 0
}
trap cleanup EXIT

mktmp() {
  local td
  td="$(mktemp -d)"
  TMPDIRS+=("$td")
  printf '%s' "$td"
}

# 1. Default empty dir
d=$(mktmp); unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "default empty dir is CODE_PROJECT"
rm -rf "$d"

# 2. _quarto.yml triggers SUPPRESS
d=$(mktmp); touch "$d/_quarto.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "_quarto.yml triggers SUPPRESS"
rm -rf "$d"

# 3. book.toml triggers SUPPRESS
d=$(mktmp); touch "$d/book.toml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "book.toml triggers SUPPRESS"
rm -rf "$d"

# 4. _bookdown.yml triggers SUPPRESS
d=$(mktmp); touch "$d/_bookdown.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "_bookdown.yml triggers SUPPRESS"
rm -rf "$d"

# 5. _config.yml with jupyter-book -> SUPPRESS
d=$(mktmp); printf 'theme: jupyter-book\n' > "$d/_config.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "_config.yml with jupyter-book triggers SUPPRESS"
rm -rf "$d"

# 6. _config.yml without educational marker -> CODE_PROJECT
d=$(mktmp); printf 'theme: minima\n' > "$d/_config.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "_config.yml without marker is CODE_PROJECT"
rm -rf "$d"

# 7. mkdocs.yml without source dir -> SUPPRESS
d=$(mktmp); touch "$d/mkdocs.yml"; unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "mkdocs.yml without src/ triggers SUPPRESS"
rm -rf "$d"

# 8. mkdocs.yml WITH src/ -> CODE_PROJECT
d=$(mktmp); touch "$d/mkdocs.yml"; mkdir -p "$d/src"; touch "$d/src/main.py"
unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "mkdocs.yml with src/ is CODE_PROJECT"
rm -rf "$d"

# 9. notebook-dominant (5 ipynb, 1 py) -> SUPPRESS
d=$(mktmp)
for i in 1 2 3 4 5; do touch "$d/lesson_${i}.ipynb"; done
touch "$d/util.py"
unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "notebook-dominant repo triggers SUPPRESS"
rm -rf "$d"

# 10. code-dominant (1 ipynb, 5 py) -> CODE_PROJECT
d=$(mktmp)
touch "$d/notebook.ipynb"
for i in 1 2 3 4 5; do touch "$d/file_${i}.py"; done
unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "code-dominant with one notebook is CODE_PROJECT"
rm -rf "$d"

# 11. override=suppress -> SUPPRESS
d=$(mktmp); touch "$d/main.py"; CRAFTSMANSHIP_PROJECT_TYPE=suppress
assert_eq "SUPPRESS" "$(run_case "$d")" "override=suppress wins"
unset CRAFTSMANSHIP_PROJECT_TYPE; rm -rf "$d"

# 12. override=code-project on educational -> CODE_PROJECT
d=$(mktmp); touch "$d/_quarto.yml"; CRAFTSMANSHIP_PROJECT_TYPE=code-project
assert_eq "CODE_PROJECT" "$(run_case "$d")" "override=code-project wins on educational"
unset CRAFTSMANSHIP_PROJECT_TYPE; rm -rf "$d"

# 13. override=auto uses heuristics
d=$(mktmp); touch "$d/main.py"; CRAFTSMANSHIP_PROJECT_TYPE=auto
assert_eq "CODE_PROJECT" "$(run_case "$d")" "override=auto uses heuristics"
unset CRAFTSMANSHIP_PROJECT_TYPE; rm -rf "$d"

# 14. invalid override falls through to heuristics
d=$(mktmp); touch "$d/main.py"; CRAFTSMANSHIP_PROJECT_TYPE=garbage
assert_eq "CODE_PROJECT" "$(run_case "$d")" "invalid override falls through"
unset CRAFTSMANSHIP_PROJECT_TYPE; rm -rf "$d"

# 15. boundary: 4 ipynb vs 2 source = 4 > 4? no -> CODE_PROJECT (locks strict >)
d=$(mktmp)
for i in 1 2 3 4; do touch "$d/lesson_${i}.ipynb"; done
for i in 1 2; do touch "$d/file_${i}.py"; done
unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "CODE_PROJECT" "$(run_case "$d")" "ratio at boundary (4:2) is CODE_PROJECT"
rm -rf "$d"

# 16. boundary: 5 ipynb vs 2 source = 5 > 4? yes -> SUPPRESS
d=$(mktmp)
for i in 1 2 3 4 5; do touch "$d/lesson_${i}.ipynb"; done
for i in 1 2; do touch "$d/file_${i}.py"; done
unset CRAFTSMANSHIP_PROJECT_TYPE
assert_eq "SUPPRESS" "$(run_case "$d")" "ratio just past boundary (5:2) is SUPPRESS"
rm -rf "$d"

if [ "$FAIL" -eq 0 ]; then
  printf 'detect-project-type: %d/%d passed\n' "$PASS" "$((PASS+FAIL))"
  exit 0
else
  printf 'detect-project-type: %d/%d passed (FAIL)\n' "$PASS" "$((PASS+FAIL))" >&2
  exit 1
fi
