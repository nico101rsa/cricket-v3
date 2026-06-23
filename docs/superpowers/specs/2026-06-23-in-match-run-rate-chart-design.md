# In-Match Run-Rate Chart — design (2026-06-23)

**Status:** AFK rung (Nico pre-authorised: "go ahead"). Design pre-locked by the
existing mockup `docs/mockups/in-match-hi-fi-v1.html` (the `.chart` block) — this
spec implements that design, it does not re-invent it. Built as a single rung,
full design including the stadium backdrop (Nico's scope ruling 2026-06-23).

## Problem

The hi-fi In-Match design has a **run-rate chart** as its hero viz — per-over
bars, a white **CRR worm** (cumulative run-rate line), a red dashed **target/par**
line, an over-number axis, a legend, over a stadium backdrop (moon, floodlights,
crowd). It is the central "are you ahead or behind?" read of a live match.

**It was never built.** The interactive match screen
(`scenes/interactive_match/interactive_match.gd:187`) substitutes a plain numeric
"RUN RATE" panel (big CRR number + required rate) for the whole chart. An earlier
in-match rung scoped itself "structural, not pixel-perfect", dropped the chart,
and never logged the deferral — so it silently fell through. This rung restores
it.

## Scope

Build the full chart (data + rendering) and wire it into the interactive match
screen, replacing the numeric "RUN RATE" placeholder panel. Pure presentation —
**no sim / tuning / ledger / data-contract files touched.**

| In scope | Out of scope |
|----------|--------------|
| Per-over bars (blue / boundary-gold / wicket-red / "now") | Win-probability indicator (mockup corner extra — defer) |
| White CRR worm + dots + glowing "now" dot | Changing any sim/economy/difficulty math |
| Red dashed target (2nd inns) / par (1st inns) line + label | Re-laying-out THIS OVER / PARTNERSHIP vizzes (kept as-is) |
| Over-number axis + CRR/TARGET legend | The watch-only `match_view` screen (chart is reusable there later) |
| Stadium backdrop (gradient sky→grass, moon, floodlights, crowd) | Scrubbing/replay-specific chart affordances |
| Live update every ball; gentle "now"-bar pulse | |

## Architecture — two units along the existing pure-builder / dumb-view seam

### Unit 1 — chart DATA (pure, fully unit-tested)

Add a `chart: Dictionary` field to `MatchView` (`scripts/data/match_view.gd`),
populated inside `MatchViewBuilder.build_rich` (`scripts/domain/`) by walking the
**active innings' raw ball-log up to the cursor** — the same `log`/`n` already
computed there for the scorecard. No new RNG, no sim calls (same purity contract
as `build()` / `build_rich()`).

Shape (`v.chart`):

```
{
  "overs": [ {"over": int, "runs": int, "crr": float,
              "has_boundary": bool, "has_wicket": bool, "now": bool}, ... ],
  "target_rr": float,   # the dashed line's RR value
  "y_max": float,       # RR scale ceiling for bars + worm (see below)
  "innings": int,       # 1 or 2 (drives label "PAR" vs "TARGET")
}
```

Derivation rules:

- **Completed overs.** For each over `o` fully bowled before the cursor: `runs` =
  legal-ball runs in that over; `crr` = cumulative `total * 6 / balls` at the end
  of the over (the worm point); `has_boundary` = any ball in the over scored 4 or
  6; `has_wicket` = any wicket fell in the over; `now` = false.
- **Current (in-progress) over.** The over the cursor sits inside (if any balls of
  it have been bowled) is appended with `now = true`, its partial `runs`, and the
  running `crr`. If the cursor is exactly at an over boundary, there is no `now`
  entry.
- **`target_rr`.**
  - 2nd innings: `(mr.innings1.total + 1) * 6.0 / 120.0` — the chase rate over the
    full 20 overs (e.g. target 161 → 8.05).
  - 1st innings: a **par benchmark constant** `PAR_RR = 8.0` (anchored to the
    sim's real-T20 scoring env, RR ~8.1 per the roadmap) so the ahead/behind read
    works with nothing to chase yet.
- **`y_max`.** `max(PAR_RR_CEIL, target_rr, max over-CRR, max single-over RR) *
  headroom`, clamped to a sane ceiling so a freak 30-run over doesn't flatten the
  worm. Concretely: `clampf(max(target_rr, max_seen_rr) * 1.15, 10.0, 18.0)`.
  (Bars are scaled by per-over RR = `runs * 6 / balls_in_over` against the same
  `y_max`, so bars and worm share one vertical scale and read together.)

A pure static helper `MatchViewBuilder._build_chart(log, n, innings_no, mr)`
returns the dict; `build_rich` assigns it to `v.chart`. `build()` (the lo-fi
watch path) does **not** set `chart` (stays `{}`), so that path is untouched.

### Unit 2 — chart RENDERING (custom-drawn Control, eyeballed)

New `scenes/interactive_match/run_rate_chart.gd` — a `Control` subclass that owns
**only drawing**. One public method:

```
func set_data(chart: Dictionary, accent: Color = Palette.GOLD) -> void
```

It stores the dict, calls `queue_redraw()`, and (re)starts the gentle pulse. All
painting happens in `_draw()`, back-to-front:

1. **Stadium backdrop.** Vertical gradient sky→grass (two `draw_rect`s or a
   `draw_rect` with a `Gradient`-derived texture; simplest: 2–3 stacked rects);
   moon = `draw_circle` (soft, upper-right); two floodlight poles (thin rects) +
   radial glow (`draw_circle` low-alpha); a crowd-silhouette strip near the
   horizon (a row of small dim arcs/rects). Stylised, cheap — atmosphere not
   realism.
2. **Bars.** One slot per over up to 20 (only drawn for overs reached). Height ∝
   `over_rr / y_max`. Colour: `Palette.BLUE` normal, `Palette.GOLD` if
   `has_boundary`, `Palette.RED` if `has_wicket` (wicket wins over boundary). The
   `now` over is drawn with a hatch/lighter fill and **pulses** (alpha eased by a
   time accumulator in `_process` → `queue_redraw`).
3. **CRR worm.** `draw_polyline` through the per-over `(x_center, y(crr))` points,
   white, width 2, with a `draw_circle` dot at each point; the last point (or the
   `now` point) drawn as a larger **gold dot + halo**.
4. **Target/par line.** Horizontal `draw_dashed_line` at `y(target_rr)`, red
   (`Palette.RED` ~0.55 alpha); a label drawn at the right end: `"target %.1f"` (2nd
   inns) or `"par %.1f"` (1st inns) via `draw_string` with the theme font.
5. **Axis + legend.** Over numbers (1, 5, 10, 15, 20) along the bottom via
   `draw_string`; a small "CRR / TARGET" legend chip (two short coloured dashes +
   text) bottom-left.

Colours come from `Palette`; the font from `ThemeDB.fallback_font` / the project
theme (Barlow). The chart reads `chart["innings"]` to switch the line label
PAR↔TARGET.

**Empty/edge states:** `chart == {}` or no overs yet → draw just the backdrop +
target line + "—" (no worm/bars); never crash on a 0-ball innings.

### Integration

In `interactive_match.gd`, the current numeric "RUN RATE" panel block
(`interactive_match.gd:187-197`, the `_crr_big` / `_req_big` labels) is **replaced**
by a `RunRateChart` instance inside the same hero panel slot. Keep `_crr_big`'s
*number* available by moving it into the scorebar meta if not already there
(`v.score_meta` already carries "CRR x.x" — so the standalone big number is
redundant once the chart lands; remove `_crr_big`/`_req_big` and their `_render`
writes). The chart binds in `_render` via `_chart.set_data(v.chart, accent)`.
"THIS OVER" and "PARTNERSHIP" panels below are unchanged.

Height: the chart panel gets an explicit `custom_minimum_size.y` (~180px, the
mockup proportion) so it never collapses (ScrollContainer/zero-height lesson).

## Determinism / risk

Pure read-model + pure rendering. The chart is a function of `(MatchResult,
cursor)` only. No file under `scripts/domain/` *resolvers*, `scripts/data/`
*tuning*, or the economy/difficulty ledger is touched. The existing `build()` /
watch path is byte-identical (chart stays `{}`). The env probe / joker bands /
build balance / pay are not in play.

## Testing

### Data — real TDD (`tests/unit/test_match_chart_data.gd`, new)

Hand-build small `MatchResult`s with crafted ball-logs and assert `v.chart`:

1. **Per-over runs + CRR series.** A known 3-over innings → `overs` has the right
   `runs` per over and a monotonic-correct `crr` series (cumulative RR).
2. **Boundary / wicket flags.** An over containing a 4 or 6 → `has_boundary`; an
   over with a wicket → `has_wicket`; an over with both wicket+boundary →
   `has_wicket` true (and bar colour rule documented).
3. **`now` over.** Cursor mid-over → last `overs` entry has `now = true` with the
   partial runs; cursor exactly on an over boundary → no `now` entry.
4. **target_rr.** 2nd innings → `(first_total+1)*6/120`; 1st innings → `PAR_RR`.
5. **innings tag.** `chart["innings"]` is 1 then 2 across the innings break.
6. **Empty innings.** 0 balls → `overs == []`, no crash, `target_rr`/`y_max` sane.

### Render — presence/visibility (`tests/unit/test_run_rate_chart_scene.gd`, new)

Custom `_draw()` can't be asserted pixel-wise, so:

1. Instantiate the chart, `set_data(sample_chart)`, add to tree, process a frame →
   `is_visible_in_tree()` true and `size.y > 0` (invisibility guard).
2. `set_data({})` (empty) → does not crash, still visible.
3. Interactive-match scene test (extend existing): after `set_session`/`boot`, the
   `RunRateChart` node exists in the tree and is visible with `size.y > 0`.

### Eyeball (mandatory — CLAUDE.md: always eyeball new UI in a real window)

A preview harness `tools/preview_run_rate_chart.gd` renders **four PNGs** under
`docs/mockups/`:

- `in-match-chart-1st-innings-v1.png` — 1st innings mid-way, par line.
- `in-match-chart-chase-v1.png` — 2nd innings chase, target line, worm above/below.
- `in-match-chart-boundary-over-v1.png` — a gold boundary over bar.
- `in-match-chart-wicket-over-v1.png` — a red wicket over bar.

Then launch the real interactive match for Nico.

## Post-build design review (bake it in — do NOT skip)

After the build + render, file a **build-fidelity review** for the claude.ai design
track: `docs/design-inbox/in-match-chart-REQUEST.md` (committed to the repo, per
the design-handoff convention) — the rendered PNGs vs `in-match-hi-fi-v1.html`,
asking design to flag deltas (worm curve, bar palette, backdrop atmosphere, label
placement). This is the review that matters (an artefact exists to compare); a
pre-build review was declined as redundant (design's own locked mockup is the
input). This step exists so the chart's fidelity is checked the way the chart
itself was missed.

## Decisions log (AFK defaults)

- **DC1** Full design incl. stadium backdrop in one rung (Nico's scope ruling).
- **DC2** 1st-innings line = fixed `PAR_RR = 8.0` benchmark (no prior innings to
  chase; anchored to the sim's real-T20 RR ~8.1). 2nd innings = real chase RR.
- **DC3** Bar colour priority wicket > boundary > normal (a wicket over is the
  more important signal).
- **DC4** Replace the numeric "RUN RATE" panel; keep THIS OVER + PARTNERSHIP.
- **DC5** Win-probability corner indicator deferred (not core to the run-rate
  read; its own small follow-on if wanted).
- **DC6** Chart is a standalone reusable `Control`; the watch-only screen can adopt
  it later without change (out of scope now).
- **DC7** No pre-build design review (redundant); post-build fidelity review filed.
