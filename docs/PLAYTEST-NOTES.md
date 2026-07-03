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
- (T7) Joker plain-English descriptions (45 one-liners, no %) + shown in Kit Room/hub (tap-info or subtext).
- (T8) DRS: show success % on the review prompt; clarify team-wide scope in copy.
  Answer to "what is the AI's DRS for": the opponent captain holds the same base reviews —
  they can overturn YOUR wickets (their batter survives) and claim close dots against you.

**Medium rungs:**
- (T9) Boost water-meter per ADR 0005 (press locks magnitude from fill %, drains, ~25s recharge,
  ~6 full presses/match) — the built version is a per-innings press budget, a real deviation
  from the design authority. Sim + gauge UI + balance check.
- (T10) Scorecard moments: mini scorecard at powerplay start / when you come in to bat-bowl /
  last 5 overs + an innings-break pause with full scorecard + short commentary.

**Needs Nico's scope call:**
- (T11) City clubs at creation (e.g. Pretoria suburbs/big clubs, pick 1 of 3 low-rank starters) —
  flavour-rich; needs club name banks per city (design-track candidate) + a creation step.
  Question for Nico: flavour-only (team name/identity) or should the pick differ mechanically?
  **RULED (Nico, 2026-07-03): flavour only — name and identity.**


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
