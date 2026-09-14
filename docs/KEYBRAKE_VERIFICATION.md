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
- Current runtime-source repair checkpoint: `a3968ad`. Later documentation closeout commits may advance the private branch without changing this source checkpoint.
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
| Complete tests | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMReleaseLifecycleFull` | pass; 35 tests, 0 failures |
| Termination and process-identity regression tests | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMReleaseLifecycle --filter EmergencyCoordinatorTests` | pass; 8 tests, 0 failures; startup hydration and all state-changing termination states fail closed, settled recovery requires an explicit decision, and bundle/executable/launch-date identity matching is exact |
| Version-gated privacy allowlist | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMPrivacyGated --filter PrivacyControllerTests` | pass; 4 tests, 0 failures; minimum macOS version and catalog membership are enforced before `tccutil` |
| SwiftPM app build | `swift build --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMKB031 --product KeyBrake` | pass; executable product compiled and linked; receipt label `keybrake-kb031-swiftpm-build` |
| Xcode Debug build | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Debug -derivedDataPath /tmp/KeyBrakeKB031DerivedData CODE_SIGNING_ALLOWED=NO build` | pass; exit 0; helper target compiled and embedded into the unsigned Debug app |
| Xcode Release build | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/KeyBrakeReleaseLifecycleDerivedData CODE_SIGNING_ALLOWED=NO build` | pass; ** BUILD SUCCEEDED **; unsigned universal app/helper bundle at `/tmp/KeyBrakeReleaseLifecycleDerivedData/Build/Products/Release/KeyBrake.app` with helper executable, LaunchDaemons plist, framework, and feature contract |
| Focused Xcode tests | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' -derivedDataPath /tmp/KeyBrakeXcodeLifecycleTests CODE_SIGNING_ALLOWED=NO -only-testing:KeyBrakeTests/EmergencyCoordinatorTests test` | pass; ** TEST SUCCEEDED **; 8 tests, 0 failures |
| App/helper bundle contents | `find`, `plutil`, `lipo`, and Mach-O inspection against `/tmp/KeyBrakeReleaseLifecycleDerivedData/Build/Products/Release/KeyBrake.app` | pass; universal app and helper binaries, embedded `KeyBrakePrivilegedHelper`, `Contents/Library/LaunchDaemons/org.realitygood.KeyBrake.Helper.plist`, feature contract, and bundle metadata are present |
| Runtime launch | staged SwiftPM executable in a temporary `.app`, added `CFBundleExecutable`, and launched with `open -n` | pass; process launched and exited without a crash; no persistent live app was left running |
| Cursor-safe UI preflight | `python3 /Users/michaeltran/.agents/cursor-steal-prevention/scripts/agent_ui_preflight.py --app org.realitygood.KeyBrake --display virtual-16x9 --start-sentinel --json` | pass; virtual display was present, the sentinel was active, and app-targeted Computer Use was standing-authorized; this receipt is not a screenshot or interaction proof |
| Agent Display provider | `/Users/michaeltran/bin/displayctl doctor`; `/Users/michaeltran/bin/displayctl capabilities` | pass; the owned virtual-display provider, socket, accessibility trust, `agent-stage`, and `virtual-16x9` were available; provider health does not prove that KeyBrake exposed a stageable content window |
| Recovery-panel staging attempt | `open -n /tmp/KeyBrakeReleaseLifecycleDerivedData/Build/Products/Release/KeyBrake.app`; `/Users/michaeltran/bin/displayctl stage --app KeyBrake --position above --preset 16:9`; `/Users/michaeltran/bin/displayctl is-isolated --app KeyBrake` | not proved; the task-owned Release app exposed no content window to the isolated display, so staging returned exit 4, no pointer action was sent, and no PNG was captured or claimed; the disposable recovery fixture was removed afterward |
| Open-source boundary | `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, capability matrix, tracked-path scan | MIT license and policy files exist on the implementation branch; GitHub remains private; no public/tagged binary release is claimed |
| Network | fixture inventory and restore tests; live isolation | fixture proof passed; live mutation intentionally not run |
| Verified launchd stop | `EmergencyCoordinator` fixture with an approved launch-agent label; helper target compiled in the Xcode app build | pass for typed coordinator-to-helper routing and helper identity-check implementation; live signed helper authorization, launchd mutation, and respawn proof remain host-unverified |
| Signing | `codesign`/`spctl` | not claimed; the Release bundle is unsigned because local proof uses `CODE_SIGNING_ALLOWED=NO` and no Developer ID signing identity is configured |
| Versioning | `SupportingFiles/Info.plist` | pass; `CFBundleShortVersionString` is `0.1.0` and `CFBundleVersion` is `1` |
| Target settings and recovery UI | focused source review, 35-test SwiftPM suite, 8-test Xcode lifecycle subset, and unsigned Release compile | pass for persisted policy, helper status, fail-closed termination, one-panel recovery ownership, synchronized dismissal state, independent network/sharing actions, and busy-state guards; live mouse proof is not claimed |

## Safety boundaries

No cloud CI, telemetry, remote logging, or runtime network dependency is added. The app never edits TCC databases, user Espanso files, user documents, or Keychain contents. The app does not run live network isolation from an active remote execution path.

## Evidence boundaries

The SwiftPM proof validates the shared typed core and the debug app product. The Xcode proof validates an unsigned app bundle, its embedded helper executable, the LaunchDaemons plist, the feature contract resource, the helper target, and the repaired AppKit lifecycle at compile time. The cursor-safe preflight validates the isolated-display control boundary, but the menu-bar-only app exposed no content window for staging, so no screenshot or pointer interaction is claimed. These commands do not prove archive output, Developer ID signing, SMAppService installation, live privileged-helper authorization, TCC behavior, live network isolation, or mouse-only interaction. Those boundaries remain visible in the master checklist and are not represented as completed runtime claims.

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
3c9f99fe30de6970f9482100b36619ee0509f5d68dbc5f71b173003aba268d0c  KeyBrake/App/KeyBrakeViewModel.swift
73929dc709e554ec16f8c0ec3a658134f89fd4b6fcfba33208395eba1853933b  KeyBrake/App/KeyBrakeAppDelegate.swift
7126316787d02cb362ee6cce86db1a61d9ae383b38fa556b265ad0f10e21a21e  KeyBrake/App/KeyBrakeApp.swift
68528ea4350b8333703c9d12299aa1914559ab0d6ac4545100cd8c1a9df2ab61  KeyBrake/UI/KeyBrakeMenuView.swift
f7554f7fa9fedca568e2668e81f343a6b746204214fd8f7c96c4373b5ece041c  KeyBrake/UI/RecoveryPanelController.swift
593936f603fc2eb8297bbdf0a8643381927b7a3d2098d2dea6d2d89986632e84  KeyBrakeCore/KeyBrakeOperationalState.swift
865a0964e361b267563040205e45601b4219fbb9199db93402509614437a107c  KeyBrake/UI/SettingsView.swift
cd9803dc5388451387916248fe36f750f535e576f4a0b419827ce21eade91ba5  KeyBrake/UI/RecoveryView.swift
401945f4b863aa9a16d0f73f082a61e3627b32a88fee711156b090c2117999d1  KeyBrakeCore/ProcessController.swift
b541861b778ac324cb6a33d24c1a0cb64a481def24a985c2b24ad7f0b96c9152  KeyBrakeTests/EmergencyCoordinatorTests.swift
cfe335cd46f597a8cf9211d4ab888c94911659e38502ca0b86deb16df082b8e1  KeyBrakeCore/CommandRunner.swift
40a6cd6e831db57a11a292a573ce4f85918446791a8260856e5d1c10e52d389e  KeyBrakeCore/RecoveryStore.swift
252f84f4ceef6489c32415281b3a2c338d4e0c31b175e8e44506a17737f7a15e  KeyBrakeCore/PrivacyController.swift
```
