# Changelog

## v1.0.0 (2026-08-15)

Initial release — standalone ops toolkit for DeepSeek Harness.

- `check-health.ps1`: 7 checks (port, HTTP, expected package in boot roster, duplicate row ids in composed tree, core-package duplicates, backup discipline)
- `backup-config.ps1`: snapshot profile config + packages list into `<dsh>/backups/<stamp>/`
- `restore-snapshot.ps1`: restore config from a snapshot (confirmation prompt, `-Force` to skip)
- `restart-service.ps1`: start the dsh service if down (launcher autodetection)
- `watchdog.ps1`: silent scheduled-task watchdog with log file
- `runbook.md`, `AGENTS.md`, `docs/diagnosis-table.md`, `docs/case-study-2026-08-15.md`
- Windows / PowerShell 5.1+; Node.js only required for composed-tree checks and restart
