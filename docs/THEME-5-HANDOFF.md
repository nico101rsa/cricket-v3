# Theme 5 — Around-the-match screens · Claude.ai hi-fi handoff

A self-contained brief for designing the around-the-match screens (everything that wraps a Match) as hi-fi HTML mockups in a fresh **Claude.ai** conversation. The in-Match screen is already locked (`docs/mockups/match-screen-final.html` + `DESIGN_HANDOFF.md` §16) and is **not** in scope.

---

## How to use this doc

1. Open a new conversation at **claude.ai**.
2. **Attach these files** (drag-drop into the chat):
   - This file (`docs/THEME-5-HANDOFF.md`)
   - `CONTEXT.md`
   - `docs/DESIGN_HANDOFF.md`
   - `docs/mockups/match-screen-final.html` *(the locked in-Match design — for visual continuity)*
   - `docs/mockups/in-match-hi-fi-v1.html` *(the hi-fi addendum — for tokens, jokers panel, water-meter boost)*
3. Paste **[The prompt](#the-prompt-to-paste)** at the bottom of this doc.
4. Iterate. When the HTML is ready, copy it into:
   `docs/mockups/around-the-match-v1.html`
   (one file, multiple phone frames side-by-side — same pattern as `match-screen-final.html`).
5. Return to Claude Code in this repo and we'll either lock it or iterate further from here.

---

## Architecture decisions — LOCKED (don't override)

These were resolved in a `grill-with-docs` session before switching to claude.ai. Pass them through verbatim.

1. **Persistent home within a Season = Season hub.** Not a conveyor belt, not a launcher menu. After every Match's **Result**, the player returns to the **Season hub**.
2. **Persistent home between Seasons = Career Grid.** When a Season ends and the end-of-Season ritual completes, the player lands on the Career Grid to pick the next cell.
3. **Shop and Offer are forced full-screen interludes.** Triggered by the locked cadence (Shop after Match 3, 5, semi, championship + free Season-start; Offer after Match 4 + 3 at end-of-Season). They appear as their own full screens *after Result, before returning to the hub* — no skip, no hub-overlay. Auto-return to hub on close.
4. **No Main Menu.** Resume-first cold start: app launches → tiny splash → lands on the last screen the player was on (mid-Season → Season hub; between Seasons → Career Grid; first-ever launch → Onboarding). Settings is a **gear icon in a corner** of every screen, not a menu tab.
5. **Season hub is one dense screen, no scroll, no tabs.** Everything visible at once: Team identity · league position · fixtures chain · Player snapshot · Jokers bench · Tons balance · big primary CTA. Drill-downs reachable by tap.
6. **Pre-match is versus-style.** Red-gradient `[YOUR TEAM] vs [OPP TEAM]` header (visual continuity with the locked Match chrome). Stakes strip, conditions strip, two team panels side-by-side, big gold "TAP TO START" CTA.

---

## Screens in scope (6)

The original Theme 5 list named 7 screens. Q3 above killed Main Menu. The 6 remaining:

| # | Screen | When seen | Locked / Open |
|---|---|---|---|
| 1 | **Season hub** | Between every Match within a Season | Layout locked single-dense (Q4); content open |
| 2 | **Pre-match** | After hub → tap "Next Match" | Layout locked versus-style (Q5); content open |
| 3 | **Shop** | Forced after Match 3/5/semi/final + free Season-start | Open — recommend vertical L/R split (see Q6 below) |
| 4 | **Offer** | Mid-Season (single, after Match 4) + end-of-Season (choose-from-3) | Open — must surface ★ rating + form delta |
| 5 | **Result / scorecard** | After every Match | Open — must hand off cleanly to Shop / Offer / hub |
| 6 | **Career Grid** | Between Seasons | Open — must visualize 3 Levels × 8 Tours, current cell, beaten cells, locked cells |
| — | **Onboarding** | First-ever launch only | Defer — design after the above 6 are locked |
| — | **Settings** | Gear icon on every screen | Defer — utilitarian, last |

Onboarding and Settings are explicitly **deferred to a later pass**. Focus the v1 mockup on screens 1–6.

---

## Per-screen content requirements

### 1. Season hub *(single dense screen)*

Components — all visible at once, no scroll:

- **Top chrome:** Team chip (badge · name · ★ · Affinity tag · country palette) · league position pill (e.g. "3rd · 6 pts") · ₸ Tons balance (big gold number with ₸ glyph)
- **Fixtures chain:** Horizontal node strip showing the Season — past Matches as W/L dots (green/red), current spot pulsing, upcoming as opponent badge chips. Current example: `[W][L][W]●[CHE][SYD][PER] | SF | The Final` where `●` is "you are here". Should accommodate 7 league + up to 2 playoff Matches.
- **Player snapshot:** Card Portrait (med size, 72×92) showing skill tier (bg) + Form (face) per DESIGN_HANDOFF §16.3 · 4 Attribute strip: Power · Composure · Attack · Control with current values (compact)
- **Jokers bench:** 4 slot row — owned Jokers in the standard rarity treatment from §16.7 (Common/Rare/Legendary borders + pip + gold synergy pill). Slot 4 shows "EARN AT FIRST LEVEL WIN" if not yet unlocked. Show held-Joker indicator if one's pinned for next Shop.
- **Primary CTA:** Large gold bottom button — `NEXT MATCH ▶` (or `SHOP OPEN ▶` / `OFFER AVAILABLE ▶` if the cadence has fired and the player hasn't passed through yet — but per architecture decision 3, these are forced after Result, so this CTA should normally say "Next Match")
- **Corner controls:** Gear icon (settings) top-right · tiny info button (current Tour / cell context) top-left

### 2. Pre-match *(versus-style)*

Components, top to bottom:

- **Red-gradient header:** `[YOUR TEAM] vs [OPP TEAM]` — same chrome as locked Match screen. Country palette swaps per data-country.
- **Stakes strip:** Gold-bordered text strip — "LEAGUE MATCH 4 · TOP 4 ADVANCE" / "SEMI-FINAL" / "THE FINAL" / "3RD-PLACE PLAYOFF". Visual weight should scale with stakes (subtle league bar; blazing for The Final).
- **Conditions strip:** Tour name + small evocative icon — e.g. `AWAY · WINTER EVENING 🌙` / `HOME · SUMMER ☀` / `PREMIUM TOUR ★`. Don't over-engineer; one line.
- **Two team panels side-by-side:**
  - LEFT (yours, blue palette): Your Player Card Portrait (med) · ★ rating · 4 Attribute compact strip · Affinity tag
  - RIGHT (opp, country accent): Their highest-★ player Card Portrait (med) · their team ★ · their recent form W/L/L/W pips · their `lastSeasonEvent` flavour line if any (ADR 0009 — catastrophic ±1 swings carry commentary, e.g. *"Captain retired mid-season"*)
- **Your build strip:** Compact row showing 4 Joker pips (icons only, rarity-coloured) + Boost-ready pip (water-meter mini, full = green, charging = grey)
- **Primary CTA:** Large gold "TAP TO START ▶" button at bottom

### 3. Shop *(side-by-side Tons + Jokers — recommended L/R split)*

**Recommended layout (vertical L/R split):**

- **Top bar:** ₸ Tons balance (big gold) · visit context ("Shop · after Match 3" / "Season Start · free starter" / "Pre-Final · last chance")
- **LEFT column (Tons spend = Attribute upgrades):** 4 stacked rows, one per Attribute (Power · Composure · Attack · Control). Each row shows: Attribute name · current value bar (with current numeric) · `+1` chip showing ₸ cost · tap-to-upgrade. Cost scales with current value (higher = more expensive). If you can't afford, chip is dimmed.
- **RIGHT column (Joker market):**
  - **Offer row (top):** 3 cards horizontal — 1 Common · 1 Rare · 1 Legendary. Each card shows: rarity border + pip + bg (per §16.7) · icon · name · effect text · ₸ price · Buy button · Hold-pin icon top-right (tap to hold for next visit; 1 hold per Shop). If a held-Joker carried in from last Shop, it pre-fills one of these slots and is marked `HELD`.
  - **Owned row (bottom):** 4 slots — your current Jokers. Tap a slot → quick-detail modal with "Sell for ₸X" partial-refund action. Slot 4 may show locked state.
- **Bottom CTA:** "Done · Continue" (auto-advances to Season hub).

**Special case — Season-start Shop:** No Tons spending. The left column (Attribute upgrades) is hidden or fully dimmed. The right column shows 3 Common Jokers as a free-pick (tap to claim one, others discarded). After the free pick, auto-advances. The carry-over Joker from last Season (if elected) appears already in slot 1 of the owned row, pre-claimed.

**Show 2 variations if you have a strong alternative.** The horizontal T/B split could work; we want to see it before committing.

### 4. Offer *(★ rating + form delta UI · two sub-variants)*

**Sub-variant A — Mid-Season Offer (after Match 4):** ONE Team approaches you. Single take-it-or-leave-it. **Accepting switches you immediately** — you finish the Season with the new Team, league position inherited, **Affinity resets**. Tons + personal stats stay with you.

- Single big Team card centered: Team badge · Team name · ★ rating (half-star precision, 0.5–5.0 — e.g. `★★★★½`) · current-Season form delta pill ("+ above baseline" / "− below baseline" / "= on baseline") · `lastSeasonEvent` flavour line if recent catastrophic swing
- Below the card: contract terms compact strip — base ₸ per Match (lower for stronger Teams — see CONTEXT.md) · estimated playing time (lower for stronger Teams)
- Narrative line: *"This Team isn't going anywhere — take the gamble and join a contender."* (or similar — match the framing in CONTEXT.md)
- Two big buttons: red "DECLINE" / gold "ACCEPT — SWITCH NOW"

**Sub-variant B — End-of-Season Offers (after the final Match):** THREE Offers + "stay" option. Choose from three (or stay). Accepting locks the move for next Season.

- Three Team cards in a horizontal row (or 2+1 stack if width is tight): same Team-card content as sub-variant A · cross-Level Offers (Level-N+1) get a gold glow / "PROMOTION" tag per CONTEXT.md guarantee
- 4th card: "STAY WITH [YOUR TEAM]" — shows current Team chip + Affinity bonus continuing + base ₸
- Carry-over Joker picker beneath: a row of your 4 owned Jokers (Season's end) — tap one to carry over (or "NONE") into next Season's free starter slot
- Single "CONFIRM" CTA at bottom (gates on both Offer chosen and carry-over chosen)

Visual emphasis on **★ rating + form delta** as the primary readable signal (per CONTEXT.md). The Team durability model (ADR 0009) is what makes Offer evaluation a real skill — surface that signal clearly.

### 5. Result / scorecard

Closes the Match arc. Should feel like a broadcast post-match.

- **Headline:** "WON BY 23 RUNS" / "LOST BY 4 WICKETS" / "TIED" — big gold or red
- **Match scoreline:** `MUM 174/6 (20) · CHE 151/8 (20)` — broadcast-style
- **Personal performance block:** Your runs · balls faced · 4s/6s · strike rate · wickets taken · economy · KMs won. Card Portrait of you at large with current Form face.
- **Tons earned:** Big ₸ number with a small breakdown ("base 50 + perf bonus 18 = 68 ₸")
- **Decision recap:** Compact row of the Key Moment cards you faced with the choice you made + outcome (✓/✗). Stretch goal — not blocker.
- **Affinity / Form deltas:** Mini bars showing change
- **Next-screen handoff CTA:** Auto-advances after a few seconds, or tap "Continue ▶". Destination per architecture decision 3: → Shop if cadence triggers · → Offer if it's after Match 4 or end-of-Season · → Season hub otherwise · → Career Grid if Season-ending.

For Match-9 (The Final or 3rd-place playoff), the Result screen should celebrate or commiserate more dramatically — fireworks / confetti for The Final win, sombre for elimination. Hand off to end-of-Season Offer set.

### 6. Career Grid *(between-Season home)*

The Career's whole map. Picks the next cell to attempt.

- **3 Levels × 8 Tours** = 24-cell grid. Levels rows (Club bottom · City middle · Province top); Tours columns left-to-right easiest → hardest (Practise · Home Summer · Home Winter · Home Evening · Away Summer · Away Winter · Away Evening · Premium)
- **Cell states:**
  - **Beaten** — checkmark, faded
  - **Won** (Level Final won = the rightmost cell of that Level) — trophy icon, gold glow
  - **Current/available** — pulsing border, your team chip overlaid
  - **Locked** — faded / chains icon (locked cross-Level by the "win Club's & City's Premium tours to unlock Province's Premium" rule)
- **Bottom-left start** (Club Practise) — first-Career origin. **Top-right finish** (Province Premium) — Career complete.
- **Top chrome:** Country flag + Country name · Career stats (Seasons played counter — the score-to-beat metric) · current Team identity strip · Tons banked (₸)
- **Cell tap:** Opens a "Start Season" confirm modal showing the cell's Tour distribution preview, Team line-up (your team's 11 players), Affinity carry-over note
- **Corner:** Gear icon (settings)
- **Visual:** Think Slay-the-Spire / Hades constellation map — clear topology, evocative not utilitarian. Country palette throughout.

---

## Open design questions — for the mockup pass to *show*, not just answer

When you produce the HTML, **propose answers visually** for these open questions. If you have a strong alternative to the recommendation, show both in adjacent frames.

1. **Shop layout primary.** Recommended: vertical L/R split (Attributes left, Jokers right). Alternative worth showing: horizontal T/B split (Joker market top, owned + Attributes bottom). Both as adjacent frames.
2. **Pre-match opp portrait — single threat or two?** Recommended: one (their highest-★ player in their dominant role). Alternative: two (top batter + top bowler). Show both, recommend one.
3. **Career Grid topology.** Grid (8×3 regular lattice) vs constellation (Slay-the-Spire-style connected nodes with slight irregularity). Show both, recommend one.
4. **Result screen pacing.** Instant full-display vs animated reveal (scoreline first, then personal stats, then Tons, then recap). Show static frame + describe animation.
5. **End-of-Season ritual sequence.** Result → Offer-set (3 cards + stay) + carry-over picker → Career Grid. That's 3 forced screens. Should the carry-over picker live as a *footer of the Offer screen* (one screen, two decisions) or be its own screen? Propose.
6. **Forfeit / quit flows.** Where does "Retire mid-Career" / "Surrender Match" live? Probably Settings — confirm.

---

## Visual system to inherit

Read **`DESIGN_HANDOFF.md` §8** (palette, type, spacing, motion) and **§16** (hi-fi addendum — CSS vars, 10-country palette, portrait system, Joker pip styling, water-meter boost). Specific must-use elements:

### CSS variable system (§16.1) — canonical, no hardcoded hexes

```css
:root {
  --bg: #0f0f14;            --bg-2: #16161e;
  --bezel: #0d0d12;         --bezel-edge: #2a2a35;
  --red: #c41e3a;           --red-dark: #8b0000;       --red-bright: #ef6c6c;
  --gold: #ffd166;          --gold-warn: #f5a623;
  --green: #2ecc71;         --green-dark: #16a34a;
  --blue: #4a90e2;          --blue-bright: #6ec1e4;
  --blue-mum-1: #1e88e5;    --blue-mum-2: #0d47a1;
  --yellow-che-1: #ffd744;  --yellow-che-2: #c08800;
  --white-soft: rgba(255,255,255,0.85);
  --white-mid:  rgba(255,255,255,0.65);
  --white-dim:  rgba(255,255,255,0.45);
  --white-faint:rgba(255,255,255,0.25);
  --surface:    rgba(255,255,255,0.04);
  --surface-2:  rgba(255,255,255,0.07);
  --border:     rgba(255,255,255,0.08);
  --border-strong: rgba(255,255,255,0.15);
  --country-1: #c41e3a;     --country-2: #8b0000;
  --country-glow: rgba(196,30,58,0.35);
  --country-accent: #ef6c6c;
}
```

### Country palette (§16.2)

Default screens to **South Africa** (`#007749 / #003e26`, accent `#FFB81C`) — that's the primary target Country per ADR 0001 and shows off the country-palette system. Add **Australia** (`#0E703F / #063a20`, accent `#FFCD00`) as a second-frame variant for at least one screen to demonstrate `data-country` swap.

### Portraits (§16.3)

- Full-bg = **skill tier** (gold/amber+sun = elite 4★, sky-blue = 3★, silver = 2★, charcoal = rookie 1★)
- Facial expression = **Form** (confident grin = hot, neutral = steady, drawn = tired, downcast = cold)
- Tiny size (28×34) doesn't show face — Form by coloured outline/glow instead (gold/green/brown/grey)

### Tons (₸) currency mark

The currency is **Tons** and the glyph is **₸** (a T struck through by a cricket bail). Asset references and rules in `docs/brand/`. Always use ₸ for currency values; never `$` or `T` plain.

### Jokers panel (§16.7) — pip + border + bg

- **Common** — white pip · neutral border · `--surface` bg
- **Rare** — blue pip · blue border + soft glow · blue gradient bg
- **Legendary** — gold pip · gold border + glow · dark purple gradient bg
- **Empty** — dashed border · "+slot 4 · earn"
- **Held** — pin icon top-right (Shop only)

### Type / spacing

System font stack; 8/9/10/11/12/14/16/22/26/36 px scale; weights 400/700/800/900; all-caps + 1–2px letterspacing for labels; `font-variant-numeric: tabular-nums` for stats; 4px base unit, 8/14/24 px common gaps; 14px phone padding; 8/12 px border radius for panels/cards.

---

## Save instructions (where the HTML lands)

Produce a **single multi-frame HTML file** showing all 6 screens (plus alternates where Q1–6 above ask for both options). Side-by-side phone frames, same pattern as `match-screen-final.html`.

**Save it to:** `docs/mockups/around-the-match-v1.html`

Nico (the human) will copy the HTML output from claude.ai and save it locally at that path. Don't try to do file I/O — claude.ai can't reach his disk; he'll handle the paste.

---

## The prompt to paste

> I'm designing the "around-the-match" screens for a mobile cricket roguelite (a mash of Reigns × Balatro × management, ~2:45 Matches, single rising Player career). I've attached: the project's domain glossary (`CONTEXT.md`), the canonical design handoff (`DESIGN_HANDOFF.md` — read §8 and §16 carefully), two existing hi-fi mockups for visual continuity (`match-screen-final.html` is the locked in-Match design; `in-match-hi-fi-v1.html` is the hi-fi addendum that introduces the CSS vars / 10-country palette / Joker panel / water-meter boost), and the Theme 5 handoff doc (`THEME-5-HANDOFF.md`) which captures architecture decisions I've already locked.
>
> **Don't override the locked decisions in the handoff doc.** Read them and design within them.
>
> **Produce a single HTML file** showing all 6 screens as side-by-side phone frames (same pattern as `match-screen-final.html`):
>
> 1. Season hub
> 2. Pre-match
> 3. Shop *(show 2 variants — vertical L/R split + horizontal T/B — adjacent frames)*
> 4. Offer *(2 frames: mid-Season single + end-of-Season triple + carry-over)*
> 5. Result / scorecard
> 6. Career Grid *(show 2 variants — regular grid + constellation — adjacent frames)*
>
> Default the country palette to **South Africa**. Include at least one frame in **Australia** palette to show the `data-country` swap working.
>
> For each "open question" in the handoff doc, propose visually with adjacent frames, recommend one, and put a short HTML comment above each frame explaining the trade-off.
>
> Use the CSS variable system from §16.1 of `DESIGN_HANDOFF.md`. No hardcoded hexes. Use ₸ for currency. Use the rarity-tier Joker styling from §16.7. Use the full-bg-skill + face-Form portrait system from §16.3.
>
> Once you've drafted it, walk me through the design decisions you made for each screen, then I'll feedback.

---

*Handoff doc written 2026-05-30. Lock state of architecture decisions: Q1–Q5 closed; Q6 (Shop layout) recommended L/R, to be confirmed visually.*
