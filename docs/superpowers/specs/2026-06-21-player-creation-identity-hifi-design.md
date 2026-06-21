# Player Creation · Identity (Screen 1) — hi-fi re-skin

**Date:** 2026-06-21 · **Rung type:** hi-fi screen re-skin (presentation, Theme 2) · **Risk:** pure UI — zero sim/ledger/data-contract.

## What & why
The Build screen (Screen 2) was re-skinned and design-confirmed (PRs #94/#95). This rung does the
**matching slice for Screen 1 — Identity** — the portrait-anchored "Who are you?" screen (country
toggle · city · appearance picker · name & re-roll). It translates the **Identity band** of the
design-locked `docs/mockups/player-creation-v2.html` onto the shared `Palette`/`UIStyle`/`Fonts`
foundation, exactly as the Build rung did. Interaction is unchanged.

Source of truth: the two Identity frames in `player-creation-v2.html` ("Screen 1 · Identity" SA +
the AUS palette swap). Both are the same locked layout, re-themed by country.

## Approach (mirrors the Build rung)
- **Rebuild `scenes/player_creation/identity.gd` in code** on `Palette`/`UIStyle`/`Fonts`; the
  `.tscn` collapses to a one-node shell (like `build.tscn`). The custom styling lives in one place.
- **Preserve the data contract exactly:** signal `advance_to_build(draft)`, `set_draft(draft)` for
  Back-hydration, and the member names the existing `test_identity_scene.gd` reaches
  (`_draft`, `_country_sa_btn`, `_country_aus_btn`, `_city_dropdown`, `_appearance_picker`,
  `_name_label`, `_reroll_btn`, `_next_btn`, and the `_on_*` handlers). All Screen-1 behaviour
  (country resets city + re-rolls name, appearance re-rolls name, Next-gating, Back re-hydration)
  is carried over byte-for-byte from the low-fi screen.
- **Reuse the `AppearancePicker` component** (its tinted tiles + selection behaviour are already
  tested). Add a non-behavioural `apply_hifi(accent)` that rounds the tiles and swaps the hard-coded
  gold selection ring for the **country accent** — visuals only, selection/enable logic untouched.

## Layout (top → bottom), country-themed via `Palette.country_set(code)`
1. **Header** — `UIStyle.header(grad1, grad2, glow)` country-gradient panel: kicker `NEW PLAYER`
   (W_LABEL) + title `Who are you?` (W_HEADLINE) + 2 step-dots (**dot 1 ON** = accent, dot 2 off —
   the inverse of Build).
2. **Hero portrait** — a centred `TextureRect` (`assets/portraits/hero-cap.png`) framed by an accent
   ring (`UIStyle.portrait_ring(accent)`) over a country-gradient backing panel + glow.
3. **Name block** (centred) — name value (W_HEADLINE) + sub `City · Country` (W_BODY, dim) + a
   re-roll button.
4. **Country toggle** — segmented two buttons (`SOUTH AFRICA` / `AUSTRALIA`); the selected one gets
   the country-gradient fill + accent border, the other a flat surface.
5. **City pill** — the `OptionButton`, styled as a rounded pill with a `▾` chevron suffix.
6. **Appearance picker** — the re-used `AppearancePicker`, hi-fi'd (rounded tiles, accent ring).
7. **CTA** — gold `Next — Build your game →` (`UIStyle.cta(Palette.GOLD)`), disabled until
   `identity_complete()`.

## Decisions (AFK defaults — recorded, not asked)
- **D1 · Portrait is the single placeholder.** Only `hero-cap.png` exists; the mockup's
  `hero-front`/`hero-helmet`/`keeper` portraits are not yet commissioned. So the hero portrait is
  **static `hero-cap.png`** and the appearance tiles keep their **placeholder skin-tone tints**
  (they do not swap the hero). The portrait pipeline is its own future rung; this screen is built to
  consume real per-appearance art the moment it lands. → **design delta #1**.
- **D2 · No emoji.** Barlow Semi Condensed has no emoji glyphs (they render as tofu — the Build rung
  learned this). So: the country toggle drops the `🇿🇦`/`🇦🇺` **flags → text only**; the re-roll
  control uses the dingbat **`↻`** (renders in Barlow), not `🎲`. Arrows (`→`, `▾`) are dingbats and
  render fine. → **design delta #2**.
- **D3 · No corner control on Identity.** The mockup shows a corner `✕`. Identity is the first screen
  on a cold start (and after permadeath, reached from the Hall of Fame) — there is nowhere to close
  *to*, so a corner button would be a dead control. Omitted. (Build legitimately has a `←` Back; its
  prior screen is Identity.) → **design delta #3**.
- **D4 · Name sub copy.** `City · Country` in title case (e.g. `Cape Town · South Africa`); shown
  only once a city is chosen, else the country alone (or `—` before any pick).

## Out of scope / deferred
- Real per-appearance portrait art (the portrait pipeline rung — unblocks live hero-swap).
- Animations (the mockup's hero cross-fade on appearance tap; reroll spin).

## §10 — Results (to fill on build)
- Tests: target **green**, +visibility/structure guards. Render `docs/mockups/latest/player-creation-identity.png`.
- Design review request: `docs/design-inbox/player-creation-identity-REQUEST.md` (the 3 deltas).
