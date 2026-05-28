# Skill model — where mastery lives

The game's depth must come from learnable, conditional decision-making, not from interface complexity (it is deliberately simpler to operate than Hearthstone, but should still reward hundreds of games of mastery). Mastery lives in three nested layers:

- **Tactical** — Key Moment swipes + Manager Boost timing, within a Match.
- **Strategic** — Joker drafting, within a Season.
- **Meta** — Offer choice + Tons allocation, across the Career.

To keep that skill real rather than artificial, two rules bind every Key Moment and the auto-sim math:

1. **No dominant answer.** Every Key Moment choice is +EV in some match states and −EV in others; the player must *discover* the conditional rule. The variables that flip it (wickets in hand, overs left, required rate, the Player's build) are visible on screen but never labelled as "the answer".
2. **Never surface the math.** No win-probability bar, projected-runs figure, or recommendation arrow. The result screen gives outcome *feedback* to learn from; it never gives *prescription*. The skill is internalising the hidden function.

**Corollaries:**

- The Joker pool and Tour conditions must support multiple viable archetypes (e.g. an anchor / wickets-in-hand build vs a boundary-tempo build), so the game is not "solved" once one optimal strategy is found.
- Key Moments always retain outcome variance — even an optimal call can fail. This keeps cricket's character and keeps the Strategic and Meta layers (building a more robust Player and Joker set) meaningful.

**Why not the obvious path:** the easy design is flavourful narrative Key Moments plus a helpful recommendation UI. That produces a game with no mastery curve — solved on first read. A future contributor will be tempted to "help" the player with a recommendation arrow; this ADR exists to stop that.

**Consequences:** the auto-sim math is constrained — every Key Moment lever must be a genuine expected-value trade-off, not a flat buff. The balance engine's headline metric is the **optimal-vs-naive skill gap**: simulate a player following the best conditional policy against one choosing randomly. A healthy, learnable game sits well above 0% (skill exists) and well below 100% (not solved, not pure RNG).
