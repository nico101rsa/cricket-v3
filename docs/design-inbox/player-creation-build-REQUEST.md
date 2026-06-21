# REQUEST → design: review the built Player Creation · Build screen (3 deltas from the locked mockup)

> **Direction:** build-side **request to the claude.ai design track**. Design reads it via the GitHub connector, sees the render, and replies with amendments (or "ship it"). This is a **review**, not a fresh brief — the screen is built and merged (PR #94).

## What was built
We translated the **already-locked** `docs/mockups/player-creation-v2.html` *Build* band (Screen 2 — the 4-attribute points-spend screen) into the real Godot game on the shipped `Palette` / `UIStyle` / `Fonts` foundation. **Faithful to your locked layout** (country-gradient header → points meter → Batting/Bowling groups w/ drag sliders → classifier panel → gold CTA).

**See the real render:** `docs/mockups/latest/player-creation-build.png` (stable path — always newest).

Because it's a faithful translation of your own locked work, we're **not** asking for a full re-review. We only want your eye on the **three places where the real game had to diverge from the mockup** — each has a reason, but each is a taste call you may want to weigh in on.

## The 3 deltas to react to

1. **CTA flourish — the 🏏 emoji is gone.** The app-wide face is **Barlow Semi Condensed**, which has no emoji glyphs, so `Begin Career 🏏` rendered as tofu. We shipped plain **`Begin Career`**. → *Want a non-emoji flourish instead (a `▶`, a small drawn bat icon as an asset, an underline/arrow), or is plain text final?*

2. **The points meter reads `44 / 44` and sits near-full.** Your mockup showed "Points spent 22 / 32" — but the **real** creation budget is a **fixed 44 points you redistribute** (every valid build sums to exactly 44; min 3 / max 25 per attribute, shown on the /100 card). So a global "spent" bar is basically always full and only dips when the build is *invalid*. We kept it as a **validity meter** (value tints red when ≠ 44). → *Is a global budget bar still the right read, or would you rather drop it and let the per-slider fills carry the "where my points went" story? (Or reframe it as "remaining to allocate" only while unbalanced?)*

3. **Back button is inline in the header, not a floating corner button.** Your mockup floated a `←` corner button top-left. We placed it **inline at the left of the header row** (left of the kicker/title) to guarantee it never overlaps the kicker text. → *Fine, or do you specifically want the floating-corner treatment to match the other screens' ⓘ/⚙ corners?*

## Everything else
Matches the locked mockup: gradient header w/ kicker + title + 2 step-dots, Batting (gold icon) / Bowling (blue icon) groups, custom accent-filled sliders w/ white-ring thumbs, the glowing classifier panel (`YOU'LL START AS A` + accent label + flavour blurb), SA-green / gold palette via `Palette.country_set`.

## Note for the next slice
**Identity (Screen 1)** is the natural sibling but it's **blocked on the portrait pipeline** — its hero + 4-thumbnail appearance picker need `hero-front` / `hero-helmet` / `keeper` portraits; only `hero-cap.png` exists today. No action needed from you on that here — just context for why Build went first.
