# Player-as-bowler — design spec

**Date:** 2026-06-08
**Theme:** 7c balance harness — completes **layer B (skills)** by making the Player's bowling Attributes a real lever.
**Rung:** sim prep-rung (sits between 7b-2b Season loop and 7c-1's skills sweep).
**Status:** design — AFK build, default decisions recorded inline (per project `CLAUDE.md`).

---

## 1. The gap (why this rung exists)

The Player has four Attributes: **Power / Composure** (batting) and **Attack / Control** (bowling). The match sim consumes the batting pair every ball the Player is on strike. It consumes the bowling pair **only** to decide the Player's batting *position* (`InningsResolver.player_position`) — they never bowl a delivery.

When the Player's team fields, the whole side bowls with generic **team** numbers (`player_team_attack/control`, derived from the Team's ★). The Player as an individual never bowls. So Attack/Control are an **inert lever**: the 7c-1 harness measured a bowling build (2/2/8/8) winning ~48% of even ★3 matches — no better than balanced — purely because those points buy nothing the sim reads.

This rung wires the Player in as a bowler, so the *whole* build matters and the batting-vs-bowling allocation becomes a genuine strategic choice (ADR 0003 meta-layer).

## 2. The mechanic

**Build-driven bowling overs — the exact mirror of build-driven batting position.**

- A bowling-heavy build already bats *lower* (`player_position`). It should now also bowl *more overs*.
- Define `InningsResolver.player_overs(attrs, itun) -> int` returning **0–4** overs (T20's per-bowler max), driven by the same batting/bowling **share** that drives position:
  `share = (attack + control) / (power + composure + attack + control)`
  `overs = clampi(round(bowl_overs_gain * share + bowl_overs_base), 0, bowl_max_overs)`
- During the **opposition's batting innings** (the only innings the Player is fielding), the Player bowls that many overs. On a Player over, the batter on strike faces the **Player's** Attack/Control instead of the team's generic bowling numbers (or the textbook rotation profile). On every other over, nothing changes — the team bowls as today.

**Which overs are the Player's:** evenly spaced across the innings — over set computed as `round((i + 0.5) * total_overs / n)` for `i` in `0..n-1`. (Even spacing keeps the Player's overs sampling across phases when a pace/spin `BowlingPlan` is active; with no plan, opposition Intent is constant BALANCED so the *count*, not the *which*, is what moves the result.)

**Always on, not opt-in.** Unlike the `BowlingPlan` (an opt-in tactical layer), Player bowling is intrinsic: every Player bowls their build-appropriate quota. A pure batting build resolves to **0 overs**, which is byte-identical to today — so the "always on" default degrades gracefully to the old behaviour for batters.

### Worked strawman (with the defaults below: gain 8, base −2.5, max 4)

| Build | share | overs | reading |
|---|---|---|---|
| Batting (8/8/2/2) | 0.20 | **0** | specialist batter, doesn't bowl |
| Balanced (5/5/5/5) | 0.50 | **2** | part-time bowler, ~2 overs |
| Bowling (2/2/8/8) | 0.80 | **4** | frontline bowler, full quota |

The `base = −2.5` threshold means a build must invest real points in bowling before bowling at all; `gain = 8` gets the specialist to the full 4-over quota. These are **strawman tuning values** living in `InningsTuning` — the harness sweeps them like every other coefficient (that's the point of this whole theme). The table above is the intended *feel*, not a locked curve.

## 3. Code changes (all additive)

**`scripts/data/innings_tuning.gd`** — three new strawman fields:
```
@export var bowl_max_overs: int = 4
@export var bowl_overs_gain: float = 8.0
@export var bowl_overs_base: float = -2.5
```

**`scripts/domain/innings_resolver.gd`:**
- New static `player_overs(attrs: Attributes, itun: InningsTuning) -> int` (the share→overs map above).
- New static helper `player_bowling_overs(n: int, total_overs: int) -> Array[int]` (the evenly-spaced over set; returns `[]` for `n <= 0`).
- `simulate_innings(...)` gains three trailing optional params (defaults = off, so all existing callers and tests are unaffected):
  `player_bowler_attack: int = 0, player_bowler_control: int = 0, player_bowler_overs: int = 0`.
  When `player_bowler_overs > 0`, precompute the over set once; inside the ball loop, if the current `over` is a Player over, override `bat_attack`/`bat_control` with the Player's numbers (this override sits *after* the scalar/`BowlingPlan` profile assignment, so it wins for those overs).

**`scripts/domain/match_resolver.gd`:**
- In `simulate_match(...)`, compute the Player's bowling quota from `player_attrs` once (`InningsResolver.player_overs(player_attrs, itun)`) and thread the Player's `attack`/`control` + that count into the **opposition's batting innings** (the `player_attrs == null` innings — `innings2` when `player_bats_first`, else `innings1`).
- `simulate_match_teams(...)` needs **no new params** — it already receives the real `player_attrs` and passes it through.
- No new RNG draws are introduced (the override only swaps the inputs to existing `resolve_ball` calls), so the fixed draw order and determinism guarantees are unchanged.

## 4. Deliberate scope decisions (recorded defaults)

- **D1 — Always on, not opt-in.** Player bowling is intrinsic to the build, mirroring batting position. Opt-in (like `BowlingPlan`) was rejected: it would leave the lever invisible to the harness unless every caller opted in, and it misrepresents the game (the Player always fields). *Consequence:* this rung **intentionally breaks the byte-identical-core invariant** held since rung 3 — opposition innings outcomes shift for any non-pure-batting Player. This is the desired effect (bowling becomes real), not a regression. Determinism and directional tests stay valid; only an absolute-value snapshot test would need its expected number updated.
- **D2 — Overs are build-driven 0–4, not a fixed quota.** Reuses the existing share signal so one allocation drives *both* batting position and bowling load — the natural tension that makes the build a real choice. Strawman curve in `InningsTuning`, harness-tunable.
- **D3 — Evenly-spaced overs.** Cheapest deterministic rule that stays cricket-plausible and samples across phases under a `BowlingPlan`. *Which* overs barely moves the result today (opposition Intent is constant BALANCED), so the count is what matters; even spacing future-proofs it for when opposition Intent/rotation arrives.
- **D4 — Player bowls with raw Attack/Control, no pace/spin tilt.** The `BowlingAttack` tilt models a team's pace/spin options; the Player is one bowler with one profile. Tilting the Player's own delivery is out of scope (and meaningless without a Player bowling *type*, which we haven't designed). Deferred.
- **D5 — Player-as-bowler does not earn a bowling stat line yet.** `InningsResult` gains no Player bowling figures (wickets/runs-conceded) this rung — the deliverable headline is the **win-rate lever moving**. A Player bowling line is a small, clean follow-up if we want to surface bowling figures in the UI later.

## 5. Testing (test-first, inline)

New GUT tests under `tests/unit/`:

**`player_overs` mapping (`test_innings_resolver*` or a new file):**
- Pure batting build → 0 overs (threshold holds).
- Balanced build → 2 overs (strawman mid-point).
- Pure bowling build → 4 overs (clamped at max).
- Monotonic: more bowling share never yields fewer overs.

**`player_bowling_overs` set:**
- `n = 0` → `[]`; `n = 4`, total 20 → 4 distinct overs within `1..20`, evenly spread.

**`simulate_innings` Player-bowler param:**
- `player_bowler_overs = 0` → byte-identical to a call without the new params (off-by-default regression).
- Directional: a strong Player bowler (high attack/control) over many opposition innings concedes **fewer runs / takes more wickets** than a weak one, holding seed paired.
- Determinism: same seed + same Player-bowler inputs → identical `InningsResult`.

**`simulate_match` integration:**
- Determinism with a statted Player who bowls.
- **Directional lever:** over many paired-seed matches at even team strength, a **bowling-build** Player wins **more** than a pure-batting Player (the headline this rung exists to make true). This is the test that would have *failed* before the rung and passes after.

Judge red by the parse-error-on-missing-`class_name` convention; green by the suite count climbing past **184** and `All tests passed`.

## 6. Deliverable (eyeball / "see the lever")

Re-run the existing skills sweep (`tools/sweep_skills.gd`) — no harness change needed, it already varies the build and reports win-rate. Confirm the **bowling build's win-rate now rises above ~48%** (the inert lever is live). Add the win-rate-per-build figures to the chart caption / roadmap, and note the before→after shift. Optionally extend the demo to also report opposition runs conceded, but the win-rate move is the headline.

This closes the 7c-1 finding ("bowling build is no better than balanced") with the fix, completing **layer B (skills)** so the next layer (C jokers-in-sim) starts from a sim where the whole build is live.

## 7. Out of scope (deferred)

- Player bowling **type** (pace/spin) and tilt (D4).
- Player **bowling stat line** in `InningsResult` / scorecards (D5).
- Opposition **batting Intent** intelligence (still BALANCED) and opposition-side Player-equivalent bowlers (opponents stay derived).
- Bowler **husbanding** (pool/fatigue/decay) — still the deferred optional 4c.
- Re-tuning the strawman curve — a harness sweep target, not this rung.
