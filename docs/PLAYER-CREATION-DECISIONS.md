# Player Creation & Hall of Fame — Decisions Log

> **⚠️ Reconciliation note (Claude Code · 2026-06-02).** Incorporated into the repo this date. **For the V1 build, the canonical attribute model is the Player Creation spec §3.5** (`docs/superpowers/specs/2026-06-01-player-creation-design.md`): **20-point budget · 1–8 per slider · 4 classifier labels** (Batter / Wicket-keeper Batter / Bowler / All-rounder). The richer **32-point / 1–10 / 9-label** classifier in §4 below is a **logged post-launch candidate**, not V1 — see `PROJECT_ROADMAP.md` → Decisions log (2026-06-02). The reviewed build plan (`docs/superpowers/plans/2026-06-01-player-creation-plan.md`) executes unchanged. AUS palette `#A86E00` (gold-forward) is canonical and already live in `DESIGN_HANDOFF.md` §16.2 + all mockups. Companion docs cited as `THEME-5-DECISIONS.md` / `THEME-5-GODOT-BUILD-NOTES.md` are claude.ai-side names not in this repo; nearest equivalents: `docs/design-handoff-from-claude-2026-05-31.md`, `docs/THEME-5-HANDOFF.md`.

**Status:** Hi-fi mockup delivered · recommendations proposed · **3 open questions await your call** (§4).
**Deliverable:** `docs/mockups/player-creation-v1.html` (single multi-frame HTML, 8 phone frames across 3 sections).
**Source of truth:** `docs/superpowers/specs/2026-06-01-player-creation-design.md` (flow spec). This file logs *what the hi-fi resolved and why*; it does not restate the domain (see `CONTEXT.md`) or the visual system (see `DESIGN_HANDOFF.md` §16).
**Date:** 2026-06-02. Companion to `THEME-5-DECISIONS.md` (the around-the-match pass this continues).

This is the bookend pass of the hard-permadeath loop: where a Player is **born** (Creation) and **laid to rest** (Hall of Fame).

---

## 1 · Locked architecture (carried from spec — do not reopen)

1. **Two-screen creation**, then straight into the first Match. Screen 1 = Identity, Screen 2 = Build. No third screen, no tutorial gate.
2. **Identity = Country · City · Appearance · Name.** Country drives the palette and the city/name banks. City is a dropdown; Appearance is a 4-portrait picker; Name is generated with a re-roll.
3. **Build = 4 Attributes off one points budget.** Batting (**Power**, **Composure**) + Bowling (**Attack**, **Control**), spent from a shared 32-point pool. A live classifier names the resulting cricketer.
4. **Default country = South Africa** (ADR 0001 primary target). Australia is the second authored slice.
5. **Hard permadeath.** A career ends once and does not resume. The Hall of Fame is the only place a finished career persists.
6. **Hall of Fame = hero card + prior-Legends list.** Hero = the just-completed Legend; list = every earlier Legend, newest-first.
7. **Token system is canonical.** `DESIGN_HANDOFF.md` §16.1 vars + §16.3 portrait language; no hardcoded hexes; `data-country` re-themes a whole screen subtree.

---

## 2 · Screen inventory (as built in the mockup)

| § | Screen | Frames in file | Notes |
|---|---|---|---|
| 1 | Player Creation — Identity | 1A, 1B, 1C | 1A/1B = layout options; 1C = same as 1A in AUS palette |
| 2 | Player Creation — Build | 2A, 2B | slider vs stepper; both live-interactive |
| 3 | Hall of Fame | 3A, 3B, 3C | density + badge-tone options |

All Screen-1 frames have a **live country toggle**; both Build frames have **live sliders/steppers** driving the budget bar + classifier.

---

## 3 · Decisions proposed by the hi-fi (recommendations)

### Screen 1 — Identity
- **Layout → vertical scroll (Frame 1A). [RECOMMENDED]** Controls lead, portrait follows. At creation the player has no attachment to the face yet, so leading with controls respects the real task — four quick choices, then play. Predictable depth, short thumb travel.
- *Alternative (1B):* portrait-anchored. Ceremonial, sells the portrait system, but pushes the four controls below the fold and over-weights a face the player can't yet care about. Reserve for a more dramatic onboarding feel.

### Screen 2 — Build
- **Slider treatment → drag sliders (Frame 2A). [RECOMMENDED]** Continuous/analogue feel suits a once-per-career identity choice; precision covered by the live number + budget bar.
- *Alternative (2B):* ± steppers. One point per tap makes the economy feel deliberate (management-genre) at the cost of expressiveness. Fallback if playtests show sliders feel "too loose."
- **Live classifier is locked in.** Maps the 4 attributes → a named build (AGGRESSIVE BATTER … GENUINE ALL-ROUNDER … STRIKE BOWLER) with a one-line playstyle blurb. The classifier function in the mockup (`classify()`) is a **first-cut mapping for review**, not balance-final.

### Screen 3 — Hall of Fame
- **List density → portrait-card rows (Frame 3A). [RECOMMENDED]** The face is the memory hook of a permadeath run; keep it present down the whole list.
- **Retire-badge tone → sombre bronze (Frame 3A). [RECOMMENDED]** Bronze reads *memorial* — matches hard-permadeath gravitas. Reserve **proud gold** (3C) as a rare flourish for an exceptional send-off (e.g. a career that won all 3 Levels).
- *Alternatives:* compact rows (3B) read as a record-book and scan better for long rosters (50+ careers) but lose the face; gold (3C) celebrates but softens the permadeath sting.
- **Career-arc beat is the marquee moment.** *Started as: BOWLER → Ended as: WK-BATTER* renders as two label pills + an arrow directly under the hero name. This is the narrative payoff of the whole loop — keep it the visual focus of the card.

---

## 4 · DECISIONS — all resolved (2026-06-02)

1. **Screen-1 layout:** **portrait-anchored** (hero face leads, controls follow). ✅
2. **Build control:** **drag sliders**, live points bar + classifier. ✅
3. **Hall of Fame:** **portrait-card rows** + **proud gold** retire badge; career-arc beat headlines the hero card. ✅
4. **AUS palette:** **gold-forward, canonically** (`--country-1 #A86E00`, accent green). ✅
   Rationale: Australia's limited-overs identity is gold-dominant (SA is green-dominant), so gold-forward is both more authentic *and* keeps the two playable countries visually distinct in lists / side-by-side — not only when you toggle. This supersedes the green-forward AUS in `THEME-5-GODOT-BUILD-NOTES.md` §7 (updated to match). Follow-up: re-swap the AUS frame in `around-the-match-v1.html` to gold-forward next time it's touched.
5. **Classifier mapping:** copy + thresholds reviewed and kept as-is for V1 (full matrix below). Final *numbers* still owned by the balance harness. ✅

### Classifier matrix (V1 copy — `classify()` in the mockup)
`diff = (Power + Composure) − (Attack + Control)`

| Condition | Label | Blurb |
|---|---|---|
| `diff ≥ 5`, Power > Composure | **AGGRESSIVE BATTER** | Lives for boundaries. High ceiling, fragile floor — a glass cannon at the crease. |
| `diff ≥ 5`, Composure > Power | **ANCHOR BATTER** | Bats time and wears bowlers down. Hard to dislodge, slow to accelerate. |
| `diff ≥ 5`, Power = Composure | **SPECIALIST BATTER** | A pure top-order bat. Little to offer with the ball. |
| `diff ≤ −5`, Attack > Control | **STRIKE BOWLER** | Hunts wickets and breaks partnerships. Leaks runs chasing the breakthrough. |
| `diff ≤ −5`, Control > Attack | **ECONOMY BOWLER** | Strangles the run rate and builds pressure. Few wickets, fewer runs conceded. |
| `diff ≤ −5`, Attack = Control | **SPECIALIST BOWLER** | A frontline bowler. A liability with the bat in hand. |
| `0 < diff < 5` | **BATTING ALL-ROUNDER** | Bats with intent and chips in with the ball. Flexible — but a jack of two trades. |
| `−5 < diff < 0` | **BOWLING ALL-ROUNDER** | Bowls front-line overs and bats with freedom down the order. Two strings, neither elite. |
| `diff = 0` | **GENUINE ALL-ROUNDER** | Equally dangerous with bat and ball. The rarest build — and the hardest to fund. |

---

## 5 · Known gaps (not blocking this design lock)

| Gap | Owner / path | Blocking? |
|---|---|---|
| Real name banks (~12k) | Theme 6 — mockup uses a stub bank | No |
| AUS portrait set | Theme 6 — AUS frame shows SA-green kit art at mockup stage | No |
| Classifier balance pass | Balance harness (Theme 7) | No — copy is reviewable now |
| Hall of Fame formal spec | ✅ Done — `docs/superpowers/specs/2026-06-02-hall-of-fame-design.md` | — |
| ADR 0012 — permadeath lifecycle | Extract at writing-plans time | No — spec captures the decision |

---

## 6 · Build notes for Godot (carry-forward)

- `data-country` ⇒ a `Country` palette resource; switching it re-themes the whole creation subtree (header gradient, toggle, accent ring, CTA glow) — mirror this with a theme-variation swap, not per-node hardcoding.
- Budget = single shared pool (32 pts in mockup; confirm with balance). Both control styles write the same 4 ints; the classifier is a pure function of those 4 — keep it engine-side and reuse it on any screen that needs to label a build.
- Portraits use the §16.3 full-bg face-as-Form system; the picker stores an art id, not a baked image.
- Career-arc beat needs **start role** captured at creation and **end role** captured at retirement — both must be persisted on the career record that the Hall of Fame reads.
