# Jokers in the sim — C2c: Form & windowed-trigger buffs (design)

**Date:** 2026-06-08 · **Rung:** 7c layer C, sub-slice C2c · **Mode:** AFK
**Prior:** C2b bowling-intent (PR #20, 15 of 45). **Pool:** `docs/joker-pool-v1.md`. **Grammar:** ADR 0007.

## 1. What this rung adds — the first *stateful* joker layer

Everything wired so far is **stateless**: `JokerResolver.roll_mults` is a pure function of the *current* ball (intent/field/window/side). Form jokers break that — they are **triggered windows**: *"when Form rises → buff the next N balls."* That needs **per-innings state** (active buffs counting down; a record of Form events). C2c builds that engine and wires the Form-driven jokers.

**Form event** (`formEvent(Player, +)` in the pool grammar) is modelled in the auto-sim as a **milestone the Player hits**:
- **batting:** the Player (on strike) hits a **boundary** (4 or 6).
- **bowling:** the Player (bowling their over) **takes a wicket**.

This reuses only signals the sim already produces (`BallOutcome.runs` / `.wicket`, the `is_player` striker flag, the Player-as-bowler quota from PR #16). CONTEXT.md restricts per-ball Form to the Player — honoured (only Player boundaries/wickets fire it).

**Pool delta: 15 → 19 of 45.**

## 2. Jokers wired (magnitudes verbatim)

| # | Name | Rarity | Trigger | Payoff |
|---|---|---|---|---|
| 10 | Ride the Wave | Common | Form rises while batting | runs ×1.20 for next 3 balls |
| 29 | Wicket Maiden | Rare | Form rises while bowling | wicket ×1.30 for next 6 balls |
| 14 | Hot Streak | Rare | 2 Form events within 6 balls (batting) | runs ×1.30 **and** wicket ×0.85 for 6 balls |
| 7 | Match-Winner's Vigil | Legendary | Form rises while batting | wicket ×0.80 for next 24 balls |

## 3. The windowed-buff engine — `JokerRuntime`

A per-innings `RefCounted` (`scripts/domain/joker_runtime.gd`) that `simulate_innings` owns and ticks each ball:

- `active: Array` — each entry `{side, target, mult, balls_left}`.
- `form_event_balls: Array[int]` — innings-ball indices where a Form event fired (for the 2-in-6 double trigger).

Per-ball flow inside `simulate_innings`, layered on top of the existing stateless mults:

1. `var stateless := JokerResolver.roll_mults(...)` (unchanged).
2. `var windowed := runtime.tick_mults(player_is_batting)` — product of active buffs whose `side` matches this innings.
3. Pass `stateless.x * windowed.x`, `stateless.y * windowed.y` to `resolve_ball` (same clamp as before).
4. `runtime.on_ball_end(jokers, player_is_batting, ball, formed)` where `formed` = a Player Form event happened this ball. It **decays first** (every active buff `balls_left -= 1`, drop ≤0 — those applied to the ball just resolved), **then pushes** new buffs from this ball's trigger (so a window_n buff covers the *next* N balls).

**Determinism:** buff detection reads `resolve_ball`'s deterministic output; decay/push are deterministic; **no new RNG draws** → same seed → same result. Off-by-default: an empty joker list (or no trigger jokers) leaves `active` empty → byte-identical to pre-C2c.

## 4. Model — `JokerEffect` gains a trigger shape

Windowed-trigger jokers carry a trigger + window instead of a per-ball condition:
- `enum Trigger { NONE, FORM_BAT, FORM_BOWL, FORM_DOUBLE_BAT }`.
- `var trigger: int = Trigger.NONE`, `var window_n: int = 0`.

A `trigger != NONE` joker is **invisible to the stateless `matches()`** (it never applies per-ball directly); the runtime owns it. `FORM_BAT`/`FORM_BOWL` fire on a single Form event on the matching side; `FORM_DOUBLE_BAT` fires when this Form event is the 2nd within 6 balls (batting). Multi-row jokers (Hot Streak = runs + wicket) keep the duplicate-`id` pattern (two trigger rows, same trigger/window).

## 5. Decisions (made AFK)

- **D1 — merge Form + windowed buffs into one rung.** Form's payoffs *are* decaying windows; building the engine and Form together is the natural seam. This absorbs the roadmap's planned "C2d windowed buffs" — the **remaining rungs shift down one**: next is **C2d setNextBowler-fire** (its windows reuse this engine), then **C2e Manager Boost**, **C2f DRS**. Still ends at 45 wired.
- **D2 — Form event = Player boundary (bat) / Player wicket (bowl).** The cleanest sim-observable milestone; uses only existing state. (A finer "every 25 runs" milestone is a later tuning dial.)
- **D3 — windowed buffs apply to every ball in the window on the matching side**, not only Player-on-strike balls — consistent with how the existing stateless batting jokers already apply across partner balls (the resolver is called per-innings, not per-striker).
- **D4 — `JokerRuntime` is the stateful layer; `JokerResolver` stays pure.** Keeps the stateless seam intact and testable; the engine is additive and off-by-default.
- **D5 — #7 Match-Winner's Vigil: wire the buff (wicket ×0.80 n=24), simplify away the "snap to Defensive" intent write.** The EV-bearing part is the buff; mid-innings intent mutation is a separate mechanic with little harness value — deferred/noted (same spirit as #18's enabler scope).
- **D6 — deferred this rung:** Form *source* jokers that only feed Form via an intent-switch fire (#2 Sheet Anchor, #11 Captain's Statement, #5 Building Phase) and pure intent-snaps (#13 Boundary Hunter) and the window-extension Legendary (#15 Chase Master) — they add intent-mutation / form-source-counting with little standalone EV; folded into a later cleanup. Noted in the roadmap so the count to 45 stays honest (19 wired + these tracked).

## 6. Threading

`simulate_innings` constructs a `JokerRuntime` at the top (always; empty when no trigger jokers) and ticks it per ball. No new public params — the runtime is internal, driven off the existing `jokers` array. `simulate_match(_teams)` unchanged (passes `jokers` as today). Trigger jokers live in the same `jokers` array as stateless ones; the runtime filters by `trigger != NONE`, the resolver filters by `trigger == NONE`.

## 7. Catalog + sweep

`JokerCatalog.implemented_groups()` 15 → 19. New sweep arms appear automatically. The shared scenario's Player build/intent already produce boundaries (Aggressive powerplay/death), so Form events fire. Add a "Form-window stack" arm (#10 + #14 + #7 batting). Refresh the viewer `DATA`.

## 8. Tests (test-first; green by count climbing past 258)

- `test_joker_effect.gd`: a `trigger != NONE` joker returns false from `matches()` (never applies per-ball).
- `test_joker_runtime.gd` (new): single FORM_BAT trigger pushes a 3-ball runs buff that decays over exactly 3 balls then expires; side gating (a bowling buff is inert in a batting innings); FORM_DOUBLE_BAT fires only on the 2nd event within 6 balls; empty runtime is identity.
- `test_joker_catalog.gd`: 19 groups; new ids present; Hot Streak has 2 rows; Ride the Wave trigger = FORM_BAT, window_n = 3.
- `test_innings_jokers.gd`: Ride the Wave raises Player runs vs baseline (boundaries trigger the window); Wicket Maiden raises opposition wickets; determinism with trigger jokers.
- `test_match_jokers.gd`: trigger jokers don't break determinism; an empty/stateless-only joker list is byte-identical to pre-C2c.
