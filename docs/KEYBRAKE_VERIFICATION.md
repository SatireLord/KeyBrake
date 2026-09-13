# KeyBrake verification record

## Historical baseline

- Repository: new; no source, project, Git history, build, or tests existed at the required canonical path.
- Baseline branch: `main` before the first commit; the repository was created at the canonical path because no prior checkout existed.
- Baseline dirty paths: all initial KeyBrake files were task-owned; generated `.build/`, `build/`, and `.codegraph/` paths are ignored.
- Baseline build/tests: not applicable before the native project was created.
- Local agent routing was not registered during baseline discovery; the current checkout is the canonical KeyBrake product repository.
- Connected discovery: no `SatireLord/KeyBrake` repository was found during baseline discovery; the current private repository and pull request are recorded in the master plan.

## Current release pass

- Canonical repository: private GitHub `SatireLord/KeyBrake` on branch `codex/keybrake-complete-implementation`.
- Last source delivery checkpoint: `8a77357`. Later documentation and public-source hygiene commits may advance HEAD without changing that source checkpoint.
- Version: `0.1.0` (build `1`).
- Release judgments: GitHub visibility **HOLD**; downloadable binary **BLOCKED** (see `docs/KEYBRAKE_CAPABILITY_MATRIX.md`).
- XcodeGen resource routing: the app contract JSON, helper service plist, and helper executable are verified in an unsigned Release bundle; signed installation and live SMAppService approval remain unverified.

## Proof ledger

The entries below are updated with exact commands and actual results as implementation advances. A local pass proves only the command that ran; it does not prove signing, notarization, helper approval, or live destructive behavior.

| Area | Command or evidence | Result |
| --- | --- | --- |
| Foundation | `xcodegen generate`; `xcodebuild -list`; `xcodebuild -showBuildSettings` | pass; native targets, schemes, bundle identifier, entitlements, helper plist, and feature-contract resource are present |
| Core type-check | `xcrun swiftc -typecheck -parse-as-library` over `KeyBrakeCore/*.swift` | pass |
| App/helper type-check | module emission followed by app and helper `swiftc -typecheck` | pass |
| Complete tests | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMContinue` | pass; 33 tests, 0 failures |
| Version-gated privacy allowlist | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMPrivacyGated --filter PrivacyControllerTests` | pass; 4 tests, 0 failures; minimum macOS version and catalog membership are enforced before `tccutil` |
| SwiftPM app build | `swift build --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMKB031 --product KeyBrake` | pass; executable product compiled and linked; receipt label `keybrake-kb031-swiftpm-build` |
| Xcode Debug build | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Debug -derivedDataPath /tmp/KeyBrakeKB031DerivedData CODE_SIGNING_ALLOWED=NO build` | pass; exit 0; helper target compiled and embedded into the unsigned Debug app |
| Xcode Release build | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Release -derivedDataPath /tmp/KeyBrakeReleaseContinue -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` | pass; ** BUILD SUCCEEDED **; unsigned app/helper bundle at `/tmp/KeyBrakeReleaseContinue/Build/Products/Release/KeyBrake.app` with helper executable, LaunchDaemons plist, and feature contract |
| Xcode tests | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Debug -derivedDataPath /tmp/KeyBrakeXcodeTestContinue -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test` | pass; ** TEST SUCCEEDED **; 33 tests, 0 failures |
| App/helper bundle contents | `find`, `plutil`, `lipo`, and Mach-O inspection against `/tmp/KeyBrakeKB031ReleaseDerivedData/Build/Products/Release/KeyBrake.app` | pass; app and helper binaries, embedded `KeyBrakePrivilegedHelper`, `Contents/Library/LaunchDaemons/org.realitygood.KeyBrake.Helper.plist`, framework, feature contract, and bundle metadata are present |
| Runtime launch | staged SwiftPM executable in a temporary `.app`, added `CFBundleExecutable`, and launched with `open -n` | pass; process launched and exited without a crash; no persistent live app was left running |
| Runtime UI | menu click and accessibility session | not claimed; no mouse-only proof is asserted |
| Open-source boundary | `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, capability matrix, tracked-path scan | MIT license and policy files exist on the implementation branch; GitHub remains private; no public/tagged binary release is claimed |
| Network | fixture inventory and restore tests; live isolation | fixture proof passed; live mutation intentionally not run |
| Verified launchd stop | `EmergencyCoordinator` fixture with an approved launch-agent label; helper target compiled in the Xcode app build | pass for typed coordinator-to-helper routing and helper identity-check implementation; live signed helper authorization, launchd mutation, and respawn proof remain host-unverified |
| Signing | `codesign`/`spctl` | not claimed; the Release bundle is unsigned because local proof uses `CODE_SIGNING_ALLOWED=NO` and no Developer ID signing identity is configured |
| Versioning | `SupportingFiles/Info.plist` | pass; `CFBundleShortVersionString` is `0.1.0` and `CFBundleVersion` is `1` |
| Target settings and recovery UI | focused source review plus local compile/test | pass for persisted policy, helper status, automatic recovery presentation, independent network/sharing actions, and busy-state guards; live mouse proof is not claimed |

## Safety boundaries

No cloud CI, telemetry, remote logging, or runtime network dependency is added. The app never edits TCC databases, user Espanso files, user documents, or Keychain contents. The app does not run live network isolation from an active remote execution path.

## Evidence boundaries

The SwiftPM proof validates the shared typed core and the debug app product. The Xcode proof validates an unsigned app bundle, its embedded helper executable, the LaunchDaemons plist, the feature contract resource, and the helper target. It does not prove archive output, Developer ID signing, SMAppService installation, live privileged-helper authorization, TCC behavior, live network isolation, or mouse-only interaction. Those boundaries remain visible in the master checklist and are not represented as completed runtime claims.

## Regression checksum anchors

These SHA-256 values anchor the safety contract and the highest-risk command seams for this deliverable. They are recorded after the final source/doc edits; a later change must recompute and review the affected value.

```text
f1bc5ca2d725220ac2173daefb2df45fbb80bca1f72bd4bbad44b1815222970f  Resources/KeyBrakeFeatureContract.json
50d16a40121c6a87ccff29ec5c9a16aaf29029a023a23dce29f31d39c2c2c09f  docs/KEYBRAKE_RECOVERY_CONTRACT.md
98ea157c6a637ea0f085bd93bb673bcb59a1c04e3774c7c605a864b84abb705f  KeyBrakeCore/HelperClient.swift
ca01abde03d3e8c5d560a52cedd8a75aa52ceb73bec02132a2fa98b042a6fc95  KeyBrakePrivilegedHelper/HelperService.swift
4f874840014b8ffd4eecc46123c55d107356b4e7bac00d5e6c2c027bf454c900  KeyBrakeCore/EmergencyCoordinator.swift
c595a7172f250472c81a7788cdb13cd8f13f2493a79ed476c8ef1e9b3f83b323  KeyBrakeCore/NetworkController.swift
a228776765d99a6d93ab1a94100e61e1bdadd31290b71d2f2791c50002f3f847  KeyBrakeCore/SharingServiceController.swift
f9a32d8dce8bd950a1e4b9d0fc2a66ff3d32eb08f9f3cecb4c62d6e2cdb32919  KeyBrake/App/KeyBrakeViewModel.swift
865a0964e361b267563040205e45601b4219fbb9199db93402509614437a107c  KeyBrake/UI/SettingsView.swift
cd9803dc5388451387916248fe36f750f535e576f4a0b419827ce21eade91ba5  KeyBrake/UI/RecoveryView.swift
c9837ceb1acf0f105568c654976de8838589cd35e2d95684c90dc574649d2ba1  KeyBrakeCore/ProcessController.swift
cfe335cd46f597a8cf9211d4ab888c94911659e38502ca0b86deb16df082b8e1  KeyBrakeCore/CommandRunner.swift
40a6cd6e831db57a11a292a573ce4f85918446791a8260856e5d1c10e52d389e  KeyBrakeCore/RecoveryStore.swift
252f84f4ceef6489c32415281b3a2c338d4e0c31b175e8e44506a17737f7a15e  KeyBrakeCore/PrivacyController.swift
```
