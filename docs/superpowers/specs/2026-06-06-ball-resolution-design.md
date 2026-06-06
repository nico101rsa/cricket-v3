# Ball resolution — design spec

**Date:** 2026-06-06
**Theme:** 7a (Tech foundation → match sim core), smallest slice
**Status:** Approved (design shape) — ready for `writing-plans`
**Implements:** ADR 0004 (auto-sim architecture), ADR 0003 (skill model — Intent trade-off)
**Companion visual:** `docs/mockups/ball-resolution-v1.html`

---

## 1. Scope

This spec covers exactly **one pure function: resolving a single delivery**. It is the atom from which every higher rung of the match sim (over → innings → match) is composed.

**In scope:** the two-stage logistic contest for one ball — wicket roll, then (if survived) runs roll — including Intent coupling, determinism, and where tuning coefficients live.

**Out of scope (deferred to later rungs, do not build here):**
- The innings/over loop, strike rotation, opponent innings, chase logic, result.
- Deriving a bowler from `(teamStrength, role, seed)` — this function takes the bowler's two numbers raw.
- Key Moments / the UI that *sets* Intent — here Intent is just an input.
- Extras (wides, no-balls, byes), run-outs, runs on a wicket ball, dismissal type, shot type.
- The two open roadmap questions — **participation model** and **bowler-rotation policy** — are innings/match-level concerns. A single ball is blind to who bowls or how long the Player bats, so neither question blocks this slice.

## 2. The contract

A single pure function. No scene tree, no member state, no I/O.

```
BallResolver.resolve_ball(
    bat_power: int,          # batter Power
    bat_composure: int,      # batter Composure
    bowl_attack: int,        # bowler Attack
    bowl_control: int,       # bowler Control
    intent: Intent,          # DEFENSIVE | BALANCED | AGGRESSIVE
    tuning: BallTuning,      # all coefficients (data, not code)
    rng: RandomNumberGenerator
) -> BallOutcome
```

**`BallOutcome`** (lightweight `RefCounted`):
- `wicket: bool`
- `runs: int` — one of {0, 1, 2, 3, 4, 6}; always `0` when `wicket` is true.

**Attribute scale:** the four inputs share one open-ended scale. Creation gives 1–8 (per `Attributes`); Tons-upgrades push higher over a career. The logistic curves accept any real difference, so no clamping is needed.

**Where it lives:** `scripts/domain/ball_resolver.gd` (pure domain logic, project convention). `Intent` is an enum; `BallOutcome` and `BallTuning` are small resources/classes in `scripts/data/`.

## 3. Stage 1 — wicket roll (Composure vs Attack)

Worked in **log-odds** (the log of the odds of a wicket) so the curve is a clean logistic that saturates gracefully — extreme mismatches approach but never reach 0% or 100%.

```
logit_w = base_w + k_w * (bowl_attack - bat_composure) + intent_w[intent]
p_wicket = sigmoid(logit_w)        # sigmoid(x) = 1 / (1 + e^-x)
```

- `base_w` sets the even-contest baseline. Default tuned so even attributes + Balanced ≈ **3.5% per ball** (≈ a wicket every ~29 balls).
- `k_w` is the gain per attribute point of bowler advantage.
- `intent_w` shifts the odds (see §5).

The function draws `roll_w = rng.randf()`. If `roll_w < p_wicket` → return `{wicket: true, runs: 0}` (and stop — stage 2 is not reached).

## 4. Stage 2 — runs roll (Power vs Control)

Reached only when the ball is survived. A **scoring strength** `s ∈ (0,1)` blends a defensive runs template toward an aggressive one, then the result is sampled.

```
s = sigmoid(base_r + k_r * (bat_power - bowl_control) + intent_r[intent])
dist[v] = lerp(DEF[v], AGG[v], s)   for v in {0,1,2,3,4,6}
dist = normalize(dist)              # divide by sum so it totals 1.0
```

- `DEF` is the runs distribution at `s → 0` (mostly dots and singles, rare boundary).
- `AGG` is the distribution at `s → 1` (more 2s, 4s, 6s).
- `s = 0.5` (even contest, Balanced) sits halfway between them.

The function draws `roll_r = rng.randf()` and walks the cumulative distribution to pick the runs value. Return `{wicket: false, runs: <value>}`.

## 5. Intent coupling

`Intent` is one enum with three bands. It shifts **both** stages in the *same* direction, so aggression buys runs **and** risk together — this coupling is the expected-value trade-off that makes every Key Moment a real decision (ADR 0003).

| Intent | `intent_w` (wicket log-odds) | `intent_r` (scoring strength) |
|---|---|---|
| DEFENSIVE | −0.55 (safer) | −0.75 (fewer runs) |
| BALANCED | 0 | 0 |
| AGGRESSIVE | +0.60 (likelier out) | +0.80 (more runs) |

Magnitudes are strawman defaults (tuning data). The *mechanism* — coupled, single dial, both directions — is what this spec fixes.

## 6. Determinism

The whole sim is deterministic-seedable (ADR 0004) so the future harness can re-run thousands of seasons. `resolve_ball` is pure and consumes the passed `rng` in a **fixed order**:

1. Always draw `roll_w` first (the wicket roll).
2. Draw `roll_r` **only if** the ball is survived.

Same inputs + same RNG state → same outcome, every time. The caller (the future innings loop) owns the `rng` and calls `resolve_ball` in sequence; the stream advances by 1 draw on a wicket ball and 2 on a surviving ball.

## 7. Tuning data

All coefficients live in **data, never hardcoded** — the harness sweeps the data, not the code (ADR 0004). They are carried by a `BallTuning` resource:

```
base_w: float, k_w: float, intent_w: Array[float]   # [def, bal, agg]
base_r: float, k_r: float, intent_r: Array[float]
RUN_VALUES: [0, 1, 2, 3, 4, 6]   # const, the outcome alphabet
def_dist: Array[float]           # aligned to RUN_VALUES
agg_dist: Array[float]           # aligned to RUN_VALUES
```

**Strawman defaults** (what the companion visual encodes; the sanity targets in §9 follow from these):

| Field | Default |
|---|---|
| `base_w` | `ln(0.035 / 0.965) ≈ -3.3174` |
| `k_w` | `0.42` |
| `intent_w` | `[-0.55, 0.0, 0.60]` |
| `base_r` | `0.0` |
| `k_r` | `0.34` |
| `intent_r` | `[-0.75, 0.0, 0.80]` |
| `def_dist` | `[0.68, 0.255, 0.035, 0.004, 0.020, 0.006]` |
| `agg_dist` | `[0.30, 0.300, 0.090, 0.010, 0.200, 0.100]` |

These are deliberately provisional — the point of Theme 7c is to replace them with swept, measured values.

## 8. Test plan (TDD, red → green)

Pure function with an injected RNG → unit-testable in isolation. Tests assert **shape and relationships**, not exact tuned numbers:

1. **Determinism** — same seed + same inputs → identical outcome sequence over N calls.
2. **Outcome alphabet** — `runs` is always in {0,1,2,3,4,6}; a wicket always has `runs == 0`.
3. **Distribution integrity** — the blended runs distribution sums to 1.0 at any `s`.
4. **Wicket baseline** — over many seeded balls at even attributes + Balanced, the empirical wicket rate ≈ 3.5% (within tolerance).
5. **Wicket monotonicity** — raising `bowl_attack` raises the empirical wicket rate.
6. **Runs monotonicity** — raising `bat_power` raises mean runs per surviving ball.
7. **Intent coupling** — AGGRESSIVE vs DEFENSIVE (same attributes) yields **both** a higher wicket rate **and** higher mean runs.
8. **Saturation** — extreme mismatches stay strictly inside (0, 1); no crash, no NaN.

Statistical tests use a fixed seed and a generous tolerance so they are deterministic, not flaky.

## 9. Sanity targets (self-check, from §7 defaults)

A sane *innings* must emerge from sane *single balls*. With default tuning:

| Contest | Wicket %/ball | ≈ Balls/wkt | ≈ Expected score |
|---|---|---|---|
| Even (5v5), Balanced | ~3.5% | ~29 | **~33** |
| Bowler dominant (Attack 12 vs Composure 5) | ~41% | ~2.5 | **~2** |
| Batter edge (Composure 8 vs Attack 5) | ~1.0% | ~98 | **~115** |

These illustrate the *shape*; the harness will tune the actual values. **Known strawman wart:** the wicket curve saturates too generously at the batter-favoured extreme — a maxed edge (Composure 12 vs Attack 5) gives ~0.2%/ball and a ~600 score. This is exactly the kind of imbalance Theme 7c is built to find and tune out; it does not affect the *shape* approved here.

## 10. Open questions

None blocking. Performance note for a later rung: `BallOutcome` is a per-ball `RefCounted` allocation; if profiling the innings loop over a full harness sweep shows it as hot, revisit with a flat/packed return. Not a concern for the atom.
