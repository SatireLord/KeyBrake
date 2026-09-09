# KeyBrake master plan

## Objective

Ship a portfolio-ready native macOS menu-bar failsafe whose independent mouse-driven controls stop approved input automation, isolate selected network and remote-access paths, record exact outcomes, and recover only state KeyBrake changed.

## Invariants

- Recovery state is persisted and verified before reversible system mutation.
- Original/applied/current comparison prevents blind restoration.
- No TCC database editing or automatic TCC restoration.
- No automatic VPN reconnection or remote-agent restart.
- No substring-only process termination, arbitrary shell command, global privacy reset, or self-targeting.
- Partial and unsupported results remain visible; command exit zero never substitutes for post-state verification.
- All CI is local and the menu plus recovery panel remain mouse-operable.

## Current control state

- Repository: `/Users/michaeltran/AntiGravity/KeyBrake`
- GitHub: private `SatireLord/KeyBrake` exists and `main` is synchronized at `91a1cf6`
- Authoritative branch: `codex/keybrake-complete-implementation`
- Pull request: [#1](https://github.com/SatireLord/KeyBrake/pull/1), open and intentionally unmerged
- Last verified commit: `c4086e13c5110d7bceeece1b16d125ef6d8e7c95`
- Next action: human review, signing, helper approval, and live-host verification
- External blockers: Xcode BuildService setup stalled before compilation; Computer Use service startup failed; signing/helper approval depends on a Developer ID identity and host configuration

## Feature inventory

| Area | Baseline | Current |
| --- | --- | --- |
| Native project | missing | implemented |
| Feature contract | missing | implemented |
| Typed command boundary | missing | implemented |
| Process identity and protected targets | missing | implemented |
| Atomic incident/recovery storage | missing | implemented |
| Espanso/local automation | missing | implemented |
| Remote target registry | missing | implemented |
| TCC reset allowlist | missing | implemented |
| Helper boundary | missing | implemented boundary; live approval remains external |
| Network/sharing adapters | missing | implemented adapters and fixtures |
| Serialized coordinator | missing | implemented |
| Menu/recovery/settings UI | missing | implemented |
| Focused tests | missing | implemented; 12 SwiftPM tests pass |
| Documentation | missing | implemented |

## PM checklist

[x] KB-001 Resolve the authoritative local and remote repository.
[x] KB-002 Query Agent-Cache and record its repository/task status.
[x] KB-003 Query GitHub and Google Drive and record repository, PR, and specification truth.
[x] KB-004 Search the local workspace for every KeyBrake artifact.
[!] KB-005 Create the external safety snapshot and SHA-256 manifest; no existing checkout required a snapshot.
[x] KB-006 Preserve and classify every dirty path; no KeyBrake dirty paths existed.
[x] KB-007 Synchronize local and remote main at 0/0 without data loss; remote did not exist at discovery.
[x] KB-008 Continue the existing PR or create the single task branch; task branch follows the foundation commit.
[x] KB-009 Establish and record the baseline build and focused tests; baseline was a new empty repository and is recorded in the verification document.
[x] KB-010 Complete the baseline feature inventory.
[x] KB-011 Preserve the existing build system or create the native Xcode foundation.
[!] KB-012 Preserve or establish bundle identifiers and signing settings; signing identity remains an external verification item.
[x] KB-013 Add the machine-readable feature contract.
[x] KB-014 Add feature-contract regression tests.
[x] KB-015 Implement typed absolute-path command execution.
[x] KB-016 Implement command timeouts, output bounds, and redaction.
[x] KB-017 Implement process inventory and exact process identity.
[x] KB-018 Implement protected-process and self-protection rules.
[x] KB-019 Implement graceful stop, verified escalation, and respawn detection.
[x] KB-020 Implement atomic versioned incident storage.
[x] KB-021 Implement atomic versioned recovery storage.
[x] KB-022 Implement corrupt-snapshot preservation and launch-time recovery.
[x] KB-023 Implement original/applied/current conflict-aware restoration.
[x] KB-024 Implement Espanso executable discovery.
[x] KB-025 Implement Espanso immediate disable, stop, start, restart, and verification.
[x] KB-026 Implement approved local automation enrollment.
[x] KB-027 Implement Stop Skynet Locally without network or TCC mutation.
[x] KB-028 Implement remote-control candidate discovery.
[!] KB-029 Implement remote-control enrollment and signing verification; exact bundle/executable enrollment is implemented, while code-signing verification remains host-dependent.
[x] KB-030 Implement exact remote-process stopping.
[x] KB-031 Implement verified non-Apple launchd-service stopping.
[x] KB-032 Enforce the rule that remote-control apps never restart automatically.
[x] KB-033 Implement the per-application privacy picker.
[x] KB-034 Implement the version-gated TCC allowlist.
[x] KB-035 Implement per-bundle privacy reset and safe per-bundle All.
[x] KB-036 Enforce the rule that KeyBrake never edits or restores TCC grants.
[x] KB-037 Implement explicit emergency-profile privacy opt-in.
[!] KB-038 Implement the SMAppService on-demand privileged helper boundary; the typed helper boundary is implemented, while signed helper installation and audit-token proof remain host-dependent.
[x] KB-039 Implement typed helper authorization validation.
[x] KB-040 Implement the privileged command and target allowlist.
[x] KB-041 Implement helper status visibility in Settings.
[!] KB-042 Implement actual network-service and hardware discovery boundary; read-only service state discovery is implemented, while host-specific hardware and privilege proof remain external.
[x] KB-043 Implement stable service and interface classification.
[x] KB-044 Implement VPN inventory and disconnection.
[x] KB-045 Implement network-service disable operations.
[x] KB-046 Implement Wi-Fi radio disable command boundary.
[x] KB-047 Implement bounded interface-down helper command.
[x] KB-048 Implement network-isolation result classification.
[x] KB-049 Implement exact network restoration without VPN reconnection.
[x] KB-050 Implement Remote Login detection, disable, verification, and restore boundary.
[x] KB-051 Implement Remote Apple Events detection, disable, verification, and restore boundary.
[!] KB-052 Implement capability-detected Screen Sharing control; host-specific command remains unsupported until verified.
[!] KB-053 Implement capability-detected Remote Management control; host-specific command remains unsupported until verified.
[x] KB-054 Implement explicit sharing-service restoration.
[x] KB-055 Implement the serialized Stop Remote Access transaction.
[x] KB-056 Implement persistence gating before system mutations.
[x] KB-057 Implement partial-failure continuation and precise status.
[x] KB-058 Implement duplicate-action serialization through the actor.
[x] KB-059 Implement the exact menu and visible state row.
[x] KB-060 Implement the persistent mouse-driven recovery panel.
[x] KB-061 Implement Restore Human Control and its independent actions.
[x] KB-062 Implement the incident-log viewer.
[x] KB-063 Implement the unresolved-state quit warning.
[x] KB-064 Implement the focused Settings sections and target editors, including exact-identity application enrollment and persisted approval.
[!] KB-065 Implement Launch at Login without duplicate processes through SMAppService; source integration exists, while signed-host proof remains external.
[x] KB-066 Add VoiceOver labels and non-color-only status communication.
[x] KB-067 Add required deterministic process, storage, privacy, helper, coordinator, and menu tests.
[x] KB-068 Run focused local tests during implementation.
[x] KB-069 Run the complete KeyBrake local test suite once; SwiftPM proof passed 13 tests with 0 failures.
[!] KB-070 Run the final local Release build; Xcode BuildService setup stalled before compilation, while the SwiftPM app product built successfully.
[x] KB-071 Verify helper embedding, plist placement, and entitlements in the generated Xcode project and build settings; final Xcode bundle output remains unproved.
[!] KB-072 Verify signing and Gatekeeper only when credentials permit proof.
[!] KB-073 Perform the safe live Espanso stop and restart test; bounded until a human-controlled session is staged.
[x] KB-074 Perform the harmless fixture remote-target test through fake process control.
[x] KB-075 Perform the safe fixture privacy-reset test through fake command formation.
[x] KB-076 Perform read-only network inventory proof through fixtures.
[!] KB-077 Perform live network isolation only when the local execution path remains recoverable.
[x] KB-078 Verify unresolved recovery after application relaunch through deterministic store tests.
[x] KB-079 Verify mouse-only quit and recovery paths through the app model and UI review.
[x] KB-080 Complete README.md.
[x] KB-081 Complete AGENTS.md.
[x] KB-082 Complete docs/KEYBRAKE_MASTER_PLAN.md.
[x] KB-083 Complete docs/KEYBRAKE_RECOVERY_CONTRACT.md.
[x] KB-084 Complete docs/KEYBRAKE_VERIFICATION.md.
[x] KB-085 Complete docs/KEYBRAKE_SAFE_DEMO.md.
[x] KB-086 Run git diff --check and the complete changed-file audit.
[x] KB-087 Compare the baseline and final feature inventories.
[x] KB-088 Prove that no requested or existing feature was removed; baseline contained no product feature.
[x] KB-089 Compute and record required SHA-256 checksums.
[x] KB-090 Commit every coherent deliverable.
[x] KB-091 Push every implementation commit.
[x] KB-092 Verify task-branch upstream divergence at 0/0.
[x] KB-093 Verify main versus origin/main divergence at 0/0.
[x] KB-094 Update the existing PR or create the single PR; PR #1 is open against `main`.
[x] KB-095 Add exact local test, build, and proof evidence to the PR body.
[x] KB-096 Preserve and list every foreign dirty file; none were changed.
[x] KB-097 Leave task-owned files clean after the final proof commit.
[x] KB-098 Record every genuine external blocker without disguising it as success.
[x] KB-099 Re-run the complete circular requirements audit and record every external proof boundary.
[x] KB-100 Deliver the complete final report with this entire current checklist.

## Proof and handoff

After each coherent milestone, update this document and `docs/KEYBRAKE_VERIFICATION.md` with the current SHA, focused proof, known limitations, and exact next action. Preserve dirty paths and never use destructive Git cleanup. Keep the final PR unmerged until human review.
