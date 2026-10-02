# Operator signed-release checklist

Agents must not claim Developer ID signing, notarization, privileged-helper approval, or live host mutation without receipts in [`KEYBRAKE_VERIFICATION.md`](KEYBRAKE_VERIFICATION.md).

## Prerequisites

- Apple Developer Program membership with a **Developer ID Application** identity (not only Apple Development / Apple Distribution).
- A **staged Mac** with a documented recovery path if live isolation or TCC reset will be exercised.
- Public **source** already on `main` per [`KEYBRAKE_PUBLIC_RELEASE.md`](KEYBRAKE_PUBLIC_RELEASE.md).

## Recommended sequence

1. Enable `CODE_SIGNING_ALLOWED=YES` only in a release lane you control; keep local default unsigned builds for contributors.
2. Sign the app, embedded helper, and privileged helper with matching team and hardened runtime settings.
3. Notarize and staple the app bundle; record ticket IDs and `spctl` output in the verification ledger.
4. Install on the staged Mac; register the privileged helper through System Settings and record approval state.
5. Run bounded live proofs documented in [`KEYBRAKE_SAFE_DEMO.md`](KEYBRAKE_SAFE_DEMO.md); do not use the primary development session for destructive isolation.
6. Update [`KEYBRAKE_CAPABILITY_MATRIX.md`](KEYBRAKE_CAPABILITY_MATRIX.md) and README **Downloadable binary** row only after receipts exist.

## Out of scope for automation

Keychain identities, notarization credentials, and SMAppService approval require the human maintainer. Agents may update docs and scripts but must not store secrets in the repository.
