# Team strength durability via half-star Markov rating

Each **Team** carries a **0.5–5.0 star rating** in **half-star increments** (10 discrete tiers) that mostly persists across **Seasons**, mutating *Markov*-style at each Season rollover. ("Markov" = memoryless: next-Season stars depend only on current-Season stars + the probability roll, not on any longer-term trend or history.) Per-Match `battingStrength` and `bowlingStrength` derive from `(stars, current Tour distribution, small per-Season noise)` rather than re-rolling each Season from scratch.

## Context

The original model (CONTEXT.md / ADR 0002) had every Team's strengths re-roll fresh from the current Tour's distribution at every Season start. This made the **Offer** mechanic structurally meaningless: a Team's *next-Season* strength was uncorrelated with what the Player saw on the Offer screen *this* Season. Choosing between Offers became a coin flip — there was no skill signal to read, no franchise identity to invest in, no fallen-giant or rising-star narrative.

The skill model (ADR 0003) requires that Meta-layer decisions (Offer picks, **Tons** allocation) be learnable. A coin-flip Offer mechanic produces no learnable function.

## Decision

Each Team has a `stars` value on the discrete set `{0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0}` (10 tiers), set at Career start (or at first Career-in-this-Country / first promotion to that Level). Mutation rule per Season rollover:

| Event | Probability | Result |
|---|---|---|
| ±0.5 swing | ~30% | Random direction, clamped at 0.5 and 5.0 |
| ±1.0 catastrophic swing | ~5% | Random direction, clamped — board fight, manager exit, captain retirement; flavoured in next Season's commentary via `Team.lastSeasonEvent` |
| No change | ~65% | Stays at current value |

The 30%/5% are **V1 strawman** — the balance harness (ADR 0004) sweeps for the actual values once a sim exists.

**Why half-star granularity over integer.** An integer 1–5 model (the original draft of this ADR) made every swing a story — Mumbai dropping 5 → 4 read as "they collapsed", with no smaller gradient available. Half-star increments give 10 tiers, smoother trajectories ("5 → 4.5 → 4 → 4.5" is natural cycling, not collapse), and more individuation across the league (a 3.5★ Team is genuinely distinct from 3★ and 4★ Teams). Catastrophic ±1 swings in this model carry the same *proportional* weight as ±2 swings did in the integer model — still newsworthy. The **0.5 floor** prevents the "permanently 1★" cellar-dweller weirdness that bottom-clamping at 1 produced.

Stars are **invariant across Tours within a Level**. Climbing from Tour 3 to Tour 4 at Club rescales *all* Teams' absolute strengths upward (per the new Tour distribution) but preserves their ranks: Mumbai is still the 5★ elite, Pune is still the 1★ underdog. Per-Match actual strength derives as:

```
battingStrength = tourDistribution.percentile(stars / 5) + uniform(-noise, +noise)
bowlingStrength = same formula, independent draw
```

`noise` is small (e.g. ±5% of the tour mean) — accounts for "did Mumbai's openers misfire this Match" without disturbing identity.

Countries are independent: starting a new Career in a different Country generates that Country's Teams with fresh star draws.

**Career start:** the Player picks 1 of the **3 lowest-star Teams** at Club Level as their starting Team. Rookie underdog narrative — you don't get parachuted into the franchise that's already 5★.

## Considered alternatives

- **Original: full re-roll each Season** — rejected. Makes Offers structurally meaningless (no signal across Seasons).
- **Fixed permanent baseRank (0.0–1.0) + ±10% per-Season wobble** — rejected. Teams *never* genuinely change identity across a Career. Mumbai is elite forever, Pune is bottom forever — dramatically flat. No fallen-giants or rising-stars stories.
- **Continuous strength rating with momentum (`actual = α·previousActual + (1−α)·tourMean + noise`)** — rejected as overkill for V1. Stars are a familiar UI idiom that narrates cleanly ("Mumbai dropped a star this year"); a continuous rating needs UI to surface deltas the player has to interpret numerically.
- **Mutate at Tour boundary instead of Season boundary** — rejected. Too coarse — only ~8 mutations across a Level's worth of Career time. Per-Season feels like a real-world cricket cycle.

## Consequences

- **Offers become a real Meta-layer skill.** The Player learns to read star tier + current-Season form delta and weigh against Tons demands and Affinity loss. ADR 0003's "no dominant answer" stays intact.
- **Career-narrative texture is free.** Fallen-giant Seasons ("Mumbai dropped to 3★ after the Khan departure") and rising-star Seasons ("Pune just jumped to 4★") give the Career its arc without authored story beats. Catastrophic ±2 events are flagged in next-Season pre-Match commentary — cheap dramatic payoff.
- **Auto-sim (ADR 0004) is unchanged.** It still consumes single `battingStrength` / `bowlingStrength` numbers per Team per Match — only the *derivation* changes. No new sim API.
- **One new piece of state per Team** (`stars: float`, restricted to the 10-tier discrete set) plus `lastSeasonEvent: string | null` for catastrophic flavour — total cost for a Country with 24 Teams (8 per Level × 3 Levels) is 24 floats + 24 nullable strings per Career. Negligible.
- **Balance-harness sweep target:** the 20%/5% probabilities, the noise magnitude, and the `tourDistribution.percentile(stars/5)` mapping all become harness-tunable knobs.
- **UI implications:** Offer screen surfaces `★★★★☆ Mumbai · +4% above baseline` rather than raw numbers. Optional: a Team-rating-change notification at Season-start ("Mumbai have dropped a star — *Khan's retirement still being felt at the franchise*").
- **The mid-Season Offer trigger** (CONTEXT.md, `Offer`) gains real meaning once stars are durable — switching mid-Season is a readable bet ("my Team is 2★ struggling, the offering Team is 4★ contending — gamble it") instead of a coin-flip.
