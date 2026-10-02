# Safe demonstration

KeyBrake can show its recovery path without changing the Mac's network, privacy settings, or processes. Recovery stays mouse-driven. These flags open temporary fixture state only.

1. Build the app with the commands in the README.
2. Open the menu-bar item and choose Open Command Center.
3. Launch a named window without changing recovery behavior:

```bash
/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-command-center
/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-settings
/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-incident-log
```

4. Stage a recovery decision in a temporary store:

```bash
/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-command-center --keybrake-recovery-demo
```

The recovery-demo route uses fixture-backed network and command controllers. It does not touch Application Support, network, sharing, privacy databases, or running processes. Relaunch that temporary app to see Recovery Required, then open the recovery panel with the mouse.

5. Run the unit tests. They use fake command runners and do not mutate the host network or privacy decisions.
6. Show Stop Skynet Locally only with a fake Espanso command trace or a disposable Espanso installation after the real configuration is backed up.
7. Show remote-target sequencing with the harmless fixture definitions in the tests. Do not enroll a real support tool unless the machine has an independent recovery path.
8. Show a privacy-reset command with a disposable fixture bundle identifier and a fake runner. Do not reset a daily-use app to create a receipt.
9. Use read-only network inventory for an ordinary demo. A full live isolation test disconnects the active network and belongs on a separately staged Mac with a known recovery path.
10. Seed the real CurrentRecovery.json only from that separately staged, human-controlled session.

## Network sandbox route

```bash
/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-network-sandbox
/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-settings --keybrake-network-sandbox
```

The connected route opens Command Center and labels itself Connected fixture. Stop Remote Access exercises fixture isolation, then Restore Network in the recovery panel. Wi-Fi restores to its recorded enabled state. VPN remains disconnected.

After each simulated operation, the Command Center and Settings inventories follow the recorded recovery snapshot. A failed isolation step is shown as unverified.

```bash
/usr/bin/open -n /path/to/KeyBrake.app --args --keybrake-network-sandbox-failure
```

That route labels itself Isolation failure fixture. Both routes are local simulations. They do not alter host Wi-Fi, VPN, sharing, processes, privacy, launchd, or user settings. Do not combine these flags with a live isolation test.
