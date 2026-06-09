# Joker re-tune to rarity-tiered bands (Theme 7c balance) — Design

**Date:** 2026-06-09
**Status:** Design — **PARKED as rung 2** (build after the fair-fight baseline rung)
**Theme:** 7c balance harness · the long-deferred joker re-tune (handoff option B)
**Prereqs on `main`:** all 45 jokers wired (PRs #18–#26); build-balance LOCKED (PRs #27–#31); 356 tests green.

> **⚠️ Split (2026-06-09).** The measurement + DRS/opponent *mechanics* in this spec grew into their
> own rung — **the fair-fight baseline** (`2026-06-09-fair-fight-baseline-design.md`, build FIRST).
> That rung delivers: team-wide Player DRS, 2 reviews, opponent base DRS + boost, symmetric opponent
> intent, the run-margin readout, and a no-joker even-★3 baseline ≈ 48–50%. **This spec (rung 2) keeps
> only the rarity-band re-tune (§2, §5.2, §6) and runs against that honest baseline.** The §4 / §5.1
> mechanics + decisions DM1–DM5 are **superseded** here and owned by the baseline spec (DF1–DF6); they
> remain below for history but are NOT this rung's work. DB1–DB4 (the tuning decisions) still apply.

---

## 1. Why now

The 45 jokers were authored with **strawman magnitudes** (`docs/joker-pool-v1.md`), always
intended to be tuned once the sim was a trustworthy, balanced foundation. That foundation now
exists (build-balance locked, every build ~47–49% at even ★3). The handoff named this rung
"option B". Re-sweeping first (the baseline moved four times since the magnitudes were set)
surfaced two problems this rung fixes:

1. **A correctness gap in DRS** (Nico, 2026-06-09): a review should be usable on *any* of the
   Player's team's dismissals, but the sim only triggers it on the **hero's** dismissal.
2. **The joker magnitudes don't respect rarity** — a Common (Field Restrictions +5.5%) can
   out-punch a Legendary (Match-Winner's Vigil +0.6%), and one joker is net-negative
   (Carry Your Bat −3.5%).

## 2. Goal & success criterion

**Every non-enabler joker's solo strength sits in a band set by its rarity.** No joker is dead
or negative; no single joker is an auto-win. The authored pool is 24 Common / 15 Rare /
6 Legendary — power should scale with that tiering (Nico's call, 2026-06-09).

**Target bands** (solo win-delta above the no-joker baseline, at the recalibrated floor — see §4).
Grounded in roguelite feel: a player holds ~5 jokers, so a Common is a modest edge that
compounds, a Legendary is build-defining:

| Rarity | Target solo win-delta |
|---|---|
| Common | **+1% to +4%** |
| Rare | **+4% to +7%** |
| Legendary | **+7% to +12%** |
| *Enablers* | **~0% solo** (exempt — see §6) |

**Done when:** every non-enabler joker's solo win-delta lands in its band (±~1% tolerance),
no joker is negative, the run-margin readout corroborates the win-deltas for the strongest
jokers, and the full GUT suite is green.

## 3. Scope (confirmed with Nico, 2026-06-09)

**In scope** — "Fix DRS + tune" (the recommended middle option), plus opponent base DRS (Nico, 2026-06-09):
- **DRS correctness fix** — review *any* team dismissal, not just the hero's (§5.1).
- **DRS review count** — set `base_reviews` 1 → **2** to match the real T20 rule (DM4, §5.1).
- **Opponent base DRS** — the opponent reviews to *survive* its own dismissals (base rule, **no jokers**),
  so the no-joker floor reflects both teams playing the same game (DM5, §4.1/§5.1).
- **Measurement upgrade** — symmetric opponent batting intent + run-margin readout (§4).
- **Rarity-band re-tune** — magnitudes + a few scalar dials, no new mechanics (§5.2).

**Out of scope (deferred, documented):**
- **Opponent boost + opponent reviews-to-claim-while-bowling.** Opponent *boost* collides with the
  Player's bowling boost in the same innings (the harder two-captain rework); opponent reviews to
  *claim* a Player wicket while bowling is a further DRS layer beyond "review my dismissals". Both edge
  into the deferred **self-play AI** stage (7c layer E). The opponent-survive DRS above is the bounded,
  intent-matching slice; the run-margin ruler handles any residual headroom above 50%.
- **Trigger-participation** — some jokers read weak because a balanced 5/5/5/5 build rarely
  *fires* them (e.g. batting-Form Legendaries), not because the magnitude is small. We tune
  magnitude (how strong *when it fires*), not firing frequency. Participation is the same theme
  as all-rounder participation and is its own future concern (§6, carve-out).
- **No new jokers, no new mechanics.**

## 4. Measurement (do this first)

The sweep (`tools/sweep_jokers.gd`) runs a fixed, sensible Player game-plan (aggressive PP/death
intent, boosts at overs 1/10/16, 1 DRS review at p=0.4, catching/defensive fields, pace/spin
bowling) identically across all arms, so the only thing that changes between "no jokers" and
"joker X" is the joker — that isolates each joker's effect. Two upgrades:

### 4.1 Lower the baseline floor — symmetric opponent intent + opponent base DRS
The current no-joker baseline wins ~62–64% purely because the opponent plays **passively** while
the Player runs a sensible game-plan with its captain levers. Two changes make the floor an honest
"both teams play the same game, the Player just holds jokers on top":
- **DM1 — symmetric opponent batting intent.** Measured (N=4000, even ★3): giving the opponent the
  **same aggressive intent plan** drops the floor ~64% → **~56%** (field symmetry adds nothing further).
  Set `opp_intent_plan` = the Player's intent plan in the sweep scenario.
- **DM5 — opponent base DRS (review-to-survive, no jokers).** The opponent reviews to survive its own
  dismissals under the base rule (`base_reviews`, `base_p`), no jokers. This removes a Player-only edge
  and pulls the floor further toward 50% (the opponent keeps wickets / scores more). The Player's
  *additional* DRS edges (jokers; reviews-to-claim while bowling) remain, so the floor lands a few
  points above 50% — fine; the run-margin ruler (§4.2) handles the residual.

A lower floor = more headroom to 100% = the strong jokers stay measurable. The DRS fixes (team-wide,
2 reviews, opponent DRS) all move this floor; we **re-measure it after** wiring them — the exact number
is informational, the win-*delta* per joker is what we tune.

### 4.2 Add a run-margin readout (non-saturating ruler)
Win-rate caps at 100% — once an arm wins ~every match, a stronger joker can't show it. **Decision
(DM2):** the scenario also returns **`margin`** = (Player's team total − opponent's total) for the
match (positive = Player won by that many runs; negative = lost). Averaged over N, this is a finer,
ceiling-free ruler that corroborates the win-delta and resolves ties among the strongest jokers.
Compute from `MatchResult`: identify the Player's innings (the one with a non-empty `player_line()`)
vs the opposition's, take totals, subtract. The sweep prints **both** win-delta and mean-margin-delta
per arm. Win-delta stays the primary band metric (intuitive); margin is the tiebreak/saturation check.

## 5. The work

### 5.1 DRS fixes (`scripts/domain/innings_resolver.gd`, `scripts/data/drs_policy.gd`, `scripts/domain/joker_runtime.gd`)

**DM3 — team-wide review (drop the hero gate).** Currently (line ~188):
`if player_is_batting and o.wicket and s["is_player"]:` — only the hero's dismissal triggers a
review-to-survive. Drop the `s["is_player"]` gate → `if player_is_batting and o.wicket:` so *any*
batter's dismissal in the Player's innings can be reviewed. Matches Nico's intent (DRS is a team-level
tool) and makes the model honest. It makes the Player's DRS **stronger** (more dismissals reviewable),
reinforcing the re-tune-down in §5.2.

**DM4 — 2 reviews.** Set `DRSPolicy.base_reviews` 1 → **2** (real T20 rule). Strengthens DRS; tuned for
in §5.2.

**DM5 — opponent base DRS (review-to-survive, no jokers).** In the opponent's batting innings (the
innings where `player_is_batting == false` and the opponent bats), give the opponent its **own** review
pool (`base_reviews`, `base_p`) and, on an opponent batter's dismissal, attempt a **no-joker**
review-to-survive (overturn → not out). Implementation shape (detail in the plan): the per-innings
`JokerRuntime` tracks a second counter (`opp_reviews_left`) and a `try_review_base()` path that applies
**only** the base rule (no joker `drs_role` modifiers, no Form/bowling-buff payoffs). Routed where the
opponent is the dismissed batter. The opponent's reviews-to-*claim* (while bowling, to get the Player
out) are **out of scope** (§3) — survival is the intent-matching, floor-moving slice.

**Shared notes:**
- **No husbanding AI** — reviews are auto-spent on dismissals as they occur (no save-for-later logic).
  Acceptable V1; husbanding is a later AI concern.
- **RNG draw order shifts** — more reviews are now attempted (any dismissal, both teams), each a
  `randf`, so snapshot/determinism-*value* tests will need rebaselining (determinism itself still holds:
  same seed → same result). Deliberate core change, same spirit as PR #16.
- **Form-on-success payoffs** in the Player's `try_review` fire as before (a teammate's successful
  review firing a Form event is acceptable — team morale). The opponent's `try_review_base()` fires
  **no** payoffs.

TDD: a test that a **teammate** dismissal (not the hero) can be overturned by the Player's review; a
test that the **opponent** can overturn a dismissal via its base review; a test that `base_reviews=2`
allows two failed reviews before the pool is empty.

### 5.2 Rarity-band re-tune (pure data + a few scalar dials)
Adjust **only magnitudes** — no mechanic changes. Levers:
- Each joker's `mult` / `drs_p_bonus` in `scripts/data/joker_catalog.gd`.
- DRS dials: `DRSPolicy.base_p` (0.4) / `base_reviews` (1); `JokerRuntime.DRS_MASTER_BONUS` (0.30),
  `DRS_BOWLING_BUFF_MULT` (1.20).

From the re-sweep (against the OLD 62.4% floor — re-measure against the new floor before tuning),
the work concentrates on:

**Pull DOWN (over-tiered):**
- **DRS family** — the headline. Pre-fix readings: The Review Master +21.9% (Legendary, but far
  over band even so), The Captain's Call +9.2% (**Rare** — bigger than most Legendaries), Snicko
  +5.0% (Rare, borderline). After the §5.1 fix these get *stronger*, so they need the hardest pull
  via `base_p`, the accuracy bonuses, and `DRS_MASTER_BONUS`.
- **Over-strong Commons** — Field Restrictions +5.5%, Powerplay Punch +5.0% (both acting like Rares).

**Fix the bug:**
- **Carry Your Bat −3.5%** (Rare) — it over-defends (wicket ×0.85 *and* runs ×0.90 in DEFENSIVE →
  survives but scores too slowly to win). Raise the runs mult so it is net-positive and in the Rare band.

**Pull UP (under-tiered / dead):**
- **Dead Commons** — Rotate the Strike ≈0%, Pressure Cooker ≈0%.
- **Weak Rares** — Hot Streak, First-Change Specialist, The Trap, Compounding Pressure,
  Bowler's Backing, Wicket Maiden (all ~0–0.7%).
- **Near-dead Legendaries** — Match-Winner's Vigil +0.6%, The Strike Bowler +1.2%, The Comeback
  Press +1.4%. (Caveat: some of these are participation-limited per §6 — tune their firing-strength
  and document the residual; do **not** crank a magnitude to compensate for low fire-rate.)

Magnitudes already near their band (Choke Hold +8.8% Legendary, Death-Over Stranglehold +5.4% Rare,
Dot Ball Pressure +4.0% Rare, The Chase Master +3.0% Legendary→needs a small bump) are left or
nudged only as needed.

### 5.3 Iterate
Tuning is empirical: change a magnitude → re-run the sweep → check the band → repeat. Expect 2–4
sweep passes. The oracle is `tools/sweep_jokers.gd` (now with symmetric opp intent + margin).

## 6. Enablers (exempt from the bands)

Some jokers have **~0% solo by design** — their value is combinatorial (they enable other jokers).
These are exempt from the per-joker bands and judged only in-combo (the sweep's stack arms cover
this):
- **Form sources** — The Sheet Anchor, Captain's Statement, Building Phase (#2/#11/#5): they emit
  Form events that *consumer* jokers (Ride the Wave, Hot Streak) turn into value.
- **Hot Spot** (DRS FORM_ON_SUCCESS) and **Defensive Captain** (sets a defensive field): pure enablers.
- **Boost base roles** that only shape the press for other Boost jokers.

Their target is "≈0% solo, positive in-combo" — verify the relevant stack arm clears its rarity
floor, not the solo arm.

## 7. Verification

- **TDD throughout** — a directional unit test for the DRS team-wide fix; for any changed scalar
  that a test asserts on, update/rebaseline as needed.
- **Determinism** — same-seed reproducibility must hold (it will; only draw-order *values* shift).
- **Re-run the sweep** after tuning; assert every non-enabler joker's solo win-delta is in its band,
  none negative, margin corroborates the top jokers.
- **Full GUT suite green** (currently 356; net count rises with new tests, some snapshot tests
  rebaselined). Judge red by parse-error/failing-assert, green by count climbing + "All tests passed".
- **Update** `docs/joker-pool-v1.md` magnitudes to the tuned values (single source of truth) and the
  distribution viewer's `DATA` const with the final sweep.

## 8. Key decisions (record)

- **DB1 (Nico):** balance target = **rarity-tiered bands** (not flat, not surgical-only).
- **DB2 (Nico):** scope = **"Fix DRS + tune"** (middle option) — DRS correctness + measurement
  upgrade + full re-tune; opponent captain-tooling deferred to self-play.
- **DM1:** lower the sweep floor via **symmetric opponent batting intent** (~56%, re-measured after
  DRS fix). Don't chase 50% (would need opponent captain-tooling, out of scope).
- **DM2:** add a **run-margin** readout (non-saturating) alongside win-delta.
- **DM3:** DRS reviews **any team dismissal** (drop the `is_player` gate). Team-level tool per intent.
- **DM4 (Nico):** DRS `base_reviews` 1 → **2** (real T20 rule).
- **DM5 (Nico):** the **opponent gets base DRS** (review-to-survive its own dismissals, no jokers) so the
  floor reflects both teams playing the same game. Opponent boost + opponent reviews-to-claim deferred.
- **DB3:** re-tune is **pure data** — catalog magnitudes + a few existing scalar dials, no new
  mechanics. If scalars alone can't bring the DRS family into band, the documented fallback is one
  mechanic tweak (drop DRS retain-on-success) — flagged, not pre-committed.
- **DB4 (carve-out):** trigger-participation is **not** tuned here — magnitude is tuned for
  firing-strength; participation-limited jokers get a documented residual, not an inflated magnitude.
- **DB5 (carve-out):** boost is **already team-wide on both sides** (verified `innings_resolver.gd:182`
  + `joker_runtime.gd:40-50,118-121`): a press buffs the whole batting line-up (runs) while batting
  and the whole bowling attack (wickets) while bowling — side-aware, applied to every delivery in the
  window, fired in both innings. Matches Nico's intent — **no change needed**.

## 9. Files touched

- `tools/sweep_jokers.gd` — symmetric opp intent (DM1) + margin in `_scenario` return + print (DM2);
  opponent gets a `DRSPolicy` (DM5).
- `scripts/domain/innings_resolver.gd` — DRS team-wide gate (DM3); route opponent dismissals to the
  opponent review pool (DM5).
- `scripts/domain/joker_runtime.gd` — `opp_reviews_left` + `try_review_base()` (DM5); DRS scalar dials
  (`DRS_MASTER_BONUS` etc.) if needed for the re-tune.
- `scripts/data/drs_policy.gd` — `base_reviews` 1 → 2 (DM4); `base_p` dial if needed.
- `scripts/data/joker_catalog.gd` — re-tuned magnitudes (DB1).
- `tests/unit/` — teammate-review, opponent-review, 2-review tests; rebaselined snapshot/value tests.
- `docs/joker-pool-v1.md`, `docs/mockups/distribution-viewer-v1.html` — final magnitudes + DATA.
