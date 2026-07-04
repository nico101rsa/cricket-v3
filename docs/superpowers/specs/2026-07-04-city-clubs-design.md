# City clubs at creation (playtest T11) — design

**Date:** 2026-07-04 · **Rung:** playtest fix T11 (small-medium, flavour + creation UI)
**Source:** Nico's playtest note (2026-07-03): *"there needs to be clubs loaded per
city so pretoria you can look at the biggest clubs/suburbs in the city..maybe give
the user a selection of 3 starting clubs (low rank clubs)"*.
**Ruling (Nico, 2026-07-03): flavour only — name and identity.** Zero mechanical
difference between clubs beyond what already exists (the three starting slots
already differ by ★ on the ladder — that is existing mechanics, not new).
**Mode:** AFK — defaults recorded as DCC1–DCC10.

## 1. What this is

Two pieces, one rung:

1. **City club-name banks** — every creation city (11 SA + 10 AUS, `Cities`) gets
   a bank of 8 club names drawn from its real suburbs/communities ("Menlo Park CC",
   "Manly Seasiders"). A new career's **Club level (Level 1, all 8 teams)** is
   named from the chosen city's bank — your first league reads as YOUR city's
   club league.
2. **The starting-club pick, surfaced** — `CareerResolver.start_career(picked_club_slot)`
   has taken a 3-way pick since the career rung (DC7) but the UI hardcodes slot 0.
   The Identity screen gains a "YOUR CLUB" section: 3 tappable tiles (the 3
   lowest-★ clubs of your city — 1.5★ / 2.0★ / 2.5★), tap to choose where you start.

## 2. Decisions (AFK defaults)

- **DCC1 — scope of renaming:** the whole Club level (8 teams) takes city names,
  not just the 3 candidates — the pick reads as "which of MY city's clubs do I
  join", and your league opponents are local too. City/Province levels keep the
  existing placeholder banks (the Country master-data axis stays a later data
  rung, per the DC6 note in `CareerResolver`).
- **DCC2 — fallback keeps canon:** `start_career(slot, city := "")` — empty or
  unknown city keeps `TEAM_NAMES` byte-for-byte (Karoo Kings stays canon; every
  existing test/caller/tool is unchanged without edits).
- **DCC3 — data home:** new `scripts/data/city_clubs.gd` (`CityClubs.bank(city)`
  → 8 names, `CityClubs.has_bank(city)`). Names are in-house content in the
  `PlayerNames` spirit: real suburb/area names + club-cricket suffixes (CC,
  Wanderers, XI, Districts…). A design-track brief for richer local flavour is
  an optional later upgrade, filed only if Nico wants it — not part of this rung.
- **DCC4 — where the pick lives:** a "YOUR CLUB" section on Identity between the
  city pill and the appearance picker. No new step/screen, step-dots untouched.
  This deviates from the design-locked Identity band → delta filed as
  `docs/design-inbox/identity-club-pick-REQUEST.md` (the PR #96 convention).
- **DCC5 — tile content:** club name + ★ rating (`Display.stars_str`, the T2
  rule) for slots 0/1/2 (= `lowest_star_club_indices()` on a fresh ladder:
  1.5★/2.0★/2.5★). The ★ difference is EXISTING ladder mechanics made visible,
  not a new mechanic; the tiles carry no other stats.
- **DCC6 — default pick, never gating:** slot 0 (the 1.5★ underdog, today's
  behaviour) preselected; Next is never blocked by the club section. City change
  re-renders tile names; the selected slot index is kept (slots are stable).
- **DCC7 — persistence path:** `PlayerCreationDraft.club_slot: int = 0` →
  `Player.club_slot` (copied in `from_draft`) → `main._push_career_grid` calls
  `start_career(player.club_slot, player.city)`. Old Player saves load
  `club_slot = 0` by @export default — exactly today's behaviour; existing
  careers keep their persisted team names (nothing renames retroactively).
- **DCC8 — re-roll:** none. The 3 offered clubs are the city bank's slots 0–2,
  deterministic per city. (A "show me other clubs" re-roll is scope creep for
  flavour — YAGNI.)
- **DCC9 — name-bank quality bar:** 8 names per city, all distinct within a
  city, distinct from every `TEAM_NAMES` placeholder, no emoji, ASCII-safe
  (Barlow), ≤ 22 chars so the hub header/fixture chain doesn't clip. Every bank
  unit-enforced on these rules (count, uniqueness, length).
- **DCC10 — no sim/balance surface:** names never enter a resolver; ★ ladder,
  opponents, tours, prices untouched. No balance gate; eyeball + renders only.

## 3. Components

- `scripts/data/city_clubs.gd` — `const BANKS := {city: [8 names]}` for all 21
  cities; `static bank(city) -> Array` (fallback `CareerResolver.TEAM_NAMES[0]`),
  `static has_bank(city) -> bool`.
- `scripts/domain/career_resolver.gd` — `start_career(picked_club_slot, city := "")`:
  Level-1 names from `CityClubs.bank(city)` when `has_bank(city)`, else placeholder.
- `scripts/data/player_creation_draft.gd` + `scripts/data/player.gd` — `club_slot`.
- `scenes/player_creation/identity.gd` — `_build_club_pick()` section (3 tiles in
  the segmented-button style, `_style_seg`-like selected state), `_club_buttons`,
  re-render on city change, writes `_draft.club_slot`.
- `scenes/main.gd` — `_push_career_grid` passes `player.club_slot, player.city`.
- `docs/design-inbox/identity-club-pick-REQUEST.md` — the Identity delta brief.

## 4. Testing

- `test_city_clubs.gd`: every `Cities.SA + Cities.AUS` city has a bank; each bank
  passes DCC9 (8 names, unique, ≤22 chars, none in `TEAM_NAMES`); unknown/""
  falls back to the placeholder bank.
- `test_career_resolver` additions: `start_career(0)` names byte-identical
  (DCC2); `start_career(1, "Pretoria")` → all 8 Club teams from the Pretoria
  bank, City/Province levels untouched, stars ladder unchanged,
  `current_team_index == 1`.
- Draft/Player: `club_slot` survives `from_draft`; defaults 0.
- `test_identity_scene` additions: 3 club tiles exist with `size.y > 0` and
  `is_visible_in_tree()`; tap tile 2 → draft carries `club_slot = 2` through
  `advance_to_build`; changing country/city re-renders tile names; Next stays
  enabled regardless of club section.
- Eyeball: render Identity (SA/Pretoria + AUS/Sydney) via the existing
  `tools/preview_player_creation_identity.gd`, plus launch-check.

## 5. Out of scope

- City/Province/team-wide naming overhaul (the "Country master-data axis" rung).
- Club badges/colours per club, club-specific mechanics, re-rolls (DCC8).
- Renaming inside existing saves.
