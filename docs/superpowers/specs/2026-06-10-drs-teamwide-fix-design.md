# DRS Team-Wide Fix (rung after 7c-E1) — Design

**Date:** 2026-06-10 · **Status:** Approved (Nico's ruling 2026-06-10; AFK rung, defaults recorded per the AFK execution policy) · **Branch:** `drs-teamwide-fix`

## 1. The bug (from E1, spec `2026-06-10-selfplay-baseline-7cE1-design.md` §10.1)

DRS (the Decision Review System — a side spends a limited review to overturn a close umpire call) has two halves in the sim:

- **Survive** (batting side reviews a dismissal to stay in) — symmetric since the fair-fight rung (PR #32). Fine.
- **Claim** (bowling side reviews a dot ball to steal a wicket) — **asymmetric**. The opponent slot claims on **all 20 overs**; the Player slot claims only on the hero's personally-bowled overs (`player_bowling` gate at the claim branch in `scripts/domain/innings_resolver.gd`), which is 0–4 overs — zero for a batting build.

Measured cost: **~6.7 win-points to the opponent slot** (E1 probe, `tools/probe_side_asymmetry.gd`: DRS-both mirror reads 46.3/53.0 instead of ~49/49). This bias is baked into the 48.1% fair-fight baseline (PR #32) and, in lesser part, the 45 joker deltas (PR #33–#35) and their ₸ prices (PR #37).

## 2. The ruling (Nico, 2026-06-10 — recorded in E1 spec §10.1)

> **DRS is team-wide on every ball, for both sides — the hero is just part of the team, no special-casing.**

## 3. Decisions

- **DD1 — The fix is dropping the gate, nothing else.** Remove `and player_bowling` from the Player-slot claim branch (`innings_resolver.gd`, the `elif orig_dot:` block). The survive branch, the one-review-per-ball gating on the *original* outcome (no review "tennis"), the review resource (`base_reviews`), and the success roll (`base_p`) are all untouched.
- **DD2 — Player DRS jokers go team-wide with it.** The Player runtime carries the team's jokers into `try_review`, so claim-side review jokers (e.g. Snicko's accuracy bonus, extra-review grants) now apply on all 20 bowling overs, not just hero overs. This is the ruling's "the hero is just part of the team" applied consistently — the jokers belong to the team's captaincy, not the hero's arm. It is also why the joker re-sweep below is mandatory, not optional.
- **DD3 — Hero bowling figures unchanged.** A claimed wicket on a non-hero over is a *team* wicket; `pb_wickets` stays gated on `player_bowling`. (Already structurally true — the stat block is separate from the DRS block.)
- **DD4 — Acceptance oracle = the E1 probe.** `tools/probe_side_asymmetry.gd` (N=4000/arm, paired seeds): the **DRS-both mirror must read ~49/49** (within ~1.5pts of the no-DRS row's 50.2/48.8 split), and the full-textbook row must lose its DRS skew too. The E1 spec §10.1 table is the "before" record.
- **DD5 — Mandatory ripple: fair-fight floor + joker re-sweep + price refresh.** The fix moves every two-sided-DRS measurement, so: re-run the fair-fight baseline (the `sweep_jokers.gd` no-joker arm; the 48.1% floor is expected to rise toward ~49–50%), re-sweep all 45 jokers (both profiles: standard + chase), and refresh `JokerCatalog.PRICES` from the fresh realized deltas using the same 7c-D method (within-rarity-band interpolation of realized win-delta; conditionals/enablers at band floor). Refresh `docs/joker-pool-v1.md` + the joker viewer DATA if deltas are republished there.
- **DD6 — Red→green test.** Mirror of the existing `test_opponent_claim_review_takes_player_wickets` but for the **Player slot**: opponent batting innings (`player_is_batting = false`), **zero hero overs** (`player_bowler_overs = 0`), claim-everything Player `DRSPolicy` (`base_p = 1.0`, many reviews) → must take more wickets than the no-DRS base. Red today (the gate makes it structurally impossible), green after the one-line fix.
- **DD7 — Build-balance: verify, don't re-tune.** The bias is side-level and constant across builds, so build-vs-build spread should be ~unchanged; the locked balance stands. One `build_spectrum_sweep.gd` re-run as verification; re-open balance only if the win-rate spread blows past ~3pts (it was 2.0 at PR #31).
- **DD8 — Economy: verify, don't re-tune.** Pay (`Economy.match_pay`) keys off the hero's stat line, which DD3 leaves untouched; expect drift ≪ ₸1. One `sweep_economy.gd` income re-run as verification; re-open pay tuning only if the build pay spread exceeds ~₸2 (it was ₸0.2).
- **DD9 — Tuning dials are NOT re-tuned in this rung.** If the re-sweep shows jokers out of their rarity bands against the new floor, magnitudes are adjusted per the rung-2 method **only where the band miss is clear** (> ~1.5pts outside band on N=2000); borderline reads are recorded as findings, not chased. Keeps this a fix-and-remeasure rung, not a re-tune rung.

## 4. What changes (files)

| File | Change |
|---|---|
| `scripts/domain/innings_resolver.gd` | Drop `and player_bowling` from the claim-review branch; update the block comment. |
| `tests/unit/test_fair_fight_baseline.gd` | + DD6 test (Player team-wide claim). |
| `scripts/data/joker_catalog.gd` | `PRICES` refresh (DD5); magnitudes only if DD9 triggers. |
| `docs/joker-pool-v1.md` + viewer DATA | Refresh if published deltas change (DD5). |
| Specs/plans/roadmap | This spec's §10 findings; plan doc; roadmap close-out. |

Existing tests: directional DRS tests should stand (the fix only *adds* claim opportunities for the Player slot). Any seed-pinned snapshot that runs two-sided DRS may shift — update baselines if so, mechanically, and say which.

## 5. Acceptance checks

1. **Probe mirrors even (DD4):** DRS-both ~49/49 ±1.5; full-textbook no longer DRS-skewed.
2. **DD6 test green**, full suite green (≥ 396 + new).
3. **New fair-fight floor recorded** (expect ~49–50%) — becomes the new joker-tuning floor.
4. **45 fresh joker deltas recorded**, bands checked, `PRICES` refreshed.
5. **Build-balance spread ≤ ~3pts (DD7); pay spread ≤ ~₸2 (DD8)** — verified, not re-tuned.

## 6. Out of scope

Bowling-balance (phase tilt, matchup term, wicket cost — next rung, design in E1 spec §10.3) · E2 conditional policy · opponent jokers · DRS UX/`tryReview` swipe surface (Theme 6) · re-running the full E1 self-play oracle (its headline numbers were measured DRS-off and stand; the bowling-balance rung re-runs it as *its* acceptance test).

## 10. Findings (filled at close)

_To be written after the sweeps._
