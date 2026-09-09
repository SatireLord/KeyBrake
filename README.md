# KeyBrake

KeyBrake is a macOS menu-bar input and remote-access failsafe. It gives users a keyboard-independent recovery path for runaway keystroke automation, pauses approved local injectors, and performs reversible network isolation during suspicious or fraudulent remote-support sessions.

KeyBrake is deliberately a command-driven recovery tool, not an antivirus product or a promise that every form of remote access can be eliminated. Its claims are bounded by the operations it can observe and verify.

## What it does

The menu keeps the physical mouse as a recovery path:

- **Stop Skynet Locally** disables and stops Espanso plus other explicitly approved local automation targets. It does not disable networking or reset privacy permissions.
- **Stop Remote Access** records a recovery snapshot before mutations, stops approved automation and remote-control targets, resets only explicitly selected TCC-managed privacy decisions, disables supported sharing controls, disconnects selected VPNs, isolates selected non-loopback network services, verifies the result, and opens a persistent recovery panel.
- **Revoke App Access…** stops one selected application and resets selected TCC-managed privacy decisions for that application. It never edits the TCC database directly and never performs a global reset without a bundle identifier.
- **Restore Human Control** exposes independent mouse-driven actions for restoring network state, explicitly restoring sharing services, restarting Espanso, opening Privacy & Security settings, and reviewing the incident record.
- **Restart Espanso** is separate from network recovery and never changes Espanso configuration, packages, matches, service registration, or privacy permissions.
- **Open Incident Log** displays the local JSON-backed operation history.

The app reports precise states such as `Local Automation Stopped`, `Network Isolated`, `Partial Isolation`, `Recovery Required`, and `Human Control Restored`. It does not claim `Computer Secured`, `Threat Neutralized`, `System Safe`, or `All Remote Access Eliminated`.

## Architecture

`KeyBrakeCore` owns the serialized emergency coordinator, typed command boundary, exact process identity rules, target registries, Espanso adapter, remote-access controls, network inventory, sharing adapters, privacy reset allowlist, atomic recovery state, and incident storage. The SwiftUI/AppKit application owns the menu bar, settings, recovery panel, and incident viewer. The helper target is a narrow on-demand command surface for administrator-required network and sharing changes; it is not a generic shell.

All runtime state is local under `~/Library/Application Support/KeyBrake`, with user-only permissions and atomic replacement. The app stores operation metadata, identifiers, bounded sanitized errors, and timestamps. It does not store credentials, TCC database contents, Keychain contents, typed text, clipboard contents, documents, or packet data.

## Recovery boundaries

KeyBrake restores only properties that KeyBrake changed, and it compares original, applied, and current values before every restore. A changed value is reported as a conflict instead of being overwritten. VPNs remain disconnected after network restoration, remote-control applications remain stopped, and macOS privacy grants are never silently restored. An unresolved `CurrentRecovery.json` survives crashes and relaunches and keeps the recovery panel available.

KeyBrake does not defeat kernel or firmware compromise. It cannot guarantee recovery when the mouse and KeyBrake process are both unavailable or attacker-controlled. It cannot silently restore reset TCC grants, and it cannot guarantee control over unsupported third-party or system-managed network paths.

## Build and test

The project uses XcodeGen only to generate the native Xcode project from `project.yml`; the app has no third-party runtime dependencies.

```bash
xcodegen generate
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' build
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' test
```

All verification remains local. No GitHub Actions, telemetry, remote logging, analytics, or network dependency is part of the runtime.

## Portfolio demonstration

Use the safe runbook in [`docs/KEYBRAKE_SAFE_DEMO.md`](docs/KEYBRAKE_SAFE_DEMO.md). It demonstrates the menu, a harmless fake command runner, the recovery contract, the incident log, and read-only network inventory without severing the active development session. Live network isolation should only be performed from a separately staged human-controlled Mac session with a known recovery path.

Thirty-second description: “I built KeyBrake because automation and remote-control software can take over the same keyboard and network interfaces that users need for recovery. KeyBrake is an independent macOS menu-bar failsafe that lets a user use the mouse to stop approved automation, terminate configured remote-control applications, isolate networking, reset selected application permissions, and recover only the state it changed.”
