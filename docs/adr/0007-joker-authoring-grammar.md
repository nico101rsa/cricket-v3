# Joker authoring grammar — passive buffs + conditional triggers, nothing else

Every Joker in the pool composes from a fixed two-shape grammar. The shapes both operate on the 6-verb palette (ADR 0006) and are the only legal Joker authorings.

The two shapes:

| Shape | Activation | Example |
|---|---|---|
| **Passive verb buff** | Always-on. Fires whenever its target verb fires. | *"Lucky Stand" — `tryReview` P(success) +15%* |
| **Conditional trigger** | Fires its buff only while a game-state condition holds (a verb is in state Y) or when a verb fires under condition Z. | *"Cordon Killer" — while `fieldMode(catching)` is set: +5% wicket roll on every ball* |

**Authoring spec.** Every Joker is the tuple `(target verb, magnitude/shape, optional trigger condition referencing another verb's firing or persistent state, rarity)`. Nothing else. No bespoke logic per Joker. No cross-Joker chain references.

**Why not flat passive buffs only.** Jokers collapse into stat sticks. Kills the Balatro "build identity" feel — the player never feels their slots *cohere* around a playstyle, just that their numbers got bigger. The §16.7 "+ pairs Captain" gold pill loses meaning because nothing actually pairs with anything.

**Why not also cross-Joker chains** (e.g. *"if another slot has a `setIntent` Joker, +5% to my buff"*). Authored pair logic does not scale — at 40-60 Jokers the synergy graph explodes, every new Joker needs balancing against every existing one, and the balance harness has to special-case chains. The same depth comes free from emergent synergy: a `fieldMode(catching)`-triggered Joker plays well with a `setNextBowler(pace)` Joker because pushing one playstyle activates both. The UI can surface this as a "+ pairs Captain" gold pill *inferred from shared verb tags* — no authored chain metadata required.

**Consequences:**

- Joker authoring becomes a data-entry task — fill in the tuple, the balance harness tunes the magnitude. No code per Joker.
- Synergy is **emergent from trigger conditions**, not declared. Two Jokers that both fire on `fieldMode(catching)` naturally amplify a catching-trap build.
- The §16.7 synergy gold pill is a **UI inference layer**, not authored metadata. The render rule: when two Jokers in the Player's active slots share a primary verb tag (e.g. both trigger on `fieldMode(catching)`, both buff `tryReview`), each shows a gold `+pairs <name>` pip referencing the other. The pip is visual confirmation only — **no buff stacking math change**, the buffs were already stacking via the grammar. Cap at **one pip per Joker** even if multiple pairs exist (clutter limit). No archetype-level "build detected" banner — that would undermine the "discover the conditional rule" intent of ADR 0003.
- The balance harness models every Joker as the same tuple shape — no per-Joker code paths to maintain.
- The ceiling cost: you cannot build a *truly novel* Joker that defies the grammar (e.g. "draw two cards" — there are no cards to draw; "double your gold next round" — there is no per-round gold). Default answer: re-shape the idea into the grammar or skip it.
