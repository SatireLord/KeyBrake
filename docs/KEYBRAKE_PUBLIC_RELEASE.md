# Public source flip checklist

This checklist recorded the public source flip for KeyBrake. Further visibility changes remain operator-owned.

## Current status

| Surface | Status |
| --- | --- |
| Source tree on `main` | Merged prototype (`3c16897`) |
| GitHub visibility | **Public** |
| Downloadable binary | **BLOCKED** — unsigned local bundle only |
| PR [#1](https://github.com/SatireLord/KeyBrake/pull/1) | **Merged** |

## Source work already in this tree

- MIT `LICENSE`
- `SECURITY.md` with GitHub private vulnerability reporting
- `CODE_OF_CONDUCT.md`, `CHANGELOG.md`, issue and pull-request templates
- Capability matrix, recovery contract, safe demo, and verification ledger
- Local SwiftPM tests, Xcode tests, and unsigned Release build as the default proof path
- Bundled feature contract is loaded at runtime with fallback; recovery panel opens the incident log through the menu-bar window bridge

## Operator-only sequence

1. Choose the public identity story: GitHub `SatireLord`, copyright `Michael Tran`, bundle IDs `org.realitygood.*`.
2. Enable GitHub private vulnerability reporting if it is not already enabled.
3. ~~Review and merge PR #1 onto `main` **before** making the repository public.~~ **Done** — merged 2026-10-02 as `3c16897`.
4. ~~Confirm `main` contains the merged prototype.~~ **Done**.
5. ~~Change GitHub visibility to public~~ **Done** after merge; README reflects experimental public source.
6. Leave downloadable binary **BLOCKED** until Developer ID, helper approval, and live recovery receipts exist (see [`KEYBRAKE_OPERATOR_SIGNED_RELEASE.md`](KEYBRAKE_OPERATOR_SIGNED_RELEASE.md)).

## Still out of scope after a source flip

Developer ID signing, notarization, SMAppService helper approval, live TCC, live network isolation, and mouse-only UI proof.
