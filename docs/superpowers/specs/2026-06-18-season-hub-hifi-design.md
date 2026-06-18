# Season Hub hi-fi v1 — design

**Date:** 2026-06-18
**Status:** approved (design), pre-plan
**Rung type:** presentation (hi-fi). **Zero ledger/sim risk by construction** — scene + new UI-helper files only; no resolver, tuning, or domain-logic file is touched.

## 1. Plain-English goal

The Season Hub is the game's home screen, and it currently looks like a skeleton — default-grey Godot `Label`s and `Button`s in a plain list (Nico: "a bit crappy / not very pretty"). This rung gives it the locked hi-fi look: styled panels, a broadcast-style topbar, a horizontal fixtures chain, a proper player card with a portrait frame, a rarity-styled joker bench, an affinity bar, and a gold primary CTA — **without changing any of the data it shows or any simulation behaviour**.

It also stands up a small, reusable **design system** (`Palette` + `UIStyle`) so the other screens (match, shop, result) become cheap hi-fi passes later.

## 2. References (the canonical, final mockups)

- **Hub layout** → `docs/mockups/around-the-match-v1.html` **§1 (Season Hub)** — the newest around-the-match reference (2026-05-31). The block stack and chrome target.
- **Visual system** → `docs/DESIGN_HANDOFF.md` **§8** (palette, type scale, spacing, radii). Canonical hex values.
- **Portrait** → `docs/DESIGN_HANDOFF.md` **§16.3** (full-frame skill-tier background + Form-coloured glow frame) + `docs/mockups/player-avatars-styles.html` (the "better profile pictures" — the illustrated faces are the *eventual* art, this rung builds only the frame + a swappable face slot).
- **In-match final** (for reference only, NOT this rung) → `docs/mockups/match-screen-final.html` ("revised layout v4"). Note its **less-stretched bar-graph / auto-sim bar** for the future in-match hi-fi rung; the hub has no worm chart so it is out of scope here.

## 3. Scope & cuts (honest about cost)

**In scope:** the full §1 block stack (7 blocks) restyled, the shared `Palette` + `UIStyle` foundation, the §16.3 portrait *frame*.

**Cut (named, deferred):**
1. **Real illustrated faces** — the §16.3 portrait is built as a **frame only**: skill-tier background + Form glow + cap number + ★ corner, with a clearly-labelled empty face slot. The illustrated cartoon/silhouette faces (`player-avatars-styles.html`) are their own **art-pipeline rung** (rendering CSS-art to textures). The frame is laid out so the real face drops in with no layout change.
2. **Motion / animation** — the hub is a static screen this rung. CTA glow, score bump, Reigns swipe belong to the *match* rung. No `Tween` work here.
3. **No-scroll "one dense screen" ideal** — keep the existing `ScrollContainer` (guards against clipping on a real 390×844 phone, per the CLAUDE.md ScrollContainer trap). Tightening to a true no-scroll screen can come later.

## 4. The shared design-system foundation

### 4.1 `Palette` — `scripts/data/palette.gd` (`class_name Palette`)
Pure constants, single source of truth for colour. From DESIGN_HANDOFF §8 + §16.3:

- Core: `BG = #1a1a22`, `SURFACE` (raised panel, `rgba(255,255,255,0.04)` → opaque approximation `#212129`), `BORDER` (`#2c2c36`), `WHITE`, `WHITE_DIM` (`#9a9aa6`).
- Accent: `GOLD = #ffd166` (primary wow / ₸ / player highlight), `WARN = #f5a623`, `DANGER = #ef6c6c`, `BLUE = #4a90e2`, `GREEN = #2ecc71`.
- Country accent (existing convention, ADR 0001): `SA = #1f7a4d`, `AUS = #e3a008`.
- Rarity: `COMMON = #e8e8e8`, `RARE = #4f8cff`, `LEGENDARY = #ffc23c` (matches the current scene constants — keep identical).
- **Skill tier bg (§16.3):** `SKILL_4 = #f5cb50` (gold), `SKILL_3 = #4a90e2` (sky blue), `SKILL_2 = #9aa0a6` (silver), `SKILL_1 = #3a3a44` (charcoal). Helper `skill_bg(stars: float) -> Color` (≥3.5→4, ≥2.5→3, ≥1.5→2, else 1).
- **Form glow (§16.3):** `FORM_HOT = GOLD`, `FORM_STEADY = GREEN`, `FORM_TIRED = #b8860b` (brown), `FORM_COLD = #808080` (grey). Helper `form_glow(form: int) -> Color`.

`form` mapping: the `SeasonView.form` int's existing meaning is the source of truth; the spec maps its range to hot/steady/tired/cold in §6.4 and the helper lives in `UIStyle`/the scene (display-only), not in `Palette` (which stays pure colour).

### 4.2 `UIStyle` — `scripts/ui/ui_style.gd` (`class_name UIStyle`)
Static factory functions returning configured `StyleBoxFlat`es / theme overrides. Chosen over a hand-authored `Theme.tres` because it is **unit-testable** (assert the returned box's `bg_color`/`corner_radius`) and matches the codebase's existing "build styleboxes in code" pattern (`appearance_picker.gd`, the current PLAY tile).

- `panel() -> StyleBoxFlat` — surface bg, 8px radius, subtle border, content margins.
- `pill(bg: Color) -> StyleBoxFlat` — rounded chip (position pill, fixture dots).
- `chip(rarity: String) -> StyleBoxFlat` — joker chip with rarity-coloured left pip/border.
- `cta(accent: Color) -> StyleBoxFlat` — solid accent, 10px radius, tall content margins (the "Next Match ▶" tile; replaces the current ad-hoc PLAY stylebox).
- `portrait_frame(skill_bg: Color, glow: Color) -> StyleBoxFlat` — skill-tier bg fill + Form-coloured border (the glow), 12px radius.
- `bar_track() / bar_fill(accent) -> StyleBoxFlat` — affinity bar.
- `apply_label(label, size, color, caps := false)` — convenience for the type scale (§8 sizes 8–26px, all-caps + letterspacing for labels).

All take colours from `Palette`; none hard-code hex.

## 5. Architecture & seam (unchanged data contract)

- The scene **still renders a `SeasonView`** built by `SeasonViewBuilder` — no field added, no builder change. Every block reads existing fields (§6 maps each).
- All current public behaviour preserved: `boot()`, `set_view()`, `set_source()`, `set_play()`, `step()`, `scrub_index()`, `season()`, `current_view()`, `live_play()`, `current_career()`, `has_play_control()`, and signals `open_match(match_index)` / `play_next(team_index)`.
- `season_hub.tscn` `Root` is rebuilt into the §1 block stack (styled `PanelContainer`s); `season_hub.gd`'s `_render_*` functions are rewritten to populate the new nodes using `Palette`/`UIStyle`. The ScrollContainer/Margin wrapper stays.

## 6. Block-by-block mapping (mockup §1 → SeasonView field → treatment)

### 6.1 Topbar
`team_name`, `team_stars`, `player_final_position`, player's points (from the player row in `standings`). Country accent from `country`.
→ team initials badge (pill, accent) · team name (accent) · ★ rating (filled/half/empty from `team_stars`) · position pill ("Nth · P pts"). On the live path, position/points come from the running `standings`; on the scrub/final path, from final standings (already how the scene gets standings).

### 6.2 ₸ band
`tons_balance` + context (`level`, `tour_name`, `difficulty_label`, scrub/played progress).
→ "TONS BANKED" caps label + big gold ₸ value (size 24) · right column: "Club · <tour>" + "MATCH n / 7" (live: `played_count()`; scrub: `scrub_index`). Fixes the ₸-chip right-edge clip (it moves into its own band, no longer fighting the team name).

### 6.3 Fixtures chain
`fixtures[]` (`{opponent_name, played, player_won, score_text}`), `scrub_index`.
→ a horizontal chain of fixture nodes inside an HBox: played = W (accent) / L (danger) dot, current scrub head = ● pulse-styled (static this rung), upcoming = "M5/M6/M7" grey, each with a 3-letter opponent cap. **Behaviour preserved:** each node is a `Button` — played → `open_match.emit(idx)`, others → `_rebuild(idx)` (scrub). Horizontal scroll allowed within the chain if it overflows.

### 6.4 Player card + §16.3 portrait frame
`appearance` (face slot id, deferred), `team_stars` (skill bg), `form` (glow), `power/composure/attack/control`, `ovr`, card batting (`card_batting_avg`, `card_strike_rate`) + bowling (`card_economy`, `card_best_bowling`, `card_wickets`) stats, `player_name`, `city`.
→ left: portrait frame (`UIStyle.portrait_frame(Palette.skill_bg(team_stars), Palette.form_glow(form))`) with cap number + ★ corner + an explicit empty face slot node named `FaceSlot` (the swap-in point). right: name · city · OVR pill · form chip (label+emoji from form) · two stat groups (🏏 Batting Avg/SR · 🎯 Bowling Econ/Wkts/Best). "no matches yet" state preserved when `card_matches == 0`.
Form→label: map `SeasonView.form` to {hot,steady,tired,cold} + emoji; display-only helper in the scene.

### 6.5 Jokers bench
`jokers[]` (`{name, rarity, effect?}`).
→ "JOKERS BENCH n / 4" header + rarity-styled chips (`UIStyle.chip(rarity)`, rarity-coloured pip) + empty slots up to 4 ("+ earn at…"). Empty-state ("(no jokers)") preserved.

### 6.6 Affinity bar
`affinity` (int).
→ "AFFINITY · <team>" label + a styled progress bar (`UIStyle.bar_track`/`bar_fill(accent)`). Bar fraction = `affinity` against its known max (display clamp 0–100%; if the affinity scale is unknown, clamp and show the integer — no new domain).

### 6.7 Primary CTA + scrub bar
`play_next` (live path) / scrub controls.
→ gold "Next Match ▶" CTA tile (`UIStyle.cta(accent)`) — this IS the existing PLAY button, restyled, same `play_next.emit(team_index)`. Below it the scrub bar (‹ Prev / Match n / N / Next ›) restyled with `UIStyle` buttons; unchanged behaviour. On the live path the CTA shows; on the scrub/replay path the scrub bar leads (current `has_play_control()` logic intact).

## 7. Testing

- **`Palette`** — unit test: helpers return the right tier/glow colour for boundary star/form values; constants present.
- **`UIStyle`** — unit test: each factory returns a `StyleBoxFlat` with the expected `bg_color` / `corner_radius` / border colour (catches silent mis-wiring; styleboxes are pure data).
- **`season_hub` scene test** (extend `test_season_hub_scene.gd`): after `set_view`/`set_play`, assert each new block node exists, **`is_visible_in_tree()`**, and **`size.y > 0`** (the StyleBox-invisible + ScrollContainer-collapse traps from CLAUDE.md), and that data still renders (team name, ₸, a fixture, a standings row, the card stats). Keep `test_season_hub_open_match.gd` green (tap-to-open-match behaviour preserved).
- **Eyeball in a real 390×844 window** (unit tests cannot catch invisibility/ugliness) → screenshot deliverable `docs/mockups/season-hub-hifi-built-v1.png`.
- **Launch the real game** at the end so Nico navigates the live hub himself (per the "launch the playable app, not a screenshot" preference).

## 8. Test-first discipline

Per CLAUDE.md: red via parse-error on the new `class_name`s (`Palette`, `UIStyle`) → green by total count climbing + `All tests passed`. Run the whole suite each step (`--import && gut -gdir=res://tests/unit`); the `-gtest` filter does not work here.

## 9. Decisions log

- **DH1** — Code-built `UIStyle` factory over a `Theme.tres` resource: testable + matches codebase pattern.
- **DH2** — `Palette` is pure colour constants (`scripts/data/`); `form`→label mapping is display-only and lives in the scene/`UIStyle`, not `Palette`.
- **DH3** — Portrait = §16.3 frame only this rung; illustrated face is a labelled `FaceSlot` swap-in for the deferred art-pipeline rung.
- **DH4** — Keep the `ScrollContainer` (no forced no-scroll); guards clipping.
- **DH5** — No motion/animation this rung (static hub); glow/swipe deferred to the match rung.
- **DH6** — In-match "less-stretched bar graph" feedback logged against `match-screen-final.html` for the future in-match hi-fi rung; not actioned here (hub has no chart).
- **DH7** — Zero data-contract change: no new `SeasonView` field, no `SeasonViewBuilder` change, no signal change — pure restyle.

## 10. Results (built 2026-06-18)

- **673 tests green** (9904 asserts). New: `test_palette.gd` (+3), `test_ui_style.gd` (+5), plus visibility asserts added to the existing hub scene test. No prior test removed; sim/ledger untouched (no resolver/tuning/domain file in the diff).
- **Screenshot deliverable:** `docs/mockups/season-hub-hifi-built-v1.png` (live forward-play hub, Karoo Kings, seed-20260615, 3/7 played). Rendered by `tools/preview_season_hub_hifi.gd`.
- **What to eyeball:** the home screen is now styled cards (not flat grey) — green team badge + ★ rating + "8th · 2 pts" pill, big-gold ₸ band, colour-coded horizontal fixtures chain with a gold current-match head, the §16.3 portrait frame (silver skill tier + form glow + "BK" initials + ★ corner, face slot stubbed for the art rung), batting+bowling career line, joker bench (4 slots), affinity bar (4/5), the league table (player row gold), and the gold "Next Match ▶" CTA.
- **Two build-time tweaks** beyond the plan: `Palette.SURFACE`/`BORDER` lightened so panels read as cards (first render had them invisible against `BG`); affinity rendered against a loyalty "full = 5" cap with the count shown (it is a small seasons-stayed counter, not 0–100) — both display-only.

### Carried to the next hi-fi rung
- **Real illustrated faces** (the "better profile pictures" from `player-avatars-styles.html`, style B etc.) — the art-pipeline rung; they drop into the `Portrait/FaceSlot` with no layout change.
- **In-match hi-fi** — `match-screen-final.html` ("revised layout v4") is the target; note its **less-stretched bar-graph / auto-sim bar** (Nico's feedback this session). The shared `Palette`/`UIStyle` foundation is now ready to reuse there.
- **Motion** (CTA glow, Reigns swipe) deferred (static hub this rung).
