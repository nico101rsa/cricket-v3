# Player Creation + Hall of Fame · Claude.ai hi-fi handoff

A self-contained brief for designing the **Player Creation** flow (2 screens) and the **Hall of Fame** (Legends archive) as hi-fi HTML mockups in a fresh **Claude.ai** conversation. The around-the-match screens are already locked (`docs/mockups/around-the-match-v1.html`) and are **not** in scope — but the visual language continues from them.

---

## How to use this doc

1. Open a new conversation at **claude.ai**.
2. **Attach these files** (drag-drop into the chat):
   - This file (`docs/PLAYER-CREATION-HANDOFF.md`)
   - `CONTEXT.md`
   - `docs/superpowers/specs/2026-06-01-player-creation-design.md` *(the spec being designed against — full source of truth)*
   - `docs/DESIGN_HANDOFF.md` *(design system — chrome, portraits, palette, tokens)*
   - `docs/mockups/around-the-match-v1.html` *(the existing hi-fi pass — visual continuity)*
   - `docs/mockups/in-match-hi-fi-v1.html` *(CSS variables / 10-country palette / portrait system)*
3. Paste **[the prompt](#the-prompt-to-paste)** at the bottom of this doc.
4. Iterate. When the HTML is ready, copy it into:
   `docs/mockups/player-creation-v1.html`
   (one file, multiple phone frames side-by-side — same pattern as `around-the-match-v1.html`).
5. Return to Claude Code in this repo and we'll either lock it or iterate further from here.

---

## Architecture decisions — LOCKED (from the spec, don't override)

These are the design-relevant decisions from `docs/superpowers/specs/2026-06-01-player-creation-design.md`. The spec is the full source of truth — these are the headlines.

1. **Hard permadeath lifecycle.** V1 has two end-states: **Win-out** (Player wins Province's Premium Final) or **Manual retire** (corner button on the Season hub). Both archive the Player to the **Legends wall**. Auto-drop / non-selection / age-based retirement is deferred to post-launch Theme 9.
2. **2-screen Creation flow: Identity → Build.** Not a single dense screen, not 3 screens. Two screens, conceptually grouped (who is this guy / what can he do).
3. **5 creation decisions.** Country (SA / AUS), City (flavour-only dropdown), Appearance (4 portrait buckets per Country), Name (random + re-roll only — no manual override), Attributes (20 points across 4 sliders).
4. **Appearance picker shows portraits only — no textual labels** in UI. Buckets internally: `white` / `mixed` / `indian` / `black`. UI shows 4 thumbnails, user picks the face.
5. **Name is random + re-roll only.** No keyboard, no manual override. Cricket-pun surnames (~70% cricketer-surname plays like *Springer* / *Tendul*; ~30% equipment puns like *Bails* / *Stumps*).
6. **20-point slider: min 1, max 8 per attribute, default 5/5/5/5.** Live classifier label below: *Batter / Wicket-keeper Batter / Bowler / All-rounder*. Label is flavour only.
7. **Hall of Fame surfaces the Career arc.** Each Legend card shows *Started as: [label] · Ended as: [label]* — this works because labels are live-derived and we snapshot starting attributes. A young Bowler who matures into a WK Batter tells that story on the wall.
8. **No Main Menu** (per ADR 0010, still in force). Player Creation is the cold-start path when no save exists; Hall of Fame is a forced screen inserted between Career-end and next Player Creation.

---

## Screens in scope (3)

| # | Screen | When seen | Notes |
|---|---|---|---|
| 1 | **Player Creation — Screen 1: Identity** | Cold start (no save) · After Hall of Fame post-Career | Country / City / Appearance / Name |
| 2 | **Player Creation — Screen 2: Build** | After Screen 1's Next button | Attribute sliders + classifier |
| 3 | **Hall of Fame** | Forced after Win-out or Manual retire, before next Player Creation | Legends archive list |

The **Starting Team picker** (the user picks from the 3 lowest-★ Club Teams) is the next screen after Build's Confirm — but it already exists in `around-the-match-v1.html`'s broader flow and is **not** in scope for this pass.

---

## Per-screen content requirements

### 1. Player Creation — Screen 1: Identity

The "discover who you found" moment. Reigns-flavour: the portrait + name read together.

Components, top to bottom:

- **Tiny top chrome:** Step indicator (e.g. `1 / 2 · IDENTITY`) · subtle, no nav controls (back is implicit if no save exists; otherwise the screen advances forward).
- **Country toggle:** Two-state pillow segmented control — `🇿🇦 SOUTH AFRICA` / `🇦🇺 AUSTRALIA`. **Starts un-set** — neither lit until the user picks. Until Country is picked, City and Appearance render disabled/placeholder, name area shows `—`. When toggled, the SA/AUS country palette swaps the screen background gradient (SA green `#007749` → AUS amber `#FFCD00`).
- **City dropdown:** Lists 10 cities for the current Country. SA: Cape Town · Johannesburg · Durban · Pretoria · Gqeberha · East London · Bloemfontein · Pietermaritzburg · Centurion · Paarl · Potchefstroom. AUS: Sydney · Melbourne · Brisbane · Perth · Adelaide · Hobart · Canberra · Geelong · Newcastle · Darwin. When Country flips, City resets to un-picked.
- **Portrait preview (large):** Full-size Card Portrait of the currently-selected appearance — the same portrait that will live on the Player card. Renders DESIGN_HANDOFF §16.3 art (sky-blue 3★ default starting tier, neutral "steady" face).
- **Appearance picker:** Row of **4 portrait thumbnails** (no textual labels). Tap to select; selection ring highlights the chosen one. Internally ordered `white` / `mixed` / `indian` / `black`. The currently-selected thumb drives the large portrait above.
- **Name display:** Large generated name beneath the portrait — e.g. `JONTY SPRINGER` (firstname caps, surname caps). Slight letterspacing per the all-caps label style. **Re-rolls automatically whenever Country or Appearance changes.**
- **🔄 Re-roll button:** Adjacent to the name (or inline). Tapping cycles a fresh name from the current bank slice. No manual text input affordance.
- **Primary CTA:** Bottom gold button — `NEXT ▶` — **disabled** until Country, City, and Appearance are all picked (name is always populated once Country+Appearance are).

**Empty state handling:** Before Country is picked, the screen reads like "make your first choice" — City dropdown is disabled, Appearance is dimmed/hidden, name shows `—`. After Country, the rest of the screen lights up.

### 2. Player Creation — Screen 2: Build

The "spec your guy" moment. Less identity, more numbers. Compact and intentional.

Components, top to bottom:

- **Tiny top chrome:** Step indicator (`2 / 2 · BUILD`) · `← BACK` corner control (returns to Screen 1, preserves picks).
- **Player card recap (small):** Horizontal strip — portrait thumb (28×34, per §16.3 small treatment) · name · `city · country flag`. Confirms identity from Screen 1 without dominating the screen.
- **Points counter:** Pinned visible — *"POINTS REMAINING: 0 / 20"* large gold when balanced, red when not. The user must spend exactly 20.
- **4 attribute sliders:** Vertical stack — Power · Composure (the two batting Attributes) then a thin divider then Attack · Control (the two bowling Attributes). Each slider:
  - Label on left (`POWER`)
  - Slider track (range 1–8 — note the floor and ceiling)
  - Numeric readout on right (large tabular `5`)
  - Optional micro-icon hinting at the role (a bat-swing arc for Power; a shield for Composure; a stump-target for Attack; an over-arm for Control)
- **Live classifier label:** Below sliders. Format suggestion: *"YOUR PLAYER IS A:"* (small all-caps grey) above a big gold label *"WICKET-KEEPER BATTER"* (or `BATTER` / `BOWLER` / `ALL-ROUNDER`). Updates live as sliders drag. This is the flavour beat — make it feel like a verdict.
- **Confirm CTA:** Bottom gold button — `BEGIN CAREER ▶` (or similar). **Disabled** while `points_remaining ≠ 0`. On press: persist Player, hand off to Starting Team picker (out of scope for this pass).

**Default state on entry:** All sliders at 5, points_remaining = 0, classifier = `ALL-ROUNDER`, Confirm enabled. The user can Confirm immediately with the default if they don't want to spec — that's intentional ("balanced all-rounder" is a valid choice).

### 3. Hall of Fame

The Legends wall. Surfaces every Player from this Career save (the device-level archive). Forced screen after a Career ends (Win-out or Manual retire); the next action from here is always "begin new Player".

Components, top to bottom:

- **Top chrome:** Title `HALL OF FAME` (large, gold, with a faint laurel motif if you want) · Legends-earned counter (e.g. `7 LEGENDS`) · faint country-flag strip showing distribution if multi-Country (V1: optional)
- **Hero card (the just-completed Legend, prominent):**
  - Full Card Portrait (large) of the Player as they ended — final attributes drive skill tier, final Form drives face (per §16.3)
  - Outcome badge: `🏆 WON THE CAREER` (gold) or `🪦 RETIRED` (muted bronze) — big, declarative
  - Name in giant type (`JONTY SPRINGER`)
  - Sub-line: `Cape Town · 🇿🇦 · 23 SEASONS PLAYED`
  - **Career arc** — the marquee beat from the spec: *"Started as: BOWLER · Ended as: WICKET-KEEPER BATTER"* — two small label pills side by side with a `→` between them. If `started == ended`, render as a single pill (no arrow): *"BATTER throughout"*.
  - Top 3 Career Records — compact strip: *Highest: 118\* · Best bowling: 5/22 · Player of the Match: ×9*
- **Legends list (scrollable):** All prior Legends as smaller cards below the hero — chronological newest-first.
  - Each row: small portrait (40×50) · name · arc pills · outcome badge · seasons-played count
  - Tap a row → detail overlay with the full Career Records (out of scope for this pass — sketch the row, don't design the overlay)
- **Primary CTA:** Large gold bottom button — `BEGIN NEW PLAYER ▶` — advances to Player Creation Screen 1.
- **No "skip" or "back" affordance.** This is a forced milestone screen. The only way forward is the CTA.

**Empty-state Hall of Fame** is not designed in this pass — it never occurs (the screen is only inserted after a Career end, so there is always at least one Legend on it).

---

## Design system reminders

These should all already be in your head from the attached files. Just to flag the high-touch bits for this pass:

### Palette per Country (§16.2)

| Country | Primary | Dark | Accent |
|---|---|---|---|
| 🇿🇦 South Africa | `#007749` (green) | `#003e26` | `#FFB81C` (amber) |
| 🇦🇺 Australia | `#FFCD00` (amber-gold) — note: this is the **post-2026-05-31 fix**, was previously near-clone SA-green | `#063a20` | `#0E703F` (green) |

Screens should render in the user's currently-selected Country palette. For Player Creation Screen 1 specifically, default to SA (or a neutral pre-pick state) until the user picks; swap to AUS in adjacent demo frame.

### Portraits (§16.3) — Appearance bucket art

Each Country needs **4 portrait variants** (`white` / `mixed` / `indian` / `black`) for this pass. At hi-fi mockup stage, the actual portrait art isn't commissioned — use placeholder portraits (skin-tone gradient backgrounds with a generic silhouette, or 4 distinct SVG portrait stylings). The important thing is the **picker structure**: 4 thumbnails, clearly distinct, tappable.

The 3★ sky-blue background tier is the default starting-skill render (5/5/5/5 default = a balanced All-rounder; not elite, not rookie). Form face = neutral "steady".

### Tons (₸)

The currency is **Tons** and the glyph is **₸**. Not used directly in Player Creation (no purchases here), but the Hall of Fame card may surface lifetime-Tons-earned as a flair stat if it fits. Don't force it.

### Type / spacing

Match the existing hi-fi system. System font stack; 8/9/10/11/12/14/16/22/26/36 px scale; weights 400/700/800/900; all-caps + letterspacing for labels; tabular-nums for stats; 14 px phone padding; 8/12 px border radius for panels/cards.

### Motion

Reference the existing hi-fi — subtle. The two animations this pass adds:

- **Country toggle → palette swap.** When the user toggles SA / AUS, the background gradient transitions over ~300ms (not a hard cut). City and Appearance reset visibly.
- **🔄 Re-roll button.** Small spin animation on the button itself; name fades out and a new one fades in (~200ms). Optional: a tiny micro-bounce on the new name.

---

## Open visual questions — propose 2 variants for each

Where there's a real design choice, render **2 adjacent frames** with a brief HTML comment explaining the trade-off, and recommend one.

1. **Identity screen layout** — vertical scroll (Country toggle → City → Appearance → Portrait → Name) OR portrait-anchored (large portrait dominates, controls cluster around it). Which feels more like a "discover a Player" moment?
2. **Build screen slider treatment** — straight horizontal sliders vs. radial dials vs. tap-up/tap-down +/- buttons. Mobile thumb ergonomics matter; sliders are the spec-language but might not be the best UI.
3. **Hall of Fame hero card outcome badge** — should `🪦 RETIRED` feel sombre (muted bronze, smaller) or proud (same gold treatment as `🏆 WON`, different icon)? Reigns flavour leans into all deaths being meaningful — but this is a personal-project cricket sim, not a horror game.
4. **Hall of Fame list density** — portrait-card rows (richer, fewer per screen, more scroll) vs. compact rows (thumbnail + 1 line of arc text + outcome badge, denser).

For everything else, just make the call and design it.

---

## Out of scope (don't design this pass)

- **Starting Team picker** — exists in `around-the-match-v1.html`'s broader flow. Player Creation hands off to it after Confirm.
- **Hall of Fame Legend detail overlay** — tapping a Legend row opens detail (full Career Records). Sketch the row only, not the overlay.
- **Settings screen** — gear-icon corner control on all screens still applies, but the Settings panel itself remains deferred (per Theme 5 closure).
- **Empty-state Hall of Fame** — never occurs in V1 (only inserted post-Career).
- **AUS Indigenous appearance bucket** — flagged as a deferred decision in the spec (§9). 4 buckets only this pass.
- **Sub-labels beyond the 4 V1 classifier labels** — Hitter, Pace Bowler, Spinner etc. are post-launch.
- **Name banks (actual content)** — placeholder names are fine (use the spec's examples + your own variants). Bank authoring is a separate deliverable.

---

## Save instructions (where the HTML lands)

Produce a **single multi-frame HTML file** showing all 3 screens (plus alternates for the 4 open visual questions above). Side-by-side phone frames, same pattern as `around-the-match-v1.html`.

**Save it to:** `docs/mockups/player-creation-v1.html`

Nico (the human) will copy the HTML output from claude.ai and save it locally at that path. Don't try to do file I/O — claude.ai can't reach his disk; he'll handle the paste.

---

## The prompt to paste

> I'm designing the **Player Creation** flow + **Hall of Fame** screen for a mobile cricket roguelite (Reigns × Balatro × management mash, ~2:45 Matches, hard-permadeath single-Player career). I've attached: the project's domain glossary (`CONTEXT.md`), the full Player Creation spec (`docs/superpowers/specs/2026-06-01-player-creation-design.md` — the source of truth), the canonical design handoff (`DESIGN_HANDOFF.md` — §16 has the design system), the existing around-the-match hi-fi pass (`docs/mockups/around-the-match-v1.html` — visual continuity reference), the in-Match hi-fi addendum (`docs/mockups/in-match-hi-fi-v1.html` — CSS vars / palette / portraits), and this handoff doc (`docs/PLAYER-CREATION-HANDOFF.md`) which captures locked decisions and per-screen requirements.
>
> **Don't override the locked decisions in the handoff doc or the spec.** Read them and design within them.
>
> **Produce a single HTML file** showing 3 screens as side-by-side phone frames (same pattern as `around-the-match-v1.html`):
>
> 1. **Player Creation — Screen 1: Identity** — Country toggle, City dropdown, 4-portrait Appearance picker, name + re-roll. Show **2 variants** for the layout question (vertical scroll vs portrait-anchored).
> 2. **Player Creation — Screen 2: Build** — 4 attribute sliders, points counter, live classifier label. Show **2 variants** for the slider treatment (horizontal sliders vs +/- buttons or dials).
> 3. **Hall of Fame** — hero card (just-completed Legend) + scrollable list of prior Legends. Show **2 variants** for the list density (portrait-card rows vs compact rows) and **2 variants** for the retire-badge tone (sombre bronze vs proud gold).
>
> Default the country palette to **South Africa**. Include at least one frame in **Australia** palette to show the `data-country` swap (especially showing the Country toggle palette transition on Screen 1).
>
> For each "open visual question" in the handoff doc, propose 2 adjacent frames, recommend one, and put a short HTML comment above each frame explaining the trade-off.
>
> Use the CSS variable system from §16.1 of `DESIGN_HANDOFF.md` and the in-Match hi-fi addendum. No hardcoded hexes. Use ₸ for currency only if it naturally surfaces (Hall of Fame lifetime-earnings is optional flair, not required). Use the full-bg-skill + face-Form portrait system from §16.3 — at hi-fi mockup stage, placeholder portraits (skin-tone gradient + generic silhouette, or 4 distinct SVG portrait styles) are fine. The structure of the picker matters more than the portrait art.
>
> Make the **Career arc** beat on the Hall of Fame hero card land — *"Started as: BOWLER → Ended as: WICKET-KEEPER BATTER"* is the marquee narrative moment of the whole permadeath loop. Two small label pills with an arrow between them.
>
> Once you've drafted it, walk me through the design decisions you made for each screen, then I'll feedback.
