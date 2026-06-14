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

> **Outcome update (2026-06-15):** measurement found this strict bar **over-constrained** — `joker_only` viability and `trophy`-via-card-strength pull the Province-final design in opposite directions, so all-9-within-5pts is unreachable without flattening genuine roguelite trade-offs. Nico ruled to **ship the gate and accept the trade-offs**; the reframed acceptance (no climb strategy dominates · all lines complete · time spread ≤1.6×) is in §10.

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

**Acceptance bar (§2):** completion max−min ≤ 5 pts AND every median time-to-beat ∈ [27,33]h.

### Iteration log

Each entry: dials → 9-arm table (completion% · median time-to-beat). E4's pre-rung baseline (gate=tour3, farm=card-maxed) for reference: rush 87–93% / 15–20h, farm 0–72% / 0–34h (two arms 0%), trophy 43–62% / 28–29h.

**Smoke (N=10, noisy — mechanism check only): gate=5, farm=8.**

| climb \ spend | attr_only | joker_only | balanced |
|---|---|---|---|
| rush | 100% · 23.6h | 90% · 21.9h | 80% · 21.3h |
| farm | 100% · 19.6h | 80% · 22.6h | 80% · 17.2h |
| trophy | 20% · 28.2h | 60% · 19.2h | 60% · 25.8h |

Read: softlocks gone (farm completes everywhere), rush slowed (15.8→21h), but times cluster below the 27–33h band and completion is uneven. N=10 too noisy to tune from → run N=60 baseline.

**Iteration 0 — N=60 baseline: gate=5 (Evening Mamba), farm=8.**

| climb \ spend | attr_only | joker_only | balanced |
|---|---|---|---|
| rush | 90.0% · 23.4h | 75.0% · 19.3h | 83.3% · 24.1h |
| farm | 86.7% · 22.6h | 73.3% · 19.7h | 81.7% · 21.6h |
| trophy | 55.0% · 30.8h | 63.3% · 30.0h | 63.3% · 29.1h |

Completion spread **35 pts** (55–90); time **19.3–30.8h**. Structure: the gate equalized rush≈farm (both ~73–90% / 19–24h, below band); trophy is the outlier — in-band on time (~30h) but low completion (55–63%) and hoarding ₸74k (winning every Premier costs seasons + the super-prize cash can't convert once attributes cap). Within rush/farm, completion is spend-driven (attr ~87–90 > balanced ~82 > joker ~73–75). **Move: gate 5→6** to push rush/farm up into the band on time and pull their completion down toward trophy's (converge both axes).

**Iteration 1 — N=60 (FINAL config): gate=6 (Evening Mixed), farm=8.**

| climb \ spend | attr_only | joker_only | balanced |
|---|---|---|---|
| rush | 86.7% · 26.0h | 80.0% · 21.6h | 85.0% · 21.8h |
| farm | 85.0% · 26.0h | 78.3% · 23.4h | 83.3% · 21.8h |
| trophy | 56.7% · 33.9h | 56.7% · 25.6h | 68.3% · 27.7h |

Completion spread **30 pts** (56.7–86.7); time **21.6–33.9h** (ratio **1.57×**). vs gate=5 (iteration 0): tighter on both (completion 30 vs 35, time ratio 1.57 vs 1.60), more lines pushed toward the band, and only the Premier (tour 8) left optional. **Chosen as final.**

### Outcome — the strict numeric target is over-constrained; the gate is shipped (Nico's ruling 2026-06-15)

**The strict §2 bar (all 9 within 5 pts completion AND all ∈ 27–33h) is NOT reachable by these dials, and the reason is structural, not a tuning failure.** The completion of every line is gated by winning the Province Premier **final** (1st of 8 — a hard, luck-heavy event), and the measurement shows **completion is driven by the number of *attempts* at that final, not by card strength**: `rush + joker_only` (a *fresh* 11/11/11/11 card) completes **80%** while `trophy + attr_only` (a *fully maxed* card) completes only **57%**, because rush reaches Province fast (many cracks at the final) and trophy arrives late (few cracks before the season cap). This creates an unresolvable squeeze:

- To give **trophy** equal completion, the final must **reward card strength** (so its maxed card wins in few attempts).
- But a strength-rewarding final **craters `joker_only`** — it never trains attributes, so a strength-gated final locks it out (§3.2, the same constraint that forced the gate to be performance-based).
- Jokers reset each Season; attributes are permanent (§3.1). So `joker_only` is structurally "viable hard mode" and `trophy` is structurally "the long, safe way" — honest roguelite trade-offs, not bugs (E4 already found "no dominant spend, healthy").

**What the rung DID achieve (the real E4 fix):** the climb axis is balanced — `rush ≈ farm` (both ~78–87% / 22–26h), and the field went from **E4's 2.25× time spread + two arms that never complete (0%)** to **1.57× spread with all 9 arms completing 57–87%**. Rush is no longer a 2× no-brainer speed-run. The two farm softlocks are fixed.

**Reframed acceptance (Nico's ruling 2026-06-15 — "ship the gate, treat the rest as healthy trade-offs"):** the rung is accepted on (1) no climb strategy dominates (rush no longer 2× faster — rush≈farm), (2) every line completes (no softlocks), (3) the time spread compressed to 1.57× (from 2.25×+∞). The residual completion spread is the spend axis (joker_only = hard mode) + the trophy pole (the long way), kept as deliberate roguelite trade-offs. Strict 9-way equality was declined as over-flattening genuine strategic diversity (and impossible to reconcile with `joker_only` viability).

**Ledger: untouched (not re-run).** This rung changed only career-grid structure (`CareerState.READINESS_TOUR`, `seasons_at_level`) and the `CareerPolicy` farm trigger — no ball/innings/joker/economy/difficulty *math*, no tuning resource. The balance ledger (joker floor 45.5, build spread 1.9, pay spread ₸0.3, env 155) holds by construction. No reserve dial (`EconomyTuning`, difficulty ladder) was touched.

**Final dials:** `CareerState.READINESS_TOUR = 6` (Evening Mixed), `CareerPolicy.FARM_MIN_SEASONS = 8`. **562 tests green.**
