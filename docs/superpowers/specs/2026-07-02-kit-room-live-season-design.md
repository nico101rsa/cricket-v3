# The Kit Room in the live season — design (Shop-in-the-live-loop, Rung 2)

**Date:** 2026-07-02
**Rung:** Shop-in-the-live-loop, **Rung 2 of 2** (Rung 1 = jokers fire in the live match, PR #102).
**Branch (planned):** `kit-room-live-season`
**Status:** design (AFK rung — Nico: "select the most AFK path and proceed"; scope split + in-house
functional UI approved 2026-06-26). Decisions recorded below.

---

## 1. Plain-English problem

The Kit Room (the Balatro-style shop: buy jokers, train attributes) exists **only in the headless
career sim** — `CareerResolver.play_season` drives it via a policy callback. The **live season the
player actually plays has no shop**: no visits, no buying, no carry-over election. Rung 1 made
jokers *fire* in live matches; this rung makes them *purchasable* there. After this, the core
gameplay loop is mechanically complete: play → earn ₸ → spend in the Kit Room → jokers change your
matches → climb.

## 2. Goal / success criteria

- The live season offers the **canon 5-visit cadence** (measured balance, shop rung DK1–DK15):
  **V0** season start (carry-over enters free + starter pick of 3 Commons) · **V1** after your 3rd
  match · **V2** after your 5th · **V3** before your semi-final · **V4** before your final.
- A functional, in-house **Kit Room screen** (buy / sell / hold / train / skip) spending real
  `Player.tons_balance` at real `Economy.joker_price` prices.
- **Season-end carry-over election** (pick one owned joker to keep) → sets
  `CareerState.carryover_joker_id`, which Rung 1 already wires to fire next season.
- Purchases/training **immediately affect subsequent live matches** (jokers via Rung 1's
  `set_player_jokers`; attrs via the session's attributes).
- **Cross-session save keeps working losslessly** — quit mid-season with bought jokers and trained
  attrs, resume byte-identical.
- **Shop off = byte-identical** (a `SeasonPlay` that never calls `enable_shop` is untouched —
  the whole existing suite stays green).
- Zero sim/tuning/ledger risk: all shop maths is the existing `ShopResolver`/`Economy` — no dial
  moves; this rung is scheduling + persistence + one screen.

## 3. Architecture

### 3.1 `SeasonPlay` — the shop lives on the live driver

New state: `_shop: ShopState`, `_shop_player: Player`, `_setun: EconomyTuning`,
`_shop_level/_shop_tour: int`, `_visits_mask: int` (bit v set = visit v consumed),
`_paid_mask: int` (bit v set = the visit's one paid action used), `_shop_log: Array`.

- **`enable_shop(player, etun, level, tour, carryover_id)`** — *rebind + init-once*: every call
  updates `_shop_player` (the hub reloads the Player after each match, so object identity changes —
  DK2-9), but the `ShopState` initializes only on the first call: carry-over joker enters **free**
  (`paid_prices[id] = 0`), effects refresh. Replaces Rung 1's carry-over seeding line in the hub
  (the carry-over now lives inside the shop, same as headless V0).
- **`pending_shop_visit() -> Dictionary`** — `{}` or `{"kind": "starter", "visit": 0, "offer":
  [3 common ids]}` / `{"kind": "visit", "visit": 1..4, "offer": roll_offer dict}`. Schedule
  (DK2-1): v0 while `played_count() == 0` · v1 at `played_count() >= 3` · v2 at `>= 5` ·
  v3 when `phase() == "playoffs"` and the pending stage is `semi` · v4 when it is `final`
  (no visit before the 3rd-place match — canon V4 is pre-championship). Each visit's offer is
  rolled on a **fresh RNG seeded `_seed + 9000 + visit`** (DK2-2) — deterministic and resume-safe
  with no stream state to persist; the held-slot semantics come from `ShopState` as in headless.
- **`apply_shop_action(act: Dictionary)`** — per-tap actions from the screen, enforcing canon
  **one paid action per visit** (DK7 → DK2-3): `{"kind": "pick", "id"}` (starter, free, consumes
  v0) · `{"kind": "buy", "id", "replace"}` / `{"kind": "train", "attr"}` (paid — first success
  sets the visit's `_paid_mask` bit; further paid actions refuse) · `{"kind": "sell", "id"}` /
  `{"kind": "hold", "id"}` (free meta-actions, any number) · `{"kind": "skip"}` (consumes the
  visit). Buy/train/sell delegate to the existing `ShopResolver` statics (which push_warning +
  no-op on illegal input); every successful action refreshes `_player_effects` from
  `ShopResolver.loadout_effects(_shop)` so the next `make_session` sees it.
- **`shop()` / `shop_enabled()` / `shop_log()`** accessors; `owned_ids` for the UI/carry-over.

### 3.2 Persistence (the replay-context fix)

Shop actions change the player's **jokers and attributes mid-season**, so a replayed match must run
with the *context it was originally played in* — replaying with the final loadout would diverge.
(This also fixes a **latent Rung-1 bug**: a carry-over joker + mid-season quit replayed effect-less.)

- **`commit_player_result` records context per entry** (DK2-4): each decisions entry gains
  `"jokers": owned ids at commit` and `"attrs": [power, composure, attack, control]` (4 floats).
- **`replay()`** applies per-entry context before each session: `set_player_jokers(
  JokerCatalog.effects_of_ids(entry.jokers))` + rebuilds `_attrs` from `entry.attrs`; missing keys
  (old saves) fall back to current values. After the loop the *final* attrs/effects are restored
  from the live state below.
- **`LiveSeasonState` v2** (all `@export`): `shop_enabled: bool`, `shop_owned: Array`,
  `shop_paid: Dictionary`, `shop_held: String`, `shop_visits_mask: int`, `shop_paid_mask: int`
  (+ the decisions entries above). `to_state` packs them; `from_state` restores the `ShopState` +
  masks and re-derives `_player_effects` — then the hub's `enable_shop` call is a pure rebind.
- Quitting **on** the Kit Room screen needs no extra state: the pending visit re-derives from
  `played_count()`/phase/masks, and the offer re-rolls identically (per-visit seed).
- `Player.tons_balance`/attributes remain the Player save's job (unchanged); `restore_pay_tally`
  still prevents double-banking.

### 3.3 `main.gd` + `season_hub` routing

- `season_hub.set_play`: replace the Rung-1 `set_player_jokers(carry-over)` line with
  `play.enable_shop(player, EconomyTuning.new(), _cell_level, _cell_tour,
  career.carryover_joker_id)`.
- `main`: a `_show_kit_room(play, career, hub_next: Callable)` pushes the screen; on `done` it
  saves (`save_player` — balance/attrs moved; `save_live_season` — shop state) and routes on.
  Check `pending_shop_visit()` at the three gates: **after `_push_hub` boots** (V0), **after
  `_commit_and_return` commits** (V1–V4, before re-showing the hub), and as a guard in
  `_play_next` (pending visit → Kit Room instead of the match).
- **Carry-over election** (DK2-6): on `season_done()`, if the shop is enabled and owns jokers,
  push the Kit Room in `carryover` mode **before** the season-end advance; the pick writes
  `career.carryover_joker_id` (or `""`), then the existing advance/persist/outcome flow runs
  (extracted to `_finish_live_season(play, career)`).

### 3.4 The Kit Room screen (in-house functional, no mockup exists)

`scenes/kit_room/kit_room.{gd,tscn}` — code-built like the Outcome screen, on
`Palette`/`UIStyle`/`Fonts`, **no emoji** (Barlow tofu). One scene, three modes via
`set_visit(play, mode, offer)`:

- **Header**: kicker `KIT ROOM · <visit label>` + live `₸ balance` (updates per action).
- **starter**: 3 Common tiles (name + rarity + FREE) — tap to pick; `Skip` CTA.
- **visit**: offer card(s) (name, rarity, price; absent rarity slots hidden) with `BUY` (disabled
  when unaffordable / paid action used) + `HOLD`; owned bench rows with `SELL ₸n` (refund =
  half of *paid*, so free jokers show ₸0); 4 train rows (`POWER 42 → 43 · ₸n`, disabled at cap
  60 / unaffordable / paid action used); `Continue` CTA (= skip if nothing done).
- **carryover**: owned rows, tap one to elect (or `Carry nothing`); emits `carryover_elected(id)`.
- Signal `done()`; `continue`/pick semantics call `SeasonPlay.apply_shop_action` directly.

## 4. Decisions log (DK2-x)

- **DK2-1** Live visit points mirror canon exactly: V0 start / V1 after match 3 / V2 after match 5 /
  V3 pre-semi / V4 pre-final; none before the 3rd-place match. Consumed via bitmask.
- **DK2-2** Per-visit fresh RNG `_seed + 9000 + visit` — deterministic offers, resume-safe, no
  collision with existing streams (+1 AI, +2 playoffs, +7 advance, +100/+200 fixtures).
- **DK2-3** One paid action (buy OR train) per visit, enforced by `_paid_mask`; sell/hold free;
  skip allowed — canon DK7 semantics as per-tap actions instead of the headless batch.
- **DK2-4** Replay context per decisions entry (`jokers` + `attrs`) — lossless resume under
  mid-season shopping; fixes the latent Rung-1 carry-over replay divergence.
- **DK2-5** `enable_shop` = rebind + init-once (idempotent across the hub's per-match rebinds).
- **DK2-6** Carry-over election happens on the Kit Room screen at season end, before the career
  advance; writing `career.carryover_joker_id` precedes `save_career`.
- **DK2-7** UI is in-house functional (approved 2026-06-26); the hi-fi Kit Room skin is a later
  design-brief rung. The screen enforces affordability/caps but all money maths stays in
  `ShopResolver`/`Economy`.
- **DK2-8** Held jokers expire with the season (canon DK15) — `ShopState` dies with `SeasonPlay`;
  only the elected carry-over survives.
- **DK2-9** `SeasonPlay._attrs` is rebound by `enable_shop` so post-save/load Player objects (new
  `Attributes` instances) keep training visible to future matches.
- **DK2-10** Hub jokers-bench wiring to the live `ShopState` is attempted only if the `SeasonView`
  seam is trivially small at build time; otherwise deferred to the hi-fi rung (logged either way).

## 5. Testing (test-first, headless)

- **Scheduling**: fresh enabled play → pending v0; pick consumes it; pending empty until 3 commits →
  v1; skip consumes; v2 at 5; strong-team playoffs → v3 at stage `semi`, v4 at stage `final`;
  missed playoffs → no v3/v4. Offer determinism: same play state → identical repeated offers.
- **Actions**: buy deducts the offer price + adds to `owned_ids` + subsequent `make_session`
  result differs (effects live); one-paid-action: buy then train refuses (and vice versa); sell
  refunds half of paid (0 for free); hold survives to the next visit's offer slot; train +1 within
  cap and only with funds.
- **Persistence (the critical pin)**: play 3 matches → V1 buy `block_the_shine` + train power →
  play 2 more → `to_state`/`from_state` round-trip → resumed `played_count`, standings, owned ids,
  balance-affecting state and the **next** match result all equal the uninterrupted run
  (byte-identical).
- **Off-guard**: no `enable_shop` → `pending_shop_visit()` always `{}`, decisions entries carry no
  regression (whole existing suite green).
- **Scene**: Kit Room renders each mode (visible, `size.y > 0`), buy button disabled when
  unaffordable, `done` emits, no emoji.
- **Hub/main**: `set_play` enables the shop (pending v0 on a fresh boot).

## 6. Blast radius / non-goals

- No tuning/pricing/ledger change; `ShopResolver`/`Economy`/`JokerCatalog` untouched.
- No hi-fi skin, no design brief (later rung); no headless-career changes (`play_season` untouched).
- Boost-role jokers still fire only on human Boost presses (Rung 1 DLF-BOOST).

## 7. Deferred

Kit Room hi-fi (design brief) · hub bench live-wiring if the seam isn't trivial (DK2-10) · the
Offers/"how to advance" screen (next thread in Nico's basic-gameplay order).
