# Hall of Fame — Real Screen Build Design

**Date:** 2026-06-05 · **Status:** Buildable · **Branch:** new feature branch off `main`
**Replaces:** the Phase-7 Hall-of-Fame *stub* (`scenes/stubs/hall_of_fame_stub.{tscn,gd}`).
**Design source of truth:** `docs/superpowers/specs/2026-06-02-hall-of-fame-design.md` (the behaviour/look spec, back-written from the locked hi-fi `docs/mockups/player-creation-v2.html`).
**This doc:** the *build* design — what we actually ship now, given which systems exist.

---

## 1 · Context & scope reconciliation

The Player Creation build is merged to `main`. The Hall of Fame currently exists only as a Phase-7 **stub** that lists archived Legends as plain text. This build replaces it with the **real screen**.

**The wrinkle:** the design spec (`2026-06-02`) describes a `Legend` record rich in career-summary stats — `seasonsPlayed`, `levelsWon`, `lifetimeTons`, `retiredSeason`, `immortalised` — but **none of the systems that produce those values exist yet** (no Season loop, no Shop, no Tons economy). They are all hard zeros today. The spec anticipates exactly this: those fields are "stubbed until the Season loop and the real HoF screen exist."

**Scope decisions (brainstorm 2026-06-05):**
1. **Wire the fields, show honest zeros.** Add the stub fields to the data model now so the data contract is complete; the Season loop fills them later. The card renders `0 Seasons · 0 Levels won` honestly rather than hiding cells.
2. **Defer the Legend drill-down.** Spec §7's "tap a Legend → Career Record sheet" reuses a Theme-5 pattern that doesn't exist yet. Rows are **display-only** in V1.
3. **Skeleton-styled, like Identity/Build.** This ships flow + layout + the one live element. Real portraits, palettes, and backgrounds are a separate Theme 6 visual pass.

The **one genuinely-live element** is the **career-arc beat** (`startRole → endRole`), which is fully derivable today from the Player snapshot.

---

## 2 · Data model changes

### 2.1 `LegendEntry` (additive)

Current fields: `player: Player`, `end_reason: String`, `ended_at: int`, `seasons_played: int`.

Add:
- `levels_won: int = 0` — career Levels won (stub; Season loop populates at archive time).
- `retired_season: int = 0` — the Season number at retirement (stub).
- `immortalised: bool = true` — gold/bronze badge gate. **V1: always `true` (gold).** The bronze "⚱ Retired" fallback (spec §5) is a later one-line flip when a balance rule lands.

`lifetime_tons` is **not** a new field — it reads from the snapshot's `player.tons_balance` (already present, currently 0).

### 2.2 Arc roles are derived, not stored

The design spec stores `startRole`/`endRole` on the `Legend` record. **We deviate:** the `Player` snapshot already holds both `starting_attributes` (captured at creation) and `attributes` (final, post-drift), so the labels are fully derivable. Storing them would duplicate derivable data and risk the stored label drifting out of sync with the attributes. **Single source of truth = the snapshot.**

Add two methods to `LegendEntry`:

```gdscript
func start_role() -> int:   # ClassifierLabel.Kind
    return Classifier.classify(player.starting_attributes)

func end_role() -> int:     # ClassifierLabel.Kind
    return Classifier.classify(player.attributes)
```

Today `start_role() == end_role()` for every Legend (no system drifts `attributes` away from `starting_attributes` yet). That's correct and honest — "a career that never changed shape is itself a story" (spec §4). The mechanism is real; it simply has nothing to diverge on yet.

---

## 3 · The screen — `scenes/hall_of_fame/hall_of_fame.{tscn,gd}`

Promoted out of `scenes/stubs/`. **Preserves `signal begin_new_player()`** — the router contract is unchanged. Layout mirrors the locked mockup's "Hall of Fame" frame, skeleton-styled.

**Ordering:** `SaveManager.archive_to_legends` does `entries.append(...)`, so the archive is stored **oldest-first** — the most recent Legend is `entries[-1]` (the last appended), and `entries[0]` is the oldest. The **hero** is always the most recent = `entries.back()`; the "Earlier Legends" list shows the remaining entries **newest-first** (iterate from the second-to-last down to index 0). This covers both the "arrived from a fresh career end" case and a future on-demand browse.

### 3.1 Anatomy

- **Header** — title `HALL OF FAME` + Legend count `{n} Legends`.
- **Hero card** (`entries.back()` — the most recent):
  - **Retire badge** — gold `★ Immortalised`. While `retired_season == 0`, **omit the `· S{n}` suffix** (no Season system makes an S-number meaningful yet — this is honest, not a faked zero). Suffix returns when `retired_season > 0`.
  - **Name** (`player.name.display_caps()`) + meta line `{seasons_played} Seasons played · {levels_won} Levels won`.
  - **Arc-beat marquee** — `[startRole pill] → [endRole pill]`, labels via `ClassifierLabel.display_name(entry.start_role())` / `end_role()`. Both pills always render even when equal. Pills size to content (no truncation).
  - **Lifetime strip** — `{seasons_played} Seasons · {levels_won} Levels won · ₸{player.tons_balance}`. Honest zeros.
  - **Portrait** — `ColorRect` tinted via `AppearancePicker.placeholder_tint(player.appearance)` (the same helper Identity/Build use). Real portrait art is Theme 6.
- **"Earlier Legends"** — `ScrollContainer` listing every entry except the hero, **newest-first** (iterate `entries` from the second-to-last index down to 0). Each row is a **portrait-card**: tint swatch + name + compact arc `{startRole} → {endRole}` + one headline stat `{seasons_played} Seasons`. **Display-only** (no tap action in V1).
- **"New Player"** button → emits `begin_new_player`.

### 3.2 Edge cases

- **First-ever career death** — hero card renders; the "Earlier Legends" list has **zero rows**. No placeholder text — the hero alone is correct (spec §8).
- **Empty archive** — the router only pushes HoF on `career_ended`, so there is always ≥1 entry in practice. Guard anyway: if `entries` is empty, hide the hero card and show nothing but the New-Player button (defensive; not a designed state).
- **0 Levels won** — meta + strip still render (`0 Levels won`); the arc beat is the focus regardless.

---

## 4 · Router change — `scenes/main.gd`

- Repoint `const HALL_OF_FAME := preload(...)` from `res://scenes/stubs/hall_of_fame_stub.tscn` to `res://scenes/hall_of_fame/hall_of_fame.tscn`.
- Delete `scenes/stubs/hall_of_fame_stub.{tscn,gd,gd.uid}`.
- `_on_career_ended` and the `begin_new_player.connect(...)` wiring are **unchanged** — same signal name and arity.

---

## 5 · Testing (test-first, per project convention)

GUT 9.6, headless run per project `CLAUDE.md`. Run `--import` once after adding the new scripts.

1. **`test_legend_entry.gd` (real red→green)** — the genuinely new logic:
   - A batter-shaped `starting_attributes` → `start_role()` returns `Kind.BATTER`.
   - Drift the snapshot's final `attributes` to a bowler shape → `end_role()` returns `Kind.BOWLER`, proving start≠end derivation works.
   - New fields default correctly: `levels_won == 0`, `retired_season == 0`, `immortalised == true`.
2. **Save round-trip** — extend `test_save_manager.gd`: archive a Player, reload, assert the new `LegendEntry` fields persist (and the deep-duplicate guard still holds).
3. **`test_hall_of_fame_scene.gd` (scene test, like `test_build_scene`)** — instantiate the scene, inject a `LegendsArchive` of N entries:
   - Header count reads `{N} Legends`.
   - Hero renders `entries[0]`'s name + arc labels.
   - "Earlier Legends" row count == `N - 1`.
   - With N == 1, earlier-list row count == 0 (no placeholder).
   - Pressing "New Player" emits `begin_new_player`.
4. **Eyeball in a real 390×844 window** — unit tests are blind to invisibility (the Phase-5 `flat`-Button lesson). Confirm: hero card, gold badge, both arc pills visible, portrait tint shows, earlier rows scroll. Walk the live loop: dev-win/retire → HoF shows the just-ended career as hero → New Player → Identity.

---

## 6 · Out of scope (deferred, non-blocking)

- `immortalised` gold/bronze trigger rule — balance (Theme 7); V1 all gold.
- Legend drill-down sheet — reuses a Theme-5 pattern that doesn't exist yet.
- Real portrait art / AUS portrait set / real name banks — Theme 6.
- Populating `seasons_played` / `levels_won` / `retired_season` / `tons_balance` with non-zero values — the Season/Shop/Tons systems (Theme 7+).
- Sort/filter, compact-row variant, on-demand HoF entry point from a new-player screen — not V1.
