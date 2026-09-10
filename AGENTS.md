# KeyBrake agent entrypoint

The canonical repository is the KeyBrake git checkout for the active task. Preserve all dirty work. Do not reset, clean, stash broadly, force-push, edit TCC databases, or run live network isolation through an active remote session.

Read [`docs/KEYBRAKE_MASTER_PLAN.md`](docs/KEYBRAKE_MASTER_PLAN.md) and [`docs/KEYBRAKE_RECOVERY_CONTRACT.md`](docs/KEYBRAKE_RECOVERY_CONTRACT.md) before implementation. The product is a local-first macOS menu-bar failsafe. Keep process control exact, keep recovery mouse-driven, and keep claims limited to verified operations.

Use `git status --short --branch`, `git diff --check`, the focused Xcode tests, and the local Release build for proof. Run `xcodegen generate` after changing `project.yml`. Record actual proof in `docs/KEYBRAKE_VERIFICATION.md`, commit coherent changes, push the active branch, and verify branch divergence separately. Do not claim signing, helper approval, TCC execution, or live network isolation unless the receipt exists.
