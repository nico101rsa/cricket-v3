# Around-the-match navigation shell

Theme 5 required deciding how the Player moves between the screens that wrap a Match. We chose three things together because they're mutually reinforcing:

1. **Season hub is the persistent home within a Season.** Between every Match's Result the Player returns to a single dense hub showing league position, fixtures chain, owned Jokers, Tons balance, Affinity, Player snapshot. Not a conveyor belt, not a launcher menu.
2. **Shop and Offer are forced full-screen interludes.** Triggered by the locked cadence (Shop after Match 3, 5, semi, championship + free Season-start; Offer after Match 4 mid-Season + 3 end-of-Season). They appear as their own full screens *after Result, before returning to the hub* — no skip, no hub-overlay. Auto-return to hub on close.
3. **No Main Menu.** App launches with a tiny splash and lands on whichever screen the Player was last on (mid-Season → Season hub; between Seasons → Career Grid; first-ever launch → Onboarding). Settings is a gear icon in the corner of every screen.

The Career Grid (between Seasons) and Season hub (within a Season) together serve the home-screen role, so a Main Menu would only add taps. Forced Shop/Offer interludes guarantee the meta-loop trade-offs are presented at the locked cadence — the Strategic-layer choice (ADR 0003) deserves dedicated screens, not a hub overlay. The hub itself stays uncluttered because it never has to host a Shop or Offer mode inline.

Decided 2026-05-30 via a `grill-with-docs` session (Q1+Q2+Q3 in `docs/THEME-5-HANDOFF.md`); the chosen shape was visually realised in `docs/mockups/around-the-match-v1.html`.

## Considered alternatives

- **Conveyor belt within a Season.** Result auto-pushes Pre-match without a hub in between. Rejected — leaves no surface for "where am I in this Season?" between Matches, and the hub is the natural place to keep the Jokers bench permanently visible (Balatro pattern, hi-fi §16.7).
- **Hub-banner opt-in for Shop/Offer.** A "Shop Open" banner on the hub the Player taps when ready. Rejected — risks skipping a Shop/Offer accidentally, which would break the meta-loop cadence.
- **Hub-inline Shop/Offer.** The hub re-skins itself when the Shop is open. Rejected — overloads the hub's visual mode, blurs the Strategic-layer trade-off, no room for the side-by-side Tons+Jokers spend.
- **Traditional Main Menu launcher.** Continue / New Career / Settings as a top-level screen. Rejected — nothing for it to do once the Career Grid serves the "between Seasons" home; resume-first is the roguelite convention (Slay-the-Spire / Balatro / Hades).
