# Jokers in the sim — C2b: bowling-side intent (design)

**Date:** 2026-06-08 · **Rung:** 7c layer C, sub-slice C2b · **Mode:** AFK (decisions made + recorded here)
**Prior:** C2a field-mode (PR #19, 11 of 45 jokers). **Pool:** `docs/joker-pool-v1.md`. **Grammar:** ADR 0007 · **Palette:** ADR 0006.

## 1. What this rung adds

The bowling captain finally gets an **intent** dimension. Until now the *batting* side has an `IntentPlan` (rung 4a) but the bowling captain has none — so the four jokers that read a bowling-captain or opposing-batsman intent can't fire. C2b adds that signal and wires those jokers.

Two new intent signals reach the **opposition's batting innings** (the innings where the Player is *bowling* — same routing as `FieldPlan`):

1. **Bowling-captain intent** (`bowl_intent`) — the Player, while bowling, sets Aggressive / Balanced / Defensive (attack the stumps vs strangle). A *new* signal. Read by **#26 Attack the Stumps**, **#22 Choke Hold**, **#18 Defensive Captain**.
2. **Opposition batsman intent** — an AI batting `IntentPlan` for the opposition (previously hard-Balanced). Read by **#19 Pressure Cooker** (which exploits a defensive opponent).

Both reuse the existing `IntentPlan` (same `DEFENSIVE/BALANCED/AGGRESSIVE` bands) — no new class.

**Pool delta: 11 → 15 of 45.**

## 2. Jokers wired (magnitudes verbatim from the pool doc)

| # | Name | Rarity | Condition | Effect |
|---|---|---|---|---|
| 26 | Attack the Stumps | Common | bowling AND bowl_intent = Aggressive | wicket ×1.12 |
| 19 | Pressure Cooker | Common | bowling AND opposing batsman intent = Defensive | wicket ×1.10 |
| 22 | Choke Hold | Legendary | bowling AND field = Defensive AND bowl_intent = Defensive | runs ×0.75 **and** wicket ×1.15 (two rows) |
| 18 | Defensive Captain | Common | bowling AND bowl_intent = Defensive | **sets** field → Defensive (enabler; no roll of its own) |

## 3. Decisions (made AFK; would otherwise be brainstorm questions)

- **D1 — the subsystem.** C2b = "bowling-side intent." Reuse `IntentPlan` for both the bowling-captain intent and the opposition AI batting intent (same three bands); no new value object. Mirrors how `FieldPlan` was the C2a subsystem.
- **D2 — joker set.** The four the roadmap named (#26, #19, #22, #18). They span: own-captain-intent read (#26), opposing-batsman-intent read (#19), a two-row Legendary combining field + captain intent (#22), and a state-setting *enabler* (#18). 11 → 15.
- **D3 — model extensions.** Two new `JokerEffect` fields, both `int`, default `-1` (consistent with the "stored as int, not enum-typed" rule — GDScript can't unify a class-local enum type across the call boundary):
  - `bowl_intent_req` — gate on the **bowling-captain** intent (distinct from `intent_req`, which gates the **batsman's** intent the ball is bowled under).
  - `sets_field` — a `FieldPlan.Mode` this joker *forces* when its non-field conditions hold (`-1` = sets nothing). For #18.
  - `matches(...)` gains a trailing `bowl_intent := -1`.
- **D4 — #18 as a field-deriving enabler.** A `sets_field` joker is a *state write*, not a roll multiplier. `JokerResolver.roll_mults` runs a **pre-pass**: for each active `sets_field` joker whose conditions hold, upgrade the **effective field mode**; the multiplier loop then reads the upgraded field. #18 carries `mult = 1.0` so it never bends a roll directly — it just unlocks field-gated jokers (Tight Lines, Dot Ball Pressure, Choke Hold). Consequence: **#18 reads ≈0% win-delta solo in a sweep** (exactly like Rotate the Strike in C2a — nothing for it to enable when it's the only joker). Its value is proven by a **unit-test combo** (#18 + Tight Lines → Tight Lines fires under Defensive bowl_intent even with no base field set).
- **D5 — threading (off-by-default, determinism-preserving).** `bowl_intent_plan: IntentPlan = null` added to `simulate_innings`; `player_bowl_intent_plan` + `opp_intent_plan` (both `IntentPlan = null`) added to `simulate_match` / `simulate_match_teams`, routed to the **opposition's batting innings**. `null` → no bowl-intent gating / opposition bats Balanced → **byte-identical** for every existing caller. Intent changes only the `resolve_ball` logit, **no new RNG draws** → determinism (same seed → same result) preserved.
- **D6 — the opp-intent coupling is real, not a hack.** The opposition's batting intent feeds **both** the `resolve_ball` logit (a genuinely Defensive opponent scores fewer runs) **and** #19's gate. So setting the opposition Defensive helps the Player win on its own; the sweep isolates a joker's effect by holding `opp_intent_plan` and `bowl_intent_plan` **constant across all arms** (same discipline as the shared field/intent plan in C2a) — the win-*delta* is the joker, not the scenario.

## 4. The seam (unchanged shape, two new fields + one pre-pass)

```
JokerEffect: side·target·mult·intent_req·ball_min·ball_max·field_req  (C2a)
           + bowl_intent_req·sets_field                               (C2b)
  matches(player_is_batting, intent, ball, field_mode:=NEUTRAL, bowl_intent:=-1)

JokerResolver.roll_mults(jokers, player_is_batting, intent, ball,
                         field_mode:=NEUTRAL, bowl_intent:=-1)
  → pre-pass: effective field = field_mode, upgraded by any matching sets_field joker
  → multiplier loop over effective field → Vector2(wicket_mult, runs_mult)

simulate_innings(..., field_plan, bowl_intent_plan:=null)
simulate_match(..., jokers, field_plan, player_bowl_intent_plan:=null, opp_intent_plan:=null)
simulate_match_teams(..., jokers, field_plan, player_bowl_intent_plan:=null, opp_intent_plan:=null)
```

Routing: in the **opposition batting innings**, `intent_plan = opp_intent_plan` (the batsman) and `bowl_intent_plan = player_bowl_intent_plan` (the Player's captaincy). In the **Player batting innings**, unchanged (`intent_plan = player_intent_plan`, no bowl_intent — opposition AI bowling intent is unmodeled, no joker reads it).

## 5. Catalog

`JokerCatalog.implemented_groups()` grows from 11 to 15 groups. #22 Choke Hold is a multi-buff (two same-`id` rows). #18 is a single row with `sets_field = DEFENSIVE`, `mult = 1.0`.

## 6. Sweep + eyeball

`tools/sweep_jokers.gd`: add shared `_bowl_intent_plan()` and `_opp_intent_plan()` passed to `simulate_match_teams` (constant across arms). The four new jokers appear as solo arms automatically (driven off `implemented_groups()`); add a **"Bowling-intent stack"** arm (#26 + #19 + #22). Refresh `docs/mockups/distribution-viewer-v1.html` `DATA`. Expectations: #26/#19/#22 lift the Player's win-rate (more opposition wickets / fewer opposition runs); #18 reads ≈0% solo (documented). Absolute numbers shift vs C2a because the shared scenario is now richer (adds bowl-intent + opp-intent plans) — the C2a regression invariant is on the *code path*, not the numbers; existing-joker deltas stay positive and similarly ordered.

## 7. Out of scope (later rungs)

- **Opposition AI bowling intent** (so the *Player's* batting jokers could read a bowling captain) — no joker needs it; deferred.
- **Context-aware AI intent** (opp goes Defensive *because* it's losing) — the harness sets a fixed plan; an adaptive AI is layer E (self-play).
- **Form / windowed-trigger / setNextBowler-fire / Boost / DRS** jokers — C2c–C2g.

## 8. Tests (test-first, judge red by parse-error, green by count climbing past 240)

- `test_joker_effect.gd`: `bowl_intent_req` gate (on/off/any); `sets_field` field present; `bowl_intent` arg defaults to -1 (old callers unaffected).
- `test_joker_resolver.gd`: bowl_intent-gated joker contributes only on match; `sets_field` pre-pass upgrades the effective field so a field-gated joker then fires (#18 + Tight Lines combo); sets_field joker contributes no multiplier itself.
- `test_joker_catalog.gd`: 15 groups; the four new ids present; Choke Hold has two effect rows; Defensive Captain has `sets_field = DEFENSIVE`.
- `test_innings_jokers.gd`: a bowl_intent plan fires #26 in the opposition innings (more wickets vs none); determinism with bowl_intent_plan set.
- `test_match_jokers.gd`: `player_bowl_intent_plan` / `opp_intent_plan` null → byte-identical to pre-C2b; #19 fires when opp_intent_plan Defensive (directional); determinism.
