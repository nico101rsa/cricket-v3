# Primary target: South Africa and Australia (not India)

## Context

`docs/DESIGN_HANDOFF.md` was written with **India as primary target market** (§2). Match length, commentary language, palette defaults, IP rules, and RAM-budget were all chosen to fit the Indian mobile-cricket market.

The success criterion for this project, however, is *"I play it and enjoy it"* (see `PROJECT_ROADMAP.md`). The creator is South African, living in Australia, and the planned playtest population is friends in those two countries.

## Decision

**Primary target countries are South Africa and Australia.** First-build content is SA + AUS master data only. India is deferred — possibly added later as content (the IP-safe Indian content in the handoff stays valid), but is no longer a design driver.

Implications:

- Default in-game language is **English**. Hindi/Tamil/Telugu are deferred. Afrikaans is an optional flavour pill, not first-build.
- Default Country palette and visual feel are SA / AUS, not India-red. The 10-Country palette system in DESIGN_HANDOFF §16.2 still applies, just with a different default.
- Team naming flavour is SA20-shape and BBL-shape, not IPL-shape.
- IP-safe rules (DESIGN_HANDOFF §7) still apply but are no longer load-bearing on first-build content.

## Considered alternatives

- **India-first (the handoff's original frame).** Rejected: optimises for a market the creator doesn't belong to and won't playtest. "Success = I play it and enjoy it" makes creator-fit beat market-fit.
- **Country-agnostic (no primary target).** Rejected: every game has cultural defaults somewhere. Refusing to pick means India's defaults stay by accident.

## Consequences

- `DESIGN_HANDOFF.md` §2 (target market), §6 (Indian session-length research as match-length rationale), and §7 (IP rules framing) are now legacy framing. They need a rewrite pass, deferred to a future cleanup.
- Soft-launch market list in `PROJECT_ROADMAP.md` (PAK / BAN / SLK / UAE) is now misaligned with primary target. The launch track is deferred anyway, but this should be revisited if launch becomes relevant.
- "Indian audience size" arguments for design decisions no longer apply. e.g. 3GB-RAM Android optimisation is over-engineering for SA/AUS first build; revisit if India is added.
