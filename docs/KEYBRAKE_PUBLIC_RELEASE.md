# Public source flip checklist

This is the operator checklist for making KeyBrake source public. Agents must not flip GitHub visibility or merge PR #1.

## Current status

| Surface | Status |
| --- | --- |
| Source tree on `codex/keybrake-complete-implementation` | Prepared for a human identity/visibility decision |
| GitHub visibility | **HOLD** — repository remains private |
| Downloadable binary | **BLOCKED** — unsigned local bundle only |
| PR [#1](https://github.com/SatireLord/KeyBrake/pull/1) | Open and unmerged until human review |

## Source work already in this tree

- MIT `LICENSE`
- `SECURITY.md` with GitHub private vulnerability reporting
- `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, issue and pull-request templates
- Capability matrix, recovery contract, safe demo, and verification ledger
- Local SwiftPM tests and unsigned Release build as the default proof path

## Operator-only sequence

1. Choose the public identity story: GitHub `SatireLord`, copyright `Michael Tran`, bundle IDs `org.realitygood.*`.
2. Enable GitHub private vulnerability reporting if it is not already enabled.
3. Review and merge PR #1 onto `main` **before** making the repository public. Default `main` currently lacks `LICENSE` and the implementation.
4. Confirm `main` contains the merged prototype.
5. Change GitHub visibility to public only after that merge.
6. After the flip, change the README public-source row from HOLD to experimental public source. Leave downloadable binary **BLOCKED** until Developer ID, helper approval, and live recovery receipts exist.

## Still out of scope after a source flip

Developer ID signing, notarization, SMAppService helper approval, live TCC, live network isolation, and mouse-only UI proof.
