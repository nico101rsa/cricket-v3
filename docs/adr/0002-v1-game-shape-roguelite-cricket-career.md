# V1 game shape: a roguelite cricket-career, with the club-management sim deferred

## Context

`docs/DESIGN_HANDOFF.md` pitches the game as Reigns × Balatro × **management**, with a Balatro-style roguelike run structure and a long list of squad / draft / scouting / season-hub screens (§11). The "Scope + Game shape" design theme set out to decide what V1 actually is.

## Decision

V1 is a **roguelite cricket-career**. The player is a single rising **Player** (not a club manager) climbing a 2D **Career grid** — Level (Club → City → Province) × Tour (eight named difficulty steps). Each grid cell is a **Season** — a ~20–30-minute playthrough (a 7-game league phase, then playoffs). Jokers are Season-scoped and reset between Seasons; the Player's stats persist — hence rogue*lite*, not roguelike.

Progression between Seasons is a **light career layer**: Teams make **Offers** (trading team strength against **Pay**); Pay is performance-scaled and is the single channel of permanent growth; **Affinity** rewards staying with a Team. The goal is to win the **Premium tour** (the top Tour) at the top Level.

First build ships **South Africa + Australia**, three Levels (Club / City / Province), eight Tours.

## Considered alternatives

- **Pure roguelike** (Balatro-style, every run from zero). Rejected: the creator wants persistent character progression and a career-climb narrative.
- **Full career / management sim** — the complete "management" pillar: transfer market, youth academy, stadium upgrades, and a living world of NPC players who move clubs, retire, and get injured. Rejected for V1: it is a second game's worth of systems and balancing. Explicitly deferred well past first build. Litmus test used to draw the line: *does an element feed a decision the player makes, or is it just the world being alive? Decisions stay; ambient life is cut.*
- **Single-Level / Club-only first build** (no climb). Rejected: the ladder climb is the narrative hook.
- **Two growth channels** (Pay-bought upgrades *plus* a separate performance/experience track). Rejected for V1 as a second balancing problem; instead performance *scales Pay*, keeping one channel while preserving the "I grow on the field" feel.

## Consequences

- The "management" pillar in DESIGN_HANDOFF is, for V1, reduced to the light Offers / Pay / Affinity layer. The squad / draft / scouting / player-development screens in §11 are deferred.
- A true second growth channel remains a possible later addition.
- Difficulty is a 2D grid with overlapping Level bands — see `CONTEXT.md`.
- DESIGN_HANDOFF §1, §2, §6, §7, §11, §12 have been revised to reconcile with this ADR and `CONTEXT.md`; its older framing is superseded where it still conflicts.
