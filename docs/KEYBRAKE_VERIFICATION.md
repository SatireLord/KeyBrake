# KeyBrake verification record

## Historical baseline

- Repository: new; no source, project, Git history, build, or tests existed at the required canonical path.
- Baseline branch: `main` before the first commit; the repository was created at the canonical path because no prior checkout existed.
- Baseline dirty paths: all initial KeyBrake files were task-owned; generated `.build/`, `build/`, and `.codegraph/` paths are ignored.
- Baseline build/tests: not applicable before the native project was created.
- Agent-Cache: repository `keybrake` was not registered during baseline discovery; the current repository is registered and certified in the Agent-Cache product registry.
- Connected discovery: no `SatireLord/KeyBrake` repository was found during baseline discovery; the current private repository and pull request are recorded in the master plan.

## Current private portfolio release pass

- Canonical repository: KeyBrake git checkout on branch `codex/keybrake-complete-implementation`.
- Last source delivery checkpoint: `ecade547`; source, tests, packaging, and release-boundary files are pushed on the active PR branch. A later documentation-only receipt may advance HEAD without changing that source checkpoint.
- Portfolio release version: `0.1.0` (build `1`); the repository remains private until release approval.
- Release judgments: public source **HOLD**; downloadable binary **BLOCKED** (see `docs/KEYBRAKE_CAPABILITY_MATRIX.md`).
- Agent-Cache direct enforcement: **ready / continue**, `cache_ready=true`, `manual_review_required=false`, and `next_action=continue_with_live_repo_truth` for the exact KeyBrake path and prompt. The bootstrap CodeGraph interlock is **degraded** with `reason=structural_owner_unresolved` because the current CodeGraph query failed; this is a task-orientation hold, not a Cursor source-mutation denial.
- Cursor admission: the exact pre-tool request for `/Users/michaeltran/AntiGravity/KeyBrake/KeyBrakeCore/HelperClient.swift` returned `permission=allow` with `mode=degraded_structural` and an exact confirmed owner. Source mutation remains fail-closed outside the consumed file envelope.
- Installed Agent-Cache runtime: `/Users/michaeltran/.codex/plugins/runtime/agent-cache-kernel/slots/0.2.4+g0b181119`, deployment `0b181119`, runtime generation `2c2d19a11199c73ac617bb2861599e6baae864df1b0adab1eddd1547383a5140`; the direct Cursor hook uses the checkout `.venv/bin/python` and `scripts/backseat_check_host_hook.py`.
- XcodeGen resource routing: the app contract JSON, helper service plist, and helper executable are verified in the final unsigned Release bundle at `/tmp/KeyBrakeReleaseDerivedDataPrivacyGated/Build/Products/Release/KeyBrake.app`; signed installation and live SMAppService approval remain unverified.

## Proof ledger

The entries below are updated with exact commands and actual results as implementation advances. A local pass proves only the command that ran; it does not prove signing, notarization, helper approval, or live destructive behavior.

| Area | Command or evidence | Result |
| --- | --- | --- |
| Foundation | `/opt/homebrew/bin/xcodegen generate`; `xcodebuild -list`; `xcodebuild -showBuildSettings` | pass; native targets, schemes, bundle identifier, entitlements, helper plist, and feature-contract resource are present |
| Core type-check | direct `xcrun swiftc -typecheck -parse-as-library` over `KeyBrakeCore/*.swift` | pass |
| App/helper type-check | direct module emission followed by app and helper `swiftc -typecheck` | pass |
| Complete tests | `/Users/michaeltran/.codex/hooks/run_test_hud_detached.py -- /Users/michaeltran/bin/swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMPrivacyGated` | pass; 29 tests, 0 failures; HUD receipt `/tmp/codex-test-hud/1789044814-local-test.summary.txt`; log hash `52b10e22bedc8bac22f249af2150e4721df02646a28bd8168e758754c54dd1b0` |
| Version-gated privacy allowlist | `/Users/michaeltran/.codex/hooks/run_test_hud_detached.py -- /Users/michaeltran/bin/swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPMPrivacyGated --filter PrivacyControllerTests` | pass; 4 tests, 0 failures; minimum macOS version and catalog membership are enforced before `tccutil`; HUD receipt `/tmp/codex-test-hud/1789044783-local-test.summary.txt`; log hash `e0c8860639b084b502139bac7dd49038838b4552ad124b274ae6316f25c13807` |
| SwiftPM app build | `/Users/michaeltran/bin/swift build --scratch-path /tmp/KeyBrakeSwiftPM --product KeyBrake` | pass; executable product compiled and linked |
| Xcode Release build | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Release -derivedDataPath /tmp/KeyBrakeReleaseDerivedDataPrivacyGated CODE_SIGNING_ALLOWED=NO build` | pass; exit 0; HUD receipt `/tmp/codex-test-hud/1789044902-local-test.summary.txt`; log hash `cb853a90e2dd44bcdbb6ce58a5d267481135b14fbf8fbf5c14b7dfaee3af630f`; universal unsigned app/helper bundle produced |
| Xcode tests | `xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -configuration Debug -derivedDataPath /tmp/KeyBrakeXcodeTestPrivacyGated CODE_SIGNING_ALLOWED=NO test` | pass; exit 0; 29 tests, 0 failures; HUD receipt `/tmp/codex-test-hud/1789044881-local-test.summary.txt`; log hash `fb8a3f3d4af9baaef1c585bfcc91f53d8fefaf77381b9ca94801b9d10a8242e3` |
| App/helper bundle contents | `find`, `plutil`, `lipo`, and Mach-O inspection against `/tmp/KeyBrakeReleaseDerivedDataPrivacyGated/Build/Products/Release/KeyBrake.app` | pass; universal app and helper binaries, embedded `KeyBrakePrivilegedHelper`, `Contents/Library/LaunchDaemons/org.realitygood.KeyBrake.Helper.plist`, framework, feature contract, and bundle metadata are present |
| Runtime launch | staged SwiftPM executable in a temporary `.app`, added `CFBundleExecutable`, and launched with `open -n` | pass; process launched and exited without a crash; no persistent live app was left running |
| Runtime UI | required Computer Use preflight and Computer Use session | not claimed; preflight passed, but Computer Use service startup failed, so no menu click or accessibility proof is asserted |
| Open-source boundary | `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, capability matrix, tracked-path scan | pass for repository hygiene; MIT license and policy files exist, tracked public-source paths contain no private `/Users/michaeltran` paths, and no public/tagged release is claimed |
| Network | fixture inventory and restore tests; live isolation | fixture proof passed; live mutation intentionally not run |
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
de7ebf482070999d9de73c3c47dc03062d3a83d2429e5e24ec22ae89c1d08b01  KeyBrakeCore/HelperClient.swift
2b95fc10af1db7db28a324aac4538b046d5d7a5a8d1e1d46b764a7349dd71170  KeyBrakePrivilegedHelper/HelperService.swift
def72a0acbcd6d1ecc1e03435c605902dc14c0d510c31bc52a83cfc3480a091d  KeyBrakeCore/EmergencyCoordinator.swift
c595a7172f250472c81a7788cdb13cd8f13f2493a79ed476c8ef1e9b3f83b323  KeyBrakeCore/NetworkController.swift
a228776765d99a6d93ab1a94100e61e1bdadd31290b71d2f2791c50002f3f847  KeyBrakeCore/SharingServiceController.swift
87645a5cbb3400731c5408772c1259858f2991944ac22c3a08bc3d37ddc7cc8b  KeyBrake/App/KeyBrakeViewModel.swift
8470d7cdce009f832636aa04c25f3f739d698d94178ba78c0510f9d13c963fd5  KeyBrake/UI/SettingsView.swift
7b9c1a69e2d0e72690395b70cf97a6f24d6adef24f175930a462b96eb8ef29f5  KeyBrake/UI/RecoveryView.swift
d4f9497882d17ce8cfe40989490b6e04a2004462dcb0160b58567477473577b6  KeyBrakeCore/ProcessController.swift
cfe335cd46f597a8cf9211d4ab888c94911659e38502ca0b86deb16df082b8e1  KeyBrakeCore/CommandRunner.swift
40a6cd6e831db57a11a292a573ce4f85918446791a8260856e5d1c10e52d389e  KeyBrakeCore/RecoveryStore.swift
252f84f4ceef6489c32415281b3a2c338d4e0c31b175e8e44506a17737f7a15e  KeyBrakeCore/PrivacyController.swift
```
