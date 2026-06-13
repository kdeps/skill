#!/usr/bin/env bash
# Validate all kdeps-skill test fixtures using global kdeps on PATH.
# Usage: ./tests/validate.sh [--run]
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/tests/fixtures"
RUN_TESTS=false
PASS=0
FAIL=0
SKIP=0

for arg in "$@"; do
  case "$arg" in
    --run) RUN_TESTS=true ;;
  esac
done

if ! command -v kdeps >/dev/null 2>&1; then
  echo "error: kdeps not found in PATH" >&2
  exit 1
fi

# Native scraper/searchWeb/searchLocal/embedding require a recent kdeps release.
NATIVE_ACTIONS_SUPPORTED=true
SCRAPER_ERR=$(kdeps validate "$FIXTURES/resources/scraper" 2>&1) || true
if echo "$SCRAPER_ERR" | grep -q "execution type"; then
  NATIVE_ACTIONS_SUPPORTED=false
fi

validate_path() {
  local label="$1"
  local path="$2"
  printf '%-40s ' "$label"
  if kdeps validate "$path" >/dev/null 2>&1; then
    echo "OK (validate)"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL (validate)"
  kdeps validate "$path" 2>&1 | grep -E "error:|Validation successful" | head -3
  FAIL=$((FAIL + 1))
  return 1
}

verify_registry_path() {
  local label="$1"
  local path="$2"
  printf '%-40s ' "$label"
  if kdeps registry verify "$path" >/dev/null 2>&1; then
    echo "OK (registry verify)"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL (registry verify)"
  kdeps registry verify "$path" 2>&1 | grep -E '\[ERROR\]|error:' | head -3
  FAIL=$((FAIL + 1))
  return 1
}

# Agency sub-agents are bundled inside the agency — not separate registry packages.
is_registry_package_root() {
  local path="$1"
  case "$path" in
    */agencies/*/agents/*) return 1 ;;
  esac
  [ -f "$path/workflow.yaml" ] || [ -f "$path/agency.yaml" ] || [ -f "$path/component.yaml" ]
}

check_pkg_manifest() {
  local path="$1"
  local label="$2"
  printf '%-40s ' "$label"
  if [ -f "$path/kdeps.pkg.yaml" ]; then
    echo "OK (kdeps.pkg.yaml)"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL (missing kdeps.pkg.yaml)"
  FAIL=$((FAIL + 1))
  return 1
}

bundle_package_path() {
  local label="$1"
  local path="$2"
  printf '%-40s ' "$label"
  if (
    cd "$path" &&
    kdeps bundle package . >/dev/null 2>&1 &&
    rm -f ./*.kdeps ./*.kagency ./*.komponent docker-compose.yml 2>/dev/null
  ); then
    echo "OK (bundle package)"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL (bundle package)"
  (cd "$path" && kdeps bundle package . 2>&1) | grep -E 'error:|Error' | head -3
  rm -f "$path"/*.kdeps "$path"/*.kagency "$path"/*.komponent "$path"/docker-compose.yml 2>/dev/null
  FAIL=$((FAIL + 1))
  return 1
}

install_roundtrip_path() {
  local label="$1"
  local path="$2"
  local install_root
  install_root=$(mktemp -d)
  printf '%-40s ' "$label"
  if (
    shopt -s nullglob &&
    cd "$path" &&
    kdeps bundle package . >/dev/null 2>&1 &&
    archives=( ./*.kdeps ./*.kagency ./*.komponent ) &&
    [ "${#archives[@]}" -gt 0 ] &&
    archive="${archives[0]}" &&
    KDEPS_AGENTS_DIR="$install_root/agents" \
    KDEPS_COMPONENT_DIR="$install_root/components" \
    kdeps registry install "$archive" >/dev/null 2>&1 &&
    rm -f ./*.kdeps ./*.kagency ./*.komponent docker-compose.yml 2>/dev/null
  ); then
    rm -rf "$install_root"
    echo "OK (registry install)"
    PASS=$((PASS + 1))
    return 0
  fi
  rm -rf "$install_root"
  rm -f "$path"/*.kdeps "$path"/*.kagency "$path"/*.komponent "$path"/docker-compose.yml 2>/dev/null
  echo "FAIL (registry install)"
  FAIL=$((FAIL + 1))
  return 1
}

run_smoke() {
  local label="$1"
  local check_cmd="$2"
  shift 2
  printf '%-40s ' "$label"
  if eval "$check_cmd"; then
    echo "OK (run)"
    PASS=$((PASS + 1))
  else
    echo "FAIL (run)"
    FAIL=$((FAIL + 1))
  fi
}

run_server_smoke() {
  local label="$1"
  local path="$2"
  local port="$3"
  local curl_cmd="$4"
  local token="skill-test-token"
  export KDEPS_API_AUTH_TOKEN="$token"

  printf '%-40s ' "$label"
  kdeps run "$path" --port "$port" >/tmp/kdeps-skill-run.log 2>&1 &
  local pid=$!
  local ok=false
  for _ in $(seq 1 30); do
    if eval "$curl_cmd"; then
      ok=true
      break
    fi
    sleep 0.5
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true

  if $ok; then
    echo "OK (run)"
    PASS=$((PASS + 1))
  else
    echo "FAIL (run)"
    FAIL=$((FAIL + 1))
  fi
}

KDEPS_VERSION=$(kdeps --help 2>&1 | head -1 || true)
echo "kdeps skill fixture validation"
echo "kdeps: ${KDEPS_VERSION:-$(command -v kdeps)}"
echo "fixtures: $FIXTURES"
echo

# --- Resources (one workflow per primary action) ---
for action in exec httpClient python sql scraper searchWeb searchLocal embedding chat browser email telephony botReply file git codeIntelligence; do
  case "$action" in
    scraper|searchWeb|searchLocal|embedding)
      if ! $NATIVE_ACTIONS_SUPPORTED; then
        printf '%-40s ' "resource/$action"
        echo "SKIP (upgrade kdeps for native $action)"
        SKIP=$((SKIP + 1))
        continue
      fi
      ;;
  esac
  validate_path "resource/$action" "$FIXTURES/resources/$action"
done

# --- Component ---
validate_path "component/echo" "$FIXTURES/components/echo"

# --- Workflow patterns ---
validate_path "workflow/inline-resources" "$FIXTURES/workflows/inline-resources"
validate_path "workflow/file-input" "$FIXTURES/workflows/file-input"
validate_path "workflow/component-input" "$FIXTURES/workflows/component-input"
validate_path "workflow/component-caller" "$FIXTURES/workflows/component-caller"
validate_path "workflow/llm-repl" "$FIXTURES/workflows/llm-repl"
validate_path "workflow/webserver" "$FIXTURES/workflows/webserver"
validate_path "workflow/api-web" "$FIXTURES/workflows/api-web"
validate_path "workflow/session" "$FIXTURES/workflows/session"
validate_path "workflow/control-flow" "$FIXTURES/workflows/control-flow"

# --- Agency (also exercises agent: resource) ---
validate_path "agency/simple" "$FIXTURES/agencies/simple"

echo
echo "Registry manifests (every package root needs kdeps.pkg.yaml):"
while IFS= read -r pkg_root; do
  rel="${pkg_root#$FIXTURES/}"
  check_pkg_manifest "$pkg_root" "manifest/$rel"
done < <(find "$FIXTURES" \( -name workflow.yaml -o -name agency.yaml -o -name component.yaml \) -print \
  | while IFS= read -r f; do dirname "$f"; done | sort -u | while IFS= read -r d; do
    if is_registry_package_root "$d"; then echo "$d"; fi
  done)

echo
printf '%-40s ' "manifest/alignment"
if python3 "$ROOT/tests/check_manifests.py" >/dev/null 2>&1; then
  echo "OK (name, version, type)"
  PASS=$((PASS + 1))
else
  echo "FAIL (alignment)"
  python3 "$ROOT/tests/check_manifests.py" 2>&1 | head -5
  FAIL=$((FAIL + 1))
fi

echo
echo "Registry verify (all kdeps.pkg.yaml fixtures):"
while IFS= read -r manifest; do
  pkg_dir=$(dirname "$manifest")
  rel="${pkg_dir#$FIXTURES/}"
  verify_registry_path "registry/$rel" "$pkg_dir"
done < <(find "$FIXTURES" -name kdeps.pkg.yaml | sort)

echo
printf '%-40s ' "scaffold-pkg/exec"
SCAFFOLD_TMP=$(mktemp -d)
if cp -R "$FIXTURES/resources/exec/." "$SCAFFOLD_TMP/" &&
  rm -f "$SCAFFOLD_TMP/kdeps.pkg.yaml" &&
  "$ROOT/skills/kdeps/scripts/scaffold-pkg.sh" "$SCAFFOLD_TMP" >/dev/null 2>&1 &&
  kdeps validate "$SCAFFOLD_TMP" >/dev/null 2>&1 &&
  kdeps registry verify "$SCAFFOLD_TMP" >/dev/null 2>&1; then
  echo "OK (scaffold-pkg)"
  PASS=$((PASS + 1))
else
  echo "FAIL (scaffold-pkg)"
  FAIL=$((FAIL + 1))
fi
rm -rf "$SCAFFOLD_TMP"

echo
echo "Bundle package (workflow, component, agency):"
bundle_package_path "bundle/workflow-exec" "$FIXTURES/resources/exec"
bundle_package_path "bundle/component-echo" "$FIXTURES/components/echo/components/echo"
bundle_package_path "bundle/agency-simple" "$FIXTURES/agencies/simple"

echo
echo "Registry install (bundle -> kdeps registry install):"
install_roundtrip_path "install/workflow-exec" "$FIXTURES/resources/exec"
install_roundtrip_path "install/component-echo" "$FIXTURES/components/echo/components/echo"
install_roundtrip_path "install/agency-simple" "$FIXTURES/agencies/simple"

echo
if $RUN_TESTS; then
  pkill -f "kdeps run.*kdeps-skill" 2>/dev/null || true
  sleep 0.5
  export KDEPS_API_AUTH_TOKEN="skill-test-token"

  run_server_smoke "exec (HTTP smoke)" \
    "$FIXTURES/resources/exec" 17601 \
    'curl -sf -o /dev/null -H "Authorization: Bearer skill-test-token" http://127.0.0.1:17601/api/v1/exec'

  if kdeps run --help 2>&1 | grep -q "self-test-only"; then
    run_smoke "exec (--self-test-only)" \
      "kdeps run \"$FIXTURES/resources/exec\" --port 17601 --self-test-only >/dev/null 2>&1"
  else
    printf '%-40s ' "exec (--self-test-only)"
    echo "SKIP (flag not available in this kdeps version)"
    SKIP=$((SKIP + 1))
  fi

  run_smoke "botReply (stateless)" \
    "printf '%s\n' '{\"message\":\"test\"}' | kdeps run \"$FIXTURES/resources/botReply\" 2>/dev/null | grep -q 'Hello from skill test'"

  run_smoke "file-input (stdin)" \
    "printf '%s\n' 'skill file content' | kdeps run \"$FIXTURES/workflows/file-input\" >/dev/null 2>&1"

  run_server_smoke "agency (inter-agent)" \
    "$FIXTURES/agencies/simple" 17615 \
    'curl -sf -H "Authorization: Bearer skill-test-token" "http://127.0.0.1:17615/api/v1/greet?name=Skill" | grep -q "Hello, Skill"'

  run_server_smoke "component-caller (HTTP)" \
    "$FIXTURES/workflows/component-caller" 17616 \
    'curl -sf -X POST -H "Authorization: Bearer skill-test-token" -H "Content-Type: application/json" -d "{\"text\":\"hello\"}" http://127.0.0.1:17616/api/v1/transform | grep -qi "HELLO"'

  run_server_smoke "component/echo (HTTP)" \
    "$FIXTURES/components/echo" 17613 \
    'curl -sf -X POST -H "Authorization: Bearer skill-test-token" -H "Content-Type: application/json" -d "{\"message\":\"hi\"}" http://127.0.0.1:17613/api/v1/echo | grep -qi "hi"'

  run_server_smoke "webserver (static)" \
    "$FIXTURES/workflows/webserver" 17617 \
    'curl -sf http://127.0.0.1:17617/ | grep -q "webserver fixture"'

  run_server_smoke "control-flow (items)" \
    "$FIXTURES/workflows/control-flow" 17619 \
    'curl -sf -H "Authorization: Bearer skill-test-token" http://127.0.0.1:17619/api/v1/flow | grep -q "itemCount"'

  run_server_smoke "session (HTTP)" \
    "$FIXTURES/workflows/session" 17618 \
    'curl -sf -H "Authorization: Bearer skill-test-token" http://127.0.0.1:17618/api/v1/session | grep -q "visits"'

  # api-web: public static UI + authed API on one port, and validations.check
  # surfacing its configured 400. Requires kdeps from 2026-06-12 or later;
  # older releases put web routes behind auth, so a 401 on "/" means SKIP.
  printf '%-40s ' "api-web (public UI + authed API)"
  kdeps run "$FIXTURES/workflows/api-web" --port 17620 >/tmp/kdeps-skill-run.log 2>&1 &
  apiweb_pid=$!
  ui_status=000
  for _ in $(seq 1 30); do
    ui_status=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:17620/ 2>/dev/null)
    [ "$ui_status" != "000" ] && break
    sleep 0.5
  done
  if [ "$ui_status" = "401" ]; then
    echo "SKIP (kdeps too old for public web routes)"
    SKIP=$((SKIP + 1))
  elif [ "$ui_status" = "200" ] && curl -s http://127.0.0.1:17620/ | grep -q "api-web fixture" &&
    [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{"text":"hi"}' http://127.0.0.1:17620/api/v1/echo)" = "401" ] &&
    curl -sf -X POST -H "Authorization: Bearer skill-test-token" -H "Content-Type: application/json" -d '{"text":"hi"}' http://127.0.0.1:17620/api/v1/echo | grep -q "echo:hi" &&
    [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Authorization: Bearer skill-test-token' -H 'Content-Type: application/json' -d '{"text":""}' http://127.0.0.1:17620/api/v1/echo)" = "400" ]; then
    echo "OK (run)"
    PASS=$((PASS + 1))
  else
    echo "FAIL (run)"
    FAIL=$((FAIL + 1))
  fi
  kill "$apiweb_pid" 2>/dev/null || true
  wait "$apiweb_pid" 2>/dev/null || true
fi

echo
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi