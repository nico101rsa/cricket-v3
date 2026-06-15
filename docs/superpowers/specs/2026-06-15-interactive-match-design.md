# Interactive Match (Boost + batting-side DRS) — Design

**Date:** 2026-06-15
**Theme:** 2 (playable career) — third presentation rung; the deferred half of the Play→Match screen.
**Status:** brainstorm locked (Nico chose "Interactive match" then "Both Boost + DRS"; delegated architecture + scope to Claude — "you decide").

---

## 1. What this is (plain English)

The watch-only Match screen (PR #66) plays a *finished* match back ball-by-ball. This rung makes it **interactive**: at the moments that matter, the replay pauses and asks you a question — *"Press the Manager Boost?"* / *"Review this wicket?"* — and your answer actually changes the rest of the match.

The trick that keeps it cheap and safe: the sim is **deterministic** and **fast** (<1ms/match). Your decisions are already just data (Boost = which overs you pressed; DRS = which balls you reviewed). So rather than rewrite the balance-critical innings loop into a pausable machine, we **re-run the existing pure resolver** with your decision baked into its policy inputs and re-capture the ball-log. Because the seed is fixed and a decision only changes things *from this point on*, everything you've already watched stays byte-identical; only the future diverges — which is exactly "your call changed the match."

## 2. Decisions (locked)

- **DI1 — Architecture = deterministic re-simulation (Approach C), NOT an engine refactor.** A `MatchSession` controller holds the seed + the accumulating decision policy; each decision re-runs `MatchResolver.simulate_match_teams` with rebuilt policies + re-capture, producing a fresh event stream. The synchronous innings loop is **not** reworked into a pausable state-machine. *Why:* zero risk to the 591-green ledger (we only *call* the existing resolver), smallest slice, reuses the entire capture→replay scaffold. The pausable-machine engine (Approach A) is the real prerequisite for *live mid-season* (rung option 2) and earns its cost there, not here.
- **DI2 — Boost is a press-anytime BUTTON, interactive in BOTH innings** (batting → +runs window; bowling → +wicket window). Faithful to ADR 0005 ("the only decision is *when* to press"): the button is enabled while budget remains; pressing it applies the boost to the *next* over (`press_overs += next_over`), re-sims, and play continues. It is **not** a forced pause — pausing at every over-boundary (40/match) would be unplayable. The decision is expressed exactly by the existing `BoostPlan.press_overs`; no resolver change needed for Boost.
- **DI3 — DRS is interactive on the BATTING side only ("review to survive").** Pause when *your* team loses a wicket and a review remains. *Why bowling-side ("review a dot to claim a wicket") is deferred:* the sim has no "was it close?" signal on a dot, so the only honest prompt would fire on every dot (~80/innings) = unplayable. Bowling-side review needs a new "appeal" concept = its own slice (§9).
- **DI4 — The opponent's Boost/DRS stay fully automatic** (the existing `opp_boost_plan` / `opp_drs_policy`). Unchanged, re-run identically on every re-sim.
- **DI5 — Boost budget = strawman, not canon.** A fixed number of presses per innings (strawman `BOOST_BUDGET = 2`), tunable. The ADR 0005 water-meter magnitude model (fill² strength/duration, ~25s recharge, ~6 presses/match) is a **real-time/hi-fi** concept that does not map onto a turn-based ball-by-ball replay — deferred to a real-time match rung. We keep the sim's existing discrete `base_mult`/`base_n` press.
- **DI6 — DRS budget** uses the sim's existing `DRSPolicy.base_reviews = 2`, `base_p = 0.32`. The Reviewer jokers already modify accuracy via `JokerRuntime.try_review`; that flows through unchanged.
- **DI7 — Prefix stability is the correctness contract.** Re-simulating with a decision added at over/ball K must leave every ball *before* K byte-identical (same seed + identical policy prefix ⇒ identical RNG prefix ⇒ identical outcomes). This is a test, not an assumption (§8).
- **DI8 — Entry is a demo/preview path this rung.** The "season feeds you the next *live* match" wiring belongs to the live-mid-season rung (it needs a resumable in-season state). This rung ships a preview harness (screenshot) + an in-editor playable scene.

## 3. Architecture

```
        Nico taps yes/no
              │
              ▼
   ┌──────────────────────┐     re-run resolver        ┌───────────────────────┐
   │  interactive_match    │  decide_boost(over)        │     MatchSession      │
   │  scene (Control)      │ ─ decide_review(ball_id) ─▶ │  (scripts/domain/)    │
   │  play/step/speed +    │                            │  seed, attrs, teams,  │
   │  decision overlay     │ ◀── fresh event stream ──  │  press_overs[],       │
   └──────────┬───────────┘                            │  review_balls[]       │
              │ build(mr, player, cursor)               └──────────┬────────────┘
              ▼                                                     │ simulate_match_teams(... 
   ┌──────────────────────┐                                        │   BoostPlan.at(press_overs),
   │   MatchViewBuilder    │ (REUSED, unchanged)                    │   DRSPolicy{review_balls})
   │   MatchView (read-mod)│                                        ▼  + capture ball logs
   └──────────────────────┘                              MatchResolver / InningsResolver
                                                          (PURE — one default-off seam, DI3)
```

- **`MatchSession`** (`scripts/domain/match_session.gd`) — the only substantial new logic. Pure given its inputs (holds an RNG seed int, not a live RNG). Public API:
  - `static func start(player, player_team, opp_team, tour, tuning, itun, seed, jokers, opp_plans...) -> MatchSession`
  - `func result() -> MatchResult` — the current re-simulated match (with captured ball logs).
  - `func events() -> Array` — `MatchViewBuilder.build_events(result(), player)` (cached; rebuilt on each decision).
  - `func boost_offer(cursor) -> Dictionary` / `func review_offer(cursor) -> Dictionary` — given the playback cursor, is the *next* event a decision point the Player can act on (budget remaining)? Returns `{}` if none. (Detection scans the event/ball metadata; see §4.)
  - `func decide_boost(over) -> void` — append `over` to `press_overs`, re-run + re-capture, rebuild events.
  - `func decide_review(ball_id) -> void` — append `ball_id` to `review_balls`, re-run + re-capture, rebuild events.
  - `func presses_left(innings_no) -> int` / `func reviews_left() -> int` — budget read-outs for the overlay.
- **Resolver seam (DI3, the only sim change):** a new optional `review_balls` field on `DRSPolicy` (which is *already* threaded `simulate_match_teams → simulate_match → simulate_innings` as `drs_policy`) — so **no new params and no `match_resolver.gd` change**. In the batting-side DRS branch (`innings_resolver.gd` ~L240–243), when `drs_policy.review_balls != null` the Player's survive-review fires **iff** `[over, ball_in_over]` is in the set (no auto-roll otherwise); when `null` (every sweep, every headless call) the current auto-logic is byte-identical. The bowling-side claim branch ignores `review_balls` entirely (stays auto — bowling-side DRS is deferred, DI3). Boost needs no seam.
- **Scene** `scenes/interactive_match/interactive_match.{gd,tscn}` — mirrors `match_view`'s structure (header / scoreboard / current line / feed + play/pause/step/speed/back). Adds a **decision overlay** (a Panel with the prompt + Yes/No). Driving loop: on each Tick or Step, ask `MatchSession.boost_offer/review_offer(cursor)`; if an offer exists, `pause()` and show the overlay; on Yes call the relevant `decide_*` and re-render at the (stable) cursor; on No just advance. `boot()` explicit (tests inject without a sim), same as `match_view`.

## 4. Where the decisions surface (the event/cursor mapping)

The event stream is the same one `MatchViewBuilder.build_events` already produces (`"ball"` / `"over"` / `"innings_break"` / `"result"`). Decision detection rides on it:

- **Boost offer** — fires at an **over boundary** in a Player-facing innings (your batting innings, or the opponent's batting innings while you bowl) when `presses_left(innings_no) > 0` and that over isn't already pressed. The natural cursor: just before the first event of a new over. The overlay shows the side-aware effect (+runs while batting / +wickets while bowling).
- **Review offer** — fires when the **next event is a `"ball"` with `wicket == true` AND `player_batting == true`** (i.e. *you* are given out — a player-involved ball; teammate wickets are folded into "over" summaries and aren't individually reviewable this slice) and `reviews_left() > 0`. The `ball_id` is `[over, ball_in_over]` (the Player bats exactly one innings, so it's unique). The overlay shows "You're given out — Review? (N left)". Because a player-dismissal ball has the Player as striker, scripting a review at that ball reviews exactly that delivery.

Ball-id stability: because a decision only ever adds to the policy at/after the current cursor, the *prefix* (every ball before the offer) is byte-identical across re-sims, so cursors/ball-ids already shown never shift. Only the suffix diverges. (DI7 test.)

## 5. The re-simulation flow (worked example)

1. `start(...)` runs the match once with empty `press_overs=[]`, `review_balls=[]` → ball logs → events. Replay begins, paused at ball 1 (same as watch-only).
2. Cursor reaches over 6 of your batting innings; `boost_offer` returns the offer; scene pauses, overlay shows. You tap **Yes**.
3. `decide_boost(6)` → `press_overs=[6]` → re-run `simulate_match_teams(seed, BoostPlan.at([6]), ...)` + capture → new events. Balls in overs 1–5 are byte-identical; over 6 onward reflects the boost.
4. Replay resumes from the same cursor; the score visibly jumps on the boosted balls.
5. Cursor reaches a wicket in your innings; `review_offer`; you tap **Yes**. `decide_review((1, 9, 3))` → re-run with that ball scripted to review. The review either overturns (you bat on — the wicket event becomes a runs/dot event) or fails (wicket stands, one review burned). Suffix re-rolls from that ball (a review consumes one `randf`).

## 6. Components touched / created

| File | Change |
|---|---|
| `scripts/domain/match_session.gd` | **NEW** — the controller (§3). |
| `scripts/data/drs_policy.gd` | add optional `review_balls` field (default `null`) the resolver reads. |
| `scripts/domain/innings_resolver.gd` | batting-side survive-review branch: honor `drs_policy.review_balls` when set (DI3); default-off byte-identical. No new param (rides on `drs_policy`). |
| `scripts/domain/match_resolver.gd` | **no change** — `drs_policy` is already threaded through. |
| `scenes/interactive_match/interactive_match.{gd,tscn}` | **NEW** — interactive scene + decision overlay. |
| `tools/preview_interactive_match.gd` | **NEW** — fixed-seed match, scripts a couple of decisions, renders the screenshot. |
| `scripts/domain/match_view_builder.gd`, `scripts/data/match_view.gd` | **REUSED unchanged.** |

## 7. Testing (TDD)

Red via parse-error (new `class_name`), green by the suite count climbing past **591** + `All tests passed`.

- **`test_match_session.gd`**
  - `start` produces a result + non-empty events (the baseline run).
  - **Prefix stability (DI7):** `decide_boost(K)` leaves the ball-log byte-identical for every ball in overs `< K`; `decide_review(id)` leaves the log byte-identical for every ball before `id`.
  - Boost: `decide_boost` on a batting over changes the team total (effect lands).
  - DRS: a scripted successful review turns the reviewed wicket into a not-out and decrements wickets at that point; a failed review leaves the wicket and decrements `reviews_left`.
  - Budget: `presses_left` / `reviews_left` decrement; offers stop when exhausted.
- **`test_interactive_drs_seam.gd`** (or fold into existing resolver tests)
  - `review_balls = null` ⇒ innings byte-identical to current `main` (the ledger gate — assert vs a pinned literal / `probe_scoring_env` digit-for-digit).
  - `review_balls = {a specific wicket ball}` ⇒ that ball attempts a review; other balls do not.
- **Scene test `test_interactive_match_scene.gd`** — inject a `MatchSession` via `boot()`, assert the overlay appears at a known offer cursor and that tapping Yes advances + re-renders (panels non-empty, `size.y > 0` per the ScrollContainer/visibility gotchas in CLAUDE.md).
- **Ledger gate:** full GUT suite green; `probe_scoring_env` byte-identical to the pre-rung value (155 / RR / wkts).

## 8. Deliverable (Nico-facing)

- **`docs/mockups/interactive-match-built-v1.png`** — a fixed-seed match (seed-20260615) mid-innings with the Boost overlay (or a post-decision feed showing a boosted over / a survived review). A loud caption notes which decisions were scripted for the shot (per the "label showcase vs canonical" memory).
- The scene is **manually playable in the editor** (point Nico at it — he learns by seeing).
- Plain-English wrap-up: what to tap, what changed, the one thing to look at.

## 9. Explicitly deferred (next rungs, not this one)

- **Bowling-side DRS ("review a dot to claim").** Needs an "appeal/close-call" signal in the sim so the prompt fires a sane number of times. Its own slice.
- **The ADR 0005 water-meter Boost** (fill² magnitude, drain/recharge, ~6 presses) — a real-time match rung; can't live in a turn-based replay.
- **Live mid-season entry** (season → the next match played live). Needs resumable in-season state — that's rung option 2, and the place Approach A (the pausable engine) finally earns its cost.
- **Interactive batting intent / bowling change / field** — more decision verbs, later slices.
- **Hi-fi chrome** (portraits, rarity glow, gradients) — the art-parity rung.

## 9a. Open defaults (chosen, recorded — not blocking)

- Boost budget = 2 presses/innings (DI5); DRS = 2 reviews/innings (DI6) — strawman, tunable.
- Overlay is a simple Yes/No Panel (low-fi, matches the watch-only fidelity).
- `ball_id` shape = `(innings_no, over, ball_in_over)`.
- Re-sim on every decision (no incremental diff) — <1ms, trivially fast.

## 10. Findings (build, 2026-06-15)

**Shipped exactly as designed (Approach C).** No engine refactor — the interactive match is the pure resolver re-run with Player-authored policy.

- **610 tests green** (+19 over 591: 5 DRS-seam + 11 `MatchSession` + 3 scene).
- **Ledger byte-identical:** `probe_scoring_env` reads **155.0** (PP 9.72 / mid 6.58 / death 7.49) — unchanged. The `DRSPolicy.review_balls == null` default path proves the gate is off for every sweep/headless call.
- **Demo match** (`tools/preview_interactive_match.gd`, seed-20260615, Player forced to bat first): screenshot `docs/mockups/interactive-match-built-v1.png` shows a real decision — **109/2 in over 14.1, the Player given out, "Review? (2 left)"**, with a ball-by-ball feed and the BOOST button live. **SHOWCASE labels:** the Boost on over 5 and the seek-to-dismissal are scripted *for the shot*; a real session presses/reviews live.
- **Three gotchas hit & recorded:**
  1. **`do_review` needed an explicit `: bool`** — `review_balls` is untyped (Variant), so `null-check or .has()` can't be `:=`-inferred; the inference failure broke `InningsResolver`'s compile and cascaded "nonexistent function" errors across the suite. (The documented GDScript ternary/inference gotcha.)
  2. **The caller must attach the captured ball-logs to the `MatchResult`.** `simulate_match_teams` fills the passed-in arrays *by reference* but does NOT set `mr.ball_log_innings1/2` — `LeagueResolver` does that after the call (L126), and so must `MatchSession._resim` (and the seam test's `_run`). Missed at first → `innings1.wickets == 6` but an empty `ball_log_innings1`.
  3. **The scene must `_render()` before showing the overlay.** First cut skipped the render on an offer, so the scoreboard/feed stayed at boot state (0/0, empty) behind the DRS prompt. Render-then-overlay gives the dismissal its context.
- **DRS scoping confirmed at the right layer:** the resolver gate reviews any listed `[over, ball]`; the player-only scoping is a `MatchSession.review_offer` concern (offers fire only on player-involved wicket events, since teammate wickets are folded into "over" summaries). The seam unit-test scripts the first wicket (any batter); the session tests script player dismissals.
