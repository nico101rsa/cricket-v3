# Offers Screen — "how to advance" in the live season

**Date:** 2026-07-02 · **Rung:** basic-gameplay item (2) (Nico's plan, 2026-06-26)
**Mode:** AFK — default decisions recorded inline as DO1–DO8.

## What this is

At the end of a live season the game currently promotes the player silently:
`CareerResolver.advance_after_live_season` auto-accepts the first cross-up offer
(the "rush-climb" Model B stand-in from PR #101). Nico's design (2026-06-26):
*"you get an offer from teams and you can choose your own league — whatever is
available."* This rung builds that choice: an **Offers screen** shown at season
end where the player picks a team offer or stays, replacing the auto-cross in
the live loop. The headless auto-cross survives as the no-UI fallback so every
existing headless test stays byte-identical.

All the domain machinery already exists and is untouched in behaviour:
- `CareerResolver.generate_offers(state, just_beat, rng)` — the canonical offer
  set (cross-up guaranteed on a fresh beat / coin otherwise · one down-Level
  from the highest unwon Level · same-Level fills · `OFFER_COUNT` = 3 rows ·
  never the current team). "Stay" is always available and is not a row.
- `accept_offer(state, player, offer)` — moves team, resets `seasons_at_level`
  and `affinity`.
- `stay(state, player)` — `affinity += 1`.

## Flow (DO1)

Carry-over election → **Offers screen** → Outcome. (The roadmap's recorded
design call: the offers pick sits *between* the carry-over Kit Room and the
Outcome, mirroring the Kit-Room routing pattern.) Rationale: the transition
descriptor the Outcome banner reads ("PROMOTED TO CITY") must already know the
pick, so the pick has to come first. The player has just played the final —
they know how they finished.

When the career is **complete** (won the Province Premier) there are no offers
(`generate_offers` returns `[]`): skip the screen, go straight to Outcome (DO2).

## Domain: two-phase split in `CareerResolver` (DO3)

`advance_after_live_season` currently does record → auto-cross → descriptor in
one call. Split it so the UI can sit between generation and choice:

```
static func begin_live_advance(state, result, level, tour, rng) -> Dictionary
```
Records the outcome (`record_outcome`), bumps `seasons_played` /
`seasons_at_level`, then draws the offer set —
`generate_offers(state, result.beat, rng)`, empty when `state.complete`.
Returns `{offers, beat, from_level, from_team_index, tour, complete}`.
Mutates only counters/grid — no team move yet.

```
static func finish_live_advance(state, player, begin: Dictionary, offer) -> Dictionary
```
`offer` is an `Offer` row or `null` (= STAY). Applies the pick:
`accept_offer` on a row; `stay` (affinity +1) on `null` **unless the career is
complete** (no stay bump on the champions path — there is no next season to be
loyal into). Returns the transition descriptor (below).

```
static func advance_after_live_season(...)  — kept, now composed
```
`begin_live_advance` → auto-pick the first cross-up offer **only under the old
rush gating** (`next_climb_tour(cur) == -1` and up-Level unlocked) → descriptor
via the shared internal builder, **without a stay-affinity bump** on the
no-promotion path. This keeps the fallback **byte-identical** to today (the old
path never called `stay()`): all four existing `test_career_resolver.gd` live-
advance tests must pass unmodified (DO4). The fallback is what headless tests
and any future no-UI driver use.

**RNG:** unchanged — `main.gd` seeds `play.seed() + 7` exactly as today;
`generate_offers` is the first and only consumer of that stream, so the offer
draw is deterministic and re-drawable after a quit (DO5).

### Transition descriptor (extended)

Existing keys unchanged: `beat, promoted, from_level, tour, to_level, complete,
next_level, next_tour`. `promoted` now means *chose* (or was auto-crossed to) a
higher Level: `to_level > from_level`. New key:

- `team_changed: bool` — `current_team_index` differs from
  `begin.from_team_index` (drives the same-Level "signed for a new team"
  banner).

## The screen (DO6)

`scenes/offers/offers.{gd,tscn}` — low-fi in-house skin, code-built, exactly
the Outcome screen's pattern (`Palette` / `UIStyle` / `Fonts`, root Control +
script). Dumb screen: renders what it is given, emits the pick, no domain math.

- **Kicker** `OFF-SEASON` · **Title** `Offers are in`
- **Current line**: `You're with <team> · <Level word>` (dim)
- **One button per offer row**: team name (bold) + `<LEVEL WORD> · n.n★` +
  a tag — `STEP UP` (gold) above the current Level, `DROP DOWN` below it,
  same Level untagged. Tap = pick, no confirm step (Reigns-simple).
- **STAY button**: `Stay with <team>` + `LOYALTY +1` note (dim styling, below
  the offers).

API: `set_offers(career: CareerState, offers: Array)` · signal
`offer_picked(offer)` where the arg is the tapped `Offer` or `null` for stay
(untyped signal arg — GDScript signals can't type an optional).

## `main.gd` routing (DO7)

`_finish_live_season(play, career)` becomes:

1. Derive the played cell first (unchanged), seed rng `play.seed() + 7`.
2. `begin := CareerResolver.begin_live_advance(...)`.
3. `begin.offers` empty (career complete) → `finish_live_advance(..., null)` →
   save + Outcome, exactly today's tail.
4. Otherwise push the Offers screen; on `offer_picked(o)` →
   `finish_live_advance(career, player, begin, o)` → `save_career` +
   `clear_live_season` + `save_player` → `_show_outcome` (today's tail).

**Persistence timing (DO5):** the career is saved only after the pick — the
same atomic window as today. Quitting on the Offers screen resumes from the
last live-season save (season replays to done, carry-over re-asked, offers
re-drawn identically from the seeded rng). *Known pre-existing quirk, out of
scope:* the final match's commit isn't in the live-season save (the
season-done path never re-saves), so quitting anywhere in the end-of-season
flow already re-plays the final on resume; this rung neither fixes nor worsens
that.

## Outcome banner (DO8)

`outcome.gd::_banner_for` gains the two new cases (it already receives
`career`; the `_career` param is used now):

- `to_level < from_level` → `MOVED DOWN TO <LEVEL>` (white — a deliberate
  title-chase, not a failure)
- `team_changed` at the same Level → `SIGNED FOR <TEAM NAME>` (white)

Check order: complete → promoted → moved down → signed → beat → missed.

## Testing (TDD throughout)

1. **Domain** (`test_career_resolver.gd` additions): `begin_live_advance`
   records once + returns the offer set; `finish_live_advance` stay bumps
   affinity / accept moves team + resets affinity + sets `promoted` /
   down-offer yields `to_level < from_level` + `team_changed`; complete →
   empty offers + no stay bump. Existing 4 live-advance tests untouched (DO4).
2. **Scene** (`test_offers_scene.gd`): renders one button per offer + STAY;
   tapping a row emits `offer_picked` with that `Offer`; STAY emits `null`.
3. **Router** (`test_main_router.gd` additions): season-done routes to the
   Offers screen (after carry-over) and the pick lands on Outcome; complete
   career skips straight to Outcome.
4. **Banner** (`test_outcome_scene.gd` additions): the two new banner cases.

## Out of scope

Hi-fi offers design (later presentation rung, needs a design brief) · team-star
mutation in the live loop (the headless DC8 mutate has no live counterpart —
pre-existing) · the final-match resume quirk (noted in DO5) · affinity
*effects* (affinity is currently just a counter).

## Decisions log

- **DO1** Offers between carry-over and Outcome (roadmap's recorded call).
- **DO2** Complete career skips the screen.
- **DO3** Two-phase split `begin_live_advance` / `finish_live_advance`;
  fallback composes them.
- **DO4** Fallback byte-identical — no stay bump on the auto path; existing
  tests pass unmodified.
- **DO5** Pick-then-save atomicity; offers re-draw deterministically on
  resume; final-match resume quirk noted, untouched.
- **DO6** Low-fi in-house skin now (like Outcome); hi-fi is a later rung.
- **DO7** No rush gating on the UI offer set — the player sees exactly
  `generate_offers` (Nico: "whatever is available"), which can offer a cross-up
  before every climb tour is beaten, and a down-Level path back. The rush
  gating survives only inside the fallback.
- **DO8** STAY is an explicit `stay()` (affinity +1) in the UI path — the
  designed loyalty mechanic finally fires in the live loop.
