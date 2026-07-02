# Portrait Pipeline — Design (2026-07-03)

Basic-gameplay item (5), the last rung before the iOS export. Replaces the single shared
placeholder (`assets/portraits/hero-cap.png`) with a real per-player portrait system wired
to appearance and form.

## Nico's rulings (given at rung start)

- **Route: hybrid.** Build the full pipeline now from the design track's delivered art;
  file a design brief in parallel for the pieces design still owes. Design's art drops in
  later with zero code changes.
- **Matrix: 16 faces** = 4 appearance buckets × 4 form expressions. Skill tier stays on
  the ring colour (`Palette.skill_ring`) — the portrait does not vary by tier.
- **Art source:** the claude.ai design project's delivered portrait set (see below), not
  the older 3-style comparison sheet.

## The recovered design deliverable

The design track produced a **locked canonical player-profile system** ("Player Profile
System v1", claude.ai design project `0bdbcddf…`) that never landed in the repo. Recovered
2026-07-03 via the project's file API and committed under `docs/design-drop/portraits/`:

- **9 expressions** (`expr-*` full tiles + `clean/face-*` close crops, 173px wide):
  neutral · happy · excited · focused · determined · surprised · disappointed · angry · confident
- **6 feature swatches** (`player-*`): clean-shaven / beard / mustache / stubble ×
  light-skin / dark-skin
- **5 headwear** (`equip-*`): cap · helmet · helmet-grill-up · sun-hat · bucket-hat
- **4 view angles** (`view-*`): front · three-quarter · side · back
- **4 action tiles** (`action-*` + `clean/act-*`): looking-up · shouting · celebrating · focused-batting
- `player-style-sheet.png` (the master sheet) + two spec HTMLs
  (`Player Profile System v1.html`, `Player Headwear Mocks v1.html`)

Design's own intent (from the spec HTML): expressions are **driven by in-match/form
state** — "Form streak hot = happy/confident, after a wicket = disappointed/angry, on a
milestone = excited, mid-decision = focused." Two skin tones shipped; the spec says
"we'll grow this to 4–5 tones in production" — that growth is exactly what our design
brief requests.

Confirmation the game already wears this style: the existing `hero-cap.png` placeholder
is **byte-identical** to the drop's `view-three-quarter.png`.

## Decisions (DP1–DP10, AFK defaults unless marked)

- **DP1 — Runtime set = 16 flat files** `assets/portraits/<bucket>-<band>.png`
  (`white|mixed|indian|black` × `hot|steady|tired|cold`), sliced/remapped from design's
  `clean/face-*` tiles. The full 44-file design drop lives under `docs/design-drop/`
  (not `assets/`) so the game bundle ships only what it uses.
- **DP2 — Form→expression mapping** (design's guidance): HOT→`confident`,
  STEADY→`neutral`, TIRED→`disappointed`, COLD→`angry`. The other 5 expressions + action
  tiles are landed but unwired (future key-moment/stinger art).
- **DP3 — Canonical form banding** in a new `FormBand` domain helper:
  `HOT form≥2 · STEADY 0≤form≤1 · TIRED form==-1 · COLD form≤-2`.
  This **fixes a latent display bug**: `Player.form` defaults to `0`, documented in
  `player.gd` as "Steady (neutral)", but the hub chip and `Palette.form_glow` banded
  `0 → TIRED` — every fresh player read as TIRED. Both now delegate to `FormBand`
  (glow colours unchanged per band; only the 0/1 boundary moves). The later
  Form-mechanic rung re-tunes ticks against this single seam.
- **DP4 — Skin-tone variants generated in-house** by `tools/gen_portraits.py`
  (committed, reproducible): palette-remap of the light-skin face tiles. WHITE = the
  original tiles untouched; BLACK anchored to design's own `player-dark-skin.png` skin
  palette; MIXED/INDIAN interpolated between them (matching the picker's four
  `placeholder_tint` positions, lightest→darkest). **Explicit stopgap** — replaced
  drop-in when design answers the brief. Fallback if the remap reads badly on eyeball:
  ship form-only faces (same face all buckets) and wait for design.
- **DP5 — `PortraitLibrary`** (`scripts/ui/portrait_library.gd`, static):
  `texture_for(bucket: int, form: int) -> Texture2D` and `path(bucket, band) -> String`;
  lazy `load()` + in-memory cache; unknown bucket/band clamps to WHITE/STEADY.
  Portraits carry **no data** — flavour only.
- **DP6 — Consumers wired this rung:** Identity hero (live-swap on appearance pick — the
  deferred delta from PR #96), Identity appearance tiles (real face thumbnails replace
  flat tints; selection ring behaviour unchanged), Season Hub player card
  (bucket × live form), Hall of Fame hero (tint ColorRect → portrait). **Out of scope:**
  in-match scorebar/key-moment avatars (side-view + action tiles; its own design-led
  rung), Pre-Match (shows attrs, no portrait slot in ADR 0010 low-fi).
- **DP7 — Hub form chip de-emoji'd** (`🔥 HOT` → `HOT` etc., colour already carries the
  band; Barlow tofus emoji — standing rule) and re-banded via `FormBand` (DP3).
- **DP8 — Opaque stage backgrounds kept.** The tiles ship on design's stage background
  (no alpha), same as today's hero-cap; portrait frames already crop with
  `STRETCH_KEEP_ASPECT_COVERED`. Transparent 2× exports are in the design brief.
- **DP9 — Design brief** `docs/design-inbox/portrait-tones-REQUEST.md`: the 9-expression
  face set in all 4 bucket tones, 2× resolution, transparent + stage variants; notes our
  bucket keys and the form mapping (DP2) so files land drop-in against DP1 names.
- **DP10 — `hero-cap.png` stays** (other screens still reference it) until the last
  consumer is migrated in this rung; delete only if nothing references it at the end.

## Architecture

```
docs/design-drop/portraits/…           ← full 44-file design deliverable (not shipped)
tools/gen_portraits.py                 ← reproducible: design-drop → runtime 16
assets/portraits/<bucket>-<band>.png   ← the 16 runtime faces (+ hero-cap.png until DP10)
scripts/domain/form_band.gd            ← FormBand: canonical banding + band keys
scripts/ui/portrait_library.gd         ← PortraitLibrary: (bucket, form) → Texture2D
consumers: identity.gd · appearance_picker.gd · season_hub.gd · hall_of_fame.gd
```

Data flow: `Player.appearance` + `Player.form` → (`SeasonViewBuilder` already copies
both onto `SeasonView`) → consumer calls `PortraitLibrary.texture(appearance, form)`.

## Testing

- Unit (GUT): `FormBand` banding table (incl. the 0=STEADY fix) · `PortraitLibrary.path`
  mapping + clamping · all 16 asset files exist and load as `Texture2D` · Identity
  hero-swap (texture object changes on `appearance_selected`) · hub card portrait matches
  the view's bucket · picker tiles carry textures not flat tints.
- Scene-visibility gotcha applies: assert texture set AND eyeball — new renders via
  `tools/preview_portraits.gd` (4×4 grid) + refreshed Identity/hub renders; launch the
  real game at the end (playable, not a screenshot).

## Risks / watch-outs

- Palette remap on soft-shaded cartoon art can band or bleed (cap is green, skin is warm
  — hue-select carefully). Mitigation: eyeball the 4×4 grid; DP4 fallback.
- `*.png.import` files are gitignored — fresh clones run `--import` (existing note).
- iCloud " 2" conflict files before any test run (existing hazard).
