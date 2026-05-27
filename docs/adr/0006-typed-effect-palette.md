# Typed-effect palette — the only in-Match lever

Every in-Match mechanic — Key Moment swipes, Manager Boost presses, Joker passives — composes from a fixed palette of six typed effects. There is no other lever in the auto-sim.

The six verbs:

| Effect | Shape | Used in |
|---|---|---|
| `setIntent(band)` | Persistent state — team aggression posture (Defensive / Balanced / Aggressive) | Powerplay Exit, Wicket Crisis, Milestone Ball, Death Plan |
| `setNextBowler(type)` | Discrete event — next over's bowler is the next available of `type` (pace / spin) | Bowling Change |
| `fieldMode(mode)` | Persistent state — field configuration (defensive / catching), until next change | Field Set |
| `buffNextBalls(roll, mult, n)` | Windowed modifier — multiplier on the wicket or runs roll for the next `n` balls | Wicket Crisis, Milestone Ball, Manager Boost |
| `formEvent(player, delta)` | One-shot — shift a specific player's Form-points counter by `delta` | Milestone Ball |
| `tryReview(outcome)` | Finite-resource consumable — roll hidden P(success); on success flip outcome and retain review, on failure consume it | DRS Review |

**Why not free-form effects per mechanic (Q10 option C).** Bespoke logic per Key Moment or Joker means no shared semantics, no way for a Joker to interact with a Key Moment generically ("this Joker buffs all `fieldMode(catching)` calls" becomes impossible), and a balance harness that has to special-case every entity. The typed palette costs a little ceiling (you cannot build a *truly novel* effect without expanding the palette) but buys consistency, composability, and a tight surface for the balance harness to model.

**Adding a 7th verb.** Possible, but every proposal must justify why an existing verb can't be re-shaped to fit. A new verb adds a permanent dimension to the balance-harness search space. Default answer: re-shape the idea into the existing palette.

**Consequences:**

- Joker design (theme 4) is constrained — each Joker is a buff on one or more verbs (e.g. "+15% to all `tryReview` P(success)", "windowed effects last +2 balls"). This is *good*: it makes Joker design tractable and the joker-stack interactions predictable.
- Manager Boost effects and Key Moments share the vocabulary, so a Joker that buffs `buffNextBalls` compounds with both. Cross-system synergies come free.
- The auto-sim API consumes a stream of typed effects + ball seeds. Nothing else. Per ADR 0004, this is what makes headless balance-harness simulation tractable.
