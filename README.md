# phoenix-claude-design

A Claude Code skill that pulls a [claude.ai/design](https://claude.ai/design) design system into an
Elixir Phoenix application: it generates HEEx function components from the design system's React
components and wires the design tokens/CSS into the Phoenix asset pipeline.

**Direction: pull only.** Claude Design is the source of truth. The skill never writes back to the
design project.

## What it does

Running `/phoenix-design-sync` inside any Phoenix app:

1. Lets you pick one of your Claude Design design-system projects (first run) and which component
   groups to sync.
2. Fetches the project's `_ds_sync.json` and diffs it against a local manifest
   (`priv/design_sync/manifest.json`) — re-runs are incremental and only touch changed components.
3. Copies the design system CSS (tokens + component classes) and fonts into `assets/css/design_system/`
   and `priv/static/fonts/design_system/`.
4. Translates each component's props contract (`.d.ts`) and rendered markup into a HEEx function
   component with proper `attr`/`slot` declarations, generated into
   `lib/<app>_web/components/design_system/<group>.ex`.
5. Generates a `/dev/design-system` preview LiveView (dev-only route) rendering every variant, so you
   can eyeball the result against the claude.ai/design previews.
6. Verifies with `mix compile --warnings-as-errors` and reports what synced cleanly, what needs a JS
   hook, and what it refused to overwrite because you hand-edited it.

## Install

```sh
./install.sh          # symlinks skills/phoenix-design-sync into ~/.claude/skills/
```

The symlink makes the skill available in every Claude Code session, for any project. To pin the skill
to a single project instead, copy the directory:

```sh
cp -R skills/phoenix-design-sync /path/to/your_app/.claude/skills/
```

Then, inside your Phoenix app, run Claude Code and invoke `/phoenix-design-sync`.

## Requirements

- Claude Code with a claude.ai login that can access your design projects (the built-in `DesignSync`
  tool handles auth; the first call may prompt to grant design-system access).
- Elixir ≥ 1.14 with your Phoenix app compiling (Elixir ≥ 1.18 preferred; older versions fall back to
  `Mix.install([:jason])` for the diff script).
- Phoenix 1.7+ (Phoenix 1.8 / Tailwind v4 is the primary target; Tailwind v3 apps are supported).

## Repo layout

```
skills/phoenix-design-sync/
├── SKILL.md                    # the sync procedure Claude follows
├── references/
│   ├── translation-guide.md    # React/.d.ts → HEEx translation rules + worked examples
│   ├── token-pipeline.md       # CSS/fonts → Phoenix asset pipeline
│   ├── manifest-format.md      # local manifest schema, incremental sync + drift semantics
│   └── preview-page.md         # /dev/design-system preview LiveView template
└── scripts/
    └── diff_manifest.exs       # deterministic upstream-vs-local hash diff
```

## Development

The skill is developed in this repo and tested against a throwaway Phoenix app in `tmp/testbed/`
(gitignored). Because the install is a symlink, edits to `skills/phoenix-design-sync/` take effect
immediately in any session using the skill.
