# Safe demonstration

The Command Center review path keeps emergency actions separate from navigation: use Incident Log to inspect recorded outcomes, and use Settings to review approved targets and isolation policy. The visible cards show counts without changing any operation.

1. Build the Debug app and launch it from a human-controlled local Mac session.
2. Open the menu bar item, show the exact status row and action ordering, and choose `Open Command Center`.
3. For isolated visual review, launch the app with `--keybrake-command-center`, then use the cursor-safe preflight and Agent Display staging path. This argument only opens the existing window and does not change recovery behavior. To stage the recovery-required state, add `--keybrake-recovery-demo`; the route creates a UUID-named temporary recovery store and incident, uses fixture-backed network and command controllers, and does not touch real Application Support, network, sharing, TCC, or process state.
4. Run the deterministic unit tests, which use fake command runners and never mutate the host network or real TCC decisions.
5. Demonstrate `Stop Skynet Locally` with a fake Espanso command trace or a disposable Espanso installation only after confirming the user configuration is backed up and untouched. Use `Restart Espanso` as a separate action.
6. Demonstrate remote-target sequencing with the harmless fixture definitions in the tests. Do not enroll a real support tool unless the machine has an independent recovery path.
7. Demonstrate privacy reset command formation with a disposable fixture bundle identifier and a fake runner. Never reset Terminal, Codex, Cursor, Espanso, KeyBrake, or another daily-use app merely to create a receipt.
8. Use read-only network inventory for the normal demo. Show the recovery contract and explain that a full live isolation test requires a separately staged session because it intentionally disconnects the active network.
9. For a deterministic recovery walkthrough, use the `--keybrake-command-center --keybrake-recovery-demo` route, relaunch the temporary app, show `Recovery Required` in the Command Center, open the recovery panel, and demonstrate the mouse-only quit warning. Seed the real `CurrentRecovery.json` only from a separately staged, human-controlled session with a known recovery path.

The demo must say `Network Isolated` or `Partial Isolation`, not that the computer is safe or that all remote access is eliminated.
