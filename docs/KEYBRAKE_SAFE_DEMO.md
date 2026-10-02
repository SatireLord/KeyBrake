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

## Review display

KeyBrake does not create a display, and the failsafe does not need one. The menu bar on the physical display remains the recovery path. On a machine that already has `displayctl`, the pane-test script can rebuild one KeyBrake-owned review display and remove that same display:

```bash
scripts/test_keybrake_preference_pane_install.sh rebuild /path/to/KeyBrake.app
scripts/test_keybrake_preference_pane_install.sh remove
```

`rebuild` creates logical display `keybrake-review` for owner `keybrake-review` at 1920×1080, then prints its inspection. Pass a built `KeyBrake.app` when you also want Command Center opened and moved above the other displays. That move does not click. `rebuild` with no app path only brings the display back.

`remove` releases and turns off `keybrake-review` for that same owner. It does not sweep other virtual displays.

Rebuild when the review display is missing, after a failed window move, or when you want a clean 1920×1080 surface before looking at Command Center, Settings, Incident Log, or the recovery panel.

Remove it when the review is finished, before you hand the Mac to someone else, and when the extra display is covering the physical menu bar you would use for mouse recovery. Leave it up while you are still reading that review. Leave every other virtual display alone. Removing this display does not restore network, sharing, or local automation, and it does not quit KeyBrake.
