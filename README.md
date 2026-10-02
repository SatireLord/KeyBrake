# KeyBrake

KeyBrake is a macOS menu-bar failsafe. Source implements mouse-driven controls that stop approved local automation, isolate selected network and remote-access paths, record exact outcomes, and recover only state KeyBrake changed. The menu-bar entry also opens a larger Command Center that keeps status, emergency actions, recovery routing, recovery inventory, and recent activity in one visible surface, with labeled navigation cards into Incident Log and Settings.

It is a command-driven recovery prototype, not an antivirus product and not a promise that every form of remote access can be eliminated. Claims are bounded by operations KeyBrake can observe and verify.

Copyright 2026 Michael Tran. GitHub repository: [SatireLord/KeyBrake](https://github.com/SatireLord/KeyBrake). Bundle identifiers use `org.realitygood.KeyBrake` as the stable Mach/helper identity.

## Release status

| Surface | Status |
| --- | --- |
| Source tree | **Experimental public source** on `main` (merge commit `3c16897`) |
| GitHub visibility | **Public** — source available; claims remain bounded by the capability matrix |
| Downloadable binary | **BLOCKED** — unsigned local bundle only; signing, helper approval, and live verification remain external |

Version `0.1.0` (build `1`) is an experimental systems prototype. Local Xcode builds verify the app, embedded helper executable, LaunchDaemons plist, and feature contract with signing disabled. This project does not claim Developer ID signing, notarization, privileged-helper approval, or live-host network isolation without receipts.

UI-015 adds explicit `CFBundleExecutable` metadata to the native app plist. The unsigned Xcode Release bundle now records `KeyBrake` as its executable while preserving the stable bundle identity, helper resources, LaunchDaemons plist, feature contract, and version metadata.

Public claims must match [`docs/KEYBRAKE_CAPABILITY_MATRIX.md`](docs/KEYBRAKE_CAPABILITY_MATRIX.md). Evidence boundaries are in [`docs/KEYBRAKE_VERIFICATION.md`](docs/KEYBRAKE_VERIFICATION.md). The operator checklist for flipping GitHub visibility is [`docs/KEYBRAKE_PUBLIC_RELEASE.md`](docs/KEYBRAKE_PUBLIC_RELEASE.md). Signed distribution steps are in [`docs/KEYBRAKE_OPERATOR_SIGNED_RELEASE.md`](docs/KEYBRAKE_OPERATOR_SIGNED_RELEASE.md).

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

After building the app, run `scripts/test_keybrake_preference_pane_install.sh /path/to/KeyBrake.app` to verify the per-user pane installer in isolated temporary homes. The test never installs into the current user's Library or opens System Settings.

## Separate System Settings preference pane

The app target builds and embeds a separate `KeyBrake.prefPane`; this pane is its own System Settings entry and does not add a control inside Apple's Keyboard or General page. Install `KeyBrake.app` separately, then install its embedded pane for the current user:

```bash
scripts/install_keybrake_preference_pane.sh /Applications/KeyBrake.app
```

The installer copies the pane to `~/Library/PreferencePanes/KeyBrake.prefPane`, checks the app and pane bundle identifiers plus the exact `keybrake` URL scheme, and preserves a previous matching pane in a hidden timestamped backup. It refuses an unrelated pane or a symlink at the destination, and it does not install the app bundle.

The pane's Open Keyboard Settings button opens KeyBrake's existing Settings > Keyboard section without selecting an app or requesting a reset. KeyBrake's separate Reset Keyboard action remains limited to the selected app's `ListenEvent` and `PostEvent` permissions; it does not reset the physical keyboard or macOS Keyboard Accessibility settings. System Settings discovery and interaction on macOS 27 remain unverified on the current host; see [`docs/KEYBRAKE_VERIFICATION.md`](docs/KEYBRAKE_VERIFICATION.md).

## License and security

MIT License. See [`LICENSE`](LICENSE), [`SECURITY.md`](SECURITY.md), [`CONTRIBUTING.md`](CONTRIBUTING.md), and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Try it

Build the app with the commands above, then open the menu-bar item. Recovery stays mouse-driven because the keyboard may be the thing that is stuck.

For a walkthrough that does not change the Mac's network, privacy, or processes, use the fixture flags in [`docs/KEYBRAKE_SAFE_DEMO.md`](docs/KEYBRAKE_SAFE_DEMO.md):

```bash
/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-command-center --keybrake-network-sandbox
```

`--keybrake-recovery-demo` opens a temporary recovery case. `--keybrake-network-sandbox-failure` rehearses a failed isolation. Neither flag touches the host.
