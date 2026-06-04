# Cricket v2 — Project Instructions

Mobile roguelite cricket-career game (Reigns × Balatro × management). Engine: **Godot 4.6.3** (Standard build), **GDScript** (not C#). Design source of truth: `CONTEXT.md` + `docs/adr/`. Build plan: `docs/superpowers/plans/2026-06-01-player-creation-plan.md` (the build authority).

## Current build
- The Player Creation build runs on branch **`player-creation-build`** (NOT `main`). Phases 0–4 are done; **Phase 5 (Screen 1: Identity — first UI phase) is next**.
- Execution is **subagent-driven from Phase 3** (Phases 0–2 were inline). Every task is **test-first**: write a failing test → run it red → implement → run it green → commit.
- `SaveManager` is registered as an **autoload** in `project.godot` (added in Phase 4). Service scripts live in `scripts/services/`, data resources in `scripts/data/`, pure domain logic in `scripts/domain/`.

## Godot / GDScript conventions
- **Godot binary is not on PATH.** Use the full path: `/Applications/Godot.app/Contents/MacOS/Godot`
- **Run the test suite (headless):**
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **After adding or renaming any script, run `--import` once before running tests:**
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
  This registers `class_name`s (GUT's and your own) in Godot's global cache. It's required in any fresh clone or git worktree (no `.godot/` yet), or GUT fails with *"class_names have not been imported"*.
- **NEVER run headless Godot while the Godot editor is open** — two instances importing the same project at once deadlock. Quit the editor (⌘Q) first.
- **Indentation is tabs** in `.gd` files.
- **Commit `*.gd.uid` files** — Godot 4.4+ pins each script's stable resource UID there; scenes reference scripts by it. They are not gitignored.
- **Don't name enums/identifiers after built-in Godot classes.** `enum Label` collides with the built-in `Label` node class and breaks `X.Label.*` resolution at parse time — pick a non-colliding name (we use `Kind`).
- Test framework is **GUT 9.6**, vendored at `addons/gut/`. The editor's GUT panel reads `.gutconfig.json` (points it at `res://tests/unit`). The in-editor runner opens a small 390×844 window; the reliable pass/fail signal is the editor's bottom-right "0 errors" counter or the terminal summary.

## Shell
- Default shell is **zsh**. Avoid bash-isms: `status` is reserved and `$PIPESTATUS` doesn't exist (zsh uses `$pipestatus`). To gate a commit on tests passing, grep GUT's `All tests passed` line rather than relying on `$?` of a pipeline.
