# REQUEST → design: review the built Player Creation · Identity screen (3 deltas from the locked mockup)

> **Direction:** build-side **request to the claude.ai design track**. Design reads it via the GitHub connector, sees the renders, and replies with amendments (or "ship it"). This is a **review**, not a fresh brief — the screen is built.

## What was built
We translated the **already-locked** `docs/mockups/player-creation-v2.html` *Identity* band (Screen 1 — the portrait-anchored "Who are you?" screen) into the real Godot game on the shipped `Palette` / `UIStyle` / `Fonts` foundation — the sibling slice to the Build screen you just signed off (PRs #94/#95). **Faithful to your locked layout:** country-gradient header → hero portrait → name + sub + re-roll → country toggle → city pill → appearance picker → gold CTA.

**See the real renders:**
- `docs/mockups/latest/player-creation-identity.png` (SA — stable path, always newest)
- `docs/mockups/player-creation-identity-built-aus-v1.png` (the **Australia palette swap** — proves the one-token re-theme: header, toggle, accent ring, step dot, hero glow all move to the gold-forward palette)

Because it's a faithful translation of your own locked work, we're **not** asking for a full re-review. We only want your eye on the **three places where the real game had to diverge from the mockup** — each has a reason, but each is a taste call you may want to weigh in on.

## The 3 deltas to react to

1. **The hero portrait is a single placeholder; the appearance tiles don't swap it yet.** Your mockup swaps the hero between `hero-front` / `hero-helmet` / `keeper` / `hero-cap` as you tap a thumbnail. Only **`hero-cap.png`** exists today, so the hero is static and the 4 appearance tiles keep their **placeholder skin-tone tints** (lightest → darkest). The screen is built to consume real per-appearance art the moment the **portrait pipeline** rung lands. → *No action needed — flagging so the render doesn't read as "the tiles are broken." When you're ready, the portrait pipeline (which art per appearance × kit × skill tier) is the next design input.*

2. **No emoji — flags and the dice are gone.** The app-wide face is **Barlow Semi Condensed**, which has no emoji glyphs (they tofu — same lesson as the Build CTA). So the country toggle dropped the `🇿🇦`/`🇦🇺` **flags → text-only** (`SOUTH AFRICA` / `AUSTRALIA`), and the re-roll control uses the dingbat **`↻`** instead of `🎲`. Arrows (`→` on the CTA, `▾` on the city pill) are dingbats and render fine. → *OK as-is, or do you want drawn flag/dice icons as real image assets (so the flourish survives without emoji)?*

3. **No corner control on this screen.** Your mockup floats a corner `✕` (present on every screen). Identity is the **first** screen on a cold start (and the screen you land on after permadeath, from the Hall of Fame) — there's nowhere to close/back *to*, so a corner button would be a dead control. We omitted it. (Build legitimately keeps its `←` — its previous screen is this one.) → *Fine, or do you want a cosmetic corner mark for cross-screen consistency even though it wouldn't do anything here?*

## Everything else
Matches the locked mockup: country-gradient header w/ kicker `NEW PLAYER` + title `Who are you?` + 2 step-dots (dot **1** active — inverse of Build), accent-ringed hero portrait over a glowing country-gradient backing, centred name + `City · Country` sub + re-roll, segmented country toggle (selected = gradient + accent border), rounded city pill, rounded appearance tiles with an accent selection ring, gold `Next — Build your game →` CTA. SA-green / gold palette via `Palette.country_set`, one-token swap to AUS.

## Behaviour (unchanged, for context)
Country pick resets the city + re-rolls the name; appearance pick re-rolls the name; the name sub follows the city + country; `Next` is disabled until country + city + appearance + name are all set; tapping **Back** from Build re-hydrates this screen with your picks intact.
