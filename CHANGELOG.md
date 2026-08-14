# Changelog

## v1.1.0 (2026-08-15)

- `check-health.ps1`: every run appended to `<dsh>/logs/health-history.log` (timestamped PASS/FAIL + failed checks) so incidents get a timeline
- `check-health.ps1`: new static lint check — user packages whose `main` file references browser globals (`window`/`document`), i.e. the malformed-theme class
- `watchdog.ps1`: restart now verifies real health (port + HTTP 200); two consecutive failed restarts stop retrying and log "config likely broken - run restore-snapshot.ps1"
- `restart-service.ps1`: verifies HTTP 200 after the port is up
- new `list-snapshots.ps1`: list snapshots with file counts and creation times
- new `diff-snapshot.ps1`: diff config between two snapshots (git-based when available, plain line diff otherwise)
- new `watch-config.ps1`: polls profile config, auto-snapshots on change (debounced) into `<dsh>/backups/auto-*` with audit log `<dsh>/logs/config-watch.log`
- new cmd wrappers: `list-snapshots.cmd`, `diff-snapshot.cmd`, `watch-config.cmd`

## v1.0.0 (2026-08-15)

Initial release — standalone ops toolkit for DeepSeek Harness.

- `check-health.ps1`: 7 checks (port, HTTP, expected package in boot roster, duplicate row ids in composed tree, core-package duplicates, backup discipline)
- `backup-config.ps1`: snapshot profile config + packages list into `<dsh>/backups/<stamp>/`
- `restore-snapshot.ps1`: restore config from a snapshot (confirmation prompt, `-Force` to skip)
- `restart-service.ps1`: start the dsh service if down (launcher autodetection)
- `watchdog.ps1`: silent scheduled-task watchdog with log file
- `runbook.md`, `AGENTS.md`, `docs/diagnosis-table.md`, `docs/case-study-2026-08-15.md`
- Windows / PowerShell 5.1+; Node.js only required for composed-tree checks and restart
