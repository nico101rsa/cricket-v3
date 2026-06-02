# Player Creation & Hall of Fame · Godot Build Notes

> **⚠️ Reconciliation note (Claude Code · 2026-06-02).** Incorporated into the repo this date. **For the V1 build, the canonical attribute model is the Player Creation spec §3.5** (`docs/superpowers/specs/2026-06-01-player-creation-design.md`): **20-point budget · 1–8 per slider · 4 classifier labels** (Batter / Wicket-keeper Batter / Bowler / All-rounder). The **32-point / 1–10 / 9-label** classifier in §1 and §3 below is a **logged post-launch candidate**, not V1 — see `PROJECT_ROADMAP.md` → Decisions log (2026-06-02). The reviewed build plan (`docs/superpowers/plans/2026-06-01-player-creation-plan.md`) is the build authority and executes unchanged. AUS palette `#A86E00` (gold-forward) is canonical and already live in `DESIGN_HANDOFF.md` §16.2 + all mockups. Companion docs cited as `THEME-5-GODOT-BUILD-NOTES.md` / `THEME-5-DECISIONS.md` are claude.ai-side names not in this repo; nearest equivalents: `docs/design-handoff-from-claude-2026-05-31.md`, `docs/THEME-5-HANDOFF.md`.

Engine-facing handoff for the two **Player Creation** screens and the **Hall of Fame**. For each screen: **data it binds**, **state transitions**, and the **country-palette token contract**. Source of truth for behaviour is `docs/superpowers/specs/2026-06-01-player-creation-design.md`; source of truth for the locked visual directions is the mockup `docs/mockups/player-creation-v2.html` and the decisions log `docs/PLAYER-CREATION-DECISIONS.md`. Look system = `DESIGN_HANDOFF.md` §16. Companion to `THEME-5-GODOT-BUILD-NOTES.md` (around-the-match) — reuse its shared model objects and §7 token contract.

> Naming below is descriptive, not prescriptive — map to your existing resource/model classes. Types are intent, not a schema.

---

## 0 · Locked directions (built in the v2 mockup)

| Screen | Locked choice | Mockup frame |
|---|---|---|
| Creation 1 — Identity | **Portrait-anchored** (hero face leads, controls follow) | "Screen 1 · Identity" + "Australia swap" |
| Creation 2 — Build | **Drag sliders** (continuous), live points bar + classifier | "Screen 2 · Build" |
| Hall of Fame | **Portrait-card rows** + **proud gold** retire badge; career-arc beat headlines the hero card | "Hall of Fame" |

CTA on Build reads **"Begin Career"** — the word *permadeath* is deliberately **off the button** (the gravity is communicated by the Hall of Fame, not a scare label).

---

## 1 · Shared model additions

Extends the `Player` / `CareerGrid` objects in `THEME-5-GODOT-BUILD-NOTES.md` §0.

```
PlayerIdentity : country:countryKey, city:string, appearanceId:enum/int,
                 name:string                      // name + city drawn from country master-data banks
PlayerBuild    : attrs{power, composure, attack, control}:int,   // shared point budget
                 startRole:roleEnum               // classifier label CAPTURED AT CREATION (see §5 arc beat)
Legend         : name, country, appearanceId, retiredSeason:int,
                 startRole:roleEnum, endRole:roleEnum,            // the career-arc beat
                 seasonsPlayed:int, levelsWon:int, lifetimeTons:int,
                 immortalised:bool                // true = exceptional career → gold badge (see §4)
HallOfFame     : legends[Legend]                  // newest-first; persists across permadeath
```

- `attrs` here is the **same four** Attributes used everywhere else (Power/Composure = batting, Attack/Control = bowling). `OVR` remains a presentation roll-up — never surface raw skill maths (ADR 0003).
- `startRole` must be **persisted at creation** and `endRole` **captured at retirement** — both are required to render the arc beat (§5). If only `endRole` exists, the marquee moment is dead.

**Budget / range (mockup placeholders — confirm at balance):** 4 attrs, each `1..10`, drawn from a single shared pool of **32** points. These numbers are first-cut; the balance harness owns the final values. Both control styles write the same four ints.

---

## 2 · Creation Screen 1 — Identity

**Binds:** `country` (toggle, default SA) · `city` (dropdown, options from `country` master-data) · `appearanceId` (4-portrait picker; selecting one swaps the hero portrait) · generated `name` + re-roll (draws from the `country` surname/forename bank) · hero portrait (full-bg face-as-Form, §16.3).

**Layout (locked):** hero portrait anchored at top, then Name (+ re-roll), Country toggle, City, Appearance row. Step indicator = dot 1 of 2.

**Live behaviour:**
- **Country toggle** re-themes the whole screen root (header gradient, accent ring, hero ring, CTA glow) via the palette swap (§6) **and** repoints the city + name banks to that country's master-data. Switching country should re-default city + re-roll name to the new slice.
- **Appearance pick** updates `appearanceId` and live-swaps the hero portrait.
- **Re-roll** draws a fresh `name` from the current country bank (no other field changes).

**Transitions:** `Next — Build your game` → Creation Screen 2. Corner ✕ → discard/back to launch (cold-start logic per ADR 0010). No data is permanent until "Begin Career" on Screen 2.

---

## 3 · Creation Screen 2 — Build

**Binds:** the four Attribute rows (name, one-word descriptor, current value, slider) grouped Batting / Bowling · points bar (`spent / total` + budget fill) · **live classifier** (label + one-line blurb). Step indicator = dot 2 of 2.

**Control (locked = sliders):** continuous drag, `1..10` per attr. The points bar and classifier update on every `input`. Budget fill = `spent / total`. (If balance later wants a hard "can't exceed budget" rule, clamp on the way up; the mockup currently lets values move freely and just reports the running total.)

**Classifier — pure function of the four attrs.** Keep it engine-side and reuse anywhere a build needs a label. Mockup logic (review the wording/thresholds before they become final copy):

```
bat  = power + composure          bowl = attack + control
diff = bat - bowl
batStyle  = power>composure ? AGGRESSIVE : composure>power ? ANCHOR  : BALANCED
bowlStyle = attack>control  ? STRIKE     : control>attack  ? ECONOMY : BALANCED

diff >=  5  → batStyle:  "AGGRESSIVE BATTER" / "ANCHOR BATTER" / "SPECIALIST BATTER"
diff <= -5  → bowlStyle: "STRIKE BOWLER" / "ECONOMY BOWLER" / "SPECIALIST BOWLER"
diff  >  0  → "BATTING ALL-ROUNDER"
diff  <  0  → "BOWLING ALL-ROUNDER"
diff == 0   → "GENUINE ALL-ROUNDER"
```

Each label carries a one-line playstyle blurb (see mockup `classify()` for the full strings). The label produced here = the Player's **`startRole`** — persist it (§1, §5).

**Transitions:** corner ← → Screen 1 (preserves entered values). `Begin Career` → commits `PlayerIdentity` + `PlayerBuild`, persists `startRole`, and loads the first Season (→ Season-start Shop → Season Hub, per Theme 5). This is the permadeath commit point — the career now exists and cannot be unmade.

---

## 4 · Hall of Fame

**Binds (chrome):** title + `legends.length` count. Gear → Settings, Info → context.

**Hero card (the just-completed Legend):**
- retire badge — **proud gold** "★ Immortalised · S{retiredSeason}". *Tone decision:* gold is locked as the default celebratory treatment. (The decisions log notes bronze as the sombre alternative; if you want gold reserved for exceptional careers only, gate on `immortalised` and fall back to a bronze "⚱ Retired" badge otherwise — the mockup ships both badge styles in CSS.)
- `name` · meta line (`seasonsPlayed Seasons played · levelsWon Levels won`).
- **Career-arc beat (marquee):** two pills + arrow — `Started as {startRole} → Ended as {endRole}`. This is the narrative payoff of the whole loop; keep it the visual focus. Pills size to content so long roles (e.g. "WK-Batter") render in full.
- lifetime strip: `seasonsPlayed` · `levelsWon` · `lifetimeTons` (₸ via the brand mark, never `$`/`T`).

**Prior-Legends list (locked = portrait-card rows):** newest-first scroll. Each row = portrait + name + compact arc (`startRole → endRole`) + a headline stat (`seasonsPlayed`). Portrait persists down the whole list — it's the memory hook of a permadeath run. (Compact text rows exist in CSS as an alternative for very long rosters; not the default.)

**Transitions:** reached after the death/retirement ritual at career end (out of this scope) and from any "Hall of Fame" entry point. From here the only forward move is **New Player → Creation Screen 1**. Tapping a Legend row → that Legend's record drill-down (reuse the Career Record sheet pattern from Theme 5 §6; not separately designed).

---

## 5 · The career-arc beat — data requirements

The single most important wiring in this pass.

- `startRole` = classifier output **at creation** (§3). Capture and persist immediately on "Begin Career".
- `endRole` = classifier output **at retirement**, computed from the Player's final attrs (which drift over a career via Shop upgrades / events).
- Both live on the `Legend` record the Hall of Fame reads. Render as `Started as {startRole} → Ended as {endRole}` on the hero card and `{startRole} → {endRole}` on list rows.
- If start == end, still render both pills (a career that never changed shape is itself a story).

---

## 6 · Country-palette token contract

Identical mechanism to `THEME-5-GODOT-BUILD-NOTES.md` §7 — country set once on the screen root, swaps four tokens; everything else is country-invariant; no hardcoded hexes.

> **AUS palette — RESOLVED: gold-forward, canonically.** AUS renders gold-forward
> (`--country-1 #A86E00`, `--country-2 #5c3a00`, `--country-accent #36CE72`,
> `--country-glow rgba(224,168,40,.45)`). Australia's limited-overs identity is
> gold-dominant (SA is green-dominant), so this is both more authentic *and*
> keeps the two playable countries distinct in lists / side-by-side, not only on
> toggle. **This supersedes the green-forward AUS in `THEME-5-GODOT-BUILD-NOTES.md`
> §7** (now updated to match). Follow-up: re-swap the AUS frame in
> `around-the-match-v1.html` to these values next time it's touched.

Tons glyph (₸): always the brand mark (two-bail ≥14px, single-bail <14px). Portrait = full-bg face-as-Form (§16.3); the Appearance picker stores an `appearanceId`, never a baked image.

---

## 7 · Known gaps (not blocking the build)

| Gap | Path | Blocking? |
|---|---|---|
| Real name banks (~12k) | Theme 6 — stub bank (10×10 per slice) wires the generator now | No |
| AUS portrait set | Theme 6 — mockup shows SA-kit art under AUS UI | No |
| Classifier thresholds + copy | Balance harness (Theme 7) owns numbers; copy reviewable now | No |
| Budget total / attr ranges | Balance harness — 32 / 1–10 are placeholders | No |
| AUS palette direction | **Resolved — gold-forward canonical (§6)** | No |
| ADR 0012 — permadeath lifecycle | Extract at writing-plans time | No — spec captures it |
| Hall of Fame formal spec | ✅ Done — `docs/superpowers/specs/2026-06-02-hall-of-fame-design.md` | — |
