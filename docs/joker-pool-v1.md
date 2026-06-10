# Joker Pool — V1 (45 Jokers)

The content half of Theme 4. Architecture is locked by ADR 0007 (authoring grammar) and ADR 0006 (6-verb palette); this doc enumerates the 45 specific Jokers that fill the pool.

V1 = first complete pass. Names and verb compositions are the authoring intent and should hold up.

> **Magnitudes tuned 2026-06-10 (rarity-band re-tune, rung 2).** The multipliers below now reflect the balance-harness re-tune against the fair-fight baseline (48.1% no-joker floor) — each non-enabler joker's solo win-delta targets its rarity band (Common +1–4% · Rare +4–7% · Legendary +7–12%). ₸ prices remain strawman. Conditional jokers that the neutral sweep under-fires (Form-consumers, bowling-change triggers, toss-gated chases) sit below band by fire-rate, not magnitude — see the spec's residuals table. The DRS "retain on fail" mechanic (Captain's Call / Review Master) was replaced by bounded extra-review grants.
>
> **Scenario-sweep rung (2026-06-10, rung 3).** Conditional jokers were re-measured in contexts that fire them (a chase profile + designed combos), and the under-powered *uncontrollable* ones buffed toward realized band: **The Chase Master ×1.20→×1.40**, **Match-Winner's Vigil ×0.80→×0.62**, **Wicket Maiden ×1.30→×1.45**. **Fire-rates (rung-D pricing input):** The Chase Master fires ~**50%** of matches (the toss; in-condition +7.2% → realized ~+3.6%). Two honest residuals: the Chase Master's runs-mult **saturates against the chase win-ceiling** (runs past the target are wasted) and Wicket Maiden's emergent trigger is **participation-capped** — neither reaches realized band by magnitude alone (would need a mechanic change). See spec `2026-06-10-scenario-sweep-conditional-jokers-design.md` §10.

---

## Pool composition

| Archetype | Common | Rare | Legendary | Total | Primary verb tags (drives the "+ pairs" gold pip) |
|---|---|---|---|---|---|
| Anchor | 4 | 2 | 1 | 7 | `setIntent(Defensive/Balanced)` · `buffNextBalls(wicket,<1)` · `formEvent(Player,+)` |
| Tempo | 4 | 3 | 1 | 8 | `setIntent(Aggressive)` · `buffNextBalls(runs,>1)` · `formEvent(Player,+)` |
| Strangler | 4 | 2 | 1 | 7 | `setIntent(Defensive)` (bowling) · `fieldMode(defensive)` · `buffNextBalls(runs,<1)` |
| Wicket Hunter | 4 | 3 | 1 | 8 | `setNextBowler` · `fieldMode(catching)` · `buffNextBalls(wicket,>1)` |
| Boost Stack | 4 | 2 | 1 | 7 | `buffNextBalls`-from-Boost · `formEvent(Player,+)` |
| Reviewer | 4 | 3 | 1 | 8 | `tryReview` |
| **Total** | **24** | **15** | **6** | **45** | |

₸ price bands (V1 strawman, balance-harness tuned):
- **Common**: ₸ 30–50
- **Rare**: ₸ 90–120
- **Legendary**: ₸ 220–250

---

## Grammar notes (apply across the pool)

These are the corners of ADR 0007's grammar this pool leans on. Worth pinning so the balance harness models them consistently:

1. **Game-state conditions count as "verb in state Y"** — ball-count windows ("first 18 balls", "from ball 90"), innings-side ("while batting" / "while chasing"), and per-innings counters are all persistent state the auto-sim tracks. Treated as legal trigger conditions.
2. **Source-qualified verb firing is allowed under "condition Z"** — "when Manager Boost fires" means *a `buffNextBalls` whose source = Boost press, not a KM*. Boost Stack archetype depends on this distinction.
3. **Joker `formEvent` targets the Player only** — CONTEXT.md restricts per-ball Form ticks to the Player; only KMs can move teammate/opponent Form. Jokers never violate this.
4. **Windowed-buff lifecycle events are not verb fires** — "when Boost ends" is grammar-dodgy and is not used in V1. If we want end-of-window payoffs later, propose a 7th verb (`onWindowEnd`) and weigh it against ADR 0006's "default answer: re-shape".

---

## Anchor — survive, accumulate, deny the wicket (7)

| # | Name | Rarity | Verb composition | Effect text (user-facing) | Flavour | ₸ |
|---|---|---|---|---|---|---|
| 1 | Dead Bat | Common | while `setIntent(Defensive)`: `buffNextBalls(wicket, ×0.92, n=1)` per ball | *While Defensive: wicket chance −8% every ball.* | "Soft hands, soft hands, soft hands." | 35 |
| 2 | The Sheet Anchor | Common | when `setIntent(Balanced)` fires: `formEvent(Player, +1)` | *Switch to Balanced → Player Form +1.* | "Drop the gear back into second. Settle in." | 40 |
| 3 | Block the Shine | Common | trigger: innings ball ≤ 18 while batting → `buffNextBalls(wicket, ×0.90, n=18)` at innings start | *First 18 balls of your innings: wicket chance −10%.* | "See it off. The bowlers will tire." | 30 |
| 4 | Rotate the Strike | Common | while `setIntent(Balanced)`: `buffNextBalls(runs, ×1.08, n=1)` per ball | *While Balanced: runs roll +8%.* | "Singles add up. Singles always add up." | 50 |
| 5 | Building Phase | Rare | while `setIntent(Defensive)` AND Player has faced 6 consecutive balls: `formEvent(Player, +1)`, repeats every 6 | *Every full over you survive while Defensive: Player Form +1.* | "Twenty minutes in. Eyes are in. Now bat." | 90 |
| 6 | Carry Your Bat | Rare | while `setIntent(Defensive)`: `buffNextBalls(wicket, ×0.85, n=1)` AND `buffNextBalls(runs, ×1.12, n=1)` per ball | *While Defensive: wicket chance −15%, runs roll +12%.* | "Bat all 20 overs. The rest is bonus." | 110 |
| 7 | Match-Winner's Vigil | Legendary | when `formEvent(Player, +)` fires while batting: `setIntent(Defensive)` AND `buffNextBalls(wicket, ×0.62, n=24)` | *Player Form rises while batting → snap Defensive, wicket chance −38% for next 24 balls.* | "Get there. Stay there." | 220 |

---

## Tempo — accelerate, ride boundaries, hot streak (8)

| # | Name | Rarity | Verb composition | Effect text (user-facing) | Flavour | ₸ |
|---|---|---|---|---|---|---|
| 8 | Powerplay Punch | Common | while `setIntent(Aggressive)`: `buffNextBalls(runs, ×1.05, n=1)` per ball | *While Aggressive: runs roll +5%.* | "First six overs. Send it." | 40 |
| 9 | Field Restrictions | Common | while batting AND opposing `fieldMode(catching)`: `buffNextBalls(runs, ×1.05, n=1)` per ball | *While batting against a catching field: runs roll +5%.* | "Catching field? Hit it over them." | 45 |
| 10 | Ride the Wave | Common | when `formEvent(Player, +)` fires while batting: `buffNextBalls(runs, ×1.20, n=3)` | *Player Form rises while batting → runs roll +20% for 3 balls.* | "Hot. Hot. Hot." | 50 |
| 11 | Captain's Statement | Common | when `setIntent(Aggressive)` fires: `formEvent(Player, +1)` | *Switch to Aggressive → Player Form +1.* | "Tell the change-room. We're chasing this down." | 35 |
| 12 | Slog Over Specialist | Rare | from ball 90 while `setIntent(Aggressive)`: `buffNextBalls(runs, ×1.35, n=1)` per ball | *Death overs (last 30 balls) while Aggressive: runs roll +35%.* | "Bowlers are tired. Bat first, ask later." | 100 |
| 13 | Boundary Hunter | Rare | when `formEvent(Player, +)` fires while batting: `setIntent(Aggressive)` | *Player Form rises while batting → snap to Aggressive.* | "One four. One more. One more." | 90 |
| 14 | Hot Streak | Rare | when `formEvent(Player, +)` fires twice within 6 balls: `buffNextBalls(runs, ×1.30, n=6)` AND `buffNextBalls(wicket, ×0.85, n=6)` | *Two Form gains in an over: runs roll +30%, wicket chance −15% for 6 balls.* | "Stay in. The over's yours." | 120 |
| 15 | The Chase Master | Legendary | while 2nd-innings AND `setIntent(Aggressive)`: `buffNextBalls(runs, ×1.40, n=1)` per ball; when `formEvent(Player, +)` fires: extend the active buff `n+=2` | *Second innings + Aggressive: runs roll +40% every ball, window extends 2 balls each time Form rises.* | "Required rate? What required rate." | 240 |

---

## Strangler — bowling, dry up runs, defensive field discipline (7)

| # | Name | Rarity | Verb composition | Effect text (user-facing) | Flavour | ₸ |
|---|---|---|---|---|---|---|
| 16 | Tight Lines | Common | while bowling AND `fieldMode(defensive)`: `buffNextBalls(runs, ×0.93, n=1)` per ball | *While bowling with a defensive field: runs conceded −7%.* | "Yorkers wide of off. All night." | 35 |
| 17 | Squeeze the Middle | Common | while bowling AND innings ball ∈ [36, 90]: `buffNextBalls(runs, ×0.92, n=1)` per ball | *Middle overs (overs 7–15): runs conceded −8%.* | "Slow it down. Make them swing." | 40 |
| 18 | Defensive Captain | Common | when `setIntent(Defensive)` fires while bowling: also `fieldMode(defensive)` set | *Switch to Defensive while bowling → also set a defensive field.* | "Boundary riders in. Sweepers wide. Strangle them." | 30 |
| 19 | Pressure Cooker | Common | while bowling AND opposing `setIntent(Defensive)`: `buffNextBalls(wicket, ×1.10, n=1)` per ball | *Bowling against a Defensive opposition: wicket chance +10%.* | "They're shutting up shop. Force the error." | 50 |
| 20 | Dot Ball Pressure | Rare | while bowling AND `fieldMode(defensive)`: `buffNextBalls(wicket, ×1.12, n=1)` AND `buffNextBalls(runs, ×0.88, n=1)` per ball | *While bowling with a defensive field: wicket chance +12%, runs conceded −12%.* | "Suffocation. They're swinging at thin air." | 95 |
| 21 | Death-Over Stranglehold | Rare | while bowling AND innings ball ≥ 90: `buffNextBalls(runs, ×0.83, n=1)` per ball | *Death overs (last 30 balls) while bowling: runs conceded −17%.* | "They came for sixes. They'll leave with twos." | 115 |
| 22 | Choke Hold | Legendary | while bowling AND `fieldMode(defensive)` AND `setIntent(Defensive)`: `buffNextBalls(runs, ×0.75, n=1)` AND `buffNextBalls(wicket, ×1.15, n=1)` per ball | *Defensive intent + defensive field while bowling: runs conceded −25%, wicket chance +15%.* | "The kind of over they show on the highlights reel. As context for the collapse." | 230 |

---

## Wicket Hunter — attack stumps, catching cordons, change-bowler strikes (8)

| # | Name | Rarity | Verb composition | Effect text (user-facing) | Flavour | ₸ |
|---|---|---|---|---|---|---|
| 23 | Cordon Killer | Common | while `fieldMode(catching)`: `buffNextBalls(wicket, ×1.10, n=1)` per ball | *While catching field: wicket chance +10%.* | "Three slips, gully, leg slip. Edge anywhere is a chance." | 40 |
| 24 | Pace Pack | Common | when `setNextBowler(pace)` fires: `buffNextBalls(wicket, ×1.15, n=6)` | *Bowling change to pace → wicket chance +15% for 6 balls.* | "Fresh pace. Hard length. Watch the splice go." | 35 |
| 25 | Spinner's Web | Common | when `setNextBowler(spin)` fires: `buffNextBalls(wicket, ×1.15, n=6)` | *Bowling change to spin → wicket chance +15% for 6 balls.* | "Loop it up. They'll dance down. They'll miss." | 35 |
| 26 | Attack the Stumps | Common | while bowling AND `setIntent(Aggressive)`: `buffNextBalls(wicket, ×1.12, n=1)` per ball | *Bowling with an Aggressive captaincy: wicket chance +12%.* | "Bowled, LBW, hit-the-stumps. Three ways to get them." | 45 |
| 27 | First-Change Specialist | Rare | every `setNextBowler(*)` fire: `buffNextBalls(wicket, ×1.20, n=6)` AND `fieldMode(catching)` set | *Every bowling change: wicket chance +20% for 6 balls, and a catching field snaps in.* | "New bowler, new plan, new chance. Every time." | 100 |
| 28 | The Trap | Rare | while `fieldMode(catching)` AND most-recent `setNextBowler` = `spin`: `buffNextBalls(wicket, ×1.25, n=1)` per ball | *Catching field with spin on: wicket chance +25%.* | "Bat-pad, silly point, deep midwicket. Pick your poison." | 110 |
| 29 | Wicket Maiden | Rare | when `formEvent(Player, +)` fires while bowling: `buffNextBalls(wicket, ×1.45, n=6)` | *Player Form rises while bowling → wicket chance +45% for 6 balls.* | "On a roll. The hat-trick ball is the next one." | 105 |
| 30 | The Strike Bowler | Legendary | when `setNextBowler(*)` fires AND `fieldMode(catching)` is set: `buffNextBalls(wicket, ×1.35, n=12)` AND `formEvent(Player, +1)` | *Bowling change into a catching field: wicket chance +35% for 12 balls, Player Form +1.* | "Top of the run-up. The captain has a feeling. The captain is right." | 250 |

---

## Boost Stack — Manager Boost amplifiers (7)

`buffNextBalls`-from-Boost is the source filter. Each Joker either modifies the Boost's parameters (`mult`, `n`) or chains a second effect onto the Boost press.

| # | Name | Rarity | Verb composition | Effect text (user-facing) | Flavour | ₸ |
|---|---|---|---|---|---|---|
| 31 | Power Up | Common | when Manager Boost (`buffNextBalls`-from-Boost) fires: extend `n` by +2 | *Manager Boost: window lasts 2 extra balls.* | "Hold it longer. Squeeze every drop." | 40 |
| 32 | Boost Battery | Common | when Manager Boost fires: also `buffNextBalls(runs, ×1.10, n=Boost.n)` if batting / `buffNextBalls(wicket, ×1.10, n=Boost.n)` if bowling | *Manager Boost gets a side-aware kicker: +10% to runs (batting) or wicket chance (bowling) for the boost window.* | "Same press. More juice." | 45 |
| 33 | Boost Adrenaline | Common | when Manager Boost fires: `formEvent(Player, +1)` | *Press Manager Boost → Player Form +1.* | "The crowd. The captain. The moment." | 35 |
| 34 | Pedal to the Metal | Common | when Manager Boost fires: also `setIntent(Aggressive)` | *Manager Boost → Intent snaps to Aggressive.* | "No half measures. Stand up. Take it." | 45 |
| 35 | Power Surge | Rare | when Manager Boost fires: amplify `mult` by ×1.40 AND extend `n` by +3 | *Manager Boost: multiplier amplified by +40%, window +3 balls.* | "Why press once when you can press once, harder." | 100 |
| 36 | Compounding Pressure | Rare | when Manager Boost fires AND `setIntent(Aggressive)`: also `buffNextBalls(runs, ×1.40, n=Boost.n)` AND `buffNextBalls(wicket, ×0.85, n=Boost.n)` if batting; mirror if bowling | *Manager Boost while Aggressive: runs roll +40%, wicket chance −15% across the boost window (side-aware).* | "Pick a moment. Make it loud." | 120 |
| 37 | The Comeback Press | Legendary | every Manager Boost fire: `formEvent(Player, +2)`. On the **3rd** Manager Boost of the Match: amplify `mult` by ×1.50 AND extend `n` by +6 | *Every Manager Boost: Player Form +2. Your 3rd Boost of the Match: multiplier ×1.5, window +6 balls.* | "Three presses. The third one is the one they remember." | 220 |

---

## Reviewer — DRS specialists (8)

`tryReview`'s native shape (roll P(success); flip outcome on success and retain the review, consume on fail) gives more handles than it looks: bump P(success), grant extra reviews, chain a payoff onto a successful review. *(The original "retain on fail" handle was retired in the 2026-06-10 re-tune — it gave effectively infinite reviews with no scalar to tune; Captain's Call / Review Master now grant bounded extra reviews instead.)*

| # | Name | Rarity | Verb composition | Effect text (user-facing) | Flavour | ₸ |
|---|---|---|---|---|---|---|
| 38 | Cool Head | Common | when `tryReview` fires: P(success) +10% | *DRS reviews: success chance +10%.* | "Watch it again. Now watch it again." | 35 |
| 39 | Captain's Eye | Common | when `tryReview` fires while `setIntent(Defensive)`: P(success) +20% | *DRS while Defensive: success chance +20%.* | "Calm helps. The bat doesn't lie." | 40 |
| 40 | Spare Review | Common | at innings start: +1 to the `tryReview` resource counter for this innings | *+1 DRS review per innings.* | "We saved one. We had a feeling." | 45 |
| 41 | Hot Spot | Common | when `tryReview` succeeds: `formEvent(Player, +1)` | *Successful DRS → Player Form +1.* | "They got it wrong. We knew." | 40 |
| 42 | Snicko | Rare | when `tryReview` fires: P(success) +12% | *DRS reviews: success chance +12%.* | "Spike. Spike. Spike. Three views, three spikes." | 90 |
| 43 | The Captain's Call | Rare | at innings start: +2 to the `tryReview` resource counter for this innings | *+2 DRS reviews per innings.* | "Umpire's call? We'll try again." | 105 |
| 44 | Bowler's Backing | Rare | when `tryReview` succeeds while bowling: `buffNextBalls(wicket, ×1.20, n=6)` | *Successful DRS while bowling → wicket chance +20% for 6 balls.* | "One overturned. Now stick another in the same spot." | 110 |
| 45 | The Review Master | Legendary | when `tryReview` fires: P(success) +6%; at innings start: +2 to the `tryReview` counter; when `tryReview` succeeds: `formEvent(Player, +2)` | *DRS reviews: success +6%, +2 reviews per innings. Successful review → Player Form +2.* | "We don't waste reviews. We make moments." | 230 |

---

## Emergent synergy spot-checks

ADR 0007 §16.7's "+ pairs Captain" gold pip renders when two active-slot Jokers share a primary verb tag. A handful of intended pairings, to sanity-check the pool actually lets identities cohere:

- **Wicket Hunter catching-trap build**: Cordon Killer (#23) + The Trap (#28) + First-Change Specialist (#27) — all share `fieldMode(catching)`. Adding Pace Pack (#24) or Spinner's Web (#25) layers a `setNextBowler` synergy on top.
- **Anchor → Tempo bridge**: The Sheet Anchor (#2) sets Balanced → Form +1; Ride the Wave (#10) fires on that Form gain → runs roll +20%. The pair pip should highlight `formEvent(Player, +)` across archetypes — "settle, then accelerate".
- **Strangler death-over lock**: Death-Over Stranglehold (#21) + Choke Hold (#22) + Tight Lines (#16) — all share `fieldMode(defensive)` while bowling.
- **Boost Stack stack**: Power Up (#31) + Power Surge (#35) compound multiplicatively on every Boost press; Pedal to the Metal (#34) means the Boost itself flips you Aggressive, which unlocks Compounding Pressure (#36)'s extra layer.
- **Reviewer chain**: Spare Review (#40) + The Captain's Call (#43) + Snicko (#42) — together ~5 reviews per innings (base 2 + Spare 1 + Captain's Call 2), each at +12% success (Snicko), kept on every overturn. Bowler's Backing (#44) then turns each successful review into a wicket-chance window. *(Post-re-tune this is the strongest archetype stack — the all-in Reviewer build still tops the sweep at ~+34% win-delta; expected reward for committing the whole hand.)*

Anti-pattern check: I tried not to author Jokers that need an *opposing* Joker to function (e.g. "X only works if you also own Y"). ADR 0007 forbids cross-Joker chains and the pool stays inside that line — every Joker is independently meaningful.

---

## Open tuning questions for the balance harness

Things V1 explicitly leaves open for Theme 7 to settle:

1. **Wicket-chance multipliers stack multiplicatively** — Cordon Killer (#23, ×1.10) + The Trap (#28, ×1.25) + Wicket Maiden (#29, ×1.30) → ×1.79 on a single ball. Is that the ceiling we want, or does the auto-sim need a per-ball cap?
2. **Manager Boost compounding** — Power Up (#31) + Power Surge (#35) + Compounding Pressure (#36) on a 3rd-Boost press with The Comeback Press (#37) is a *very* long, *very* loud window. Likely the highest-variance state in the pool; needs explicit playtest.
3. **Form-trigger feedback loops** — Boundary Hunter (#13) flips you Aggressive on Form gain; Hot Streak (#14) fires on rapid Form gains; Ride the Wave (#10) gives a runs window on every Form gain. A hot Player batting can chain three different Jokers off a single boundary. Almost certainly overpowered before the harness tunes it down, but feels like the right *kind* of overpowered (the Balatro snowball moment).
4. **Match-Winner's Vigil (#7) re-triggers** — `formEvent(Player, +)` fires multiple times in an innings (every milestone Form bump). Each fire grants a fresh 24-ball wicket-chance reduction. Refresh or stack? V1 reading: refresh (a single rolling window). Confirm at harness time.
5. **Price bands are V1 strawman** — no in-game ₸ economy has been tuned yet. Once Tons inflow per Match is set (Theme 7), these all rescale together.

---

## What this unblocks

- **Theme 6 (visual content)** — joker art can be designed against named, archetyped cards.
- **Theme 7 (balance harness)** — the harness can ingest this pool as 45 typed tuples and start sweeping magnitudes.
- **Carry-over picks** — every archetype now has a Legendary-tier carry candidate plus 1–2 archetype-defining Commons worth holding for next Season's build.
