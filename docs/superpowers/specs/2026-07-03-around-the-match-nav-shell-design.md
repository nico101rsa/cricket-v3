# Around-the-match nav shell — design

**Date:** 2026-07-03 · **Rung:** basic-gameplay item (3) (Nico's plan, 2026-06-26) · **AFK rung** — default decisions recorded here as DN1–DN10.

## What this is

The screen-to-screen frame around the match, translating the locked mockup
`docs/mockups/around-the-match-v1.html` (ADR 0010) into the live game. Three new
screens + routing:

1. **Pre-Match** — the versus moment between tapping PLAY on the hub and the match.
2. **Result** — the post-match payoff moment (verdict, your numbers, the ₸ you earned)
   that hands off per the cadence (→ Kit Room / → hub / → season end).
3. **Career Grid** — the between-Seasons home (ADR 0010 §3): the 3×8 career map,
   seen after the Outcome screen and on a cold boot between Seasons.

All three are **code-built, in-house skin** on the shared `Palette`/`UIStyle`/`Fonts`
foundation (same fidelity tier as Outcome/Kit Room/Offers — structure + layout
faithful to the mockup, hi-fi polish is a later design-brief rung, same as the
standing pattern). **Zero sim/tuning/ledger risk** — pure UI + routing; every number
shown is read from existing domain objects, nothing is simulated or re-tuned.

## What already satisfies ADR 0010 (not in scope)

- Season hub as persistent home — built (hi-fi, design-locked).
- Forced Shop/Offer full-screen interludes — built (Kit Room PR #103, Offers PR #104).
- No-main-menu resume routing — built (`main._ready` routes on save state).

## Slice 1 — Pre-Match screen (`scenes/pre_match/`)

Mockup section 2, **Q2 locked: single opponent portrait**.

**Layout (top→bottom):** versus header (You play for `<team>` + ★ | VS | `Match N` /
stage + `<opp>` + ★) · stakes strip (`League Match N of 7 · Top 4 advance`,
`Semi-Final · Win to reach The Final`, `The Final`, `3rd-Place Match`) · conditions
line (the tour's real flavour name, e.g. `Club · Flat & Warm`) · two panels:
**Your captain** (portrait placeholder, your 4 real attributes Pow/Com/Atk/Ctl,
`AFFINITY` pips from `Player.affinity`) vs **Their danger man** (portrait
placeholder, flavour surname via `PlayerNames.for_position(opp_name, country, 0)`,
opp team ★ rating) · build strip (owned joker count/names from
`play.player_effects()` context + `shop_owned()`, BOOST READY pip) · gold
**TAP TO START** CTA.

**Data honesty (DN1):** every number real — attrs from `Player.attributes`, stars
from `Team.stars`, stage from `next_player_opponent()["stage"]`, tour name from
`SeasonView.tour_name`. The danger man is **flavour only** (name + team ★) — the
sim has no named opponents (established in-match precedent). No home/away tag
(DN2 — the sim has no home/away concept; the mockup's `Home`/`Away` labels are
dropped rather than faked). No opponent form pips (DN3 — deferred; the live table
could derive W/L pips later, cheap but not load-bearing for the flow).

**Routing:** `main._play_next` currently builds the session and pushes the match
directly. Now: hub PLAY → (pending Kit Room visit still gates first, unchanged) →
**Pre-Match** → `start_pressed` → session + interactive match (exact current code).
**No back affordance (DN4)** — mockup-faithful forward flow (Reigns conveyor);
the session is only created on TAP TO START.

## Slice 2 — Result screen (`scenes/result/`)

Mockup section 5. Sits between the in-match back and the existing
kit-room/hub/season-end fork in `main._commit_and_return`.

**Layout:** `Match N · Result` kicker + verdict (`WON BY 23 RUNS` green / `LOST BY …`
red, from `MatchResult.result_text`-equivalent) · broadcast scoreline (both teams,
`174/6 (20 ov)`, winner highlighted; SA runs/wickets order per the locale
convention) · **personal perf grid** (Runs · Balls · SR · 4s·6s · Bowl figures —
from the player line in `MatchResult`; bowling figures wickets/runs) · **₸ earned**
(`base + perf = total`, plus `+ win prize` on a win, and `bank now ₸N` from
`Player.tons_balance`; recomputed for display via `Economy.match_pay` /
`match_win_prize` with the same inputs `SeasonPlay._settle` used — same ints,
display-only) · handoff CTA that **names the destination**: `CONTINUE → KIT ROOM`
(visit pending) / `CONTINUE → SEASON END` (season done) / `CONTINUE` (hub).

**Final-win celebration variant (DN5):** when the committed match was The Final and
the player won — gold-bordered trophy panel (`CHAMPIONS · <LEVEL> · <TOUR>` +
`Season beaten`), verdict styled up. Text-styled only — **no emoji** (Barlow tofu;
the mockup's 🏆/confetti are design polish, deferred with the hi-fi skin), no
animated reveal (Q4's 2.5s stagger is hi-fi polish, deferred, DN6).

**Dropped, recorded (DN7):** KM-recap chips (the domain has no per-KM won/lost
outcome — a KM is an intent choice, not a bet) · Affinity/Form delta bars (affinity
only moves at season end; Form is a stub `0 = Steady`). Neither is faked.

**Side fix:** the in-match result state's CTA reads `PLAY AGAIN ▶` — a pre-live-loop
leftover (it actually returns to the season). Relabel `CONTINUE ▶`.

**Pay context plumbing:** `_settle` knows `{stars, level, tour}`; the Result screen
needs the same to recompute the display breakdown. `SeasonPlay` gains a read-only
`pay_context()` (or equivalent getters) — no behaviour change.

## Slice 3 — Career Grid screen (`scenes/career_grid/`)

Mockup section 6, **Q3 reco: diagonal ladder**.

**Layout:** career header (country name + ₸ balance · Seasons played / Current team /
Levels won — all real from `CareerState` + `Player`) · the **ladder map**: 3 rising
diagonal rows of 8 tour nodes (Club bottom-left → Province top-right, each Level
starting at the height the previous topped out), nodes drawn per
`CareerState.cell_status` (LOCKED dim / UNLOCKED lit / BEATEN check / Premier-won
trophy-gold via `level_won`), the **current cell** (`CareerResolver.next_live_cell`)
pulsed in the country accent with the team badge · legend row (`beaten · won ·
here · locked`, text glyphs not emoji) · gold **START SEASON — <LEVEL> · <TOUR>** CTA.
Custom-`_draw()` node+link rendering (RunRateChart precedent).

**No node picking (DN8):** the domain plays exactly one cell
(`next_live_cell`) — the map is a *map*, the CTA starts that cell. The mockup's
"tap a lit node" implies choosing among unlocked cells; that's a domain feature
the career resolver doesn't have. Deferred to its own rung if wanted.

**No career-stats block / 6b records rail (DN9):** career-wide aggregates (matches,
win rate, batting/bowling career lines, global rank) exist nowhere in the domain —
only per-season results do. The mockup's stats bands are deferred until a
career-stats ledger rung exists. Header counters (seasons/levels/team/₸) are real
and shown.

**Routing:** the grid becomes the between-Seasons home:
- **Outcome → Continue** → Career Grid (was: straight into the next season's hub).
  Career complete keeps routing to `LifecycleManager.win_out()` (unchanged).
- **Cold boot** with a player + career but **no live season** → Career Grid
  (was: hub auto-booting a season). Mid-season resume (live-season save exists) →
  hub, unchanged. First-ever creation flow → starting-team picker → Career Grid
  (consistent single entry into a season).
- **START SEASON** → `_push_hub()` (hub.boot() starts the season at
  `next_live_cell` exactly as today — season creation stays in the hub, the grid
  is read-only, DN10: hub.boot's career-create-if-absent logic is hoisted so the
  grid can render a fresh career without booting a season; the season sim itself
  still only runs on hub boot).

## Deferred (recorded, out of scope)

- **Settings gear** (every-screen corner gear, ADR 0010) — there is no settings
  screen to open; own rung.
- **Splash** — cosmetic; boot routing is already resume-first.
- **Mid-season Offer** (mockup section 4, single take-it-or-leave-it) — the domain
  only generates offers at season end (PR #104); a mid-season offer generator is a
  domain feature, not nav shell.
- **Hi-fi skins** for all three screens + animations/confetti — later design-brief
  rungs (standing pattern).
- **6b Career Records** rail/sheet + node picking + opp form pips (DN3/DN8/DN9).

## Testing

Per screen: GUT scene tests (structure + real-data wiring + visibility guards —
`is_visible_in_tree()` + `size.y > 0` per the ScrollContainer/flat-button traps) +
routing tests on `main.gd`'s forks where testable headlessly. Render harnesses
`tools/preview_{pre_match,result,career_grid}.gd` → `docs/mockups/*-v1.png`,
each eyeballed in a real window before merge. Whole suite green before each PR;
each slice is its own PR (nav routing lands with its screen, so `main` stays
shippable between slices).

## Slice order

1 (Pre-Match) → 2 (Result) → 3 (Career Grid). 1 and 2 bracket the match; 3 is the
biggest and independent. End of rung: launch the real game for Nico's eyeball.
