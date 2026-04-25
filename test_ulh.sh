#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
TMPDIR_BASE=""

# --- Test framework ---
setup() {
  TMPDIR_BASE=$(mktemp -d)
}

teardown() {
  [[ -n "$TMPDIR_BASE" ]] && rm -rf "$TMPDIR_BASE"
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo -e "  \033[0;32m✓\033[0m $label"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m $label"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo -e "  \033[0;32m✓\033[0m $label"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m $label"
    echo "    expected to contain: '$needle'"
    echo "    actual: '$haystack'"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local label="$1" expected_code="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local actual_code=$?
  set -e
  if [[ "$actual_code" -eq "$expected_code" ]]; then
    echo -e "  \033[0;32m✓\033[0m $label"
    PASS=$((PASS + 1))
  else
    echo -e "  \033[0;31m✗\033[0m $label"
    echo "    expected exit code: $expected_code"
    echo "    actual exit code:   $actual_code"
    FAIL=$((FAIL + 1))
  fi
}

# --- Source functions from ulh without running main ---
ULH_SOURCED=1 source "$SCRIPT_DIR/ulh"

# ============================================================
# detect_project_type
# ============================================================
echo ""
echo "detect_project_type"

setup

# Static: no package.json
mkdir -p "$TMPDIR_BASE/static-site"
echo "<html>hello</html>" > "$TMPDIR_BASE/static-site/index.html"
assert_eq "no package.json → static" "static" "$(detect_project_type "$TMPDIR_BASE/static-site")"

# Vite React: package.json with react + vite
mkdir -p "$TMPDIR_BASE/vite-app"
cat > "$TMPDIR_BASE/vite-app/package.json" <<'JSON'
{
  "dependencies": { "react": "^18.0.0" },
  "devDependencies": { "vite": "^5.0.0" }
}
JSON
assert_eq "react + vite → vite" "vite" "$(detect_project_type "$TMPDIR_BASE/vite-app")"

# CRA: package.json with react + react-scripts
mkdir -p "$TMPDIR_BASE/cra-app"
cat > "$TMPDIR_BASE/cra-app/package.json" <<'JSON'
{
  "dependencies": { "react": "^18.0.0", "react-scripts": "5.0.0" }
}
JSON
assert_eq "react + react-scripts → cra" "cra" "$(detect_project_type "$TMPDIR_BASE/cra-app")"

# Vite config file heuristic: react but no vite in package.json, vite.config.ts exists
mkdir -p "$TMPDIR_BASE/vite-config"
cat > "$TMPDIR_BASE/vite-config/package.json" <<'JSON'
{
  "dependencies": { "react": "^18.0.0" }
}
JSON
touch "$TMPDIR_BASE/vite-config/vite.config.ts"
assert_eq "react + vite.config.ts → vite" "vite" "$(detect_project_type "$TMPDIR_BASE/vite-config")"

# React with unknown bundler (no vite, no CRA, no vite config) — fallback to vite
mkdir -p "$TMPDIR_BASE/react-unknown"
cat > "$TMPDIR_BASE/react-unknown/package.json" <<'JSON'
{
  "dependencies": { "react": "^18.0.0" }
}
JSON
assert_eq "react with unknown bundler → vite fallback" "vite" "$(detect_project_type "$TMPDIR_BASE/react-unknown")"

# Non-react package.json → static
mkdir -p "$TMPDIR_BASE/node-no-react"
cat > "$TMPDIR_BASE/node-no-react/package.json" <<'JSON'
{
  "dependencies": { "express": "^4.0.0" }
}
JSON
assert_eq "package.json without react → static" "static" "$(detect_project_type "$TMPDIR_BASE/node-no-react")"

teardown

# ============================================================
# get_deploy_dir
# ============================================================
echo ""
echo "get_deploy_dir"

assert_eq "vite → /tmp/x/dist" "/tmp/x/dist" "$(get_deploy_dir "vite" "/tmp/x")"
assert_eq "cra → /tmp/x/build" "/tmp/x/build" "$(get_deploy_dir "cra" "/tmp/x")"
assert_eq "static → /tmp/x" "/tmp/x" "$(get_deploy_dir "static" "/tmp/x")"

# ============================================================
# derive_project_name
# ============================================================
echo ""
echo "derive_project_name"

setup

# Plain directory name
mkdir -p "$TMPDIR_BASE/My Cool Project"
assert_eq "directory name sanitised" "my-cool-project" "$(derive_project_name "$TMPDIR_BASE/My Cool Project")"

# Directory with special characters
mkdir -p "$TMPDIR_BASE/foo_bar.baz"
assert_eq "underscores and dots → hyphens" "foo-bar-baz" "$(derive_project_name "$TMPDIR_BASE/foo_bar.baz")"

# Git remote takes priority
mkdir -p "$TMPDIR_BASE/local-name"
(cd "$TMPDIR_BASE/local-name" && git init -q && git remote add origin https://github.com/user/Remote-Repo.git)
assert_eq "git remote overrides dir name" "remote-repo" "$(derive_project_name "$TMPDIR_BASE/local-name")"

teardown

# ============================================================
# check_entry_point (ambiguity detection)
# ============================================================
echo ""
echo "check_entry_point"

setup

# Case: root has no index.html, subdirs v1 and v2 do → should error with suggestions
mkdir -p "$TMPDIR_BASE/ambiguous/v1" "$TMPDIR_BASE/ambiguous/v2"
echo "<html></html>" > "$TMPDIR_BASE/ambiguous/v1/index.html"
echo "<html></html>" > "$TMPDIR_BASE/ambiguous/v2/index.html"

output=$(check_entry_point "$TMPDIR_BASE/ambiguous" 2>&1 || true)
assert_contains "errors on missing root index.html" "No index.html" "$output"
assert_contains "suggests v1" "v1" "$output"
assert_contains "suggests v2" "v2" "$output"

# Case: root has index.html → should pass silently
mkdir -p "$TMPDIR_BASE/has-index"
echo "<html></html>" > "$TMPDIR_BASE/has-index/index.html"

output=$(check_entry_point "$TMPDIR_BASE/has-index" 2>&1)
if [[ -z "$output" ]]; then
  echo -e "  \033[0;32m✓\033[0m root index.html present — passes silently"
  PASS=$((PASS + 1))
else
  echo -e "  \033[0;31m✗\033[0m root index.html present — unexpected output: $output"
  FAIL=$((FAIL + 1))
fi

# Case: no index.html anywhere, no subdirs → should warn but not error
mkdir -p "$TMPDIR_BASE/empty-site"

output=$(check_entry_point "$TMPDIR_BASE/empty-site" 2>&1)
assert_contains "warns when no index.html anywhere" "No index.html found" "$output"

teardown

# ============================================================
# Summary
# ============================================================
echo ""
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  echo -e "\033[0;32mAll $TOTAL tests passed\033[0m"
else
  echo -e "\033[0;31m$FAIL/$TOTAL tests failed\033[0m"
  exit 1
fi
