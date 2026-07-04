# Playtest Notes — Nico's pass (started 2026-07-03)

Raw notes while playing. No structure required — a line per observation is plenty.
Claude reads this file at session start; each item becomes a fix rung or a ruling.
Don't tidy it. Date each play session; jot in whatever words come.

Useful anchors when something feels off (all optional):
- **Where:** which screen / moment (hub, match, Kit Room, Offers, Outcome, grid)
- **What happened** vs **what you expected**
- **Feel:** too easy / too hard / boring / confusing / satisfying

Things worth an eye this pass (from the Form rung — ignore unless noticed):
- Does the portrait face + form chip moving match-to-match feel right?
- All-rounder-ish builds may wear the TIRED face late-season (known, measured harmless — does it FEEL bad?)
- Does STAY-for-loyalty vs a STEP UP offer feel like a real choice?

---

## 2026-07-03

- (first fresh-start session — notes go here)
- there needs to be clubs loaded per city so pretoria you can look at the biggest clubs.suburbs in the city..maybe give the user a selection of 3 starting clubs (low rank clubs)
- jokers must say what it does. maybe a small i which you can click or some words underneath. it does not need to give %, but does say powerplay punch makes you very solid in power play overs
- my team was 1.5 stars but shows as 2 stars
- tap to start should just start..no need to press play afterwards
- boost needs to empty once press and slow fill back up(see logic in specs)
- one of the playtest it asked me in key moment with 5 overs left, but the batter showed over 30. see screenshot
- player after 1 game that was not very good is tired..how does this work
- DRS should give you % of success and review all your batters (what is the DRS review again for AI)?
- keep batter in position they came in, do not switch them around..you can however change the highlight if they are facing..otherwise it is difficult for me to focus on one batter as it keeps on flipping over
- check second game i played in playtest. i played against a very much stronger side and destroyed them with bowling..just luck?
- also show scorecard at the start of powerplay, when i come into bat/bowl or before the last 5 overs..maybe a mini scorecard at the bottom. but i want to pause between innigs and a full scorecard and some high level commentary?
---

## Triage (Claude, 2026-07-03 evening — after Nico's first 2 games)

**Investigate FIRST (possible sim bug):** ✅ DONE 2026-07-03 late
- (T1) The 41/9-in-6-overs collapse vs a stronger side (screenshot 19.03.19). 9 wickets in
  6 overs is extreme even for a weak side; if wicket probability at that cell / with
  team-wide DRS auto-claims is off, it colours everything else. Reproduce the fixture
  headlessly from the save's seed+decisions before trusting any other balance feel.

**Quick-fix batch (one small rung):** ✅ ALL DONE (PR #112, 2026-07-03 late) — plus new T12 below
- (T2) Pre-Match star glyphs: `pre_match.gd _stars()` rounds 1.5→★★ (hub does ★½ right) → shared helper.
- (T3) KM card "OVR 30" read as "over 30" → plain label ("rated 30/100" or drop it); sweep KM cards for shorthand.
- (T4) Pre-Match TAP TO START starts the match directly (no second PLAY press).
- (T5) In-match batter rows: fixed positions, highlight the striker instead of reordering.

**Small feel rungs:**
- (T6) Form too twitchy: one dismissal (−0.5) rounds to the TIRED band immediately —
  answer to "player tired after 1 bad game": dismissed −0.5 + a dot-streak −0.25 = −0.75,
  and the display rounds −0.5..−1.49 to TIRED. Fix: widen STEADY to cover > −1.0 (band on
  raw points, not roundi), so one bad game ≠ tired face. Re-check with the sweep.
  ✅ DONE 2026-07-04: FormBand now bands raw points — STEADY > −1.0 ≥ TIRED > −2.0 ≥ COLD,
  HOT ≥ 1.5 (same effective boundary as before). One bad game (−0.75) keeps the STEADY face;
  it takes two to look TIRED. No sweep needed: banding is display-only (hub chip, portrait,
  glow, Hall of Fame) — the sim reads FormState.mult(), which never touches bands.
- (T7) Joker plain-English descriptions (45 one-liners, no %) + shown in Kit Room/hub (tap-info or subtext).
  ✅ DONE 2026-07-04: `JokerCatalog.DESC` — 45 one-liners, no numbers/% (unit-enforced), honest
  to the real effect rows. Kit Room shows the line under every joker (starter picks, shelf,
  your-jokers, carry-over); hub bench tiles are now tappable — tap toggles the description
  in a line under the bench. Renders: docs/mockups/kit-room-{starter,visit}-v1.png +
  docs/mockups/hub-joker-desc-v1.png (harness tools/preview_joker_desc.gd).
- (T8) DRS: show success % on the review prompt; clarify team-wide scope in copy.
  Answer to "what is the AI's DRS for": the opponent captain holds the same base reviews —
  they can overturn YOUR wickets (their batter survives) and claim close dots against you.
  **EXPANDED (Nico, 2026-07-04 am): DRS becomes a real decision moment.** Direction:
  more DRS decisions but contextual, not every wicket — (a) a top-order batter who is set
  ("on fire") falls to a reviewable-looking dismissal (caught behind / LBW flavour), or
  (b) the last 2 overs with a review still in hand. Success chance is drawn PER MOMENT in
  roughly the 20%–70% range and SHOWN — the decision is "burn the review at 35% now, or
  hold it for the death overs". Proposed shape (to brainstorm at rung time): dismissal-type
  flavour roll (bowled/caught/LBW/caught-behind…) gates reviewability; per-moment p drawn
  from situation + flavour; failed review burns it (standard cricket); the opponent AI
  mirrors the same variable p (symmetry); moment frequency × mean p tuned so total
  overturn rate ≈ today's flat rate → the fair-fight floor doesn't move (sweep gate).
  T8 is now a MEDIUM rung (sim moment model + KM-style card UI + balance check).
  ✅ DONE 2026-07-04 (spec 2026-07-04-drs-decision-moments-design.md, DT1–DT12):
  wickets carry a hash-drawn dismissal flavour; LBW/caught-behind wickets where the
  batter was set (≥10 balls) or in the last 2 overs become DECISION MOMENTS — any
  batter on your team, with the overturn % (20–70%, drawn per moment) SHOWN on the
  card ("REVIEW — 26% to overturn · 2 left"). Failed review burns, success retained
  (real T20 rule — was burn-on-any-commit). The opponent now holds the same DRS in
  the LIVE match (it had none — live was quietly easier than the measured floor).
  Balance gate passed: fair-fight floor holds 48–49% every build (spec §6 table).
  Non-moment dismissals no longer pause the match.

**Medium rungs:**
- (T9) Boost water-meter per ADR 0005 (press locks magnitude from fill %, drains, ~25s recharge,
  ~6 full presses/match) — the built version is a per-innings press budget, a real deviation
  from the design authority. Sim + gauge UI + balance check.
  ✅ DONE 2026-07-04 (spec 2026-07-04-boost-water-meter-design.md, DW1–DW13): the meter
  ticks per BALL (the sim has no wall clock): starts full each innings, a press locks
  strength AND length from the current fill (100% = the old full boost; 50% = half),
  drains over the boost, recharges over 34 balls — 3 full presses per innings possible,
  ~6/match per the ADR. Presses under 25% fill do nothing; the BOOST badge is now a live
  % gauge ("ON" while boosting). Found+fixed en route: every live press was silently
  double-firing in the innings where you bowl (invisible buff — gone). Balance gate:
  floor holds 48–49% every build; the Boost lever measured +2.0 win-pts (was +1.5) after
  one dial iteration (base_mult 1.15→1.22), spec §9 has both tables.
- (T10) Scorecard moments: mini scorecard at powerplay start / when you come in to bat-bowl /
  last 5 overs + an innings-break pause with full scorecard + short commentary.
  ✅ DONE 2026-07-04 (spec 2026-07-04-scorecard-moments-design.md, DSC1–DSC10, PR #118):
  gold mini strip above the dock at YOU'RE IN / YOU'RE ON / POWERPLAY (innings 1) /
  FINAL 5 OVERS — shows live score + batters at the crease, holds autoplay ~2.5s,
  never pauses. Innings break now PAUSES on a full first-innings scorecard (every
  batter's real runs/balls, dismissal flavour matching the T8 DRS hash, DNB line)
  + short commentary (total, required rate, top scorer — no par judgement) + CONTINUE.
  Bonus fix found by the render eyeball: the screen behind the break used to show
  the FINISHED chase score (a result spoiler, one-tick flash before) — gone.
  Renders: docs/mockups/scorecard-moment-strip-v1.png + innings-break-v1.png.

**Needs Nico's scope call:**
- (T11) City clubs at creation (e.g. Pretoria suburbs/big clubs, pick 1 of 3 low-rank starters) —
  flavour-rich; needs club name banks per city (design-track candidate) + a creation step.
  Question for Nico: flavour-only (team name/identity) or should the pick differ mechanically?
  **RULED (Nico, 2026-07-03): flavour only — name and identity.**
  ✅ DONE 2026-07-04 (spec 2026-07-04-city-clubs-design.md, DCC1–DCC10, PR #119):
  every creation city has a bank of 8 suburb clubs (Pretoria: Menlo Park CC,
  Hatfield Hurricanes, Sunnyside Swifts, Waterkloof Warriors…); a fresh career's
  whole Club league wears your city's club names; Identity now shows a YOUR CLUB
  section — pick 1 of 3 starting clubs (★½/★★/★★½, the ladder's existing starting
  slots made visible). Flavour only — names never touch the sim. Old saves keep
  their names; no city on file keeps Karoo Kings. Design delta filed:
  docs/design-inbox/identity-club-pick-REQUEST.md. Render:
  docs/mockups/player-creation-identity-built-v1.png.


## Batch-1 outcomes (2026-07-03 late, PR #112)

- **T1 verdict:** the 41/9 collapse is the Club-Practise env being deliberately wild, not
  a bug — same-fixture benchmark N=300 (tools/probe_save_replay.gd): opponent innings mean
  105.2/7.4, P(9+ wkts)=49.7%, P(<=45 all out)=5.3%. Your match was a ~5% tail. Verdict:
  luck + club-cricket texture. (Riverside are 2.5★ vs your 1.5★ — one star up, not giants.)
- **T12 (NEW BUG, found via T1, FIXED):** your match 2 was never saved — the season file
  only wrote when you pressed Continue on the Result screen, so quitting there lost the
  match (your ₸ pay kept it, desync). Now the season saves the moment a match commits.
- **T2–T5 fixed:** star glyphs (1.5 = ★½ everywhere) · KM card says "skill 30" not "OVR 30" ·
  TAP TO START starts the match rolling · batter rows hold their positions, the gold
  highlight follows the strike.
- **Still queued:** T6 form-twitchiness (one bad game ≠ tired face) · T7 joker descriptions ·
  T8 DRS % · T9 Boost water-meter (ADR 0005) · T10 scorecard moments · T11 city clubs
  (ruled: flavour only).
