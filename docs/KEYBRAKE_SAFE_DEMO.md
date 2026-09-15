# Safe demonstration

UI-006 makes the recovery panel state-first by repeating the shared status hierarchy before its existing actions. UI-007 keeps that hierarchy truthful during asynchronous launch hydration by showing the shared checking state until recovery status is known. UI-008 applies the same checking explanation to the compact menu-bar status help. UI-009 applies that hydration boundary to the Command Center status icons and recovery card plus the Settings and Incident Log recovery summaries. UI-010 applies the same status symbol boundary to the menu-bar extra label. UI-011 applies that same symbol to the compact menu header. UI-012 explains why Restore Human Control is unavailable while the menu is checking, busy, or has no unresolved recovery snapshot. UI-013 explains why state-changing Recovery-panel actions are temporarily unavailable while an operation is running, while review actions remain available. UI-014 explains why Command Center emergency and recovery actions are temporarily unavailable during a busy operation while Incident Log and Settings navigation remains available. UI-015 repairs the native app plist so the Xcode Release bundle declares its executable explicitly; a successful unsigned bundle build does not prove signing, helper approval, exact display containment, or pointer interaction. UI-016 makes the latest recorded outcome scannable with the shared state icon, tint, state title, and accessibility summary; this is presentation-only. UI-017 makes the empty Recent activity state a single combined accessibility surface with a stable identifier; this is also presentation-only. UI-018 makes the Current protection state card one combined accessibility surface with a stable identifier while hiding only its decorative symbol; this is presentation-only. UI-019 makes the Incident Log and Settings navigation cards one combined destination/count surface each; this is presentation-only. UI-020 makes the `Emergency actions` and `Review and configure` section headings one combined non-actionable accessibility surface each with heading semantics; this is presentation-only. UI-021 makes the `Stop Skynet Locally` and `Stop Remote Access` emergency buttons one combined actionable accessibility surface each; this is presentation-only. UI-022 gives the existing busy-state emergency-action explanation the stable identifier `keybrake.command-center.emergency-actions.busy-guidance`; this is presentation-only. UI-023 gives the recovery decision card's visible title and explanation one combined accessibility surface, hides only the decorative warning icon, and exposes `keybrake.command-center.recovery-decision-required`; this is presentation-only. UI-024 gives the existing recovery-card busy-state explanation the stable identifier `keybrake.command-center.recovery-card.busy-guidance`; this is presentation-only. UI-025 gives the existing combined recovery inventory the stable identifier `keybrake.command-center.recovery-inventory`; this is presentation-only. UI-026 gives the existing recovery-card GroupBox the stable container identifier `keybrake.command-center.recovery-card`; this is presentation-only. UI-027 gives the existing network, sharing, and unresolved recovery metric Labels stable inspection identifiers; this is presentation-only. UI-028 changes that recovery inventory from one combined parent accessibility surface to a containing parent with separately inspectable metric children; this is presentation-only. UI-029 repeats the exact Agent Display containment diagnosis against the current private head without changing source behavior; this is host-routing evidence only. UI-030 gives each existing recovery metric an explicit accessibility label equal to its live summary; this is presentation-only. A recovery-demo, Command Center, or shell staging failure must remain labeled as host routing evidence only; it does not change the source or recovery contract.
UI-031 applies only an accessibility traversal priority to the existing recovery metric Labels, so the containing recovery-inventory orientation remains ahead of its child summaries without changing the safe-demo route, fixture state, visible copy, recovery actions, or host mutation boundary. The unique LaunchServices-launched bundle was inspected through Agent Display, but identifier and PID staging did not establish containment, OCR exposed another application's Recovery surface, isolation returned `isolated=false` with `windowCount=0`, and the exact process was terminated; no pointer or additional PNG proof is claimed.

UI-032 changes only accessibility-identifier ownership: `keybrake.command-center.recovery-card` is attached to the recovery-card GroupBox and is no longer attached to `emergencyActions`, while the safe-demo route, fixture state, visible copy, recovery actions, child surfaces, and host mutation boundary remain unchanged. The unique LaunchServices-launched bundle was staged through Agent Display as PID 93334, but staging remained silent for about 40 seconds and was stopped with SIGINT when the testing lane changed to the non-mutating network-sandbox request, `is-isolated` returned `isolated=false` with `windowCount=0` after cleanup, and the exact process was terminated; no contained visual, runtime accessibility, pointer, or additional PNG proof is claimed.

UI-033 adds explicit `--keybrake-network-sandbox` and optional `--keybrake-network-sandbox-failure` routes. The route opens the Command Center with a visible Network sandbox active boundary, uses deterministic fixture-backed Wi-Fi, USB Ethernet, Work VPN, and loopback observations, and keeps Settings controls disabled. Stop Remote Access, restore, and failure outcomes exercise only the fixture controller; UUID temporary stores, `RecordingCommandRunner`, and a no-op process controller prevent host network, process, privacy, sharing, TCC, launchd, and user-settings mutations. This is a source/test and local runtime route; it is not OS-level network namespace or live VPN isolation.

UI-034 identifies the selected fixture in both review surfaces. The connected route shows `Connected fixture`, the failure route shows `Isolation failure fixture`, and Command Center and Settings expose stable scenario identifiers for those labels. This removes ambiguity during a failure demonstration without changing the fixture controller, production route, or host-operation boundary.

UI-035 keeps each scenario identifier attached to one combined title-and-detail accessibility surface, while the separate host-operation warning remains its own boundary message. The visible demo layout and fixture behavior are unchanged.

UI-036 keeps the outer Command Center sandbox banner as a containing accessibility surface, so the scenario identifier and host-operation boundary remain independently inspectable beneath the banner identifier. This changes inspection grouping only; the visible demo layout, fixture controller, production route, and host-operation boundary remain unchanged.

UI-037 gives the existing host-operation warning stable identifiers in Command Center and Settings: `keybrake.command-center.network-sandbox-host-boundary` and `keybrake.settings.network-sandbox-host-boundary`. This changes inspection addressability only; the visible warning, fixture controller, production route, disabled Settings controls, and non-mutating host-operation boundary remain unchanged.

UI-038 gives the Settings Network sandbox section the stable container identifier `keybrake.settings.network-sandbox-section` while preserving its scenario and host-boundary children. This changes inspection addressability only; the visible demo layout, fixture controller, production route, disabled Settings controls, and non-mutating host-operation boundary remain unchanged.

UI-039 gives the existing “Network sandbox active” and “Host operations disabled” labels stable inspection identifiers in Command Center and Settings. This changes inspection addressability only; the visible demo layout, fixture controller, production route, disabled Settings controls, and non-mutating host-operation boundary remain unchanged.

UI-040 makes the Settings Network sandbox section a containing accessibility surface through `keybrake.settings.network-sandbox-section`, while its status, scenario, and host-boundary children remain independently inspectable. This changes inspection structure only; the visible demo layout, fixture controller, production route, disabled Settings controls, and non-mutating host-operation boundary remain unchanged.

UI-041 adds a visible fixture network inventory to the Command Center sandbox banner. The inventory lists Wi-Fi, USB Ethernet, Work VPN, and loopback from the same immutable fixture used by the controller, and each row reports its simulated state and device when available. This makes the inputs inspectable before an isolation or recovery action without adding host network access or changing the production route.

UI-042 mirrors that inventory in the Settings Network sandbox section, before the settings form is disabled. The section uses the same immutable fixture and exposes `keybrake.settings.network-sandbox-inventory` plus stable per-service identifiers, so Settings and Command Center show identical simulated Wi-Fi/VPN inputs without adding host network access or changing the production route.

UI-043 makes the Incident Log easier to review after a safe fixture run: each row shows its final state, update date/time, resolution, and step count, and expanding it shows target, outcome, operation description, and recorded observed state when available. Existing incident and operation-step UUIDs provide stable inspection anchors, while the view remains read-only over local incident history and does not invoke a host operation.

UI-044 keeps sandbox information readable during the safe Settings route. The status, scenario, fixture inventory, and current protection state remain visible, while host-bound settings sections stay disabled through the existing sandbox gate; no control in the sandbox route invokes a host operation.

UI-045 keeps empty target configuration states explicit during Settings review. When Local Automation or Remote Access has no configured entry, the section explains the state and points to the existing enrollment or approval path; the route remains read-only in sandbox mode and does not alter target or host behavior.

UI-046 makes configured target identity reviewable during Settings review. Each configured Local Automation or Remote Access row shows its bundle identifier and recorded executable path, or states that a built-in target has no recorded path; this is read-only presentation over the existing target definitions.

UI-047 makes the App Access menu destination explicit during safe review. The menu entry says `Open App Access Settings…` because it opens the existing Settings surface for review and mutation; selecting it does not revoke access immediately and does not change the sandbox or host-operation boundary.

UI-048 makes the Recovery panel's busy-state actions explicit during safe review. While a state-changing operation is running, `Quit KeyBrake` is unavailable with an explanation that matches the existing termination guard, while `Keep Isolation` remains available to close the panel without resolving recovery.

UI-049 makes the busy state explicit in the menu during safe review. The existing busy-disabled Stop Skynet Locally, Stop Remote Access, Open App Access Settings…, and Restart Espanso entries explain that KeyBrake is completing the current operation, while Stop Skynet Locally explains when local automation is already stopped; selecting them still follows the existing handlers and gates.

UI-050 makes menu Quit KeyBrake state-aware during safe review. The existing enabled action explains when recovery status is loading, when an emergency action is busy, when recovery choices remain required, and when KeyBrake can quit normally; selecting it still follows `requestQuit()` and its existing mouse-operated recovery flow.

UI-051 makes the menu's navigation destinations explicit during safe review. Open Command Center, Open Incident Log, and Settings… explain the surfaces they open through help and accessibility hints, while selecting them still follows the existing window routes.

UI-052 makes Recovery action hover guidance match the spoken descriptions during safe review. Keep Isolation and the shared recovery actions expose visible help for their normal descriptions and their existing busy-disabled explanation, while selecting them still follows the existing recovery handlers and gates.

UI-053 makes Application Access reset availability explicit during safe review. The existing Revoke Selected Access action explains whether the network sandbox or a missing application or privacy-service selection prevents use, while the action still follows its existing selection gate and privacy boundary.

UI-054 makes General host-bound settings explicit during safe review. Launch KeyBrake at Login and Register Privileged Helper explain when the network sandbox prevents host registration, and they expose current macOS status or the latest error without sending a new host request during review; their existing handlers and disabled gate remain unchanged.

UI-055 makes Emergency Isolation policy effects explicit during safe review. Each existing toggle identifies its Wi-Fi, Ethernet, VPN, Remote Login, or Remote Apple Events effect and current policy state, while the network sandbox explanation states that fixture state remains unchanged and no host request is sent during review.

UI-056 makes target enrollment paths explicit during safe review. The Local Automation and Remote Access Add Application controls describe their destination, exact identity capture, and Remote Access approval requirement, while the network sandbox explanation states that target fixtures and host configuration remain unchanged.

UI-057 makes custom-target removal explicit during safe review. Each existing custom-target Remove action explains which configured identity is removed, while the network sandbox explanation states that no removal request is sent during sandbox review and built-in targets remain protected.

UI-058 makes Application Access inputs explicit during safe review. The application picker and Privacy Reset Profile toggles explain current selection, required inputs, reset scope, and the TCC boundary, while the network sandbox explanation states that host privacy settings remain unchanged.

UI-059 makes Privacy Reset Profile scannable during safe review. The profile shows zero or selected-service count and repeats the sandbox/TCC boundary without sending a reset request.

UI-060 makes Remote Access approval state explicit during safe review. Each approval toggle explains whether its exact application is included, what changing the toggle does, and that the network sandbox changes neither fixture state nor host configuration.

UI-061 makes the Settings Recovery overview accessible during safe review. The visible recovery value retains its existing hydration-aware explanation, and accessibility inspection receives the same explanation without triggering a recovery action.

UI-062 makes Remote Access configuration scannable during safe review. The section shows how many configured targets are approved and repeats that only approved exact identities are stopped, while the network sandbox changes neither fixture state nor host configuration.

UI-063 makes the Settings Isolation profile explicit during safe review. The profile explains how many of the five controls are enabled, what the next Stop Remote Access operation will apply, and that sandbox review does not change fixture or host state.

UI-064 makes configured-target scope explicit during safe review. The overview distinguishes local-automation and remote-access targets and repeats that actions use exact bundle-and-executable identity while sandbox review leaves host configuration unchanged.

UI-065 makes the Settings protection state explicit during safe review. The existing title and explanation remain hydration-aware and non-actionable, while accessibility inspection receives one stable protection-state surface.

UI-066 makes the Emergency Isolation capability boundary explicit during safe review. The existing unsupported-sharing explanation is deterministically inspectable, while policy bindings, next-operation routing, and sandbox behavior remain unchanged.

UI-067 makes the Application Access TCC boundary explicit during safe review. The existing reset explanation is deterministically inspectable, while service selection, reset gating, sandbox behavior, and host privacy operations remain unchanged.

UI-068 makes the Settings Recovery contract boundary explicit during safe review. The existing recovery explanation is deterministically inspectable, while recovery routing, incident retention, sandbox behavior, and host operations remain unchanged.

UI-069 makes the Local Automation exact-identity boundary explicit during safe review. The existing bundle-and-executable matching explanation is deterministically inspectable, while target storage, process matching, sandbox behavior, and host operations remain unchanged.

UI-070 makes the Privileged Helper status explicit during safe review. The existing status text is deterministically inspectable, while helper registration, approval state, sandbox behavior, and host operations remain unchanged.

UI-071 makes the Privileged Helper error state explicit during safe review. The existing conditional error text is deterministically inspectable, while helper registration, error handling, approval state, sandbox behavior, and host operations remain unchanged.

UI-072 makes the Launch-at-Login error state explicit during safe review. The existing conditional error text is deterministically inspectable, while launch-at-login behavior, error handling, approval state, sandbox behavior, and host operations remain unchanged.

UI-073 makes the Settings error alert explicit during safe review. The existing alert message is deterministically inspectable, while alert routing, error handling, sandbox behavior, and host operations remain unchanged.

UI-074 makes the Application Access picker explicit during safe review. The existing target-selection control is deterministically inspectable, while target selection, reset gating, sandbox behavior, and host operations remain unchanged.

UI-075 makes the Revoke Selected Access action explicit during safe review. The existing TCC-safe reset action is deterministically inspectable, while its selection gate, reset request, sandbox behavior, and host operations remain unchanged.

UI-076 makes the Emergency Isolation section explicit during safe review. The existing policy section is deterministically inspectable, while its five policy bindings, unsupported-sharing boundary, sandbox behavior, and host operations remain unchanged.

UI-077 makes the Privacy Reset Profile section explicit during safe review. The existing privacy-service selection section is deterministically inspectable, while its summary, service-selection bindings, TCC boundary, sandbox behavior, and host operations remain unchanged.

UI-078 makes the Recovery section explicit during safe review. The existing recovery contract section is deterministically inspectable, while its contract explanation, recovery state, action routing, sandbox behavior, and host operations remain unchanged.

UI-079 makes the Remote Access section explicit during safe review. The existing approval section is deterministically inspectable, while its summary, empty state, target rows, enrollment action, target approval, sandbox behavior, and host operations remain unchanged.

UI-080 makes the Application Access section explicit during safe review. The existing privacy-access section is deterministically inspectable, while its target picker, TCC-safe explanation, revoke action, selection gate, sandbox behavior, and host operations remain unchanged.

UI-081 makes the General section explicit during safe review. The existing host-settings section is deterministically inspectable, while its launch-at-login control, privileged-helper status and registration action, conditional errors, sandbox behavior, and host operations remain unchanged.

UI-082 makes the Local Automation section explicit during safe review. The existing local-automation section is deterministically inspectable, while its empty state, target rows, Add Application action, exact bundle-and-executable identity boundary, sandbox behavior, and host operations remain unchanged.

UI-083 makes the Current protection state section explicit during safe review. The existing hydration-aware protection overview is deterministically inspectable, while its status surface, configured-target summary, isolation-profile summary, recovery summary, sandbox behavior, and host operations remain unchanged.

UI-084 makes the Configured targets summary explicit during safe review. The existing protection overview row is deterministically inspectable, while its target count, identity semantics, help text, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-085 makes the Isolation profile summary explicit during safe review. The existing protection overview row is deterministically inspectable, while its enabled-control count, policy semantics, help text, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-086 makes the Recovery summary explicit during safe review. The existing protection overview row is deterministically inspectable, while its recovery summary, contract semantics, help text, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-087 makes the Launch-at-Login control explicit during safe review. The existing General-section toggle is deterministically inspectable, while its binding, host-settings semantics, helper boundaries, help text, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-088 makes the Privileged Helper summary explicit during safe review. The existing General-section summary is deterministically inspectable, while its status, registration action, error surfaces, helper semantics, host-settings boundaries, help text, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-089 makes the Local Automation Add Application action explicit during safe review. The existing enrollment action is deterministically inspectable, while its handler, exact target identity semantics, enrollment guidance, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-090 makes the Remote Access Add Application action explicit during safe review. The existing approval-aware enrollment action is deterministically inspectable, while its handler, target identity semantics, approval guidance, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-091 makes the existing Disable Wi-Fi Emergency Isolation control explicit during safe review. The existing toggle is deterministically inspectable, while its visible label, policy binding, isolation guidance, policy semantics, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-092 makes the existing Disable physical Ethernet Emergency Isolation control explicit during safe review. The existing toggle is deterministically inspectable, while its visible label, policy binding, isolation guidance, policy semantics, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-093 makes the existing Disconnect VPNs Emergency Isolation control explicit during safe review. The existing toggle is deterministically inspectable, while its visible label, policy binding, isolation guidance, policy semantics, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-094 makes the existing Disable Remote Login Emergency Isolation control explicit during safe review. The existing toggle is deterministically inspectable, while its visible label, policy binding, isolation guidance, policy semantics, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-095 makes the existing Disable Remote Apple Events Emergency Isolation control explicit during safe review. The existing toggle is deterministically inspectable, while its visible label, policy binding, isolation guidance, policy semantics, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-096 makes each existing Privacy Reset Profile service control explicit during safe review. Each service toggle is deterministically inspectable through its TCC service value, while descriptor order, display labels, selection binding semantics, TCC reset boundaries, hydration behavior, sandbox behavior, and host operations remain unchanged.

UI-097 makes each existing non-built-in configured target removal control explicit during safe review. The Local Automation and Remote Access removal buttons are deterministically inspectable through their existing TargetDefinition.id values, while labels, built-in-target filtering, target identity details, removal semantics, sandbox behavior, and host operations remain unchanged.

UI-098 makes each existing Remote Access target approval control explicit during safe review. Each approval toggle is deterministically inspectable through its existing TargetDefinition.id value, while labels, target identity details, approval binding semantics, removal semantics, sandbox behavior, and host operations remain unchanged.

UI-099 makes the existing menu Restore Human Control action explicit during safe review. The recovery action is deterministically inspectable through its stable identifier, while its label, recovery-state gate, mouse-driven recovery route, menu ordering, sandbox behavior, and host operations remain unchanged.

UI-100 makes the existing menu Stop Remote Access action explicit during safe review. The emergency action is deterministically inspectable through its stable identifier, while its label, busy-state gate, handler, menu ordering, sandbox behavior, and host operations remain unchanged.

UI-101 makes the existing menu Stop Skynet Locally action explicit during safe review. The emergency action is deterministically inspectable through its stable identifier, while its label, already-stopped and busy-state gates, handler, menu ordering, sandbox behavior, and host operations remain unchanged.

UI-102 makes the existing menu Open App Access Settings action explicit during safe review. The Settings navigation action is deterministically inspectable through its stable identifier, while its label, Settings route, busy-state gate, handler, menu ordering, sandbox behavior, and host operations remain unchanged.

UI-103 makes the existing menu Open Command Center action explicit during safe review. The status navigation action is deterministically inspectable through its stable identifier, while its label, command-center route, guidance, menu ordering, sandbox behavior, and host operations remain unchanged.

UI-104 makes the existing menu Open Incident Log action explicit during safe review. The history navigation action is deterministically inspectable through its stable identifier, while its label, Incident Log route, guidance, menu ordering, sandbox behavior, and host operations remain unchanged.

UI-005 adds a visible history-cleanup availability state and stable symbols for the menu actions. The safe route remains non-mutating: an empty Incident Log keeps its clear-history action unavailable because no resolved record exists.

The Command Center review path keeps emergency actions separate from navigation: use Incident Log to inspect recorded outcomes, and use Settings to review approved targets and isolation policy. The visible cards show counts without changing any operation, and each destination now begins with the state or record context needed to interpret its controls.

1. Build the Debug app and launch it from a human-controlled local Mac session.
2. Open the menu bar item, show the exact status row and action ordering, and choose `Open Command Center`.
3. For isolated visual review, launch the app with `--keybrake-command-center`, `--keybrake-settings`, or `--keybrake-incident-log`, then use the cursor-safe preflight and Agent Display staging path. Each argument only opens its named window and does not change recovery behavior. UI-004 Settings shows current protection state and target/isolation counts, while Incident Log shows record/recovery counts, timestamped status, and expandable operation outcomes. The menu's `Open App Access Settings…` entry opens the same Settings review surface instead of performing an immediate revoke. In the Settings sandbox route, the fixture status and inventory remain readable while host-bound settings stay disabled, empty Local Automation or Remote Access lists explain the existing enrollment or approval path, and configured target rows expose the recorded identity fields without changing target behavior. To stage the recovery-required state, add `--keybrake-recovery-demo` to the Command Center route; the route creates a UUID-named temporary recovery store and incident, uses fixture-backed network and command controllers, and does not touch real Application Support, network, sharing, TCC, or process state.
4. Run the deterministic unit tests, which use fake command runners and never mutate the host network or real TCC decisions.
5. Demonstrate `Stop Skynet Locally` with a fake Espanso command trace or a disposable Espanso installation only after confirming the user configuration is backed up and untouched. Use `Restart Espanso` as a separate action.
6. Demonstrate remote-target sequencing with the harmless fixture definitions in the tests. Do not enroll a real support tool unless the machine has an independent recovery path.
7. Demonstrate privacy reset command formation with a disposable fixture bundle identifier and a fake runner. Never reset Terminal, Codex, Cursor, Espanso, KeyBrake, or another daily-use app merely to create a receipt.
8. Use read-only network inventory for the normal demo. Show the recovery contract and explain that a full live isolation test requires a separately staged session because it intentionally disconnects the active network.
9. For a deterministic recovery walkthrough, use the `--keybrake-command-center --keybrake-recovery-demo` route, relaunch the temporary app, show `Recovery Required` in the Command Center, open the recovery panel, and demonstrate the mouse-only quit warning. During a busy fixture operation, confirm that `Quit KeyBrake` is unavailable while `Keep Isolation` remains available. Seed the real `CurrentRecovery.json` only from a separately staged, human-controlled session with a known recovery path.

## Network sandbox route

Use the temporary app bundle produced by the Release build:

`/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-network-sandbox`

To open the Settings review surface with the same sandbox, use:

`/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-settings --keybrake-network-sandbox`

The connected route opens Command Center in normal state and labels itself `Connected fixture`; choose `Stop Remote Access` to exercise fixture isolation, then use `Restore Network` in the mouse-operated recovery panel. Wi-Fi restores to its recorded enabled state, while VPN remains disconnected per the recovery contract.

Use `--keybrake-network-sandbox-failure` instead to exercise deterministic Wi-Fi/VPN failure outcomes; that route labels itself `Isolation failure fixture`. Both routes are local fixture simulations and never alter host Wi-Fi, VPN, sharing, process, privacy, launchd, or user settings. Do not combine these flags with a live-host isolation test.

The demo must say `Network Isolated` or `Partial Isolation`, not that the computer is safe or that all remote access is eliminated.
