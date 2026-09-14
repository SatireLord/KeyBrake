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
| Mouse-only UI proof | `host-unverified` | UI-002 has an isolated 760×652 Command Center Agent Display capture with readable recovery-required inventory and action hierarchy; the disposable AppKit trace observed a visible recovery panel, but the harness exposed no exact panel target and no pointer action was sent |
| Developer ID signing / notarization | `planned` | No signing identity is configured on this host |
| Open-source license file | `implemented` | MIT `LICENSE` at repository root on the implementation branch; GitHub `licenseInfo` stays empty until that file reaches default `main` |

UI-003 navigation refinement is source and SwiftPM Release proven, and the contained Agent Display receipt shows Incident Log and Settings as readable navigation cards with live counts. UI-004 is source and SwiftPM Release proven, and Agent Display accessibility inspection observed the new Settings overview and Incident Log empty state through deterministic destination launch arguments; the one retained SendMePics PNG covers Settings, while Incident Log was inspected without a second capture. The receipts prove rendered surfaces only; opening either window with a pointer remains unverified.

UI-005 is source and SwiftPM Release proven, and Agent Display inspection observed the new no-resolved-records guidance in Incident Log. The receipts prove rendered surfaces only; opening either window with a pointer remains unverified.

UI-006 is source and SwiftPM Release proven, and the recovery-demo route exposed the expected 760x652 Command Center window, but Agent Display could not route that window to agent-stage on either bounded attempt. No contained recovery-demo capture or pointer action is claimed.

UI-007 is source and SwiftPM Release proven, and the recovery panel now uses the shared checking state while isRecoveryStatusKnown is false. The recovery-demo route again exposed the expected 760x652 Command Center window, but Agent Display could not route it to agent-stage; no contained visual or pointer proof is claimed.

UI-008 is source and SwiftPM Release proven, and the menu-bar status help now uses the same checking explanation as its visible label until hydration completes. Agent Display isolated the disposable Command Center as window ID 79230, but the menu itself was not an exact harness target; no pointer or additional PNG proof is claimed.

## Checklist realignment

Items previously marked complete in `docs/KEYBRAKE_MASTER_PLAN.md` but contradicted by source at audit time are reclassified in that document using `[!]` (partial/host-dependent) or `[ ]` (not implemented).
