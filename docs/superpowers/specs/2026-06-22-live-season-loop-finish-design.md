# Finish the Live Season Loop — design (2026-06-22)

**Status:** AFK rung. Design decisions recorded here (Nico pre-authorised AFK execution:
"you choose and continue AFK as long as possible until you require a real decision or
verification of output"). Built slice-by-slice, one PR each.

## Problem

The **career loop** (`CareerResolver.play_season`) already plays a full Season
non-interactively: league → top-4 knockout playoffs → outcome → ₸ pay banked →
`CareerState` saved. The **live loop** (`SeasonPlay`, driven by `scenes/main.gd`
`_play_next`/`_commit_and_return`) lets you play the **7 league fixtures
interactively** (Boost / DRS / Key Moments) — but then **stops dead** at
`league_done()`:

- no playoffs (`live_season()` returns a league-only `SeasonResult`);
- no outcome screen (you never see where you finished);
- no ₸ banked from live play (the career path banks, the live path doesn't);
- no cross-session save (quit mid-season = lose the season).

"Finish the live season loop" = bring the live path up to parity, with the
player's **knockout** matches played interactively.

## Scope — four slices (one PR each)

Built in this order (pure logic first, the UI slice last so there is a single
eyeball/verification handoff):

| # | Slice | Kind | Needs eyeball? |
|---|-------|------|----------------|
| 1 | Live playoffs in `SeasonPlay` | pure domain logic | no |
| 3 | ₸ pay banking on the live path | pure domain logic | no |
| 4 | Cross-session save of the live `SeasonPlay` | service/persistence | no |
| 2 | UI wiring (hub PLAY-playoff tile + outcome) | scene/UI | **yes** |

(Numbered by the roadmap bundle "playoffs + outcome + ₸ pay + cross-session save";
implemented 1 → 3 → 4 → 2.)

---

## Slice 1 — Live playoffs in `SeasonPlay` (this PR)

Extend `SeasonPlay` with a **phase state machine** and a playoff bracket that
mirrors `SeasonResolver` exactly, but plays the **Player's** knockouts
interactively while auto-resolving the rest.

### Phases

`phase()` → `"league"` | `"playoffs"` | `"done"`.

- **league** — the existing 7 fixtures (unchanged). When `played_count() == 7`,
  the league phase is over.
- On league completion, **seed the bracket** from the final standings:
  seeds 1–4 = `standings[0..3].team_index`. SF1 = seed1 v seed4, SF2 = seed2 v
  seed3; Final = the two SF winners; 3rd-place = the two SF losers (identical to
  `SeasonResolver.simulate_season`).
- **playoffs** — only entered if the **Player finished top-4**
  (`live_league().made_playoffs`). The Player plays exactly **two** interactive
  knockouts: their semi-final, then — depending on the SF result — the **Final**
  (if they won) or the **3rd-place playoff** (if they lost). The other semi and
  the other championship match **auto-resolve** (derived `simulate_match` on the
  held `_bat`/`_bowl` strengths, the same path as the league's AI fixtures).
- **done** — the whole bracket is resolved.

If the Player finished **5th–8th**: there is nothing to play. On league
completion the entire bracket auto-resolves immediately and the phase goes
straight to **done** (player_final_position = league position 5–8).

### New / changed API (all additive; league behaviour byte-identical)

- `phase() -> String` — `"league"` / `"playoffs"` / `"done"`.
- `season_done() -> bool` — true once the bracket is fully resolved.
- `next_player_opponent() -> Dictionary` — extended. In playoffs returns
  `{name, team_index, stage}` where `stage ∈ {"semi","final","third"}` for the
  Player's pending knockout; `{}` when none is pending (not in playoffs, or the
  bracket has auto-resolved).
- `make_session() -> MatchSession` — extended. In playoffs builds a session for
  the Player vs the current bracket opponent, with a playoff-specific derived
  seed (`_seed + 200 + stage_offset`) so each knockout diverges only on its own
  decisions. Uses the same `_opp_spec` brain floor as the league.
- `commit_player_result(MatchResult)` — extended. In playoffs records the
  knockout, advances the bracket, and auto-resolves any now-determined
  non-player match.
- `season_result() -> SeasonResult` — the **complete** result once
  `season_done()`: `league`, `semi1`, `semi2`, `final_match`, `third_place`,
  `final_order` (8 indices 1st..8th), `player_final_position`, `beat`,
  `won_final`. (`live_season()` stays the league-only view used by the hub
  during the league phase; this is the post-playoffs outcome read-model.)

### Determinism

- Non-player knockouts auto-resolve on a fresh RNG seeded `_seed + 2` (a stream
  distinct from the strength draw `_seed` and the AI-fixture stream `_seed + 1`),
  in fixed bracket order.
- The Player's interactive knockouts use derived per-stage seeds; same seed +
  same decisions ⇒ same result.
- This live bracket is **NOT** byte-identical to `SeasonResolver.simulate_season`
  (the Player plays interactively, and the RNG streams differ) — it is a coherent,
  deterministic-given-decisions bracket with the **same structure** and the same
  seeding/advancement rules. That is the contract; byte-parity is neither
  required nor claimed.

### Tie rule

A tied knockout is decided by **better seed (lower league position) advances** —
identical to `SeasonResolver._knockout`.

### What this slice does NOT touch

- No `scenes/` changes (UI wiring is Slice 2).
- No ₸ banking (Slice 3), no save (Slice 4).
- No tuning / ledger files. Env / jokers / build / pay math untouched by
  construction (this is scheduling, not cricket).

### Tests (`tests/unit/test_season_play.gd`, extending the existing file)

1. Player **top-4** → `phase()` becomes `"playoffs"` after the 7th league game;
   `next_player_opponent().stage == "semi"`.
2. Player wins SF → next stage is `"final"`; loses SF → next stage is `"third"`.
3. After both player knockouts committed → `season_done()`, `phase()=="done"`.
4. Player **out of top-4** → after the 7th game the bracket auto-resolves,
   `season_done()` immediately, `next_player_opponent() == {}`,
   `player_final_position` in 5..8.
5. `season_result()` completeness — all four knockout `MatchResult`s present,
   `final_order` has 8 distinct indices, `beat`/`won_final` consistent with
   `player_final_position`.
6. Determinism — two `SeasonPlay`s, same seed + same committed results ⇒ identical
   `final_order`.
7. League phase regression — the existing 8 league tests still pass unchanged.

---

## Slice 3 — ₸ pay banking (next PR, pure logic)

Bank match pay as live matches commit, mirroring `CareerResolver._settle_matches`:
`Economy.match_pay(result, stars, etun)["total"]` + `Economy.match_win_prize` on a
win, plus the playoff/Final/grand-final/Season prizes
(`Economy.playoff_win_bonus` / `final_appearance_bonus` / `grand_final_prize` /
`season_prizes`) once the season is done. Accrued into `Player.tons_balance`.
SeasonPlay gains an optional `EconomyTuning` + `stars_at_play` and a running pay
tally exposed for the outcome screen. Idempotent settlement (slice from a
`settled_count`).

## Slice 4 — Cross-session save (next PR, persistence)

Persist the in-progress live season so a quit mid-season resumes. A serialisable
`LiveSeasonState` resource (seed, committed player results, phase, bracket
progress, pay tally) saved via `SaveManager` (`user://live_season.tres`), and a
`SeasonPlay.resume(state)` / `to_state()` pair. Reconstruct held strengths +
AI fixtures deterministically from the seed (they are pure functions of it), so
only the player-driven divergence needs serialising.

## Slice 2 — UI wiring (final PR, needs eyeball)

After the league, the hub surfaces a PLAY tile for the Player's pending playoff
match (semi → final/third), routed through the existing interactive match scene;
on `season_done()` an outcome surfaces (where you finished + ₸ banked). Launch the
real app for Nico to feel. (Low-fi acceptable; a hi-fi outcome screen is a later
presentation rung.)

---

## Decisions log (AFK defaults)

- **DL1** Player plays only their own knockouts; the rest auto-resolve on the
  held strengths (the league's AI path). Rationale: keeps the live bracket cheap
  and consistent with how the league already treats AI fixtures.
- **DL2** Out-of-top-4 ⇒ instant full auto-resolve, phase `"done"`. No empty
  "playoffs" the player can't act in.
- **DL3** Playoff RNG on `_seed + 2`, distinct from strength (`_seed`) and AI
  fixtures (`_seed + 1`). Per-stage player seeds `_seed + 200 + offset`.
- **DL4** No byte-parity with `SeasonResolver` claimed or required — the live
  path is interactive. Same *structure* (seeding, bracket, tie rule) is the
  contract.
- **DL5** Slice order 1 → 3 → 4 → 2: logic slices (autonomous) before the UI
  slice (needs Nico's eyeball), so there's one verification handoff, not many.
