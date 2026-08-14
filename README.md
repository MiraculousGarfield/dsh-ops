# dsh-ops — Ops Toolkit for DeepSeek Harness

**Version: v1.0.0** · [CHANGELOG](CHANGELOG.md) · [MIT](LICENSE)

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
| `check-health.ps1` | 7 checks: port, HTTP, expected package in boot roster, duplicate row ids in composed tree, core-package duplicates in profile `node_modules`, backup discipline | 0 tokens |
| `backup-config.ps1` | Snapshot profile config (cordis.yml / cordis.patch.yml / package.json / pnpm-workspace.yaml / settings.yaml) + packages list into `<dsh>/backups/<stamp>/` | 0 tokens |
| `restore-snapshot.ps1` | Restore config from a snapshot (with confirmation) | 0 tokens |
| `restart-service.ps1` | Start the dsh service if it is down (auto-detects the launcher) | 0 tokens |
| `watchdog.ps1` | Silent watchdog for scheduled tasks; restarts the service and logs to `<dsh>/backups/watchdog.log` | 0 tokens |
| `runbook.md` | Rules, procedures, and the symptom → first-check table | — |

Double-click friendly `.cmd` wrappers live in `cmd/`.

## Quick start

```powershell
# one-click health check
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-health.ps1

# with a custom profile / port / expected theme package
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-health.ps1 -Profile web -Port 3080 -ExpectTheme dsh-theme-space

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
