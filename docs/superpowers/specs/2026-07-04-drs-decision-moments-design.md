# DRS Decision Moments (playtest T8) — design

**Date:** 2026-07-04 · **Status:** approved direction from Nico (playtest note, 2026-07-04 am), defaults recorded here per AFK protocol · **Rung:** medium (sim moment model + card UI + balance gate)

## 1. What Nico asked for (the design authority)

From `docs/PLAYTEST-NOTES.md` T8 (expanded 2026-07-04):

> More DRS decisions but contextual, not every wicket — (a) a top-order batter who is set ("on fire") falls to a reviewable-looking dismissal (caught behind / LBW flavour), or (b) the last 2 overs with a review still in hand. Success chance is drawn PER MOMENT in roughly the 20%–70% range and SHOWN — the decision is "burn the review at 35% now, or hold it for the death overs". Failed review burns it; the opponent AI mirrors the same variable p (symmetry); moment frequency × mean p tuned so total overturn rate ≈ today's flat rate → the fair-fight floor doesn't move (sweep gate).

Also answers his earlier notes: "DRS should give you % of success and **review all your batters**" — moments now cover ANY batter on your team, not just the hero.

## 2. Today's DRS (what changes and what doesn't)

- **Survive channel** (batting side reviews a wicket): headless auto = every wicket attempted at flat `base_p = 0.32`, retained on success, 2 fails per innings. Live = only the HERO's dismissals offered, scripted via `DRSPolicy.review_balls`.
- **Claim channel** (bowling side reviews a close dot to claim a wicket): auto on every dot, both sides headless. **Unchanged by this rung** (DT5).
- **Live asymmetry found while exploring:** `MatchSession._resim` passes `opp_drs_policy = null` — the live opponent holds NO reviews, while the headless fair-fight floor (48.9%) was measured two-sided. The live game has been quietly easier than the measured floor. This rung fixes it (DT4).

## 3. Decisions (AFK defaults — flag anything you'd change, Nico)

- **DT1 — Dismissal flavour, hash-derived (no RNG shift).** Every wicket gets a flavour from a deterministic hash of (batting side, over, ball-in-over): caught 35%, bowled 22%, LBW 18%, caught-behind 15%, run-out 7%, stumped 3%. *Reviewable* = LBW or caught-behind (~33% of wickets). Hash, not an RNG draw, so the ball-outcome cascade is untouched and re-sims are stable.
- **DT2 — Moment gate.** A wicket is a DRS MOMENT iff reviews remain AND flavour is reviewable AND (the striker was **set** — had faced ≥ 10 balls — OR the ball is in the **death overs**, over ≥ 19). Applies to any batter on the batting team, both sides.
- **DT3 — Per-moment shown odds.** p = 0.20 + 0.50 × u, u a second independent hash of the same ball → p ∈ [0.20, 0.70], mean 0.45. The card SHOWS the percentage. Reviewer-joker accuracy bonuses (Cool Head, Snicko, Captain's Eye when its intent gate holds at that over, Review Master) are added into both the shown number and the actual roll.
- **DT4 — Symmetry + AI policy.** The live opponent now holds a base `DRSPolicy` (same as headless). Auto/AI sides burn a review in a moment iff raw moment p ≥ 0.35 (holds cheap reviews — mirrors the human's "burn or hold" call). Same rule for the player's own headless career sims.
- **DT5 — Claim channel untouched.** Dot-ball claims stay auto at flat `base_p`, both sides. This rung redesigns the survive channel only.
- **DT6 — Scripted path.** `DRSPolicy.review_balls` still lists the player's committed reviews; at a listed ball the resolver rolls the MOMENT p (recomputed from the same hash), not `base_p`. New test seam `DRSPolicy.moment_p_override` (< 0 = off) forces all moment p's for deterministic tests, mirroring the `review_balls` seam pattern.
- **DT7 — Session moments precomputed.** `MatchSession` walks the team-batting ball log each re-sim (like `_km_moments`): qualifying wickets → `{cursor, ball_id, over, ball, batter_pos, batter_runs, batter_balls, flavour, p_shown, death}`. Cursor anchors to the event CONTAINING the ball — the hero's own "ball" event, or the "over" summary event for a teammate's wicket. Pause fires before the event shows; the watched prefix stays byte-identical.
- **DT8 — Card copy.** The existing blue DRS card gains: who fell (position + score, "Your #4 · 34 off 22 — set"), the flavour ("Given out CAUGHT BEHIND"), and the shown odds on the REVIEW button ("Send it upstairs — 43%"). Death-over moments say so ("Last overs — use it or lose it"). ACCEPT stays the walk.
- **DT9 — Budget unchanged.** 2 reviews per innings, failed review burns one, success retains (standard T20).
- **DT10 — Balance gate.** Run the shared balance sweep (`tools/sweep_form_balance.gd`) after the change; gate = per-build win-rate and net-pay within noise of the v3 reference (spec 2026-07-03 Results §). The survive-channel redesign is two-sided and symmetric, so the floor should hold by construction; the sweep verifies. DRS-joker re-pricing deferred unless the sweep shows drift.
- **DT11 — Save compatibility.** `export_decisions()` format unchanged (`review_balls` pairs). An in-flight match replayed from an old save re-sims under the new rules (different outcomes possible); committed match results are untouched (they're stored, not replayed — T12 fix). Recorded as an accepted one-time deviation.
- **DT12 — The hero's non-moment dismissals no longer pause the match.** That's the point ("not every wicket") — bowled second ball for 0 is out, walk on.

## 4. Architecture

New pure helper **`scripts/domain/drs_moments.gd`** (`class_name DRSMoments`) — the single source of truth both the resolver and the session consume:

- `flavour_of(batting_side_is_player: bool, over: int, bio: int) -> String`
- `is_reviewable(flavour: String) -> bool`
- `moment_p(batting_side_is_player: bool, over: int, bio: int) -> float`
- `is_moment(flavour: String, striker_balls_faced: int, over: int) -> bool` (set ≥ 10 balls OR over ≥ 19)
- `AI_BURN_P := 0.35`, `SET_BALLS := 10`, `DEATH_OVER := 19`, `P_LO := 0.20`, `P_SPAN := 0.50`

**`InningsResolver`** survive-channel block: auto mode gates on `is_moment` (striker's balls faced is `s["balls"]` pre-increment) + AI burn threshold, rolls `moment_p` (or the override); scripted mode reviews listed balls at `moment_p`. Claim channel untouched.

**`MatchSession`**: `_resim` passes a base `DRSPolicy` as `opp_drs_policy` (DT4); `_compute_drs_moments()` after each re-sim; `review_offer(cursor)` returns the enriched moment dict (DT7) or `{}`; `decide_review` unchanged.

**`interactive_match.gd`**: `_build_drs_body()` renders the enriched offer (DT8).

## 5. Testing

- `test_drs_moments.gd` — flavour distribution over a big sample (weights ±2pp), determinism (same inputs same flavour/p), p range [0.20, 0.70], gate table (set/death/reviewable).
- `test_drs_review_balls_seam.gd` — UPDATED to the new contract: auto with `moment_p_override = 1.0` overturns every QUALIFYING wicket and leaves non-qualifying wickets standing; scripted single ball still works.
- `test_fair_fight_baseline.gd` — the "reviews any dismissal, not just hero" test adapts to override seam + qualifying wickets.
- `test_match_session.gd` — offer fires at a moment cursor with `p_shown`/`flavour`/batter fields; non-moment hero dismissals DON'T offer; prefix byte-identity; budget tests carried.
- Scene test — DRS card shows the percentage and flavour.
- Sweep gate (DT10) recorded in §6 Results.

## 6. Results (build, 2026-07-04)

**Instrument:** `tools/sweep_form_balance.gd` (the shared balance re-sweep): 4 reference builds, even ★3, form-OFF vs ON. Match level N=2000 paired seeds per build×arm; season level N=300 LeagueResolver seasons per build×arm. Log `/tmp/t8_sweep.log`; v3 reference `/tmp/form_sweep_v3.log` + form spec Results §.

**Match level (win% · pay · team/opp totals · form net), the canonical build-equality gate:**

| build | OFF win% | ON win% | ON pay ₸ | form net |
|---|---|---|---|---|
| batter | 49.0 | 49.3 | 69.4 | +0.04 |
| bat-AR | 48.4 | 48.5 | 69.4 | −0.23 |
| all-rounder | 49.3 | 48.9 | 68.5 | −0.23 |
| bowler | 48.1 | 48.2 | 68.1 | +0.28 |

- **The fair-fight floor holds:** every build in both arms sits at 48–49% (win spread 1.2pp OFF / 1.1pp ON, tolerance ~2pp) — the moment redesign is two-sided and symmetric, and the total overturn EV landed close enough to the old flat rate that nothing moved. Nico's DT10 gate ✓.
- Pay spread ≤ ₸1.6 with the known v3 batter residual (+₸1.33 ON−OFF) unchanged ✓.
- Form nets identical to the v3 reference (+0.04/−0.23/−0.23/+0.28) ✓. Scoring env ~177.5 both sides ✓.

**Season level (fixture-win% OFF→ON · season-end form):** batter 47.7→48.0 (−0.22) · bat-AR 45.0→43.9 (−1.91) · all-rounder 46.2→44.7 (−1.41) · bowler 56.6→57.5 (+1.66). All within N=300 noise (±~1.5pp) of the v3 reference run. **Note:** the bowler build's high season fixture-win% (~57%) is PRE-EXISTING — v3 measured 56.9% on the identical instrument pre-DRS — and match-level equality holds; flagged as its own investigation (season vs match instrument divergence), not a T8 effect.

**DRS-joker re-pricing:** deferred per DT10 — no floor drift to react to. Reviewer jokers' accuracy bonuses now ride on the moment p (shown and rolled); their realized value shifts with moment frequency, worth folding into the next joker sweep if one runs.
