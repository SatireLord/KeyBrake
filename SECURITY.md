# Security policy

KeyBrake is experimental macOS recovery software that can stop processes, mutate network settings, reset privacy decisions, and invoke a privileged helper. Treat reports as high priority.

## Supported versions

| Version | Supported |
| --- | --- |
| 0.1.x (experimental prototype) | Best-effort review on the active development branch |

The GitHub repository is currently private. Downloadable binaries are unsigned.

## Reporting a vulnerability

Do not open a public GitHub issue for exploitable defects in privileged execution, recovery bypass, or authorization boundaries.

Use GitHub private vulnerability reporting:

https://github.com/SatireLord/KeyBrake/security/advisories/new

Include:

1. A concise description of the impact
2. macOS version and hardware class
3. KeyBrake version or commit SHA
4. Reproduction steps that avoid destructive live isolation unless explicitly agreed
5. Any logs from `~/Library/Application Support/KeyBrake/Incidents/` with secrets redacted

## Out of scope

- Live network isolation on a machine without a known recovery path
- Requests to bypass macOS TCC by editing the TCC database
- Reports that KeyBrake cannot recover from kernel or firmware compromise (documented limitation)

## Safe disclosure expectations

Reports should distinguish:

- **Design defects** (incorrect recovery logic, missing authorization)
- **Implementation defects** (command construction, race conditions)
- **Host-configuration gaps** (unsigned helper, missing Developer ID identity)

We will not claim a fix is shipped until focused tests or staged host receipts exist.
