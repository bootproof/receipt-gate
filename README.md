# Receipt Gate

**No merge without proof it runs.**

AI agents open pull requests that compile, pass the tests they wrote, and don't run. Receipt Gate closes the gap between "the checks are green" and "the application actually works": it boots your app in CI, waits for an observed health signal, and blocks the merge unless one exists. The evidence is written as an ed25519-signed attestation — a portable receipt anyone can independently verify with `npx bootproof verify`, on any machine, with no account and no platform.

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
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Require proof of boot
        uses: bootproof/receipt-gate@v1
        with:
          path: .
          timeout: '60000'
```

Every run uploads the signed receipt as a `boot-receipt` workflow artifact. Attach it to the PR, the release, the invoice — it verifies itself wherever it lands.

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
            "command": "npx -y bootproof@0.3.0 up . --provider local --unsafe-local --json --timeout 60000 > .bootproof-last.json; node -e \"const r=require('./.bootproof-last.json'); console.log(r.booted ? '✅ RECEIPT: work boots — signed attestation at ' + r.attestationPath : '❌ NO RECEIPT: ' + (r.failureClass||'boot not observed') + ' — the work does not provably run');\""
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

## Requirements

Node 20.11+ on the runner (matches the `bootproof` engine requirement). The gate runs `bootproof` with `--provider local`; a CI runner is an ephemeral sandbox, which is exactly the acknowledgement that flag requires.

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `path` | `.` | Path to the application inside the repo |
| `timeout` | `60000` | Health verification timeout in ms |
| `install` | `true` | Run the dependency install step before booting |
| `bootproof-version` | `0.3.0` | Pinned bootproof version from npm |

## Outputs

| Output | Meaning |
|---|---|
| `booted` | `true` if an observed boot signal exists |
| `health-verified` | `true` if an HTTP health signal was observed |
| `failure-class` | BootProof failure classification when not booted |
| `attestation-path` | Path to the signed ed25519 attestation (the receipt) |

## License

Apache-2.0, same as [`bootproof`](https://github.com/bootproof/bootproof).
