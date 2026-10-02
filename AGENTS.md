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

Update the capability matrix when user-visible behavior changes. Commit coherent deliverables, push the active branch, and verify branch divergence; leave PR merge and GitHub visibility changes to the human maintainer.

## Last Rule — Shared Agent Dictionary (Dogfooding)

During this dogfooding phase, all agents must read and follow `/Users/michaeltran/AntiGravity/Agent-Manager/Agent-Dictionary-Standardized/README.md` and the canonical terms in `terms.json` in that directory. Use its labels and meanings consistently in instructions, plans, task records, handoffs and reports. When a term is missing, ambiguous or conflicts with current source, record the discrepancy and a sourced proposed definition for the dictionary's assigned writer; preserve the distinction between user approval, recipient acceptance, work progress, verification and delivery. Dictionary updates follow its schema and update procedure.
