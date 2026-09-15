# KeyBrake capability matrix

This document classifies every user-visible or safety-critical capability by implementation status. Public claims must match these classifications.

| Status | Meaning |
| --- | --- |
| `implemented` | Source implements the behavior and focused tests or host receipts cover it |
| `fixture-only` | Behavior is proven only through test doubles, not live host mutation |
| `source-present but unwired` | Types or targets exist but production paths do not call them |
| `host-unverified` | Code path exists but requires signing, helper approval, or staged host proof |
| `planned` | Documented intent without production implementation |

## Release judgments

| Release surface | Status | Reason |
| --- | --- | --- |
| Source tree | Prepared | License, security contact, community files, and redacted verification are in the implementation branch |
| GitHub visibility | **HOLD** | Repository remains private until the owner identity and release decision |
| Downloadable binary | **BLOCKED** | Local unsigned bundle is proven; signing, helper approval, and live verification remain external gates |

## Capability inventory

| Capability | Status | Notes |
| --- | --- | --- |
| Hydration-aware menu status | implemented | Menu-bar status help uses the shared checking explanation until recovery-status hydration completes, matching the visible status label |
| Hydration-safe destination summaries | implemented | Command Center icons and recovery card, Settings recovery summary, and Incident Log recovery summary remain in checking state until recovery-status hydration completes |
| Hydration-safe menu-bar shell icon | implemented | The menu-bar extra label uses the shared checking symbol until recovery-status hydration completes, then follows the confirmed operational state |
| Hydration-safe compact menu header | implemented | The compact menu heading reuses the hydration-aware status symbol, so its title and status row agree while recovery status is checking |
| State-aware recovery action explanation | implemented | Restore Human Control explains checking, busy, recovery-available, and no-snapshot states without changing its existing disabled-state gate or action target |
| Recovery action availability guidance | implemented | Recovery panel explains the busy disabled state for state-changing actions while leaving Privacy & Security, Incident Log, Keep Isolation, and Quit routes unchanged |
| Recovery hydration status | implemented | Recovery panel uses the shared checking state until launch recovery hydration completes, then presents the current operational state before its existing actions |
| Recovery state orientation | implemented | The Recovery panel repeats the shared operational-state icon, tint, detail, and pending-decision explanation before its existing restore, keep-isolation, and quit actions |
| State-aware history and menu affordances | implemented | Incident Log explains whether resolved records are available and disables its clear-history action when none exist; the menu uses stable symbols for its existing actions, and Settings reuses the shared state tint |
| Menu-bar app shell | `implemented` | SwiftUI menu bar, readable Settings and Incident Log windows, and one AppKit-owned Recovery panel |
| Command Center window | `implemented` | Stageable SwiftUI status surface with state explanation, full-width emergency actions, recorded recovery inventory, recovery routing, recent activity, and secondary navigation; UI-002 also corrects singular inventory labels and persists the latest stored incident for relaunch visibility |
| Destination window orientation | `implemented` | Settings begins with current protection state, configured-target count, isolation-profile count, and recovery status; Incident Log begins with record/recovery counts and a useful empty state |
| Recovery-required staging route | `fixture-only` | `--keybrake-recovery-demo` creates a UUID-named temporary snapshot and incident, uses fixture-backed controllers, and avoids real Application Support, network, sharing, TCC, and process mutation |
| Serialized emergency coordinator | `implemented` | Actor boundary with fixture-backed tests |
| Typed absolute-path commands | `implemented` | No shell interpolation |
| Process identity before termination | `implemented` | Exact bundle ID, executable URL, and stored launch-date re-check with focused identity-matrix coverage |
| Protected process rejection | `implemented` | Self and core system targets blocked |
| Espanso disable/stop/restart | `host-unverified` | Command boundary implemented; live Espanso proof deferred |
| Built-in remote target registry | `implemented` | Exact bundle identifiers, user approval required |
| Custom target enrollment | `implemented` | Settings enrollment with registry validation |
| Custom local automation stop | `implemented` | Coordinator uses configured local targets |
| Recovery snapshot persistence | `implemented` | Atomic write with backup-rename semantics |
| Original/applied/current restore | `implemented` | Network and sharing adapters compare current vs applied |
| Partial restore retention | `implemented` | Snapshot retained until all subsystems resolve |
| Launch-time recovery panel | `host-unverified` | Source replays pending recovery visibility when the delegate attaches, lazily provisions the AppKit controller when needed, anchors the panel beside the Command Center, and keeps one panel across presentation, Keep Isolation, close, and reopen; the disposable recovery demo observed the panel visible, while the display harness exposed only the Command Center frame |
| Recovery-window lifecycle synchronization | `host-unverified` | AppKit title-bar close and SwiftUI Keep Isolation both update `isShowingRecoveryPanel`; source, Release compile, and disposable panel presentation are proven, while live pointer interaction remains unverified |
| Privileged helper XPC listener | `host-unverified` | Listener bootstrap, typed routing, caller identity checks, verified launchd identity checks, helper embedding, and plist placement are source/build proven; signed installation and live authorization remain unverified |
| Verified non-Apple launchd stop | `fixture-only` | Approved labels route through the helper; `launchctl print` path, optional `codesign` designated requirement, and post-stop state are checked; live signed-host mutation remains unverified |
| SMAppService daemon registration | `host-unverified` | Settings exposes registration and status through `SMAppService`; signed-host installation and approval remain unverified |
| Live network isolation | `host-unverified` | Network/sharing mutations route through helper boundary; live mutation deferred |
| Live sharing disable/restore | `host-unverified` | Setter commands corrected; privilege proof external |
| Per-bundle privacy reset | `host-unverified` | `tccutil` boundary implemented; live TCC proof deferred |
| Emergency profile settings | `implemented` | Persisted and consumed by coordinator |
| Helper status in Settings | `implemented` | Derived from `SMAppService` daemon status |
| Independent sharing restore | `implemented` | Network-only restore does not clear unresolved sharing |
| Feature contract resource | `implemented` | Bundled JSON with regression test |
| Command Center action availability guidance | `implemented` | Command Center explains busy-state unavailability for emergency and recovery actions while Incident Log and Settings navigation remains available; existing handlers, targets, identifiers, and disabled-state gates remain unchanged |
| Release bundle executable metadata | `implemented` | `SupportingFiles/Info.plist` binds `CFBundleExecutable` to `$(EXECUTABLE_NAME)`; the UI-015 native Xcode Release bundle contains the `KeyBrake` executable and version/build metadata while preserving the helper and feature-contract resources |
| Recent activity outcome orientation | `implemented` | UI-016 uses the existing `KeyBrakeStatusPresentation` symbol and tint, adds the recorded final-state label, and exposes a combined accessibility summary without changing incident storage or action routing |
| Empty Recent activity accessibility orientation | `implemented` | UI-017 exposes the visible no-recorded-incident message as one combined accessibility surface with the stable identifier `keybrake.command-center.recent-activity.empty`, without changing populated incident behavior or action routing |
| Current protection state accessibility orientation | `implemented` | UI-018 combines the visible protection-state title, detail, and status badge into one accessibility surface, hides the decorative state symbol from that reading order, and exposes the stable identifier `keybrake.command-center.current-protection-state` without changing state computation or action routing |
| Mouse-only UI proof | `host-unverified` | UI-002 has an isolated 760×652 Command Center Agent Display capture with readable recovery-required inventory and action hierarchy; the disposable AppKit trace observed a visible recovery panel, but the harness exposed no exact panel target and no pointer action was sent |
| Developer ID signing / notarization | `planned` | Apple Development and Apple Distribution identities are present, but no Developer ID Application identity was verified; Release builds keep `CODE_SIGNING_ALLOWED=NO`, and no signed or notarized artifact is claimed |
| Open-source license file | `implemented` | MIT `LICENSE` at repository root on the implementation branch; GitHub `licenseInfo` stays empty until that file reaches default `main` |

UI-003 navigation refinement is source and SwiftPM Release proven, and the contained Agent Display receipt shows Incident Log and Settings as readable navigation cards with live counts. UI-004 is source and SwiftPM Release proven, and Agent Display accessibility inspection observed the new Settings overview and Incident Log empty state through deterministic destination launch arguments; the one retained SendMePics PNG covers Settings, while Incident Log was inspected without a second capture. The receipts prove rendered surfaces only; opening either window with a pointer remains unverified.

UI-005 is source and SwiftPM Release proven, and Agent Display inspection observed the new no-resolved-records guidance in Incident Log. The receipts prove rendered surfaces only; opening either window with a pointer remains unverified.

UI-006 is source and SwiftPM Release proven, and the recovery-demo route exposed the expected 760x652 Command Center window, but Agent Display could not route that window to agent-stage on either bounded attempt. No contained recovery-demo capture or pointer action is claimed.

UI-007 is source and SwiftPM Release proven, and the recovery panel now uses the shared checking state while isRecoveryStatusKnown is false. The recovery-demo route again exposed the expected 760x652 Command Center window, but Agent Display could not route it to agent-stage; no contained visual or pointer proof is claimed.

UI-008 is source and SwiftPM Release proven, and the menu-bar status help now uses the same checking explanation as its visible label until hydration completes. Agent Display isolated the disposable Command Center as window ID 79230, but the menu itself was not an exact harness target; no pointer or additional PNG proof is claimed.

UI-009 is source and SwiftPM Release proven, and the Command Center header, protection card, recovery-card visibility, Settings recovery summary, and Incident Log recovery summary now respect the same hydration boundary. Agent Display preflight passed, but the disposable Command Center did not leave a running window for exact containment on this attempt; no pointer or additional PNG proof is claimed.

UI-010 is source and SwiftPM Release proven, and the menu-bar extra label now uses the same hydration-aware status symbol as the compact status row. Agent Display preflight passed, but the disposable shell route did not leave a running KeyBrake window for exact containment; no pointer or additional PNG proof is claimed.

UI-011 is source and SwiftPM Release proven, and the compact menu header now reuses the hydration-aware status symbol already used by its status row. Agent Display preflight passed, but the disposable app exposed no movable content window for exact containment; no pointer or additional PNG proof is claimed.

UI-012 is source and SwiftPM Release proven, and Restore Human Control now exposes state-specific help and accessibility text while preserving its existing recovery gate and target. Agent Display preflight passed, but the unchanged compact-menu host route exposed no movable content window; no pointer or additional PNG proof is claimed.

UI-013 is source and SwiftPM Release proven, and the Recovery panel now explains why state-changing actions are unavailable during a busy operation while review actions remain available. Agent Display preflight passed and the disposable route moved six KeyBrake windows through the virtual-display route, but the follow-up isolation check returned `isolated=false` with `windowCount=0`; the disposable process was terminated, and no pointer or additional PNG proof is claimed.

UI-014 is source and SwiftPM Release proven, and the Command Center now explains why emergency and recovery actions are unavailable during a busy operation while Incident Log and Settings navigation remains available. Agent Display preflight passed; the original disposable identifier did not register, and an alternate disposable identifier staged four windows through accessibility, but the follow-up isolation check returned `isolated=false` with `windowCount=0`; the process was terminated, and no pointer or additional PNG proof is claimed.

UI-015 is source and native Xcode Release proven for the bundle metadata seam. `SupportingFiles/Info.plist` now declares `CFBundleExecutable=$(EXECUTABLE_NAME)`, `plutil` lint passes, the rebuilt unsigned Release bundle reports `KeyBrake` as its executable, and the app/helper/resource/version inventory remains present. The focused Debug Xcode `EmergencyCoordinatorTests` target passed 8 tests with 0 failures; the Release-focused test invocation remains held by an Xcode `@testable` module/testability and architecture mismatch before test execution. Agent Display preflight and provider checks passed, and a unique disposable bundle identifier launched the rebuilt app, but bounded staging timed out and `is-isolated` returned `isolated=false` with `windowCount=0`; no contained visual, pointer, signed-host, helper-approval, TCC, network, launchd, or notarization proof is claimed.

UI-016 is source and SwiftPM Release proven, and the full 35-test suite remains green. Recent activity now shows the latest recorded operational state with the same visual language as the status card, and its accessibility summary includes the action, state, resolution, and step count. Agent Display preflight/provider checks passed and the unique UI-016 bundle launched, but bounded stage timed out with exit 124 and `is-isolated` returned `isolated=false` with `windowCount=0`; no pointer or additional PNG proof is claimed.

UI-017 is source and SwiftPM Release proven, and the full 35-test suite remains green. The empty Recent activity state now combines its visible no-recorded-incident message into one accessibility surface and exposes a stable empty-state identifier, while the populated incident branch and all action routing remain unchanged. Agent Display preflight/provider checks passed and the unique UI-017 bundle launched, but bounded stage timed out with exit 124 and `is-isolated` returned `isolated=false` with `windowCount=0`; no pointer or additional PNG proof is claimed.

UI-018 is source and SwiftPM Release proven, and the full 35-test suite remains green. The Current protection state card now combines its existing visible state title, detail, and status badge into one accessibility surface, hides only the decorative state symbol, and exposes `keybrake.command-center.current-protection-state`; state computation, badge semantics, handlers, and action routing remain unchanged. Agent Display preflight/provider checks passed and the unique UI-018 bundle launched, but the bounded stage request produced no response, `is-isolated` returned `isolated=false` with `windowCount=0`, and no pointer or additional PNG proof is claimed.

## Checklist realignment

Items previously marked complete in `docs/KEYBRAKE_MASTER_PLAN.md` but contradicted by source at audit time are reclassified in that document using `[!]` (partial/host-dependent) or `[ ]` (not implemented).
