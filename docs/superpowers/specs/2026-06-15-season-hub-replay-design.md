# Season Hub — scrubbable replay (first presentation slice)

**Date:** 2026-06-15 · **Branch:** `season-hub-replay` · **Theme:** 2 (Presentation / playable career — first rung)

## 1. Plain-English goal

Build the first real, on-screen career screen: the **Season Hub** from the Theme-5 hi-fi
(`docs/mockups/around-the-match-v1.html` §1), wired to a **genuinely simulated season** and made
**scrubbable** — step match-by-match through the season and watch your results and your stat card fill
in. One screen, done right, every panel truthful. This is the bridge from the headless career (which
runs entirely in code today) to something Nico can open in a Godot window and look at.

This rung does **not** make matches playable. The match still resolves via the existing sim; the Player's
interaction here is *scrubbing the replay*. The "Play a match" screen is the next rung.

## 2. Scope decisions (asked & answered with Nico, 2026-06-15)

- **First slice = "Season Hub, deeply"** — one screen, faithful to the hi-fi, wired to live season data;
  matches resolve via placeholder (Nico's call).
- **Hub moment = "Season replay you can scrub"** (Nico's call) — run a real season up-front; the hub shows a
  snapshot at match N (results 1..N filled in, rest pending); a scrub control advances N.
- Rejected at brainstorm: *season-start static render* (too inert — can't "run" anything) and *true live
  mid-season standings + resumable state* (that's the next-rung machine; out of scope here).

## 3. The clean seam (architecture)

The UI must never call resolvers directly. One read-model sits between the headless game and the scene.

| Unit | File | Kind | Responsibility |
|---|---|---|---|
| **`SeasonView`** | `scripts/data/season_view.gd` | `RefCounted` (transient, not persisted) | The read-model. Holds *everything the hub renders* as plain typed fields. No node, no resolver deps. |
| **`SeasonViewBuilder`** | `scripts/domain/season_view_builder.gd` | pure static | `build(player, career_state, season_result, scrub_index) -> SeasonView`. Folds the Player's real per-match lines into running totals. Fully unit-testable, no UI, no RNG. |
| **`SeasonHub`** | `scenes/season_hub/season_hub.{gd,tscn}` | `Control` scene (replaces `scenes/stubs/season_hub_stub.tscn`) | Renders a `SeasonView` faithful to the hi-fi. Scrub control sets `scrub_index` → rebuild → re-render. |

**Data flow:** `Player` + `CareerState` + a real `SeasonResult` (from `SeasonResolver.simulate_season`,
seeded) → `SeasonViewBuilder.build()` → `SeasonView` → hub renders. Scrub changes `scrub_index` → rebuild
the card stats → re-render. No resolver changes anywhere → **zero ledger / balance risk by construction**.

## 4. `SeasonView` fields (the read-model contract)

Grouped by hub panel. Each field is plain data the scene reads; the builder fills them.

- **Context:** `level: int`, `tour: int`, `tour_name: String`, `difficulty_label: String`, `country: int`,
  `team_name: String`, `team_stars: float`.
- **Player snapshot:** `player_name: String`, `city: String`, `form: int`, `appearance: int`,
  `power/composure/attack/control: float`, `ovr: int` (derived, §6).
- **Wallet / loyalty:** `tons_balance: int`, `affinity: int`. (Both live off the `Player` resource.)
- **Fixtures chain** (`fixtures: Array` of typed dicts, one per league game, in order): `{opponent_name,
  opponent_stars, played: bool, player_won: bool, margin_text: String, score_text: String}`. `played` is
  `index < scrub_index`.
- **Final standings** (`standings: Array` of `{team_name, played, won, points, nrr, is_player}`, ranked):
  the season's **final** league table, labeled "Final" in the UI (§5). `player_final_position: int`.
- **Jokers** (`jokers: Array` of `{id, name, rarity}`): owned this season. This slice = the starting
  joker (career start) / `carryover_joker_id` if present. (Mid-season Shop acquisitions are a later rung.)
- **Scrub:** `scrub_index: int` (0..7; 0 = before match 1, 7 = whole league done), `match_count: int` (=7).
- **Career card** (folded over `season_result.league.player_matches[0 .. scrub_index-1]`, §6):
  `card_matches, card_runs, card_balls_faced, card_dismissals, card_high_score, card_strike_rate: float,
  card_batting_avg: float, card_wickets, card_runs_conceded, card_balls_bowled, card_economy: float,
  card_best_bowling: String` (e.g. `3/24`).

## 5. The hub scene (faithful to the hi-fi)

Reproduce `around-the-match-v1.html` §1 layout in Godot, country-aware:

- **Header chrome** — country gradient (SA default / AUS swap per ADR 0001, DESIGN_HANDOFF §16.2),
  gear + info corner controls (present, may be inert this slice), the **₸ Tons balance chip**.
- **Fixtures chain** — the 7 league games as a horizontal/vertical chain; played games show W/L + score,
  pending games greyed; the *current* position (the scrub head) is marked.
- **Player card** — illustrated portrait (expression encodes Form), the 4-attribute strip, and the **cricket
  career stat strip** (matches, avg, SR, best figures, wickets, OVR) folded from the replay.
- **Jokers bench** (§16.7) — owned jokers, rarity-colored (white/blue/gold).
- **Affinity / next-reward strip** — surfaces `affinity`.
- **League table panel** — secondary/collapsed, the Player row highlighted, **labeled "Final" with its
  provenance clear** (it is the season's finishing table, *not* a fabricated mid-season ladder).
- **Play CTA** — a placeholder button (no match screen yet; tapping shows a "coming soon" state or is
  disabled). **The scrub control is the real interaction.**
- **Scrub control** (SH-default) — a prev/next stepper + "Match N of 7" readout; tapping a fixture jumps
  the scrub head to it. (A drag slider is an acceptable substitute.)

The Retire button + dev win-out cheat currently on the stub move onto a dev/debug affordance so the
`LifecycleManager` hooks survive (they're still needed until the real lifecycle UI lands).

## 6. Folding the career card (the one piece of real logic)

Pure, in `SeasonViewBuilder`, over `league.player_matches[0 .. scrub_index-1]`. For each `MatchResult`:

- **Batting** — the Player's innings is `innings1` if `player_bats_first` else `innings2`; read its
  `player_line()` → `{runs, balls, out}`. Accumulate `card_runs += runs`, `card_balls_faced += balls`,
  `card_matches += 1`, `card_dismissals += (1 if out else 0)`, `card_high_score = max(...)`.
- **Bowling** — sum `player_bowl_wickets/runs/balls` across *both* innings of the match (only the bowling
  innings is non-zero). Track `card_best_bowling` = the match maximising wickets, tiebreak fewest runs.
- **Derived** — `card_batting_avg = card_runs / max(card_dismissals, 1)` (label as "not out" aware; if
  `card_dismissals == 0`, show `card_runs` with a `*`). `card_strike_rate = 100 * card_runs /
  max(card_balls_faced, 1)`. `card_economy = card_runs_conceded / max(card_balls_bowled/6.0, 1)`.
- **OVR** — `round((power + composure + attack + control) / 4.0)` on the /100 card scale. Simple,
  honest, label "OVR". (A weighted role-aware OVR is a later polish, not this rung.)

At `scrub_index == 0` the card is genuinely empty — show em-dashes, not zeros-as-data (provenance rule:
never render absence as a real number).

## 7. Boot (where the season comes from, this slice)

`SeasonHub` boots a real season for the saved Player:

1. If `SaveManager.has_career()` → use the saved `CareerState`; else `CareerResolver.start_career(0)` a
   default (so the screen always has a valid cell to simulate). *(The current router reaches the hub via
   the starting-team stub, which may not persist a real CareerState — the hub tolerates either.)*
2. Build the cell's `TourSpec` + opponents (`CareerState.opponents_of_current()`,
   `DifficultyLadder.spec_for`), call `SeasonResolver.simulate_season(...)` once with a **dev seed**
   (a re-roll control so Nico can cycle seasons while eyeballing).
3. `SeasonViewBuilder.build(player, career_state, season_result, scrub_index)`; **boot at `scrub_index = 0`**
   (empty card, all fixtures pending) so the natural interaction is *play the season forward* via the
   stepper; scrubbing back/forward replays it. (Nico can veto to boot at 7 = full season shown.)

No resumable season-state, no persistence of the simulated season, no resolver changes.

## 8. Testing

- **`SeasonViewBuilder` unit tests** (GUT, `tests/unit/test_season_view_builder.gd`): fixtures chain length
  (7) + order + `played` flips at `scrub_index`; result lines match `player_matches`; card folds correctly
  at `scrub_index` 0 / mid / 7 (avg = runs/dismissals, SR, best-bowling selection, HS); `tons_balance` /
  `affinity` / context passthrough; `scrub_index == 0` ⇒ empty card sentinels.
- **Hub scene smoke test** (`tests/unit/test_season_hub.gd`): instantiate with a built `SeasonView`; assert
  key nodes exist, are `is_visible_in_tree()`, and have `size.y > 0` (per the `ScrollContainer`/`flat`-Button
  invisibility gotchas in CLAUDE.md — `get_child_count()` alone is not enough).
- **Mandatory manual eyeball** in a real Godot window (unit tests can't catch invisibility) + a **screenshot
  for Nico** (he learns by seeing). Verify the country swap, the scrub, the card filling in.

## 9. Out of scope (named — each its own later rung)

Real Play → match screen (the in-match hi-fi / `playable-prototype.html`) · true live mid-season standings +
resumable season-state · Shop (Kit Room) / Offer / Career Grid screens · mid-season joker acquisition on the
bench · cross-season career-stat *persistence* (this slice folds within one season's replay) ·
splash/resume routing changes · gear/info corner-control behaviour · the economy pay-spread reconciliation
(Nico is doing economy in a separate session).

## 10. Findings / deltas (end of rung)

**Built & green: 580 tests** (was 566; +14: 2 `SeasonView`, 9 `SeasonViewBuilder`, 3 `season_hub` scene). No new orphans. Zero resolver/tuning files touched ⇒ ledger untouched by construction (env/joker/build/pay all unaffected — not re-run, can't have moved).

**Screenshot (the deliverable):** `docs/mockups/season-hub-built-v1.png` — a seed-20260615 Club season, scrubbed to Match 4 of 7. Everything on it is real folded data: Karoo Kings vs 7 named opponents, WON/LOST score lines, the ▶ scrub head at Match 5, the player card (4 inns · 10.5 avg · SR 135.5 · best 0/8 · OVR 26 — folded from the actual match lines), the FINAL TABLE with Karoo Kings highlighted 6th, "Match 4 / 7" scrubber. Regenerate with `tools/preview_season_hub.gd` (run **with** rendering, not headless).

**Batching vs the plan:** Tasks 2–6 (builder) were written as one cohesive file + one test file (the fold logic is interdependent); Tasks 7–9 (scene) likewise. Net behaviour identical to the plan; fewer commits.

**Deltas from the plan:**
- **Boot is explicit, not `_ready`-auto.** A `SceneTree -s` preview proved `@onready` refs aren't resolved when you inject in `_initialize`; more importantly, auto-booting in `_ready` would fire a real-season sim (and read the save file) during scene tests. So `boot()` is a public method the router calls after mounting (`main._push_hub()`), and the preview/tests inject via `set_source`/`set_view`. Cleaner and save-safe.
- **GDScript gotcha:** a ternary assigned with `:=` can't be type-inferred (`Cannot infer the type of "rr_for"`); needs an explicit `var x: float = (...) if c else y`. (Hit on the NRR lines.)
- **Title shows team name only** (not "Team · Country") — the country accent colour carries the locale; keeps the ₸ chip from being pushed off-screen.

**Known cosmetic polish (deferred to the art/margin-parity rung, per §-scope "structural not pixel-perfect"):**
- A ~16px right-edge clip trims the ₸ chip ("₸ 180" → "₸ 18") and a thin left inset — the `MarginContainer` insets aren't visually landing in the preview window. Functional, not faithful; fold into the hi-fi styling pass.
- Portraits/rarity-glow/gradient chrome are approximated (solid colours / text) — art parity is its own rung (§ visual-fidelity scope).
- "best 0/8" shows for a non-bowling build (0 wickets, fewest runs) — honest but reads oddly; a "did-not-bowl" sentinel is a nicety for later.

**Next rung options (handoff):** the playable **Play → match screen** (the in-match hi-fi), or **true live mid-season** standings + resumable season-state (turns the scrub into a real forward-play), or the **art/margin hi-fi pass** on this hub. Seams in place: `SeasonView` (read-model), `SeasonViewBuilder.build(player, career, season, scrub_index)` (pure fold), `scenes/season_hub/` (`set_view`/`set_source`/`boot`/`step`), `tools/preview_season_hub.gd` (visual harness).
