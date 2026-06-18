# Bowling Key Moments — Design

**Date:** 2026-06-18 · **Theme:** 2 (Presentation) · **Rung:** SIXTH presentation rung — *Key Moments, bowling-innings half*
**Status:** spec written (build = this rung, AFK)
**Why this rung exists:** The batting Key Moments (PR #73) gave the captain real decisions while batting — the match pauses, you choose, the rest of the innings re-sims. The **bowling innings is still a pure watch**: when the opposition is batting and you're in the field, you have no calls to make. This rung adds the mirror set of decisions to the bowling half, so a whole match (both innings) is a fight.

---

## 1. What this is (plain English)

When the opposition is batting and **you're bowling**, the match now pauses at dramatic points and asks you — the captain — a two-button call that changes how your team bowls the rest of the innings. Exactly the feel of the batting Key Moments, just on the other side of the ball.

This rung builds the **bowling-innings Key Moment framework + 3 archetypes**: 🎯 Powerplay Exit, 🔥 New Batsman In, 💀 Death Defence. Two always-fire + one event-triggered = **2–3 decisions per bowling innings**, matching the batting trio.

---

## 2. The lever — Pace vs Spin (the only bowling channel with real ball EV)

The batting Key Moments override the team's **Intent** band (Defensive/Balanced/Aggressive), which has measured EV. The bowling side has three candidate levers; only one actually changes the cricket:

| Lever | Class | Affects the ball outcome? |
|---|---|---|
| **Pace / Spin** | `BowlingPlan` | ✅ **Yes** — the bowling-balance rung (PR, 2026-06-11) tuned a phase tilt (pace best PP+death, spin best middle) **and** an intent×kind matchup inside `resolve_ball` |
| Field Set (catching/defensive) | `FieldPlan` | ❌ No intrinsic EV — only a flag jokers gate on (C2a) |
| Bowl aggression (bowl-intent) | `IntentPlan` (bowl-intent slot) | ❌ No intrinsic EV — only a flag jokers gate on (C2b, `innings_resolver.gd:204`) |

So the bowling Key Moments control **Pace vs Spin**. Two payoffs:

1. **It's a genuinely different lever from the batting Intent one** — bowling moments feel distinct, not a reskin of "Defensive vs Aggressive."
2. **It's a real trade-off, not a free buff — by the same mechanism PR #77 used for batting.** The EV of pace-vs-spin depends on (a) the phase and (b) the *batsman's* intent (intent×kind matchup: "slogging spin carries extra wicket risk", bowling-balance spec §4.2). The opponent brain now sets that intent *adaptively by match state*. So the right ball is a **read of the situation**, not a button that always helps. The build measures this (D6) on the same bar PR #77 set for batting.

Field Set as a card is **deferred** — it would need a "field as a real lever" EV rung built first (FieldPlan is inert today).

---

## 3. Decisions (locked)

- **D1 — A bowling Key Moment is another decision baked into the deterministic re-sim (the cheap third door, same as Boost/DRS/batting-KM).** No new sim engine. `MatchSession` already re-runs the pure sim from the seed with accumulated policy; a bowling-KM choice appends to that policy and re-sims. The watched prefix stays **byte-identical**; only the future diverges.
- **D2 — Choices map onto the existing Pace/Spin lever (`BowlingPlan`).** "Spin" / "Pace" *is* `BowlingPlan.Kind.SPIN` / `PACE`. No new ball-math — the bowling-balance rung already built and tuned the EV.
- **D3 — The policy is a per-over Pace/Spin override (`BowlingKeyMomentPlan`), exact mirror of `KeyMomentPlan`.** It carries `(from_over, kind)` overrides; the effective bowler kind for an over is the latest override at-or-before it, falling back to the base `BowlingPlan` phase rotation. Mid-phase firing supported (New Batsman In at, say, over 10 overrides overs 10+). Each override only affects the **future**.
- **D4 — A new optional field `BowlingPlan.key_moments: BowlingKeyMomentPlan` (null = plain phase rotation), consumed by `BowlingPlan.for_over`.** Exact mirror of `IntentPlan.key_moments` → zero new resolver params. `MatchSession` passes its accumulated bowling-KM plan into `simulate_match_teams`'s existing `player_bowling_plan` slot (currently `null`).
- **D5 — Three archetypes this rung, all bowling-innings (one Pace/Spin channel):** 🎯 Powerplay Exit, 🔥 New Batsman In, 💀 Death Defence (§4). Two always-fire + one event-triggered.
- **D6 — Build measures the trade-off is real** (re-run `tools/sweep_interactive_levers.gd`, extended with a bowling-KM arm): no bowling choice may be strictly-best across the club fixtures — the bar PR #77 set for batting. If one band dominates, record it as a feel finding for Nico (not necessarily a blocker — phase-correct bowling *can* be the textbook answer, exactly as phase-correct batting is; the test is whether the opponent's adaptive intent makes the answer *shift*).
- **D7 — Triggers are computed from the opposition's batting-innings ball-log** (the innings where the Player is bowling — `ball_log_innings2` if player bats first, else `ball_log_innings1`). Mirror of batting-KM D7 (which reads the player's batting innings). New Batsman In fires on the first opposition wicket in overs 7–14 (override over = wicket+1 ≤ 15, never colliding with Death Defence at 16).
- **D8 — Card = two big tap buttons, reuses the KM overlay pattern.** Same overlay the batting Key Moments use (`KMOverlay/KMBox`); the bowling moments are just more entries in the same offer/decide flow, distinguished by which innings the cursor is in. Swipe animation deferred (polish).
- **D9 — Batting Key Moments, Boost, DRS all untouched.** This rung only adds the bowling-innings offers and the `BowlingKeyMomentPlan` policy.

---

## 4. The three archetypes

All fire during the **opposition's batting innings** (you bowling). Buttons map to `BowlingPlan.Kind`.

| # | Moment | Trigger | Prompt | Option A | Option B |
|---|---|---|---|---|---|
| 1 | 🎯 **Powerplay Exit** | over 7, always | "Powerplay's done — how do you bowl the middle?" | **Spin** (squeeze, `SPIN`) | **Pace** (keep at them, `PACE`) |
| 2 | 🔥 **New Batsman In** | first opposition wicket in overs 7–14 | "A new batter's in — how do you attack?" | **Pace** (rough up the new man, `PACE`) | **Spin** (choke the rebuild, `SPIN`) |
| 3 | 💀 **Death Defence** | over 16, always | "Last five overs — how do you defend?" | **Pace** (yorkers, `PACE`) | **Spin** (take the pace off, `SPIN`) |

The phase-correct/textbook reply (per the bowling-balance tilt) is Spin in the middle, Pace at the death — but the intent×kind matchup means an aggressive opposition can flip it (slog-happy batters punish the "wrong" kind into extra wickets *or* boundaries). That's the read.

**Deferred flavour variants of moment #2** (recorded, not built — easy to revisit): *Star on 49 / milestone* (fires when a danger batter nears a fifty — still resolves to pace/spin, needs a milestone-watch trigger) and *Danger Partnership* (fires when an unbroken partnership crosses a run threshold — needs threshold tuning). "New Batsman In" chosen this rung as the clean mirror of batting's Wicket Crisis (same ball-log trigger, lowest complexity).

---

## 5. Architecture

```
BowlingKeyMomentPlan (new, scripts/data/)  — exact mirror of KeyMomentPlan
  overrides: Array of {from_over:int, kind:int}   # kind = BowlingPlan.Kind
  effective_for_over(over, base_kind) -> int       # latest override at-or-before `over`, else base

BowlingPlan (extended, scripts/data/)
  key_moments: BowlingKeyMomentPlan = null         # null => plain phase rotation (byte-identical)
  for_over(over): consult key_moments over the phase default (mirror of IntentPlan.for_over)

MatchSession (extended, scripts/domain/)
  _bowl_km_plan := BowlingKeyMomentPlan.new()       # accumulated overrides
  _resim(): build a BowlingPlan { textbook phases + key_moments = _bowl_km_plan }, pass it into
            simulate_match_teams's player_bowling_plan slot (was null)
  _compute_km_moments(): ALSO add the 3 bowling moments, cursors into the OPPOSITION batting innings
  bowling_key_moment_offer(cursor) / decide_bowling_key_moment(from_over, kind)
            — OR fold into the existing key_moment_offer/decide if the {label,band|kind} payload
              can carry a "lever" tag (build decides the cleaner shape; both are pure + tested)

interactive_match scene (extended, scenes/interactive_match/)
  the existing KM overlay also fires on bowling-innings cursors; button -> decide -> resim -> resume
```

**Byte-identical guarantee (the gotcha to respect):** passing a non-null `player_bowling_plan` flips the sim into rotation mode (`match_resolver.gd:190`). In the **live game** the opponent brain already passes `opp_bowling_plan` (so rotation is already on), and an empty `BowlingKeyMomentPlan` over a `BowlingPlan.textbook()` base == the `null`→`textbook()` path the live game already runs ⇒ byte-identical. The empty-plan proof test (mirror of `test_empty_km_is_byte_identical_to_no_plan`) **must be set up in the live config** (`_opp_spec != null`, rotation on), exactly like the batting-KM byte-identical gotcha already recorded in the roadmap. For the `_opp_spec == null` preview/standalone path, `MatchSession` keeps passing `null` unless a bowling-KM override exists (so existing preview tools stay byte-identical).

---

## 6. Testing

- `BowlingKeyMomentPlan.effective_for_over` — base passthrough, single override, latest-wins, mid-phase (unit, pure).
- `BowlingPlan.for_over` with `key_moments` — override beats phase default; null = plain rotation.
- `MatchSession` empty bowling-KM == no plan (**byte-identical**, live config per §5).
- `MatchSession` bowling-KM offers fire at the right cursors (over 7 PP-exit; first opp middle-wicket; over 16 death) in the opposition innings; prefix before the override over is byte-identical.
- `decide_bowling_key_moment` overrides bowler kind from `from_over` onward and re-sims.
- Scene test: bowling-KM overlay shows on a bowling-innings trigger, button calls decide, replay resumes.
- D6 measurement (oracle, not a unit gate): `tools/sweep_interactive_levers.gd` bowling-KM arm — report the win-lift of each band, confirm no strictly-best.

**Red→green per CLAUDE.md:** judge red by the `Parse Error: Identifier "BowlingKeyMomentPlan" not declared` (GUT skips the file); judge green by the total count climbing + `All tests passed`. Run the whole suite (`-gdir=res://tests/unit`) each step.

---

## 7. Scope (in / out)

**In:** `BowlingKeyMomentPlan`, `BowlingPlan.key_moments`, the 3 bowling moments wired into `MatchSession` + the interactive scene, the byte-identical proof, the D6 measurement, a screenshot deliverable (a bowling moment paused in the real app).

**Out (deferred):** Field Set as a real card (needs a field-EV lever); Star-on-49 / Danger-Partnership trigger variants; opponent *bowling* Key Moments (the AI rotates via `OpponentBrain` already — it doesn't need decision cards); swipe animation / hi-fi card art (shared polish rung); a bowling Boost.

---

## 10. Results — the bowling lever is a real trade-off (D6 measured)

**Oracle:** `tools/sweep_interactive_levers.gd` §5 (the bowling-KM arm). 1.5★ reference build (35/30/30/30) vs the seven club opponents at the Club entry tour (brain on → bowling moments fire). Each arm forces the whole bowling innings one way via the two always-fire moments (Powerplay Exit @7 + Death Defence @16); `base` = the textbook phase rotation (no override). Smoke run **N=30×7 = 210 matches/arm** (full N=400 available, ~6.5 min):

| arm | win% | vs base |
|---|---|---|
| **base** (textbook P / S / P rotation) | **44.8%** (94/210) | — |
| bowl_spin (spin from over 7 on) | 36.2% (76/210) | **−8.6** |
| bowl_pace (pace from over 7 on) | 20.0% (42/210) | **−24.8** |

**Verdict: a real lever with real downside — NOT a free buff.** The phase-correct rotation (spin the middle, pace the death) is best; the *wrong* call costs **9–25 win-points**. Pace-everywhere is the worst (−24.8) because it wastes the middle overs where spin owns the matchup; spin-everywhere only mis-bowls the death (−8.6). This is the same shape as the batting Key Moments — phase-correct cricket is the reliable answer, a **learnable read**, and the intent×kind matchup (bowling-balance spec §4.2) means the right kind can shift against an aggressive opponent. So picking a side at each moment is a genuine decision: get it wrong and you lose more.

**Feel note for Nico:** at the entry tour the "textbook" reply (Spin at the PP-Exit, Pace at the Death) is the dependable best — i.e. there *is* a learnable correct answer per moment (just as aggressive batting was correct before the opponent brain made it punishable). That's healthy for an entry tour. If you ever want bowling moments to be a knife-edge dilemma even here, the lever to add is the deferred Field Set / a per-moment risk (e.g. attacking fields trade catches for boundaries) — recorded, not built.

**Deliverable:** `docs/mockups/bowling-key-moment-built-v1.png` (the 🎯 Powerplay Exit bowling card paused at over 7, Spin/Pace buttons), via `tools/preview_bowling_key_moment.gd`.

---

## 8. Deliverable for Nico

Launch the real game (per `feedback-launch-playable-not-screenshot`): from the hub, play your fixture, **bat through your innings, then watch the bowling innings pause** at the Powerplay Exit, at a New Batsman In if a wicket falls, and at the Death Defence — pick Pace or Spin on each and feel the opposition's chase change. Plus the screenshot proof `docs/mockups/bowling-key-moment-built-v1.png`. Plain-English wrap-up naming the one thing to look at.
