# Receipt Gate

**No merge without proof it runs.**

AI agents open pull requests that compile, pass the tests they wrote, and don't run. Receipt Gate closes the gap between "the checks are green" and "the application actually works": it boots your app in CI, requires an observed health signal, and blocks the merge unless one exists. The evidence is written as an ed25519-signed attestation — a portable receipt anyone can independently verify with `npx bootproof verify`, on any machine, with no account and no platform.

Green tests assert what the author thought to check. A receipt records what was observed. Different things.

## Use it in a workflow

```yaml
name: receipt-gate
on: [pull_request]

jobs:
  prove-it-runs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Require proof of boot
        uses: bootproof/receipt-gate@v1
        with:
          path: .
          timeout: '60000'
```

That's it — no `setup-node` step needed. The action sets up Node 20 internally.

Every run uploads the signed receipt as a `boot-receipt` workflow artifact. Attach it to the PR, the release, the invoice — it verifies itself wherever it lands.

## What "pass" means

The gate has two modes, controlled by the `require-health` input (default: `true`):

| `booted` | `healthVerified` | `require-health=true` (default) | `require-health=false` |
|---|---|---|---|
| `true` | `true` | ✅ PASS | ✅ PASS |
| `true` | `false` | ❌ FAIL | ✅ PASS |
| `false` | `*` | ❌ FAIL | ❌ FAIL |
| invalid JSON | — | ❌ FAIL (closed) | ❌ FAIL (closed) |

The default (`require-health=true`) requires an observed HTTP health signal — the app must actually answer. Set `require-health: false` only if you have a specific reason to accept process-only boot (e.g. a worker process with no HTTP endpoint).

```yaml
- uses: bootproof/receipt-gate@v1
  with:
    path: .
    require-health: false   # accept process-only boot
```

## Pinning (recommended for trust/proof tools)

`@v1` is a moving tag — it tracks the latest v1.x release. For a tool whose entire purpose is trust, pin to a specific commit SHA instead:

```yaml
- uses: bootproof/receipt-gate@<commit-sha>  # immutable, auditable
```

Get the current SHA:
```bash
git ls-remote https://github.com/bootproof/receipt-gate.git refs/tags/v1
```

## Gate your AI agent directly

If you use Claude Code (or any agent with lifecycle hooks), make the agent hand you a receipt every time it claims to be done. In `.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "npx -y bootproof@0.3.0 up . --provider local --unsafe-local --json --timeout 60000 > .bootproof-last.json; node -e \"const r=require('./.bootproof-last.json'); console.log(r.booted && r.healthVerified ? '✅ RECEIPT: work boots and answers — signed attestation at ' + r.attestationPath : '❌ NO RECEIPT: ' + (r.failureClass||r.booted ? 'booted but no health signal' : 'boot not observed') + ' — the work does not provably run');\""
          }
        ]
      }
    ]
  }
}
```

The agent finishes; the receipt (or its absence) prints before you review a single line.

## What the receipt does and does not prove

A receipt at trust level `local_developer_signed` proves the evidence has not been altered since signing — integrity, not the honesty of the machine that signed it. Inside CI the runner context strengthens this; the documented trust ladder (`local_developer_signed` → `ci_oidc_signed` → `neutral_runner_signed` → `transparency_logged`) is the upgrade path, and the file format survives every rung. A gate that overclaimed would defeat its own purpose, so this one doesn't: no observed signal, no green check — and no green check pretending to be more than an observed signal.

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `path` | `.` | Path to the application inside the repo |
| `timeout` | `60000` | Health verification timeout in ms |
| `install` | `true` | Run the dependency install step before booting |
| `require-health` | `true` | Require observed HTTP health (not just process boot) |
| `bootproof-version` | `0.3.0` | Pinned bootproof version from npm |

## Outputs

| Output | Meaning |
|---|---|
| `booted` | `true` if an observed boot signal exists |
| `health-verified` | `true` if an HTTP health signal was observed |
| `failure-class` | BootProof failure classification when not booted |
| `attestation-path` | Path to the signed ed25519 attestation (the receipt) |

## Requirements

None beyond a standard GitHub runner. The action sets up Node 20.11+ internally (matching the `bootproof` engine requirement). The gate runs `bootproof` with `--provider local`; a CI runner is an ephemeral sandbox, which is exactly the acknowledgement that flag requires.

## Compliance posture

Receipt Gate is designed to produce evidence that survives an audit. The signed attestation is the primary artifact; everything below follows from it.

- **Tamper-evident by construction.** Every attestation is ed25519-signed. Any byte change invalidates the signature. `npx bootproof verify` checks this independently; the Living Receipt re-verifies in a browser with zero network calls.
- **Redaction in the evidence path.** Secrets are redacted from the attestation before it is written — not filtered after. The receipt contains no credentials, tokens, or env values that bootproof observed.
- **Deterministic failure classification.** When the gate fails, the `failure-class` output carries bootproof's classified failure taxonomy (e.g. `not_an_application`, `health_check_timeout`, `port_conflict`). An auditor sees the same class string the engine produced.
- **7-year artifact retention.** The action uploads the receipt as a workflow artifact with `retention-days: 2555` (~7 years), supporting audit timelines under EU AI Act Article 9, NIST AI RMF, and enterprise governance frameworks. For longer retention, download and archive externally.
- **Offline verification.** `npx bootproof verify` works with no network access. An auditor does not need a bootproof account, a dashboard, or a live CI connection to validate a receipt.
- **Trust ladder, stated on the receipt.** A receipt signed at `local_developer_signed` proves integrity-since-signing, not that the signing machine was honest. The receipt says so. The upgrade path (`local_developer_signed` → `ci_oidc_signed` → `neutral_runner_signed` → `transparency_logged`) is documented in the artifact itself.

What the gate does **not** claim:
- It does not vouch for the honesty of the CI runner — only for the integrity of the evidence since it was signed.
- It does not produce an SBOM. Dependency provenance is a separate concern (on the bootproof roadmap).
- It does not sign with OIDC by default. CI-OIDC signing is a higher trust level on the roadmap; today the gate signs at `local_developer_signed` inside the runner context.

## License

Apache-2.0, same as [`bootproof`](https://github.com/bootproof/bootproof).
