# All-Rounder Viability + Team Construction — Design

**Date:** 2026-06-09
**Theme:** 7c balance (follow-up to build-balance Slices 1–3) + a Theme-2 meta-layer decision
**Status:** Part 1 BUILT (2026-06-09, see §10). Parts 2 & 3 are recorded decisions.

---

## 1. Problem

Build-balance (Slices 1–3, PRs #27–#30) made every Player build win-neutral at the **team** level (~fair at even ★3). But Nico flagged a deeper concern about the **all-rounder build specifically**, on two fronts:

1. **Progression (Tons):** Tons — the career currency — are earned as `base contract × performance multiplier`, where the multiplier is raw **runs, wickets, Key Moments won** (CONTEXT.md). A pure batter maxes the runs term; a pure bowler maxes the wickets term; an all-rounder gets a moderate slice of both and, because measurable value concentrates, earns **less than either specialist**. So the meta-optimal move is to min-max into one discipline → **the all-rounder becomes a trap build.**
2. **Authenticity / participation:** a real all-rounder (Stokes, Jadeja) bowls their full 4-over quota and bats in the top order. Ours bowls only **2 overs** (the build→overs curve maps a 5/5/5/5 to 2). It under-participates.

Nico's framing: *"an all-rounder allows the team to specialize more in other areas"* — which is already true mechanically (the Slice-3 gap-fill makes a specialist Player's team carry an extra player of the opposite discipline). The missing piece is that this team-level value isn't reflected in the **Player's own reward or stat line.**

### Two distinct "all-rounder value" surfaces (the key reframe)

- **Does the all-rounder help the team *win*?** → **Already solved** by Slice-3 gap-fill (every build ~fair at even ★3). Not in scope here except to preserve it.
- **Does the all-rounder *progress / feel rewarded*?** → **The gap this design closes.**

### Empirical grounding — "fair" is win ≈ loss ≈ ~49.5%, not 50%

A cricket match has three outcomes: win / loss / **tie**. Measured over N=4000 even-★3 matches:

| build | win% | loss% | tie% |
|---|---|---|---|
| batter 8/8 | 49.5 | 49.6 | 0.8 |
| all-rounder 5/5 | 48.6 | 50.3 | 1.1 |
| bowler 2/8 | 47.8 | 51.0 | 1.2 |

So **fair = win ≈ loss**, which lands at **~49.5%** (ties take ~1% off the top — you can't reach 50% wins). The batter is genuinely dead-even; bowling-heavy builds currently sit a hair sub-even (lose ~2–3% more than they win). All balance targets below are stated as **win ≈ loss**, anchored to the batter's dead-even line, NOT chased to a theoretical 50.

---

## 2. Decisions taken (Nico's calls during brainstorming, 2026-06-09)

- **DA1 — All-rounder fix = parity, not advantage.** An all-rounder should earn *roughly the same* Tons as a specialist (removes the trap), not *more* (which would just flip the trap onto specialists). All three builds stay equally valid; the choice is playstyle + joker-fit.
- **DA2 — Two-part fix: 4-over participation + a visible Tons synergy bonus.** Confirmed by experiment that volume alone is insufficient (see §3.1), so both.
- **DA3 — The reward fix lives in the *Tons payout*, not the win-rate (already fair) and not the net-runs rating (kept as the honest performance stat).**
- **DA4 — Non-★3 team construction stays the current uniform star-offset (option A) for V1.** Per-player budget scaling (B) and lopsided-by-stars composition (C) are recorded as deferred texture.
- **DA5 — Batting-ish builds bowl *somewhat* (not zero).** A 7/7 bowls ~1 over, 6/6 ~2–3; only the pure batter (8/8) bowls 0 at baseline. This is worth the small balance cost, fixed by the conservation rounding lever (§3.3). The "~2 overs a season" token for a pure batter is a *deferred situational* mechanic (§3.5), not baseline.

---

## 3. Part 1 — All-rounder bowls its full 4 overs (BUILDABLE NOW)

### 3.1 Why volume alone isn't the fix (experiment, 2026-06-09)

Temporarily ramped the overs curve so the all-rounder bowls 4. Result: its **rating moved only 0.3 → 0.8** — still ~zero. Reason: the all-rounder is *average* at bowling, and the net-runs rating measures surplus *above an average player*, so 4 average overs net ~zero just like 2 did. **Participation buys authenticity, not viability.** Viability is Part 2's job. But the experiment also gave the all-rounder a real bowling line (0.42 wkts, a genuine spell) — worth having for the fantasy.

### 3.2 The change — the target overs curve

Re-shape the build→overs curve (`InningsTuning.bowl_overs_gain` / `bowl_overs_base`, consumed by `InningsResolver.player_overs`) to Nico's scale, where **"bowling stat" = attack + control**:

| build | bowling stat | overs/game (baseline) |
|---|---|---|
| 8/8/2/2 (batter) | 4 | **0** (token ~2/season is a *deferred situational* effect, §3.5 — not the baseline) |
| 7/7/3/3 | 6 | ~1 (bowls *somewhat* — Nico's call DA5) |
| 6/6/4/4 | 8 | ~2–3 |
| 5/5/5/5 (all-rounder) | 10 | **4** (the cap) |
| 4/4/6/6 → 2/2/8/8 | 12–16 | 4 (capped) |

So the ramp runs **batter 0 → all-rounder 4 overs across the batting↔all-rounder range**, then holds at the 4 cap for bowling-heavy builds. **Exact `gain`/`base` are a calibration output**, tuned against the sweep, not fixed here.

### 3.3 The balance cost to re-flatten

Forcing a **weak** bowler to bowl drags the team's bowling *below par*, via the Slice-3 bowling-conservation rule + integer rounding. Worked example — a 7/7/3/3 (attack 3) made to bowl 2 overs:
- player overs contribute `2 × 3 = 6` units; conservation wants teammates to cover `100 − 6 = 94` over 18 overs = 5.2 each;
- 5.2 **rounds down to 5** → teammates give `18 × 5 = 90`; team total = `96` vs the opponent's `100` → the team under-bowls → win% slips (~47 → ~45 in the test).

Since Nico wants 7/7 / 6/6 to bowl *somewhat* (DA5), we can't dodge the dip by keeping them at 0 — we must instead **fix the under-compensation at its root**.

**Re-flatten lever (in order):**
1. **Fix the conservation rounding leak** (primary) — when a *weak* Player bowls (attack below team average), conservation wants teammates *above* the team scalar to keep the total at 100, but a single integer scalar rounds the fraction away (the 5.2→5 in the worked example) and the team under-bowls. Fix by distributing the (overs−n) teammate overs as a **mix of `floor` and `ceil`** so their average hits the exact conserved value (e.g. 4 overs at 6 + 14 at 5 = 94, not 18 at 5 = 90). This holds the team total at 100 regardless of *who* bowls, so a part-timer bowling no longer drags the side below par. This is the principled fix that *lets* 7/7 / 6/6 bowl without a dip.
2. **`bowl_concentration_k`** and the **gap-fill distribution** (top-vs-tail) — the same fine-tuning screws used in Slice 3, for any residual.

**Target:** win ≈ loss across all 7 builds (anchored to the batter's dead-even ~49.5), within ~±2%. Oracle = `tools/build_spectrum_sweep.gd`; loop adjust → re-sweep → compare. The unit tests assert invariants (determinism, directionality, the conservation identity — *total team bowling ≈ over_limit·S for any Player build/overs*), not the calibrated magnitudes.

### 3.4 Scope guard

The 4-over cap itself is **unchanged** (realism anchor). Player batting position is **unchanged** (the all-rounder still bats #5). Only the overs *curve* moves. The scalar `simulate_match` path stays byte-identical (the change is in tuning data + `player_overs` + the conservation distribution, which the scalar callers already use the same way).

### 3.5 Deferred — situational over-allocation (the "~2 overs a season" for a near-pure batter)

The baseline curve gives a pure batter **0** overs. But in the real game a near-pure batter occasionally *should* bowl a token over or two across a season — not from their skill, but from **situational factors**: the captain turns to a part-timer when a frontline bowler is **fatigued**, **out of form**, being **milked**, or the match state calls for a surprise. This is the realistic source of the "~2 overs a season" Nico described. It is **deferred**: it needs a bowler-state model (fatigue/form per bowler) that doesn't exist yet (per-bowler husbanding is already deferred to a possible rung 4c). Documented here so the baseline-0 decision is understood as *"0 from skill; the rare token comes later from situational mechanics,"* not *"a batter can never bowl."*

---

## 4. Part 2 — Visible "all-rounder bonus" in the Tons payout (FORWARD DESIGN)

**Builds with the Career/meta rung** — there is no Tons-earning system in code yet, so this is a recorded decision + formula shape, implemented when that rung lands.

### 4.1 Shape

The Tons performance reward gains a **synergy term**:

```
tons_performance = batting_contribution + bowling_contribution + synergy
synergy = k * pairing(batting_contribution, bowling_contribution)   # 0 unless BOTH are non-trivial
```

- **Based on raw dual contribution** (runs + wickets/economy), **NOT** net-vs-par — because an average-at-both player nets ~zero vs par, so a par-based bonus wouldn't lift them (the §3.1 finding). The synergy must reward the *fact* of contributing in both disciplines.
- `pairing(...)` returns ~0 if either side is trivial (a specialist gets no synergy) and grows with the *smaller* discipline's contribution (rewards balance). A **qualifying threshold** (a real spell *and* a real innings) stops it being gamed by a token over.
- `k` is calibrated to **parity**: tune until Tons-per-season is roughly flat across the build spectrum. **Oracle = the same build-spectrum sweep** (extend it to emit Tons-per-match once the payout exists).

### 4.2 Legibility (why visible)

Surface it on the Result screen, e.g. *"All-rounder bonus: +12 ₸ — contributed with bat and ball."* This turns the all-rounder from "not punished" into "feels rewarded," and makes the *"frees the team to specialize"* rationale a tangible thing the player sees.

### 4.3 Separation of concerns

- **Net-runs rating** (`PlayerRating`, already built) = the honest "how well you played" stat. **Unchanged** — it stays a "smile" (specialists rate higher) because that is what net-runs honestly measures.
- **Tons payout** = the deliberately *balanced reward*. The synergy lives only here.

---

## 5. Part 3 — Non-★3 team construction (DECISION + DEFERRAL)

**V1 = the current uniform star-offset (option A).** A weaker team is the standard XI shape (6 batter / 1 all-rounder / 4 bowler) with every stat shifted by a uniform offset tied to the team's star-derived strength (Slice-2 D6). Because the Tour band is narrow (spread 1.5), a 1★ team sits ~1 point below ★3 per stat. Composition never changes with stars — only magnitude. Sufficient: directionality (stronger team wins more) already holds and the balance work assumes it.

**Deferred (revisit only if weak teams feel too samey):**
- **(B) Per-player budget scales with stars** — genuinely weaker *individuals* on a weak team (same composition shape).
- **(C) Composition varies by stars/tour** — lopsided weak teams (no genuine all-rounder, or strong-bat/weak-bowl), so weak teams feel texturally distinct.

---

## 6. Defaults recorded (change in review if wrong)

- "Fair" target = **win ≈ loss** (~49.5% wins at even ★3), within ~±2%; ties ~1%.
- Part 1 overs curve: pure batter (8/8) bowls 0; 7/7 ~1, 6/6 ~2–3, all-rounder (5/5) hits the 4-over cap, bowling-heavy stay at 4; exact `gain`/`base` are calibration outputs (§3.2). Re-flatten primarily via the conservation floor/ceil rounding fix (§3.3).
- Part 2 synergy: raw-contribution based, parity-calibrated `k`, qualifying threshold, visible on Result; net-runs rating untouched; built with the Tons/Career rung.
- Part 3: uniform offset (A) for V1; (B)/(C) deferred.

---

## 7. Decomposition / sequencing

- **Part 1** → its own implementation plan + PR **now** (a calibration rung; test-first; mirrors Slice 3).
- **Part 2** → recorded here; spec'd into the Career/meta rung when Tons-earning is built.
- **Part 3** → no work; the deferral is the decision.

## 8. Deferred / out of scope

- The Tons-earning system itself (base contract, performance multiplier wiring) — Part 2 plugs into it later.
- Key Moments as a Tons input (listed in CONTEXT alongside runs/wickets) — folds in with the Tons rung.
- Per-player budget scaling / lopsided weak teams (Part 3 B/C).
- **Situational over-allocation** — fatigue/form/match-state pushing a captain to use a part-time bowler (the source of a near-pure batter's "~2 overs a season"). Needs a per-bowler state model (tied to deferred husbanding, rung 4c). See §3.5.
- Any change to the 4-over cap, batting-position curve, or the net-runs rating model.

---

## 10. Part 1 calibrated baseline (2026-06-09, BUILT)

Part 1 shipped: the all-rounder bowls its full 4 overs, and bowling conservation is now exact (float). Final dials:
- `InningsTuning.bowl_overs_gain = 13.0`, `bowl_overs_base = -2.6` → overs by build: 8/8→0, 7/7→1, 6/6→3, 5/5→**4**, 4/4→4, 3/3→4, 2/2→4.
- `InningsTuning.bowl_concentration_k = 1.0 → 0.5` (exact conservation is tighter than the old integer version, so the strong-bowler penalty was re-balanced down).
- `_conserved_bowling` now returns an **exact float**; the bowling-stat params are widened to `float` down `simulate_match → simulate_innings → resolve_ball`. **Rating dials unchanged** (`sr_par=107.4`, `rr_par=9.0`, `wicket_value=2.0`) — the 5/5 build's SR (106.7) and econ (8.99) are essentially unchanged (it still bats #5; it just bowls more at the same rate), so the average player still rates ~0.

Build-spectrum sweep (2000 even-★3 matches/build, neutral Intent):

| build | win% | wkts/match | rating | r-bat | r-bowl |
|---|---|---|---|---|---|
| 8/8/2/2 (batter) | 48.7 | 0.00 | 9.1 | 9.1 | 0.0 |
| 7/7/3/3 | 46.9 | 0.07 | 4.4 | 5.4 | −1.0 |
| 6/6/4/4 | 48.2 | 0.25 | −0.0 | 0.9 | −1.0 |
| 5/5/5/5 (all-r) | 48.0 | 0.42 | 0.7 | −0.0 | 0.9 |
| 4/4/6/6 | 48.9 | 0.53 | 3.3 | −0.1 | 3.5 |
| 3/3/7/7 | 48.4 | 0.66 | 6.4 | −0.1 | 6.5 |
| 2/2/8/8 (bowler) | 48.6 | 0.82 | 9.6 | −0.1 | 9.7 |

**Win-rate: flat — every build 46.9–48.9 (win ≈ loss), spread 2.0** (flatter than the Slice-3 baseline's 4.1), and the all-rounder bowls a real 4-over spell (0.42 wkts/match). The exact-float conservation removed the weak-part-timer dip that the integer version caused (7/7/6/6 lifted from ~45.8 to ~47–48). **Rating: still a "smile"** (batter 9.1 ≈ bowler 9.6; all-rounder valley ~0.7) — exactly as the design predicts; **Part 2 (the Tons synergy bonus) is the parity fix for the all-rounder's reward, not this.** Realisation note: §3.3's proposed per-over floor/ceil *integer* mix was achieved more cleanly as an exact **float** conserved value (same outcome — team total held exactly — far less surface). 356 tests green.
