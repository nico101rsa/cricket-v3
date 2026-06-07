# Full-match sim — design spec

**Date:** 2026-06-07
**Theme:** 7a (Tech foundation → match sim core), rung 3 of 4 (ball → innings → **match** → Intent/KMs)
**Status:** Approved (design shape) — ready for `writing-plans`
**Builds on:** `InningsResolver.simulate_innings()` (spec `2026-06-07-innings-sim-design.md`)
**Implements:** ADR 0004 (auto-sim architecture — headless, deterministic-seedable, only-Player-statted)

---

## 1. Scope

One new pure domain class that simulates **a complete T20 match** — two innings plus a result — by calling the existing single-innings resolver twice and comparing. This is rung 3 of the bottom-up match sim: it turns one innings into a full match with a winner and a margin.

This is the **thinnest viable wrapper** (the "simplest-first" option). It deliberately keeps the existing constant-bowling interface and raw-int inputs; the richer Team-based interface and real bowler rotation arrive at later rungs.

**In scope:**
- A second innings (the opposition bats; all 11 derived, no statted Player).
- A **chase**: the second innings carries a `target` and ends early when it is reached.
- Result decision: win-by-runs / win-by-wickets / tie, the way cricket reports it.
- A `MatchResult` holder with both innings, the outcome, the margin, and Player-perspective accessors.
- Two small additive changes to `simulate_innings()` to support the above (optional Player; optional target).

**Out of scope (deferred to later rungs, do not build here):**
- **Real bowler rotation.** Each batting innings still faces a single constant `(attack, control)` pair. Per-over rotation — Player-side via the **Bowling Change Key Moment**, opponent-side via an AI rotation policy — lands at the next rung (Intent/KMs). Per-over bowler *profiles* (death-over specialists) are later harness-driven polish (7c) if needed.
- **The Player as a bowler.** The Player is statted on the **bat only**. When the opposition bats they face the Player's team's constant bowling pair; the Player's own Attack/Control is not individually simulated this rung. (Bowling-side participation is settled here as: not modelled in V1; arrives with the Bowling Change KM.)
- **The `stars → batting/attack/control → numbers` pipeline.** `simulate_match()` takes the derived numbers as **inputs** (raw ints), exactly as `simulate_innings()` and `resolve_ball()` take their numbers raw. The Team-instantiation seam belongs to the Season wrapper (7b).
- **The toss as flavour.** Who bats first is a caller-supplied bool, not a simulated coin-flip. The Season wrapper decides/ randomises it later.
- Intent (fixed **Balanced** every ball), Form, Jokers, Manager Boost, conditions, extras, run-outs, Super Overs — all still off.

## 2. The contract

A pure function — no scene tree, no member state, no I/O. Lives at `scripts/domain/match_resolver.gd` (project convention for pure domain logic).

```
MatchResolver.simulate_match(
    player_attrs: Attributes,        # the statted batter (Player's team, with the bat)
    player_team_batting: int,        # Player's team derived batting strength (partners)
    player_team_attack: int,         # Player's team bowling Attack (constant pair)
    player_team_control: int,        # Player's team bowling Control
    opp_batting: int,                # opposition derived batting strength (all 11)
    opp_attack: int,                 # opposition bowling Attack (constant pair)
    opp_control: int,                # opposition bowling Control
    player_bats_first: bool,         # caller-supplied toss outcome
    tuning: BallTuning,              # existing ball coefficients
    innings_tuning: InningsTuning,   # existing innings coefficients (reused, no new resource)
    rng: RandomNumberGenerator
) -> MatchResult
```

**Flat param list** (each value its own argument, no new bundling type) — mirrors `simulate_innings()` / `resolve_ball()`. The tidier Team-based bundled interface is deferred with the star→numbers pipeline (7b).

**Determinism:** the match is deterministic-seedable (ADR 0004). It consumes `rng` only through the two innings (each of which consumes it only through `resolve_ball`, fixed draw order). Same inputs + same seed → identical `MatchResult`. This is what lets the future balance harness re-run thousands of matches.

**No new tuning resource** — reuses `BallTuning` + `InningsTuning`.

## 3. Two additive changes to `simulate_innings()`

The existing resolver gains two backward-compatible extensions; the rung-2 behaviour is unchanged when the new options are at their defaults.

1. **Optional Player.** `player_attrs` may be `null`. When `null`, all 11 batters are derived from the batting-strength int (reusing the existing tail curve); no statted Player is inserted, and `player_line()` returns `{}` (already its documented empty case). This serves the opposition innings.
2. **Optional target (the chase).** A new trailing param `target: int = 0`. When `target > 0`, the innings gains a **third stop condition**: the loop ends the instant `total >= target`. `target = 0` (default) = first innings, no chase — identical to rung-2 behaviour.

The existing termination conditions (10 wickets, 120 balls) are unchanged; the chase is an *additional* early stop layered on top.

## 4. Match flow

```
1. First innings:  total1 = simulate_innings(<batting side>, ..., target = 0)
2. Chase target:   target = total1 + 1
3. Second innings: result2 = simulate_innings(<other side>, ..., target = target)
4. Decide the result from total1 vs result2.total (see §5).
```

Which side bats first is set by `player_bats_first`:
- **Player bats first:** innings 1 = Player's team (statted Player + `player_team_batting`, facing `opp_attack`/`opp_control`); innings 2 = opposition (derived from `opp_batting`, facing `player_team_attack`/`player_team_control`).
- **Player bats second:** the two innings swap — opposition posts, Player's team chases.

The `player_attrs` (statted Player) is passed only into the **Player's team innings**; the opposition innings passes `null` for the Player.

## 5. Result logic

Let `total1` = first-innings total, `total2` = second-innings total, `wkts2` = second-innings wickets, `balls2` = second-innings balls.

- `total2 > total1` → **chasing side wins by `10 - wkts2` wickets**, `balls_remaining = 120 - balls2`. (The chase loop stops the moment the target is passed, so a win is always "by wickets".)
- `total2 == total1` → **tie** (no Super Over in V1).
- `total2 < total1` → **defending (first-batting) side wins by `total1 - total2` runs**.

The winning *side* is then mapped to the Player's perspective via `player_bats_first` to set `outcome`.

## 6. `MatchResult`

A lightweight result holder (`RefCounted`), `scripts/data/match_result.gd`:

- `innings1: InningsResult`, `innings2: InningsResult` — the two innings in batting order (innings1 = whoever batted first).
- `player_bats_first: bool` — so consumers can map innings ↔ side.
- `outcome: int` — enum `Outcome { PLAYER_WIN, OPPONENT_WIN, TIE }` (name chosen to avoid Godot built-in collisions).
- `margin_runs: int` — set when a side wins batting first (else 0).
- `margin_wickets: int`, `balls_remaining: int` — set when a side wins chasing (else 0).
- Accessors:
  - `player_won() -> bool`
  - `is_tie() -> bool`
  - `margin_text() -> String` — e.g. `"won by 14 runs"`, `"won by 6 wickets (8 balls left)"`, `"match tied"`. The line the Theme 5 Result screen will display.

## 7. Test plan (TDD, red → green)

Pure function with an injected RNG → unit-testable in isolation. Tests assert **shape and relationships**, not exact tuned numbers; statistical tests use fixed seeds + generous tolerances so they are deterministic, not flaky.

Per project `CLAUDE.md`: the GUT `-gtest` flag does not filter — judge **red** by the `Parse Error: Identifier "MatchResolver"/"MatchResult" not declared` (GUT skips the file), **green** by the total test count climbing and `All tests passed`.

1. **Determinism** — same seed + inputs → identical `MatchResult` (outcome, both totals, margin) across repeated calls.
2. **Optional Player in `simulate_innings`** — `player_attrs = null` → 11 derived batters, `player_line()` empty, innings still terminates within bounds (≤120 balls, ≤10 wickets).
3. **Backward compatibility** — `simulate_innings` with default args (`target = 0`, statted Player) reproduces rung-2 behaviour (existing rung-2 tests stay green).
4. **Chase stops early** — a deliberately low first total → the chasing innings ends on `total >= target` with balls and/or wickets to spare (does not bowl all 120).
5. **Win by runs** — strengths/seed where the chase falls short → `Outcome` correct, `margin_runs == total1 - total2`, `margin_wickets == 0`.
6. **Win by wickets** — strengths/seed where the chase succeeds → `Outcome` correct, `margin_wickets == 10 - wkts2`, `balls_remaining == 120 - balls2`, `margin_runs == 0`.
7. **Tie** — a seed/strengths producing equal totals → `is_tie()`, `outcome == TIE`. (If a natural tie seed is hard to find, assert the tie branch via a direct result-decision unit on constructed totals rather than a full sim.)
8. **Perspective mapping** — same match inputs/seed, `player_bats_first` true vs false → `player_won()` flips correctly and innings1/innings2 swap sides.
9. **Even-contest sanity** — equal strengths over N seeded matches → roughly balanced Player win/loss split (loose band, like rung 2's score-band test; not a precise 50/50).

## 8. What this de-risks / sets up

- Proves the looped ball→innings engine produces sane, decidable matches end-to-end.
- The next rung (Intent / Key Moments) plugs into a complete match: Intent stops being a fixed `BALANCED` constant, and the Bowling Change KM gives the constant bowling pair its first real per-over variation.
- The Season wrapper (7b) plugs in above this: it introduces the `stars → numbers` pipeline (replacing the raw-int inputs with Team objects) and decides the toss, then loops `simulate_match()` across a Season.
- Bowler rotation, Player-as-bowler, the star pipeline, and the toss-as-flavour all stay cleanly deferred behind the input seam.

## 9. Open questions

None blocking. Confirmed deferrals (with their landing rungs):
- **Bowler rotation / Player-as-bowler** → next rung (Intent / Key Moments), via the Bowling Change KM + an opponent AI rotation policy.
- **Star → numbers pipeline + Team-bundled interface** → Season wrapper (7b).
- **Toss as a simulated event** → Season wrapper (7b); a caller-supplied bool for now.
