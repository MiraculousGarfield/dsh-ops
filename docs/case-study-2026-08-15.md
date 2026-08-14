# Case study — 2026-08-15: how a theme install bricked every session (anonymized)

## Timeline

- `00:01` — a session changed `settings.yaml` (default model provider to a community plugin provider).
- `00:02` — a third-party theme package was dropped into `<dsh>/packages/`.
  The package was **malformed**: `package.json` had `"main": "client.js"` — i.e. the server-side entry
  pointed at a browser script whose first line referenced `window`.
- `00:03` — `pnpm add` was run inside the profile. It resolved and installed:
  - the broken theme,
  - several community plugins, and
  - **six core `@deepseek-ai/dsh-*` packages duplicated** into the profile's own `node_modules`
    (same versions, different module instances than the runtime's).
  At the same time, `cordis.patch.yml` re-inserted two packages that were **already in
  `dsh.profile.bundles`** (`modlens`, `dsh-recall`).
- `00:06` — the service repeatedly failed to start. The desktop wrapper's watchdog kept respawning a
  broken server.

## Root causes (in order of severity)

1. **Duplicated core packages** (host-level). The tool registry resolves scheduler instances by
   `Symbol`; with two module instances, the registry lookup returned `undefined` → any tool call from
   **any** session crashed in ~1 ms with `Cannot read properties of undefined (reading 'prepare')`.
   This is why dsh could not diagnose itself: every diagnostic tool was equally broken.
2. **Malformed theme package**: `main` → browser script → `window is not defined` at server load.
3. **Duplicate plugin rows**: same package loaded via bundle and via patch insert.
4. (Minor) corrupt session history with a dangling tool call → API 400s in that session.

## Fix

- Removed the duplicate inserts from `cordis.patch.yml` (kept the theme insert).
- Replaced the broken theme with a working one; removed the bad package from `package.json`.
- Ran `pnpm install` in the profile to prune the duplicated core packages.
- Archived the corrupt session.
- Total cost: roughly half an hour of external tooling work, plus a large amount of tokens — mostly because every attempt to diagnose
  inside dsh crashed instantly, so diagnosis had to be done externally.

## Lessons → what this kit automates

- Host-level failures cannot be diagnosed from inside dsh → standalone, zero-token scripts
  (`check-health.ps1`, `restore-snapshot.ps1`, `restart-service.ps1`, `watchdog.ps1`).
- Duplicate detection should be automatic → `check-health.ps1` scans the composed tree for duplicate
  row ids and the profile `node_modules` for duplicated core packages.
- Recovery must be a 5-minute copy-back, not a debugging session → snapshots + `restore-snapshot.ps1`.
- The rules that would have prevented all of this are in `runbook.md`.
