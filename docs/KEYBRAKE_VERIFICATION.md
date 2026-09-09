# KeyBrake verification record

## Baseline

- Repository: new; no source, project, Git history, build, or tests existed at the required canonical path.
- Baseline branch: `main` before the first commit; the repository was created at the canonical path because no prior checkout existed.
- Baseline dirty paths: all initial KeyBrake files were task-owned; generated `.build/`, `build/`, and `.codegraph/` paths are ignored.
- Baseline build/tests: not applicable before the native project was created.
- Agent-Cache: repository `keybrake` is not registered; operator session unavailable and operator doctor reported `Unknown repository id 'keybrake'`.
- Connected discovery: no `SatireLord/KeyBrake` repository; no matching Drive specification; local workspace search found no other KeyBrake candidate.

## Proof ledger

The entries below are updated with exact commands and actual results as implementation advances. A local pass proves only the command that ran; it does not prove signing, notarization, helper approval, or live destructive behavior.

| Area | Command or evidence | Result |
| --- | --- | --- |
| Foundation | `/opt/homebrew/bin/xcodegen generate`; `xcodebuild -list`; `xcodebuild -showBuildSettings` | pass; native targets, schemes, bundle identifier, entitlements, helper plist, and feature-contract resource are present |
| Core type-check | direct `xcrun swiftc -typecheck -parse-as-library` over `KeyBrakeCore/*.swift` | pass |
| App/helper type-check | direct module emission followed by app and helper `swiftc -typecheck` | pass |
| Complete tests | `/Users/michaeltran/bin/swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPM` | pass; 12 tests, 0 failures |
| SwiftPM app build | `/Users/michaeltran/bin/swift build --scratch-path /tmp/KeyBrakeSwiftPM --product KeyBrake` | pass; executable product compiled and linked |
| Xcode build | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake ... build` and Core retry | blocked by Xcode BuildService setup; no source diagnostic was emitted before interruption |
| Runtime launch | staged SwiftPM executable in a temporary `.app`, added `CFBundleExecutable`, and launched with `open -n` | pass; process launched and exited without a crash; no persistent live app was left running |
| Runtime UI | required Computer Use preflight and Computer Use session | not claimed; preflight passed, but Computer Use service startup failed, so no menu click or accessibility proof is asserted |
| Network | fixture inventory and restore tests; live isolation | fixture proof passed; live mutation intentionally not run |
| Signing | `codesign`/`spctl` | not claimed; no Developer ID signing identity or release bundle was available |

## Safety boundaries

No cloud CI, telemetry, remote logging, or runtime network dependency is added. The app never edits TCC databases, user Espanso files, user documents, or Keychain contents. The app does not run live network isolation from an active remote execution path.

## Evidence boundaries

The SwiftPM proof validates the shared typed core and the debug app product. It does not prove Xcode archive output, Developer ID signing, SMAppService installation, privileged-helper audit-token authorization, TCC behavior, or live network isolation. Those boundaries remain visible in the master checklist and are not represented as completed runtime claims.

## Regression checksum anchors

These SHA-256 values anchor the safety contract and the highest-risk command seams for this deliverable. They are recorded after the final source/doc edits; a later change must recompute and review the affected value.

```text
f1bc5ca2d725220ac2173daefb2df45fbb80bca1f72bd4bbad44b1815222970f  Resources/KeyBrakeFeatureContract.json
50d16a40121c6a87ccff29ec5c9a16aaf29029a023a23dce29f31d39c2c2c09f  docs/KEYBRAKE_RECOVERY_CONTRACT.md
b29b538b5e6b63ead54edcfffd3a91a2ee8a9afed36faff0d41828a6f3de817e  KeyBrakeCore/HelperClient.swift
e5ae969421494ed6968344d09e615440f5bc0de0f56c4e1542b7adbcf5007fc4  KeyBrakePrivilegedHelper/HelperService.swift
e6a8b4772557f92b17b9825a0927155f85c5a1b138634377286ff544532aa369  KeyBrakeCore/EmergencyCoordinator.swift
```
