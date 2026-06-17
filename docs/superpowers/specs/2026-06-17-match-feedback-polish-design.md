# Match Feedback Polish — Design

**Date:** 2026-06-17 · **Theme:** 2 (Presentation) · **Rung:** small follow-up to Key Moments — "let me see what's happening in the test build"
**Status:** spec written + approved (build this session)
**Why:** Nico playtested the interactive match (Key Moments rung) and asked for two readability tweaks so the replay is legible while testing: (1) a DRS review should tell you whether it was lost or successful before continuing; (2) your own big moments (boundaries, milestones, wickets, getting out) should briefly pause and stand out so you can see them go by.

---

## 1. What this is (plain English)

Two display-only tweaks to the **interactive match** scene so a watched innings reads clearly:
1. **Review outcome popup** — after you tap *Review*, the card shows ✅ successful / ❌ lost and waits for **OK**.
2. **Brief highlight on your moments** — your `FOUR!`/`SIX!`, `FIFTY!`/`HUNDRED!`, your `WICKET!`/`THREE-FOR!`/`FIVE-FOR!`, and your `OUT!` flash in a bold gold label and the autoplay holds ~1.5s on them.

Neither touches the sim — pure presentation (same risk profile as the overs-notation fix).

## 2. Decisions (locked with Nico)

- **D1 — Review popup: outcome + OK.** Tapping *Review* re-sims (as today), then the overlay flips to a result state ("✅ Review successful — NOT OUT" / "❌ Review lost — still OUT (N left)") with one **OK** button that hides the overlay and resumes. Declining (*No*) stays as-is (no popup — you accepted the out). Review economy unchanged (a review still costs one regardless of outcome this rung).
- **D2 — Highlight scope: your moments only.** Batting: a four, a six, reaching 50, reaching 100, and getting **out**. Bowling: a wicket, reaching 3-for, reaching 5-for. Teammate/opponent events are NOT highlighted. (Nico's call; getting out added on review.)
- **D3 — Milestones win.** A ball that is both a boundary and brings up a milestone shows the milestone (`FIFTY!` over `FOUR!`); a wicket that reaches 3/5-for shows `THREE-FOR!`/`FIVE-FOR!` over plain `WICKET!`.
- **D4 — Brief auto-pause, no tap.** During autoplay, hold ~1.5s on a highlight then continue automatically (`FLASH_HOLD`). Manual stepping still bolds the line but does not auto-pause (you're already in control). A Key Moment or DRS overlay (full pause) takes precedence if it lands on the same step.
- **D5 — Display only.** No sim/score/ledger change. `MatchView` gains one `highlight_text` field; the watch-only match screen ignores it for now (the tweak targets the interactive scene Nico plays).

## 3. Architecture

```
MatchSession (extended)
  ball_is_wicket(ball_id) -> bool   # reads the player batting ball-log; for the review outcome

MatchViewBuilder.build (extended)
  computes v.highlight_text for the just-shown ball (the event at cursor-1) when it's
  the Player's: FOUR!/SIX!/FIFTY!/HUNDRED!/OUT! (batting) · WICKET!/THREE-FOR!/FIVE-FOR! (bowling)

MatchView (extended)
  var highlight_text: String = ""   # "" = nothing to flash

interactive_match scene (extended)
  Overlay: a third button (ReviewOk) + a result state after a review decision
  Flash: a new bold/gold Label showing v.highlight_text
  FlashTimer: one-shot ~1.5s; during autoplay a highlight stops Tick, starts FlashTimer,
              which restarts Tick on timeout (unless the user paused meanwhile)
```

## 4. Highlight rules (MatchViewBuilder, for the event at cursor-1 only)

| Your ball | highlight_text |
|---|---|
| batting, reaches 100 (runs_before < 100 ≤ runs_after) | `HUNDRED! {runs} ({balls})` |
| batting, reaches 50 (runs_before < 50 ≤ runs_after) | `FIFTY! {runs} ({balls})` |
| batting, six | `SIX!` |
| batting, four | `FOUR!` |
| batting, out | `OUT! {runs} ({balls})` |
| bowling, reaches 5 wkts | `FIVE-FOR! {wkts}/{runs}` |
| bowling, reaches 3 wkts | `THREE-FOR! {wkts}/{runs}` |
| bowling, wicket (not 3/5) | `WICKET! {wkts}/{runs}` |
| anything else / not your ball | `""` |

Priority within batting: hundred → fifty → six → four → out. (Out can't coincide with a boundary; a milestone four is shown as the milestone.)

## 5. Where it surfaces

- `scripts/data/match_view.gd` — new `highlight_text` field.
- `scripts/domain/match_view_builder.gd` — compute `highlight_text` for the cursor-1 ball.
- `scripts/domain/match_session.gd` — `ball_is_wicket(ball_id)`.
- `scenes/interactive_match/interactive_match.{gd,tscn}` — `ReviewOk` button + review result state; `Flash` label; `FlashTimer` + the brief-hold logic in `step`.

## 6. Testing (TDD)

Builder (pure):
1. your four → `FOUR!`; your six → `SIX!`.
2. a 49→53 ball → `FIFTY! 53 (n)`; teammate four → `""`.
3. your dismissal → `OUT! …`; getting out is highlighted (D2 addition).
4. your 3rd wicket (bowling) → `THREE-FOR! …`; 5th → `FIVE-FOR! …`; 1st → `WICKET! …`.

MatchSession:
5. `ball_is_wicket(ball_id)` true for a still-out ball, false for an overturned one.

Scene:
6. after `decide_review`, the overlay shows the outcome text + OK; pressing OK hides it and (if autoplay was on) resumes.
7. a highlight ball populates the `Flash` label text.

Run the whole suite each step (`-gdir=res://tests/unit`); green = count climbs + `All tests passed`. **Eyeball the real game** after (launch it — the flash/bold and the popup can't be unit-tested for feel).

## 7. Deliverable

Launch the real game for Nico to play the next fixture and feel: does the review tell him lost/won, and do his fours/fifties/wickets/outs stand out and hold briefly? (Per [[feedback-launch-playable-not-screenshot]] — copy-paste-complete command, absolute path.)

## 8. Explicitly deferred

- Wiring the highlight into the watch-only match screen (`scenes/match_view/`).
- A real bold font / animation / sound — gold + larger font is the "bold" this rung.
- Review economy change (successful review retained) — separate balance call.
- Highlighting opponent/teammate moments.

## 9. Findings (build) — filled in at build

(to be completed: test count delta, the exact Flash styling used, launch instructions given to Nico.)
