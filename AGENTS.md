# KeyBrake agent entrypoint

KeyBrake is a local-first macOS menu-bar failsafe. Keep process control exact, keep recovery mouse-driven, and keep claims limited to verified operations.

Before changing recovery, process, network, helper, or privacy behavior, read:

- [`docs/KEYBRAKE_RECOVERY_CONTRACT.md`](docs/KEYBRAKE_RECOVERY_CONTRACT.md)
- [`docs/KEYBRAKE_CAPABILITY_MATRIX.md`](docs/KEYBRAKE_CAPABILITY_MATRIX.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)

## Safety

- Do not edit TCC databases or restore TCC grants automatically.
- Do not run live network isolation, VPN disconnect, or sharing mutation through an active remote or primary development session. Use fixtures and [`docs/KEYBRAKE_SAFE_DEMO.md`](docs/KEYBRAKE_SAFE_DEMO.md) unless a staged Mac with a known recovery path is documented.
- Do not terminate processes by substring, run arbitrary shell commands, perform a global privacy reset, or target KeyBrake itself.
- Do not discard the user's uncommitted work. Do not force-push shared branches.
- Do not make the GitHub repository public. Do not merge pull request #1 unless the human maintainer explicitly asks.

## Proof

After `project.yml` changes, run `xcodegen generate`.

```bash
xcodegen generate
swift test --disable-sandbox --scratch-path /tmp/KeyBrakeSwiftPM
xcodebuild -project KeyBrake.xcodeproj -scheme KeyBrake -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

Do not claim Developer ID signing, notarization, privileged-helper approval, TCC execution, or live network isolation unless a corresponding receipt exists in [`docs/KEYBRAKE_VERIFICATION.md`](docs/KEYBRAKE_VERIFICATION.md).

Update the capability matrix when user-visible behavior changes. Leave commit, push, and PR creation to the human maintainer unless they explicitly ask.
