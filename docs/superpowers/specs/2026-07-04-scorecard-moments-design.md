# Scorecard Moments (playtest T10) — design

**Date:** 2026-07-04 · **Rung:** playtest fix T10 (medium, presentation-only)
**Source:** Nico's playtest note (docs/PLAYTEST-NOTES.md, 2026-07-03): *"also show
scorecard at the start of powerplay, when i come into bat/bowl or before the last 5
overs..maybe a mini scorecard at the bottom. but i want to pause between innigs and
a full scorecard and some high level commentary?"*
**Mode:** AFK — defaults recorded here as decisions DSC1–DSC10, not asked.

## 1. What this is

Two presentation features on the interactive match screen
(`scenes/interactive_match/interactive_match.gd`):

1. **Mini scorecard moments** — a compact strip that appears at orientation points
   (powerplay start, the Player coming in to bat, the Player coming on to bowl,
   the final 5 overs) and briefly holds autoplay, so the viewer re-orients without
   having to pause manually.
2. **Innings-break pause** — when playback crosses the `innings_break` event the
   match pauses on a full first-innings scorecard overlay (all batter rows, real
   numbers, dismissal flavour) with 1–2 lines of commentary, and a CONTINUE button.

**No sim, no tuning, no ledger.** Pure read-model additions + scene work — the same
shape as the T8 (DRS moments card) and in-match chart rungs. No balance gate needed;
the project's eyeball rule applies (unit tests can't catch invisible UI).

## 2. Decisions (AFK defaults)

- **DSC1 — architecture:** pure static read-model functions on `MatchViewBuilder`
  + thin scene rendering. Rejected: (a) walking events in scene code — breaks the
  screen's read-model purity convention; (b) injecting new "moment" events into
  `build_events()` — would shift `event_count`/cursor semantics that the scrubber,
  feed tests, and save-replay cursor maths sit on. Moments are *derived from* the
  stream, never added to it.
- **DSC2 — mini-moment triggers** (evaluated on the event just applied, i.e. index
  `cursor-1`):
  - `you_bat` — first event of an innings with `player_batting`
  - `you_bowl` — first event of an innings with `player_bowling`
  - `powerplay` — first event of **innings 1 only** (see DSC3)
  - `death` — first event of an innings with `over >= 16`
  One strip per step; precedence `you_bat`/`you_bowl` > `powerplay` > `death`
  (if the Player opens the batting, "YOU'RE IN" wins over "POWERPLAY").
- **DSC3 — no powerplay strip in innings 2:** the innings-break overlay lands
  immediately before it and already re-orients; two interruptions in two events
  is noise. The chase's death overs still get their strip.
- **DSC4 — strip behaviour:** non-blocking. It appears above the auto-sim dock,
  autoplay holds ~2.5 s (the existing `FLASH_HOLD` pattern) and resumes; stepping
  manually past it just shows it. It never pauses the match.
- **DSC5 — strip content:** moment title + the live mini scorecard composed from
  the already-built `MatchView` (score/overs + the batters at the crease when
  batting, or "Defending N · your figures" when bowling). No new numbers are
  computed for the strip — it re-uses `build_rich` fields (all real).
- **DSC6 — innings-break trigger:** stepping forward onto the `innings_break`
  event pauses playback and shows the overlay (resume-after flag like KM/DRS).
  `seek_to` (scrubbing) landing on it shows the overlay but never auto-pauses —
  same convention as the existing overlays. Scrubbing away clears it.
- **DSC7 — full scorecard rows:** `build_scorecard()` reads
  `MatchResult.innings1.batters` (real per-position runs/balls/out on the /100
  card) + `fall_of_wickets`. Rows = every batter who faced a ball or fell; the
  rest collapse into one "did not bat" line. Names are flavour (`PlayerNames`),
  the Player's row reads **YOU** and is highlighted. Batting-order positions,
  never reordered (the T5 rule).
- **DSC8 — dismissal flavour on out rows:** reuse `DRSMoments.flavour_of(side,
  over, ball_in_over)` — the T8 hash draw, zero RNG, stable across re-sims — so
  the scorecard's "lbw" / "c behind" agrees with what any DRS card showed for
  that ball. Display map: caught → "c", caught_behind → "c behind", bowled → "b",
  lbw → "lbw", run_out → "run out", stumped → "st". Not-out rows show "not out".
- **DSC9 — commentary is chase-anchored, never par-judged:** the fixed PAR_RR
  (8.0) is a chart benchmark; calling 110 "below par" at Club level (env ~110)
  would be wrong. Templates use only self-evident numbers: the total + required
  rate ("Karoo Kings post 162/5 — the chase needs 8.2 an over."), the top scorer
  ("Mabuza top-scored with 41."), and the Player's own line when they batted
  ("You made 27 off 19."). All numbers real; names flavour (stat-provenance rule).
- **DSC10 — no emoji in the new banner/strip text** (Barlow tofus emoji; the two
  existing banner glyphs predate the rule and are design-locked — new copy stays
  text-only).

## 3. Read-model additions (`scripts/domain/match_view_builder.gd`)

```
static func moment_at(mr: MatchResult, player: Player, cursor: int) -> Dictionary
```
Returns `{}` or `{ "kind": "you_bat"|"you_bowl"|"powerplay"|"death",
"title": String, "sub": String }` for the event at `cursor-1`, per DSC2/DSC3.
`title`/`sub` are the strip's two text lines ("YOU'RE IN", "FINAL 5 OVERS", …);
the scene adds the live score line from the current `MatchView`.
A trigger fires only when its condition is true at `cursor-1` and was not true
for any earlier event of the same innings (first-crossing semantics — the strip
shows once per innings per kind, however the user stepped there).

```
static func build_scorecard(mr: MatchResult, player: Player,
        bat_team: String, bat_code: int, chase_team: String) -> Dictionary
```
The innings-1 card for the break overlay:
- `header`: "KAROO KINGS · 162/5 (20.0)"
- `rows`: [{pos, name, badge, runs, balls, out, how, is_player}] per DSC7/DSC8
- `dnb`: "Did not bat: Nkosi, Dlamini, …" or ""
- `commentary`: 1–2 sentences per DSC9

Whether the PLAYER's team batted first comes from `mr.player_bats_first`; the
caller passes the right names/codes (the scene already holds them).

## 4. Scene work (`interactive_match.gd`)

- **Strip:** a hidden `PanelContainer` (`_moment_strip`) inserted above the dock in
  `_body_vbox`; `_show_moment(m, v)` fills title/sub/score and shows it; hidden
  again on the next step where `moment_at` returns `{}` — plus the FLASH_HOLD
  autoplay hold when playing. Public test seam: `moment_strip_visible()`.
- **Break overlay:** third overlay via the existing `_make_overlay_root()` skeleton
  (`_break_overlay`), banner "INNINGS BREAK", card = scorecard header + row list +
  commentary (italic, like KM narration) + a gold CONTINUE tile (`_two_line_btn`).
  `step()` checks it after the KM/DRS offers (a break event carries no ball, so no
  collision). Public seams: `break_overlay_visible()`, `break_continue()`.
- Ordering in `step()`: KM offer → DRS offer → innings-break → flash hold
  (unchanged behaviour for everything that exists today).

## 5. Testing

Read-model (`test_match_view_builder_rich.gd` or a new `test_scorecard_moments.gd`):
- `moment_at` fires `you_bat`/`you_bowl` at the Player's first involvement per
  innings, `powerplay` only in innings 1, `death` at over 16+, `{}` elsewhere;
  precedence per DSC2; first-crossing = fires at exactly one cursor per kind/innings.
- `build_scorecard` rows sum to the innings total/wickets; the Player row is
  flagged; out rows carry the DRSMoments-consistent flavour; DNB line correct;
  commentary contains the real total and required rate.

Scene (`test_interactive_match_scene.gd`):
- stepping onto the `innings_break` event → `break_overlay_visible()` true, playback
  paused; `break_continue()` hides it and resumes.
- a `you_bat` trigger cursor → strip visible AND `size.y > 0` AND
  `is_visible_in_tree()` (the ScrollContainer/invisibility lesson).
- scrubbing (`seek_to`) past the break → overlay shown, not playing.

Plus the render harness (`tools/preview_scorecard_moments.gd`) → PNGs under
`docs/mockups/` and a real-window eyeball before merge.

## 6. Out of scope

- Second-innings/end-of-match full scorecard (the Result recap already exists).
- Opponent bowling figures on the card (the sim doesn't model named bowlers —
  same honesty rule as the bowler row).
- Any sim/balance change. `build()`/`build_rich()` outputs are untouched for
  existing fields; the whole existing suite must stay green unmodified.
