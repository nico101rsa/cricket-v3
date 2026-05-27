# Manager Boost — no menu, single side-aware buff

Pressing the Manager Boost button applies a single side-aware all-Attribute buff: `Power` + `Composure` for your batters when batting, `Attack` + `Control` for your current bowler when bowling. Magnitude is locked at press from the water-meter's current fill % (linear scaling — 50% fill → half strength, 100% → full). Once pressed, the meter **drains** during the active boost; the boost ends when the meter reaches 0%, after which recharge begins. Pressing at higher fill therefore yields both a *stronger* and a *longer* boost — a single-axis trade (total boost value scales roughly with fill²). There is no menu, no choice of effect — the **only** player decision is *when* to press.

**Why not the menu from §9 / §16.8.** The earlier design layered a Reigns-card menu (Pep Talk, Field Switch, Substitution, DRS Review, Captain's Word) on top of the water-meter timing. That stacked two strategic decisions per press onto a 3-second moment in a Match that already has 5–8 Key Moments doing the heavy tactical work. It also re-implemented mechanics already covered elsewhere — Captain's Word duplicates what Key Moment swipes already do; DRS Review duplicates the dedicated DRS Review Key Moment; Substitution duplicates Bowling Change. The buffs that *were* unique (Pep Talk, Field Switch) collapse cleanly into a generic "all Attributes ×(1 + fill × max)" formula.

**The decision the player makes.** Timing — press now for partial strength, wait for full, or save entirely for the death overs. That single dimension is enough; with ~6 max-strength presses available per Match (at the proposed ~25s recharge), the player has a real "when do I spend it?" budgeting game without an extra layer of "what do I spend it on?" friction.

**Consequences:**

- The Manager Boost UI is simpler: a green flash and an overlay banner, not a Reigns card. Implementation cost drops.
- All Manager Boost depth becomes Joker territory — Jokers can buff fill speed, magnitude, window length, side-asymmetry (e.g. boost only batters). The §9 menu options reincarnate as named Jokers rather than baseline mechanics.
- The §9 strawman menu and §16.8's "menu still appears" note are both deprecated by this ADR.
