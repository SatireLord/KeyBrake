# Contributing to KeyBrake

KeyBrake is an experimental macOS recovery prototype. Contributions must preserve safety boundaries and truthful documentation.

## Before you start

1. Read [`docs/KEYBRAKE_CAPABILITY_MATRIX.md`](docs/KEYBRAKE_CAPABILITY_MATRIX.md) for capability classifications.
2. Read [`docs/KEYBRAKE_RECOVERY_CONTRACT.md`](docs/KEYBRAKE_RECOVERY_CONTRACT.md) before changing recovery behavior.
3. Do not run live network isolation on your primary development machine without a separate recovery path.

## Build and test

```bash
xcodegen generate
swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPM
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

## Change rules

- Keep emergency mutations behind the serialized `EmergencyCoordinator` actor.
- Route privileged commands through the typed helper boundary when elevation is required.
- Never edit the TCC database directly.
- Never claim signing, notarization, helper approval, or live isolation without a receipt in `docs/KEYBRAKE_VERIFICATION.md`.
- Update the capability matrix when user-visible behavior changes.

## Pull requests

Include:

- What changed and why
- Capability classification (`implemented`, `fixture-only`, `host-unverified`, etc.)
- Focused test commands and results
- Explicit statement of what was **not** verified on a live host

## Live mutation boundary

Fixture tests and safe-demo procedures are the default proof path. Live destructive tests require a staged Mac session documented in the PR.
