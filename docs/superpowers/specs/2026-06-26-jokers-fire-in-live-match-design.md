# Jokers fire in the live match — design (Shop-in-the-live-loop, Rung 1)

**Date:** 2026-06-26
**Rung:** Theme 2/4 — Shop-in-the-live-loop, **Rung 1 of 2** (foundation).
**Branch (planned):** `jokers-fire-live-match`
**Status:** design approved (Nico: "go ahead"). AFK rung.

---

## 1. Plain-English problem

The shop sells **jokers** (Balatro-style modifiers), and the headless career *simulation*
feeds the player's owned-joker effects into its matches so they fire as priced. But the
**live interactive match the player actually plays does not** — `MatchSession._resim` calls
`MatchResolver.simulate_match_teams(...)` with an empty `jokers` list (`[]`) and a `null`
`field_plan`. So in the live loop, owned jokers do nothing.

This rung threads the player's joker effects into the live match path so they fire faithfully —
the prerequisite for the Kit Room shop (Rung 2): a store that sells jokers is pointless until
jokers work in the matches you play.

## 2. Goal / success criteria

- A player's owned-joker effects **fire in the live interactive match**, identical to a direct
  `simulate_match_teams` call with the same effects.
- **Empty effects = byte-identical** to the current live match (no regression; the whole live
  loop, careers, tests stay green).
- A real **end-to-end hook**: a joker set as the career carry-over fires in live matches.
- **Zero sim/tuning/ledger risk** — no joker/economy/ball/innings math is touched; this only
  routes existing `JokerEffect` rows into the live path that currently drops them.

## 3. The plumbing (the `simulate_match_teams` mapping)

`simulate_match_teams(player_attrs, player_team, opp_team, tour, tuning, itun, rng,
player_intent_plan, player_bowling_plan, **jokers**, **field_plan**, player_bowl_intent_plan,
opp_intent_plan, boost_plan, drs_policy, …)`.

Today `MatchSession._resim` passes `jokers = []` and `field_plan = null` (positions 10–11).
This rung fills them from the player's owned effects.

### 3.1 `MatchSession`

- `start(attrs, team, opp, tour, seed, force_player_bats_first := -1, tuning := null,
  itun := null, opp_spec := null, player_effects: Array = [])` — new **trailing optional**
  param so every existing caller (tests, previews, the standalone path) is unchanged.
- Store `_player_effects: Array = []`.
- In `_resim`, when `_player_effects` is non-empty:
  - `jokers` slot ← `_player_effects`.
  - `field_plan` slot ← `ShopResolver.plans_for(_player_effects)["field"]` (the modal field mode
    the gated jokers want — exactly how the headless career derives it, CF3).
  - **Boost stays human-controlled** — the existing `boost` (built from the player's `_presses`)
    is passed unchanged. A boost-role joker fires only when the human presses Boost. We do **not**
    OR-in `plans_for`'s auto-`[1,10,16]` schedule (DLF-BOOST below).
  - When `_player_effects` is empty: `plans_for([])` ⇒ `{field: null, boost: null}` ⇒ `jokers []`
    + `field_plan null` ⇒ **byte-identical to today** (the guard).

### 3.2 `SeasonPlay`

- Hold `_player_effects: Array = []`; `set_player_jokers(effects: Array)` setter.
- `make_session()` passes `_player_effects` as the trailing `MatchSession.start` arg (both the
  league and playoff branches).
- `replay()` / `from_state()` path: effects are derived from the career (carry-over), not the
  decision log, so resume is unaffected — `set_player_jokers` is re-applied by the hub on boot.
  (Effects are deterministic state, not a decision, so they don't belong in the decision log.)

### 3.3 `season_hub` (the carry-over bridge)

- In `set_play()` (the single funnel both `boot` and `_show_live_hub` pass through), after binding
  the play, seed effects from the persisted carry-over:
  `play.set_player_jokers(JokerCatalog.effects_of_ids([career.carryover_joker_id]) if
  career.carryover_joker_id != "" else [])`.
- `carryover_joker_id` is `""` until Rung 2's shop sets it, so live play stays empty/byte-identical
  today; the wire lights up the moment the shop exists.

## 4. Why faithful to the headless path

The headless career runs `SeasonResolver.simulate_season(..., ShopResolver.loadout_effects(shop),
hook)` and the hook returns `loadout_effects` after each visit; gated jokers get their field via
`plans_for`. The live path now does the same two things (effects + `plans_for(effects).field`) per
match, so a live match with effects X equals a `simulate_match_teams` call with `jokers = X,
field_plan = plans_for(X).field` — pinned by a test (§6).

## 5. Decisions log

- **DLF1** New control enters as a **trailing optional** `player_effects` on `MatchSession.start`
  + a `SeasonPlay.set_player_jokers` setter — every existing caller is byte-identical.
- **DLF2** Field plan for gated jokers is derived via `ShopResolver.plans_for(effects).field` (reuse
  the headless derivation; do not invent a new one).
- **DLF-BOOST** Live boost is **human-controlled**: boost-role jokers fire only when the player
  presses Boost; we do **not** inject `plans_for`'s auto `[1,10,16]` schedule. Rationale: Boost is
  the player's live lever (ADR 0005); auto-pressing would remove the decision. Consequence: a
  boost-role joker's realized strength in live play depends on the player using Boost — correct for a
  live game, a slight divergence from the headless pricing assumption (noted, not a balance change).
- **DLF3** Effects are seeded from `CareerState.carryover_joker_id` in `season_hub.set_play` — the
  bridge to Rung 2; empty today ⇒ byte-identical.
- **DLF4** Effects are **not** persisted in the live-season decision log — they are derived from the
  career each boot (deterministic state, not a player decision), so cross-session resume is unchanged.

## 6. Testing (test-first)

Test joker: **`block_the_shine`** (`JokerCatalog`) — BATTING / WICKET mult **0.90**, any intent,
balls 1–18, **ungated** (no `field_req`, no `boost_role`). An always-on early-innings survival buff:
fewer dismissals ⇒ a reliably higher batting total, with **no field/boost dependency** — so it
isolates "the joker fired" from the field-plan and boost wiring.

- **Empty guard (deterministic):** `MatchSession.start(…, player_effects = [])` is **byte-identical**
  to the no-arg `MatchSession.start(…)` on a fixed seed/teams/tour — same final scores + winner.
- **It fires (directional sweep):** over a small seed set (e.g. 20 seeds, fixed teams/tour), the
  **summed player batting total** with `player_effects = [block_the_shine effect]` is **strictly
  greater** than with `[]`. Proves the effect flows through the real joker code path.
- **SeasonPlay threading:** `set_player_jokers([block_the_shine effect])` then play the league
  fixtures — the summed player batting total exceeds a no-jokers `SeasonPlay` on the same seed
  (effects reach the live driver's matches).
- **Hub bridge:** `boot()` with `career.carryover_joker_id = "block_the_shine"` → `live_play()` has
  non-empty player effects (and its first `make_session()` result differs from a `""`-carry-over
  boot on the same seed). Proves the carry-over wire.

Effects come from `JokerCatalog.effects_of_ids(["block_the_shine"])` in tests.

Run headless per CLAUDE.md (`--import` once, then the GUT cmdln; judge red by the parse-error skip,
green by the count climbing + `All tests passed`). Editor must be quit; only one Godot process.

## 7. Blast radius / non-goals

- **No shop, no UI, no economy** — that is Rung 2 (Kit Room in the live season).
- **No tuning/ledger change** — jokers/prices/env/build/pay untouched; this is pure routing.
- **No new RNG draws** — `simulate_match_teams` already consumes `jokers`/`field_plan`; passing
  non-empty values changes outcomes via the existing joker code paths, not via new randomness.

## 8. Deferred to Rung 2

`ShopState` on the live driver, the visit cadence (after matches 3 & 5, pre-semi, pre-final), the
functional Kit Room screen (buy/train/sell/hold/skip) spending real ₸, and the season-end carry-over
election. The Kit Room **hi-fi skin** (design brief) is a later presentation rung — no mockup exists.
