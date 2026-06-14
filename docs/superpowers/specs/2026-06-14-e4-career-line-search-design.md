# E4 — Optimal career-line search (design)

**Date:** 2026-06-14
**Rung:** 7c-E4 (the last 7c-E measurement rung)
**Branch:** `e4-career-line-search`
**Status:** spec
**Supersedes/feeds:** the deferred pacing re-peg (world-scale v2's `attr_cost_base` long-climb) — E4's *optimal* seasons-to-complete is the number a re-peg should target, not the naive ~78.

---

## 1. Plain-English what & why

A career has two strategic levers the player controls: **how you climb** the 24-cell grid (which tour to play, when to chase up to the next level vs stay) and **how you spend** ₸ at the Kit Room (attributes vs jokers vs balanced). Until now every measured career used **one** hardcoded climb line (the "naive" line in `career_preview.gd`: lowest unbeaten tour, accept the first cross-up once the level is won) crossed with the 3 spend presets.

E4 searches the climb axis properly and grids it against spend, to answer:

1. **What is the *optimal* line** — the climb×spend combination that completes the career fastest (and most reliably)?
2. **Is any line dominant?** A single combination that wins on *both* completion-rate and time-to-beat would mean the game has a solved meta — an ADR-0003 depth red flag (the player should face a genuine trade-off, not a recipe).
3. **What is the honest time-to-beat under optimal play** (seasons + matches → hours)? This refines the naive ~78-season figure and is the target the pacing re-peg aims at.

A career is **single-agent** — the opponent brain is fixed per cell (E3's `DifficultyLadder`), so there is no self-play equilibrium to converge (unlike E1/E2). E4 is therefore a plain optimization over a small set of named strategies, measured by Monte-Carlo over seeds. No best-response iteration needed.

## 2. Goal metrics

Per arm (one climb×spend combination, N careers):

- **Completion rate** — % of careers that beat Province Premier within the season cap (120).
- **Time-to-beat** — median (+ IQR) **seasons** and **Player matches** to complete; matches × 2:45 → **hours** (the headline Nico tracks).
- **Card-max season** — median Season-index when all 4 attributes hit the cap (60); diagnoses whether the line is ₸-starved.
- **End bank** — ₸ at completion (or at cap), to see hoarding/starvation.

**"Optimal"** = the arm that completes fastest among arms with completion rate within a small band (≥ the best arm's completion − 5 pts) — i.e. don't crown a fast arm that only finishes 40% of the time. **"Dominant"** = one arm strictly best on *both* completion AND median time-to-beat by a clear margin (flagged loudly if found).

## 3. The two search axes

### 3.1 Climb — new `CareerPolicy` (`scripts/harness/career_policy.gd`)

A pure preset class mirroring `ShopPolicy`. It owns the two climb decisions a career faces each Season. Pure, static, unit-testable — no member state, no sim.

Interface (both pure):

```
CareerPolicy.choose_tour(kind, state) -> int
    # which unlocked tour to play at the current Level this Season
CareerPolicy.choose_offer(kind, state, offers, player) -> Offer  (null = stay)
    # accept one end-of-Season Offer, or stay (null)
```

`KINDS := ["rush", "farm", "trophy"]`.

Grid topology recap (`CareerState`): `LEAGUE_GATE_TOUR = 3` (beating it unlocks the next Level's Tour 0), `PREMIER_TOUR = 7` (winning its **final** sets `level_won`), tours unlock sequentially within a Level, Province Premier (L2,T7) win = **career complete**. Province Premier is playable on adjacency alone (no Level-win gate, career-pacing DP1).

The three poles:

| Pole | `choose_tour` | `choose_offer` | The hypothesis it tests |
|---|---|---|---|
| **`rush`** | lowest unbeaten unlocked tour; if all beaten, the Premier tour (T7) | accept the cross-up Offer the moment a higher Level is reachable (`offer.level > current`) — i.e. straight after beating the gate (T3), **without** winning the Level's Premier | Fewest tours touched → fewest seasons. The genuinely-minimal path (NOT previously measured). |
| **`farm`** | highest **unlocked** tour (climb to the richest tour, then replay it for the escalating prizes + Premier super prize) | **stay** until the card is maxed (all 4 attrs at cap), then accept the cross-up | Buy full card strength at safe/rich lower tours *before* facing Province under-built. |
| **`trophy`** | lowest unbeaten unlocked tour; if all beaten, the Premier tour (T7) — replays it until the final is won | stay until the current Level's Premier final is **won** (`state.level_won[current]`), then accept the cross-up | The completionist line: win each Level's trophy before moving up. **≡ today's naive line** (`career_preview` gates cross-up on `level_won`), so `trophy × spend` is the regression cross-check. |

Notes:
- **`beat` (top-3) marks a tour beaten, but only `won_final` (1st) sets `level_won`** — so a career can beat all 8 tours without winning the Premier final. The "if all beaten → T7" `choose_tour` fallback (rush & trophy) means a career that has run out of unbeaten cells **replays the Premier** to keep trying for the final win it needs to advance/complete. (Matches the naive `_choose_tour` fallback `playable_cells().back()` = T7.)
- `choose_offer` returns an `Offer` to accept or `null` to stay; the harness then calls `accept_offer`/`stay`. It must never accept a **down** Offer (DC16's safety net is for softlocks the naive line never hits; these three poles never need to move down — they only ever cross up or stay).
- `farm`/`trophy` "stay" semantics: when the policy says stay but no higher Level exists yet (still climbing within the Level toward the gate/Premier), the loop simply plays the next `choose_tour` cell — staying is about *Offers*, climbing-within-a-Level happens through `choose_tour` regardless.
- `trophy` reproduces the current naive climb decisions exactly (`choose_tour` = lowest-unbeaten/T7 fallback; `choose_offer` = accept cross-up iff `level_won[current]`), so the `trophy × {attr_only,joker_only,balanced}` arms should reproduce `career_preview`'s latest numbers at equal N+seeds (a free regression cross-check). `rush` and `farm` are new lines never previously measured.

### 3.2 Spend — existing `ShopPolicy` (unchanged)

The 3 presets as-is: `attr_only` / `joker_only` / `balanced`. No change to `ShopPolicy` — E4 only *consumes* it.

### 3.3 The grid

3 climb × 3 spend = **9 arms**. N=60/arm default (QUICK=10). Seeds shared across arms (seed `9000+c` per career, same as `career_preview`) so arm-to-arm differences are policy, not seed luck.

## 4. The oracle — `tools/career_search.gd`

A new headless tool. Reuses the per-career loop shape of `career_preview.gd` but parameterizes the climb decisions through `CareerPolicy` instead of the hardcoded `_choose_tour` + inline offer logic.

- Envs: `CAREER_QUICK=1` (N=10), `N` (override), `CLIMB` / `SPEND` (restrict to one arm for a fast single-cell run; default = full 9-arm grid).
- Per career: start at a lowest-★ Club slot (as `career_preview`), fresh 11/11/11/11 hero (world-scale v2 default), textbook plans, loop Seasons until `complete` or cap, driving tour + offer via `CareerPolicy.choose_tour/choose_offer` and spend via `ShopPolicy.preset(spend)`.
- Collects the §2 metrics per arm; prints a `DATA <json>` line for the viz with a per-arm block + a computed `optimal` arm and `dominant` flag.
- Runtime: 9 arms × 60 careers; one arm N=100 ≈ 6 min (career-loop note) → N=60 ≈ 3.6 min × 9 ≈ **~30 min**. Over the 10-min Bash cap → **`nohup … > /tmp/e4.log 2>&1 &`** + a **log-grep watcher** (grep `/tmp/e4.log` for the final `DATA` line, never `pgrep` — CLAUDE.md hazard).

## 5. Deliverables

1. **`docs/mockups/career-search-v1.html`** — the 9-arm comparison (Nico learns by seeing): a small grid/bar view of completion% and time-to-beat (seasons + hours) per arm, the **winning line called out** in plain English, dominance verdict stated. Plain descriptive labels ("rush + balanced", "finished fastest"), counts/N visible (stat-provenance memory).
2. **Spec §10 findings** — the optimal line, the dominance verdict, the honest optimal time-to-beat, and the **number the pacing re-peg should target**.
3. **The headline for Nico** — one plain-English paragraph: best line, whether the game is "solved", real hours-to-beat.

## 6. Tests (TDD)

`tests/unit/test_career_policy.gd` — `CareerPolicy` is pure, so unit-test the decisions directly (red via `CareerPolicy` parse-error, green by count climbing past 547):

- `rush.choose_tour` returns the lowest unbeaten unlocked tour; `farm.choose_tour` returns the highest unlocked tour; `trophy.choose_tour` returns the lowest unbeaten until T7.
- `rush.choose_offer` accepts the cross-up Offer when present, stays otherwise; never accepts a down Offer.
- `farm.choose_offer` stays while any attr < cap, accepts cross-up once maxed.
- `trophy.choose_offer` stays while `level_won[current]` is false, accepts cross-up once true.
- A no-higher-Level state: all poles return `null` (stay) from `choose_offer`.

No sim assertions needed — the search tool is an oracle, not under unit test (consistent with `career_preview`/`sweep_*`).

## 7. Zero sim ripple (by construction)

E4 adds **only** `scripts/harness/career_policy.gd` + `tools/career_search.gd` + its test + the viz. It touches **no** ball / innings / economy / joker / difficulty math, and does not modify `CareerResolver`, `ShopPolicy`, `SeasonResolver`, or any tuning resource. Therefore the entire ledger — joker floor 45.5, build spread 1.9, pay spread ₸0.3, env 155 — is untouched **by construction**, no re-measurement owed. (Stated explicitly so the §10 ledger line is "untouched, not re-run".)

## 8. Decisions (defaults chosen AFK, per project CLAUDE.md)

- **E4-1 — Three climb poles** (`rush`/`farm`/`trophy`), Nico's scope ruling 2026-06-14 (chose the 3rd, trophy-chase, pole over the 2-pole minimum).
- **E4-2 — Single-agent, named-strategy search** (no best-response/equilibrium): careers are not adversarial; the opponent brain is fixed per cell, so optimization over a handful of legible strategies is the right tool, not E1/E2-style self-play.
- **E4-3 — N=60/arm default** (QUICK=10): balances Monte-Carlo tightness against the ~30-min 9-arm runtime. Shared seeds across arms.
- **E4-4 — "Optimal" = fastest among the completion-competitive arms** (completion ≥ best−5 pts), not raw fastest — guards against crowning a fast-but-flaky line.
- **E4-5 — Climb never moves down**: the three poles only cross up or stay; the DC16 down-Offer is ignored by all (it exists for softlock recovery the naive line never triggers).
- **E4-6 — `CareerPolicy` is harness, not domain**: lives in `scripts/harness/` beside `ShopPolicy`/`PolicySearch`; these are measurement strategies, not shipped game AI. (The shipped career UI's default line is a later Theme-2 presentation call.)
- **E4-7 — Pacing re-peg stays deferred to Nico**: E4 *reports* the optimal time-to-beat but does **not** move `attr_cost_base`. The re-peg is Nico's call with E4's number in hand (he ruled E4-before-pacing on 2026-06-14).

## 9. Out of scope (YAGNI)

- No best-response / equilibrium search (single-agent — §8 E4-2).
- No new climb poles beyond the three (e.g. partial-farm, adaptive-by-bank lines) — measure the poles first; a hybrid only earns a slice if the poles show a clear gap to exploit.
- No tuning changes — E4 measures, it does not re-peg (the pacing re-peg is its own deferred decision).
- No shipped career-AI / UI — `CareerPolicy` is a harness strategy set, not the game's default line.

## 10. Findings (filled at end of rung)

_TBD — optimal line, dominance verdict, optimal time-to-beat (seasons/matches/hours), pacing-target number, viz path, final test count._
