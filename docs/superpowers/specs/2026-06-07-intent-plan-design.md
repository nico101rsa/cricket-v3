# Intent plan — design spec

**Date:** 2026-06-07
**Theme:** 7a (Tech foundation → match sim core), rung 4a (ball → innings → match → **Intent** → Bowling Change). Rung 4 is split into **4a (Intent)** and **4b (Bowling Change)**; this is 4a.
**Status:** Approved (design shape) — ready for `writing-plans`
**Builds on:** `MatchResolver.simulate_match()` (spec `2026-06-07-full-match-design.md`) and `InningsResolver.simulate_innings()` (spec `2026-06-07-innings-sim-design.md`)
**Implements:** ADR 0004 (auto-sim — headless, deterministic-seedable, Intent is a coupled modifier) + the `setIntent(band)` verb of ADR 0006 (typed-effect palette)

---

## 1. Scope

Today every ball in the sim is resolved at a hardcoded `BallResolver.Intent.BALANCED`. This rung removes that hardcode and lets the **caller choose the batting Intent per match phase**, via a small `IntentPlan` value threaded through the innings loop.

The ball atom *already* accepts an `Intent` (`DEFENSIVE / BALANCED / AGGRESSIVE`) and couples it onto both rolls (aggression scores faster *and* dies sooner — ADR 0004). Rung 4a builds the **data path** that carries a per-phase Intent choice down to that existing knob. Nothing in `resolve_ball()` changes.

Because the sim is headless and pure, "the Player sets Intent" means **the Intent becomes a caller-supplied input** rather than a constant. In the balance harness this is a coded policy (the lever the naive-vs-optimal skill-gap metric of ADR 0003 finally has something to vary); in the live game (much later, Theme 6 in-match screen) it is the human's swipe-card choice. Rung 4a builds the seam both will drive.

**In scope:**
- A small `IntentPlan` type holding one Intent band per phase, with an over → band lookup.
- Two phase boundaries: **Powerplay** (overs 1–6), **Middle** (overs 7–15), **Death** (overs 16–20).
- Two named factories: `balanced()` (neutral) and `textbook()` (Aggressive / Balanced / Aggressive).
- Threading an optional plan through `simulate_innings()` and `simulate_match()`, backward-compatibly.
- Applying the plan only to the **Player's batting innings**; the opposition innings stays Balanced.

**Out of scope (deferred — do not build here):**
- **Bowler rotation** → rung 4b (Bowling Change KM, opponent AI rotation policy). The bowling side stays a constant `(attack, control)` pair this rung.
- **Opponent batting intelligence.** The opposition bats at a flat `BALANCED` plan; a smart opponent batting policy is a later rung.
- **Per-over Intent granularity.** No design driver yet — the two always-on intent KMs land exactly on these phase boundaries.
- **Reactive Intent** (Wicket Crisis, Milestone Ball changing posture mid-phase) — later KMs.
- **The swipe-card UI / the typed-effect *stream* machinery.** This rung is the per-phase data path, not the in-match decision UI or a generic effect bus.
- **The star → numbers pipeline, Team-bundled interface, and the toss** → Season wrapper (7b), unchanged from rung 3.
- Form, Jokers, Manager Boost, conditions, extras, run-outs, Super Overs — all still off.

## 2. The `IntentPlan` type

A lightweight value object (`RefCounted`, not a saved `Resource` — it is a transient per-match decision input, not tuning), at `scripts/data/intent_plan.gd`.

State — three Intent bands (values from `BallResolver.Intent`):

```
powerplay: int   # Intent for overs 1..6
middle:    int   # Intent for overs 7..15
death:     int   # Intent for overs 16..20
```

Phase boundaries are **constants on the class** (documented as defaults the harness may revisit later):

```
const POWERPLAY_OVERS  := 6    # fixed by T20 law (6-over powerplay)
const DEATH_START_OVER := 16   # tunable default (last 5 overs)
```

One lookup method:

```
for_over(over: int) -> int        # 1-based over number -> Intent band
    over <= POWERPLAY_OVERS        -> powerplay
    over <  DEATH_START_OVER       -> middle
    else                           -> death
```

Two factories (static):

- `IntentPlan.balanced()` — all three bands `BALANCED`. The neutral baseline; behaviourally identical to the current hardcode.
- `IntentPlan.textbook()` — `powerplay = AGGRESSIVE`, `middle = BALANCED`, `death = AGGRESSIVE`. A sensible "decent baseline" plan for the harness and the directional test.

`IntentPlan` knows nothing about RNG, batters, or scores — it is a pure over → band map. It can be understood and tested entirely on its own.

## 3. Threading through `simulate_innings()`

`simulate_innings()` gains one trailing optional parameter:

```
simulate_innings(
    player_attrs, partner_batting, opp_attack, opp_control,
    tuning, itun, rng,
    target: int = 0,
    intent_plan: IntentPlan = null      # NEW — null => all-BALANCED
) -> InningsResult
```

Inside the loop, the hardcoded `BallResolver.Intent.BALANCED` is replaced by a per-ball lookup:

```
var over := balls / 6 + 1                 # 1-based over of the ball about to be bowled
var intent := BallResolver.Intent.BALANCED
if intent_plan != null:
    intent = intent_plan.for_over(over)
# ... resolve_ball(..., intent, ...)
```

`balls` is the pre-increment count (incremented *after* `resolve_ball`), so `balls / 6 + 1` is the correct 1-based over for the delivery being bowled: `balls = 0 → over 1`, `balls = 5 → over 1`, `balls = 6 → over 2`, `balls = 119 → over 20`.

**Intent is a team posture, not per-batter** (ADR 0006 — "team aggression posture"): the band depends only on the over, and applies to whichever batter is on strike. Strike rotation is untouched.

## 4. Threading through `simulate_match()`

`simulate_match()` gains one trailing optional parameter:

```
simulate_match(
    ... existing params ... ,
    player_intent_plan: IntentPlan = null   # NEW — the Player's batting plan
) -> MatchResult
```

Routing — the plan goes to the **Player's team innings only**; the opposition innings passes `null` (→ Balanced):

- **Player bats first:** innings 1 (Player's team) gets `player_intent_plan`; innings 2 (opposition) gets `null`.
- **Player bats second:** innings 1 (opposition) gets `null`; innings 2 (Player's team) gets `player_intent_plan`.

No other change to match flow, the chase, or `_decide_result()`.

## 5. Backward compatibility

Both new params default to `null`, and `null` resolves to `BALANCED` on every ball — **byte-identical to rung 3**. Every existing innings-level and match-level test must stay green unchanged; this is the load-bearing regression guard (mirrors how rung 3 added optional `player_attrs` / `target`).

Determinism is preserved: `IntentPlan` consumes no RNG, and the draw order in `resolve_ball()` is unchanged. Same inputs + same seed + same plan → identical result.

## 6. Test plan (TDD, red → green)

Per project `CLAUDE.md`: the GUT `-gtest` flag does not filter — judge **red** by `Parse Error: Identifier "IntentPlan" not declared` (GUT skips the file), **green** by the total count climbing past 133 and `All tests passed`. Statistical tests use fixed seeds + generous tolerances so they are deterministic, not flaky.

`IntentPlan` unit tests (pure, no RNG):
1. **Phase mapping at boundaries** — `for_over` returns: powerplay for overs 1 and 6; middle for overs 7 and 15; death for overs 16 and 20.
2. **Factories** — `balanced()` returns BALANCED for all three phases; `textbook()` returns AGGRESSIVE / BALANCED / AGGRESSIVE.

`simulate_innings()` tests:
3. **Backward compatibility** — `intent_plan = null` reproduces the existing rung-2/3 result for a fixed seed (identical `InningsResult`). (Existing innings/match tests also stay green by construction.)
4. **Determinism with a plan** — same seed + same non-trivial plan → identical `InningsResult` across repeated calls.
5. **Directional sanity** — over N seeded innings, an all-AGGRESSIVE plan yields a higher average total **and** more average wickets than an all-DEFENSIVE plan (the coupling working — loose bands, not exact numbers).

`simulate_match()` tests:
6. **Routing** — proven via the fact that the **first** innings always consumes the RNG from the seed's initial state, so it is directly comparable to a standalone `simulate_innings()` call seeded identically (this sidesteps the shared-RNG coupling, where a longer first innings shifts the second innings' draws):
   - **Player bats first** (`player_bats_first = true`) with a distinctive plan (`textbook()`) → `match.innings1` equals a standalone Player innings simulated with that same plan at the same seed. (The plan reached the Player's innings.)
   - **Player bats second** (`player_bats_first = false`) with the same `textbook()` plan → `match.innings1` (the opposition) equals a standalone opposition innings simulated with a **`null`/Balanced** plan at the same seed. (The opposition got Balanced, *not* the Player's plan — routing is correct.)
7. **Determinism** — same inputs + seed + plan → identical `MatchResult` across repeated calls.

## 7. What this de-risks / sets up

- Intent stops being a dead constant — the sim now has its **first real decision input**, the one the ADR 0003 naive-vs-optimal skill-gap metric measures.
- Confirms the per-phase posture model (Powerplay / Middle / Death) is enough to express the two always-on intent Key Moments (Powerplay Exit, Death Plan) without per-over machinery.
- Leaves a clean seam: rung 4b (Bowling Change) replaces the constant bowling pair with a rotating cast and an AI policy; the live in-match swipe-card (Theme 6) later writes into the same `IntentPlan` seam instead of the harness/factory writing it.

## 8. Open questions

None blocking. Confirmed deferrals (with landing rungs):
- **Bowler rotation / opponent AI bowling policy** → rung 4b (Bowling Change).
- **Opponent *batting* intelligence** (non-Balanced opposition plan) → later rung; Balanced for now.
- **Reactive Intent** (Wicket Crisis / Milestone Ball mid-phase changes) → later KMs.
- **Per-over Intent granularity** → only if a design driver appears; three phases for now.
- **Swipe-card UI + typed-effect stream** → Theme 6 in-match screen.
- **Death-overs boundary as swept tuning** → constant on `IntentPlan` for now (`DEATH_START_OVER = 16`); harness may promote it into `InningsTuning` later if it proves worth sweeping.
