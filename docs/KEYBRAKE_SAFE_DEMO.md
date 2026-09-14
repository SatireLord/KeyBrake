# Safe demonstration

1. Build the Debug app and launch it from a human-controlled local Mac session.
2. Open the menu bar item, show the exact status row and action ordering, and choose `Open Command Center`.
3. For isolated visual review, launch the app with `--keybrake-command-center`, then use the cursor-safe preflight and Agent Display staging path. This argument only opens the existing window and does not change recovery behavior.
4. Run the deterministic unit tests, which use fake command runners and never mutate the host network or real TCC decisions.
5. Demonstrate `Stop Skynet Locally` with a fake Espanso command trace or a disposable Espanso installation only after confirming the user configuration is backed up and untouched. Use `Restart Espanso` as a separate action.
6. Demonstrate remote-target sequencing with the harmless fixture definitions in the tests. Do not enroll a real support tool unless the machine has an independent recovery path.
7. Demonstrate privacy reset command formation with a disposable fixture bundle identifier and a fake runner. Never reset Terminal, Codex, Cursor, Espanso, KeyBrake, or another daily-use app merely to create a receipt.
8. Use read-only network inventory for the normal demo. Show the recovery contract and explain that a full live isolation test requires a separately staged session because it intentionally disconnects the active network.
9. Seed `CurrentRecovery.json` with a test fixture, relaunch the app, show `Recovery Required` in the Command Center, open the recovery panel, and demonstrate the mouse-only quit warning.

The demo must say `Network Isolated` or `Partial Isolation`, not that the computer is safe or that all remote access is eliminated.
