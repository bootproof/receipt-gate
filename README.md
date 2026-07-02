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

## License

Apache-2.0, same as [`bootproof`](https://github.com/bootproof/bootproof).
