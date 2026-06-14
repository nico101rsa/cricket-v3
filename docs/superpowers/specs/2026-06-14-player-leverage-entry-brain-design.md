# Player leverage — the entry-tour over-boost — design

**Date:** 2026-06-14 · **Rung:** player-leverage / structural over-boost (deferred half of world-scale v2) · **Branch:** `player-leverage-entry-brain`
**Mode:** AFK — default decisions recorded as PL1–PL7 (project CLAUDE.md policy). One feel-decision put to Nico (entry difficulty) and answered: **"honest underdog climb."**

---

## 1. Goal (plain English)

The world-scale v2 handoff flagged: *"the Player's OWN team over-performs at weak tours regardless of the Player's card — a fresh 1.5★ side finishes ~1st at Club and wins ~25–30% even with the hero dialled down; lowering the hero does NOT help."* It proposed the cause was a **roster-vs-derived scaling** split (the Player's matches on a gap-filled roster path, NPC games on a derived scalar path that scales down at weak tours), and the fix as reconciling the two.

**That diagnosis is wrong — superseded by measurement this rung (PL1).** Two facts kill it:

1. **There is no derived-scalar path anymore.** The career-fidelity rung (CF1, PR #53) moved *every* league fixture onto the roster path: `LeagueResolver.build_rosters` builds a standard XI (712.5 batting pts) for all 8 teams and `simulate_league` passes `rosters[i], rosters[j]` to all 28 games. NPC-vs-NPC and Player games scale identically (`bat[i] / REF_SCALAR`). The Player's card is gap-filled away to a standard team total, so team strength is driven by **stars**, not card.
2. **The over-performance is entirely the entry-tour opponent AI**, and **the card DOES have leverage** (the handoff misread a narrow weak-card range).

## 2. The real root cause (PL1 — measured)

The Player's team over-performs **only at the naive-brain tours** (difficulty d≤3 = Club Tours 1–3). The mechanism: in Player-facing fixtures the *opponent* draws the cell's brain plans (`OpponentBrain.draw_plans`), and at d≤3 that brain is **NAIVE** (a uniform-random plan draw). The rest of the league plays competently (NPC-vs-NPC games use engine-default plans). So the Player's weak side farms a randomly-playing opponent that the NPCs never face.

`brain_for(d)` feeds **only** the Player's opponent (it sets `TourSpec.brain_tier/blend`, consumed at `league_resolver.gd:71` for `i==0` fixtures). NPC games don't use it. So this is a single, localized lever — not a scaling-path schism.

**Measured (`tools/standings_correlation.gd`, the Player's 1.5★ team = the weakest of 8, N=100):**

| Tour | Opponent AI | Player finish | Player win% | NPCs sort by stars? |
|---|---|---|---|---|
| Club Flat & Warm (d=1) | naive (random) | **2.9 / 8** | **35%** | No — only the Player breaks it |
| City Day Mixed (d=8) | textbook | 7.2 / 8 | 0% | Yes, cleanly (r=0.68) |
| Province Premier (d=20) | adaptive | 7.3 / 8 | 0% | Yes, cleanly (r=0.71) |

At City/Province the Player's weak team **correctly finishes near the bottom**. Only the Club on-ramp is broken.

**Isolation (Club d=1, fresh 11/11/11/11, N=100):** swap the Player's opponent from naive → engine-default and the Player's win-rate collapses **35% → 3%** (finish 2.9 → 6.4). Stripping the Player's own textbook plans on top moves 3% → 1%. So the freebie is **~all** the naive opponent; the Player's captaincy/kit (textbook plans, 2-sided DRS, default boost/field) adds a ~2-pt sliver. The Player's kit alone never lifts the weak team at d=8 (textbook opponent), confirming the brain is the driver.

**Card leverage is healthy** (Club d=1, naive baseline): win% scales 25% (card 6) → 31% (11) → 44% (25) → 60% (50). The handoff's "lowering the hero doesn't help" was reading the flat 6–11 stub of a curve that clearly climbs. The card matters; the bug is the ~25% *floor* the naive opponent gifts regardless of card.

## 3. The decision: re-tune the entry-tour brain (PL2)

**PL2 — change the entry band `brain_for(d ≤ 3)` from `[NAIVE, 1.0]` to `[TEXTBOOK, ~0.4]`.** The opponent then plays textbook with p≈0.4, else naive (`draw_plans` blends down one tier) — "weak but not a pushover." This:

- **Preserves the two-axis difficulty architecture** (the brain tiers + the E3 difficulty sheet are untouched; only the entry band's tier/blend is re-pegged). NAIVE still fires ~60% of entry-tour games via the blend-down.
- **Only touches Club Tours 1–3** (d=1,2,3). Club Tour 4 (d=4) is already `[TEXTBOOK, 0.5]`; the new entry band `[TEXTBOOK, 0.4]` sits just below it — monotone. City (d≥5) and Province (d≥9) are unaffected.
- **Hits the feel target.** Measured `p`→fresh-underdog Club win% (N=120): p=0.0→30%, p=0.3→18%, p=0.5→8%, p=1.0→0%. **p≈0.4 → ~12–13%** (mid-low finish ~4.4/8), inside Nico's "honest underdog climb" (10–15%).
- **Stays card-sensitive.** At p=0.5: card 6→6%, 11→8%, 25→16%, 50→37% win — a fresh underdog grinds mid-low, card growth lifts them, and a maxed player can still top the easiest tour. The weakest team no longer becomes champion on a coin-flip.

**Nico's ruling (2026-06-14):** entry feel = **"honest underdog climb"** — a fresh weak player finishes mid-to-low at Club and must grow the card before winning; Club stays the easiest tour but isn't a gimme.

**Strawman value: p = 0.4.** Final value pinned by re-measurement in the build (target fresh Club win 10–15%, mid-low finish, monotone vs Tour 4).

## 4. What this is NOT (scope — PL3, PL4)

- **PL3 — gap-fill / card-team-leverage is NOT changed.** The card already has healthy leverage on results (§2). Gap-fill keeping the team total at 712.5 is correct (it's what makes builds *equal*, the hard-requirement memory). We removed a freebie floor, not re-architected leverage.
- **PL4 — build-equality at fresh totals is a SEPARATE rung, deferred.** `build_spectrum_sweep SUM=44` shows a 13.7-pt win-spread between batting-lean and bowling-lean *fresh* builds (heals to 1.9 by SUM=125). Different root (gap-fill makes weak batting redundant while the 4-over bowling lever is additive — a build-*shape* fairness issue in the Player's own match, `simulate_match_teams`), different fix. Recorded as a follow-up, not bundled here (scope discipline).
- **No ball math, joker, economy, or NPC-game change.** `brain_for` is not used by any balance oracle or the ball/innings sim, so the ledger is byte-identical by construction (PL6).

## 5. Components touched

| File | Change |
|---|---|
| `scripts/data/difficulty_ladder.gd` | `brain_for`: the `d ≤ 3.0` branch returns `[TourSpec.Tier.TEXTBOOK, 0.4]` (was `[NAIVE, 1.0]`). A short comment records why (entry-tour over-boost fix, PL2). |
| `tests/unit/test_difficulty_ladder.gd` | `test_ladder_brain_progression`: the Club-Tour-1 assertion flips `NAIVE`→`TEXTBOOK`, `blend 1.0`→`0.4`. Add a monotonicity assertion: entry blend (0.4) ≤ Tour-4 blend (0.5), both TEXTBOOK. |
| `tools/standings_correlation.gd` | Keep this rung's probe toggles (`NO_BRAIN`, `NO_PLAYER_PLAN`, `BRAIN_TIER`, `BRAIN_BLEND`) — guarded, env-unset = unchanged; useful for the re-anchor. (The handoff's "errors at d≥8" note was a zsh word-split bug in the caller, not a tool bug.) |

## 6. Re-anchor + acceptance (PL5, PL6)

**PL5 — re-measure and record (no new dials beyond p):**
- **Standings (the fix):** at Club Tours 1–3, the Player's fresh 1.5★ team finishes mid-low (win 10–15%, no longer the league outlier); `r` climbs toward the City/Province band (~0.5+). City/Province standings byte-identical (their brain band is unchanged — verify by spot-run).
- **Difficulty grid** (`tools/sweep_difficulty_ladder.gd`): Club Tours 1–3 beat-rate drops (the on-ramp gets honestly harder); record the new grid wall. City/Province cells unchanged.
- **Career pacing** (`tools/career_preview.gd`): the early game is harder → re-measure completion / median seasons / time-to-beat. Nico deferred the pacing re-peg; **measure and flag** — re-peg `attr_cost_base` only if the change makes the career unwinnable or wildly off the ~50-season target (record the call either way).

**PL6 — ledger byte-identical (verify, don't re-tune):** `probe_scoring_env.gd` (env 155), `sweep_jokers.gd` (floor 45.5), build spread, `sweep_economy.gd` (pay spread) — all independent of `brain_for`. Spot-run env + the joker floor to confirm no ripple.

**PL7 — acceptance checklist:**
1. Fresh 1.5★ Player wins Club Tour 1 **10–15%** of the league, finishes mid-low (~4–5/8), no longer the standings outlier.
2. Card-sensitive at Club: maxed card clearly out-wins fresh (a strong player can top the easiest tour).
3. City and Province standings/grid **unchanged** (spot-run byte-identical).
4. Ledger oracles (env, joker floor) **unchanged**.
5. Career pacing re-measured + recorded (re-peg only if broken).
6. Full GUT suite green (the one flipped assertion + the new monotonicity assertion).

## 7. TDD / build order

1. **Red→green the brain change:** update `test_ladder_brain_progression` to expect `[TEXTBOOK, 0.4]` (red — current code returns NAIVE), then change `brain_for` (green). Add the monotonicity assertion.
2. **Tune p:** re-run `standings_correlation` at Club Tours 1–3 (fresh + a card sweep); confirm fresh ∈ [10,15]% and monotone vs Tour 4. Adjust p if needed, re-pin the test.
3. **Re-anchor:** `sweep_difficulty_ladder` (grid wall) + `career_preview` (pacing) + spot-run `probe_scoring_env` / `sweep_jokers` (ledger unchanged). Record all in §10.
4. **Docs:** CONTEXT.md difficulty canon + `docs/mockups/difficulty-ladder-v1.html` / `calibration-v1.html` DATA refreshed for the new Club on-ramp.

## 8. Findings (§10)

**The fix (production brain p=0.4, `standings_correlation`, fresh 1.5★ = weakest of 8, N=150):**

| Cell | Player finish | Player win% | r (star→finish) | vs. before |
|---|---|---|---|---|
| Club Tour 1 (d=1) | 4.22 / 8 | **12%** | 0.348 | was 2.9 / 35% / r=0.20 |
| Club Tour 2 (d=2) | 4.19 / 8 | 10% | 0.374 | — |
| Club Tour 3 (d=3) | 4.81 / 8 | 4% | 0.421 | — |
| Club Tour 4 (d=4, unchanged) | 5.29 / 8 | 5% | 0.492 | unchanged band |

Monotone on-ramp (win 12→10→4%), fresh underdog inside the 10–15% target, no longer the standings outlier. The weakest team's `r` climbed from 0.20 (broken) toward the healthy band.

**Card-sensitive (Club Tour 1, N=150):** card 6→13% · 11→12% · 25→21% · **50→43%** win. A fresh underdog grinds mid-low; card growth earns the climb; a maxed player can top the easiest tour (43%, not a lock). The old ~25–35% naive floor is gone.

**City/Province unchanged (spot-run, N=150):** City Day Mixed finish 7.15 / win 0% (was 7.20 / 0%); Province Premier finish 7.29 / win 0% (was 7.30 / 0%) — byte-identical within noise (their brain band is untouched). ✓ PL7-3.

**Ledger unchanged (PL6):** `probe_scoring_env` mean total **155.0** (env held); joker floor / build / pay sit on the ball path that never calls `brain_for` → byte-identical by construction. ✓ PL7-4.

**Difficulty grid re-anchor (PL5, `sweep_difficulty_ladder`, N=200, full re-run on the world-scale-v2 base).** Note the grid measures a **mid reference build (35/30/30/30 = 125 pts) on a ★3 tour-average team** — NOT the fresh-underdog start (that's the standings probe above). So the grid is far less sensitive to the entry-brain change than the fresh-underdog standings (a ★3 team never relied on the naive freebie). New grid (beat = top-3 finish):

| Cell | beat% | brain |
|---|---|---|
| Club Flat & Warm (d1) | 75.0 | TEXTBOOK ½(0.4) |
| Club Spin (d2) | 78.0 | TEXTBOOK ½(0.4) |
| Club Green Mamba (d3) | 81.5 | TEXTBOOK ½(0.4) |
| Club Day Mixed (d4) | 70.0 | TEXTBOOK ½(0.5) |
| … | … | … |
| City Premier (d15) | 24.0 | STATIC_EQ |
| Province Premier (d20) | **17.5** | ADAPTIVE |

The wall now spans **Club 75–81% → Province Premier 17.5%**. Club Tours 1–3 dropped from the pure-naive band (cf. the sweep's naive-isolation **85.5%** at d7 — at the weaker Club d1–3 the pre-fix beat was ~85–90%) to 75–81.5% for the reference build — honestly harder, still the easiest band. Cells 4–23 are byte-identical to world-scale v2 (their brain band is untouched). **Pre-existing inversion noted (NOT this rung's):** Club 1→3 beat rises with d (75→81.5) — the ★3 reference team sits at the tour mean while opponents have fixed stars, so a wider spread at higher d lets the mean team crush the bottom half more easily. Inherited from the low-tour strength theme (world-scale/env-span), surfaced (not caused) by un-saturating the brain.

**Career pacing re-anchor (PL5, `career_preview`, N=100 — measure + flag; the pacing re-peg is Nico's deferred call, NOT done here):**
- attr_only: **65/100 complete**, 35 capped, seasons-to-complete **median 78**, attributes maxed median S68, matches-to-complete median 632.
- balanced (jokers): **62/100 complete**, 38 capped, seasons-to-complete **median 79**.
- **My change's isolated share** (same base + seeds, OLD naive brain vs NEW): old = 58/100 complete, median 82 S → new = 65/100, median 78 S. The harder on-ramp **did not worsen** completion — marginally *improved* it (the naive freebie was rushing under-developed players to the top to stall). The bulk of the drift from the old ~86/100·~57 S is world-scale v2's long-climb re-peg (`attr_cost_base` 13→7, max-out ~S68), not the entry brain.
- **Verdict:** careers still complete (~63%) and are NOT unwinnable, so per PL5 the rung does **not** re-peg `attr_cost_base`. The median ~78–79 S vs Nico's ~50 target is the deferred pacing decision (world-scale v2 flagged it); recorded for Nico, not actioned (scope discipline + it's his call).
