# Jokers in the sim — C2a: field-mode condition + state-gated jokers · design

**Date:** 2026-06-08 · **Status:** spec · **Rung:** 7c-C2a (first sub-slice of C2)
**Predecessors:** 7c-C jokers slice (PR #18) — the effect-application seam + 5 jokers.
**Source of truth:** ADR 0006 (6-verb palette), ADR 0007 (authoring grammar), `docs/joker-pool-v1.md`.

---

## 1. What this rung is — and why C2 is split

The roadmap's next step was **7c-C2: scale the 5-joker slice to all 45 + add the deferred verbs.** Auditing the pool against the sim shows C2 is not one rung — the 40 remaining jokers need **six separate new sim subsystems**, each rung-sized:

| Needed machinery | Jokers it unlocks (≈) | Status |
|---|---|---|
| (already built) stateless per-ball `buffNextBalls` on intent/ball-window/side | 5 (the slice) | ✅ PR #18 |
| **field mode** (catching/defensive state a captain sets) | ~6–10 | **← this rung (C2a)** |
| bowling-side intent (opposition/captain intent band) | ~4 | C2b |
| Form system (Player Form counter + `formEvent` + Form triggers) | ~8 | C2c |
| windowed-trigger buffs (decaying per-innings window counter) | substrate | C2d |
| `setNextBowler` fire events (depends on windows) | ~6 | C2e |
| Manager Boost (press event + boost window) | 7 | C2f |
| DRS / `tryReview` (review resource + success roll) | 8 | C2g |

So **C2 is decomposed C2a→C2g**, one subsystem + the jokers it unlocks per rung, sweeping as we go — same rung-by-rung discipline as 4a/4b and 7b-1/7b-2. This rung is **C2a**.

**C2a = the field-mode condition + every joker the current seam can express with field added.** It takes the implemented pool from **5 → 11 of 45** by:
1. adding **field mode** as a readable per-phase captain state (a new condition dimension, mirroring how `IntentPlan` supplies the intent condition);
2. supporting **multi-buff jokers** (one joker that bends both rolls) via the resolver's existing product (no model change — two `JokerEffect` rows share an `id`);
3. authoring the **6 jokers** unlocked: 3 stateless-leftover (intent/ball-window only) + 3 field-gated.

**Success =** the harness sweep shows each of the 11 implemented jokers' distribution + win-rate shift vs baseline, with field-gated jokers firing under a supplied `FieldPlan`.

## 2. The one design decision: field mode is a *condition*, not (yet) an EV lever

In the real game a catching field has its own effect (more wickets, more runs conceded) — a genuine EV trade the captain makes. **This rung does NOT model that intrinsic effect.** Field mode is added purely as a **captain-set state that jokers read** — exactly as the slice treats the intent band: a condition, supplied by the caller, that decides whether a joker fires. The field's own roll EV ("catching trades runs for wickets") is a **deferred tuning item** (its own future rung where it's properly designed, like bowling husbanding was deferred from 4b).

**Why the cheap door:** layer C's job is *wire the jokers' effects into the sim* — measuring levers, not designing new gameplay ones. Making field a real EV lever is Theme-2/3 design that deserves its own brainstorm. A field state that only jokers read is fully consistent with the slice (where a bowling joker's intent condition is likewise inert unless set) and keeps determinism trivially intact (no new rolls, no new RNG draws). Documented as **D2** below.

Consequence: in the sweep, field-gated jokers fire only when the arm's shared `FieldPlan` sets the matching mode for that over — the field-mode analogue of how the slice's shared `IntentPlan` makes intent jokers fire.

## 3. The 6 new jokers (from `docs/joker-pool-v1.md`, magnitudes verbatim)

| # | Name | Rarity | Side | Condition | Target(s) | Needs |
|---|---|---|---|---|---|---|
| 4 | Rotate the Strike | Common | batting | intent = Balanced | runs ×1.08 | existing seam |
| 6 | Carry Your Bat | Rare | batting | intent = Defensive | wicket ×0.85 **and** runs ×0.90 | multi-buff |
| 12 | Slog Over Specialist | Rare | batting | intent = Aggressive **and** ball ≥ 90 | runs ×1.25 | existing seam (intent+window) |
| 16 | Tight Lines | Common | bowling | field = Defensive | runs ×0.90 | field condition |
| 20 | Dot Ball Pressure | Rare | bowling | field = Defensive | wicket ×1.12 **and** runs ×0.88 | field + multi-buff |
| 23 | Cordon Killer | Common | bowling | field = Catching | wicket ×1.10 | field condition |

This set is deliberately spanning: it proves **multi-buff** (#6, #20), **combined intent+window** (#12), and the **new field condition** across catching/defensive × wicket/runs × single/multi (#16, #20, #23). Implemented pool 5 → 11.

(Pool subtleties parked: #6's pool text reads "field defensive" in some builds — modelled here off its Anchor intent=Defensive composition, magnitudes verbatim. #9 Field Restrictions reads the *opposing* field while batting — needs an opposition field model → deferred to C2b. The captain-*set* field jokers #18/#22/#27/#30 need bowling intent or bowler-change events → deferred to C2b/C2e.)

## 4. Components

### 4.1 `FieldPlan` — `scripts/data/field_plan.gd` (new value object)
Per-phase captain field setting — the field mirror of `IntentPlan`/`BowlingPlan`:
```
enum Mode { NEUTRAL, CATCHING, DEFENSIVE }   # NEUTRAL = 0 = no field set
const POWERPLAY_OVERS := 6
const DEATH_START_OVER := 16
var powerplay: int = Mode.NEUTRAL   # overs 1..6
var middle: int    = Mode.NEUTRAL   # overs 7..15
var death: int     = Mode.NEUTRAL   # overs 16..20
func for_over(over: int) -> int
static func neutral() -> FieldPlan        # all NEUTRAL (== no field)
static func catching() -> FieldPlan       # all CATCHING
static func defensive() -> FieldPlan      # all DEFENSIVE
```

### 4.2 `JokerEffect` — one new field + extended `matches()`
`var field_req: int = -1` (-1 = any field; else a `FieldPlan.Mode` value). `make()` gains a trailing `p_field_req: int = -1`. `matches()` gains a trailing `field_mode: int = FieldPlan.Mode.NEUTRAL` and a `field_ok := field_req == -1 or field_mode == field_req` gate. Defaults keep every existing joker (field_req -1) and every existing caller byte-identical.

### 4.3 `JokerResolver.roll_mults` — one new param
Trailing `field_mode: int = FieldPlan.Mode.NEUTRAL`, passed through to `matches()`. (Multi-buff needs no change: two same-`id` `JokerEffect` rows already multiply correctly into the wicket/runs split.)

### 4.4 `InningsResolver.simulate_innings` — one new trailing param
`field_plan: FieldPlan = null` (after `player_is_batting`). Per ball:
```
var field_mode := FieldPlan.Mode.NEUTRAL
if field_plan != null:
    field_mode = field_plan.for_over(over)
var jm := JokerResolver.roll_mults(jokers, player_is_batting, intent, balls + 1, field_mode)
```
Default null → NEUTRAL → field-gated jokers inert → existing callers unchanged. No new RNG draws → determinism preserved.

### 4.5 `MatchResolver.simulate_match` / `simulate_match_teams` — one new trailing param
`field_plan: FieldPlan = null`. The Player sets the field **while their team bowls**, so route `field_plan` to the **opposition's batting innings** (the `player_is_batting = false` calls in both toss branches) and pass `null` to the Player's own batting innings — exactly mirroring how `player_bowling_plan` routes. (#9-style "opposing field while batting" is deferred, so the Player's batting innings has no field.)

### 4.6 `JokerCatalog` — grouped implemented pool
- Keep `slice_v1()` unchanged (back-compat with existing tests/old sweep).
- Add `implemented_groups() -> Array` — the growing pool as **groups**, each `{ "id", "jname", "rarity", "effects": Array[JokerEffect] }`, so a multi-buff joker is one group with two effect rows. Returns all 11 (the 5 slice + 6 new).
- Add `implemented() -> Array` — flat concat of every group's effects (helper for callers that want the raw effect list).

## 5. The sweep deliverable — `tools/sweep_jokers.gd` (extended)
Switch from `slice_v1()` to `implemented_groups()`: one arm per group (config = the group's effects) + baseline + a batting stack + a field-defensive stack. Add a **shared `FieldPlan`** (CATCHING powerplay/death, DEFENSIVE middle) passed to `simulate_match_teams`, mirroring the existing shared `IntentPlan` — so each field joker fires in its matching phases and the field state is constant across arms (the win-delta is purely the joker). Emit the same JSON the viewer eats; refresh `docs/mockups/distribution-viewer-v1.html` `DATA`.

## 6. Testing (test-first, inline; red by parse-error, green by count climbing past 219)
1. **FieldPlan** — `for_over` phase mapping (over 6→pp, 7/15→middle, 16→death); `neutral`/`catching`/`defensive` factories.
2. **JokerEffect field gate** — field_req set fires only on matching field_mode; field_req -1 ignores field; field combines with side.
3. **JokerResolver field threading** — a field-gated joker contributes only when field_mode matches; default NEUTRAL → inert; existing-signature calls (no field arg) still work.
4. **multi-buff** — a two-row same-id joker products both wicket and runs mults.
5. **simulate_innings field_plan** — null == today (determinism vs no-field on same seed); a catching-field bowling wicket-booster raises wickets when `field_plan=catching` vs neutral on the same seed; determinism with a field_plan.
6. **simulate_match field routing** — a bowling field joker shifts win-rate vs baseline over N seeds; determinism with field_plan.
7. **JokerCatalog** — `implemented_groups()` returns 11; multi-buff groups have 2 effects; spot-check a field joker's `field_req` and a stateless leftover's fields; `implemented()` flat count = 13 rows (11 groups, 2 of them double).

Target ~13–16 new tests (219 → ~233+).

## 7. Non-goals / known
- **No intrinsic field EV** this rung (D2) — field is a joker-condition only; its own roll effect is a future tuning rung.
- No Form / DRS / Manager-Boost / windowed-trigger / setNextBowler-event / bowling-intent machinery (→ C2b–C2g).
- No opposition-side field, so #9 + captain-set field jokers wait.
- Joker stacking-cap question (pool §148) still open; the field stack arm is the next data point.
- Pre-existing HoF scene-test orphans unchanged (pure domain logic + a tool only).
- Determinism (same seed → same result) required and tested; byte-identical-core invariant already retired at PR #16 and new defaults are arithmetically identical anyway.

## 8. Decisions log (AFK defaults made here)
- **D1 — split C2 into C2a→C2g**, one new subsystem + its jokers per rung; this rung is **C2a (field mode)**. Rationale: the 40 remaining jokers need 6 distinct new subsystems; one-per-rung keeps the project's slice discipline and keeps each PR reviewable.
- **D2 — field mode is a readable captain *condition*, no intrinsic roll EV** this rung. Layer C wires jokers, not new gameplay levers; field's own EV is a documented future rung. Keeps scope tight + determinism trivial.
- **D3 — C2a joker set = #4/#6/#12 (stateless leftovers) + #16/#20/#23 (field)**, chosen to span multi-buff, combined intent+window, and catching/defensive × wicket/runs, using only conditions now in the sim.
- **D4 — multi-buff via duplicate-`id` rows** (no `JokerEffect` model change); the catalog groups them via `implemented_groups()`.
- **D5 — `FieldPlan` per-phase, NEUTRAL default, routed to the opposition's batting innings** (Player sets the field while bowling), mirroring `BowlingPlan` routing. No new RNG draws.
