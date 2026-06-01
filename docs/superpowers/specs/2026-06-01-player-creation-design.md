# Player Creation — V1 Design

**Status:** Approved, ready for implementation plan
**Brainstormed:** 2026-06-01
**Closes:** Theme 5 deferred onboarding work
**Owns the lifecycle decision:** Player permadeath model (Win or Manual retire). Promotes to **ADR 0012** at plan time.

---

## 1. Purpose & scope

Player Creation is the **cold-start path** when no Career save exists on the device. It is the only place the human shapes the in-game Player's starting identity (Country, City, Appearance, Name, Attributes); from creation onward, the Player lives until **Win** (Province's Premium Final) or **Manual retire**, at which point they archive to the Legends wall and a new Creation begins.

**This spec covers:**
- The 2-screen Creation flow (Identity → Build) and what's on each
- The 5 decisions the user makes (Country / City / Appearance / Name / Attribute distribution)
- The hard-permadeath Player lifecycle model and its V1 end-states
- The data shape of the in-progress draft and the persisted Player
- The hand-off point to the existing Starting Team picker
- Where this slots in the existing navigation shell (ADR 0010)

**This spec does NOT cover:**
- Hall of Fame / Legends wall screen layout (sibling spec, owed by Theme 5)
- Auto-drop / non-selection mechanics (deferred to **Theme 9 — Career pressure & retirement**, post-launch)
- Player aging / age-based retirement (Theme 9)
- Sub-labels beyond Batter / WK Batter / Bowler / All-rounder (post-launch flavour expansion)
- AUS Indigenous appearance bucket (separate decision — needs cultural consultation; not blocking V1)
- Per-Country Creation backgrounds, motion, polish (Theme 6 visual content)
- Tuned magnitudes (classifier thresholds, name-pool sizes, Attribute upgrade cap) — Theme 7 balance-harness tunes

---

## 2. Player lifecycle — hard permadeath

V1 end-states:

1. **Win-out** — Player wins Province's Premium tour's Final → archived to **Legends** as a winning Legend; new Creation begins.
2. **Manual retire** — Corner button on the Season hub: *"End this Player's career"* with a confirm dialog → archived to Legends as *"What might have been"*; new Creation begins.

No auto-drop, no age-based retirement, no team-release path in V1. These all live in deferred **Theme 9** (post-launch). The cheap escape-hatch button covers the *"I'm stuck and want to roll a new Player"* case without needing any failure detection or balance work.

**Reasons (informational — formalised in ADR 0012 at plan time):**
- Hard permadeath makes Seasons-played a real cost and gives the Hall of Fame meaning — the "now beat that" replay loop hooks off finite Player-lives, not just numerical scores.
- Auto-drop balance is hard before the baseline Career loop is playtested; layering an unproven failure mode on an unproven success loop is bad sequencing.
- Architecturally, an auto-drop trigger added later is the same state transition as Manual retire, just counter-triggered instead of button-triggered. Zero rewrite cost to add post-launch.
- If/when Theme 9 ships auto-drop, the trigger anchors on **Player form** (low runs over last K innings, lost KMs, etc.), **not Team result** — a good Player on a bad Team shouldn't be punished for the Team's losses.

---

## 3. The 5 creation decisions

### 3.1 Country

SA or AUS toggle. Already locked by ADR 0001. Two pillows: ZA flag + RSA palette teaser, AU flag + amber-gold palette teaser. One must be picked (no default; the user makes an explicit choice).

### 3.2 City

Hometown of the Player. **Flavour only** — no mechanical impact (no starting-Team bias, no Affinity bonus, no City-derived bonuses). City surfaces in:
- The Player card on the Season hub
- Commentary lines that mention origin (*"the kid from Pietermaritzburg has timed that beautifully"*)
- Player record entries on the Hall of Fame

V1 dropdown contents (cricket-relevant cities per Country, V1 — expandable later):

| Country | Cities |
|---|---|
| SA | Cape Town · Johannesburg · Durban · Pretoria · Gqeberha · East London · Bloemfontein · Pietermaritzburg · Centurion · Paarl · Potchefstroom |
| AUS | Sydney · Melbourne · Brisbane · Perth · Adelaide · Hobart · Canberra · Geelong · Newcastle · Darwin |

Dropdown widget; user must pick one. No "random City" affordance in V1 (the user explicitly chooses).

### 3.3 Appearance

Four portrait skin-tone buckets per Country (eight portrait sets total to commission). Ordered by tone:

| Internal name | UI position | Notes |
|---|---|---|
| `white` | 1 of 4 | Lightest skin tone |
| `mixed` | 2 of 4 | Lighter mid-tone; spans "Coloured" (SA-specific identity) and any mixed-heritage AUS reading |
| `indian` | 3 of 4 | South-Asian skin tone; covers SA Indian community + AUS South-Asian diaspora |
| `black` | 4 of 4 | Darkest skin tone |

**UI shows only portrait thumbnails — no textual labels** for the buckets. This sidesteps the naming problem (the *"what do we call the mixed bucket in AUS"* question that doesn't have a clean answer). The user picks the portrait that looks right to them by face.

The portrait selection drives:
- The base portrait art (DESIGN_HANDOFF §16.3 portrait system)
- The name-bank slice used by the name generator (see §3.4)

Theme 6 (visual content) commissions the eight portrait sets. AUS Indigenous representation is acknowledged as a real gap and held as a separate decision needing cultural consultation — not blocking V1.

### 3.4 Name

Random-generated, with a **🔄 Re-roll** button. **No manual override** — the user can re-roll as many times as they like until they're happy, then **Confirm** locks the name. The Player's name is then immutable for that Player's entire Career.

This preserves the Reigns "found, not designed" feel. Every Legend on the Hall of Fame wall has a properly weird cricket-pun name.

**Name banks**: 8 banks total = 4 Appearance × 2 Country. Each bank is a `(first_names[], surnames[])` tuple. The generator samples uniformly within the bank slice for the Player's (Country, Appearance) combination.

**Surname composition** within each bank:
- **~70% real-cricketer-surname plays** — recognisable but not literal. Examples: *Springer* (Rhodes / springbok), *Tendul* (Tendulkar), *Smithers* (Smith), *Vilas* (de Villiers), *Dhonner* (Dhoni), *Kohlrabi* (Kohli), *Amlaa* (Amla), *Markrum* (Markram).
- **~30% cricket-equipment puns** — the Reigns-flavour layer. Examples: *Bails*, *Stumps*, *Crease*, *Cover*, *Yorker*, *Bouncer*, *Square*, *Slips*, *Pitch*, *Boundary*, *Maiden*.

**First names** stay sensible-but-cricket-aware: *John*, *Jonty*, *Hashim*, *Kagiso*, *Quinton*, *Temba*, *Pat*, *Steve*, *Ricky*, *Glenn*, etc. The pun lives in the surname, not the first name.

**Pool sizes V1 (strawman, balance-tuned later):** ~30 first names × ~50 surnames per bank → ~1,500 unique combos per bank, 8 banks → ~12,000 combinations across the full pool. Plenty of variety; almost zero repeat collisions across a single user's Career history.

The name banks themselves are out of scope for *this* spec — they're a name-bank doc owed before art / build, but separable. The spec locks the **shape** of the generator (the 8-bank slicing, the 70/30 surname mix, the random+re-roll flow), not the bank contents.

### 3.5 Attribute slider

The Player's starting distribution across the four Attributes from ADR 0004. The only moment the human directly shapes the Player's mechanical identity; everything after is Tons upgrades from the Shop.

**Rules:**
- **4 sliders**: Power, Composure (batting) · Attack, Control (bowling)
- **20 points total**, must spend exactly 20 (can't Confirm with `points_remaining ≠ 0`)
- **Min 1, max 8 per slider** — no zeros (every cricketer can at least defend a ball or roll an arm; sim edge cases break on zero); cap of 8 forces a slight second skill (no pure-only specialists)
- **Default = 5 / 5 / 5 / 5** — balanced all-rounder; user must actively shift to specialise

**Live classifier label** updates below the sliders as the user drags. V1 thresholds:

| Condition | Label |
|---|---|
| Power ≥ 6 AND Composure ≥ 6 AND Attack ≤ 4 AND Control ≤ 4 AND Composure − Power ≥ 2 | **Wicket-keeper Batter** |
| Power ≥ 6 AND Composure ≥ 6 AND Attack ≤ 4 AND Control ≤ 4 | **Batter** |
| Attack ≥ 6 AND Control ≥ 6 AND Power ≤ 4 AND Composure ≤ 4 | **Bowler** |
| Otherwise | **All-rounder** |

The classifier label is **flavour only** — has zero impact on the auto-sim, the Joker pool, or any other system. It exists to give the Player a recognisable identity in the Hall of Fame and on the Player card. The 4-attribute model from ADR 0004 stays untouched; WK Batter is a *title*, not a *role*.

**The label is live** — it re-evaluates whenever the Player's attributes change (Tons upgrades from the Shop). This reflects real cricket Careers: a young hitter matures into an anchor, a part-timer becomes the strike bowler. The label tracks who the Player has become, not just who they started as. See §6.2 for how this is persisted.

Threshold values (6 / 4 / 2 split) are V1 strawman — Theme 7 balance harness tunes them based on what feels right in playtest.

---

## 4. Flow — the 2 screens

### Screen 1 — Identity

| Element | Affordance |
|---|---|
| **Country toggle** | Two-state pillow segmented control (SA / AUS). **Starts un-set** — the user makes an explicit first choice. Until Country is picked, City and Appearance are hidden (or shown disabled) and the name area shows a placeholder. |
| **City dropdown** | Lists 10 cities of the currently-selected Country. Updates when Country toggles. **When Country changes, City resets to un-picked** (the prior city no longer exists in the new list). Required pick. |
| **Appearance picker** | 4 portrait thumbnails (skin-tone buckets, country-specific art set). Tap to select. The full-size portrait of the selected appearance renders above the picker as the Player avatar preview. **When Country changes, Appearance keeps the bucket (`white` stays `white`) but the rendered portrait swaps to the new Country's art set.** |
| **Name display** | Generated name shown large beneath the portrait. Re-generates whenever **Country or Appearance changes** (the name bank slice has shifted). |
| **🔄 Re-roll button** | Adjacent to the name; re-rolls within the current bank. |
| **Next →** | Bottom of screen. Disabled until Country, City, and Appearance are all picked. |

The portrait + name read together as one "this is who you found" identity moment.

### Screen 2 — Build

| Element | Affordance |
|---|---|
| **Player card recap** | Small recap at top: portrait thumbnail + name + city + country. Confirms identity from Screen 1. |
| **4 attribute sliders** | Power, Composure, Attack, Control. Each labelled, each with a numeric readout (1–8). |
| **Points remaining** | Counter pinned visibly: *"Points remaining: X / 20"*. Highlighted red when not zero. |
| **Live classifier label** | Below sliders. Updates on every drag. Format: *"Your Player is a: [Wicket-keeper Batter]"*. |
| **← Back** | Returns to Identity screen, preserving picks. |
| **Confirm** | Bottom of screen. Disabled while `points_remaining ≠ 0`. On press: persist the Player and hand off to Starting Team picker. |

---

## 5. Where this slots in (navigation shell, ADR 0010)

Player Creation is reached **only** from cold-start or post-Career paths. There is no Main Menu, no Settings entry. Per ADR 0010 (resume-first cold start), the game's launch logic is:

```
App launch
  ├── Existing Career save?
  │     ├── YES → resume into Season hub (or Match if mid-Match save)
  │     └── NO  → Player Creation (Screen 1 — Identity)
  │
End-of-Career (Win or Manual retire)
  └── → Legends archive write → Hall of Fame screen → "Start new Player" → Player Creation
```

After Player Creation Screen 2 Confirm:

```
Player persisted (new domain object)
  → Starting Team picker (existing — CONTEXT.md: pick from 3 lowest-star Club Teams)
  → first Season hub
  → first Shop visit (free starter Common Joker)
  → Season starts
```

The Starting Team picker is an **existing**, already-spec'd step (CONTEXT.md). Player Creation simply hands off into it.

---

## 6. Data shape

### 6.1 `PlayerCreationDraft` (transient, in-progress)

Lives only across the 2 Creation screens. Discarded if the user backs out before Confirm.

```
PlayerCreationDraft {
  country:           "SA" | "AUS"                          // null until picked
  city:              string                                 // null until picked
  appearance:        "white" | "mixed" | "indian" | "black" // null until picked
  name:              { firstName: string, surname: string } // re-rolled on Country/Appearance change
  attributes: {
    power:     int  // 1-8
    composure: int  // 1-8
    attack:    int  // 1-8
    control:   int  // 1-8
    // invariant on Confirm: sum == 20, each ∈ [1, 8]
  }
}
```

### 6.2 `Player` (persisted at Confirm)

Existing domain object (DESIGN_HANDOFF / ADR 0004 / CONTEXT.md). Creation contributes these fields:

```
Player {
  // existing fields
  name:              { firstName: string, surname: string }
  country:           Country
  attributes:        { power, composure, attack, control }
  form:              Form     // initialised "Steady" (neutral)
  affinity:          int      // initialised 0
  tonsBalance:       int      // initialised 0 (first Shop visit is the free starter Common)
  // ...

  // NEW fields added by this spec
  city:              string
  appearance:        "white" | "mixed" | "indian" | "black"
  startingAttributes: { power, composure, attack, control }  // snapshot at creation, immutable
  createdAt:         timestamp
}
```

**Label is derived, not stored.** `currentLabel` is computed from `attributes` (live), `startingLabel` is computed from `startingAttributes` (snapshot at creation). Both run through the same classifier function (§3.5). Tons upgrades re-evaluate the live label automatically — a young Bowler who pumps Composure for ten Seasons can become a WK Batter, and the Hall of Fame will tell that story.

This mirrors real cricket Careers — players do shift archetype as they mature (city-cricketer to provincial all-rounder, junior hitter to senior anchor). The Legend's card on the Hall of Fame surfaces the **arc**: *"Started as: Bowler · Ended as: All-rounder"* — the two labels read together. Costs almost nothing (already snapshotting attributes at creation; classifier is a pure function).

### 6.3 `LegendsArchive` (persisted across Careers)

New persistent collection. Holds every retired (Won or Manual-retired) Player as a frozen record.

```
LegendsArchive: list of LegendEntry {
  player:            Player           // full snapshot at archive time, includes startingAttributes + final attributes
  endReason:         "won" | "retired"
  endedAt:           timestamp
  seasonsPlayed:     int
  careerStats: {
    // derived from Match history (highest score, best bowling, etc.)
    // detail in Career Records spec (ADR 0011)
  }
}
```

Because the archived `Player` carries both `startingAttributes` (snapshot at creation) and `attributes` (final state), the Hall of Fame can render the **Career arc** at zero extra storage cost: *"Started as: Bowler · Ended as: All-rounder"*. The Hall of Fame screen layout itself is out of scope for *this* spec — sibling spec owed by Theme 5.

---

## 7. Open V1 strawmen — Theme 7 will tune

Items in this spec carrying placeholder magnitudes that the balance harness should sweep:

1. **Classifier thresholds** — 6 / 4 / 2 split is a V1 guess. *"Does WK Batter feel like it triggers at the right shape?"* is a playtest question.
2. **City list contents** — 10 cities per Country is a V1 strawman. Easy to expand.
3. **Name pool sizes** — ~30 firsts × ~50 surnames per bank. Easy to expand. Bank authoring is its own deliverable.
4. **Attribute upgrade soft cap** from Tons — currently no documented max. CONTEXT.md says Tons upgrades give +1 to any Attribute via Shop. The cap (12? 15? unbounded?) is a Theme 7 question. Affects late-Career feel.

---

## 8. What this unblocks

- **Theme 5 onboarding deferred work** — closes. Theme 5 is now fully closed pending Hall of Fame screen (a separate sibling spec).
- **Theme 6 art briefs** — 8 portrait sets (4 Appearance × 2 Country) + Creation backgrounds + Re-roll button motion.
- **Theme 7 balance harness** — classifier thresholds, attribute upgrade cap, name-pool size all become tunable parameters.
- **ADR 0012** — formalises the hard-permadeath lifecycle decision at implementation-plan time.
- **Theme 9 (deferred, post-launch)** — Career pressure & retirement; auto-drop slots in as a new trigger on the same end-state transition Manual retire uses.
- **Implementation plan** — next step after this spec is reviewed.

---

## 9. Decisions deferred from this spec

Recorded for clarity — these are real questions, just not blocking V1:

- **AUS Indigenous appearance bucket** (Aboriginal / Torres Strait Islander) — real cricket community (Jason Gillespie, Ashleigh Gardner, Scott Boland), but adding it requires cultural consultation that this design pass does not attempt. Worth opening as a separate brainstorm before AUS soft launch.
- **More flavour sub-labels** beyond the 4 V1 labels (Hitter, Pace Bowler, Spinner, Stock Bowler etc.) — easy post-launch addition if the 4-label classifier feels flat.
- **Name-bank authoring** — the actual ~12,000 unique combos need writing. Separate deliverable; this spec locks the shape, not the contents.
- **City flavour expansion** — once City is in commentary lines, the commentary bank needs City-aware lines. Theme 6 carries.
- **Hall of Fame screen** — sibling spec, owed by Theme 5.

---

## 10. Implementation handoff

Next move: **writing-plans** skill to convert this spec into a phased implementation plan.

Plan should cover, in dependency order:
1. `PlayerCreationDraft` + `Player` data-shape extensions (new fields: `city`, `appearance`, `classifierLabel`)
2. Name generator (bank slicing + random + re-roll), with a stub bank (10 firsts + 10 surnames per bank) for initial wiring; full bank authoring as a separate deliverable
3. Classifier function (pure, deterministic; unit-testable)
4. Screen 1 — Identity UI (Godot scene)
5. Screen 2 — Build UI (Godot scene)
6. Wiring from Confirm → existing Starting Team picker
7. Manual retire button on the Season hub + confirmation dialog
8. `LegendsArchive` write on Win-out and Manual retire (the archive *read* — Hall of Fame screen — is a separate spec)
9. ADR 0012 — formalise hard-permadeath lifecycle decision
