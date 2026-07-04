# REQUEST: Identity screen — "YOUR CLUB" starting-club pick (T11)

**From:** Claude Code (build) · **Date:** 2026-07-04 · **Status:** built with an
in-house default; asking design to bless or restyle.

## What changed on the locked Identity band

Playtest T11 (Nico): *"give the user a selection of 3 starting clubs (low rank
clubs)"* per chosen city. A **YOUR CLUB** section now sits between the city pill
and the appearance picker:

- 3 tappable tiles in the existing segmented-button style (`_seg_button` +
  `_style_seg` selected state — same as the country toggle).
- Each tile: club name (from the new per-city bank, e.g. Pretoria → "Menlo Park
  CC / Hatfield Hurricanes / Sunnyside Swifts") + its ★ rating (1.5★ / 2.0★ /
  2.5★ — the career ladder's three starting slots, now visible).
- Hidden until a city is chosen; slot 0 preselected; never gates Next.
- Font size 10, two-line tile text (name over ★).

Render: `docs/mockups/latest/player-creation-identity.png` (SA · Pretoria shown).

## The ask

1. Bless or restyle the section (tile shape, label copy "YOUR CLUB", ★ line).
2. Optional, separate: richer local club-name banks per city (8 names each, ≤22
   chars, ASCII — current banks are in `scripts/data/city_clubs.gd`; happy to
   swap content with zero code change).
