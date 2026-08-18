# Local sync manifest: `priv/design_sync/manifest.json`

The manifest is the skill's only state in the target Phoenix app. It makes re-runs incremental
(diff upstream hashes against what was last synced) and makes local drift detectable (sha256 of every
file the skill wrote, as it wrote it). It is versioned with the app — commit it.

All identifiers below are placeholders from a fictional "Nimbus" design system.

## Schema

```json
{
  "version": 1,
  "projectId": "00000000-0000-0000-0000-000000000000",
  "projectName": "Nimbus Design System",
  "syncedAt": "2026-01-01T12:00:00Z",
  "groups": ["core-ui"],
  "styleSha": "f0e1d2c3…",
  "styleTargets": [
    "assets/css/design_system/design_system.css",
    "assets/css/design_system/fonts.css"
  ],
  "components": {
    "core-ui/Button": {
      "sourceHashes": { "jsx": "a1b2c3d4e5f6", "dts": "0f1e2d3c4b5a", "prompt": "9988aabbccdd" },
      "targetFile": "lib/my_app_web/components/design_system/core_ui.ex",
      "function": "button",
      "status": "generated",
      "todos": []
    },
    "core-ui/ThemeToggle": {
      "sourceHashes": { "jsx": "c3d4e5f6a1b2", "dts": "2d3c4b5a0f1e", "prompt": "7766ccddeeff" },
      "targetFile": "lib/my_app_web/components/design_system/core_ui.ex",
      "function": "theme_toggle",
      "status": "partial",
      "todos": ["implement DsThemeToggle JS hook (flips the theme data attribute)"]
    }
  },
  "fileShas": {
    "lib/my_app_web/components/design_system/core_ui.ex": "3f2a…(sha256 hex)",
    "lib/my_app_web/live/design_system_preview_live.ex": "9c81…",
    "assets/css/design_system/design_system.css": "77aa…"
  }
}
```

### Field semantics

| Field | Meaning |
|---|---|
| `projectId` | Claude Design project this app syncs from. One project per app. |
| `groups` | Component groups the user chose to sync (e.g. `core-ui`). Components outside these groups are ignored entirely — they are not "removed", just unsynced. |
| `styleSha` | Upstream `_ds_sync.json` `styleSha` at last sync. Differs ⇒ re-copy CSS. |
| `styleTargets` | CSS/font files the style pipeline wrote (also present in `fileShas`). |
| `components` | Keyed `"<group>/<Name>"` matching upstream `components/<group>/<Name>/` paths. |
| `sourceHashes` | The three upstream per-file hashes from `_ds_sync.json` `sourceHashes` (`.jsx`, `.d.ts`, `.prompt.md`) at last sync. Any difference ⇒ component is `changed`. |
| `function` | Generated HEEx function name (snake_case) inside `targetFile`. |
| `status` | `generated` (clean translation) \| `partial` (compiles, but behavior stubbed or markup unverified — see `todos`) \| `skipped` (tracked upstream but intentionally not generated, `targetFile: null` — e.g. an app-specific form generator) \| `orphaned` (removed upstream, user chose to keep local copy). |
| `todos` | Human-actionable follow-ups; re-surfaced in every sync report while non-empty. |
| `fileShas` | sha256 (lowercase hex) of each generated file **exactly as the skill last wrote it**. Current content differing ⇒ the user hand-edited it (`drifted`) ⇒ never overwrite without asking. Recomputed at the end of every sync. |

## Drift semantics

- **Upstream drift** (design changed on claude.ai/design): detected via `sourceHashes`/`styleSha`
  diff → component listed as `changed`; sync regenerates it.
- **Local drift** (user edited a generated file): detected via `fileShas` → file listed in `drifted`;
  the skill shows a diff and asks overwrite/skip/abort per file. On *skip*, the recorded
  `fileShas` entry is left stale on purpose so the file keeps warning on future runs.
- A `fileShas` path that no longer exists on disk is drift too (reported with `"reason": "missing"`);
  regeneration recreates it after confirmation.
- `mix format` reflows generated files — always run it **before** computing `fileShas`, or every
  re-run reports phantom drift.

## Diffing

`scripts/diff_manifest.exs` compares the manifest against a freshly fetched upstream `_ds_sync.json`
and prints a single JSON object to stdout (all lists sorted, keys `"<group>/<Name>"`):

```sh
elixir scripts/diff_manifest.exs priv/design_sync/manifest.json /tmp/ds_sync.json [app_root]
```

```json
{
  "first_run": false,
  "style_changed": false,
  "added": ["core-ui/NewThing"],
  "changed": ["core-ui/Button"],
  "removed": ["core-ui/OldThing"],
  "drifted": [{ "path": "lib/…/core_ui.ex", "reason": "modified" }],
  "unchanged": 18,
  "upstream_components": { "core-ui/Button": { "jsx": "…", "dts": "…", "prompt": "…" }, "…": {} }
}
```

- Pass `-` as the manifest path (or a nonexistent path) on first run: everything upstream is `added`.
- The script reports **all** upstream components; group/component filtering is applied by the skill,
  not the script (so `upstream_components` doubles as the fetch worklist and provides the fresh
  hashes to record in the manifest after each component syncs).
- `app_root` (default `.`) is the base for resolving `fileShas` paths when computing drift.
