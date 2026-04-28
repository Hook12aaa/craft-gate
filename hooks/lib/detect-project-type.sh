#!/usr/bin/env bash
# Project-type detector for craftsmanship-test plugin.
#
# Returns CODE_PROJECT or SUPPRESS to stdout. Denylist semantics:
# default CODE_PROJECT; SUPPRESS only on strong educational signals.
#
# Source this file, then call: craft_detect_project_type <project_dir>

_craft_is_educational() {
  local dir="$1"

  for f in _quarto.yml book.toml _bookdown.yml; do
    if [ -f "$dir/$f" ]; then
      return 0
    fi
  done

  if [ -f "$dir/_config.yml" ] && grep -qE 'jupyter-book|bookdown' "$dir/_config.yml" 2>/dev/null; then
    return 0
  fi

  if [ -f "$dir/mkdocs.yml" ]; then
    local has_source=false
    for d in src lib app cmd pkg internal; do
      if [ -d "$dir/$d" ]; then
        has_source=true
        break
      fi
    done
    if ! $has_source; then
      return 0
    fi
  fi

  local notebook_count source_count
  notebook_count=$(find "$dir" -maxdepth 2 -name '*.ipynb' -type f 2>/dev/null | wc -l | tr -d ' ')
  source_count=$(find "$dir" -maxdepth 2 -type f \( \
    -name '*.py' -o -name '*.pyi' \
    -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
    -o -name '*.mjs' -o -name '*.cjs' \
    -o -name '*.go' -o -name '*.rs' \
    -o -name '*.java' -o -name '*.kt' -o -name '*.scala' \
    -o -name '*.rb' -o -name '*.swift' \
    -o -name '*.cpp' -o -name '*.cc' -o -name '*.c' -o -name '*.h' -o -name '*.hpp' \
    -o -name '*.cs' -o -name '*.php' \
    -o -name '*.ex' -o -name '*.exs' \
    \) 2>/dev/null | wc -l | tr -d ' ')

  if [ "$notebook_count" -gt 0 ] && [ "$notebook_count" -gt $((source_count * 2)) ]; then
    return 0
  fi

  return 1
}

craft_detect_project_type() {
  local dir="${1:?dir required}"

  case "${CRAFTSMANSHIP_PROJECT_TYPE:-auto}" in
    code-project) printf 'CODE_PROJECT\n'; return 0 ;;
    suppress)     printf 'SUPPRESS\n';     return 0 ;;
    auto|"")      : ;;
    *) ;; # invalid value: fall through to heuristics, do not short-circuit
  esac

  if _craft_is_educational "$dir"; then
    printf 'SUPPRESS\n'
    return 0
  fi

  printf 'CODE_PROJECT\n'
}
