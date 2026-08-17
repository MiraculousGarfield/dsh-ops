# dsh-ops — Ops Toolkit for DeepSeek Harness

**Version: v1.2.0** · [CHANGELOG](CHANGELOG.md) · [MIT](LICENSE) · [中文](README.md)

> Companion plugin **dsh-ops-health** is featured on the community-maintained [Awesome DeepSeek Harness Plugin](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin) list
> [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

> **For AI agents**: if you are assisting with a dsh (DeepSeek Harness) deployment,
> read [`runbook.md`](runbook.md) and [`docs/diagnosis-table.md`](docs/diagnosis-table.md) first,
> and prefer the scripts in `scripts/` over exploratory debugging.
> If every tool call crashes in ~1 ms (`prepare` / undefined), that is a host-level failure:
> **stop diagnosing inside dsh** and use the standalone scripts (see runbook §3).

A small, standalone, **AI-free** operations toolkit for [DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness) deployments on Windows.
Born from a real incident (2026-08-15) that cost tokens and effort: a broken third-party theme + duplicate plugin rows + duplicated core packages bricked **every** dsh session (host-level `prepare` crash), and dsh could not diagnose itself.

**Key insight**: host-level failures take down every dsh session, so the tooling must be runnable *without* dsh — plain PowerShell, zero tokens, zero AI.

## Features

| Tool | What it does | Cost |
|---|---|---|
| `fix-service.ps1` | **Smart one-click recovery**: restores snapshots newest-first (auto-* → known-good-auto → dated known-good), restarting + health-checking each one, stopping at the first green state (keeps your recent work); snapshots the current broken state to `pre-fix-*` first | 0 tokens |
| `restore-known-good.cmd` | Fast fallback straight to the latest green baseline (`known-good-auto`, auto-refreshed by every green check) | 0 tokens |
| `check-health.ps1` | 8 checks: port, HTTP, expected package in boot roster, duplicate row ids in composed tree, core-package duplicates, backup discipline, static lint (user packages whose `main` references browser globals). Every run is appended to `<dsh>/logs/health-history.log`; **all-green runs auto-refresh the `known-good-auto` snapshot** | 0 tokens |
| `backup-config.ps1` | Snapshot profile config (cordis.yml / cordis.patch.yml / package.json / pnpm-workspace.yaml / settings.yaml) + packages list into `<dsh>/backups/<stamp>/` | 0 tokens |
| `restore-snapshot.ps1` | Restore config from a snapshot (with confirmation) | 0 tokens |
| `list-snapshots.ps1` | List snapshots with file counts and creation times | 0 tokens |
| `diff-snapshot.ps1` | Diff config between two snapshots (audit what changed) | 0 tokens |
| `restart-service.ps1` | Start the dsh service if down; verifies port **and** HTTP 200 | 0 tokens |
| `watchdog.ps1` | Silent watchdog for scheduled tasks; restarts only if the config is healthy (2 consecutive failed restarts stop retrying and tell you to restore a snapshot) | 0 tokens |
| `watch-config.ps1` | Auto-snapshot config whenever it changes (poll + debounce, keeps 20) + audit log `<dsh>/logs/config-watch.log` | 0 tokens |
| `audit-ops.ps1` | Project self-audit: PS syntax / cmd reference integrity / GBK-garble risk in console output / secret patterns / check-health copy drift | 0 tokens |
| `runbook.md` | Rules, procedures, and the symptom → first-check table | — |

Double-click friendly `.cmd` wrappers live in `cmd/`.

A browser-side plugin shell (**dsh-ops-health**) lives in its own repo:
[`MiraculousGarfield/dsh-ops-health`](https://github.com/MiraculousGarfield/dsh-ops-health) —
sidebar button → plain HTTP route `/ops/health` (independent of the tool registry) → hidden
`check-health.ps1` run → structured report card with theme-following colors.

## Snapshot tiers (three layers)

| Tier | Updated by | Purpose |
|---|---|---|
| `auto-<stamp>` | `watch-config.ps1` on every config change (keeps 20) | raw material for step-by-step rollback |
| `known-good-auto` | `check-health.ps1` on every all-green run | fast-fallback safety baseline |
| `known-good-<date>` | manual (`backup-config.ps1 -Name`) | human-confirmed milestones |

## Installation & deployment

dsh-ops is deliberately **install-free**: clone it anywhere and run the scripts directly (all paths are auto-detected). The only optional installation is the **config watcher auto-start**:

```powershell
# 1. clone anywhere (recommended: %USERPROFILE%\.dsh\ops\)
git clone https://github.com/MiraculousGarfield/dsh-ops.git

# 2. (optional) register watch-config to auto-start at logon - zero window (VBS)
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

# remove it again
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

Notes:
- `install.ps1` registers auto-start via the **per-user Startup folder** (no admin rights, VBS zero-window wrapper, no console flash) and starts the watcher immediately. `-Uninstall` removes it.
- `watch-config.ps1` keeps only the newest **20** auto-snapshots (`-MaxAutoSnapshots`); manual snapshots (`known-good-*`, timestamped backups) are never pruned.
- The system-level **watchdog is intentionally not installed**: most setups do not need the dsh service running 24/7 - the desktop wrapper or a manual `restart-service.ps1` covers the rest. If you want it anyway, register `scripts\watchdog.ps1` as your own scheduled task (it exits silently and only logs).

## Quick start

```powershell
# one-click health check
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-health.ps1

# with a custom profile / port / expected theme package
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-health.ps1 -Profile web -Port 3080 -ExpectTheme <your-theme-package>

# back up before ANY config change
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\backup-config.ps1

# restore from a snapshot
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\restore-snapshot.ps1 -Snapshot known-good-20260815

# restart the service if it is down
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\restart-service.ps1
```

## How it finds things (no configuration needed)

- **DSH home**: `$env:DSH_HOME` or `%USERPROFILE%\.dsh`
- **dsh launcher**: `$env:DSH_BIN` override, then npx caches under `%LOCALAPPDATA%\npm-cache\_npx`, then `<dsh>\profiles\node_modules`
- **node.exe**: `PATH`, then standard install locations

## Safety rules (read `runbook.md` for the full list)

1. **Never** `pnpm add` random packages into a dsh profile — it can pull duplicated core packages and brick every session.
2. **Never** `insert` a plugin row that is already in `dsh.profile.bundles` (duplicate loader entry).
3. Theme/plugin packages: `main` must be a valid server entry; browser code only via `exports["./client"]` + `dsh.client` metadata. Never point `main` at a browser script.
4. Back up before every change (`backup-config.ps1`), check after (`check-health.ps1`).

## Requirements

- Windows (PowerShell 5.1+, `netstat`, `powershell.exe`)
- Node.js on PATH (only needed for the composed-tree duplicate check and restart)

## Docs

- `runbook.md` — the rules and procedures
- `docs/diagnosis-table.md` — symptom → first check
- `docs/case-study-2026-08-15.md` — the incident that motivated this kit (anonymized)

## License

MIT
