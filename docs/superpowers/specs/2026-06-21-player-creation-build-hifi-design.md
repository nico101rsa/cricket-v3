# Player Creation · Screen 2 (Build) — hi-fi re-skin

**Date:** 2026-06-21 · **Branch:** `player-creation-build-hifi` · **Theme 2 (presentation).**

## One-line takeaway
Re-skin the existing **Build** screen (the 4-attribute points-spend screen) to the design-locked
`docs/mockups/player-creation-v2.html` "Build" band, on the shared `Palette`/`UIStyle`/`Fonts`
foundation. **Pure UI — zero sim/ledger/data-contract risk.** The interaction model is unchanged
(4 sliders summing to a fixed budget, live classifier, confirm-when-valid).

## Why now / context
Nico picked "hi-fi the player creation/build screen" as the next rung. Design already locked this
screen long ago (`player-creation-v2.html`, marked LOCKED per band, built on the same §16.1 token
system the Season Hub + in-match hi-fi screens consume). Decisions (both Nico's, 2026-06-21):
- **Translate the locked mockup directly** (no fresh claude.ai design-relay hop); design reviews the
  Godot render via the repo afterward.
- **First slice = Build (Screen 2)** — self-contained, no portrait dependency. Identity (Screen 1)
  follows once the **portrait pipeline** exists (only `hero-cap.png` is present; Identity's hero +
  4-thumbnail appearance picker need `hero-front` / `hero-helmet` / `keeper` too).

## The locked design (Build band, from `player-creation-v2.html`)
Top→bottom inside the phone frame:
1. **Corner back button** (`←`, top-left) — replaces the footer Back button.
2. **Country-gradient header** (`creation-head`): kicker `NEW PLAYER · <NAME>`, title `Build your game`,
   **step dots** (two; second active = step 2/2).
3. **Points bar**: label `POINTS SPENT`, value `<sum> / <budget>` (tabular), a **budget track + fill**
   (grey base, country-gradient fill).
4. **Batting group** (gold icon): **Power** (_boundaries_) · **Composure** (_resists dismissal_).
5. **Bowling group** (blue icon): **Attack** (_wicket chance_) · **Control** (_economy_).
   Each attr row = name + tiny descriptor + live number (country-accent, tabular) + a custom slider
   (8px track, grey base, country-gradient fill to the thumb, white thumb w/ accent ring).
6. **Classifier panel**: gradient surface + accent border + inner glow — `YOU'LL START AS A` / **LABEL**
   (country-accent) / a one-line flavour blurb.
7. **Gold CTA** `Begin Career 🏏` — replaces the footer Confirm button.

## Data-model reconciliation (IMPORTANT — adopt visuals, keep real numbers)
The mockup's numeric literals are **stale** (pre-world-scale-v2): it shows 1–10 sliders, a 32-pt
budget, /10 readouts and a richer 9-way classifier taxonomy. The **real game** is authoritative:
- Budget `Attributes.CREATION_TOTAL = 44`, per-attr `CREATION_MIN/MAX = 3/25`, slider `step = 1`.
  A fresh draft opens at 11/11/11/11 = **44 (already valid)**; you rebalance within 44.
- Readouts show the **/100 card** value via `Display.to_card_round(...)` (world-scale v2 WS6), not raw
  internal points.
- The classifier has **4 real kinds** (`ClassifierLabel.Kind`: BATTER / WK_BATTER / BOWLER /
  ALL_ROUNDER) — we use the real `Classifier.classify`, **not** the mockup's invented 9-way set.
- **Blurbs** are display-only **flavour** (a small const dict keyed by the 4 kinds, in the scene) — no
  data, mirrors `PlayerNames` flavour. Honest, generic one-liners.
- **Points bar semantics:** value = `<sum> / 44`; fill = `min(1, sum/44)`. Valid only at exactly 44
  (`Attributes.is_valid_creation_distribution`). When `sum ≠ 44` the value tints **red** and Confirm
  is disabled — this is the real validity meter (the mockup's "spent 22/32" is just stale demo data).

## Components / seams
- **`scenes/player_creation/build.{tscn,gd}`** — rebuilt **in code** (like the in-match scene), so the
  custom slider theming + gradient panels + corner button are owned in one place. Public API preserved:
  `set_draft(draft)`, signals `back_pressed(draft)` / `confirmed(player)`. Behaviour preserved: sliders
  drive `_draft.attributes`, classifier + points + confirm update live, confirm persists via
  `SaveManager.save_player` + emits, back emits the same draft for re-hydration.
- **`scripts/ui/ui_style.gd`** — small additions for this screen (kept testable, code-built):
  `points_bar()` (surface panel), `attr_group()` (surface panel), `classifier_panel(accent)` (gradient
  + accent border + inner glow), `slider_track()` / `slider_fill(accent)` styleboxes, and a generated
  circular `slider_grabber(accent)` `ImageTexture` (white fill, accent ring) for the HSlider thumb.
  Reuse existing `header()`, `cta()`, `corner_btn()`, `bar_track()`/`bar_fill()`.
- **`scripts/ui/fonts.gd`** — consumed, not changed: title `W_HEADLINE`/`W_BOLD`, group + section
  labels `W_LABEL`, descriptors `W_BODY`/`W_MEDIUM`, all numbers **tabular**.
- **`scripts/data/palette.gd`** — consumed via `country_set(draft.country)` for the header
  gradient/glow + the accent (slider fill, numbers, classifier). SA default; AUS reskins by the four
  country tokens, exactly like the hub.
- **`tools/preview_player_creation_build.gd`** — renders the real scene to
  `docs/mockups/latest/player-creation-build.png` (stable workflow path) + a versioned
  `player-creation-build-built-v1.png`. Run WITH rendering; inject the draft in `_process` frame 2.

## Testing (TDD, GUT)
Extend `tests/unit/test_build_scene.gd`. Preserve behavioural assertions, adapt to the new tree:
- default draft → `sum()==44`, confirm enabled, classifier text contains `ALL-ROUNDER`.
- unbalance a slider → `sum()!=44`, confirm disabled, points value reads invalid (red / `"/ 44"`).
- confirm → `confirmed` emitted + `SaveManager.has_player()`.
- back → `back_pressed` emitted with the same draft instance.
- header kicker shows the player **name** (city/country deliberately not shown on Build per design).
- **hi-fi/visibility** (CLAUDE.md gotchas — unit tests can't catch invisibility, so also eyeball):
  title label, points bar, both attr groups, classifier panel, CTA all `is_visible_in_tree()` and
  `size.y > 0`; CTA uses a `StyleBoxFlat` (not flat+modulate).
- **Eyeball gate:** render via the preview tool + launch the real flow; confirm it reads like the
  mockup before merge.

## Scope / explicitly out
- **Identity (Screen 1)** — next slice, blocked on the portrait pipeline.
- **Portrait art pipeline** — its own rung (handoff option 2).
- **Hall of Fame** — already a real screen; not touched.
- No new attribute, classifier, economy, or sim behaviour. Visuals + flavour blurbs only.

## Default decisions recorded
- Build scene rebuilt in code (consistency with the in-match hi-fi scene; one owner for slider theming).
- Drop the on-Build city/country recap (design folds identity into the header kicker = name only).
- Classifier blurbs are flavour, keyed by the 4 real kinds, lives in the scene.
- Stable render path `docs/mockups/latest/player-creation-build.png`.
