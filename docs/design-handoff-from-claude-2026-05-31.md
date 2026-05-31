# Handoff: Collection / Achievements screen + Australia palette fix

## Overview
Two changes to the **Around-the-Match** hi-fi mockups, ready to fold back into the main project:

1. **Australia country palette recolour** — Australia was rendering in the same green as South Africa. It now uses a distinct **amber-gold gradient with a green accent**, so the two nations read as clearly different teams everywhere the country swap is applied.
2. **New Collection screen (§7)** — a persistent "trophy cabinet" reward layer: every milestone, first, boundary feat, and joker the player chases across a whole Career, with three achievement states (earned / in-progress / locked) and Tons payouts.

Everything is built on the file's existing CSS token system and component vocabulary — no new fonts, no new base colors beyond the two palette values noted below.

## About the Design Files
The bundled `around-the-match-v1.html` is a **design reference created in HTML** — a prototype showing intended look and behaviour, not production code to ship. The task is to **recreate these screens in the target codebase's environment** (the game is built in Godot per `docs/THEME-5-GODOT-BUILD-NOTES.md`; for a web client use its established patterns) using existing components and tokens. Treat the HTML as the source of truth for layout, color, type, spacing, and states.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, rarity treatments, and interaction states. Recreate pixel-accurately using the codebase's existing primitives. All values below are exact.

---

## Change 1 — Australia palette

The file drives per-country theming from a single attribute, `data-country`, set on each `.phone` frame. Each country defines four CSS custom properties.

**Before (the bug — identical green to South Africa):**
```css
[data-country="aus"] { --country-1:#0E703F; --country-2:#063a20; --country-glow:rgba(14,112,63,0.45); --country-accent:#FFCD00; }
```

**After (distinct amber-gold + green accent):**
```css
[data-country="aus"] { --country-1:#A86E00; --country-2:#5c3a00; --country-glow:rgba(224,168,40,0.45); --country-accent:#36CE72; }
```

For reference, the other nations are unchanged:
```css
[data-country="sa"]    { --country-1:#007749; --country-2:#003e26; --country-glow:rgba(0,119,73,0.45);  --country-accent:#FFB81C; }
[data-country="india"] { --country-1:#c41e3a; --country-2:#8b0000; --country-glow:rgba(196,30,58,0.35); --country-accent:#ef6c6c; }
[data-country="eng"]   { --country-1:#1E2761; --country-2:#0a1238; --country-glow:rgba(30,39,97,0.5);   --country-accent:#C8102E; }
```

These four variables feed every country-themed surface: header/topbar gradients, the versus banner, shop/career headers, "live/now" ladder markers, opponent rings, and progress fills. Implement the country theme as a swappable token set keyed off the active nation; do not hardcode the green anywhere. Design intent: South Africa = green primary / gold accent; Australia = the inverse (gold primary / green accent) — authentic "green & gold" for both, but emphasis-flipped so they never look alike.

---

## Change 2 — Collection / Achievements screen

A new top-level destination reached from the **Career Grid** (the between-Season home). Three views; all use the South Africa palette in the mock but inherit whatever the active country is.

### Shared frame
- Device frame: **340 × 636px** phone, interior background `--bezel` `#0d0d12`, 13px padding, 7px vertical gap, flex column.
- Standard corner controls present on every screen: info button (top-left), gear/settings (top-right) — 26px circles, `rgba(0,0,0,0.4)` fill, `--border-strong` ring.

### View A — Collection · Overview
Purpose: at-a-glance progress + entry point to drill into a category.

Top → bottom:
1. **Completion hero** (`.coll-hero`) — gold-tinted card (`linear-gradient(95deg, rgba(255,209,102,0.14), rgba(255,209,102,0.03))`, border `--gold-deep`, radius 13px).
   - **Ring** (`.ring`, 60×60px): conic-gradient progress, gold arc on `rgba(255,255,255,0.09)` track, driven by `--p` (percent int). Inner mask via `::before` inset 5px filled `--bezel`. Center: percentage, 19px/900, `--gold`.
   - **Meta**: title "Collection" (16px/900); subline "47 of 77 earned" (9px/800 uppercase, count bold in `--white-soft`).
   - **Reward**: Tons total `2,340` using the `.tons`/`.tmark` glyph, gold; label "TONS FROM FEATS" (7px/800).
2. **"Recently earned"** section label + three **medal cards** (`.recent .rb`). Each: 33px circular medallion tinted by rarity (`.medal.common` green ring, `.rare` blue glow, `.legend` gold glow), name (8px/800), context tag (7px, dim).
3. **"By category"** label (with `6 sets` count) + **2-col grid** of six category cards (`.cat`): icon + name + `n/total` fraction + a thin progress bar. Bar fill uses `linear-gradient(90deg, var(--country-2), var(--country-accent))`; `.cat.gold` variant fills gold (used for Jokers, Special). Categories shown: Batting 9/14, Bowling 6/11, Firsts 8/12, Boundaries 7/10, Jokers 14/25, Special 3/10.
4. **"Closest unlock" nudge** — a single `.ach.prog` row (Century, best 87, 13 away) with a blue progress bar.
5. **Ghost CTA** "Browse all 77 ▸".

### View B — Collection · Batting & Bowling (filtered list)
1. **Filter tabs** (`.coll-tabs`): All · Bat · Bowl · Firsts · Jokers. Active tab(s) (`.tab.on`) fill with the country gradient + accent border. (Mock shows Bat + Bowl active.)
2. **Scrollable list** (`.coll-scroll`, `flex:1; min-height:0; overflow-y:auto`, 4px thin scrollbar) grouped by section label (`🏏 Batting 9/14`, `🎯 Bowling 6/11`).

### View C — Collection · Firsts & Jokers
1. Filter tabs with Firsts + Jokers active.
2. **Firsts & Career** list (8/12): First Win, First Semi, First Trophy, Top of the Log (prog), Promotion, Province Bound (locked), Invincible (locked, legendary), Club Loyal.
3. **"Jokers collected" 14/25** — a **5-col gallery** (`.jk-gallery` / `.jk-cell`, square tiles): collected cards glow by rarity (common neutral, `.rare` blue, `.legend` gold), uncollected are `.locked` dashed silhouettes (🔒).
4. Two trailing achievement rows: Synergy (earned, legendary), Full Set (locked, "11 left").

### Achievement row anatomy (`.ach`) — the core reusable component
```
[ badge 34×34 ]  [ name + description (+ optional progress bar) ]  [ right rail ]
```
Three states, driven by classes:

| State | Class | Badge treatment | Right rail |
|-------|-------|-----------------|------------|
| **Earned** | `.ach.done` + tier (`.common`/`.rare`/`.legend`) | tier-tinted border + glow; a ✓ check top-right in tier color | Tons reward (gold `.tons`) |
| **In progress** | `.ach.prog` | neutral | `.frac` fraction in `--blue-bright` (e.g. `87/100`), faded Tons preview, **blue progress bar** under the description (`max-width:160px`) |
| **Locked** | `.ach.locked` | grayscale + dashed border | `.st.locked` pill "Locked" / "11 left" |

Tier tints (match the existing Joker rarity system, see §16.7 in the file):
- **Common** → green (`--green-dark` border)
- **Rare** → blue (`--blue` border, `rgba(74,144,226,0.3)` glow)
- **Legendary** → gold (`--gold` border, gold glow, dark-purple gradient `#3a2a4e → #1d0e2e`)

---

## Interactions & Behavior
- **Entry**: Collection opens from the Career Grid ("View full record" / trophy-cabinet entry point). Overview → tap a category set → filtered list view (B/C) pre-scoped to that category.
- **Filter tabs**: toggle which categories the list shows. Mock shows multi-select (Bat+Bowl, Firsts+Jokers); single-select is also acceptable — match the codebase's tab pattern.
- **Achievement tap**: surface full detail / reward (not mocked — recommend a sheet with the unlock condition + Tons reward + earned date).
- **Earned animation** (recommended, not mocked): when a feat unlocks mid-match, play a medal pop + Tons payout, then mark `.done` here.
- **Progress rows** are live: `--p` on the ring and the `width` on `.pbar > i` / `.cat .bar > i` are data-bound (0–100%).
- No console JS drives Collection — it is pure markup/CSS. The only script in the file is the unrelated Career-ladder renderer.

## State Management
Per player profile, persisted Career-wide:
- `achievements[]` — each: `id`, `category` (batting | bowling | firsts | boundaries | jokers | special), `tier` (common | rare | legendary), `state` (locked | prog | done), `progress` (current/target), `tonsReward`, `earnedAt`.
- Derived: overall completion % (earned ÷ total → ring), per-category fractions, total Tons earned from feats, "closest unlock" (highest-progress non-done item).
- Jokers gallery reads from the player's joker-collection set (collected vs full deck of 25).

## Design Tokens (all already defined at `:root` in the file)
Colors:
- `--bg:#0f0f14` · `--bezel:#0d0d12` · `--bezel-edge:#2a2a35`
- `--gold:#ffd166` · `--gold-warn:#f5a623` · `--gold-deep:#c9912b`
- `--green:#2ecc71` · `--green-dark:#16a34a`
- `--blue:#4a90e2` · `--blue-bright:#6ec1e4`
- `--red:#c41e3a` · `--red-dark:#8b0000` · `--red-bright:#ef6c6c`
- Whites: `--white-soft .85` · `--white-mid .65` · `--white-dim .45` · `--white-faint .25` (all `rgba(255,255,255,…)`)
- Surfaces: `--surface .04` · `--surface-2 .07` · `--surface-3 .10`; borders `--border .08` · `--border-strong .15`
- Country tokens: `--country-1/-2/-glow/-accent` (see Change 1)

Type: system stack (`-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", Arial, sans-serif`). Sizes are small/dense — labels 7–9px/800 uppercase with 0.4–1.4px letter-spacing; values 9–19px/900 tabular-nums; body copy 8–10px. Radii: cards 8–13px, badges 9px, pills 5–7px.

Tons glyph: the `.tmark` mask (a struck "T") is defined in the file under §16.8 — reuse it, it inherits `currentColor`.

## Assets
None external. Icons are emoji (consistent with the rest of the mock's vocabulary — 🏏 🎯 🏆 👑 etc.). If the production client uses a custom icon set, map each emoji to its equivalent glyph; the layout reserves a 34×34 badge / 33px medallion slot.

## Files
- `around-the-match-v1.html` — full mock. Relevant regions:
  - `[data-country="aus"]` rule near the top of `<style>` (Change 1).
  - Collection CSS: the `─── COLLECTION / ACHIEVEMENTS §17 ───` block in `<style>`.
  - Collection markup: the `SECTION 7 — COLLECTION / ACHIEVEMENTS` block in `<body>` (three `.frame`s).
