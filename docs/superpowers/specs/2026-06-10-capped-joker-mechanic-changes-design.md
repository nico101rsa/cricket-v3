# Mechanic changes for the two magnitude-capped jokers — Design

> **Follow-up to rung 3** (`2026-06-10-scenario-sweep-conditional-jokers-design.md` §10.2). That rung
> proved two Legendary/Rare conditional jokers **cannot reach realized band by magnitude alone** — their
> first mechanic *saturates*. The fix flagged there (and approved by Nico, 2026-06-10) is a **mechanic
> change**: give each a **second effect component that converts where the first one is wasted**.

Date: 2026-06-10 · Status: approved (Nico) · AFK rung · inline TDD.

## 1. The problem (from rung 3)

- **The Chase Master** (Legendary): runs ×1.40 while chasing + Aggressive. The runs-mult **saturates
  against the chase win-ceiling** — runs scored past the target are wasted, so cranking 1.20→1.70 moved
  in-condition only +7.0→+7.9%. It can't reach realized band by a bigger number.
- **Wicket Maiden** (Rare): wicket ×1.45 for 6 balls after a Player bowling wicket. Its extra wicket-
  chance only pays off **if another wicket actually falls** in the window — a rare emergent event — so it
  is participation-capped, and cranking the mult risks a wicket→window→wicket spiral.

## 2. The fix — add a second component that always converts

Both jokers' first component only pays off in a narrow case (runs past target = waste; extra wicket-
chance = only helps if a wicket falls). Add a second component that converts in the *common* case:

- **The Chase Master + composure (survival).** Add a **wicket ×<1** row (reduce the Player's dismissal
  chance) gated identically (chasing + Aggressive). **Not getting out** wins close chases even when the
  extra runs are wasted — so survival converts where runs saturate. Thematically: a chase-master both
  scores fast *and* doesn't throw it away. The engine already supports multi-row jokers (Hot Streak =
  runs + wicket), so this is additive, no new mechanic primitive.
- **Wicket Maiden + economy (dot pressure).** Add a **runs ×<1** row for the post-wicket window (concede
  fewer runs after a wicket). Economy **always** converts (every ball conceded matters), whereas extra
  wicket-chance only helps if a wicket falls — and it is thematically exact: a *wicket maiden* is an over
  with a wicket **and no runs**. Same multi-row pattern.

## 3. Tuning

Empirical, against `tools/sweep_jokers.gd` (Chase Master via the **chase** profile; Wicket Maiden via the
standard profile, since its FORM_BOWL trigger fires there). Target each joker's **realized** strength into
its rarity band (Common +1–4 / Rare +4–7 / Legendary +7–12), where realized = in-condition × fire-rate.

- Chase Master fire-rate ~0.50 (toss) → in-condition can climb to ~+20% before realized tops Legendary
  band, so there is headroom; no auto-win risk.
- Start: Chase Master keep runs ×1.40, add **wicket ×0.80**; Wicket Maiden keep wicket ×1.45, add **runs
  ×0.85** over the window. Tune from there.

**Verify the hypothesis first:** if composure breaks Chase Master's ceiling (in-condition climbs past the
~+8% runs cap), the approach is validated; carry it to Wicket Maiden. If a second component *also*
saturates, that is itself a finding — record it and stop rather than cranking.

## 4. Decisions (record)

- **DM1 (Nico):** fix the capped jokers with a **mechanic change** (a converting second component), not by
  cranking the saturated first component.
- **DM2:** Chase Master's second component = **survival** (wicket ×<1, same gate); Wicket Maiden's =
  **economy** (runs ×<1 over the window).
- **DM3:** both via the existing **duplicate-id multi-row** pattern — additive, no new primitive.
- **DM4:** tune to **realized** band (in-condition × fire-rate), same as rung 3.

## 5. Files touched

- `scripts/data/joker_catalog.gd` — add the second effect row to each joker; tune magnitudes.
- `tests/unit/test_joker_catalog.gd` — assert each joker now has 2 rows + the magnitudes.
- `docs/joker-pool-v1.md` — update both jokers' verb compositions + the rung note.
- `docs/mockups/distribution-viewer-v1.html` — refreshed `DATA`.
- `PROJECT_ROADMAP.md` — status + handoff.

## 6. Findings (built 2026-06-10)

**Both mechanic changes worked — the converting second component is the unlock.** Inline TDD, **366
tests green**. N=2000/arm.

### The Chase Master — composure broke the saturation ceiling
The runs-mult alone capped at +7.2% in-condition (rung 3). Adding the composure (survival) row lifted it:

| Config | In-condition (chase) | Realized (×0.50 toss) |
|---|---|---|
| runs ×1.40 only (rung 3) | +7.2% | +3.6% |
| runs ×1.40 + composure ×0.80 | +10.2% | +5.1% |
| **runs ×1.40 + composure ×0.62** (final) | **+13.1%** | **+6.6%** |

Realized **+3.6% → +6.6%** (Legendary floor, within tolerance) — composure roughly doubled the realized
strength because *not getting out* wins close chases even when extra runs are wasted. **No blowout**
(player-runs mean 9.3 vs 9.9 baseline, max 113 vs 107). Locked **composure ×0.62**.

### Wicket Maiden — economy lifted it into band
The wicket-mult alone read +1.0% (only pays off if a second wicket falls). Adding the economy (runs ×<1)
row over the same 6-ball window:

| Config | Standard win-delta |
|---|---|
| wicket ×1.45 only (rung 3) | +1.0% |
| wicket ×1.45 + economy ×0.85 | +2.1% |
| **wicket ×1.45 + economy ×0.62** (final) | **+4.0%** (Rare floor) |

Economy converts where the wicket-chance can't (every conceded ball counts), and it does **not** spiral
(it causes no extra wickets), so it is the safe lever. Locked **economy ×0.62**.

### Takeaway
The rung-3 "magnitude-capped" residual is resolved: a saturated/rare-trigger first component is fixed not
by a bigger number but by a **second component that converts in the common case** (survival for a chase,
economy for a wicket window). Both jokers now reach their rarity-band floor. Wicket Maiden remains
fire-rate-limited (it only fires on a Player bowling wicket) so it sits at the Rare floor, not mid-band —
an honest, accepted cap.
