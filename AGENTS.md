# KeyBrake agent entrypoint

KeyBrake is a local-first macOS menu-bar failsafe. Keep process control exact, keep recovery mouse-driven, and keep claims limited to verified operations.

Before changing recovery, process, network, helper, or privacy behavior, read:

- [`docs/KEYBRAKE_RECOVERY_CONTRACT.md`](docs/KEYBRAKE_RECOVERY_CONTRACT.md)
- [`docs/KEYBRAKE_CAPABILITY_MATRIX.md`](docs/KEYBRAKE_CAPABILITY_MATRIX.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)

## Safety

- Do not edit TCC databases or restore TCC grants automatically.
- Do not run live network isolation, VPN disconnect, or sharing mutation through an active remote or primary development session. Use fixtures and [`docs/KEYBRAKE_SAFE_DEMO.md`](docs/KEYBRAKE_SAFE_DEMO.md) unless a staged Mac with a known recovery path is documented.
- Do not terminate processes by substring, run arbitrary shell commands, perform a global privacy reset, or target KeyBrake itself.
- Do not discard the user's uncommitted work. Do not force-push shared branches.
- Do not make the GitHub repository public. Do not merge pull request #1 unless the human maintainer explicitly asks.

## Proof

After `project.yml` changes, run `xcodegen generate`.

```bash
xcodegen generate
swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPM
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

Do not claim Developer ID signing, notarization, privileged-helper approval, TCC execution, or live network isolation unless a corresponding receipt exists in [`docs/KEYBRAKE_VERIFICATION.md`](docs/KEYBRAKE_VERIFICATION.md).

Update the capability matrix when user-visible behavior changes. Commit coherent deliverables, push the active branch, and verify branch divergence; leave PR merge and GitHub visibility changes to the human maintainer.

## Last Rule — Shared Agent Dictionary (Dogfooding)

During this dogfooding phase, all agents must read and follow `/Users/michaeltran/AntiGravity/Agent-Manager/Agent-Dictionary-Standardized/README.md` and the canonical terms in `terms.json` in that directory. Use its labels and meanings consistently in instructions, plans, task records, handoffs and reports. When a term is missing, ambiguous or conflicts with current source, record the discrepancy and a sourced proposed definition for the dictionary's assigned writer; preserve the distinction between user approval, recipient acceptance, work progress, verification and delivery. Dictionary updates follow its schema and update procedure.

<!-- AGENT-CACHE-SEED:agent-cache-tether:ask-first:BEGIN -->
## Agent-Cache tether (ask before you discover)

- Ask the hub first: MCP `agent_cache_ask` with `repo_root` set to this repo and `question` set to "how do I ...". It returns the live symbols, lane protocols, linked skills, past PRs, banned patterns and checksum regions for the question.
- Before running a risky shell command, pass it as `command`. Matching banned patterns come back with the route to use instead.
- CLI fallback: `PYTHONPATH=<agent-cache>/src python3 -m agent_cache.packet_learning ask --repo . --question "<how do I ...>"`.
- This block and `.agent-cache-tether.json` are owned by the Agent-Cache seed `agent-cache-tether`. Change the seed, not this block. `tether heal` adopts local edits as a repo variant.
<!-- AGENT-CACHE-SEED:agent-cache-tether:ask-first:END -->

<!-- AGENT-CACHE-SEED:agent-work-rules:agent-work-rules:BEGIN -->
## Shared agent work rules (fleet seed `agent-work-rules`)

These rules apply in every repo. The full text and examples live in `~/.agents/agent-team-contract.md`; this block only routes to them.

- **Defense in depth; re-employ, never just remove.** Protect each behavior with more than one layer (guard or checksum, focused test, runtime check, fail-loud alert). A superseded or criticized mechanism that still works stays as a fallback, diagnostic, opt-in mode or lower layer. The simplest synchronous layer comes first, and a kept layer never delays it. Removal is the last resort: consumer trace, replacement owner, lossless migration, regression proof and the user's approval.
- **Solve blockers for the future.** Fix the cause at its owner so no later agent hits it again, with no per-case literals or repeated manual steps. Record the friction with its route the same turn.
- **No hardcoding.** Before writing a literal, check its owner, variability and comparator. UI sizes come from the owning container, measured at runtime. Thresholds come from their owner and fail loud when it is missing. Test expectations come from the same owner.
- **Fail loud.** Exit non-zero with one reason line. A fallback names itself `DEGRADED: <why>`. Never swallow an exception silently.
- **Looped work never stops at the end of a list.** Take the next triage item, in order:
  1. anything you broke, or a claim that turned out false;
  2. backlog and [Current PR + 1] items;
  3. fresh live audit findings;
  4. friction rows and reusable tools;
  5. sibling defects of the bug class just fixed.

  Ask the user only for design choices, reserved destructive steps or credentials.
- **Cut output waste.** Report results, not process. Filter tool output. Do not rerun checks on unchanged bytes.
- **Keep historical data.** Never delete old ledgers, receipts, memory stores or the unique commits on old branches. Back them up and index them instead.
<!-- AGENT-CACHE-SEED:agent-work-rules:agent-work-rules:END -->
