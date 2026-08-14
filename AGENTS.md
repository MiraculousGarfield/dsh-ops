# AGENTS.md — for AI agents working with this repo

This repository ships standalone Windows/PowerShell ops tooling for DeepSeek Harness (dsh).
It exists because host-level dsh failures cannot be diagnosed from inside dsh: when core
packages get duplicated, **every** dsh session's tools crash in ~1 ms, so the toolkit must be
runnable without dsh (plain PowerShell, zero tokens, zero AI).

## Quick orientation

| File | Purpose |
|---|---|
| `runbook.md` | Rules, procedures, escape hatch — **read first** |
| `docs/diagnosis-table.md` | Symptom → first check |
| `scripts/check-health.ps1` | One-command health check (prefer it over exploratory debugging) |
| `scripts/backup-config.ps1` | Snapshot profile config before changes |
| `scripts/restore-snapshot.ps1` | Restore config from a snapshot |
| `scripts/restart-service.ps1` | Start the dsh service if down |
| `scripts/watchdog.ps1` | Silent watchdog for scheduled tasks |
| `lib/dsh-common.ps1` | DSH home / launcher / node autodetection helpers |
| `cmd/*.cmd` | Double-click wrappers for the scripts |

## Golden rules

1. **Never** `pnpm add` into a dsh profile — it can duplicate core `@deepseek-ai/dsh-*`
   packages and brick every session (the worst incident class).
2. **Never** `insert` a plugin row that is already in `dsh.profile.bundles` (duplicate entry).
3. Theme/plugin packages: `main` must be server-safe; browser code only via
   `exports["./client"]` + `dsh.client` metadata.
4. Back up before changes (`backup-config.ps1`), verify after (`check-health.ps1`).

## Escape hatch (critical)

- **Symptom**: any tool call crashes in ~1 ms with `prepare` / undefined.
- **Cause class**: duplicated core packages (host-level) — dsh sessions cannot self-diagnose.
- **Action**: do NOT open dsh sessions to investigate; use the standalone scripts / `.cmd`
  wrappers directly (see `runbook.md` §3), and only involve external tooling if those fail.

## Environment discovery (no configuration needed)

- DSH home: `$env:DSH_HOME` or `%USERPROFILE%\.dsh`
- dsh launcher: `$env:DSH_BIN` override, npx cache under `%LOCALAPPDATA%\npm-cache\_npx`, or `<dsh>\profiles\node_modules`
- node.exe: `PATH`, then standard install locations
