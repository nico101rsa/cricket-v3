# Cricket v2 — Project Instructions

Mobile roguelite cricket-career game (Reigns × Balatro × management). Engine: **Godot 4.6.3** (Standard build), **GDScript** (not C#). Design source of truth: `CONTEXT.md` + `docs/adr/`. Build plan: `docs/superpowers/plans/2026-06-01-player-creation-plan.md` (the build authority).

## Current build
- The Player Creation build runs on branch **`player-creation-build`** (NOT `main`). **Phases 0–11 are all COMPLETE** (full flow runnable + manually verified end-to-end, 69 tests green). The branch is **unmerged to `main`** — merge/PR is an open decision. **Next theme is a decision point**: real Hall of Fame screen vs Theme 7 (balance harness).
- Execution was **hybrid**: Phases 0–2 inline, 3–7 subagent-driven (one phase per fresh chat), 8–10 inline (tiny test-only/doc phases batched continuously — Nico finds per-phase stop/start too granular for small phases). Tasks are **test-first**: failing test → red → implement → green → commit — except Phases 8–9, which by design retro-test code already built in Phase 7, so they went green on first run (verification, not red→green).
- `SaveManager` and `LifecycleManager` are registered as **autoloads** in `project.godot` (added in Phases 4 and 7). `scenes/main.tscn` is the entry point (`run/main_scene`); it routes on `SaveManager.has_player()`. Service scripts live in `scripts/services/`, data resources in `scripts/data/`, pure domain logic in `scripts/domain/`, scenes in `scenes/`.

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
- **A `flat` Button + `modulate` draws nothing.** A flat Button has no background, and `modulate` only tints pixels that are actually drawn — so a flat, text-less, icon-less button renders invisibly (this hid the Phase 5 appearance tiles; unit tests passed because they only check the button exists, not that it's visible). For a solid colored tile use a `StyleBoxFlat` (`bg_color` + `add_theme_stylebox_override` per state), not `flat`+`modulate`. **Unit tests can't catch invisibility — always eyeball new UI scenes in a real window.**
- **A `ScrollContainer`'s min size is 0 in its scroll axis — it can collapse and clip all its content.** It expects to scroll, so it contributes ~0 height to a parent `VBoxContainer`; if nothing forces it taller, it renders at 0px and *clips its children invisibly* even though they exist as nodes (this hid the Hall-of-Fame "Earlier Legends" rows). Give it an explicit `custom_minimum_size` height (and/or a guaranteed-tall sibling layout). A scene test asserting `get_child_count()` passes regardless — assert `row.size.y > 0` and `is_visible_in_tree()` to catch it, and still eyeball it.

## Environment / sync hazard
- **This repo lives under `~/Documents/`, which iCloud Drive syncs — it periodically spawns `" 2"` conflict-copy files** (e.g. `utils 2.gd`, `project 2.godot`, a whole shadow `addons/gut/` tree). They are untracked, but Godot's `--import` registers their duplicate `class_name`s and **silently breaks the entire headless GUT run** with errors like *"Class GutUtils hides a global script class."* If a test run suddenly fails to load GUT, suspect this first.
- **Cleanup (safe — these are always untracked junk; git holds the canonical files):**
  ```sh
  find . \( -name "* 2" -o -name "* 2.*" \) -not -path "./.git/*" -delete && rm -rf .godot
  ```
  Then re-run `--import` once. `git ls-files | grep " 2"` should always be empty — if it's not, something real was misnamed; investigate instead of deleting.
- **Only ever run ONE Godot process at a time.** Firing overlapping headless runs (e.g. several backgrounded test commands) corrupts the `.godot` import cache the same way. Chain `--import && <test>` in a single command and wait for it.
- Test framework is **GUT 9.6**, vendored at `addons/gut/`. The editor's GUT panel reads `.gutconfig.json` (points it at `res://tests/unit`). The in-editor runner opens a small 390×844 window; the reliable pass/fail signal is the editor's bottom-right "0 errors" counter or the terminal summary.

## Shell
- Default shell is **zsh**. Avoid bash-isms: `status` is reserved and `$PIPESTATUS` doesn't exist (zsh uses `$pipestatus`). To gate a commit on tests passing, grep GUT's `All tests passed` line rather than relying on `$?` of a pipeline.
