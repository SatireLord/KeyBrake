# KeyBrake

KeyBrake is a macOS menu-bar failsafe. Source implements mouse-driven controls that stop approved local automation, isolate selected network and remote-access paths, record exact outcomes, and recover only state KeyBrake changed. The menu-bar entry also opens a larger Command Center that keeps status, emergency actions, recovery routing, recovery inventory, and recent activity in one visible surface.

It is a command-driven recovery prototype, not an antivirus product and not a promise that every form of remote access can be eliminated. Claims are bounded by operations KeyBrake can observe and verify.

Copyright 2026 Michael Tran. GitHub repository: [SatireLord/KeyBrake](https://github.com/SatireLord/KeyBrake). Bundle identifiers use `org.realitygood.KeyBrake` as the stable Mach/helper identity.

## Release status

| Surface | Status |
| --- | --- |
| Source tree | Prepared for a human identity and visibility decision |
| GitHub visibility | **HOLD** — this repository remains private |
| Downloadable binary | **BLOCKED** — unsigned local bundle only; signing, helper approval, and live verification remain external |

Version `0.1.0` (build `1`) is an experimental systems prototype. Local Xcode builds verify the app, embedded helper executable, LaunchDaemons plist, and feature contract with signing disabled. This project does not claim Developer ID signing, notarization, privileged-helper approval, or live-host network isolation without receipts.

Public claims must match [`docs/KEYBRAKE_CAPABILITY_MATRIX.md`](docs/KEYBRAKE_CAPABILITY_MATRIX.md). Evidence boundaries are in [`docs/KEYBRAKE_VERIFICATION.md`](docs/KEYBRAKE_VERIFICATION.md). The operator checklist for flipping GitHub visibility is [`docs/KEYBRAKE_PUBLIC_RELEASE.md`](docs/KEYBRAKE_PUBLIC_RELEASE.md).

## What it does

The menu keeps the physical mouse as a recovery path. The following behaviors exist in source; live host mutation is **host-unverified** until a receipt exists.

- **Stop Skynet Locally** disables and stops Espanso plus other explicitly approved local automation targets. It does not disable networking or reset privacy permissions.
- **Stop Remote Access** records a recovery snapshot before mutations, stops approved automation and remote-control targets, disables supported sharing controls according to the emergency profile, disconnects selected VPNs, isolates selected non-loopback network services, verifies the result, and opens a persistent recovery panel. Privacy resets are a separate explicit action via **Revoke App Access…**, not part of Stop Remote Access.
- **Revoke App Access…** opens Settings, where one selected application can be stopped and selected TCC-managed privacy decisions reset. KeyBrake never edits the TCC database file and never performs a global reset without a bundle identifier.
- **Restore Human Control** exposes independent mouse-driven actions for restoring network state, explicitly restoring sharing services, restarting Espanso, opening Privacy & Security settings, and reviewing the incident record.
- **Restart Espanso** is separate from network recovery and never changes Espanso configuration, packages, matches, service registration, or privacy permissions.
- **Open Incident Log** displays the local JSON-backed operation history.
- **Open Command Center** opens the at-a-glance status and action surface without changing the underlying recovery semantics. It keeps full-width emergency actions prominent, surfaces recorded recovery inventory and unresolved recovery, and links to the Incident Log and Settings windows.

The app reports states such as `Normal Input`, `Local Automation Stopped`, `Network Isolated`, `Partial Isolation`, and `Recovery Required`. Successful restore returns to `Normal Input`. It does not claim `Computer Secured`, `Hacker Removed`, `Threat Neutralized`, `System Safe`, or `All Remote Access Eliminated`.

## Architecture

`KeyBrakeCore` owns the serialized emergency coordinator, typed command boundary, exact process identity rules, target registries, Espanso adapter, remote-access controls, network inventory, sharing adapters, privacy reset allowlist, atomic recovery state, and incident storage. The SwiftUI/AppKit application owns the menu bar, settings, recovery panel, and incident viewer. The helper target is an on-demand privileged command surface for administrator-required network, sharing, and verified launchd stops. It is not a generic shell. The helper can enable as well as disable network and sharing services during restore; that is intentional recovery behavior.

All runtime state is local under `~/Library/Application Support/KeyBrake`, with user-only permissions and atomic replacement. The app stores operation metadata, identifiers, bounded command errors, and timestamps. It does not store credentials, TCC database contents, Keychain contents, typed text, clipboard contents, documents, or packet data.

## Recovery boundaries

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

The Command Center now groups Incident Log and Settings into a Review and configure section that shows the current incident and configured-target counts, while the emergency and recovery actions keep their existing semantics.

Use the runbook in [`docs/KEYBRAKE_SAFE_DEMO.md`](docs/KEYBRAKE_SAFE_DEMO.md). It demonstrates the menu, the Command Center, a harmless fake command runner, the recovery contract, the incident log, and read-only network inventory without severing the active development session. For deterministic recovery-required staging, launch the temporary app with `--keybrake-command-center --keybrake-recovery-demo`; that route writes its fixture snapshot and incident into a UUID-named temporary directory and uses fixture-backed controllers, so it does not touch real Application Support, network, sharing, TCC, or process state. Live network isolation should only be performed from a separately staged human-controlled Mac session with a known recovery path.
