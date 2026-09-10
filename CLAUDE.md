# Cricket v3 — READ THIS FIRST (added 2026-09-08)

**This repo is a spin-off of `cricket-sim` (Cricket v2), not the original.** It was copied with full history on 2026-09-08 so the original can be left alone while this one becomes a different game. The `upstream` remote points at the original for reference and cherry-picking; its push URL is disabled on purpose. Never push to upstream.

## What this game is
A **text-only cricket management game played through Claude Code from Nico's phone.** No graphics. The game is a program that prints stats; Claude Code is the screen and the commentator. Nico manages a team over multiple seasons, saves persist between sessions, and the point is the *feeling of running a team*: picking the XI, watching the table, ageing and replacing players.

Everything below this section (and most of `PROJECT_ROADMAP.md`, `CONTEXT.md`, `docs/`) is **inherited from Cricket v2** and describes the mobile Godot game. Treat it as reference material for the sim, not as instructions for this repo, until this preface is replaced by a proper CLAUDE.md.

## Decisions made so far (grilling session, 2026-09-08)
- Second repo, full history copy, `upstream` = original, read-only. Done.
- Phone workflow = Claude Code cloud sessions only. Nico reviews and merges on the phone.
- "Headless" = the playable text game, not CI. CI comes with it but is not the goal.
- Saves live in git: a play session ends with commit → push → PR → merge, done by Claude. A cloud session can only push its own working branch, so this is the only way a career survives the sandbox.
- The cloud sandbox has Python 3, pip and pytest pre-installed (Ubuntu 24.04, x86_64). Downloading a Godot binary there needs a custom network allowlist plus a setup script.

## Decided by building (2026-09-09 → 2026-09-10)
- **The game is a web app, engine in JavaScript.** `web/` holds the whole thing: `src/engine/` (ball → innings → match, ported from Cricket v2 via the Python port, every tuned coefficient verbatim), `src/game/` (league generator, fixtures, table with NRR, playoffs, stats, save), `src/ui/` (one-file phone UI, no framework). `node build.js` concatenates it into `web/dist/index.html`; `node --test` runs the suite (`web/test/`). Nico opens the built page in Safari and adds it to his home screen (it is a PWA with offline cache).
- **Python is the reference oracle, not the game.** `cricket/` + `pytest -q` stay until the next PR. `web/test/golden.json` (made by `web/tools/make_golden.py`) is a recorded Python rng tape for 40 matches; the JS engine must reproduce every scorecard ball for ball and consume the tape exactly. Once merged, the follow-up PR deletes the Godot tree and the Python package; golden.json stays forever as the regression pin.
- **Hosting: GitHub Pages from this repo.** `.github/workflows/ci.yml` runs pytest + node tests on every PR and deploys `web/dist` on every push to `main`. Nico agreed to make the repo public (free plans cannot serve Pages from a private repo). One-time setup on the phone: Settings → General → change visibility to Public; Settings → Pages → Source: GitHub Actions. The game then lives at `https://nico101rsa.github.io/cricket-v3/`.
- **Saves live in the phone's browser** (localStorage, one JSON with a `version` field and a migrate() chain), with Export/Import text under More. This replaces the "saves live in git" rule: the cloud sandbox cannot see the phone. If a save matters, Nico pastes the export into a session and Claude commits it under `saves/`.
- **Nico never sees attributes.** Only cricket stats (runs, balls, average, SR, wickets, economy, best, last five innings), age, role and pace/spin. `Game.suggestXI` ranks by visible stats only (a test proves changing hidden attributes cannot change the suggestion). AI teams pick with true attributes.
- **The manager's levers (v1):** pick 11 from 15, batting order, five bowlers, and one game plan per match (Cautious / Balanced / Attacking = the intent presets in `src/engine/intent.js`). Bowling rotation is automatic (pace in the powerplay and death, spin in the middle, four overs each, no consecutive overs).
- **League shape:** 10 clubs, 5 from Pretoria and 5 from Sydney, single round robin (45 fixtures, 9 rounds, every team once per round), top four → semis (1v4, 2v3) → final; a tied playoff goes to the higher seed. Hidden team tiers (0.85–1.15), stars and passengers (lognormal quality, sd 0.28), varied squad shapes (6–8 batters, 1–3 all-rounders, ≥2 pace and ≥2 spin) and age profiles. Design check pinned in `web/test/game.test.js`: over six seasons a batter's average correlates r ≥ 0.6 with hidden batting attributes, economy r ≤ −0.5 with bowling.
- **Live match = replay of a pre-simulated match.** `Game.startLive` plays the other four fixtures of the round, simulates the user's match from seed (league seed, season, fixture id) and stores only the replay position; events regenerate deterministically on reload. Replay is wall-clock driven (3 s a ball at 1×, speeds 1/3/10×, skip over/innings/end), so a locked phone catches up. Season rollover: everyone ages a year (form curve peaks 25–31), career stats carry, same squads. Retirements, signings and budgets are the next rungs, one per season, as Nico asked.

## First thing a new session should do
1. `pytest -q` (Python oracle) and `cd web && node --test && node build.js` (53 + 54 tests). Optional: `CHROMIUM_PATH=/opt/pw-browsers/chromium-1194/chrome-linux/chrome node tools/smoke.js` drives the built game in headless Chromium at iPhone size and writes screenshots to `web/tools/shots/` — look at them; unit tests cannot see layout.
2. Read `PROJECT_ROADMAP.md` "Next session" for the current rung. Never change the tuned coefficients in `src/engine/tuning.js` without re-running the golden test and the band tests.
3. Keep the phone-first rules: every screen must fit 390 px, tap targets ≥ 44 px, no fixed-position layout, every stat with its setup (what/N/who).

---

# Cricket v2 — Project Instructions

Mobile roguelite cricket-career game (Reigns × Balatro × management). Engine: **Godot 4.6.3** (Standard build), **GDScript** (not C#). Design source of truth: `CONTEXT.md` + `docs/adr/`. Build plan: `docs/superpowers/plans/2026-06-01-player-creation-plan.md` (the build authority).

## Communication style
- **Lead with a plain-English takeaway.** First 1–2 lines: what happened / what it means, in words Nico (a learner-coder) understands. No jargon dump. Then the detail.
- **Tell him what to look at.** Every wrap-up should point at the one or two things that matter — "look at this", "you don't need to read the rest", "nothing for you to do here". He's said he doesn't always know where to focus; don't make him guess.
- **Define jargon on first use** (file names, function names, cricket-sim terms). Don't assume he tracks the internal vocabulary.
- **Be concise, not terse-to-the-point-of-cryptic.** Short is good; an unreadable wall of technical bullets is not. Cut verbosity, keep clarity. (Applies to chat replies, not spec/ADR/doc prose.)
- **Every stat carries its setup (added 2026-06-12).** A quoted number states % of what / N / who-vs-whom / at what strength+brain, and must be findable on an artefact Nico can open (viz, spec §, log — name it). Tables and viz use plain descriptive labels ("finished top 3 of the table"), not internal shorthand. If two numbers look like they should agree but measure different conditions, reconcile them proactively — he cross-checks.

## Current build
- Everything ships on **`main`** now (Player Creation V1 + real Hall of Fame both merged). Live status, next step, and decisions log are in **`PROJECT_ROADMAP.md`** — read it at session start, not this section.
- **Active work: Theme 7 — the match sim** (ADR 0004), built bottom-up rung by rung: ✅ `resolve_ball()` atom · ✅ single-innings sim · ⏳ next = full match → Intent/KMs → Season wrapper (7b) → balance harness (7c). Each rung is its own brainstorm→spec→plan→build→PR cycle (specs/plans dated under `docs/superpowers/`, interactive design sandboxes under `docs/mockups/`).
- **Execution discipline:** test-first throughout (red via parse-error → green by count climbing → commit). Rungs run **subagent-driven** (implementer → spec review → quality review per task) or inline for tiny doc/test-only slices — Nico finds per-phase stop/start too granular for small phases.
- **Run rungs AFK (autonomous) by default** (set 2026-06-07). For a rung, drive the whole cycle — brainstorm → spec → plan → build → PR-merge → roadmap — on your own without stopping between stages. **Make sensible default decisions yourself and record them in the spec** rather than asking. Only stop to ask Nico when a decision is *genuinely* his to make (irreversible, changes scope/feel, or you truly can't pick a sane default) — and even then, recommend an option and proceed if he's away. This overrides brainstorming's default "one question at a time" interactive pacing. End with a plain-English summary (see Communication style).
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
- **Commit `*.gd.uid` files** — Godot 4.4+ pins each script's stable resource UID there; scenes reference scripts by it. They are not gitignored. **Note: GUT _test_ scripts in `tests/` do NOT generate a `.uid`** — only scripts under `scripts/` do. So `git add tests/unit/test_x.gd.uid` will fail ("pathspec did not match"); add just the `.gd` for test files.
- **Don't name enums/identifiers after built-in Godot classes.** `enum Label` collides with the built-in `Label` node class and breaks `X.Label.*` resolution at parse time — pick a non-colliding name (we use `Kind`).
- **A class-local `enum` type can't be used as a param/field *type* if callers pass the qualified value across the class boundary.** Declaring `var side: Side` / `func make(p_side: Side, …)` in class `Foo`, then calling `Foo.make(Foo.Side.X)` from another script, fails at parse: *"Cannot pass a value of type 'Foo.Side' as 'Side'"* — GDScript treats qualified `Foo.Side` and bare local `Side` as different types. **Fix:** store/type these as plain `int` (enum values *are* ints) while keeping the `enum` for the named constants. (Hit on the jokers slice; `JokerEffect.side/target` are `int`.)
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
- **Oracle/sweep runs longer than ~10 min must be detached with `nohup … > /tmp/log 2>&1 &`** — Claude Code's background Bash tasks are killed at a 10-minute cap (hit 2026-06-11 on the 25-min E2 oracle). Then arm a separate watcher task that greps the log for the final `DATA` line *or* Godot exiting (silence ≠ success). **The watcher must grep the LOG, never `pgrep` the script name — a `pgrep -f sweep_x.gd` inside the watcher matches the watcher's own command line and never fires** (cost an hour, 2026-06-11).
- **Background/cloud sessions leave worktrees under `.claude/worktrees/` that can hold `main`** — then `gh pr merge --delete-branch` / `git checkout main` fails with *"'main' is already used by worktree"*. Check `git worktree list`; if the worktree is CLEAN (`git -C <path> status --short` empty), `git worktree remove <path>` is safe. Related: parallel cloud PRs can land on `main` mid-session (hit 2026-07-04 — PR #116 merged during the T9 rung) — after your own merge, `git pull` and re-run the suite once on the combined state before writing the handoff.
- Test framework is **GUT 9.6**, vendored at `addons/gut/`. The editor's GUT panel reads `.gutconfig.json` (points it at `res://tests/unit`). The in-editor runner opens a small 390×844 window; the reliable pass/fail signal is the editor's bottom-right "0 errors" counter or the terminal summary.

## Shell
- Default shell is **zsh**. Avoid bash-isms: `status` is reserved and `$PIPESTATUS` doesn't exist (zsh uses `$pipestatus`). To gate a commit on tests passing, grep GUT's `All tests passed` line rather than relying on `$?` of a pipeline.
