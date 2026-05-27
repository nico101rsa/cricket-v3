# Auto-sim architecture

The auto-sim is a **headless, pure, deterministic-seedable** module — independent of Godot's scene tree and rendering. Same seed in → same Match out, every time. This is the load-bearing call: it lets the balance harness run thousands of Seasons in a tight loop without the rendering layer, and it lets the skill-model metric (optimal-vs-naive gap, ADR 0003) actually be measured empirically rather than estimated by feel.

Within that module, four shape decisions hold:

1. **Ball-by-ball.** The engine rolls every one of the ~240 deliveries per Match. Aggregate-with-backfill (computing segment totals then faking individual balls for display) creates permanent consistency drag — Key Moment triggers like "batter on 49" or "key wicket falls" become fake events — for no real saving. 240 rolls per Match is computationally trivial.

2. **Only the Player is statted; everyone else is derived.** The Player carries four persistent **Attributes** — `Power`, `Composure`, `Attack`, `Control` — upgraded via Pay. Every other player (10 teammates + 11 opponents) is generated from `(teamStrength, role, seed)` at Match start and thrown away. The sim treats all 22 uniformly; only one stat-block is real. Per ADR 0002, full per-player stats would quietly rebuild the management sim that was deferred.

3. **Two-stage logistic resolution.** Each ball is two contests in sequence: a wicket roll (`Attack` vs `Composure`), then — if survived — a runs roll (`Power` vs `Control`). Each contest uses a logistic / Elo-style curve, so extreme mismatches saturate gracefully and a maxed Player still faces real risk on a hard Tour. **Intent** (three bands — Defensive / Balanced / Aggressive, set by Key Moments) is a *coupled* modifier on both rolls: more aggression scores faster *and* dies sooner. That coupling is what makes every Key Moment a genuine expected-value trade-off per ADR 0003.

4. **The sim is pressure-blind.** Required run rate, wickets in hand, balls remaining — none feed the rolls directly. The Player reads pressure and responds via Key Moments. Reading pressure IS the skill (ADR 0003).

**Why not the obvious path:** sim logic inside Godot scene nodes, with stats hand-authored per player and outcomes drawn from a single distribution lookup. That path makes rendering convenient but makes balance-harness simulation impractical (or expensive enough never to get built), and makes the four-Attribute aggression trade-off impossible to express cleanly. This ADR exists to stop a future contributor from "simplifying" by collapsing the sim into the UI layer.

**Consequences:**

- The sim exposes a tight API: `(matchSetup, seed) → matchLog`. The UI animates the log; it does not drive the sim.
- All tuning lives in data — logistic scale per roll, Form multipliers, Tour strength distributions, Joker effect coefficients, Boost effect coefficients. The balance harness sweeps the data, not the code.
- Adding a new Joker, Manager Boost option, or Key Moment means defining what it does to the two rolls or to Intent. No other lever exists.
