# Career-line balancing — design

**Date:** 2026-06-14
**Rung:** the structural follow-up to E4 (the optimal-career-line search). Theme 7 / Theme 2 boundary.
**Status:** spec — design approved 2026-06-14, plan + build to follow.

---

## 1. Plain-English what & why

E4 (PR #60) measured the player's 9 career lines (3 climb strategies × 3 spend styles) and found them **wildly unequal**: `rush + balanced` beats the game in ~15.8h at 93.3%, while `farm + joker_only/balanced` **never complete (0%)** and `trophy`/`farm` plod at 28–34h with 43–72% completion. The single cause: **you cross up to the next League by beating only the gate tour (Day Mixed, tour 3)** — so `rush` skips ~half of every league and races to Province with a near-fresh card, then wins the Province Premier *final* by luck.

This rung makes the 9 lines **equally viable and equally paced** — the build-equality principle applied to the *strategy* axis. Two changes plus an iterative tune:

1. **A soft readiness gate** (real game rule): crossing up requires clearing a higher tour, not just the gate tour. Forces `rush` to climb most of each league before it can leave → slows it into the target band, and spreads difficulty across the whole climb.
2. **A farm-trigger fix** (harness only): `farm` no longer waits for an unreachable "card maxed" condition → no more 0% softlocks.
3. **A measure-tune loop** on the gate height + farm linger (+ reserve dials) until the acceptance bar is green.

## 2. Goal metrics (the acceptance bar — Nico's ruling 2026-06-14)

Measured by `tools/career_search.gd` at **N=60/arm** (the E4 protocol), the rung is **GREEN** when:

- **Completion equality:** the 9 arms' completion rates are all **within ~5 percentage points of each other** (max − min ≤ 5 pts).
- **Pacing band:** **every** arm's median time-to-beat is inside **27–33h** (≈30h centre).

(Confirmed read: completion-rate equality + all inside the 27–33h band — *not* the tighter "times also within 5% of each other".)

## 3. The two structural facts that constrain the design

1. **Jokers reset every Season; attributes are permanent.** Only `carryover_joker_id` survives a Season. So durable power = attributes; jokers are in-Season power.
2. **`joker_only` never trains attributes.** Therefore **any gate based on attribute strength would softlock `joker_only` forever** → the readiness gate **must be performance-based** (beat a tour), which both spend styles can satisfy. This is non-negotiable for the acceptance bar.

## 4. Change 1 — Soft readiness gate (`CareerState`)

**Today** (`career_state.gd`): `const LEAGUE_GATE_TOUR := 3`; `mark_beaten(level, tour)` unlocks `(L+1, 0)` when `tour == LEAGUE_GATE_TOUR`.

**Change:** introduce `const READINESS_TOUR := 5` (Evening Mamba — default; the tunable lever) and unlock the next League off **it** instead of the gate tour:

```gdscript
const READINESS_TOUR := 5   # Evening Mamba — soft readiness gate (career-line balancing).
                            # Was tour 3 (Day Mixed); raised so the rusher must clear
                            # 6 of 8 tours per League before crossing up. Premier (7)
                            # stays optional (DP1). Tunable — swept by career_search.gd.

func mark_beaten(level: int, tour: int) -> void:
    cell_status[cell_index(level, tour)] = CellStatus.BEATEN
    _unlock(level, tour + 1)
    if tour == READINESS_TOUR:
        _unlock(level + 1, 0)
```

Tours unlock sequentially (beat T → unlock T+1), so raising the trigger to tour 5 simply means the next League opens only after you have climbed Flat&Warm → … → Evening Mamba (6 of 8). The Premier (tour 7) remains beyond the gate and optional. `READINESS_TOUR` is performance-based, so `joker_only` clears it via jokers at the lower (easier) Levels.

**Why tour 5 as the default:** it leaves a one-tour-plus-final gap (tours 6, 7) above the gate so `rush` and `trophy` stay distinguishable, while tripling `rush`'s mandatory climbing (4 tours → 6). The exact height is the primary tuning dial (sweep range 4–6).

**`LEAGUE_GATE_TOUR`:** retired in favour of `READINESS_TOUR` (a rename + raise). No other code references the gate semantically beyond `mark_beaten`; CONTEXT.md's "Tour-4 gate" canon updates to the new tour.

**No infinite softlock risk:** if a weak line cannot beat `READINESS_TOUR` at all, it simply does not complete (counts against completion %); the Season cap (120) halts it. Tuning balances gate height against completability.

## 5. Change 2 — Farm-trigger fix (`CareerPolicy`, harness)

**Today** (`career_policy.gd`): `farm` crosses only when `_card_maxed(player)` (all 4 attrs at the cap). `joker_only`/`balanced` never train → never max → **0% completion**.

**Change:** `farm` crosses when **card-maxed OR it has played at least `FARM_MIN_SEASONS` at the current Level** (whichever first), provided the next League is unlocked. This guarantees `farm` always eventually crosses regardless of spend style, while preserving its identity ("over-invest before moving on").

**The counter (minimal new state):** add `@export var seasons_at_level: int = 0` to `CareerState`, incremented once per `play_season`, reset to 0 in `CareerResolver.accept_offer` (the climb poles only ever accept cross-up offers, so accept always means a Level change). `CareerPolicy._wants_to_cross("farm", state, player)` becomes:

```gdscript
"farm":
    return _card_maxed(player) or state.seasons_at_level >= FARM_MIN_SEASONS
```

`choose_offer` already only surfaces cross-up offers once the next League is unlocked, so the "next League unlocked" condition is implicit (no offer exists before then).

- `rush`: unchanged — cross the instant a cross-up offer exists.
- `trophy`: unchanged — cross only after winning the current Level's Premier (`state.level_won[L]`).

`FARM_MIN_SEASONS` default **8** (sweep 6–12) — farm plays ~8 Seasons at a Level (enough to climb to the gate plus a few banking/building Seasons) before moving on. Lives as a `const` on `CareerPolicy`.

**Note on `choose_tour` under the new gate:** `rush`/`trophy` already play "lowest unbeaten unlocked tour" — they will now naturally climb to tour 5 (and trophy on to 7) before the cross-up offer appears. `farm` plays the highest unlocked tour (richest cell) — unchanged. No `choose_tour` change needed; only `_wants_to_cross` / `choose_offer` for the farm trigger.

## 6. Tuning dials & the measure-tune loop

Swept by `tools/career_search.gd` (N=60, full 9-arm run ~30 min, nohup'd per CLAUDE.md) until §2 is green:

| Dial | Where | Effect | Default | Sweep |
|---|---|---|---|---|
| `READINESS_TOUR` | `CareerState` | higher → rush climbs more → slower & harder | 5 | 4–6 |
| `FARM_MIN_SEASONS` | `CareerPolicy` | farm pacing + completability | 8 | 6–12 |
| **(reserve)** prize-escalation / super-prize sizes | `EconomyTuning` | reward optional climbing so trophy/farm's extra work repays in a faster finish | unchanged | only if needed |
| **(reserve)** Province-final strength-sensitivity | difficulty ladder top cell | make a strong card win the final notably more (so building pays off) | unchanged | only if needed |

**Order of operations (simplest mechanic first):**
1. Apply Changes 1 & 2 at defaults; run the oracle.
2. Read the 9-arm table. If `rush` is still below the band, raise `READINESS_TOUR`; if `farm` is off-pace or under-completes, adjust `FARM_LINGER`.
3. **Only if** completion-equality won't close with the two structural dials (because trophy/farm's extra climbing isn't repaid), reach for the reserve dials — and re-measure the **balance ledger** if `EconomyTuning` is touched (prize dials are not on the ball path, so the joker/build/pay/env ledger stays untouched by construction; the reserve note is for completeness).

Record every iteration's 9-arm table in §10 so the convergence path is legible.

## 7. Tests (TDD)

New `tests/unit/` assertions (judge green by total count climbing past **556**):

- **Gate:** beating `READINESS_TOUR` unlocks `(L+1, 0)`; beating the old gate tour (3) **no longer** unlocks the next League; beating tour < READINESS_TOUR unlocks only the next tour.
- **Farm trigger:** `CareerPolicy._wants_to_cross("farm", …)` returns true once `state.seasons_at_level >= FARM_MIN_SEASONS` even with an unmaxed card; false before; still true immediately if maxed. `rush` true once unlocked, `trophy` true only after the Premier win — unchanged.
- **Existing tests to update:** any test asserting "tour 3 / Day Mixed beat unlocks the next League" → re-point to `READINESS_TOUR`. Search `LEAGUE_GATE_TOUR` and `mark_beaten` test references.

The oracle (`career_search.gd`) is the acceptance instrument, not a unit test — its DATA line is the green/red signal for §2.

## 8. Decisions (defaults chosen, per project CLAUDE.md AFK)

- **CB-1 — Soft gate, not hard** (Nico's ruling 2026-06-14): crossing requires clearing a mid tour, **not** winning the Premier. Preserves three distinct climb routes (vs a hard "win every Premier" gate that collapses them) and keeps DP1's "Premier optional". Chosen over the "reward optional content only" approach because E4 showed the final is luck-gated not strength-gated, making pure rewards hard to equalise.
- **CB-2 — Performance-based gate** (forced by §3.2): the gate is "beat a tour", never "reach an attribute total" — the only kind `joker_only` can pass.
- **CB-3 — `READINESS_TOUR = 5` default**: leaves tours 6–7 above the gate so rush ≠ trophy; tunable.
- **CB-4 — Farm crosses on maxed-OR-`FARM_MIN_SEASONS`**: a hard seasons-at-Level cap guarantees no softlock for any spend style; preserves farm's "over-invest" flavour. Needs one new `CareerState` field (`seasons_at_level`).
- **CB-5 — Reserve dials held back**: super-prize / final-sensitivity only if the two structural dials can't close completion-equality. Simplest mechanic first; avoids touching `EconomyTuning` / difficulty unless measurement demands it.
- **CB-6 — This is a shipped game-rule change** (unlike E4's harness-only work): the readiness gate is real `CareerState`. CONTEXT.md canon + any pacing prose update accordingly.

## 9. Out of scope (YAGNI)

- No change to the ball / innings / joker / economy *sim* math — the balance ledger holds by construction (the gate is grid structure, not the ball path).
- No new climb poles (the three from E4 stand).
- No shipped career-AI / UI — `CareerPolicy` stays a harness strategy set.
- No re-peg of `attr_cost_base` — E4 proved it a weak lever on optimal time-to-beat (rush wins the final before maxing); the gate is the right lever, not attribute costs.
- No down-Level / lifeline behaviour change (DC16 down-offer still ignored by the climb poles, E4-5).

## 10. Findings

*(Filled during the build — the converged `READINESS_TOUR` / `FARM_LINGER`, the final 9-arm completion+time table proving §2 green, the iteration path, and the ledger-untouched confirmation.)*
