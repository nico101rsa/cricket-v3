# REQUEST → design: translate our final in-match design into a Godot handoff

> **Direction:** this is a build-side **request to the claude.ai design track** (the reverse of a normal inbox brief). Design reads it via the GitHub connector, then drops the actual handoff back as `docs/design-inbox/in-match.md` (+ reference image).

We already have the **final visual design**: `docs/mockups/match-screen-final.html` ("The game · revised layout v4"). **Don't redesign it.** The job is a **translation**: convert that exact design into a Godot-friendly handoff spec precise enough that the Godot build matches the HTML closely on the first pass.

**Why precision matters:** last time (the Season Hub) the build drifted from the design and looked crappy, because an HTML mockup alone doesn't pin exact sizes/spacing/tokens. A tight spec is the fix — it's what stops the Godot build drifting.

## What to produce
1. A **reference render PNG** of the final design — the states it already shows: **Auto-sim**, **Key Moment**, **Boost used**, **Result** — plus the **DRS review** overlay if you can (it's a real built state).
2. A **GODOT-AI-PROMPT spec `.md`**: for every block, its **size, spacing/padding, font size/weight, and which `Palette`/`UIStyle` token it uses**. This precision is the whole point.
3. **Re-theme to our shipped look** while keeping the layout identical: SA green / Karoo Kings, ₸ currency, via the existing `Palette.country_set("ZA")` tokens (bg `#0f0f14`, green `#007749→#003e26`, gold `#FFB81C`). The v4 mockup is still Mumbai/Chennai red — swap the colours, keep the structure.
4. A list of any **new `Palette`/`UIStyle` tokens** you need so Claude Code can add them.

## The five built states (so the spec covers what actually exists)
1. **Auto-sim (live watch)** — scoreboard (`1ST INNINGS  72/2`, run-rate), on-strike batsmen, current bowler, partnership, ball-by-ball feed, controls bar (Back · Step · Play/Pause · Speed 1x/2x/4x · **BOOST**).
2. **Key Moment card** — modal that pauses the match, two-button call. Batting: ⚡ Powerplay Exit (over 7) · 🩸 Wicket Crisis (first middle wicket) · 💀 Death Plan (over 16). Bowling: 🎯 Powerplay Exit · 🔥 New Batsman In · 💀 Death Defence. Title + context line + two choice buttons.
3. **Boost** — button's three states: `BOOST (2)` available → `BOOST ON` (charging) → recharged; plus the "burn a boost?" framing the v4 mockup shows.
4. **DRS review overlay** — fires when *you're* given out: "Review? (n left)" → Yes/No → ✅/❌ outcome popup → OK.
5. **Result screen** — won/lost by margin, "league point", opponent + date, the player's final card line.

**Defer (not built):** Milestone-ball, Final-over micro-swipe.

## Constraints to respect
- 390×844 portrait, **no scroll** — fits one screen.
- **Never show raw attributes** (PWR/COM/ATT/CON) — only OVR + match stats (runs/balls/SR, wickets/economy, ★).
- Overlays are **modal pauses** over the live match.
- Keep it **implementable in Godot** (Labels / Panels / StyleBoxFlat) — no exotic CSS-only effects.
- Honour the v4 note: **"less-stretched bar-graph / auto-sim bar."**

## Then
Claude Code builds it, renders the real screen to `docs/mockups/latest/in-match.png`, and **we iterate until the Godot build matches the v4 design exactly.**
