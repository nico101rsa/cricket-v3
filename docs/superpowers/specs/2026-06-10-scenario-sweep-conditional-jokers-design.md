# Scenario sweep — honest measurement of conditional & synergy jokers (Theme 7c balance) — Design

> **Rung 3 of the balance-tune arc** (rung 1 = fair-fight baseline, rung 2 = joker re-tune to bands).
> This rung closes the rung-2 residual (§10.3 of `2026-06-09-joker-retune-rarity-bands-design.md`):
> the neutral fixed-scenario sweep **cannot measure conditional jokers' true strength**, so ~13 jokers
> (incl. 4 of 6 Legendaries) read weak only because their trigger never fires. It is the prerequisite
> for honestly **pricing** jokers in rung D (the ₸ economy).

Date: 2026-06-10 · Status: design approved (Nico, 2026-06-10) · AFK rung.

---

## 1. Why now

Rung 2 tuned every *unconditional* joker to its rarity band against the 48.1% fair-fight floor, and
found a hard limit: the single neutral scenario (even ★3, balanced build, one fixed game-plan)
under-fires conditional jokers. They read +0–3% **by fire-rate, not magnitude** (DB4). You cannot
honestly *price* a joker (rung D) whose strength you cannot *measure*. This rung builds the
measurement.

## 2. Goal & success criterion

Produce an **honest strength number for every joker** by measuring each one in a context where its
trigger actually fires, and **buff the genuinely under-powered ones** so their *realized* (season-
average) strength matches their rarity band.

**Done when:**
1. Every conditional joker in §10.3 has a measured in-condition delta (vs a same-context baseline).
2. Every synergy/enabler joker has a measured marginal-in-combo contribution.
3. A **fire-rate** is recorded per conditional joker (the rung-D pricing input).
4. Under-band *uncontrollable* jokers are buffed to realized-band (§4); over-ceiling stacks nerfed.
5. No realistic single joker **or stack** is an auto-win.
6. Full GUT suite green (≥363, magnitude asserts rebaselined).

**Target bands** (unchanged from rung 2): Common +1–4% · Rare +4–7% · Legendary +7–12% · Enablers ~0% solo.

## 3. The core principle — measure in the context that fires it

A joker that does nothing in the neutral sweep is not weak; it is **dormant**. Three kinds of context
make a joker fire, all measured the same way — *give it the context, compare against that-context's own
no-joker baseline*:

| Context | What it supplies | Example jokers |
|---|---|---|
| **Scenario profile** | a game state (batting 2nd, chasing) | Chase Master, Match-Winner's Vigil |
| **Designed combo** | the partner joker it's built to pair with | Form sources ↔ Ride the Wave / Hot Streak |
| **Stack ceiling** | the strongest realistic multi-joker build | any synergy cluster |

**Same-context baseline is mandatory.** A chasing joker is measured against a *no-joker chase*, not the
standard baseline — otherwise "chasing is hard" gets blamed on the joker. Each profile carries its own
baseline arm.

## 4. The tuning rule — realized-to-band, gated on controllability

**(Supersedes rung-2 DB4.)** Rung 2 left dormant jokers at firing-strength. Nico's call (2026-06-10):
**a rarely-firing joker should be buffed to compensate** — a situational Legendary should be *nuclear
when it fires* so it averages out to Legendary band over a season. This is genre-authentic (Balatro
situational cards) and it **simplifies rung-D pricing** (every Legendary averages the same → no separate
situational discount).

> **Tune so that  (strength-when-it-fires) × (fire-rate a player can realistically achieve) ≈ rarity band.**

**The guardrail — controllability.** "Fire-rate a player can realistically achieve" is the key, because
some triggers the player *chooses*:

- **Uncontrollable** (random / emergent) → the real buff candidates. The player can't farm them, so
  buffing to realized-band just rewards the prepared-but-unlucky. Capped at the passive fire-rate.
  - *Chase Master* (bat 2nd only when you lose the toss, ~50%), *Match-Winner's Vigil*, *Wicket Maiden*.
- **Controllable** (player sets the field / intent / bowling change / boost press) → already fair at
  in-condition band, because the achievable fire-rate ≈ 100% (realized ≈ in-condition). **Do not over-buff** —
  doing so re-creates the Review Master auto-win (a player drives the condition to 100% and it's a +30% win).
  - *Strike Bowler, Pace Pack, Spinner's Web, First-Change, The Trap, Attack the Stumps, Cordon Killer,
    Dead Bat, Block the Shine, Rotate the Strike*, all Boost-press jokers.

**Accepted feel trade-off (Nico, 2026-06-10):** buffed situational jokers are *swingy* — a dead slot
most matches, a game-winner occasionally. That variance is wanted (it rewards build-crafting around a
joker), opted into knowingly.

## 5. The synergy / combo problem

A lone Form *source* (e.g. The Sheet Anchor) reads ~0 because it has nothing to enable — it is a *key*,
not a payoff. You measure the door it opens, not the key.

- **5.1 Use the *designed* combos, not all pairs.** 45 jokers = ~1000 pairs (an explosion). The author
  already encoded the synergy clusters as id-sets in `sweep_jokers.gd` (`form_combo_ids`, `boost_stack`,
  `wicket_hunter_ids`, `reviewer_stack`, …). We measure those, not every combination.
- **5.2 Attribution = marginal-add.** A joker's worth in a combo =
  `delta(combo with it) − delta(combo without it)`. One extra "partner-core minus the enabler" baseline
  arm per cluster makes this computable (no full Shapley). Answers "does this joker earn its slot?".
- **5.3 An enabler is in band if the value it *adds to its intended combo* is in its rarity band** — the
  synergy-analog of in-condition delta. Buff/nerf on that number, same realized-to-band + controllability
  guardrail.
- **5.4 The combo ceiling (the one genuinely new gate).** A combo *should* beat the sum of its parts —
  committing two slots + the draw-luck of finding both deserves a payoff above a single-joker band, so
  combos legitimately exceed Legendary band. The hard limit is **no auto-win**: the strongest realistic
  stack stays meaningfully below the Review-Master-was-too-much line (+28%). Target: a committed synergy
  build wins convincingly but loses ~1 in 3 (≈ ≤ +20% win-delta). The existing "full pool (all 45)"
  +51.8% arm is illustrative only (never held at once) and is **not** a balance target.

## 6. The work

### 6.1 Scenario profiles (`tools/sweep_jokers.gd`)
Generalize the single `_scenario` into a small set of **profiles**, each a (game-plan + forced
conditions) bundle with its **own no-joker baseline arm**. Most controllable conditions already fire in
today's plans (intent/field/bowling/boost/DRS are all threaded) — the genuine gaps:

- **Chase profile** — Player forced to bat 2nd against a competitive target, so `is_chase` holds and
  Chase Master / Vigil fire. **Needs a toss-force seam** (§6.2).
- **Standard profile** — today's scenario, kept as the unconditional-joker anchor + regression check.
- (Form / boost / bowling-change / DRS conditions already covered by the existing plans + combo arms;
  reused, not rebuilt.)

Each conditional joker is reported under the profile that fires it, against that profile's baseline.

### 6.2 Toss-force seam (`scripts/domain/match_resolver.gd`)
Add an optional trailing param to `simulate_match_teams` — `force_player_bats_first: int = -1`
(-1 = use the seeded toss; 0 = Player bowls first / bats 2nd; 1 = Player bats first). Additive,
off-by-default → the default path stays byte-identical (existing tests untouched). The Chase profile
passes `0`.

### 6.3 Marginal-combo baselines (`tools/sweep_jokers.gd`)
For each designed synergy cluster, add the "partner-core without the test enabler" arm so §5.2's
marginal-add is computable. Print marginal contribution alongside the stack delta.

### 6.4 Fire-rate measurement (`tools/sweep_jokers.gd`)
For each conditional joker, measure how often its trigger fires in **standard play** (the passive
fire-rate) — e.g. the fraction of matches where `is_chase` holds for the batting side. Emit it in the
JSON per arm. This is the rung-D pricing input; it does **not** change the magnitude.

### 6.5 Targeted buffs (`scripts/data/joker_catalog.gd`)
Buff the *uncontrollable* under-band jokers (Chase Master, Match-Winner's Vigil, Wicket Maiden, and any
other §10.3 joker that is both uncontrollable and under-band once measured) so realized ≈ band at the
achievable fire-rate. Empirical loop: edit `mult`/`drs_p_bonus` → re-run profile → check band → repeat
(2–4 iterations each, exactly the rung-2 dial loop). Nerf any combo that breaches the §5.4 ceiling.
Leave controllable jokers alone (already in band in-condition).

### 6.6 Rebaseline + docs
Update the magnitude asserts in `tests/unit/test_joker_catalog.gd` for every buffed joker; refresh
`docs/joker-pool-v1.md` (magnitudes + the new fire-rate column) and the viewer `DATA`.

## 7. TDD

- **Toss-force seam** (`tests/unit/test_match_resolver.gd`): default (-1) byte-identical to current;
  force-0 → Player bats 2nd (and force-1 → bats 1st), deterministic. Red via parse-of-absent-param /
  failing assert; green by count climbing.
- **Catalog magnitudes** (`tests/unit/test_joker_catalog.gd`): rebaselined asserts for each buffed joker.
- The sweep is a **tool**, not a test — its honest-delta / fire-rate / marginal numbers are recorded in
  the spec §10 (findings) and the pool doc, judged by eyeball against the bands (same as rung 2).

## 8. Key decisions (record)

- **DS1 (Nico):** measure conditional jokers in firing contexts, then **buff** under-powered ones —
  *not* measure-only. Reverses rung-2 DB4's "leave dormant jokers at firing-strength".
- **DS2 (Nico):** buff to **realized** (fire-rate-weighted) band, so situational jokers are nuclear-when-
  they-fire. Accepts the resulting swinginess.
- **DS3 (Nico + analysis):** **controllability guardrail** — only buff *uncontrollable* triggers; leave
  player-controllable ones at in-condition band (else auto-win exploit).
- **DS4:** synergy jokers measured **as designed combos** (not all pairs); attribution by **marginal-add**;
  an enabler is in band if its marginal-in-combo contribution is in band.
- **DS5:** combos may exceed single-joker bands by design; the only hard ceiling is **no auto-win**
  (strongest realistic stack ≤ ~+20% win-delta, well under the +28% danger line).
- **DS6:** toss-force is an additive, off-by-default sim param — default path byte-identical.
- **DS7:** fire-rate is measured and emitted **for pricing (rung D)**; it does not alter magnitudes.

## 9. Files touched

- `tools/sweep_jokers.gd` — scenario profiles, per-profile baselines, marginal-combo arms, fire-rate.
- `scripts/domain/match_resolver.gd` — `force_player_bats_first` param (additive).
- `scripts/data/joker_catalog.gd` — targeted buffs.
- `tests/unit/test_match_resolver.gd` — toss-force tests.
- `tests/unit/test_joker_catalog.gd` — rebaselined magnitude asserts.
- `docs/joker-pool-v1.md` — magnitudes + fire-rate column.
- `docs/mockups/distribution-viewer-v1.html` — refreshed `DATA`.
- `PROJECT_ROADMAP.md` — status + handoff.

## 10. Findings & residuals (built — fill in)

_To be completed during the build: honest in-condition delta table (whole pool), fire-rate per
conditional joker, marginal-in-combo numbers, the buffs applied, and the strongest-stack ceiling check._
