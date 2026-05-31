# Global player ranking via Tour-distribution percentile

The Career Records screen (a drill-down from the Career Grid — see `docs/mockups/around-the-match-v1.html` §6b) surfaces a "rank in the world" stat: the Player's position against *every* other player across all Levels and Tours, displayed as `#X / 2,112`. This ADR records *how* that rank is computed — and crucially, that it is computed **analytically from existing inputs, not by simulating other Players**.

## The model

- **Population.** 8 Tours × 3 Levels × 8 Teams per league × 11 players per team = **2,112 hypothetical Players** in the world.
- **Each (Level × Tour) cell** already defines a strength distribution per ADR 0004 (mean × spread → battingStrength / bowlingStrength draws). The 24 distributions together define the full population.
- **The Player's mixed rating** (a single number combining their 4 Attributes for batting/bowling, weighted by current role) is compared into the *union* of all 24 cell distributions, weighted by cell population (88 each). The percentile yields a global rank.
- **Display.** `#X / 2,112` rank plus a "Top Y%" pill plus a "better than Z%" bar. Day 1 Career → bottom of the table (you're in Club Practise, the weakest cell). Career complete → top of the table.

## Why this works

- **Zero extra simulation cost.** Every other player's rating is *already* implied by the Tour × Team distribution math the auto-sim uses (ADR 0004). No per-rival stat tracking, no expanded save schema, no balance-harness scope creep.
- **Deterministic from existing inputs.** Same Career inputs → same rank, every time. Plays well with seeded deterministic auto-sim (ADR 0004) and the balance harness.
- **Cheap third door.** Considered alternative: simulate every other player as a first-class entity with persistent stats. Rejected — orders-of-magnitude more cost (~2,100 sim agents to maintain) for a feature that's a *display* surface, not a gameplay surface.
- **Reads as authentic.** The cricket fan understands "you rank 87th of 2,112 players in this country" instinctively. Doesn't need to know the underlying maths.

## Consequences

- **The 2,112 number is invariant per Country**, since the grid is fixed at 3 Levels × 8 Tours × 8 Teams × 11 players. If Levels are ever added beyond v1's three (U-20, B-side, National, International — see CONTEXT.md `Level`), the population scales proportionally and the ADR holds.
- **Mockup constants.** The around-the-match mockup uses #87 / 2,112 (top 4%) for the SA example and #41 / 2,112 (top 2%) for the AUS example. These are illustrative; real values are computed per-Player.
- **No global leaderboard.** This is *your* rank against the *world model*, not against other human players. Multiplayer is deferred (`docs/RESEARCH_LAUNCH_PLAYBOOK.md`); when/if it lands, a real leaderboard would supersede this — but the analytical rank still survives as a single-player feature.

Decided 2026-05-31 in response to claude.ai's `docs/design-handoff-from-claude-2026-05-31.md` introducing the Career Records screen.
