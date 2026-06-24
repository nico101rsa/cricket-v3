# Live Career Advance + Outcome screen hi-fi — design

**Date:** 2026-06-24
**Rung:** Theme 2 presentation/logic — the live-season-loop's last structural gap.
**Branch (planned):** `live-career-advance`
**Status:** design (AFK rung; decisions recorded below, Nico delegated the climb-model choice — "you decide").

---

## 1. Plain-English problem

The live season loop now plays end-to-end (league → playoffs → ₸ → outcome → quit & resume),
**but it doesn't *progress*.** Two concrete gaps:

1. **The live season is hardwired to tour 0 of the current Level and never touches the
   career grid.** `season_hub.boot()` always builds `DifficultyLadder.spec_for(level, 0)`
   with a constant `BOOT_SEED`. So "Continue" on the Outcome screen replays the *identical*
   cell — same opponents, same difficulty, same seed — forever. The `CareerState` is loaded
   (or freshly created) but its cell grid / `current_team_index` is never advanced by play,
   and **the live path never even saves the career** (it's recreated each cold start).

2. **The Outcome screen is bare-bones** — a `CenterContainer` with three stat rows, no
   design language, and it says nothing about *where the career goes next*.

This rung closes both: make the loop climb the grid (Club → City → Province) and re-skin the
Outcome screen on the shared `Palette`/`UIStyle`/`Fonts` foundation.

## 2. Goal / success criteria

- After a live season, the career grid **records the outcome** and the next season plays a
  **different, harder cell** — the loop genuinely climbs Club → City → Province → career-complete.
- The career is **persisted** across the live loop (survives quit, like the season already does).
- A **not-beaten** season replays the same cell with a *fresh seed* (a real re-attempt, not the
  identical match) — no softlock.
- Winning the **Province Premier final** completes the career → Hall of Fame.
- The Outcome screen wears the game's design language and tells you what just happened
  (cleared / promoted / champion) and what's next.
- **Zero sim/tuning/ledger risk** by construction — no ball/innings/joker/economy/difficulty
  math is touched; this is scheduling + grid transitions + presentation only.

## 3. The climb model (DECISION DLC1 — Model B, "rush-climb")

Nico delegated the choice between three models; recording **Model B**:

- **(A) Full offer-choice screen** — Continue shows an Offers card (cross up / stay / which team).
  Rejected for *this* rung: it is net-new decision-UI that wants its own design brief; it belongs
  in a later, well-scoped "Offers screen" rung. (Not discarded — deferred. See §9.)
- **(B) Tour advance + auto-cross at Level boundaries** — *chosen.* The live loop plays the lowest
  unbeaten-unlocked tour at the current Level; when a Level's climb tours are cleared it
  **auto-accepts the cross-up offer** so the loop climbs Levels with no new UI. This is exactly the
  `rush` climb line E4 found optimal (skip the optional Premier, cross the moment the readiness
  tour is beaten).
- **(C) Within-Level only** — rejected: the loop still wouldn't climb between Levels.

**Why B is the right default:** it makes the loop fully progress end-to-end with zero net-new
UI to design, is fully AFK-able, and leaves the offer-*choice* as a clean follow-up rung.

### 3.1 Cell-selection rule (the "rush" walk)

For a career at `current_level()` `L`:

1. **Climb tour** `t` = the lowest tour in `[0 .. READINESS_TOUR]` whose status is `UNLOCKED`
   (unlocked but not yet `BEATEN`). If `t` exists → **play `(L, t)`**.
2. Else (all climb tours `≤ READINESS` cleared at this Level):
   - If `L < LEVELS-1` **and** the next Level is unlocked → the career should already have
     **crossed up** in `advance_after_live_season` (so by boot time `current_team_index` is at
     `L+1` and rule 1 picks `(L+1, 0)`). Defensive fallback only.
   - Else (top Level, Province) → **play the Premier `(L, PREMIER_TOUR=7)`** — the only way to
     complete the career.

`PREMIER_TOUR` (7) is **optional at non-top Levels** (rush skips it) and **required at Province**
(winning its Final sets `complete`). (DLC5.)

### 3.2 "Beat a cell" = top-3 finish (DLC2)

Identical to the headless `CareerResolver`: `SeasonResult.beat` (player finished top 3) marks the
cell `BEATEN` and unlocks the next; `won_final` (finished 1st) drives Level-won / career-complete.
The live `SeasonPlay.season_result()` **already populates both** (`season_play.gd:489-490`), so the
trigger needs no new sim work.

## 4. Architecture — where the logic lives (DLC9)

Pure, headless-testable. No scene/sim code in the transition logic.

### 4.1 `CareerState` (new read helper)

- `next_climb_tour(level: int) -> int` — lowest tour in `[0..READINESS_TOUR]` with status
  `UNLOCKED`; `-1` if none. Pure read over `cell_status`.

### 4.2 `CareerResolver` (new static helpers — it already owns career orchestration)

- `next_live_cell(state) -> Dictionary` — `{ "level": int, "tour": int }` per §3.1. Pure read.
- `advance_after_live_season(state, player, result: SeasonResult, level, tour, rng) -> Dictionary`
  — the end-of-season grid transition for the live path. Mirrors the relevant slice of
  `play_season`:
  1. `state.record_outcome(level, tour, result.beat, result.won_final)`
  2. `state.seasons_played += 1`; `state.seasons_at_level += 1`
  3. **Auto-cross (DLC4):** if `state` is not `complete`, the current Level has **no** remaining
     climb tour (`next_climb_tour(L) == -1`), `L < LEVELS-1`, and `any_unlocked_at(L+1)` →
     `offers = generate_offers(state, result.beat, rng)`, pick the first offer with
     `level == L+1`, and `accept_offer(state, player, offer)` (resets `seasons_at_level`,
     `affinity`). If no cross-up offer is drawn, no-op (stay).
  4. Returns a small transition descriptor for the Outcome screen:
     `{ "beat": bool, "promoted": bool, "from_level": int, "to_level": int,
        "complete": bool, "next_level": int, "next_tour": int }`.

`generate_offers` already guarantees the cross-up offer on a fresh beat (`just_beat=true`), so a
readiness beat reliably crosses. The `rng` is seeded deterministically by the caller.

### 4.3 `season_hub.gd` (boot/set_play drive off the real cell)

- `boot()` and `set_play()` compute the cell via `CareerResolver.next_live_cell(career)` and store
  it (`_cell_level`, `_cell_tour`); the resume branch sets them from the loaded `LiveSeasonState`.
- Seed varies: `BOOT_SEED + career.seasons_played` (DLC6) — a brand-new career
  (`seasons_played == 0`) keeps the existing first-game seed; re-attempts and later cells differ.
- `enable_pay(...)` is passed the **real** `(_cell_level, _cell_tour)` (was `(level, 0)`).
- New accessor `current_cell() -> Vector2i` so `main` can save mid-season state at the right cell.
- **First-boot persistence:** when `boot()` creates a fresh career (`not has_career()`),
  `SaveManager.save_career(career)` immediately so the grid is durable.

### 4.4 `main.gd` (orchestration on season end)

- `_commit_and_return`: the mid-season save uses the hub's real cell —
  `play.to_state(cell.x, cell.y)` (was `(current_level(), 0)`).
- On `season_done()`:
  1. `var t = CareerResolver.advance_after_live_season(career, player, play.season_result(),
     cell.x, cell.y, rng)` (rng = `RandomNumberGenerator` seeded `play.seed() + 7`, a fixed
     offset distinct from strength/AI/playoff seeds).
  2. `SaveManager.save_career(career)`; `SaveManager.clear_live_season()`;
     `SaveManager.save_player(player)` (pay already banked).
  3. `_show_outcome(play, career, t)`.
- `_show_outcome` passes the transition descriptor to the screen. **Continue routing:**
  - If `t.complete` → `LifecycleManager.win_out()` (archives to Hall of Fame, clears player+career)
    → `career_ended` → HoF.
  - Else → `_push_hub()` (boot picks the new cell).

## 5. Outcome screen hi-fi (DLC8)

Re-skin `scenes/outcome/outcome.gd` on the shared foundation, conveying the transition. No design
brief/mockup exists for this screen → designed in-house to the established language (the same move
used for the season hub / in-match screens), then rendered for Nico's eyeball.

`set_outcome(result, pay, wins, career, transition)` gains the `transition` descriptor. Elements:

- **Country-gradient header** (`UIStyle.header`) with kicker `SEASON COMPLETE` + the finish
  headline (gold for a podium).
- **Transition banner** — the new, central piece: `CLUB · TOUR 3 CLEARED ↑` /
  `PROMOTED TO CITY` (gold, celebratory) / `🏆 PROVINCE CHAMPIONS — CAREER COMPLETE` /
  `MISSED OUT — ANOTHER GO` (muted, for a not-beaten season).
- **Stats panel** (existing rows, re-styled): finished position, record, ₸ banked.
- **Next-up chip** — `NEXT: CITY · TOUR 1` (or `HALL OF FAME →` when complete) so the player
  sees where Continue takes them.
- **Gold CTA** — `CONTINUE ▶` (or `ENTER THE HALL OF FAME ▶` when complete).

Behaviour/signals preserved: `continue_pressed`. Provenance-honest: no fabricated numbers; the
banner/next-up read straight off the real `CareerState` transition.

## 6. Persistence summary

| Object | When saved | Cleared |
|---|---|---|
| `Player` (incl. `tons_balance`, `affinity`) | after each match + on season end | on career-complete (LifecycleManager) |
| `CareerState` (grid, `current_team_index`, counters) | on fresh creation + on each season-end advance | on career-complete (LifecycleManager) |
| `LiveSeasonState` (seed/cell/decisions) | mid-season (per match) | on season end + on career-complete |

## 7. Testing (test-first)

Headless GUT unit tests carry the weight (the logic is pure):

- `CareerState.next_climb_tour` — fresh career → 0; after beating (L,0) → 1; after beating
  readiness → -1 (all climb tours cleared).
- `CareerResolver.next_live_cell` — fresh → (0,0); mid-Level → next tour; readiness cleared at
  a non-top Level after a cross → (L+1,0); top Level readiness cleared → (2,7) Premier.
- `CareerResolver.advance_after_live_season` —
  - beat a mid tour → cell BEATEN, next unlocked, `seasons_played`/`seasons_at_level` ++.
  - beat readiness at Level 0 → auto-crossed (`current_team_index` now a Level-1 team,
    `seasons_at_level` reset, `affinity` 0), descriptor `promoted=true`.
  - NOT beaten → grid unchanged (same cell still the next), `promoted=false`, counters still ++.
  - win Province Premier final → `complete=true`, descriptor `complete=true`.
- `season_hub.boot()` integration — fresh career persists a career save; seed varies with
  `seasons_played`; resume still byte-identical (existing test stays green).
- Outcome scene test — banner/next-up text reflect the transition descriptor; `is_visible_in_tree()`
  + `size.y > 0` guards on the new banner (per the ScrollContainer/flat-button gotchas).

**Determinism guard:** a no-decision live season committed twice with the same seed → same
`season_result()` (the prefix-stable contract is untouched).

## 8. Risk / blast radius

- **Sim/ledger:** none. No ball/innings/joker/economy/difficulty file is edited; `next_live_cell`
  only chooses *which* tuned cell to play.
- **Cross-session save:** preserved. `to_state` now carries the real tour (it already had the
  field); resume reads it. The existing resume integration test must stay green.
- **The one behavioural change to the existing live path:** the boot seed now varies with
  `seasons_played` (was constant). A brand-new career (`seasons_played == 0`) is byte-identical to
  today; only *subsequent* seasons differ (which is the whole point).

## 9. Deferred (explicitly out of scope)

- **Offer-choice screen** (Model A) — player picks cross-up / stay / which team, with a design
  brief. Its own rung.
- **Down-Level offers / optional Premier trophy chase** in the live loop — the rush model skips
  them; the headless career still models them.
- **Affinity performance bonus**, mid-season offers — unchanged, still deferred (career-loop spec §4).
- **Hi-fi Hall of Fame hand-off polish** — the complete→HoF route is wired but HoF itself isn't
  re-touched here.

## 10. Decisions log

- **DLC1** Climb model = **B (rush-climb, auto-cross)**. Nico delegated; recorded as the AFK default.
- **DLC2** "Beat" = top-3 finish (`SeasonResult.beat`), identical to headless.
- **DLC3** Next cell = lowest unbeaten-unlocked tour ≤ `READINESS_TOUR` at current Level; else cross
  up (non-top) / Premier (top).
- **DLC4** Auto-cross via `generate_offers(state, beat, rng)` + accept the cross-up offer;
  deterministic rng (`play.seed() + 7`).
- **DLC5** Premier (7) optional at Club/City, required at Province to complete.
- **DLC6** Career persisted on the live path; boot seed = `BOOT_SEED + seasons_played`.
- **DLC7** Career-complete → `LifecycleManager.win_out()` → Hall of Fame.
- **DLC8** Outcome screen re-skinned in-house to the design language (no brief); offer-choice UI deferred.
- **DLC9** Transition logic = pure statics on `CareerResolver` + read helper on `CareerState`.
- **DLC10** Not-beaten season replays the same cell with a fresh seed; `record_outcome(beat=false)`
  is a grid no-op → no softlock.
