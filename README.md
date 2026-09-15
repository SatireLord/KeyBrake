# KeyBrake

KeyBrake is a macOS menu-bar failsafe. Source implements mouse-driven controls that stop approved local automation, isolate selected network and remote-access paths, record exact outcomes, and recover only state KeyBrake changed. The menu-bar entry also opens a larger Command Center that keeps status, emergency actions, recovery routing, recovery inventory, and recent activity in one visible surface, with labeled navigation cards into Incident Log and Settings.

It is a command-driven recovery prototype, not an antivirus product and not a promise that every form of remote access can be eliminated. Claims are bounded by operations KeyBrake can observe and verify.

Copyright 2026 Michael Tran. GitHub repository: [SatireLord/KeyBrake](https://github.com/SatireLord/KeyBrake). Bundle identifiers use `org.realitygood.KeyBrake` as the stable Mach/helper identity.

## Release status

| Surface | Status |
| --- | --- |
| Source tree | Prepared for a human identity and visibility decision |
| GitHub visibility | **HOLD** — this repository remains private |
| Downloadable binary | **BLOCKED** — unsigned local bundle only; signing, helper approval, and live verification remain external |

Version `0.1.0` (build `1`) is an experimental systems prototype. Local Xcode builds verify the app, embedded helper executable, LaunchDaemons plist, and feature contract with signing disabled. This project does not claim Developer ID signing, notarization, privileged-helper approval, or live-host network isolation without receipts.

UI-015 adds explicit `CFBundleExecutable` metadata to the native app plist. The unsigned Xcode Release bundle now records `KeyBrake` as its executable while preserving the stable bundle identity, helper resources, LaunchDaemons plist, feature contract, and version metadata.

Public claims must match [`docs/KEYBRAKE_CAPABILITY_MATRIX.md`](docs/KEYBRAKE_CAPABILITY_MATRIX.md). Evidence boundaries are in [`docs/KEYBRAKE_VERIFICATION.md`](docs/KEYBRAKE_VERIFICATION.md). The operator checklist for flipping GitHub visibility is [`docs/KEYBRAKE_PUBLIC_RELEASE.md`](docs/KEYBRAKE_PUBLIC_RELEASE.md).

## What it does

The menu keeps the physical mouse as a recovery path. The following behaviors exist in source; live host mutation is **host-unverified** until a receipt exists.

- **Stop Skynet Locally** disables and stops Espanso plus other explicitly approved local automation targets. It does not disable networking or reset privacy permissions.
- **Stop Remote Access** records a recovery snapshot before mutations, stops approved automation and remote-control targets, disables supported sharing controls according to the emergency profile, disconnects selected VPNs, isolates selected non-loopback network services, verifies the result, and opens a persistent recovery panel. Privacy resets are a separate explicit action via **Revoke App Access…**, not part of Stop Remote Access.
- **Revoke App Access…** opens Settings, where one selected application can be stopped and selected TCC-managed privacy decisions reset. KeyBrake never edits the TCC database file and never performs a global reset without a bundle identifier.
- **Restore Human Control** exposes independent mouse-driven actions for restoring network state, explicitly restoring sharing services, restarting Espanso, opening Privacy & Security settings, and reviewing the incident record.
- **Restart Espanso** is separate from network recovery and never changes Espanso configuration, packages, matches, service registration, or privacy permissions.
- **Open Incident Log** displays the local JSON-backed operation history with status-coded, timestamped records, expandable step outcomes, recovery summary, and a clear empty state when no records exist.
- **Open Command Center** opens the at-a-glance status and action surface without changing the underlying recovery semantics. It keeps full-width emergency actions prominent, surfaces recorded recovery inventory and unresolved recovery, and links to the Incident Log and Settings windows, which orient the user before their existing controls.
- **Clear resolved history** communicates its availability from recorded outcomes and remains unavailable when the Incident Log has no completed record to remove.

The app reports states such as `Normal Input`, `Local Automation Stopped`, `Network Isolated`, `Partial Isolation`, and `Recovery Required`. Successful restore returns to `Normal Input`. It does not claim `Computer Secured`, `Hacker Removed`, `Threat Neutralized`, `System Safe`, or `All Remote Access Eliminated`.

## Architecture

`KeyBrakeCore` owns the serialized emergency coordinator, typed command boundary, exact process identity rules, target registries, Espanso adapter, remote-access controls, network inventory, sharing adapters, privacy reset allowlist, atomic recovery state, and incident storage. The SwiftUI/AppKit application owns the menu bar, settings, recovery panel, and incident viewer. The helper target is an on-demand privileged command surface for administrator-required network, sharing, and verified launchd stops. It is not a generic shell. The helper can enable as well as disable network and sharing services during restore; that is intentional recovery behavior.

All runtime state is local under `~/Library/Application Support/KeyBrake`, with user-only permissions and atomic replacement. The app stores operation metadata, identifiers, bounded command errors, and timestamps. It does not store credentials, TCC database contents, Keychain contents, typed text, clipboard contents, documents, or packet data.

## Recovery boundaries

The recovery decision panel now repeats the current operational state with the same icon, tint, and explanation hierarchy used by the Command Center, so the user sees the decision context before choosing a restore action.

While launch hydration is incomplete, the recovery decision panel shows "Checking Recovery Status" and the shared checking explanation instead of presenting the initial in-memory state as confirmed.

KeyBrake restores only properties that KeyBrake changed, and it compares original, applied, and current values before every restore. A changed value is reported as a conflict instead of being overwritten. VPNs remain disconnected after network restoration, remote-control applications remain stopped, and macOS privacy grants are never silently restored. An unresolved `CurrentRecovery.json` survives crashes and relaunches and keeps the recovery panel available.

KeyBrake does not defeat kernel or firmware compromise. It cannot guarantee recovery when the mouse and KeyBrake process are both unavailable or attacker-controlled. It cannot silently restore reset TCC grants, and it cannot guarantee control over unsupported third-party or system-managed network paths. The AppKit recovery panel presents the recorded decision inventory beside the Command Center when recovery requires review, and closing that panel does not make an unresolved decision disappear.

## Build and test

The project uses XcodeGen only to generate the native Xcode project from `project.yml`. The app has no third-party runtime dependencies. SwiftPM covers `KeyBrakeCore` and a debug executable; the unsigned `.app` with embedded helper is an Xcode product.

```bash
xcodegen generate
swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPM
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO test
```

All verification remains local. No GitHub Actions, telemetry, remote logging, analytics, or network dependency is part of the runtime.

## License and security

MIT License. See [`LICENSE`](LICENSE), [`SECURITY.md`](SECURITY.md), [`CONTRIBUTING.md`](CONTRIBUTING.md), and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Demonstration

UI-005 adds state-aware resolved-history guidance, stable menu action symbols, and shared Settings status tinting without changing emergency or recovery semantics.

UI-006 gives the Recovery panel the same state-first visual hierarchy as the Command Center; the recovery actions and their safety boundaries remain unchanged.

UI-007 keeps that state-first hierarchy honest during asynchronous launch hydration by showing a checking state until the recovery-status check completes; it does not change any recovery action.

UI-008 keeps the menu-bar status label and its help text aligned during the same hydration window, so the compact failsafe surface does not describe an unconfirmed state as current.

UI-009 keeps the Command Center header, protection card, and destination recovery summaries in a checking state until recovery hydration completes, so every visible surface agrees about whether a decision is known.

UI-010 keeps the menu-bar extra icon in the same checking state until recovery hydration completes, so the compact shell does not show a normal or warning state before KeyBrake has confirmed it.

UI-011 keeps the compact menu header icon aligned with the adjacent status row, so the menu cannot show a confirmed normal shield while recovery status is still checking.

UI-012 explains why Restore Human Control is unavailable while KeyBrake is checking, completing another operation, or has no unresolved recovery snapshot, while the existing mouse-driven recovery gate remains unchanged.
UI-013 explains why state-changing Recovery-panel actions are temporarily unavailable while an operation is running, while review actions remain available and existing handlers stay unchanged.
UI-014 explains why Command Center emergency and recovery actions are temporarily unavailable during a busy operation, while review navigation remains available and existing handlers, targets, identifiers, and disabled-state gates stay unchanged.
UI-015 repairs the native Release bundle’s explicit executable metadata and records the Xcode Release, focused Xcode test, signing, and Agent Display evidence boundaries. The bundle metadata and Release build are proven locally, while Developer ID signing, helper approval, exact live containment, and pointer-driven recovery remain unclaimed.
UI-016 makes the Recent activity card scannable by reusing the shared operational-state icon and tint, exposing the final recorded state in text, and providing a combined accessibility summary without changing incident data or action behavior. Agent Display preflight passed and the unique disposable route launched, but bounded staging timed out and no contained visual or pointer proof is claimed.
UI-017 gives the empty Recent activity state one combined accessibility label and a stable empty-state identifier that matches its visible no-record message, without changing populated incident behavior or any action route. Agent Display preflight passed and the unique disposable route launched, but bounded staging timed out and no contained visual or pointer proof is claimed.
UI-018 gives the Current protection state card one combined accessibility surface and the stable identifier `keybrake.command-center.current-protection-state`; the decorative state symbol is hidden from the combined reading order while the visible state, detail, and badge remain unchanged. Agent Display preflight/provider checks passed and the unique disposable route launched, but the bounded stage request produced no response, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and no contained visual, accessibility, or pointer proof is claimed.
UI-019 gives the Incident Log and Settings navigation cards one combined accessibility surface each, so every destination name and live count are oriented together while the existing identifiers, hints, review-only semantics, and window routes remain unchanged. Agent Display preflight/provider checks passed and the unique disposable route launched, but bounded staging timed out with exit 124, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and no contained visual, accessibility, or pointer proof is claimed.
UI-020 gives the Command Center's `Emergency actions` and `Review and configure` headings one non-actionable accessibility surface each, combining each visible title and explanatory subtitle and publishing heading semantics without changing typography, spacing, actions, or recovery behavior. Agent Display preflight/provider checks passed and the unique disposable route launched, but bounded staging timed out with exit 124, inspection showed another application on `agent-stage`, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and no contained visual, runtime accessibility, or pointer proof is claimed.
UI-021 gives the `Stop Skynet Locally` and `Stop Remote Access` emergency buttons one combined accessibility surface each, so the visible action title and explanation are oriented together while the existing handlers, identifiers, hints, disabled-state gates, button styles, and recovery semantics remain unchanged. Agent Display preflight/provider checks passed and the unique disposable route launched, but bounded staging timed out with exit 124, inspection showed another application on `agent-stage`, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and no contained visual, runtime accessibility, or pointer proof is claimed.
UI-022 gives the busy-state emergency-action explanation the stable identifier `keybrake.command-center.emergency-actions.busy-guidance`, so the non-actionable guidance can be located deterministically while its visible copy, busy gate, review navigation, and operation semantics remain unchanged. Agent Display preflight/provider checks passed and the unique disposable route launched, but bounded staging timed out with exit 124, inspection showed another application on `agent-stage`, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and no contained visual, runtime accessibility, or pointer proof is claimed.
UI-023 gives the recovery decision card's visible `Recovery decision required` title and explanation one combined accessibility surface, hides only the decorative warning icon, and exposes the stable identifier `keybrake.command-center.recovery-decision-required` without changing the recovery snapshot inventory, busy guidance, button handler, existing identifier, hint, disabled-state gate, visible layout, or operation semantics. Agent Display preflight/provider checks passed and the unique disposable route launched as PID 35276, but bounded staging timed out with exit 124, inspection showed another application on `agent-stage`, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no contained visual, runtime accessibility, or pointer proof is claimed.
UI-024 gives the existing recovery-card busy-state explanation the stable identifier `keybrake.command-center.recovery-card.busy-guidance`, so that conditional guidance can be located deterministically while its visible copy, busy condition, typography, spacing, recovery button, review navigation, and operation semantics remain unchanged. Agent Display preflight/provider checks passed and the unique disposable route launched as PID 75042, but bounded staging timed out with exit 124, inspection showed the shared host surface rather than the exact recovery-card binding, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no contained visual, runtime accessibility, or pointer proof is claimed.
UI-025 gives the existing recovery inventory one stable accessibility inspection anchor, `keybrake.command-center.recovery-inventory`, while its live network, sharing, and unresolved-step counts, combined accessibility label, visible layout, and recovery semantics remain unchanged. Agent Display preflight/provider checks passed and the unique disposable route launched as PID 6553, but bounded staging timed out with exit 124, inspection showed the shared host surface rather than the exact recovery-inventory binding, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no contained visual, runtime accessibility, or pointer proof is claimed.
UI-026 gives the existing recovery-card GroupBox one stable container-level accessibility inspection anchor, `keybrake.command-center.recovery-card`, while all child surfaces, controls, recovery inventory, busy-state guidance, visible layout, and recovery semantics remain unchanged. Agent Display preflight/provider checks passed and the unique disposable route launched as PID 47252, but bounded staging timed out with exit 124, inspection showed the shared host surface rather than KeyBrake, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no contained visual, runtime accessibility, or pointer proof is claimed.
UI-027 gives the existing network, sharing, and unresolved recovery metric Labels stable inspection identifiers, `keybrake.command-center.recovery-metric.network`, `keybrake.command-center.recovery-metric.sharing`, and `keybrake.command-center.recovery-metric.unresolved`, while the parent combined recovery-inventory surface, live summaries, visible layout, and recovery semantics remain unchanged. Agent Display preflight/provider checks passed and the unique disposable route launched as PID 83774, but bounded staging timed out with exit 124, inspection showed no KeyBrake metric surface, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no contained visual, runtime accessibility, or pointer proof is claimed.
UI-028 changes only the recovery inventory's accessibility grouping from one combined parent surface to a containing parent with the existing network, sharing, and unresolved metric children separately inspectable, while preserving the parent identifier and label, live summaries, visible layout, and recovery semantics. Agent Display preflight/provider checks passed and the unique disposable route launched as PID 30195, but bounded staging was stopped with exit 130 after about 60 seconds, inspection showed no KeyBrake metric surface, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no contained visual, runtime accessibility, or pointer proof is claimed.
UI-029 repeated the exact Agent Display containment diagnosis against the current private head with a new unique disposable bundle, but bounded staging again remained silent for about 60 seconds, inspection showed no KeyBrake window or recovery-metric surface, and `is-isolated` returned `isolated=false` with `windowCount=0`; the exact process was terminated and no runtime or visual proof is claimed. This remains a host-routing limitation rather than a source-behavior failure.
UI-030 gives each existing network, sharing, and unresolved recovery metric an explicit spoken label equal to its live summary, while preserving the metric values, visible text, icon, identifiers, containing parent, layout, and recovery semantics. Agent Display preflight/provider checks passed and the unique disposable route launched as PID 98388, but bounded staging was stopped with exit 130 after about 60 seconds, inspection showed another application's Recovery surface, the follow-up isolation check returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no contained visual, runtime accessibility, or pointer proof is claimed.
UI-031 applies `.accessibilitySortPriority(-1)` to each existing recovery metric Label so the containing recovery-inventory orientation remains ahead of its child summaries during accessibility traversal, while preserving the live metric values, summaries, icons, identifiers, parent grouping, visible layout, and recovery semantics. Source checkpoint `108c23d2d169c7a99fcfd63f59be8af2f0f20afe` passed bounded parsing, the cursor-safe UI guard, the workspace single-flight guard, the SwiftPM Release build in 10.55 seconds, and 35 tests with zero failures. Agent Display preflight/provider checks passed and LaunchServices registered the unique `org.realitygood.KeyBrake.UI031` bundle as PID 72658, but identifier and PID staging attempts failed, bounded staging remained silent for about 60 seconds and was stopped with SIGINT, inspection exposed another application's Recovery surface while the host inventory briefly showed the KeyBrake Command Center, the exact PID route remained silent, `is-isolated` returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no contained visual, runtime accessibility, pointer, or additional PNG proof is claimed. Agent-Cache recorded the source and runtime evidence, but its exact snapshot endpoint failed the work-begin-order check and receipt projection remained skipped without a revision; no complete projection is claimed.

UI-032 restores ownership of the existing `keybrake.command-center.recovery-card` identifier by removing it from `emergencyActions` and attaching it to the actual recovery-card GroupBox, so accessibility inspection no longer labels the emergency-action surface as the recovery card. Source checkpoint `d8918cfc24d45030bebcbcc2d5f1ca03b16d1c5b` passed bounded parsing, the cursor-safe UI guard, the workspace single-flight guard, the SwiftPM Release build in 11.71 seconds, and 35 tests with zero failures; the recovery decision, inventory, busy guidance, button, visible layout, recovery semantics, and child identifiers remain unchanged. Agent Display preflight/provider checks passed and LaunchServices registered the unique `org.realitygood.KeyBrake.UI032` bundle as PID 93334, but staging remained silent for about 40 seconds and was stopped with SIGINT when the testing lane changed to the non-mutating network-sandbox request, `is-isolated` returned `isolated=false` with `windowCount=0` after cleanup, and the exact process was terminated; no contained visual, runtime accessibility, pointer, or additional PNG proof is claimed. Agent-Cache recorded the source evidence, but the exact snapshot endpoint returned `database is locked` and receipt projection remained skipped without a revision; no complete projection is claimed.

The Command Center groups Incident Log and Settings into a Review and configure section that shows the current incident and configured-target counts. UI-004 adds a current protection-state summary to Settings and a record/recovery summary plus empty state to Incident Log, while the emergency and recovery actions keep their existing semantics.

Use the runbook in [`docs/KEYBRAKE_SAFE_DEMO.md`](docs/KEYBRAKE_SAFE_DEMO.md). It demonstrates the menu, the Command Center, a harmless fake command runner, the recovery contract, the incident log, and read-only network inventory without severing the active development session. For deterministic destination staging, launch the temporary app with `--keybrake-settings` or `--keybrake-incident-log`; each argument opens only the named review window and performs no emergency operation. For deterministic recovery-required staging, launch the temporary app with `--keybrake-command-center --keybrake-recovery-demo`; that route writes its fixture snapshot and incident into a UUID-named temporary directory and uses fixture-backed controllers, so it does not touch real Application Support, network, sharing, TCC, or process state. Live network isolation should only be performed from a separately staged human-controlled Mac session with a known recovery path.

UI-033 adds a safe network-simulation route. Launch the temporary app with `--keybrake-network-sandbox` to exercise deterministic Wi-Fi, disabled USB Ethernet, Work VPN, loopback, isolation, restore, and recovery outcomes through local fixtures; use `--keybrake-network-sandbox-failure` to exercise deterministic Wi-Fi/VPN isolation failures. The Command Center displays a visible sandbox boundary, Settings controls are disabled, recovery state is confined to a UUID-named temporary directory, and the route uses a recording command runner, unavailable helper, and no-op process controller. Neither route invokes host Wi-Fi, VPN, sharing, process, privacy, launchd, or user-settings operations, and neither route claims OS-level network namespace or live VPN isolation.

UI-034 makes the selected fixture explicit in both review surfaces: the connected route shows `Connected fixture`, while the failure route shows `Isolation failure fixture`. Command Center and Settings expose those labels through `keybrake.command-center.network-sandbox-scenario` and `keybrake.settings.network-sandbox-scenario`, so a failure run cannot be mistaken for a connected simulation; route behavior and the host-operation boundary remain unchanged.

UI-035 combines each sandbox scenario title with its explanatory detail as one accessibility surface while keeping the host-operation warning separate. The existing scenario identifiers remain stable, and this change affects only inspection semantics in the two review surfaces.

UI-036 keeps the outer Command Center sandbox banner as a containing accessibility surface, so the scenario identity and host-operation boundary remain independently inspectable beneath the banner identifier. The visible sandbox layout and all fixture and production behavior remain unchanged.

UI-037 gives the existing host-operation warning its own stable accessibility identifier in both review surfaces: `keybrake.command-center.network-sandbox-host-boundary` and `keybrake.settings.network-sandbox-host-boundary`. The safety boundary is therefore directly addressable during inspection without changing visible copy, fixture behavior, disabled controls, or host-operation semantics.

UI-038 gives the Settings Network sandbox section its own stable container identifier, `keybrake.settings.network-sandbox-section`, while preserving the existing scenario and host-boundary identifiers beneath it. This makes the complete Settings safety surface directly addressable during inspection without changing visible layout, fixture behavior, disabled controls, or host-operation semantics.

UI-039 gives the existing sandbox status labels direct inspection anchors in both review surfaces: `keybrake.command-center.network-sandbox-status` for “Network sandbox active” and `keybrake.settings.network-sandbox-status` for “Host operations disabled”. This lets a test or accessibility review verify the safety state before reading scenario details or host-boundary limits, without changing visible copy or behavior.

UI-040 makes the Settings Network sandbox section a containing accessibility surface through `keybrake.settings.network-sandbox-section`, so its status, scenario, and host-boundary children remain independently inspectable beneath one safety context. This changes inspection structure only; visible layout, fixture behavior, disabled controls, and host-operation semantics remain unchanged.

UI-041 lists the connected or isolation-failure fixture's Wi-Fi, USB Ethernet, Work VPN, and loopback rows in the Command Center sandbox banner, including each simulated state and device when available. The inventory is derived from the same immutable local fixture used by the controller, so the review surface makes the test inputs explicit without adding host network access or changing the production route.

UI-042 mirrors that immutable fixture inventory in the Settings Network sandbox section before the disabled settings form. The stable anchors `keybrake.settings.network-sandbox-inventory` and `keybrake.settings.network-sandbox-service.<service-id>` expose the same simulated state and device details in both review surfaces, while the route remains presentation-only and makes no live network or host-operation claim.

UI-043 improves Incident Log review by showing each recorded operation's final state, update date/time, resolution, and step count at a glance. Expanding an entry shows each target, outcome, operation description, and recorded observed state when available, with UUID-derived inspection anchors; this remains a presentation-only view over local JSON history and does not change storage or recovery behavior.

UI-044 keeps the sandbox status, scenario, fixture inventory, and current protection information readable while the host-bound General, Local Automation, Remote Access, Application Access, Emergency Isolation, Privacy Reset Profile, and Recovery settings remain disabled. The change preserves the existing model guards and fixture-only route, so the sandbox explains what is simulated without making any host-operation claim.

UI-045 makes empty target configuration states explicit in Settings. Local Automation and Remote Access now explain when no target is configured and describe the existing Add Application or approval path, while configured target rows and all target mutation behavior remain unchanged.

UI-046 makes configured target identity reviewable in Settings. Local Automation and Remote Access rows show the existing bundle identifier and recorded executable path, keep the path copyable, and explicitly identify built-in targets whose executable path is not recorded; process matching and target mutation behavior remain unchanged.

UI-047 makes the menu's App Access destination explicit. The menu entry now says `Open App Access Settings…` because its existing action opens the Settings review surface; the settings route, busy gate, target controls, and access-mutation behavior remain unchanged.

UI-048 makes the Recovery panel's quit affordance match the existing busy-state safety guard. `Quit KeyBrake` is unavailable while a state-changing operation is running and explains why, while `Keep Isolation` remains available and recovery behavior is unchanged.

UI-049 makes busy menu actions explain their availability. Stop Skynet Locally, Stop Remote Access, Open App Access Settings…, and Restart Espanso now expose matching help and accessibility text, including the already-stopped local automation state; their handlers and busy gates remain unchanged.

UI-050 makes menu Quit KeyBrake explain its current availability. The existing action now exposes hydration, busy, recovery-required, and normal-state guidance while remaining enabled so `requestQuit()` can preserve its existing guards and mouse-operated recovery decision flow.

UI-051 gives every menu navigation destination explicit guidance. Open Command Center, Open Incident Log, and Settings… now explain the surface they open through help and accessibility hints, while their existing window routes and handlers remain unchanged.

UI-052 gives Recovery actions matching visible and spoken guidance. Keep Isolation and the shared recovery actions now expose help that follows their existing descriptions and busy-state accessibility hints, while recovery behavior remains unchanged.

UI-053 explains Application Access reset availability. The existing privacy-reset action now states whether the network sandbox, application selection, or privacy-service selection is preventing use, while its existing TCC boundary and disabled gate remain unchanged.

UI-054 makes General host-bound settings self-explanatory. Launch KeyBrake at Login and Register Privileged Helper now explain sandbox unavailability, current state, macOS approval or missing-bundle status, and the latest error through help and accessibility hints; their existing registration handlers and host-bound gates remain unchanged.

UI-055 makes Emergency Isolation policy effects self-explanatory. The five existing settings toggles now state which Wi-Fi, Ethernet, VPN, or sharing capability they control, show whether each policy is enabled, and explain that sandbox review leaves fixture state unchanged; the existing policy binding and next-operation behavior remain unchanged.

UI-056 makes target enrollment paths self-explanatory. The Local Automation and Remote Access Add Application controls now describe their destination, exact bundle-and-executable identity capture, and Remote Access approval requirement; sandbox review remains non-mutating and the existing picker validation is unchanged.

UI-057 makes custom-target removal self-explanatory. Each existing custom-target Remove action now states that the configured target identity, including its exact bundle identifier and executable path, will no longer be used; sandbox review remains non-mutating and built-in targets stay protected.

UI-058 makes Application Access inputs self-explanatory. The application picker and Privacy Reset Profile toggles now state the current selection, required inputs, reset scope, and sandbox boundary; the existing TCC-safe reset action remains unchanged.

UI-059 makes Privacy Reset Profile scannable. The existing profile now shows the selected service count, explicit zero-selection direction, and sandbox-only boundary while the existing TCC-safe reset behavior remains unchanged.

UI-060 makes Remote Access approval state scannable. Each existing approval toggle now explains whether the exact application is included, what the next toggle action does, and that sandbox review does not change host configuration; approval behavior remains unchanged.

UI-061 makes the Settings Recovery overview accessibility-parity complete. The existing hydration-aware recovery explanation is now available to accessibility inspection alongside its visible recovery value, while recovery state and actions remain unchanged.

UI-062 makes Remote Access configuration scannable. The existing section now shows approved versus configured target counts and preserves the exact-identity and sandbox boundaries while target behavior remains unchanged.

UI-063 makes the Settings Isolation profile scannable. The existing five-control count now explains zero, enabled, and sandbox-review states and identifies the next Stop Remote Access operation without changing policy behavior.

UI-064 makes the configured-target overview scannable. The existing count now distinguishes local-automation and remote-access scope and repeats exact bundle-and-executable matching and sandbox boundaries without changing target behavior.

UI-065 makes the Settings protection state scannable. The existing title and explanation now form one deterministic accessibility surface with a stable inspection anchor, while recovery-state behavior remains unchanged.

UI-066 makes the Emergency Isolation capability boundary scannable. The existing unsupported-sharing explanation now has a stable inspection anchor, while isolation policy, next-operation routing, and sandbox behavior remain unchanged.

UI-067 makes the Application Access TCC boundary scannable. The existing reset explanation now has a stable inspection anchor, while service selection, reset gating, and host privacy behavior remain unchanged.

UI-068 makes the Settings Recovery contract scannable. The existing recovery explanation now has a stable inspection anchor, while recovery routing, incident retention, and sandbox behavior remain unchanged.

UI-069 makes the Local Automation exact-identity boundary scannable. The existing bundle-and-executable matching explanation now has a stable inspection anchor, while target storage, process matching, and sandbox behavior remain unchanged.

UI-070 makes the Privileged Helper status scannable. The existing status text now has a stable inspection anchor, while helper registration, approval state, and sandbox behavior remain unchanged.

UI-071 makes the Privileged Helper error state scannable. The existing conditional error text now has a stable inspection anchor, while helper registration, error handling, approval state, and sandbox behavior remain unchanged.

UI-072 makes the Launch-at-Login error state scannable. The existing conditional error text now has a stable inspection anchor, while launch-at-login behavior, error handling, approval state, and sandbox behavior remain unchanged.

UI-073 makes the Settings error alert scannable. The existing alert message now has a stable inspection anchor, while alert routing, error handling, and sandbox behavior remain unchanged.

UI-074 makes the Application Access picker scannable. The existing target-selection control now has a stable inspection anchor, while target selection, reset gating, and sandbox behavior remain unchanged.

UI-075 makes the Revoke Selected Access action scannable. The existing TCC-safe reset action now has a stable inspection anchor, while its selection gate, reset path, and sandbox behavior remain unchanged.

UI-076 makes the Emergency Isolation section scannable. The existing policy section now has a stable inspection anchor, while its five policy bindings, unsupported-sharing boundary, and sandbox behavior remain unchanged.

UI-077 makes the Privacy Reset Profile section scannable. The existing privacy-service selection section now has a stable inspection anchor, while its summary, service bindings, TCC boundary, and sandbox behavior remain unchanged.

UI-078 makes the Recovery section scannable. The existing recovery contract section now has a stable inspection anchor, while recovery state, action routing, and sandbox behavior remain unchanged.

UI-079 makes the Remote Access section scannable. The existing approval section now has a stable inspection anchor, while its summary, empty state, target rows, enrollment action, and sandbox behavior remain unchanged.

UI-080 makes the Application Access section scannable. The existing privacy-access section now has a stable inspection anchor, while its target picker, TCC-safe boundary, revoke action, and sandbox behavior remain unchanged.

UI-081 makes the General section scannable. The existing host-settings section now has a stable inspection anchor, while launch-at-login, helper registration, error presentation, sandbox behavior, and host operations remain unchanged.

UI-082 makes the Local Automation section scannable. The existing local-automation section now has a stable inspection anchor, while its empty state, target rows, Add Application action, exact bundle-and-executable identity boundary, sandbox behavior, and host operations remain unchanged.

UI-083 makes the Current protection state section scannable. The existing hydration-aware protection overview now has a stable inspection anchor, while its status surface, configured-target summary, isolation-profile summary, recovery summary, and sandbox behavior remain unchanged.

UI-084 makes the Configured targets summary scannable. The existing protection overview row now has a stable inspection anchor, while its target count, identity semantics, help text, hydration behavior, and sandbox behavior remain unchanged.

UI-085 makes the Isolation profile summary scannable. The existing protection overview row now has a stable inspection anchor, while its enabled-control count, policy semantics, help text, hydration behavior, and sandbox behavior remain unchanged.

UI-086 makes the Recovery summary scannable. The existing protection overview row now has a stable inspection anchor, while its recovery summary, contract semantics, help text, hydration behavior, and sandbox behavior remain unchanged.

UI-087 makes the Launch-at-Login control scannable. The existing General-section toggle now has a stable inspection anchor, while its binding, host-settings semantics, helper boundaries, help text, hydration behavior, and sandbox behavior remain unchanged.

UI-088 makes the Privileged Helper summary scannable. The existing General-section summary now has a stable inspection anchor, while its status, registration action, error surfaces, helper semantics, host-settings boundaries, hydration behavior, and sandbox behavior remain unchanged.

UI-089 makes the Local Automation Add Application action scannable. The existing enrollment action now has a stable inspection anchor, while its handler, exact target identity semantics, enrollment guidance, hydration behavior, and sandbox behavior remain unchanged.

UI-090 makes the Remote Access Add Application action scannable. The existing approval-aware enrollment action now has a stable inspection anchor, while its handler, target identity semantics, approval guidance, hydration behavior, and sandbox behavior remain unchanged.

UI-091 makes the Disable Wi-Fi control scannable. The existing Emergency Isolation toggle now has a stable inspection anchor, while its policy binding, isolation guidance, hydration behavior, sandbox behavior, and host-operation behavior remain unchanged.

UI-092 makes the Disable physical Ethernet control scannable. The existing Emergency Isolation toggle now has a stable inspection anchor, while its policy binding, isolation guidance, hydration behavior, sandbox behavior, and host-operation behavior remain unchanged.

UI-093 makes the Disconnect VPNs control scannable. The existing Emergency Isolation toggle now has a stable inspection anchor, while its policy binding, isolation guidance, hydration behavior, sandbox behavior, and host-operation behavior remain unchanged.

UI-094 makes the Disable Remote Login control scannable. The existing Emergency Isolation toggle now has a stable inspection anchor, while its policy binding, isolation guidance, hydration behavior, sandbox behavior, and host-operation behavior remain unchanged.

UI-095 makes the Disable Remote Apple Events control scannable. The existing Emergency Isolation toggle now has a stable inspection anchor, while its policy binding, isolation guidance, hydration behavior, sandbox behavior, and host-operation behavior remain unchanged.

UI-096 makes each Privacy Reset Profile service control scannable. Each existing service toggle now has a stable identifier derived from its TCC service value, while descriptor order, display labels, selection binding, TCC reset boundaries, hydration behavior, sandbox behavior, and host-operation behavior remain unchanged.

UI-097 makes each configured target removal control scannable. Existing Local Automation and Remote Access removal buttons now have stable identifiers derived from each TargetDefinition.id, while labels, built-in-target filtering, target identity details, removal semantics, sandbox behavior, and host-operation behavior remain unchanged.

UI-098 makes each Remote Access target approval control scannable. Each existing approval toggle now has a stable identifier derived from its TargetDefinition.id, while labels, target identity details, approval binding semantics, removal semantics, sandbox behavior, and host-operation behavior remain unchanged.

UI-099 makes the menu Restore Human Control action scannable. The existing recovery action now has a stable identifier, while its label, recovery-state gate, mouse-driven recovery route, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-100 makes the menu Stop Remote Access action scannable. The existing emergency action now has a stable identifier, while its label, busy-state gate, handler, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-101 makes the menu Stop Skynet Locally action scannable. The existing emergency action now has a stable identifier, while its label, already-stopped and busy-state gates, handler, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-102 makes the menu Open App Access Settings action scannable. The existing Settings navigation action now has a stable identifier, while its label, Settings route, busy-state gate, handler, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-103 makes the menu Open Command Center action scannable. The existing status navigation action now has a stable identifier, while its label, command-center route, guidance, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-104 makes the menu Open Incident Log action scannable. The existing history navigation action now has a stable identifier, while its label, Incident Log route, guidance, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-105 makes the menu Settings action scannable. The existing Settings navigation action now has a stable identifier, while its label, Settings route, guidance, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-106 makes the menu Restart Espanso action scannable. The existing local-automation recovery action now has a stable identifier, while its label, busy-state gate, handler, guidance, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-107 makes the menu Quit KeyBrake action scannable. The existing recovery-aware quit action now has a stable identifier, while its label, recovery-aware guidance, handler, menu ordering, sandbox behavior, and host-operation behavior remain unchanged.

UI-108 makes the Settings Register Privileged Helper action scannable. The existing helper-registration action now has a stable identifier, while its label, guidance, handler, General section layout, sandbox behavior, and host-operation behavior remain unchanged.
