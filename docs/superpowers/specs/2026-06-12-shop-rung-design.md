# Shop rung — the Kit Room in headless career play

**Date:** 2026-06-12 · **Branch:** `shop-rung` · **Mode:** AFK (defaults recorded here, per the 2026-06-07 ruling)

## 1. What this rung is

The Shop (in-fiction: **Kit Room**) is the last missing economy piece: the place a Player spends banked ₸ on **Jokers** (Season-scoped power) versus **Attribute upgrades** (permanent growth). Everything around it already exists — all 45 jokers are wired into the sim and priced, `Economy.attr_upgrade_cost` works, the Career loop banks ₸ — but there is **no Shop**: career Seasons simulate with an empty joker list, and the preview bot upgrades attributes without any visit cadence. The bank climbs to ~₸97k with nothing to buy (career-loop finding, PR #48).

This rung builds the Shop **headlessly** (engine + career integration + policies + measurement). The Kit Room *screen* builds later against the same resolver.

**Why now (Nico's call, 2026-06-12):** E4 (career-playing AI) needs the full spend decision space — a career AI without jokers-vs-attributes would have to be re-measured after the Shop anyway, and the open claim "jokers buy back the 62-Season grind" is only testable with a Shop.

**Nico's three requirements recorded for E4 (seeded here):**
1. A **joker-only playstyle** must be a runnable policy (buy jokers, never attributes).
2. Career runs must **track how each career ended** (the forced-retirement slot — the mechanic itself is Theme 9, deferred; the tracking lands now).
3. After this rung: **one narrated playthrough** for Nico to react to (how he wants to *see and run* the game).

## 2. Canon being implemented (CONTEXT.md, verbatim cadence)

Up to **5 Shop visits per Season** — fewer if the Player misses the playoffs:

| Visit | When | Notes |
|---|---|---|
| V0 | Season start | **Free starter**: pick 1 Joker from 3 Commons (no ₸ cost) |
| V1 | after Player match 3 | always |
| V2 | after Player match 5 | always |
| V3 | before the semi-final | only if Player finished top 4 |
| V4 | before the championship match (Final or 3rd-place playoff) | only if Player made the semi |

At each **post-Match** visit (V1–V4) the Player may take **one of each** action (zero of any is fine):
- **Buy 1 Joker** from an offer of **1 Common + 1 Rare + 1 Legendary**. Full slots (4) → replacement pick.
- **Upgrade 1 Attribute** (+1 point on the /100 card scale, cap 60 — career-pacing DP4).
- **Sell 1 owned Joker** for a partial refund (`sell_refund_frac` = 0.5 of the price *paid*).
- **Hold 1 offered Joker** — it re-appears in the next visit's offer in its rarity slot, alongside 2 fresh draws. Held offers expire at Season end.

Jokers are **Season-scoped**: all owned jokers reset at Season end, except the Player may **carry over one** (their choice; "none" valid) into next Season's starting slots, alongside V0's free starter.

Prices **scale with Tour difficulty** (CONTEXT §Tons — "per-Tour scarcity comes from prices scaling with Tour difficulty, not from a clock").

## 3. Decisions (DK1–DK15)

**DK1 — Headless only.** Domain logic + career integration + harness policies. No scenes. The Kit Room screen is a later rung; it calls the same `ShopResolver` functions.

**DK2 — Visit anchors map to engine reality.** The league's `round_robin` order puts the Player's 7 fixtures first (pairs (0,1)…(0,7)), so "after Match 3 / after Match 5" = after the 3rd/5th league fixture. V3 fires iff the Player seeds top-4; V4 fires before the Final **or** the 3rd-place playoff, whichever the Player is in.

**DK3 — Zero-ripple invariant.** Every new parameter defaults off (`shop_policy = null`, `jokers = []`). With defaults, league/season/career are **byte-identical** to `main` (no extra RNG draws, same outcomes) — pinned by a seeded equality test. All existing oracles (joker floor 45.5%, env peg, build/pay spreads) are untouched by construction: no ball-math, no sim dials.

**DK4 — Pay accrues match-by-match inside `play_season`.** Today pay is summed after the whole Season; a mid-Season Shop needs the budget to be real at visit time. `play_season` re-orders to accrue `match_pay` + `match_win_prize` per Player match as the hooks fire (Season prizes still land at the end — they depend on the final table). The shop-off total is **exactly equal** to the old path (pinned by test; same formula, different summation order, all-int arithmetic).

**DK5 — Tour-scaled pricing.** `Economy.joker_price(id, level, tour, etun)` = `JokerCatalog.price(id)` × `joker_price_level_mult[level]` × `joker_price_tour_mult[tour]`, rounded to int. Strawman dials in `EconomyTuning`:
- `joker_price_level_mult = [1.0, 1.5, 2.0]` (Club / City / Province)
- `joker_price_tour_mult = [1.0, 1.1, 1.1, 1.1, 1.3, 1.4, 1.5, 1.6]` (initialised to the prize-escalation shape so cost tracks income; a **separate dial** so they can diverge when measured)

Rationale: keeps the catalog's measured relative prices (45 jokers, banded by realized strength) and scales the whole sheet with where you are — the "frequently cannot afford every Joker" scarcity canon. Sweepable at E4.

**DK6 — State lives in `ShopState` (Season-scoped) + one persisted field.** New `scripts/data/shop_state.gd` (Resource): `owned_ids: Array[String]` (≤4), `paid_prices: Dictionary` (id → ₸ paid; refunds are honest), `held_id: String` (empty = none). Created fresh each Season inside `play_season`. The only cross-Season persistence is **`CareerState.carryover_joker_id: String`** (default `""`), saved with the career. Carried/starter jokers enter `owned_ids` at V0 with paid price 0 — selling them refunds nothing. (A carried joker does *not* keep last Season's paid price: that would mean persisting price history on `CareerState` for a refund edge case. It arrived free this Season; ₸0 is the honest refund base.)

**DK7 — All four actions ship.** Buy / upgrade / sell / hold, each capped at one per visit, validated in `ShopResolver` (affordability, slot cap, duplicates — a joker already owned can't be offered or bought twice; held id excluded from fresh draws).

**DK8 — Owned = active.** The 4-slot cap means owned jokers are all live in every Player-facing match (league fixtures + Player knockouts; derived fixtures between other teams never see them). No benching this rung — `loadout_cap` (4) is the ownership cap.

**DK9 — Policies are the harness's, not the engine's.** New `scripts/harness/shop_policy.gd` (`ShopPolicy`): a strategy enum + pure deciders called at each visit with (offer, state, player, level, tour, etun). Presets:
- `NONE` — never visits, never spends (the pure shop-off floor; the old preview bot's unlimited between-Season spending is deleted by DK10, not preserved as an arm).
- `ATTR_ONLY` — never buys jokers; takes the +1 attribute upgrade whenever affordable (round-robin attr pick, the preview's existing rule).
- `JOKER_ONLY` — **Nico's playstyle**: buys the best affordable joker every visit (Legendary > Rare > Common when affordable), never upgrades attributes; sells nothing; holds the Legendary it can't yet afford; carries over the highest-paid owned joker.
- `BALANCED` — strawman heuristic: buy a joker if affordable after reserving the next attribute upgrade's cost; otherwise upgrade; hold a Legendary when nearly affordable.

E4 searches this space properly; this rung only needs honest fixed strategies.

**DK10 — The Shop replaces the preview's free-form attribute spending.** Canon says +1 attribute per visit, ≤5 visits/Season — a *harder* cadence than the preview's "upgrade while affordable between Seasons". `tools/career_preview.gd` moves to shop-policy arms (the old unlimited spend is deleted, not kept as an arm — it was never canon). **Expected pacing ripple, re-measured this rung:** max-out was pegged to median S50 under unlimited spending (`attr_cost_base` 13); under the visit cadence the binding constraint may shift from ₸ to visits. If max-out drifts off Nico's ~49-Season target, re-peg `attr_cost_base` (the DP3-anticipated re-solve) and record before/after.

**DK11 — Career end-reason tracking (Nico's ask).** Career runs report `end_reason`: `COMPLETE` (Province Premier won) or `SEASON_CAP` (hit the run cap). The enum lives where E4 will read it (preview output + narrative), with room for `RETIRED_FORCED` when Theme 9 builds the mechanic. No retirement mechanic ships this rung.

**DK12 — Narrated playthrough tool.** `tools/career_narrate.gd`: plays **one seeded career** with `BALANCED`, emitting a season-by-season story — team + ★, tour name, league finish, headline Player numbers, every Shop action in plain English ("bought The Chase Master ₸220", "held Snicko"), Offers and the choice made, bank trajectory, end reason — written to `docs/mockups/career-narrative-v1.md`. This is the artefact Nico reacts to ("how I want to see it and run it"); it is deliberately *narrative*, not a stats table.

**DK13 — RNG discipline.** Shop offer draws consume the **career rng** (same stream as the season sim) at documented points: V0 draws before the league, V1/V2 between fixtures, V3/V4 before knockouts. With `shop_policy = null` no shop code runs → zero draws → DK3's byte-identity holds. When the shop is on, RNG-stream divergence from `main` is expected and fine (jokers change outcomes anyway).

**DK14 — Sell refunds the price paid.** `Economy.sell_refund(paid, etun)` (existing) over `ShopState.paid_prices[id]` — not the current shelf price. Within a Season level/tour are fixed so the distinction is small; paid-price is the honest rule and survives future mid-Season price changes.

**DK15 — Hold semantics.** Holding marks one of the three offered ids; at the next visit that id occupies its rarity slot and the other two slots draw fresh (a held Common → fresh Rare + Legendary, etc.). The held id is excluded from fresh draws while held. Expires (cleared) at Season end. Holding is free and does not reserve ₸.

## 4. Architecture

New/changed units, one purpose each:

| Unit | Kind | Purpose |
|---|---|---|
| `scripts/data/shop_state.gd` (**new**) | Resource | Season-scoped ownership: `owned_ids`, `paid_prices`, `held_id` |
| `scripts/domain/shop_resolver.gd` (**new**) | pure static | `roll_offer(rng, state, level, tour, etun)` → `{common, rare, legendary, prices}` honoring held/owned exclusions · `starter_offer(rng)` → 3 Commons · `buy/sell/hold/upgrade_attribute` appliers with validation · `season_reset(state, carry_id)` |
| `Economy.joker_price` (**new fn**) | pure static | catalog price × level mult × tour mult (DK5) |
| `EconomyTuning` (+2 dials) | Resource | `joker_price_level_mult`, `joker_price_tour_mult` |
| `LeagueResolver.simulate_league(..., jokers := [], shop_hook := Callable())` | seam | passes `jokers` into Player fixtures; invokes `shop_hook(player_matches_so_far)` after Player matches 3 and 5 — the hook returns the (possibly new) jokers array |
| `SeasonResolver.simulate_season(..., jokers := [], shop_hook := Callable())` | seam | threads league seam; invokes the hook before the semi (if Player top-4) and before the Player's championship match; Player knockouts get the current loadout |
| `CareerResolver.play_season(..., shop_policy := null)` | orchestration | builds the hook closure: accrue pay for new matches → run the visit via `ShopResolver` + policy → return updated loadout. V0 starter + carry-over before the league; carry-over decision + `season_reset` after. Pay accrual goes incremental (DK4) |
| `CareerState.carryover_joker_id` (**new field**) | persisted | DK6 |
| `scripts/harness/shop_policy.gd` (**new**) | harness | DK9 presets |
| `tools/career_preview.gd` (rework) | oracle | policy arms + `end_reason` (DK10/DK11) |
| `tools/career_narrate.gd` (**new**) | tool | DK12 narrative |

**Data flow (one Season with the Shop on):** `play_season` → V0 (carry-over + starter into `ShopState`) → `simulate_season(jokers = owned)` → league fires `shop_hook` after P3/P5 → hook: bank the new matches' pay, `roll_offer`, policy decides, apply buy/upgrade/sell/hold → returns `owned` → remaining fixtures use it → hook again before semi/championship → Season ends → Season prizes bank → policy picks carry-over → `season_reset`.

**Error handling:** resolver appliers validate and `push_warning` + no-op on illegal actions (can't afford, slot overflow without a replacement pick, selling an unowned id) — same recoverable-validation convention as `play_season` on a locked cell (and GUT counts `push_error` as a failure).

## 5. Testing

- **Resolver units:** offer composition (1C+1R+1L, no owned/held dupes), starter = 3 distinct Commons, buy math (balance, slots, replacement), sell refund = frac × paid, hold re-appearance + expiry, price scaling table, carry-over + reset.
- **Seam units:** hook fires at exactly P3/P5 (league) and pre-semi/pre-championship gated on qualification (season); jokers reach Player fixtures only.
- **Byte-identity (DK3):** seeded league/season/career with defaults ≡ pre-rung results (standings, scores, pay totals).
- **Pay-equality (DK4):** shop-off `play_season` total == old batch total on seeded runs.
- **Policy units:** JOKER_ONLY never upgrades, ATTR_ONLY never buys, both respect budgets.
- **Career integration:** a seeded career with JOKER_ONLY ends with `ShopState` empty (Season reset) but `carryover_joker_id` set; `end_reason` correct on a capped run.

Suite: 508 green today; judge green by the count climbing.

## 6. Measurement (this rung's §10, filled at close-out)

`career_preview` N=100 per arm — `ATTR_ONLY` (the new canon-cadence floor) vs `JOKER_ONLY` vs `BALANCED`:
- completion rate / median Seasons / median matches / hours (vs the pre-Shop naive line 79/100 · 62 S · 24.2 h),
- max-out Season (DK10 re-peg check vs ~S50 target),
- bank trajectory (does the ₸97k hoard deflate?),
- first read on "jokers buy back the grind" (JOKER_ONLY + BALANCED vs ATTR_ONLY medians).

Viz: `docs/mockups/shop-career-v1.html` (arms compared, counts on bars, censored runs visible) + the narrative artefact (DK12).

## 7. Out of scope (deferred, recorded)

- Kit Room **screen** + Kit Manager persona lines (Theme 5/6 build).
- Mid-Season Offer (career-loop DC2 — playable-season rung).
- Joker price re-solving / optimal spend search — **E4** (with Nico's joker-only playstyle + end-reason requirements).
- Forced-retirement *mechanic* (Theme 9); only the tracking slot lands (DK11).
- Affinity performance bonus (DC12, still unmeasured).
- Benching/loadout-vs-ownership split — only if a future rung raises ownership above 4.
