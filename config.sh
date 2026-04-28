# craftsmanship-test plugin configuration
#
# Projects may override these by creating a `.craftsmanship-test.sh` at the
# target project root that redefines this array. The plugin sources it if present.
#
# Glob patterns identifying source-code files where comments should be gated.
# Comments in non-source files (markdown, yaml, json, etc.) are not gated.

CRAFT_SOURCE_GLOBS=(
  "**/*.py" "**/*.pyi"
  "**/*.ts" "**/*.tsx" "**/*.js" "**/*.jsx" "**/*.mjs" "**/*.cjs"
  "**/*.go" "**/*.rs"
  "**/*.java" "**/*.kt" "**/*.scala"
  "**/*.rb" "**/*.swift"
  "**/*.cpp" "**/*.cc" "**/*.c" "**/*.h" "**/*.hpp"
  "**/*.cs" "**/*.php"
  "**/*.ex" "**/*.exs"
)
