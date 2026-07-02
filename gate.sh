#!/usr/bin/env bash
# Receipt Gate — no merge without proof the work actually runs.
# Runs BootProof against the repo, parses the signed result, and fails the
# check unless an observed boot signal exists. By default (require-health=true)
# it also requires an observed HTTP health signal — not just a running process.
# The attestation is the receipt.
set -uo pipefail

APP_PATH="${INPUT_PATH:-.}"
TIMEOUT_MS="${INPUT_TIMEOUT:-60000}"
INSTALL="${INPUT_INSTALL:-true}"
BP_VERSION="${INPUT_BOOTPROOF_VERSION:-0.3.0}"
REQUIRE_HEALTH="${INPUT_REQUIRE_HEALTH:-true}"
RESULT_FILE="$(mktemp)"

FLAGS=(up "$APP_PATH" --provider local --unsafe-local --json --timeout "$TIMEOUT_MS")
# --provider local is safe here by construction: a CI runner is already an
# ephemeral sandbox, which is precisely the acknowledgement --unsafe-local asks for.
if [ "$INSTALL" = "true" ]; then FLAGS+=(--install); fi

echo "Receipt Gate: running bootproof@${BP_VERSION} ${FLAGS[*]}"
echo "Receipt Gate: require-health=${REQUIRE_HEALTH} (true = observed HTTP health signal required; false = process boot accepted)"
npx -y "bootproof@${BP_VERSION}" "${FLAGS[@]}" > "$RESULT_FILE" 2> bootproof-stderr.log
BP_EXIT=$?

if ! node -e "JSON.parse(require('fs').readFileSync('$RESULT_FILE','utf8'))" 2>/dev/null; then
  echo "::error::Receipt Gate: bootproof produced no parseable result (exit $BP_EXIT). Failing closed — no proof, no merge."
  tail -20 bootproof-stderr.log || true
  echo "booted=false" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 1
fi

BOOTED=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$RESULT_FILE','utf8')).booted === true ? 'true' : 'false')")
HEALTH=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$RESULT_FILE','utf8')).healthVerified === true ? 'true' : 'false')")
FAILCLASS=$(node -e "const r=JSON.parse(require('fs').readFileSync('$RESULT_FILE','utf8')); console.log(r.failureClass ?? 'none')")
ATTESTATION=$(node -e "const r=JSON.parse(require('fs').readFileSync('$RESULT_FILE','utf8')); console.log(r.attestationPath ?? '')")
EXPLANATION=$(node -e "const r=JSON.parse(require('fs').readFileSync('$RESULT_FILE','utf8')); console.log((r.explanation ?? '').toString().slice(0,400))")

{
  echo "booted=$BOOTED"
  echo "health-verified=$HEALTH"
  echo "failure-class=$FAILCLASS"
  # Guard: only emit attestation-path when one actually exists. Emitting "./"
  # for an empty attestation would give downstream steps a malformed path.
  if [ -n "$ATTESTATION" ]; then
    echo "attestation-path=${APP_PATH%/}/${ATTESTATION}"
  fi
} >> "${GITHUB_OUTPUT:-/dev/null}"

# Determine pass/fail.
# Default (require-health=true): pass only if booted=true AND healthVerified=true.
# Weak mode  (require-health=false): pass if booted=true (process-only OK).
GATE_PASS=true
REASON=""
if [ "$BOOTED" != "true" ]; then
  GATE_PASS=false
  REASON="no observed boot signal (class: $FAILCLASS)"
elif [ "$REQUIRE_HEALTH" = "true" ] && [ "$HEALTH" != "true" ]; then
  GATE_PASS=false
  REASON="process started but no HTTP health signal observed (require-health=true; the app booted but did not answer a health probe)"
fi

SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"
if [ "$GATE_PASS" = "true" ]; then
  HEALTH_LABEL="$([ "$HEALTH" = "true" ] && echo '✅ verified' || echo '⚠️ process only (require-health=false)')"
  {
    echo "## ✅ Receipt Gate — PASS (observed, signed)"
    echo ""
    echo "| Check | Result |"
    echo "|---|---|"
    echo "| Boot observed | ✅ yes |"
    echo "| Health signal | $HEALTH_LABEL |"
    echo "| require-health | \`$REQUIRE_HEALTH\` |"
    echo "| Signed receipt | \`$ATTESTATION\` (uploaded as workflow artifact) |"
    echo ""
    echo "This is runtime evidence, not a test result: the app was started, supervised, and observed. The attestation is ed25519-signed and independently verifiable with \`npx bootproof verify\`."
  } >> "$SUMMARY_FILE"
  echo "Receipt Gate: PASS — work provably boots. Receipt at $ATTESTATION"
  exit 0
else
  {
    echo "## ❌ Receipt Gate — FAIL"
    echo ""
    echo "**Reason:** $REASON"
    echo ""
    echo "**Failure class:** \`$FAILCLASS\`"
    echo ""
    echo "$EXPLANATION"
    echo ""
    echo "No observed signal sufficient for this gate mode (require-health=\`$REQUIRE_HEALTH\`). Green tests are not proof of a running application — this check requires the application to actually run."
  } >> "$SUMMARY_FILE"
  echo "::error::Receipt Gate: FAIL — $REASON"
  exit 1
fi
