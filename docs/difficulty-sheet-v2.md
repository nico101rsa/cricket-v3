# Difficulty sheet v2 — Nico's redesign (2026-06-12 evening)

Source: Nico's spreadsheet, pasted as a screenshot in chat 2026-06-12 ~18:26 and
transcribed here verbatim. **This supersedes the v1 d-sheet** codified at E3
(`DifficultyLadder.D_SHEET`, bands Club 1–8 / City 2–10 / Province 3–12).
**BUILT 2026-06-12** by the difficulty-sheet-v2 rung — spec
`docs/superpowers/specs/2026-06-12-difficulty-sheet-v2-design.md` (DV1–DV12) settles the
open questions below; this doc stays as the verbatim source transcription.

## The new d-sheet

Tour names now carry **pitch conditions** (pulls ideas-backlog cluster 1 into the ladder;
"Practise/Home/Away" naming is replaced):

| # | Tour (condition flavour) | Club | City | Province |
|---|---|---|---|---|
| 1 | Flat/warm | 1 | 5 | 9 |
| 2 | Spin | 2 | 6 | 10 |
| 3 | Green Mamba (seaming) | 3 | 7 | 11 |
| 4 | **Day mixed conditions** (green cell) | **4** | **8** | 12 |
| 5 | Evening Spin | 5 | 9 | 13 |
| 6 | Evening Mamba | 6 | 10 | 14 |
| 7 | Evening mixed conditions | 7 | 11 | 15 |
| 8 | Premier | 10 | 15 | 20 |

Properties vs v1: linear 1-step ramp inside a Level, then a **jump into Premier** (7→10,
11→15, 15→20); **narrower band overlap** (Club 1–10, City 5–15, Province 9–20; City
Flat/warm d5 = Club Evening-Spin d5; Province Flat/warm d9 sits just under Club Premier
d10); difficulty ceiling rises 12 → **20**.

## Unlock rule (green highlights)

"Unlock next league" + the green Tour-4 cells (Club 4 / City 8): **beating Tour 4 (Day
mixed conditions) unlocks the next Level** — replaces v1's "beat any (L,T) unlocks
(L+1,T)". (Up-unlock within a Level presumably stays sequential — confirm at spec.)

## Prize escalation (column G)

Per-tour escalation within a Level: T2 +10% · T3 +10% · T4 +10% · T5 +30% · T6 +40% ·
T7 +50% · T8 +60% (T1 blank = base).

Nico's notes, verbatim:
- "Prize for winning match, bonus for reaching final, winning a playoff and grand final
  big prize"
- "Incentivize player to stick around in club to get more money with prize escalation"
- "Super big prize for winning Premier Grand Final"

This is the **incentive replacing the removed endgame gate** (career-pacing DP1): higher
tours of your *current* Level pay escalating prizes, so farming up a Level competes with
jumping Levels early; the Premier Grand Final super-prize is the trophy payout.

## Open questions for the spec (settle with Nico or record AFK defaults)

1. **Escalation base — ANSWERED (Nico, 2026-06-12 18:30): match prizes only.** The
   per-tour % scales the match-prize objects (win prize, Final/playoff/grand-final
   bonuses), NOT the game fee / other pay. Treat as per-tour absolute multipliers
   (T8 = 1.6×) unless measurement argues otherwise.
2. **New prize objects**: match-win prize / reached-The-Final bonus / playoff-win bonus /
   grand-final big prize / Premier-Grand-Final super prize — sizes? (Economy rung; the
   existing `Economy.win_bonus` ₸5+₸5/Level is the seed for the match-win prize.)
3. **`mean_frac` re-map — ANSWERED (Nico, 2026-06-12 18:30): the sheet is proportional;
   scale it as needed.** The two structural requirements to preserve: **City Tour-1 = Club
   Tour-5** (the overlap anchor — same d, same strength) and **a big jump into Premier
   from Tour 7** so Premier *feels* notably harder. Free to re-anchor the absolute span
   (e.g. d=20 ≈ today's hardest card strength) so long as those relative shapes hold;
   the oracle measures the resulting beat-rates either way.
4. **Conditions: names-only this rung, or mechanical?** Mechanical pace/spin tilt per
   tour = ideas cluster 1 (rides the bowling-balance matchup machinery) — naming can ship
   first, mechanics as their own rung.
5. **Brain table re-map** over the new d-range (v1 thresholds were tuned to d≤12).
6. **Tour-4 gate**: does the across-unlock at T4 also retire the DC16 down-offer
   rationale shift, and does beat-of-T4 still guarantee the cross-Level Offer (DC11)?
7. **Re-anchor budget**: E3 ladder sweep (~3.3 min) + career preview (~12 min) re-run;
   refreshed beat-grid, completion median, time-to-beat. E4 waits for this.
