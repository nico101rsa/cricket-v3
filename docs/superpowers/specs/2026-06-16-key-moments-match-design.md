# Key Moments in the Match — Design

**Date:** 2026-06-16 · **Theme:** 2 (Presentation) · **Rung:** FIFTH presentation rung — *the core game-feel feature*
**Status:** spec written (build = next session)
**Why this rung exists:** Nico launched the real game for the first time and found the match "just ran through… nothing like key moments." Correct diagnosis: the balance track built the *math* (Intent, typed effects, jokers, DRS, Boost) and the presentation track built screens to *watch* it — but the **Key Moments, the documented locus of player agency (CONTEXT.md "Match" / "Key Moment"; ADR 0003), were never built into the playable match.** This rung builds them.

---

## 1. What this is (plain English)

Per the locked design (DESIGN_HANDOFF §3), a T20 innings is **auto-sim segments punctuated by 5–8 Key Moments** — each a swipe/tap decision card that pauses the action and asks the captain (you) to make a call. Your choice changes how the team plays the next stretch. That is where the game is *played*; without it the match is a replay you watch.

This rung builds the **Key Moment framework + the first 3 batting-innings archetypes**, so the match pauses at dramatic points, shows you a decision, and your call changes the result.

## 2. Decisions (locked)

- **D1 — A Key Moment is another decision baked into the re-sim (the cheap third door, same as Boost/DRS).** No new sim engine. `MatchSession` already re-runs the deterministic sim from the seed with accumulated policy; a Key Moment choice appends to that policy and re-sims. The prefix you've already watched stays **byte-identical** (the determinism contract); only the future diverges = "your call changed the match." (Mirrors `decide_boost`/`decide_review`.)
- **D2 — Choices map onto the sim's existing Intent lever.** The team's aggression band (Defensive / Balanced / Aggressive, `BallResolver.Intent`) already trades scoring against dismissal risk (ADR 0003: no dominant answer — honest by construction). So "Anchor vs Hunt" *is* "Defensive vs Aggressive." No new ball-math.
- **D3 — The policy is a per-over Intent override (small generalisation of `IntentPlan`).** Rather than only the 3 fixed phase bands, a `KeyMomentPlan` carries `(from_over, band)` overrides; the effective Intent for an over is the latest override at-or-before it (falling back to the base `IntentPlan`). This cleanly supports a moment firing *mid-phase* (Wicket Crisis at, say, over 10 overrides overs 10+). Each override only affects the **future** (its over onward), so the watched prefix stays identical.
- **D4 — Three archetypes this rung, all batting-innings (one Intent channel):** ⚡ Powerplay Exit, 🩸 Wicket Crisis, 💀 Death Plan (§4). Two always-fire + one event-triggered = 2–3 real decisions per innings.
- **D5 — Card = two big tap buttons this rung.** The swipe animation is polish; a tap is the same decision and is testable. The card overlay reuses the interactive-match overlay pattern (the DRS overlay already pauses the replay and resumes after a choice).
- **D6 — The Manager Boost stays as-is** (ADR 0005 — separate from Key Moments). DRS stays as the existing batting-side review popup this rung (reframing DRS as a Key Moment archetype is deferred).
- **D7 — Triggers are computed from the player's batting-innings ball-log**, not the player-centric event stream (a teammate's wicket lives in an over-summary, not a per-ball event). After each re-sim the triggers are recomputed (the prefix triggers are stable; a changed future may move/add/remove a later Wicket Crisis — correct, that's your PP-Exit call shaping the game).

## 3. Architecture

```
MatchSession (extended)
  _km_plan: KeyMomentPlan            # accumulated (from_over, band) overrides — a resim policy input
  key_moment_offer(cursor) -> {}|{kind, from_over, choices:[{label,band}]}
                                     # scans the player batting innings ball-log; returns the
                                     # moment at/just-before this playback cursor, or {}
  decide_key_moment(from_over, band) # append override, _resim() (prefix byte-identical)
  _resim(): builds the effective IntentPlan from base + _km_plan, passes to simulate_match_teams

interactive_match scene (extended)
  on step/playback reaching a KM trigger cursor -> pause, show the KM card overlay (2 buttons)
  button pressed -> session.decide_key_moment(...) -> re-render -> resume (mirrors DRS overlay flow)
```

`KeyMomentPlan` (`scripts/data/`): `var overrides: Array = []` of `{from_over:int, band:int}`; `effective_for_over(over, base: IntentPlan) -> int` returns the latest override ≤ over, else `base.for_over(over)`. Pure, unit-tested.

The effective per-over Intent feeds `simulate_innings` for the **player's batting innings only** (the captain sets their own team's intent; the opposition innings is unchanged). Threaded through `MatchSession._resim` → `simulate_match_teams`'s `player_intent_plan` seam. **Implementation note (resolve in plan):** `simulate_match_teams` takes a single `IntentPlan`; the per-over override is realised either by (a) building an `IntentPlan` whose 3 phase bands reflect the overrides when overrides fall on phase boundaries (covers PP Exit→middle, Death Plan→death exactly), plus (b) a per-over override path for mid-phase moments (Wicket Crisis). Simplest correct route: give `simulate_innings` an optional per-over intent source that defaults to the `IntentPlan` (byte-identical when no overrides) — decide in the plan whether to extend `IntentPlan` with an overrides array or add a thin wrapper.

## 4. The three archetypes

| Moment | Trigger (player batting innings) | Choices → effect (band from the trigger over onward) |
|---|---|---|
| ⚡ **Powerplay Exit** | end of over 6 (always) | **Anchor** → middle = DEFENSIVE · **Hunt** → middle = AGGRESSIVE |
| 🩸 **Wicket Crisis** | first wicket to fall in overs 7–15 (variable) | **Settle** → DEFENSIVE from that over · **Counter-attack** → AGGRESSIVE from that over |
| 💀 **Death Plan** | start of over 16 (always) | **Milk it** → death = BALANCED · **Go big** → death = AGGRESSIVE |

(Default if you never decide / a moment doesn't fire: the base `IntentPlan` band, i.e. BALANCED — byte-identical to today.)

Each is a genuine EV trade-off in different match states (ahead of the rate vs behind it, wickets in hand vs not) — never labelled as "the answer" (ADR 0003).

## 5. Where it surfaces

- `scripts/data/key_moment_plan.gd` (**new**) — the policy + `effective_for_over`.
- `scripts/domain/match_session.gd` — `_km_plan`, `key_moment_offer(cursor)`, `decide_key_moment(...)`, `_resim` builds the effective intent.
- the per-over intent path in `simulate_innings`/`IntentPlan` (see §3 note).
- `scenes/interactive_match/interactive_match.{gd,tscn}` — the KM card overlay + trigger-pause flow (reuse the DRS overlay pattern: `_pending`, `_resume_after`, pause/show/resume).
- trigger detection helper reading `MatchResult.ball_log_innings*` (already captured by the live loop).

## 6. Testing (TDD)

Pure first, then scene:
1. `KeyMomentPlan.effective_for_over` — empty = base band; one override applies from its over onward; latest-wins on overlap.
2. `MatchSession.key_moment_offer(cursor)` — returns Powerplay Exit at the over-6 boundary cursor; Death Plan at the over-16 boundary; Wicket Crisis at the first middle-overs wicket; `{}` elsewhere.
3. `decide_key_moment` — appends the override, re-sims, **prefix byte-identical** (assert the pre-trigger balls of the event stream are unchanged), future diverges.
4. Determinism: same choices + seed → identical result.
5. Scene: inject a session, drive to a trigger, assert the KM card overlay shows with the right label + two buttons; press one → overlay hides, result re-renders.

Run the whole suite each step (`-gdir=res://tests/unit`); red = `KeyMomentPlan` parse error; green = count climbs + `All tests passed`. **Eyeball the real game** (per the launch-playable rule) — invisibility/feel can't be unit-tested.

## 7. Deliverable (Nico-facing) — LAUNCH IT, don't screenshot

Per the lesson from this session ([[feedback-launch-playable-not-screenshot]]): the deliverable is the **playable game**, launched. After the build: seed a save (`tools/seed_demo_save.gd`), launch `scenes/main.tscn`, and tell Nico to PLAY a fixture and feel the Key Moments pause-and-decide. A screenshot is build-proof only. Tell him exactly what to do and what to feel (does the pause land? does the choice visibly change the match?).

## 8. Explicitly deferred (later rungs)

- Bowling-innings Key Moments (Bowling Change, Field Set, Star-bat-on-49) — a second Intent/effect channel.
- The Final Over 6-micro-swipe sequence (ball-by-ball yorker/slower/bouncer).
- DRS reframed as a Key Moment archetype (it stays the existing popup this rung).
- Swipe animation + card art (hi-fi) — tap buttons this rung.
- Milestone Ball (batter on 49/99) + the 8th archetype.
- "Key Moments won" as a tracked stat feeding ₸ pay (CONTEXT.md mentions it; defer until the moments exist).

## 9. Open defaults (chosen, recorded — not blocking)

- Wicket Crisis fires on the **first** middle-overs wicket only (one crisis/innings this rung) — keeps it to ≤3 decisions/innings.
- Powerplay band stays the base default (not a decision this rung) — PP Exit decides the *middle*, the first thing you actually control.
- Card copy uses the DESIGN_HANDOFF labels (Anchor/Hunt etc.); plain descriptive text, no recommendation arrow (ADR 0003).

## 10. Findings (build) — filled in next session

(to be completed at build: trigger-cursor mapping, a worked resim example showing the prefix held + future changed, test count delta, and the launch instructions given to Nico.)
