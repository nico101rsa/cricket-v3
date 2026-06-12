# Career pacing — gate removal + attribute-sink stretch

**Date:** 2026-06-12 · **Status:** approved (Nico's rulings, same-day follow-up to the
Career-loop rung PR #48) · **Spec it amends:** `2026-06-12-career-loop-design.md`

## 1. Nico's rulings (2026-06-12, post-PR-#48 review)

1. **No gate on Province's Premium Final.** The ordered endgame (Province Premium
   unlockable only after Club's and City's Premium tours are won) is removed. Lower-Level
   Premium wins become an *optional trophy chase* — to be made appealing (Premium trophy +
   a large ₸ payout) rather than mandatory. **The incentive design is deferred** (logged in
   the roadmap ideas backlog); this rung only removes the gate.
2. **Attribute progression must span a Career, not two Seasons.** "Without jokers the
   player should be maxed out at about the median Seasons (~49), else the upgrade is too
   much." PR #48's finding: at `attr_cost_base 0.256`, maxing every attribute costs
   ~₸1.5–2k total ≈ one Season's income — the sink vanishes by Season ~2.
3. Both numbers get **re-tuned later**: once jokers compete for the same ₸ in the loop,
   and once the auto-research rung (7c-E4) searches for the fastest legitimate completion.

## 2. Decisions (DP1–DP5)

- **DP1 — Gate removal.** `CareerState.is_unlocked` drops the `level_won[0] and
  level_won[1]` check; Province Premium is playable on normal adjacency unlock. Winning
  it still completes the Career (`record_outcome` unchanged). CONTEXT.md (the canon
  glossary) is edited to match — Level-wins become optional trophies, with a pointer to
  the deferred incentive design.
- **DP2 — DC16 down-offers stay, rationale updated.** They were the anti-softlock for the
  gate; with the gate gone they survive as the *path back down* for the optional trophy
  chase (and the future dropped-player lifeline) — "a lower-Level Team always wants you
  back while its trophy is unwon". Mechanism unchanged, comment + spec note updated.
- **DP3 — The sink stretch is the existing linear dial, retuned.** `attr_upgrade_cost`
  stays `base × current_value`; `attr_cost_base` rises from **0.256** until the naive
  preview line (no jokers) maxes out around its own median completion Season. Budget
  arithmetic predicts base ≈ 14 (≈ ₸73k to max vs ~₸1.5k/Season income); the preview
  measures the real value (growth-rate ↔ win-rate feedback makes prediction inexact).
  The 7c-D "legacy ROI" calibration (DE7: +1 ≈ 1.3–2.6× joker ₸-per-win-point over 3
  Seasons) is **deliberately superseded** — attributes are now the Career-horizon sink by
  ruling; the joker-vs-attribute ROI gets re-solved at the Shop rung when both sinks
  coexist. The `test_economy` pin moves from the legacy-ROI relation to the new dial.
- **DP4 — "Maxed" stays the preview's working cap (60/attribute).** A real in-game
  attribute ceiling is a separate design call (open dial for the Shop/balance rung);
  nothing in `scripts/` hardcodes 60.
- **DP5 — The naive preview policy is unchanged** (win a Level before moving up). With
  the gate gone a *rushing* policy could finish faster — measuring that frontier is
  exactly E4's job, not the eyeball's.

## 3. Acceptance (eyeball, career_preview full N=100)

- Careers still complete; the run reports **median max-out Season**, targeted at Nico's
  literal **~49** (the median he saw on the PR #48 chart). Note completion median ≠
  max-out by construction — completion is always max-out *plus* the post-max Premium
  grind (~20–30 Seasons on the naive line) — so "max ≈ completion median" is not
  achievable; the literal Season-number target is what's tuned. A feel-dial, not a
  precision gate.
- The mean-₸-bank curve on `career-loop-v1.html` shows money being *consumed* for most of
  a Career (visibly flatter than PR #48's straight ₸165k climb).
- Suite stays green (count ≥ 499 minus the one swapped economy pin, plus its replacement).

## 4. Out of scope

- Premium-trophy incentive design (₸ payout sizes, trophy surface) — with Nico later.
- Real attribute ceiling value — Shop/balance rung.
- Joker sink in the loop + ROI re-solve — Shop rung.
- Fastest-completion search — 7c-E4.

## 10. Findings (career_preview full N=100, seeds 9000–9099, base 11, gate removed)

All on `docs/mockups/career-loop-v1.html`.

- **`attr_cost_base` 0.256 → 11.0** (iterated 14 → 11 by quick runs; 14 read max-out ~61).
  At 11.0: **attributes fully max (60 each) at median Season 46** (range 41–51; 95/100
  careers got there) — on Nico's ~49 target. The mean-bank curve is **flat at ~₸1.3–1.6k
  through Season ~45** (income being consumed) then climbs once maxed — the sink now spans
  a Career instead of evaporating by Season 2.
- **Completion lengthened as a consequence:** median 49 → **63 Seasons** (range 34–110)
  over the 77/100 that completed; capped-at-120 rose 15 → **23**. The post-max grind at
  Province Premium (~25% beat-rate per visit, win-Final rarer) is unchanged — jokers (Shop
  rung) are the intended buy-back of that stretch; re-tune then (Nico's ruling, §1.3).
- **Basic time-to-beat (Nico's ask, refined later):** exact match counts — **median 532
  Player matches** to complete (range 298–902, over the 77 completed) **× ~2:45/Match ≈
  24 hours of match play** (range 14–41h). Excludes Shop/Offer screen time; the skilled
  line (jokers + E4-searched choices) should land well under it.
- **Gate removal verified by test** (`test_province_premium_has_no_level_win_gate`): the
  naive policy still wins Levels in order (its choice, DP5), so the eyeball numbers are
  not rush-distorted. Down-offers (DC16) stay as the trophy-chase path back (DP2).
- Suite: **499 tests green** (legacy-ROI economy pin swapped 1:1 for the pacing pin).
