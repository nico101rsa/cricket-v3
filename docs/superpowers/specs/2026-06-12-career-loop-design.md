# Career loop — design (Theme-2 rung)

**Date:** 2026-06-12 · **Status:** approved (AFK defaults recorded per the 2026-06-07 ruling)
**Builds on:** `SeasonResolver` (PR #13), `DifficultyLadder`/`TourSpec`/`OpponentBrain` (E3, PR #47),
`Economy.match_pay` (7c-D, PR #37), `Team.mutate_stars` (7b-2b, built never wired), `SaveManager`.
**Canon:** CONTEXT.md (Career / Tour / Level / Beat-Win / Offer / Tons / Affinity / Seasons played),
ADR 0002 (roguelite career), ADR 0009 (Team durability).

## 1. What this rung is

The **multi-Season Career loop**, headless and domain-pure: a `CareerState` you can start,
play Seasons against (each Season = one Career-grid cell, simulated atomically by
`SeasonResolver` with the cell's `DifficultyLadder` difficulty + brain), and persist.
Beating cells unlocks the grid, winning Premium Finals wins Levels, ₸ flows into the
Player's bank per match, stars mutate at every rollover, Offers move the Player between
Teams/Levels, and winning Province's Premium completes the Career.

This is the prerequisite for **E4 (player-AI career runs)** — E4 needs exactly this
headless API. **No UI ships this rung** (the Career Grid / Offer / Season hub screens are
designed in `docs/mockups/around-the-match-v1.html` and build in a later Theme-5/6 rung).

Glossary reminders (CONTEXT.md): **beat** a Season = finish top 3 (unlocks grid
progression); **win a Level** = win The Final of that Level's Premium tour; **₸ (Tons)** =
the Career-scoped currency; **Affinity** = tenure with the current Team.

## 2. Decisions (DC1–DC15, AFK defaults)

- **DC1 — Domain-first scope.** Pure domain (`scripts/domain/career_resolver.gd` static
  funcs) + data (`scripts/data/career_state.gd`, `scripts/data/offer.gd`) + persistence
  (`SaveManager`) + an eyeball oracle (`tools/career_preview.gd` → viz). No scenes.
- **DC2 — Seasons are atomic.** A Season is one `SeasonResolver.simulate_season` call.
  The canonical **mid-Season Offer (after Match 4) is deferred** to the playable-season
  rung, where Seasons run match-by-match anyway (Shop cadence, Key Moments). End-of-Season
  Offers only here. Recorded so it isn't forgotten: the Offer screen rung must add it.
- **DC3 — DL11 call: League/Season fidelity stays scalar.** E3 left "upgrade Season play
  to the roster+factor path" as this rung's call. **Deferred to its own rung** ("Season
  fidelity upgrade"): doing it here would move the measured 24-cell beat surface, the env
  peg, and possibly joker bands — a sim-fidelity rung's job with its own re-anchor budget.
  This rung is meta-loop only; **zero sim-math changes, zero oracle ripple.**
- **DC4 — Grid model.** 3 Levels × 8 Tours = 24 cells, each `locked / unlocked / beaten`
  (beaten implies unlocked). Start: only Club Practise (0,0) unlocked. **Beating (L,T)
  unlocks (L,T+1) (up) and (L+1,T) (across)** — CONTEXT.md "opens the cell above and
  across". Cells stay replayable forever (retry on fail; pay-farming is legit canon).
  **Province Premium (2,7) additionally requires Club's AND City's Premium tours won**
  (the ordered endgame gate). Winning it completes the Career.
- **DC5 — Where you play.** The Player's current Team fixes the **Level**; each Season the
  caller picks any **unlocked cell at that Level** (`playable_cells()`). Levels change
  only by accepting a cross-Level Offer (canon).
- **DC6 — Real rosters, persistent identity.** `CareerState` holds **24 `Team`s** (8 per
  Level, flat array, index = level×8+slot) created at Career start with a fixed star
  ladder per Level: **[1.5, 2.0, 2.5, 3.0, 3.0, 3.5, 4.0, 4.5]** (mean 3.0 — matches the
  E3 neutral field's centre). Team names from a new static 24-name bank (SA-flavoured
  placeholders incl. the canon-cited "Karoo Kings"; the Country master-data axis lands in
  a later data rung). A Season's opponents = the 7 other Teams at the current Level.
  The ladder + names are strawman dials.
- **DC7 — Starting Team pick.** `start_career(picked_index)` — the pick is validated to be
  one of the **3 lowest-★ Club Teams** (canon: rookie underdog choice).
- **DC8 — Star mutation wiring.** At every Season rollover, **all 24 Teams** run
  `Team.mutate_stars(rng)` (ADR 0009), *before* Offers are generated — so an Offer shows
  the ★ the Team will actually have next Season (Offers stay a readable signal). The
  current-Season "form delta" display is a UI-rung nicety, not stored here.
- **DC9 — ₸ income.** Per Season, the Player banks `Economy.match_pay` for **every match
  they played** (the 7 league `player_matches` + any playoff match where
  `player_line()` is non-empty), into `Player.tons_balance`. Star-scaled base pay
  (stronger Teams pay less) comes free from the existing `star_pay_slope`.
- **DC10 — Team winning bonus (ideas cluster 2 → IN).** New pure
  `Economy.win_bonus(level, tuning)` = `win_bonus_base + win_bonus_level_step × level`,
  paid per Player-team **win** (league + playoffs). Strawman dials on `EconomyTuning`:
  base **₸5**, step **₸5** (Club 5 / City 10 / Province 15 per win — ~₸20–45/Season at
  Club rates, deliberately small next to the ~₸470/Season match-pay income so build-pay
  equality is untouched; it's team-level, build-independent). `match_pay` itself is
  **unchanged** → `sweep_economy.gd` and all pay numbers hold (DL9 discipline).
- **DC11 — Offers (end-of-Season, choose-from-3 + stay).** Composition default:
  - **Cross-Level guarantee (canon):** if the Player just **beat** a Level-N cell and a
    Level-(N+1) cell is unlocked → the set contains **at least one** Level-(N+1) Team.
    If the higher Level is unlocked but this Season wasn't a fresh beat → a Level-(N+1)
    Team appears with **P = 0.5** (strawman dial).
  - Remaining slots: distinct random Teams from the **current Level**, excluding the
    current Team. "Offer quality scales with Player strength / recent finishes" is
    **deferred** (a tuning pass once E4 can measure what offer-following does).
  - An `Offer` = {team_index, level, stars snapshot}. **Accept** → `current_team_index`
    moves, **Affinity resets to 0**. **Stay** → Affinity +1.
- **DC12 — Affinity = counter only this rung.** `Player.affinity` (field exists) counts
  consecutive Seasons with the current Team; reset on accept, +1 on stay. The canon
  **performance bonus is deferred to a balance rung** — it's a sim buff that must be
  harness-measured (band-checked against build equality + the joker floor) before it
  ships; wiring an unmeasured buff would violate the project's balance discipline.
- **DC13 — Difficulty per cell.** Every Season threads
  `DifficultyLadder.spec_for(level, tour)` as `opp_spec` (tour distribution from
  `TourSpec.make_tour()`, brain on Player-facing fixtures per DL5). The adaptive brain
  becoming live in real play keeps the joker-floor question **oracle-side only** (DL9):
  no sweep defaults change this rung.
- **DC14 — Persistence + lifecycle.** `CareerState extends Resource`, saved at
  `user://career.tres` (`SaveManager.has_career/save_career/load_career/clear_career`).
  `LifecycleManager.end_career` reads the real `seasons_played` from the saved
  CareerState (replacing `_PLACEHOLDER_SEASONS`) and clears the career save alongside
  the player save. Career completion routes through the existing `win_out()`.
- **DC15 — Eyeball oracle.** `tools/career_preview.gd`: N full Careers under a fixed
  naive policy — play the lowest unbeaten unlocked Tour at the current Level (else the
  Premium tour again, chasing the Level win); accept a cross-Level Offer **up** only once
  the current Level is won, and a down-Level Offer never (the naive line never needs one);
  textbook player plans (the `OpponentBrain` TEXTBOOK literals); and **naive ₸ spending**
  (round-robin +1 attribute upgrades at `Economy.attr_upgrade_cost` while affordable,
  capped at 60/attribute) so growth — the thing that closes the E3 "fresh build reads 15%
  at Province Premium" gap — actually happens and completion is measurable. Outputs
  seasons-played distribution to completion, per-cell visit/beat counts, ₸ bank trajectory
  → `docs/mockups/career-loop-v1.html`. This is an *eyeball*, not a policy search —
  optimal career play is **E4's** job.
- **DC16 — Down-Level offers (anti-softlock).** Canon lets the Player climb to Level N+1
  before *winning* Level N (beating any cell is enough for the cross-Level Offer) — but
  the ordered endgame gate (DC4) requires winning every Level's Premium Final. With
  up-only Offers a fast climber could strand above an unwon Level forever. So:
  **whenever the Player's current Level sits above any unwon Level, the offer set always
  contains one Team from the highest unwon lower Level** (deterministic, not a dice
  roll — it doubles as readable UX: "Club still wants you back until you've won it").
  The deferred dropped-player lifeline will ride this same machinery.

## 3. Data shapes

### 3.1 `CareerState` (`scripts/data/career_state.gd`, Resource)

```
teams: Array[Team]            # 24, level-major (level*8 + slot)
current_team_index: int       # 0..23; floor(idx/8) = current Level
cell_status: Array[int]       # 24 × {LOCKED=0, UNLOCKED=1, BEATEN=2}, level-major (level*8 + tour)
level_won: Array[bool]        # 3 — Premium Final won per Level
seasons_played: int           # ticks every Season, beaten or failed (canon)
complete: bool                # Province Premium won
```

Helpers: `current_level()`, `status_of(level, tour)`, `is_unlocked(level, tour)`
(encapsulates the Province-Premium endgame gate), `playable_cells()` → unlocked tours at
the current Level, `roster_of(level)`, `lowest_star_club_indices()` (the 3 starting picks).

### 3.2 `Offer` (`scripts/data/offer.gd`, RefCounted)

`team_index: int`, `level: int`, `stars: float` (snapshot at generation). Pure data.

### 3.3 `CareerResolver` (`scripts/domain/career_resolver.gd`, static, no member state)

```
start_career(picked_club_slot) -> CareerState               # builds 24 teams, unlocks (0,0);
                                                            # deterministic, no rng needed
play_season(state, player, tour_index, tuning, itun, etun, rng,
            intent_plan := null, bowling_plan := null) -> Dictionary
    # {season: SeasonResult, pay: int, wins: int, offers: Array[Offer]}
generate_offers(state, just_beat, rng) -> Array[Offer]      # public for tests + the UI rung
accept_offer(state, player, offer) -> void                  # move team, affinity = 0
stay(state, player) -> void                                 # affinity += 1
```

Grid transitions on the Player's own data live on `CareerState` itself
(`mark_beaten`, `record_outcome(level, tour, beat, won_final)` — the latter owns the
Level-win + completion flags so the transition is unit-testable without forcing a sim
outcome).

`play_season` sequence (one rng, fixed draw order for determinism):
1. Validate `tour_index` is unlocked at the current Level.
2. `spec = DifficultyLadder.spec_for(level, tour_index)`; `tour = spec.make_tour()`.
3. `SeasonResolver.simulate_season(player.attributes, current_team, other_7, tour, …, spec)`.
4. Pay: Σ `Economy.match_pay(m, current_team.stars, etun).total` over the Player's
   played matches + `Economy.win_bonus(level, etun)` per won match → `player.tons_balance`.
5. Grid: `beat` → mark cell BEATEN, unlock (L,T+1) and (L+1,T) where in range.
   `won_final` at Premium (T=7) → `level_won[L] = true`; Province ⇒ `complete = true`.
6. `seasons_played += 1`.
7. Mutate all 24 Teams' stars (DC8).
8. Generate Offers (DC11) — skipped when `complete`.

The caller then calls `accept_offer` / `stay` and saves. Note the Player-team star used
for pay (step 4) is the ★ the Season was *played* at — mutation (step 7) lands after.

## 4. Out of scope (recorded so they don't creep)

- **Mid-Season Offer** (after Match 4) — playable-season rung (DC2).
- **Season roster+factor fidelity** — its own rung (DC3, the DL11 seed).
- **Affinity performance bonus** — balance rung; magnitude must be harness-measured (DC12).
- **Offer playing-time % variant + dropped-player lifeline** (ideas cluster 2) — both hang
  on open design question #1 (participation model, leaning "fixed"); decide there. The
  lifeline's forced down-move reuses the DC16 down-offer machinery.
- **Offer quality scaling with Player strength / recent finishes** — tune once E4 measures.
- **Shop / Jokers / Form inside the Career loop** — the headless loop banks ₸; spending it
  is the Shop (UI rung) and E4 (policy) surface. Jokers are Season-scoped and the
  atomic-Season sim runs joker-less here, exactly like the E3 ladder measured.
- **Country variation, team-name master data** — data rung.
- **UI screens** — Theme-5/6.

## 5. Tests (TDD, inline)

1. **Grid**: fresh state = only (0,0) unlocked; beat unlocks up + across; edges clamp;
   replay allowed; Province-Premium gate needs both lower Premiums won; completion flag.
2. **Start**: 24 teams (8/Level, star ladder, mean 3.0); pick validated to 3 lowest-★ Club
   slots; names non-empty/distinct.
3. **play_season**: determinism (same seed ⇒ same result/pay/offers); seasons_played ticks
   win or lose; pay = Σ match_pay over exactly the Player's matches + win_bonus×wins
   (reconciled against the SeasonResult by hand in the test); bank grows.
4. **Stars**: rollover mutates via the ADR 0009 distribution (seeded — some teams move,
   clamped 0.5–5.0); Offers show post-mutation stars.
5. **Offers**: ≤3 + stay; distinct; never the current Team; cross-Level guarantee fires on
   a fresh beat with the higher cell unlocked; down-Level offer always present while a
   lower Level is unwon (DC16); none once complete.
6. **Accept/stay**: accept moves Team/Level + Affinity 0; stay increments Affinity.
7. **Economy**: `win_bonus` arithmetic per Level; `match_pay` itself untouched
   (existing tests stand — no dial changes).
8. **Persistence**: save → load roundtrip preserves grid + teams + counters;
   `LifecycleManager.end_career` archives the real seasons_played and clears the career.

Suite must climb past **464** and stay green; no existing test edits expected
(pure addition — no sim-math change).

## 6. Acceptance (the eyeball, not a gate)

`career_preview.gd` (N≈100 Careers, naive policy): Careers **complete** (the gate
topology is traversable); seasons-played distribution is plausibly roguelite (tens of
Seasons, not 3 and not 500 — CONTEXT cites "beat the game in 34" as the flavour target);
₸ bank rises across a Career; Province cells visited only after City offers accepted.
Numbers land in the spec §10 findings + the viz, with denominators.
