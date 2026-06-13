# World-scale v2 — display layer + fresh-player re-peg — design

**Date:** 2026-06-13 · **Rung:** world-scale v2 (calibration) · **Branch:** `hero-world-calibration`
**Mode:** AFK — default decisions recorded as WS1–WS8 (project CLAUDE.md policy).

---

## 1. Goal (plain English)

Nico's two complaints, from the season-table + calibration grid:
1. **A freshly-created hero is too big** — bat card ~32 = 2.6× an average Club player, only 0.9× at Province Premier. You're built for the *top* of the grid but *start* there, so there's no climb.
2. **The /100 scale is barely used** — Province Premier averages ~37 (internal); a top league should read ~85, the best team ~90, and a maxed player should reach 100.

Nico's target (his words, 2026-06-13): *"maxed hero is 100. all players can become 100 if rng allows. premier provincial average 85, best team 90."* Plus the earlier ruling: a fresh hero ≈ a weak 1★ player (~11).

## 2. The decision: display layer, not an internal rescale (WS1)

**WS1 — deliver the 0–100 world via a DISPLAY transform over the existing internal scale, plus a genuine fresh-player re-peg. NOT a full internal rescale.** (Nico: "you decide", 2026-06-13.)

Why. The sim's scores, difficulty curve and entire balance ledger (45 joker bands, the ₸ economy, build-equality, the difficulty ladder, the fair-fight floor) depend on the **bat−bowl strength difference within a match** — which is set by the *internal* world span (Club ~12.5 → Province best ~46.5, a ~3× ladder tuned across ~15 rungs). The absolute display numbers are a labelling choice. So:

- **(a) the real gameplay fix** — a fresh hero that starts weak and grows — is a player-stat re-peg (creation default + cost curve), done genuinely.
- **(b) the 0–100 look** — Province 85/90, you to 100 — is a monotonic display transform applied to every *shown* card/strength value. The sim keeps running on internal numbers, so the balance ledger is preserved by construction.

The alternative (genuinely stretch the internal world to a 6.5× span and re-derive the scoring math) would change the tuned difficulty curve and force a full ledger re-run for a number the player never sees as anything but the display. Rejected as poor value/risk; recorded as a possible future rung if "the real number must equal the shown number" ever becomes a requirement.

## 3. The display transform (WS2)

**WS2 — `Display.to_card(internal: float) -> float`**, a pure, monotonic piecewise-linear interpolation through Nico's anchors. The SAME transform applies to player attributes and team strengths (so they're comparable on screen). Anchor table (internal → display):

| Internal | What it is | Display |
|---|---|---|
| 0 | floor | 0 |
| 11 | a weak Club player / fresh hero | 11 |
| 12.5 | Club average (tour mean d1) | 13 |
| 31.25 | ★3 mid-tour (REF_SCALAR) | 67 |
| 37.5 | Province Premier average (d20 mean) | 85 |
| 46.5 | Province Premier best team (4.5★) | 90 |
| 60 | the attribute cap | 100 |

(31.25→67 falls out of the interpolation; recorded so "an average pro reads ~67" is intentional.) The transform is display-only — never fed back into the sim. A matching `Display.to_card_round()` returns an int for labels.

## 4. Fresh-player re-peg (WS3–WS5)

**WS3 — a fresh hero starts ≈ a weak Club player.** Creation budget drops so a fresh build sits at internal ~11–13 per attribute (display ~11–14), not ~30–35.
- `CREATION_TOTAL 125 → 46` (internal). Default build **13/11/11/11** (sum 46, classifies ALL_ROUNDER; display ~14/11/11/11).
- Sliders re-ranged (internal): `CREATION_MIN 5 → 3`, `CREATION_MAX 50 → 25`, step 1 (display readouts via `Display`). A fresh specialist can reach internal ~25 in one axis (display ~50) — strong in one thing, weak overall, balanced by build-equality.
- **`ATTR_CAP` stays 60** (displays 100) — unchanged. The player grows internal 46 → 240 (4×60) over a career; display 11 → 100.

**WS4 — re-peg the cost curve.** The player now buys ~+194 internal points (46→240) instead of +115 (125→240), so `EconomyTuning.attr_cost_base` drops to keep max-out near the naive line's median (~season 50). Re-measured with `career_preview` per arm.

**WS5 — build-equality holds across the player's whole range (the hard requirement).** Sim/scoring/joker/economy core is UNCHANGED, so the build-equality measured at sum-125 is preserved. But the player now spends the game at sum 46 → 240, so the ledger ADDS a build-equality check at a low total (~46) and a high total (~240), not just 125. Expected to hold (logit-space balance is ~scale-invariant); a break is a finding, not a planned re-tune.

## 5. Where the transform is applied (WS6)

**WS6 — display the transformed value wherever a card or team strength is shown to Nico; the sim and saved data stay internal.**
- Tools: `calibration_grid.gd`, `season_table.gd`, `one_match.gd`, `career_*` tools — card/strength columns show `Display.to_card`.
- UI scenes (player creation, career screens) — show display values; creation sliders operate in internal but label via `Display`.
- Saves, sim, economy, jokers: untouched (internal).

## 6. Out of scope (WS7)

**WS7 —** no change to: the scoring math (base_w/base_r/k_w/k_r), the world's internal difficulty span / `mean_frac` / `SPREAD_RATIO`, joker magnitudes & prices, the ₸ economy formula, the difficulty ladder brains, the fair-fight floor, save migration. The underdog all-out rate (30→58%) is the star-gap working as designed (measured, not a bug) — left as-is.

## 7. Test plan (WS8) + ledger

**WS8 — TDD** (red = parse error / failing assert, green = count climbs past 541):
1. `Display.to_card` — hits every anchor exactly, monotonic, identity-ish at the bottom, 60→100. New `test_display.gd`.
2. Creation: validator accepts the new 46-budget builds, rejects 125-scale; default classifies ALL_ROUNDER. Update `test_card_scale.gd` creation constants + creation/draft tests.
3. Existing suite stays green (sim untouched → most tests unaffected; only creation-constant + default-build literals move).

**Re-verification ledger** (record in §9):
| Check | Oracle | Gate |
|---|---|---|
| Fresh hero ≈ weak Club | `calibration_grid.gd` | fresh hero ~1.0× the Club average (was 2.6×) |
| Display anchors | `test_display.gd` | Province avg→85, best→90, cap→100, fresh→~11 |
| Max-out timing | `career_preview.gd` per arm | max-out ~season 50 after `attr_cost_base` re-peg |
| Build equality (low/mid/high total) | `build_spectrum_sweep.gd` | spread ≤ ~2.5 pts at sum 46 / 125 / 240 |
| Scores / joker / economy | (unchanged by construction) | no oracle needed — sim core untouched |

## 8. Plan

1. `Display` class + tests (the transform).
2. Creation re-peg (constants, default, sliders, validator) + tests.
3. Wire `Display` into the tools (+ UI creation labels).
4. `attr_cost_base` re-peg via `career_preview`; build-equality low/high check.
5. Re-run `calibration_grid` → refresh `calibration-v1.html` showing display values + the fixed fresh ratio.
6. Roadmap + PR.

## 9. Findings (in progress)

**Built (547 tests green, +6):** `Display.to_card` transform (`scripts/domain/display.gd` + `test_display.gd`); creation re-peg (`CREATION_TOTAL 125→44`, range `[3,25]`, default 11/11/11/11, sliders step 1); `Display` wired into the build scene readouts, `calibration_grid.gd`, `season_table.gd`; `attr_cost_base 13→7`.

**Headline — the scale fix lands (`calibration_grid.gd`, /100 display):**
- Club start: world 13 avg, fresh hero **0.9× the average** (was 2.6×). Scale gap closed.
- Province Premier: world **85 avg / 90 best** (Nico's exact target); maxed hero (60) → **100**.
- League bat≈bowl every cell (unchanged); typical scores real-T20 131→156 (sim core untouched).

**Pacing (WS4) — re-pegged, final target is Nico's call (deferred "Awaiting A"):** the weaker fresh hero climbs 44→240 (vs 125→240), so at the old base 13 it maxed S89. `attr_cost_base 13→7` → attr_only max-out **S67**, completion median **74** (was 85). Sub-linear (income rises with skill), so hitting ~50 needs Nico's target + 1–2 more `career_preview` runs.

**Open / observed:**
- Early-game feel: a weak fresh hero ON the 1.5★ underdog team posts very low season-1 scores (29–60 all out vs the league's ~131) — the bottom-of-the-world experience. Acceptable "earn it" or too punishing? Nico's feel call (couples with the pacing — how fast you grow out of it).
- **WS5 build-equality at low/high totals NOT yet run** (sim core unchanged → sum-125 equality preserved by construction; the 46/240 check is pending). Joker/economy/scoring ledger untouched by construction.
