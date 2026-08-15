# dsh-ops Runbook

> Purpose: let anyone (human or AI) **locate a problem in one minute and recover in five**,
> without burning hours and tokens re-diagnosing from scratch.

## 1. Iron rules (breaking any of these = incident)

1. **Never edit `profiles/<profile>/cordis.yml`** — it is a stub; the plugin tree is composed from patches.
2. **Never run `pnpm add <package>` inside a dsh profile.** This is the #1 root cause of the worst incident:
   it can resolve duplicated core `@deepseek-ai/dsh-*` packages into the profile's own `node_modules`,
   causing module duplication, mismatched `Symbol`s and a 1 ms crash of **every** tool in **every** session
   (`scheduler.prepare is undefined`). The correct way to install: put the package under
   `<dsh>/profiles/node_modules/` (or `<dsh>/packages/`) and add one `insert` row in `cordis.patch.yml`.
   You usually do **not** need to touch `package.json` dependencies.
3. **Check for duplicates before inserting**: if a package is already in `dsh.profile.bundles`
   (`package.json`), do NOT `insert` it again (duplicate loader entry id). To change its config, use an
   **id-targeted override** (`- id: <existing row id>` + `config:`), not an insert.
4. **Theme/plugin package shape** (reference: any working theme): `main` must be a valid server-side
   entry (or absent); browser code is exposed only through `exports["./client"]` + `dsh.client` metadata.
   **Never point `main` at a browser script** (`window is not defined` → server crashes on boot).
5. **After any config change, before restarting the service**: run `check-health.ps1`; restart only when green.
6. **Back up before any change**: `backup-config.ps1` (snapshot into `<dsh>/backups/<stamp>/`).
7. **Once a bundle is registered** (`dsh.profile.bundles` in `package.json`), **never delete the package
   directory from node_modules while the bundle line remains.** A registered-but-missing bundle makes the
   service refuse to boot (`cannot resolve profile bundle`). Remove the bundle line / dependency first,
   then the package — never the reverse.
8. **After every confirmed-healthy state, refresh the known-good snapshot**:
   `backup-config.ps1 -Name known-good-<date>`. Restoring an outdated known-good silently drops every
   later correct change (the 2026-08-16 lesson: restore lost a working theme + Tailscale config).

## 2. Standard procedures

### Install a theme / plugin (correct way)
1. `backup-config.ps1`
2. Put the package at `<dsh>/profiles/node_modules/<name>/` (or `<dsh>/packages/<name>/`)
3. Check `package.json` bundles — never re-insert an already bundled package
4. Add an `insert` row in `cordis.patch.yml` (unique id, `name:` the package name)
5. `check-health.ps1` — the composed tree must show the package exactly once, no duplicate ids
6. Restart the service and verify

### Recover (5-minute plan)
1. `cmd\fix-service.cmd` — **smart one-click rollback (preferred)**: restores snapshots
   newest-first (auto-* from watch-config, then known-good-auto, then dated known-good),
   restarting + health-checking each one, stopping at the first green state — this keeps
   as much recent work as possible instead of dropping everything since the last green run.
2. `cmd\restore-known-good.cmd` — fast fallback straight to the latest green baseline
   (drops intermediate changes; use when you know you just broke it).
3. If core packages were duplicated inside the profile `node_modules`: run `pnpm install` in the profile
   dir to prune (it follows `package.json`), or remove the extra entries
4. Repeat until green; when green, the check-health auto-refresh keeps known-good-auto current
   (no manual snapshot step needed).

## 3. Escape hatch: when EVERY dsh session is dead (0 tokens)

**Key fact**: duplicated core packages are a **host-level** failure — every dsh session's tools crash in ~1 ms,
so **dsh can never diagnose this class of problem itself**. Do NOT open dsh sessions to investigate.
Use the standalone scripts directly (double-click the `.cmd` wrappers or run the `.ps1` files):

1. `cmd\health-check.cmd` — 10-second health check (no AI, 0 tokens)
2. Map the output against `docs/diagnosis-table.md`
3. `cmd\restore-snapshot.cmd` — restore a known-good snapshot (confirmation prompt)
4. `cmd\restart-server.cmd` — restart the service
5. Only if still red after all of the above: hand an external tool (Codex, etc.) this runbook —
   it should finish in minutes instead of hours.

## 4. Template for AI sessions (token saver)

> Read `runbook.md` first. Before ANY config change run `backup-config.ps1`; run `check-health.ps1`
> for diagnosis instead of exploring from scratch. **If a tool crashes in ~1 ms with
> `prepare` / undefined: stop diagnosing inside dsh immediately** — ask the user to run the standalone
> scripts (section 3), and only use external tooling if those fail.
