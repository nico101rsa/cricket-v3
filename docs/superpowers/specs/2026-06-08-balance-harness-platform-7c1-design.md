# Balance harness platform (7c-1) — sweep engine · distribution stats · before/after viewer — design spec

**Date:** 2026-06-08
**Theme:** 7c (balance harness). Rung **7c-1** — the **platform** (layer A of the 7c decomposition). Later rungs add the *models* it sweeps: skills (B), jokers-in-sim (C), the ₸ economy (D), and the self-play decision AI (E).
**Status:** Approved (design shape — autonomous/AFK, decisions recorded below) — ready for `writing-plans`
**Builds on:** the complete Season loop (`SeasonResolver`, `LeagueResolver`, `MatchResolver`, `Team`, `TourDistribution`) + the throwaway `tools/*_preview.gd` runners this generalises
**Implements:** ADR 0004 (headless, deterministic-seedable — the design that makes a balance harness possible)

---

## 1. Scope & intent

Nico's 7c vision is large (run thousands of scenarios; see how **skills vs jokers** spending shifts the outcome distribution; model the **₸ economy**; an **AI that self-plays to find optimal strategies** and is throttled per Level). That is a multi-rung theme. **This rung builds only the platform** — the reusable lens every later layer is viewed through — and proves it on the one model that fully works today (Player **build / skills**).

The platform answers, generically: *"run N scenarios for each of several configs ('arms'), and show how the outcome distribution shifts between them (before/after)."*

Three reusable pieces + one demo:
1. **`Distribution`** — summary stats (mean, sd, min, max) + a histogram from a list of numbers.
2. **`Sweep`** — run `arms × N` seeded scenarios through a caller-supplied scenario `Callable`, collecting metric records; **paired seeds across arms** (same seed sequence per arm) so arm-to-arm differences aren't RNG noise.
3. **A generic distribution-overlay viewer** (HTML) — overlaid histograms of a chosen metric across arms + a summary table. Reused by every future sweep by swapping the inlined data.
4. **Demo: the skills sweep** — vary the Player's Attribute build, hold everything else even, and visualise the **player-runs distribution shift** + win-rate per build. This both proves the platform and surfaces a real finding (batting attrs move the distribution; bowling attrs are currently inert — the Player-as-bowler gap).

**In scope:** `Distribution`, `Sweep` (pure, tested); a demo runner `tools/sweep_skills.gd` that prints JSON; the reusable viewer `docs/mockups/distribution-viewer-v1.html` rendering the demo.

**Out of scope (later 7c rungs / deferred):**
- **Jokers-in-sim (C)** — the 45 Jokers' 6-verb effects aren't wired into the sim; building them is its own rung, *then* a joker sweep. Not here.
- **₸ economy (D)** — earning ₸ from performance, prices, the skills-vs-jokers spend ROI. Needs B + C. Not here.
- **Self-play / decision AI + the optimal-vs-naive skill-gap metric + per-Level difficulty throttling (E)** — the crown jewel; its own mini-project once B/C/D exist. Not here.
- **Player-as-bowler** — the Player's Attack/Control still don't feed the sim, so the skills demo will show bowling attrs as inert. That's a *finding to surface*, not something this rung fixes.
- **Writing data files to disk / a live in-engine dashboard.** Data is **printed as JSON and inlined into the HTML** (the established `*_preview` pattern — avoids `file://` CORS and keeps charts self-contained). A disk/dashboard pipeline can come later if sweeps get large.

## 2. Recorded design decisions (AFK)

- **D1 — Platform first, demo on skills.** Confirmed with Nico (chose option A). The platform is generic; skills is the demo because it's the only model that already affects the sim.
- **D2 — Paired seeds across arms.** Arm *k*'s *i*-th scenario uses `base_seed + i`, the same for every arm. So comparing arms holds the RNG fixed — the distribution shift is the *config's* effect, not seed luck. (This is the right default for before/after.)
- **D3 — Scenario as a `Callable`.** `Sweep.run(arms, n, scenario, base_seed)` takes `scenario: Callable(config, rng) -> Dictionary`. Keeps `Sweep` model-agnostic — a season sweep, a match sweep, a future joker sweep all reuse it. The metric record is a plain Dictionary of named numbers.
- **D4 — Data via inlined JSON.** Runner prints a JSON blob; it's pasted into the viewer's `const DATA`. Consistent with every prior chart; no disk I/O.
- **D5 — Demo at match level, even teams.** The skills signal is cleanest with both teams equal (★3 vs ★3) so the Player's build is the only lever; per-match `player_runs` gives a rich continuous distribution to overlay. (A season-level sweep also works through the same `Sweep` — match is just the clearest demo.)

## 3. `Distribution` — stats + histogram

`scripts/harness/distribution.gd` (a new `scripts/harness/` folder for balance-tooling that is tested library code, distinct from the throwaway `tools/` runners):

```
class_name Distribution extends RefCounted

var values: Array = []

func _init(vals: Array = []) -> void:
	values = vals

func count() -> int
func mean() -> float                       # 0.0 if empty
func sd() -> float                          # population sd; 0.0 if <2 values
func minimum() -> float                     # 0.0 if empty
func maximum() -> float                     # 0.0 if empty
func histogram(bins: int, lo: float, hi: float) -> Array
	# Array[int] of length `bins`; each value mapped to bin floor((v-lo)/(hi-lo)*bins),
	# clamped to [0, bins-1] so out-of-range values fall in the end bins.
func to_dict() -> Dictionary               # {count, mean, sd, min, max}
```

Pure, no RNG. The numeric workhorse the viewer and tests use.

## 4. `Sweep` — run arms × seeds

`scripts/harness/sweep.gd`:

```
class_name Sweep extends RefCounted

# arms: Array of {name: String, config: Variant}
# scenario: Callable(config, rng: RandomNumberGenerator) -> Dictionary (metric record)
# Returns: Array of {name: String, records: Array[Dictionary]} in arm order.
# Paired seeds: arm k's i-th run uses base_seed + i (same across arms).
static func run(arms: Array, n: int, scenario: Callable, base_seed: int = 1) -> Array

# Extract one numeric field across an arm's records into a flat Array.
static func values_of(records: Array, field: String) -> Array
```

Determinism: same `arms`/`n`/`scenario`/`base_seed` → identical records. `Sweep` knows nothing about cricket — it just drives the Callable.

## 5. Demo runner — `tools/sweep_skills.gd`

A `SceneTree` script (like the other `tools/` runners). Defines:
- **Scenario** `func(config, rng) -> Dictionary`: build an `Attributes` from `config` (a `Vector4i`-ish dict of power/composure/attack/control), run one `MatchResolver.simulate_match_teams(player_attrs, Team(★3), Team(★3), tour, …, rng)`, and return `{player_runs, won}` where `player_runs` = the Player's runs that innings (from the Player's batting `InningsResult.player_line()` / the `is_player` batter) and `won` = 1 if `outcome == PLAYER_WIN` else 0.
- **Arms**: `[{name:"Batting build (8/8/2/2)", config:{power:8,composure:8,attack:2,control:2}}, {name:"Balanced (5/5/5/5)", config:{5,5,5,5}}, {name:"Bowling build (2/2/8/8)", config:{2,2,8,8}}]`.
- Calls `Sweep.run(arms, N, scenario)` with N ≈ 2000, builds, per arm, a `Distribution` of `player_runs`, and prints a JSON blob:

```
{"metric":"player_runs",
 "arms":[{"name":"...","values":[...],"stats":{...},"win_rate":0.50}, ...]}
```

(`values` capped/strided to a few hundred for inlining if needed; `stats` + `win_rate` computed over all N.)

## 6. Viewer — `docs/mockups/distribution-viewer-v1.html`

A self-contained, **reusable** page: a `const DATA = {metric, arms:[{name,color,values,stats,win_rate}]}` (the demo's JSON pasted in) and a renderer that draws **overlaid semi-transparent histograms** of `values` per arm on a shared axis (auto-scaled to the pooled min/max), a vertical mean line per arm, and a summary table (per arm: mean ± sd, min–max, win-rate). A caption frames it as the **before/after distribution-shift** lens. Future sweeps reuse this file by replacing `DATA`.

The demo view shows the three build histograms: batting-heavy shifted right (more player runs), bowling-heavy left/inert, balanced between — with win-rate revealing bowling attrs as a non-lever today.

## 7. Backward compatibility & determinism

Purely additive: new `scripts/harness/` library + new `tools/` runner + new mockup. No existing file changes; all 177 tests stay green. `Sweep`/`Distribution` are deterministic and RNG-free except `Sweep` constructing seeded RNGs in a fixed order.

## 8. Test plan (TDD, red → green)

Per project `CLAUDE.md`: red by parse error, green by count climbing past 177. `--import` after adding the new `scripts/harness/` files.

`Distribution` (pure):
1. **Stats** — for `[2,4,4,4,5,5,7,9]`: `mean()==5.0`, `sd()≈2.0`, `minimum()==2`, `maximum()==9`, `count()==8`. Empty → mean/min/max `0.0`, count 0.
2. **Histogram** — `histogram(5, 0, 10)` on known values puts each in the right bin; an out-of-range value (e.g. 12) lands in the top bin, a negative in the bottom bin; the counts sum to `count()`.

`Sweep` (seeded):
3. **Shape** — `run(arms, n, scenario)` returns one entry per arm, each with `n` records; `values_of` pulls the right field with `n` entries.
4. **Determinism + paired seeds** — same inputs → identical records across calls; and a scenario that returns `{seed_used: rng.seed}`-style determinism check shows arm 0 and arm 1 received the *same* seed sequence (paired).
5. **Arms differ by config, not seed** — a scenario returning `{v: config}` yields each arm's records all equal to that arm's config (sanity that config is threaded, seeds are shared).

(The demo runner §5 + viewer §6 have no unit tests — their directional claim, "batting build outscores bowling build," is implicitly the existing match directional behaviour; eyeballed in the browser.)

## 9. What this de-risks / sets up

- Gives Nico the **"run 1000s of scenarios + see the distribution shift before/after"** capability immediately, on real sim output.
- `Sweep` + `Distribution` + the viewer are the **reusable substrate** for every later 7c layer: the joker sweep (C) overlays joker-on vs joker-off through the *same* pieces; the economy (D) and self-play (E) emit metrics into the *same* `Sweep`.
- The skills demo surfaces the **Player-as-bowler inert-attributes gap** as concrete data — useful input for sequencing the later sim rungs.

## 10. Open questions

None blocking. Confirmed deferrals (landing rungs): jokers-in-sim + joker sweep → 7c-C; ₸ economy + skills-vs-jokers ROI → 7c-D; self-play decision AI + optimal-vs-naive skill-gap + per-Level difficulty throttle → 7c-E; Player-as-bowler (to make bowling attrs a real lever) → a sim rung feeding 7c-B/E; disk-backed data pipeline / live dashboard → later if sweeps outgrow inlined JSON.
</content>
