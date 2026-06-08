# Jokers in the sim — C2h: the final two (design)

**Date:** 2026-06-08 · **Rung:** 7c layer C, sub-slice C2h (the last) · **Mode:** AFK
**Prior:** C2g Form sources (PR #25, 43 of 45). **This rung completes the pool: 43 → 45 of 45.**

## 1. What this rung adds

Two stateless leftovers that each need one new readable condition:

- **#9 Field Restrictions** — *while batting against a catching field: runs ×1.12.* Reads the **opposition's** field while the Player bats. The field signal exists (`FieldPlan`) but only routes to the Player's bowling innings; C2h routes an **opposition field** into the Player's batting innings.
- **#15 The Chase Master** — *2nd innings + Aggressive: runs ×1.20 every ball.* Needs an **is-chase** condition. (The pool's "Form extends the window" framing is moot in our per-ball model — a continuous condition is always on while it holds — so it collapses to a stateless gate.)

Both reuse the existing per-ball seam (`field_req` / `intent_req`) plus one new condition each.

## 2. Model + threading

- `JokerEffect.chase_req: int = -1` (−1 any · 1 requires chase · 0 requires not-chase). `matches()` gains a trailing `is_chase := false`; `JokerResolver.roll_mults` gains `is_chase := false`.
- `simulate_innings`: `is_chase := target > 0` (a chase passes a target). New `opp_field_plan: FieldPlan = null` — when **batting**, the effective `field_mode` is read from `opp_field_plan` (the opposition's field); when bowling, it stays the Player's `field_plan` (unchanged).
- `simulate_match(_teams)`: new `opp_field_plan: FieldPlan = null`, routed to the **Player's batting innings** (the chase already sets `target`, so `is_chase` is automatic).

**Determinism:** new conditions only gate existing rolls, no new RNG. Off-by-default: no `chase_req` jokers / no `opp_field_plan` → byte-identical.

## 3. Jokers (43 → 45)

| # | Name | Rarity | Condition | Effect |
|---|---|---|---|---|
| 9 | Field Restrictions | Common | batting, opp field = catching | runs ×1.12 |
| 15 | The Chase Master | Legendary | batting, chasing, Aggressive | runs ×1.20 |

## 4. Decisions (AFK)

- **D1 — #9 reuses `field_req`** by feeding the opposition's field into the batting innings' `field_mode`. The opposition field is a harness input now (a future opposition AI sets it).
- **D2 — #15 collapses to a stateless chase+Aggressive gate** — in a per-ball model the "extend the window on Form" payoff is equivalent to an always-on buff while the conditions hold; the EV (runs ×1.20 chasing aggressively) is fully captured.
- **D3 — is-chase = `target > 0`** — the chase innings already carries a target; no new plumbing.

## 5. Catalog + sweep

`implemented_groups()` 43 → 45 — **the full pool wired.** Sweep: pass a shared `opp_field_plan` (catching in a phase) so #9 fires; #15 fires in the chase when the shared intent plan is Aggressive. Refresh viewer. Add a final assertion that the catalog now covers all 45 pool ids.

## 6. Tests (green past 324)

- `test_joker_effect.gd`: `chase_req` gate (chase/not/any) via the `is_chase` arg.
- `test_joker_catalog.gd`: **45 groups**; #9 field shape, #15 chase shape.
- `test_innings_jokers.gd`: Field Restrictions raises runs when batting with `opp_field_plan` catching; Chase Master raises runs in a chase (target > 0) under Aggressive vs not-chasing; determinism.
- `test_match_jokers.gd`: `opp_field_plan` null → byte-identical.
