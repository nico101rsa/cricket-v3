# Jokers in the sim — vertical slice (Theme 7c, layer C) · design

**Date:** 2026-06-08 · **Status:** spec · **Rung:** 7c-C (first slice)
**Predecessors:** 7c-1 harness platform (PR #14), Player-as-bowler / layer B (PR #16), D5 bowling stat line (PR #17).
**Source of truth:** ADR 0006 (6-verb palette), ADR 0007 (authoring grammar), `docs/joker-pool-v1.md`.

---

## 1. What this rung is

Layer C of the 7c balance harness is "wire the 45 Jokers' effects into the sim, then sweep joker on/off → distribution shift, flag OP/weak." That is a big build. Per Nico's call (2026-06-08), this rung does a **vertical slice first**: build the reusable *effect-application seam* and wire **5 representative Jokers** end-to-end (catalog → sim → sweep → viewer), proving the pattern. A follow-up rung (7c-C2) scales to the remaining ~40 and adds the verbs this slice deliberately defers.

**Success = ** the harness can run a real joker on/off sweep over even ★3 matches and show, per joker, how the player-runs distribution and win-rate move — using the same `Sweep`/`Distribution`/viewer from 7c-1.

## 2. The core insight that shapes the seam

`BallResolver.resolve_ball()` (the atom) produces exactly two rolls:
- a **wicket roll** — `p_wicket = sigmoid(...)`, the chance the batter is out this ball;
- a **runs roll** — a scoring-strength `s = sigmoid(...) ∈ [0,1]` that blends the defensive→aggressive run distribution.

The `buffNextBalls(roll, mult, n)` verb — a windowed multiplier on the wicket or runs roll — is the numeric heart of the palette, and the overwhelming majority of the pool's Jokers resolve to a conditional `buffNextBalls(wicket|runs, mult)`. So the seam is: **let an active-joker layer multiply `p_wicket` and/or `s` per ball.** Everything else (which jokers, under what conditions) is data evaluated against the ball context.

Uniform math, side-independent: a *batting* "wicket ×0.92" (Dead Bat) makes the batter safer; a *bowling* "wicket ×1.10" (Cordon Killer) makes the opposition batter likelier to fall. Both just multiply the same `p_wicket`. The joker's **side** decides *whether it is active this innings*, not the arithmetic.

## 3. Scope — the slice boundary (decisions recorded here, AFK defaults)

**In scope — the stateless "while CONDITION: buffNextBalls(wicket|runs, mult, n=1) per ball" sub-grammar**, for conditions the sim *already tracks*:
- Intent band (per over, via `IntentPlan` — already in the player's batting innings).
- Innings ball-count windows (we have the ball number).
- Innings side — batting vs bowling, relative to the joker owner (the Player).

**Out of scope — deferred to 7c-C2** (each needs new sim machinery this slice will not build):
- **Windowed trigger buffs** — "when Y *fires*: buff for the next n balls" (Pace Pack, Ride the Wave, …). The slice does only the *stateless per-ball* form (`n=1`, re-checked every ball). The decaying-window form needs a per-innings buff-window counter — its own rung.
- **`formEvent` / Form points** — the sim has no Form counter. (All Anchor/Tempo Form-trigger jokers wait.)
- **`tryReview` / DRS** — no review resource in the sim.
- **`fieldMode(catching|defensive)`** — no field state in the sim.
- **`setNextBowler` *firing* events** — we have `BowlingPlan` per-over types but no "a change just fired" event.
- **Manager-Boost-sourced buffs** — no Manager Boost in the sim.
- **Bowling-side intent** — the opposition bats Balanced; no bowling-captain intent band. So bowling-side jokers in the slice use **ball-window conditions only**, never intent.

**Why this slice:** it spans both roll targets (wicket, runs), both directions (help-batting, help-bowling), both sides, and both condition kinds (intent band, ball window), across Common + Rare rarities — the full shape of the most common joker form — without dragging in five separate new subsystems. It is the smallest end-to-end proof of the pattern.

## 4. The 5 slice Jokers (from `docs/joker-pool-v1.md`, magnitudes verbatim)

| # | Name | Rarity | Side | Condition | Target | mult |
|---|---|---|---|---|---|---|
| 1 | Dead Bat | Common | batting | intent = Defensive | wicket | ×0.92 |
| 8 | Powerplay Punch | Common | batting | intent = Aggressive | runs | ×1.10 |
| 3 | Block the Shine | Common | batting | innings ball ≤ 18 | wicket | ×0.90 |
| 17 | Squeeze the Middle | Common | bowling | innings ball ∈ [36, 90] | runs | ×0.92 |
| 21 | Death-Over Stranglehold | Rare | bowling | innings ball ≥ 90 | runs | ×0.80 |

(Note: Block the Shine's pool text is a one-shot 18-ball window "at innings start"; modelled here in its equivalent stateless form "while ball ≤ 18" — identical result for a batter who opens, and the only stateless reading available this slice.)

## 5. Components

### 5.1 `JokerEffect` — `scripts/data/joker_effect.gd` (new value object)
One joker as a per-ball conditional roll modifier — a pure data tuple (ADR 0007 "data-entry, no code per joker"):
```
enum Target { WICKET, RUNS }
enum Side { BATTING, BOWLING }
var id: String           # short slug, for sweep labels
var jname: String        # display name ("jname" — avoid Godot `name` collision)
var rarity: String       # "Common" / "Rare" / "Legendary" (label only this slice)
var side: Side
var target: Target
var mult: float
var intent_req: int = -1 # -1 = any; else a BallResolver.Intent value
var ball_min: int = 1    # inclusive innings-ball window
var ball_max: int = 120
# matches(player_is_batting, intent, ball) -> bool
#   side gate: (side==BATTING) == player_is_batting
#   intent gate: intent_req == -1 or intent == intent_req
#   ball gate: ball_min <= ball <= ball_max
```

### 5.2 `JokerResolver` — `scripts/domain/joker_resolver.gd` (new, static, pure)
The model-agnostic stack the harness sweeps:
```
# Product of all matching jokers' mults, split by target.
static func roll_mults(jokers, player_is_batting, intent, ball) -> Vector2:
    # returns Vector2(wicket_mult, runs_mult); empty/no-match -> (1.0, 1.0)
```

### 5.3 `JokerCatalog` — `scripts/data/joker_catalog.gd` (new, static)
`slice_v1() -> Array[JokerEffect]` returns the 5 authored jokers above (shared by tests + sweep). One JokerEffect per row of §4.

### 5.4 `BallResolver.resolve_ball` — two new trailing params
`wicket_mult: float = 1.0, runs_mult: float = 1.0`. Applied as:
- `p_wicket = clampf(sigmoid(logit_w) * wicket_mult, 0.0, 1.0)`
- `s = clampf(sigmoid(...) * runs_mult, 0.0, 1.0)`

Defaults 1.0 → arithmetically identical to today. **RNG draw order and count are unchanged** (wicket draw always; runs draw iff survived) → determinism preserved.

*Interpretation recorded:* "runs roll ×m" = scale the scoring-strength `s` (nudges the run distribution toward aggressive, bounded/clamped); "wicket roll ×m" = scale `p_wicket`. Both strawman, harness-tunable later — magnitudes come from the pool.

### 5.5 `InningsResolver.simulate_innings` — two new trailing params
`jokers: Array[JokerEffect] = [], player_is_batting: bool = true`. Per ball, before `resolve_ball`:
```
var ball_num := balls + 1
var jm := JokerResolver.roll_mults(jokers, player_is_batting, intent, ball_num)
# ... resolve_ball(..., jm.x, jm.y)
```
Empty jokers → `(1,1)` → unchanged. Default `[]` keeps every existing caller byte-identical.

### 5.6 `MatchResolver.simulate_match` / `simulate_match_teams` — one new trailing param
`jokers: Array[JokerEffect] = []`. The Player owns the jokers; pass the **same list to both innings**, with `player_is_batting = true` for the Player's batting innings and `false` for the opposition innings. Each joker self-selects by `side`, so a batting joker is inert in the opposition innings and vice-versa. Threads through the existing `player_bats_first` branch unchanged otherwise.

## 6. The sweep deliverable — `tools/sweep_jokers.gd` (new)
Mirrors `tools/sweep_skills.gd`. Arms = **baseline (no jokers)** + each of the 5 jokers individually + a **batting-stack** arm (the 3 batting jokers together). Even ★3 vs ★3, balanced player build (5/5/5/5) so the *jokers* are the only lever, `n` matches each, scenario returns `{player_runs, won}`. Emits the same JSON the viewer eats (swap `DATA` in `docs/mockups/distribution-viewer-v1.html`). Read-out per arm: player-runs distribution + **win-rate delta vs baseline** — the OP/weak flag.

## 7. Testing (test-first, inline; judge red by parse-error, green by count climbing past 197)
1. **JokerEffect.matches** — side gate (batting joker inert when bowling), intent gate (Defensive joker off under Balanced), ball-window gate (in/out of range), and a fully-matching case true.
2. **JokerResolver.roll_mults** — empty → (1,1); single match on each target; two jokers same target → product; non-matching excluded; batting/bowling split.
3. **resolve_ball mults** — `wicket_mult=1.0, runs_mult=1.0` == baseline (same seed, identical outcome); `wicket_mult<1` lowers wicket rate over N balls; `runs_mult>1` raises mean runs over N balls.
4. **simulate_innings** — a batting wicket-reducer (Dead Bat under an all-Defensive plan) yields fewer wickets / ≥ score vs no joker on the same seed; determinism with jokers (same seed twice → identical result); empty jokers == today.
5. **simulate_match** — over N seeds, the batting-stack raises player win-rate vs baseline; a bowling joker (Death-Over Stranglehold) raises win-rate vs baseline; determinism with jokers.
6. **JokerCatalog.slice_v1** — returns 5; spot-check one batting + one bowling joker's fields.

Target: ~12–16 new tests (197 → ~210+).

## 8. Eyeball
Refresh `docs/mockups/distribution-viewer-v1.html` `DATA` with the `sweep_jokers.gd` output so Nico can see each joker's curve + win-rate shift overlaid against baseline.

## 9. Non-goals / known
- Not building Form/DRS/field/Boost/windowed-trigger machinery (→ 7c-C2).
- Joker *stacking-cap* question (pool §148) is out of scope — multiplicative stacking stands for the slice; the sweep's batting-stack arm is the first data point on whether a cap is needed.
- Pre-existing HoF scene-test orphans unchanged (this rung adds only pure domain logic + a tool).
- Byte-identical-core invariant already retired at PR #16; new defaults here are arithmetically identical anyway.

## 10. Decisions log (AFK defaults made here)
- **D1 — vertical slice, 5 jokers** (Nico's explicit call). Pattern-proof over completeness.
- **D2 — slice only the stateless per-ball `buffNextBalls(wicket|runs)` sub-grammar**; defer windowed-trigger + Form/DRS/field/Boost verbs. Smallest end-to-end seam.
- **D3 — joker set chosen to span both targets/directions/sides + intent & ball-window conditions + Common/Rare**, using only conditions already in the sim.
- **D4 — seam lives in `resolve_ball` (two mult params)**, computed by a pure `JokerResolver` from a `JokerEffect` data tuple; mirrors how `IntentPlan`/`BowlingPlan` thread as optional trailing params.
- **D5 — "runs ×m" scales `s`, "wicket ×m" scales `p_wicket`, both clamped [0,1]; RNG draw count unchanged** → determinism preserved.
- **D6 — bowling-side slice jokers use ball-window conditions only** (no bowling-captain intent modelled yet).
