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
- Release repair checkpoint: `a3968ad`.
- Current UI-001 source checkpoint: `fe24017763e52a88de90b966c2d4b5b0692945c1`; this checkpoint adds the Command Center surface and remains on the private PR branch.
- Version: `0.1.0` (build `1`).
- Release judgments: GitHub visibility **HOLD**; downloadable binary **BLOCKED** (see `docs/KEYBRAKE_CAPABILITY_MATRIX.md`).
- XcodeGen resource routing: the existing helper service plist, helper executable, and contract resource were verified in the prior unsigned Release bundle; UI-001 also registers `CommandCenterView.swift` in the project file. Current Xcode Release revalidation is held before source compilation by the host build-service stall below, so no newer unsigned bundle is claimed.

## Proof ledger

The entries below are updated with exact commands and actual results as implementation advances. A local pass proves only the command that ran; it does not prove signing, notarization, helper approval, or live destructive behavior.

| Area | Command or evidence | Result |
| --- | --- | --- |
| Foundation | `xcodegen generate`; `xcodebuild -list`; `xcodebuild -showBuildSettings` | pass; native targets, schemes, bundle identifier, entitlements, helper plist, and feature-contract resource are present |
| Core type-check | `xcrun swiftc -typecheck -parse-as-library` over `KeyBrakeCore/*.swift` | pass |
| App/helper type-check | module emission followed by app and helper `swiftc -typecheck` | pass |
| Complete tests | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMReleaseLifecycleFull` | pass; 35 tests, 0 failures |
| UI-001 complete tests | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMUI001` | pass; 35 tests, 0 failures after adding the Command Center contract entry |
| Termination and process-identity regression tests | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMReleaseLifecycle --filter EmergencyCoordinatorTests` | pass; 8 tests, 0 failures; startup hydration and all state-changing termination states fail closed, settled recovery requires an explicit decision, and bundle/executable/launch-date identity matching is exact |
| Version-gated privacy allowlist | `swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMPrivacyGated --filter PrivacyControllerTests` | pass; 4 tests, 0 failures; minimum macOS version and catalog membership are enforced before `tccutil` |
| SwiftPM app build | `swift build --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMKB031 --product KeyBrake` | pass at the release repair checkpoint; executable product compiled and linked; receipt label `keybrake-kb031-swiftpm-build` |
| UI-001 SwiftPM Debug app build | `swift build --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMBuildUI001` | pass; app executable compiled and linked, including `CommandCenterView.swift` |
| UI-001 SwiftPM Release app build | `swift build -c release --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMReleaseUI001` | pass; production-mode app executable compiled and linked, including `CommandCenterView.swift` and the launch-argument route |
| Xcode Debug build | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Debug -derivedDataPath /tmp/KeyBrakeKB031DerivedData CODE_SIGNING_ALLOWED=NO build` | pass at prior source checkpoint `a3968ad`; current UI-001 revalidation is covered by SwiftPM because the Xcode build service stalled before source compilation |
| Xcode Release build | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/KeyBrakeReleaseLifecycleDerivedData CODE_SIGNING_ALLOWED=NO build` | pass at prior source checkpoint `a3968ad`; current UI-001 revalidation is recorded as held below, so no current Xcode Release bundle is claimed |
| UI-001 Xcode Release revalidation | `env -u CC -u CXX xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Release -sdk macosx -derivedDataPath /tmp/KeyBrakeXcodeReleaseUI001 -disableAutomaticPackageResolution -jobs 1 ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build` | hold; Xcode reached `Prepare packages` and `ExecuteExternalTool ... clang -v -E -dM`, then remained in the build service without compiling a KeyBrake source file; the bounded attempt was interrupted with exit 130 and no KeyBrake diagnostic |
| Focused Xcode tests | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' -derivedDataPath /tmp/KeyBrakeXcodeLifecycleTests CODE_SIGNING_ALLOWED=NO -only-testing:KeyBrakeTests/EmergencyCoordinatorTests test` | pass at prior source checkpoint `a3968ad`; current UI-001 revalidation is recorded as held below |
| UI-001 focused Xcode test revalidation | `env -u CC -u CXX xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Debug -destination 'platform=macOS,id=00006041-001821160260801C' -derivedDataPath /tmp/KeyBrakeXcodeUI001 -disableAutomaticPackageResolution -parallel-testing-enabled NO -only-testing:KeyBrakeTests/FeatureContractTests CODE_SIGNING_ALLOWED=NO test` | hold; the concrete-device retry reached the same pre-compile Xcode build-service stall and was interrupted without a KeyBrake source diagnostic |
| App/helper bundle contents | `find`, `plutil`, `lipo`, and Mach-O inspection against `/tmp/KeyBrakeReleaseLifecycleDerivedData/Build/Products/Release/KeyBrake.app` | pass at prior source checkpoint `a3968ad`; universal app and helper binaries, embedded `KeyBrakePrivilegedHelper`, `Contents/Library/LaunchDaemons/org.realitygood.KeyBrake.Helper.plist`, feature contract, and bundle metadata are present |
| Runtime launch | staged SwiftPM executable in a temporary `.app`, added `CFBundleExecutable`, and launched with `open -n` | pass; process launched and exited without a crash; no persistent live app was left running |
| Cursor-safe UI preflight | `python3 /Users/michaeltran/.agents/cursor-steal-prevention/scripts/agent_ui_preflight.py --app org.realitygood.KeyBrake --display virtual-16x9 --start-sentinel --json` | pass; virtual display was present, the sentinel was active, and app-targeted Computer Use was standing-authorized; this receipt is not a screenshot or interaction proof |
| Agent Display provider | `/Users/michaeltran/bin/displayctl doctor`; `/Users/michaeltran/bin/displayctl capabilities` | pass; the owned virtual-display provider, socket, accessibility trust, `agent-stage`, and `virtual-16x9` were available; provider health does not prove that KeyBrake exposed a stageable content window |
| UI-001 Command Center staging | temporary SwiftPM Release `.app` with `--keybrake-command-center`; `/Users/michaeltran/bin/displayctl stage --app KeyBrake --position above --preset 16:9`; `/Users/michaeltran/bin/displayctl inspect-ui --display agent-stage`; `/Users/michaeltran/bin/displayctl is-isolated --app KeyBrake`; `/Users/michaeltran/bin/displayctl capture --display agent-stage --out /Users/michaeltran/AntiGravity/KeyBrake/.agent-cache/proofs/keybrake-ui-001-command-center.png` | pass; one isolated 760×648 `KeyBrake Command Center` window was staged, accessibility inspection identified the intended status/action/navigation labels, and one readable 1920×1080 PNG receipt was captured; no pointer action was sent |
| Historical recovery-panel staging attempt | `open -n /tmp/KeyBrakeReleaseLifecycleDerivedData/Build/Products/Release/KeyBrake.app`; `/Users/michaeltran/bin/displayctl stage --app KeyBrake --position above --preset 16:9`; `/Users/michaeltran/bin/displayctl is-isolated --app KeyBrake` | not proved for the Recovery panel; the prior task-owned Release app exposed no content window to the isolated display, so staging returned exit 4 and no pointer action was sent |
| Open-source boundary | `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, capability matrix, tracked-path scan | MIT license and policy files exist on the implementation branch; GitHub remains private; no public/tagged binary release is claimed |
| Network | fixture inventory and restore tests; live isolation | fixture proof passed; live mutation intentionally not run |
| Verified launchd stop | `EmergencyCoordinator` fixture with an approved launch-agent label; helper target compiled in the Xcode app build | pass for typed coordinator-to-helper routing and helper identity-check implementation; live signed helper authorization, launchd mutation, and respawn proof remain host-unverified |
| Signing | `codesign`/`spctl` | not claimed; the Release bundle is unsigned because local proof uses `CODE_SIGNING_ALLOWED=NO` and no Developer ID signing identity is configured |
| Versioning | `SupportingFiles/Info.plist` | pass; `CFBundleShortVersionString` is `0.1.0` and `CFBundleVersion` is `1` |
| Target settings and recovery UI | focused source review, UI-001 SwiftPM Debug/Release builds, 35-test SwiftPM suite, Agent Display accessibility inspection, and one PNG receipt | pass for persisted policy, helper status, fail-closed termination, one-panel recovery ownership, synchronized dismissal state, independent network/sharing actions, busy-state guards, and the new Command Center hierarchy; current Xcode Release revalidation and live pointer proof are not claimed |

## Safety boundaries

No cloud CI, telemetry, remote logging, or runtime network dependency is added. The app never edits TCC databases, user Espanso files, user documents, or Keychain contents. The app does not run live network isolation from an active remote execution path.

## Evidence boundaries

The SwiftPM proof validates the shared typed core and the UI-001 debug and Release app products, including the Command Center source. The prior Xcode proof validates an unsigned app bundle, its embedded helper executable, the LaunchDaemons plist, the feature contract resource, the helper target, and the repaired AppKit lifecycle at the earlier release checkpoint; current UI-001 Xcode revalidation stalled in the host build service before source compilation. The cursor-safe preflight and Agent Display proof validate a contained, stageable Command Center window and readable visual hierarchy, but they do not prove pointer interaction or the Recovery panel’s mouse-only route. These commands do not prove archive output, Developer ID signing, SMAppService installation, live privileged-helper authorization, TCC behavior, live network isolation, or mouse-only interaction. Those boundaries remain visible in the master checklist and are not represented as completed runtime claims.

## Regression checksum anchors

These SHA-256 values anchor the safety contract and the highest-risk command seams for this deliverable. They are recorded after the final source/doc edits; a later change must recompute and review the affected value.

```text
0a7f4cbffd7c6d7f127d6423c3f3759dc80c83c0798ff4723631bbd8b4d58aa2  Resources/KeyBrakeFeatureContract.json
50d16a40121c6a87ccff29ec5c9a16aaf29029a023a23dce29f31d39c2c2c09f  docs/KEYBRAKE_RECOVERY_CONTRACT.md
98ea157c6a637ea0f085bd93bb673bcb59a1c04e3774c7c605a864b84abb705f  KeyBrakeCore/HelperClient.swift
ca01abde03d3e8c5d560a52cedd8a75aa52ceb73bec02132a2fa98b042a6fc95  KeyBrakePrivilegedHelper/HelperService.swift
4f874840014b8ffd4eecc46123c55d107356b4e7bac00d5e6c2c027bf454c900  KeyBrakeCore/EmergencyCoordinator.swift
c595a7172f250472c81a7788cdb13cd8f13f2493a79ed476c8ef1e9b3f83b323  KeyBrakeCore/NetworkController.swift
a228776765d99a6d93ab1a94100e61e1bdadd31290b71d2f2791c50002f3f847  KeyBrakeCore/SharingServiceController.swift
f610d79aa5b7b39efd1934d3f3357bf806b90a796f288f67e9ecdc4a633d6bdd  KeyBrake/App/KeyBrakeViewModel.swift
73929dc709e554ec16f8c0ec3a658134f89fd4b6fcfba33208395eba1853933b  KeyBrake/App/KeyBrakeAppDelegate.swift
ddb2dd188310f68e7781ebd4d78eb969ff92fbaf66b98b7be5c7a2bdce9d65a9  KeyBrake/App/KeyBrakeApp.swift
4e702ffedd39fd656205e75ce01e64310d801f439da776c72495432d0d513660  KeyBrake/UI/KeyBrakeMenuView.swift
7a9ba0f2056e6eedcf8af8df800c80c1c6d3dfa6c310be48edf0110f892d454e  KeyBrake/UI/CommandCenterView.swift
f7554f7fa9fedca568e2668e81f343a6b746204214fd8f7c96c4373b5ece041c  KeyBrake/UI/RecoveryPanelController.swift
593936f603fc2eb8297bbdf0a8643381927b7a3d2098d2dea6d2d89986632e84  KeyBrakeCore/KeyBrakeOperationalState.swift
865a0964e361b267563040205e45601b4219fbb9199db93402509614437a107c  KeyBrake/UI/SettingsView.swift
cd9803dc5388451387916248fe36f750f535e576f4a0b419827ce21eade91ba5  KeyBrake/UI/RecoveryView.swift
8b7279ff324774a5f01f70e80bbf49277fa2291ac7ed75de124c9db179d2c0da  KeyBrakeCore/FeatureContract.swift
3c3e614e2bee1e0638248ba51f58bf4d2950529f8137c35a41c1b4cf6b7866e1  KeyBrakeTests/FeatureContractTests.swift
401945f4b863aa9a16d0f73f082a61e3627b32a88fee711156b090c2117999d1  KeyBrakeCore/ProcessController.swift
b541861b778ac324cb6a33d24c1a0cb64a481def24a985c2b24ad7f0b96c9152  KeyBrakeTests/EmergencyCoordinatorTests.swift
cfe335cd46f597a8cf9211d4ab888c94911659e38502ca0b86deb16df082b8e1  KeyBrakeCore/CommandRunner.swift
40a6cd6e831db57a11a292a573ce4f85918446791a8260856e5d1c10e52d389e  KeyBrakeCore/RecoveryStore.swift
252f84f4ceef6489c32415281b3a2c338d4e0c31b175e8e44506a17737f7a15e  KeyBrakeCore/PrivacyController.swift
```
