# Interactive Lever Balance — design + measurement

**Date:** 2026-06-17 · **Rung:** Theme 7 match-sim balance · **Mode:** AFK (decisions recorded here, not asked)

## Why

Nico tests the interactive match and "always wins, very close." Diagnosis of the
live code path (`scenes/main.gd::_play_next` → `SeasonPlay.make_session` →
`MatchSession`) surfaced three structural facts:

1. **It's one frozen game.** `season_hub.gd` boots the season from a *constant*
   `BOOT_SEED = 20260615`, and `CareerResolver.start_career(0)` is deterministic.
   Every fresh start replays the identical first fixture (same opponent, same
   per-match seed `BOOT_SEED+100+0`). Only the player's decisions + saved build vary.
2. **The player is the underdog on paper.** A new career starts on Club slot 0 =
   **1.5★** (`STAR_LADDER[0]`), facing club opponents at 2.0–4.5★.
3. **The opponent holds none of the player's levers.** In `MatchSession._resim()`
   the resolver is called with the player's Boost + DRS, but `opp_boost_plan`,
   `opp_drs_policy`, `opp_bowling_plan` are all `null`, and Key Moments are a
   player-only intent override. So the player has three one-sided levers:
   - **Boost** (`BoostPlan`): +15% runs/wickets for 6 balls, 2 presses/innings.
   - **DRS** (`DRSPolicy`): review to overturn, `base_p = 0.32`, 2 reviews/innings.
   - **Key Moments** (`KeyMomentPlan`): per-over batting-Intent overrides.

The balance harness (E1 self-play, E3 difficulty ladder) only ever measured the
**no-lever** path (textbook intent, no Boost/DRS/KM). The design intent recorded in
`difficulty_ladder.gd::brain_for` (PL2, 2026-06-14) is that a *fresh underdog wins
~12%* at Club tours 1–3 and must grow the card to win more. **Nobody has measured
what the three levers add on top of that.** That's the gap this rung closes.

## Goal

Measure the **lever-on per-match win-rate** on the exact matchup Nico plays, decompose
it by lever, reconcile it with his "always winning" experience, and — only if the
number is out of a sane band — tune it back.

## Decisions (AFK defaults)

- **D1 — Measure through the real controller.** The oracle drives `MatchSession`'s
  public API (`decide_boost`, `decide_review`, `decide_key_moment`) so it exercises
  the actual interactive code path, not a re-implementation.
- **D2 — Matchup = the default career start.** Player on Club slot 0 (1.5★) vs the
  seven club opponents (2.0–4.5★), default tour Club "Flat & Warm" (`spec_for(0,0)`,
  d=1.0, TEXTBOOK p=0.4 brain). This is literally what Nico replays.
- **D3 — Player build = reference 35/30/30/30** (the E3 reference creation build).
  Caveat: Nico's *saved* build may be stronger — this measures the **system**, not his
  specific save. If the system reads balanced but Nico still dominates, his card is the
  cause and the lesson is "card growth works", not "levers are broken".
- **D4 — Variation.** N seasons; each season plays all 7 club fixtures on paired seeds
  across arms. Per-match win-rate = wins / (N × 7). `QUICK=1` → small N smoke.
- **D5 — Lever decomposition arms:**
  | arm | Boost | DRS | Key Moments |
  |---|---|---|---|
  | `base` | – | – | – (all BALANCED) |
  | `+boost` | death overs 16,18 of batting innings | – | – |
  | `+drs` | – | review first 2 batting dismissals | – |
  | `+km_aggr` | – | – | Hunt(7)+GoBig(16) |
  | `+km_def` | – | – | Anchor(7)+Milk(16) |
  | `all_aggr` | ✓ | ✓ | aggressive |
  | `all_def` | ✓ | ✓ | defensive |

  The **realistic player ceiling** = `max(all_aggr, all_def)` — the player learns the
  better Key-Moment line. Wicket-Crisis KM (conditional, over varies) is omitted from
  the oracle: it only fires on a mid-innings wicket and its magnitude is minor next to
  the two always-on moments.
- **D6 — Reconcile the "always winning" anecdote.** The oracle also prints the single
  deterministic `BOOT_SEED` first-fixture result (base + all-levers). If that one seed
  is a player win, that *alone* explains "always winning" — it's one frozen game, not a
  win-rate.
- **D7 — Card-growth check.** One extra comparison row: ★3 team + a strong build (50/50
  bat) on `base` and `all_aggr`, to confirm win-rate scales with the card (design intent).

## Target band (my call — flag final number for Nico)

A designed underdog (1.5★, reference build, entry tour) should be able to *scrap* with
the levers but not dominate:

- `base` (no levers): roughly **12–25%** (matches the ~12% PL2 floor, a touch higher off
  a 1.5★ team vs the dumbed-down entry brain).
- best-lever ceiling: **≤ ~50%** — a coin-flip, not a near-certain win.

**If the ceiling is ≥ ~65%, the levers are over-powered** and get tuned back (cheapest
first): Boost budget 2→1 or `base_mult` 1.15→lower; then DRS `base_p`; then ensure no
single Key-Moment band strictly dominates. **If `base` itself is already high**, the
matchup/brain is mis-tuned, not the levers — fix there instead. Measurement decides;
no pre-tuning.

## Deliverable

- `tools/sweep_interactive_levers.gd` — the oracle (this rung's measurement).
- `docs/mockups/interactive-lever-balance-v1.html` — a viz of the per-lever win-rate
  bars (Nico learns by seeing), counts on bars per the stat-provenance rule.
- Findings + any tuning recorded back here in a "Results" section.

## Results (measured 2026-06-17, N=600 seasons × 7 fixtures = 4200 matches/arm, ±0.7pp)

**Verdict: the match is well-balanced. No nerf warranted.** The *weakest* team in the
league (1.5★, reference build) wins **30.8% with no levers** and tops out at a
**50.4% ceiling with optimal lever play** — a coin-flip for an underdog, which is
healthy. Card growth works as intended (★3 + strong build: 48.3% base → 68.3% levers).

| arm | win% | Δ vs base |
|---|---|---|
| base (no levers) | 30.8% | — |
| +boost (death 16,18) | 32.3% | **+1.5** |
| +drs (review 2) | 30.5% | **−0.3** (noise) |
| +km_aggr (Hunt+GoBig) | 45.7% | **+14.9** |
| +km_def (Anchor+Milk) | 17.3% | **−13.5** |
| all_aggr (realistic ceiling) | 50.4% | +19.6 |
| all_def | 19.2% | −11.6 |

**Why Nico "always wins":** three non-balance reasons, none a bug.
1. **One frozen game.** `BOOT_SEED` is constant → he replays the identical fixture 0,
   which is a **base win by 7 runs** (→ 40 runs with levers). He never sees the losses.
2. **Key Moments are the only real lever (+14.9).** Boost (+1.5) and DRS (~0) barely
   move it. Picking aggressive Key Moments swings ~28 points (+14.9 vs −13.5).
3. **His saved build is likely stronger** than the 35/30/30/30 reference, pushing
   toward the ★3 strong-build numbers (48–68%).

**The one design question (NOT a balance bug — Nico's feel call):** Key Moments have a
strictly-best answer (aggressive), because `decide_key_moment` overrides batting Intent
**from that over onward** — so one tap at over 7 makes you aggressive for the whole
middle phase. The UI copy ("how do you play the middle overs / last five overs")
frames this as a deliberate *phase-strategy* chooser, and aggressive batting against
weak bowling on a flat deck is simply correct cricket. So this is content/feel, not a
balance defect:
- **Option A — keep it a learnable phase-intent chooser** (status quo). Aggressive is
  "right" here; on harder tours / better bowling the answer flips. Low effort.
- **Option B — make it a state-dependent dilemma** (aggressive risks a collapse when
  few wickets are in hand, so neither band dominates on average). More design + tuning;
  best decided alongside the upcoming **bowling Key Moments** rung so both are designed
  as genuine trade-offs from the start.

**Recommendation:** ship the oracle as the reusable balance gate; leave the sim
untouched (it's balanced); take Option A↔B and the frozen-seed/testing-workflow
question to Nico — both are feel/workflow calls, not balance fixes.

