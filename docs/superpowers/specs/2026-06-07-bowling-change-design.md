# Bowling Change — design spec

**Date:** 2026-06-07
**Theme:** 7a (Tech foundation → match sim core), rung 4b (ball → innings → match → Intent (4a) → **Bowling Change**). Rung 4 was split into 4a (Intent, shipped PR #7) + 4b (this).
**Status:** Approved (design shape) — ready for `writing-plans`
**Builds on:** `InningsResolver.simulate_innings()` + `MatchResolver.simulate_match()` (incl. the rung-4a `IntentPlan` seam)
**Implements:** ADR 0004 (auto-sim — headless, deterministic-seedable) + the `setNextBowler(type)` verb of ADR 0006 + ADR 0003 (the choice must be a no-dominant-answer EV trade-off)

---

## 1. Scope

Today every ball in an innings faces a single **constant** `(attack, control)` bowling pair. This rung replaces that with a **per-over bowler-type rotation**: two bowler types — **pace** and **spin** — each with a differentiated `(attack, control)` profile, selected per match phase via a `BowlingPlan` (the mirror of rung-4a's `IntentPlan`).

This is the **thinnest viable bowling rotation** (simplest-first). It is the clean counterpart to Intent: where `IntentPlan` is the Player's *batting* posture per phase, `BowlingPlan` is the Player's *bowling* choice per phase — the output of the **Bowling Change Key Moment** (`setNextBowler(type)`). The opposition bowls to a fixed default plan (the simplest "AI rotation policy").

**Why the two types make it a real decision (ADR 0003).** The profiles are *tilted* opposites of the same base bowling strength:
- **Pace** = attack-tilted: *more* wickets **and** *more* runs conceded (higher Attack, lower Control).
- **Spin** = control-tilted: *fewer* runs **and** *fewer* wickets (lower Attack, higher Control).

So neither dominates: deploy pace when you need wickets (a chase running away), spin when you need containment (defending a small total at the death). The conditional is for the player to discover — no surfaced math.

**In scope:**
- A `BowlingAttack` value object: derives the pace and spin `(attack, control)` profiles from a base bowling pair + a tilt constant.
- A `BowlingPlan` value object: one bowler **type** per phase (Powerplay 1–6 / Middle 7–15 / Death 16–20), with `for_over()` lookup and factories.
- Threading both, as optional trailing params, through `simulate_innings()` (per-over profile selection) and `simulate_match()` (route the Player's plan to the innings where the Player's team bowls; opposition uses a default plan).
- Backward-compatible defaults: no `BowlingPlan` → the existing constant-pair behaviour, byte-identical to rung 4a.

**Out of scope (deferred — do not build here):**
- **Bowler husbanding** — a finite pool of individually-tracked bowlers, the **T20 4-over-per-bowler cap**, and fatigue/**decay** within a spell. This rung models *types*, not individual bowlers, so there is no scarcity to husband yet. → a follow-on rung **4c** if playtesting wants it.
- **The Player as a statted bowler.** Team bowling is derived from team strength; the Player's own Attack/Control still do not feed the sim (they affect batting position + the classifier label only, as today). Player-as-bowler → later rung.
- **A "wildcard" third bowler type.** The DESIGN_HANDOFF KM blurb lists "Spinner vs Wildcard vs Pace", but ADR 0006's `setNextBowler(type)` is pace/spin. Build the two-type model per the authoritative palette; a wildcard can be a Joker-flavoured variant later.
- **Adaptive opponent AI.** The opposition bowls a fixed default `BowlingPlan` (deterministic); a reactive opponent policy is later.
- **Per-batter matchup** (left/right, bowler-vs-batter tilts), the **Field Set KM** (`fieldMode`, fires alongside bowling changes), reactive Intent, the swipe-card UI, the star→numbers pipeline + toss (7b), Form, Jokers, Manager Boost, extras, run-outs.

## 2. `BowlingAttack` — the two type profiles

A lightweight value object (`RefCounted`, transient per-match derived data — not saved tuning), at `scripts/data/bowling_attack.gd`.

Constructed from a base bowling pair and a tilt:

```
BowlingAttack.new(base_attack: int, base_control: int, tilt: int = DEFAULT_TILT)
```

`const DEFAULT_TILT := 2` — strawman, the balance harness sweeps it later (documented like `IntentPlan`'s phase constants).

It exposes the derived profiles, each clamped to a floor of 1 (attributes never drop below 1):

```
pace_attack    = max(1, base_attack + tilt)
pace_control   = max(1, base_control - tilt)
spin_attack    = max(1, base_attack - tilt)
spin_control   = max(1, base_control + tilt)
```

And a lookup by type that returns the pair as a `Vector2i(attack, control)`:

```
profile(kind: int) -> Vector2i      # kind is BowlingPlan.Kind
    PACE -> Vector2i(pace_attack, pace_control)
    SPIN -> Vector2i(spin_attack, spin_control)
```

`BowlingAttack` knows nothing about overs, plans, or RNG — it is a pure strength → two-profiles derivation, testable on its own.

## 3. `BowlingPlan` — the per-phase type choice

A lightweight value object (`RefCounted`), at `scripts/data/bowling_plan.gd`. The bowling mirror of `IntentPlan`.

```
enum Kind { PACE, SPIN }            # named Kind (not Type) to avoid built-in collisions

const POWERPLAY_OVERS := 6          # aligns with IntentPlan / T20 powerplay
const DEATH_START_OVER := 16        # aligns with IntentPlan death overs

powerplay: int = Kind.PACE          # overs 1..6
middle:    int = Kind.SPIN          # overs 7..15
death:     int = Kind.PACE          # overs 16..20
```

(The field defaults already encode the "textbook" shape — pace in the powerplay, spin through the middle, pace at the death — because there is no neutral "balanced" bowler type the way there is a BALANCED intent. A plain `BowlingPlan.new()` is therefore the sensible default rotation.)

```
for_over(over: int) -> int          # 1-based over -> Kind (same phase logic as IntentPlan)
```

Factories (static):
- `BowlingPlan.textbook()` — pace / spin / pace (same as the defaults; named for clarity at call sites and tests).
- `BowlingPlan.pace_only()` — PACE in all three phases (for the directional test + an all-out-attack policy).
- `BowlingPlan.spin_only()` — SPIN in all three phases (containment).

## 4. Threading through `simulate_innings()`

Two new optional trailing params (after the rung-4a `intent_plan`):

```
simulate_innings(
    player_attrs, partner_batting, opp_attack, opp_control,
    tuning, itun, rng,
    target: int = 0,
    intent_plan: IntentPlan = null,
    bowling_attack: BowlingAttack = null,   # NEW
    bowling_plan: BowlingPlan = null         # NEW
) -> InningsResult
```

Per-ball bowling resolution (mirrors the rung-4a intent lookup, using the same `over = balls / 6 + 1`):

```
var over := balls / 6 + 1
var bat_attack := opp_attack          # scalar fallback (rung-3/4a behaviour)
var bat_control := opp_control
if bowling_attack != null and bowling_plan != null:
    var prof := bowling_attack.profile(bowling_plan.for_over(over))
    bat_attack = prof.x
    bat_control = prof.y
# ... resolve_ball(s.power, s.composure, bat_attack, bat_control, intent, tuning, rng)
```

When either new param is `null`, the constant `opp_attack`/`opp_control` is used — **byte-identical to rung 4a**. (The pre-existing `opp_attack`/`opp_control` params stay; they are the base for the scalar path and are *not* used to build the profiles inside the innings — the caller passes a ready-made `BowlingAttack`.)

## 5. Threading through `simulate_match()`

One new optional trailing param — the Player's bowling choice (the Bowling Change KM output):

```
simulate_match(
    ... existing params incl. player_intent_plan ... ,
    player_bowling_plan: BowlingPlan = null   # NEW
) -> MatchResult
```

**Opt-in semantics (preserves rung-3/4a determinism):** when `player_bowling_plan == null`, no rotation happens on either side — every innings uses its constant scalar pair, exactly as before. Passing a plan turns rotation on for **both** sides (it is a feature you enable):

- **Player's team bowling** (faced by the opposition when they bat): `BowlingAttack(player_team_attack, player_team_control)` + `player_bowling_plan`.
- **Opposition bowling** (faced by the Player when they bat): `BowlingAttack(opp_attack, opp_control)` + a **default `BowlingPlan.textbook()`** (the simplest AI rotation).

Routing by toss (symmetric with how `intent_plan` routes to the Player's *batting* innings — `bowling_plan` routes to the innings where the Player's team *bowls*, i.e. the opposition's batting innings):

- **Player bats first:** innings1 = Player batting (faces opp `BowlingAttack` + textbook AI plan); innings2 = opposition batting (faces Player team `BowlingAttack` + `player_bowling_plan`).
- **Player bats second:** innings1 = opposition batting (faces Player team `BowlingAttack` + `player_bowling_plan`); innings2 = Player batting (faces opp `BowlingAttack` + textbook AI plan).

The batting `intent_plan` continues to route to the Player's batting innings exactly as in rung 4a; the two seams are independent.

## 6. Backward compatibility

`player_bowling_plan` defaults to `null` → no `BowlingAttack`/`BowlingPlan` is constructed → both innings run the constant scalar pair → **byte-identical to rung 4a**. Every existing innings-level and match-level test must stay green unchanged. Determinism holds: the new value objects consume no RNG, and `resolve_ball`'s draw order is unchanged.

## 7. Test plan (TDD, red → green)

Per project `CLAUDE.md`: judge **red** by `Parse Error: Identifier "BowlingAttack"/"BowlingPlan" not declared` (GUT skips the file), **green** by the total count climbing past 144 and `All tests passed`. Statistical tests use fixed seeds + generous tolerances.

`BowlingAttack` unit tests (pure, no RNG):
1. **Tilt direction** — for a base `(5, 5)` with default tilt: `profile(PACE)` has `attack > control` and `profile(SPIN)` has `control > attack`; and `pace.attack > spin.attack`, `spin.control > pace.control`.
2. **Floor clamp** — a base `(1, 1)` never yields a profile component below 1.

`BowlingPlan` unit tests (pure):
3. **Phase mapping at boundaries** — `for_over` returns the powerplay band for overs 1 & 6, middle for 7 & 15, death for 16 & 20.
4. **Factories** — `textbook()` = PACE/SPIN/PACE; `pace_only()` = all PACE; `spin_only()` = all SPIN. A bare `BowlingPlan.new()` equals `textbook()`.

`simulate_innings()` tests:
5. **Backward compatibility** — `bowling_attack`/`bowling_plan` null reproduces the existing rung-4a result for a fixed seed (identical `InningsResult`).
6. **Determinism with rotation** — same seed + same `BowlingAttack` + `BowlingPlan` → identical `InningsResult` across repeated calls.
7. **Directional sanity** — over N seeded innings (Intent held BALANCED to isolate the bowling effect), an all-`pace_only()` attack yields **more total wickets** *and* a **higher aggregate run rate** (Σruns / Σballs) than an all-`spin_only()` attack. (Run *rate*, not total runs: pace takes more wickets, which can end an innings early and truncate the total — run rate isolates the per-ball tilt from innings length, so the EV trade-off shows cleanly.)

`simulate_match()` tests:
8. **Backward compatibility** — `player_bowling_plan` null reproduces the rung-4a `MatchResult` for a fixed seed (existing match tests also stay green by construction).
9. **Routing** — using the first-innings-uses-initial-RNG isolation trick (as in rung 4a): with `player_bats_first = false`, innings1 is the opposition batting against the Player's team bowling, so it must equal a standalone opposition innings simulated with the Player's team `BowlingAttack` + `player_bowling_plan` at the same seed. (The Player's bowling plan reached the right innings.)
10. **Determinism with a plan** — same inputs + seed + `player_bowling_plan` → identical `MatchResult` across repeated calls.

## 8. What this de-risks / sets up

- Gives the *bowling* side its first real decision lever — the symmetric partner to rung-4a Intent. The two together let the ADR 0003 skill-gap metric vary both batting posture and bowling type.
- Confirms the per-phase type model expresses the Bowling Change KM (`setNextBowler`) without individual-bowler machinery.
- Leaves clean seams: husbanding (pool + 4-over cap + decay) layers in at 4c behind the `BowlingAttack`/`BowlingPlan` seam; the live in-match swipe-card (Theme 6) later writes the `BowlingPlan` instead of the harness/factory; the Season wrapper (7b) supplies the base bowling pairs from the star→numbers pipeline.

## 9. Open questions

None blocking. Confirmed deferrals (with landing rungs):
- **Bowler husbanding** (finite pool, 4-over cap, decay) → follow-on rung 4c (only if playtesting wants the scarcity layer).
- **Player as a statted bowler** → later rung (opens a bowling-participation sub-design).
- **Wildcard third type** → later, likely Joker-flavoured.
- **Adaptive opponent bowling AI** → later; fixed `textbook()` default for now.
- **Field Set KM** (`fieldMode`, fires with bowling changes) → its own KM rung.
- **Star → numbers pipeline + toss** → Season wrapper (7b).
