# Outcome Hi-Fi — Design Spec (2026-07-03)

Basic-gameplay item (4): re-skin the season-end **Outcome screen** (`scenes/outcome/`)
to the game's design language. Run AFK — every decision below is a recorded default
(DO-prefixed), not an open question.

## What the screen is

The season-end payoff moment. Shown after the Offers pick, before the Career Grid:
where you finished, the career transition (promoted / cleared / moved / missed),
the ₸ banked this season, and a Continue that routes to the Career Grid (or the
Hall of Fame when the career completes — wiring from PR #107, unchanged).

Today it is the low-fi in-house skin (PR #101): a centered column of plain labels
and one stats panel. All *content* is right; this rung is presentation only.

## Approach (DO1)

**Derive the skin in-house from the locked screens** — the Season Hub / Identity
header language and the Result screen's panel idioms are the reference. The
alternative (a design brief to the claude.ai track via `docs/design-inbox/`) needs
Nico as courier at every hop, which an AFK rung can't do. If design later reviews
this screen, its deltas land as a follow-on — same path the hub/in-match took.

## Layout (390×844 design size, top → bottom)

1. **Country-gradient header band** (`UIStyle.header(grad1, grad2, glow)`, the
   Identity/hub pattern): kicker `SEASON COMPLETE` (W_LABEL, dim) over the big
   headline (`CHAMPIONS` / `RUNNERS-UP` / … , 26px W_HEADLINE, gold on podium,
   white otherwise). The headline moves INTO the band — the band is what makes
   the moment read "designed".
2. **Transition strip** — the career-consequence line, styled by weight (DO2):
   - `promoted` / `complete` (champion): **gold celebration panel**
     (`UIStyle.cta(Palette.GOLD)`, dark text) — the Result screen's champion-panel
     idiom. On promotion a small sub-line `YOUR CAREER MOVES UP`; on complete the
     banner text already says it (no sub — eyeball round found the duplicate).
   - cleared / moved down / signed: plain `UIStyle.panel()` strip, white text.
   - missed: same strip, dim text.
   Banner *wording* is unchanged from PR #101/#104 (tests pin it).
3. **Season stat tiles** (`UIStyle.panel()`): a 3-column grid of value-over-label
   cells (the Result perf-grid idiom) replacing the label-left/value-right rows —
   `1st / FINISHED`, `8 of 9 won / RECORD`, `₸ 506 / BANKED` (₸ value gold,
   tabular figures). Text content byte-identical to today (DO3).
4. **Next-up pill** (`UIStyle.pill(SURFACE_2)`): `NEXT: CITY · TOUR 1` (or
   `NEXT: HALL OF FAME`), centred.
5. **Gold CTA** — unchanged (`CONTINUE  >` / `ENTER THE HALL OF FAME  >`).

No portrait (DO4): the portrait pipeline is basic-gameplay item (5), its own rung;
adding another consumer of the placeholder `hero-cap.png` here buys nothing and
the header band already carries the visual weight. No emoji anywhere (standing
rule — Barlow tofus them).

## Country theming (DO5)

`set_outcome` gains an **optional trailing param** `country: int = Country.Code.SA`.
`Palette.country_set(country)` themes the header gradient/glow (exactly like
Identity). `scenes/main.gd::_show_outcome` passes the live player's country
(`_apply_offer_pick` already holds the `Player`; thread it through — null player
falls back to SA). Existing callers and all 9 scene tests compile and pass
untouched — that is the point of the trailing default.

## Contract preserved (DO3)

- Signal `continue_pressed()` and the PR #107 routing (Career Grid / Hall of Fame)
  untouched.
- Node names `Kicker`, `Headline`, `Banner`, `StatsPanel`, `NextUp`, `ContinueBtn`
  keep working with `find_child` (the Banner label now lives inside the transition
  strip panel; `find_child(recursive)` still finds it).
- Every *pinned* string identical (headline words, banner wording, `N of M won`,
  ordinals, `₸ <pay>`, CTA text — everything the tests assert). Panel captions may
  adapt to the tile form (`₸ BANKED` row → `BANKED` caption under a gold `₸ 506`
  value). Presentation-only diff.

## Testing (DO6)

Existing `tests/unit/test_outcome_scene.gd` (9 tests) must pass unchanged — they
are the behaviour lock. New hi-fi guards added test-first:
- header band exists and has height > 0 (`is_visible_in_tree`, `size.y > 0` —
  the ScrollContainer/flat-button traps from CLAUDE.md);
- promoted/champion transition strip is the gold panel (stylebox bg = GOLD family),
  missed is not;
- AUS country param re-themes the header (stylebox bg differs from the SA default);
- stat tiles grid present with the three captions.

## Deliverables

- `scenes/outcome/outcome.gd` re-skinned (code-built, same file).
- `scenes/main.gd` passes the country.
- `tools/preview_outcome.gd`: re-render the same four state PNGs
  (`docs/mockups/outcome-{cleared,promoted,champion,missed}-v1.png` — same paths,
  roadmap links stay valid) + `CTRY=aus` env variant support (Identity-preview
  precedent), proof PNG `outcome-promoted-aus-v1.png`.
- Eyeball in a real window (unit tests can't catch invisibility) + end by
  launching the game.

## Out of scope

Offers-screen hi-fi (its own later rung) · animations · portrait · any domain
change (zero sim/ledger risk by construction — scene + tool files only, plus the
one-line country pass-through in main).
