# Jokers in the sim — C2f: DRS / tryReview (design)

**Date:** 2026-06-08 · **Rung:** 7c layer C, sub-slice C2f · **Mode:** AFK
**Prior:** C2e Manager Boost (PR #23, 31 of 45). The last *new-mechanic* C-rung.

## 1. What this rung adds

The **DRS** (Decision Review System) — the Reviewer archetype (#38–#45). `tryReview`'s native shape (pool doc): *roll P(success); on success flip the outcome and retain the review, on fail consume it.* This is the first joker mechanic that **flips a ball outcome** and **consumes RNG**.

**DRS model (harness):** a per-innings **review resource** (`base_reviews`, strawman 1) and a base success chance (`base_p`, strawman 0.4), supplied via a `DRSPolicy`. A review is attempted automatically at a **close decision**:
- **batting:** the Player is dismissed → review to *survive* (overturn out → not-out, the ball becomes a dot).
- **bowling:** the Player (bowling) concedes a **dot ball** → review to *claim* (overturn not-out → wicket). A harness abstraction of "a strong shout turned down."

On success the review is **retained** (base behaviour); on fail it is **consumed** (unless a retain joker). The reviewer jokers modify P(success), grant reviews, retain on fail, or chain off a successful review.

**Pool delta: 31 → 39 of 45.**

## 2. Jokers wired (magnitudes verbatim)

| # | Name | Rarity | Effect |
|---|---|---|---|
| 38 | Cool Head | Common | P(success) +10% |
| 39 | Captain's Eye | Common | P(success) +20% while Defensive |
| 40 | Spare Review | Common | +1 review per innings |
| 41 | Hot Spot | Common | successful review → Player Form event |
| 42 | Snicko | Rare | P(success) +25% |
| 43 | The Captain's Call | Rare | failed review retains (not consumed) |
| 44 | Bowler's Backing | Rare | successful review **while bowling** → wicket ×1.20 for 6 |
| 45 | The Review Master | Legendary | P +30%, retain on fail, +1 review, success → Form event |

## 3. Model + engine extensions

- `DRSPolicy` (`scripts/data/drs_policy.gd`): `base_reviews := 1`, `base_p := 0.4`.
- `JokerEffect`: `enum DRSRole { NONE, ACCURACY, EXTRA_REVIEW, RETAIN, FORM_ON_SUCCESS, BOWLING_BUFF, MASTER }`, `var drs_role := NONE`, `var drs_p_bonus := 0.0`. Captain's Eye reuses `intent_req = DEFENSIVE` (accuracy applies only while Defensive). `drs_role != NONE` jokers are runtime-owned (`matches()` false).
- `JokerRuntime`:
  - `var reviews_left := 0`.
  - `init_reviews(jokers, base_reviews)` — `reviews_left = base_reviews + (#40 / #45 grants)`. Called once at innings start (when a `DRSPolicy` is set).
  - `try_review(jokers, player_is_batting, intent, base_p, ball, rng) -> bool` — returns whether the decision is overturned. Sums P bonuses (ACCURACY gated by `intent_req`; MASTER +0.30), clamps, rolls **one** `rng.randf()`; on success fires Form (FORM_ON_SUCCESS / MASTER) and the #44 bowling buff, retains the review; on fail consumes unless a RETAIN/MASTER joker.

## 4. Threading

`simulate_innings` gains `drs_policy: DRSPolicy = null`. At innings start (policy set) → `runtime.init_reviews(...)`. After `resolve_ball`, **before** the wicket/runs handling, a DRS block (gated on `drs_policy != null`) checks the close-decision trigger and, on an overturn, **mutates `o`** (`BallOutcome.new(false, 0)` to survive / `BallOutcome.new(true, 0)` to claim) — the existing wicket/runs path then handles it unchanged. `simulate_match(_teams)` gains `drs_policy`, passed to **both** innings.

**Determinism:** `try_review` draws `rng.randf()` **only** when a review is actually attempted (policy set + trigger + `reviews_left > 0`). No policy → no draw → byte-identical to pre-C2f. With a policy, draws shift the sequence but are deterministic (same seed → same result).

## 5. Decisions (AFK)

- **D1 — auto-review at a close decision** (Player dismissal / Player-bowled dot). The harness can't model "the captain decides to review," so it reviews whenever a review is available and the trigger fires. Resource scarcity (1–2 reviews) bounds it naturally.
- **D2 — outcome flip via mutating `o`**, reusing the existing wicket/runs handling — minimal surgery in the hot loop.
- **D3 — Form magnitude (+1 vs +2) is not modelled** — C2c models Form as an *event* (no meter), so Hot Spot and Review Master both just fire one Form event. Noted.
- **D4 — bowling DRS is a documented abstraction** (reviewing a dot ball = a turned-down shout). Batting review-to-survive is the high-value mechanic; bowling review is a minor gamble.
- **D5 — RNG only on an actual attempt**, keeping off-by-default byte-identical.

## 6. Catalog + sweep

`implemented_groups()` 31 → 39. Add a shared `DRSPolicy` to the sweep so reviews happen; add a "Reviewer stack" arm (#38+#42+#40+#43+#45). The base DRS (review-to-survive) shifts the baseline (shared across arms). Refresh viewer.

## 7. Tests (green past 301)

- `test_drs_policy.gd` (new): defaults.
- `test_joker_effect.gd`: a `drs_role != NONE` joker returns false from `matches()`.
- `test_joker_runtime.gd`: `init_reviews` counts grants; `try_review` consumes on fail / retains on success; accuracy bonus raises success rate (seeded); Captain's Call never consumes; Spare Review adds a review; a successful bowling review pushes the #44 buff.
- `test_joker_catalog.gd`: 39 groups; the 8 drs_roles present.
- `test_innings_jokers.gd`: a DRSPolicy lowers the Player's dismissals (review-to-survive); high-accuracy DRS lowers them further; determinism with a policy.
- `test_match_jokers.gd`: no policy → byte-identical; determinism with a policy.
