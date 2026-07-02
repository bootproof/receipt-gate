# Launch Kit — Receipt Gate / BootProof

## The Show HN post

**Title:** Show HN: My AI agent now hands me a signed receipt proving its work actually ran

**Body:**

Like everyone, I've been reviewing AI-generated code that compiles, passes its own tests, and doesn't run. So I built the thing I wanted: when an agent (or a human) claims work is done, the claim arrives as a receipt — the app was actually booted, supervised, and observed answering HTTP, and the evidence is written into an ed25519-signed attestation you can verify independently on any machine with `npx bootproof verify`. No account, no platform, no dashboard.

Two ways to use it:

1. `npx bootproof up .` — boots the repo you're standing in and signs what it observed. There's also a "Living Receipt": the same evidence as a single self-contained HTML file that re-verifies its own signature in your browser and visibly collapses if you tamper with a single byte. (Try it — there's a tamper button.)

2. Receipt Gate — a GitHub Action so no agent PR merges without an observed boot signal. Green tests assert what the author thought to check; the gate requires the application to actually run.

The part I care most about is what it *refuses* to claim. No observed signal → no green check. A local receipt proves integrity-since-signing, not that the signing machine was honest — that's stated in the artifact itself, with a documented trust ladder (local → CI-OIDC → neutral runner → transparency log) as the upgrade path. A trust tool that overclaims is worse than no tool, so this one is deliberately conservative.

It's early (v0.3.0), open source, and I'd genuinely value having it broken by this crowd.

---

## First-two-hours crib sheet

**"Can't the agent just fake the receipt?"**
Not by editing it — any byte change invalidates the signature and the verdict collapses; that's the whole design. Can a hostile *signer* sign lies? At the local trust level, yes in principle — which is why the trust level is printed on the receipt itself and why the ladder exists. Run the gate in CI and the agent never touches the signing context. I'd rather state this limit plainly than sell you a green check that can't cash itself.

**"How is this different from CI tests passing?"**
Tests assert what the author thought to check — and when the author is the agent, the tests share the author's blind spots. The receipt is observational: process started, supervised, HTTP answered, evidence captured. Also: a CI tick lives on one platform; the receipt is a portable file that verifies anywhere.

**"in-toto / SLSA / Sigstore already exist."**
They're the reason the signing design looks the way it does — but they attest *build provenance* (how an artifact was built, for policy engines, verified with tooling). This attests *runtime behavior* (it ran, it answered), rendered so a human can verify it by opening a file. Complementary, not competing — an in-toto-compatible predicate for the receipt schema is on the roadmap so both worlds compose.

**"What about apps that need Postgres/Redis/secrets?"**
Compose-aware inference exists but is young; complex stacks are the hard frontier and I won't pretend otherwise. The gate is most valuable exactly where agent PRs are most common today: services and apps that should boot standalone. Failure classes are preserved in the attestation — bring me the ones it can't classify.

**"Why should I trust *your* tool's judgment?"**
You shouldn't — that's the point. It doesn't ask for trust in its judgment; it captures evidence and signs it. `bootproof verify` is independent of me, the receipt is readable JSON, and the verifier for Living Receipts runs entirely in your browser with zero network calls.

**"This is a wrapper around 'npm start && curl'."**
The boot is, deliberately — boring and inspectable. The product is what surrounds it: inference of how an arbitrary repo boots, supervision, failure classification, and evidence that is signed, portable, and tamper-evident. "curl in CI" leaves you a log line someone can edit; this leaves you a receipt nobody can.

---

## The ten keystrokes (in order, nothing skipped)

1. Create `github.com/bootproof/receipt-gate`, push these three files (`action.yml`, `gate.sh`, `README.md`).
2. Tag `v1` (`git tag v1 && git push --tags`) — Actions consumers pin to it.
3. Add the Receipt Gate workflow to the bootproof repo itself — the product must wear its own badge first.
4. Record one 60-second GIF: agent PR opens → gate fails closed → fix → gate passes → receipt artifact. Both paths, no cuts.
5. Fix the health-path inference nit (receipt honestly signed a 404 at `/` when the service answered on `/health`; route inference or a `--health-path` flag turns that into a clean 200).
6. Put the Living Receipt download + tamper demo at the top of the README if it isn't already the first thing a visitor meets.
7. Post the Show HN above, Tuesday–Thursday, 13:00–14:00 UK time.
8. Answer every comment in the first two hours using the crib sheet — this is the launch, everything else is amplification.
9. Same day: post to r/ClaudeAI, r/ChatGPTCoding, and the Claude Code community — the agent-hook snippet is the hook for that audience.
10. Find maintainer #1: one real project that adopts the gate and displays the badge. One is infinitely more than zero, and the badge loop starts there.
