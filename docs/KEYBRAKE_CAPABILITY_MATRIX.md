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
| Menu-bar app shell | `implemented` | SwiftUI menu bar, Settings and Incident Log windows, and one AppKit-owned Recovery panel |
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
| Launch-time recovery panel | `host-unverified` | Source replays pending recovery visibility when the delegate attaches and keeps one AppKit panel across presentation, Keep Isolation, close, and reopen; live window proof is not available |
| Recovery-window lifecycle synchronization | `host-unverified` | AppKit title-bar close and SwiftUI Keep Isolation both update `isShowingRecoveryPanel`; source and Release compile are proven, while live interaction remains unverified |
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
| Mouse-only UI proof | `host-unverified` | Cursor-safe preflight and a healthy virtual-display provider were confirmed, but the sandboxed menu-bar build exposed no content window for staging, so no CUA action or screenshot proof was claimed |
| Developer ID signing / notarization | `planned` | No signing identity is configured on this host |
| Open-source license file | `implemented` | MIT `LICENSE` at repository root on the implementation branch; GitHub `licenseInfo` stays empty until that file reaches default `main` |

## Checklist realignment

Items previously marked complete in `docs/KEYBRAKE_MASTER_PLAN.md` but contradicted by source at audit time are reclassified in that document using `[!]` (partial/host-dependent) or `[ ]` (not implemented).
