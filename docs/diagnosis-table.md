# Diagnosis table — symptom → first check

| Symptom | Check this first |
|---|---|
| `duplicate loader entry id: X` | Is X both in `dsh.profile.bundles` and inserted in `cordis.patch.yml`? Remove the duplicate insert |
| Service won't boot + `window is not defined` / ReferenceError | A package's `main` points at a browser script; fix the package shape |
| Every tool crashes in ~1 ms with `prepare` / undefined | Core package duplication: `profiles/<profile>/node_modules/.pnpm` contains `@deepseek-ai+dsh-*` entries; prune them |
| Session returns 400 / dangling tool call | Session history is corrupt → start a new session; stop pasting errors into the broken one |
| App shortcut opens nothing | Check the port first (`check-health.ps1`), then the rows above |
| Page loads but the theme is missing | Check the boot roster for your theme package (`check-health.ps1 -ExpectTheme <pkg>`) |
| Health check itself fails to find the launcher | Set `DSH_BIN` to the dsh `bin.js` path or install dsh so it lands in the npx cache |

All of the machine-readable checks are automated in `check-health.ps1`.
