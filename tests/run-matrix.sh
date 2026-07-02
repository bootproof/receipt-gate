#!/usr/bin/env bash
# tests/run-matrix.sh — run all scenario × require-health combinations and
# assert exit codes match the expected decision matrix.
#
# Decision matrix (what we're verifying):
#
#   scenario        require-health   expected-exit
#   --------------  --------------   --------------
#   health-true     true             0  (PASS)
#   health-true     false            0  (PASS)
#   health-false    true             1  (FAIL — no health signal)
#   health-false    false            0  (PASS — process-only accepted)
#   boot-fail       true             1  (FAIL — no boot)
#   boot-fail       false            1  (FAIL — no boot)
#   bad-json        true             1  (FAIL — fail closed)
#   bad-json        false            1  (FAIL — fail closed)
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$REPO_ROOT/tests:$PATH"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# gate.sh writes bootproof-stderr.log in CWD; run from $WORK to avoid polluting the repo.
cd "$WORK" || exit 1

# A fake app dir — gate.sh passes it to npx (which the shim ignores) and uses
# it to construct the attestation-path output. It doesn't need to actually boot.
mkdir -p app && echo '{}' > app/package.json

run_case() {
  local scenario="$1" require="$2" expected="$3"
  export BOOTPROOF_FAKE_SCENARIO="$scenario"
  rm -f "$WORK/out" "$WORK/summary" "$WORK/stdout" "$WORK/stderr"
  INPUT_PATH="$WORK/app" \
  INPUT_TIMEOUT=1000 \
  INPUT_INSTALL=true \
  INPUT_REQUIRE_HEALTH="$require" \
  INPUT_BOOTPROOF_VERSION=0.3.0 \
  GITHUB_OUTPUT="$WORK/out" \
  GITHUB_STEP_SUMMARY="$WORK/summary" \
  bash "$REPO_ROOT/gate.sh" >"$WORK/stdout" 2>"$WORK/stderr"
  local actual=$?
  if [ "$actual" = "$expected" ]; then
    echo "  PASS  scenario=$scenario  require-health=$require  exit=$actual"
    return 0
  else
    echo "  FAIL  scenario=$scenario  require-health=$require  exit=$actual (expected $expected)"
    echo "        --- stderr ---"
    sed 's/^/          /' "$WORK/stderr" 2>/dev/null
    echo "        --- stdout ---"
    sed 's/^/          /' "$WORK/stdout" 2>/dev/null
    return 1
  fi
}

PASS=0; FAIL=0
declare -a CASES=(
  "health-true   true   0"
  "health-true   false  0"
  "health-false  true   1"
  "health-false  false  0"
  "boot-fail     true   1"
  "boot-fail     false  1"
  "bad-json      true   1"
  "bad-json      false  1"
)

echo "Running Receipt Gate scenario matrix (8 cases)..."
echo ""

for case in "${CASES[@]}"; do
  read -r scenario require expected <<< "$case"
  if run_case "$scenario" "$require" "$expected"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" = "0" ] || exit 1
