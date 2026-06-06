# Cricket v2 — Project Instructions

Mobile roguelite cricket-career game (Reigns × Balatro × management). Engine: **Godot 4.6.3** (Standard build), **GDScript** (not C#). Design source of truth: `CONTEXT.md` + `docs/adr/`. Build plan: `docs/superpowers/plans/2026-06-01-player-creation-plan.md` (the build authority).

## Communication style
- **Be extremely concise.** Terse bullets, sentence fragments fine. Sacrifice grammar for concision. No preamble/recap unless asked. (Applies to chat replies, not spec/ADR/doc prose.)

## Current build
- Everything ships on **`main`** now (Player Creation V1 + real Hall of Fame both merged). Live status, next step, and decisions log are in **`PROJECT_ROADMAP.md`** — read it at session start, not this section.
- **Active work: Theme 7 — the match sim** (ADR 0004), built bottom-up rung by rung: ✅ `resolve_ball()` atom · ✅ single-innings sim · ⏳ next = full match → Intent/KMs → Season wrapper (7b) → balance harness (7c). Each rung is its own brainstorm→spec→plan→build→PR cycle (specs/plans dated under `docs/superpowers/`, interactive design sandboxes under `docs/mockups/`).
- **Execution discipline:** test-first throughout (red via parse-error → green by count climbing → commit). Rungs run **subagent-driven** (implementer → spec review → quality review per task) or inline for tiny doc/test-only slices — Nico finds per-phase stop/start too granular for small phases.
- **Layout:** pure domain logic in `scripts/domain/`, data resources in `scripts/data/`, services in `scripts/services/`, scenes in `scenes/`. `SaveManager` + `LifecycleManager` are autoloads in `project.godot`; `scenes/main.tscn` is the entry point (routes on `SaveManager.has_player()`).

## Godot / GDScript conventions
- **Godot binary is not on PATH.** Use the full path: `/Applications/Godot.app/Contents/MacOS/Godot`
- **Run the test suite (headless):**
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- **After adding or renaming any script, run `--import` once before running tests:**
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
  This registers `class_name`s (GUT's and your own) in Godot's global cache. It's required in any fresh clone or git worktree (no `.godot/` yet), or GUT fails with *"class_names have not been imported"*.
- **NEVER run headless Godot while the Godot editor is open** — two instances importing the same project at once deadlock. Quit the editor (⌘Q) first.
- **The GUT `-gtest=res://…` flag does NOT filter to one file here** — with `.gutconfig.json` pointing at `-gdir=res://tests/unit`, a run executes the *whole* suite regardless of `-gtest`. So a red→green TDD loop can't lean on per-file runs: a not-yet-implemented `class_name` shows up as a **`SCRIPT ERROR: Parse Error: Identifier "X" not declared`** (GUT logs it and silently skips that test file), not as a failing assertion. Judge **red** by that parse error; judge **green** by the total test count climbing and `All tests passed`. The full suite runs in <1s, so just run `-gdir=res://tests/unit` every step.
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
