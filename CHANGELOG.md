# Changelog

## v1.1.3 (2026-08-15)

- i18n: README 改为中文为主（`README.md`），新增英文镜像 `README.en.md`（与生态清单一致的双语文案）
- PR #3 / Issue #248 正文改为中文（清单维护者均为中文社区）

## v1.1.2 (2026-08-15)

- **privacy fix**: removed the machine-specific generated `scripts/watch-config.vbs` from the repository (it contained an absolute user path); history rewritten to purge it
- `install.ps1` now writes the VBS wrapper **only** into the per-user Startup folder, never into the repo
- `.gitignore` for generated artifacts; README `-ExpectTheme` example neutralized to a generic placeholder

## v1.1.1 (2026-08-15)

- `watch-config.ps1`: retention policy — keeps only the newest 20 auto-* snapshots (`-MaxAutoSnapshots`); manual snapshots are never pruned
- new `install.ps1`: registers watch-config auto-start via the per-user Startup folder (zero-window VBS wrapper, no admin needed); `-Uninstall` removes it; starts the watcher immediately
- README: new "Installation & deployment" section (clone, optional auto-start, explicit note that the system-level watchdog is intentionally not installed)
- system-level watchdog documented as optional (register manually if desired)

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
