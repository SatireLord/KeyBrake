# Contributing to KeyBrake

KeyBrake is an experimental macOS recovery prototype. Contributions must preserve safety boundaries and truthful documentation.

Please read [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) and [`SECURITY.md`](SECURITY.md) first.

## Before you start

1. Read [`docs/KEYBRAKE_CAPABILITY_MATRIX.md`](docs/KEYBRAKE_CAPABILITY_MATRIX.md) for capability classifications.
2. Read [`docs/KEYBRAKE_RECOVERY_CONTRACT.md`](docs/KEYBRAKE_RECOVERY_CONTRACT.md) before changing recovery behavior.
3. Do not run live network isolation on your primary development machine without a separate recovery path.

## Build and test

```bash
xcodegen generate
swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPM
swift build -c release --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPM-release
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/KeyBrakeDerivedData-release-test \
  -parallel-testing-enabled NO -only-testing:KeyBrakeTests/EmergencyCoordinatorTests \
  CODE_SIGNING_ALLOWED=NO test
```

After `project.yml` changes, run `xcodegen generate` before Xcode commands. `KeyBrakeCore` sets `ENABLE_TESTABILITY` so Release `@testable` imports work in Xcode tests.

SwiftPM covers `KeyBrakeCore` and tests. The unsigned `.app` with the embedded helper is an Xcode product.

The `KeyBrake` Xcode scheme also builds `KeyBrakePreferencePane` and embeds the `.prefPane` product. After an app build, run `scripts/test_keybrake_preference_pane_install.sh /path/to/KeyBrake.app`; this test exercises replacement, refusal, and URL-scheme checks under temporary homes without launching System Settings.

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
