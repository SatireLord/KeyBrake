# KeyBrake recovery contract

1. KeyBrake writes and verifies `CurrentRecovery.json` before it mutates network, sharing, or other reversible system state.
2. Every restorable value records `original`, `applied`, and current observations. KeyBrake restores only when current equals applied; otherwise it records a conflict and leaves the newer value untouched.
3. Restoration is idempotent. A value already equal to original is skipped as `alreadyInDesiredState`; repeated restore does not toggle it.
4. A failed, unsupported, or conflicting selected restoration keeps `CurrentRecovery.json` and publishes `Recovery Required`.
5. KeyBrake never edits or silently restores the TCC database. After `tccutil reset`, macOS may ask the user to grant access again.
6. Network restoration never reconnects a VPN automatically. The incident lists previously connected VPNs for explicit user action.
7. Network restoration never restarts remote-control applications. Remote-control software remains stopped until the user explicitly launches or enables it.
8. Sharing restoration is a separate mouse-driven action. It restores only services KeyBrake disabled and only while their current state still equals the applied disabled state.
9. Espanso restart is a separate explicit action and never edits Espanso configuration or unregisters its service.
10. A corrupt or incompatible snapshot is preserved. KeyBrake shows `Recovery Required` and the incident path rather than deleting the file.
11. On launch, an unresolved snapshot immediately exposes the recovery panel and keeps every recovery action mouse-operable.
