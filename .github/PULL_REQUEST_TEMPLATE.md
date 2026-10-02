## Summary

What changed and why.

## Capability classification

Mark the user-visible behavior using `implemented`, `fixture-only`, `host-unverified`, `source-present but unwired`, or `planned`. Update `docs/KEYBRAKE_CAPABILITY_MATRIX.md` when that classification changes.

## Proof

Commands run and results:

```text
swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPM
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

## Not verified

Explicitly list live-host work that was **not** run (signing, helper approval, TCC mutation, live network isolation, mouse-only UI).
