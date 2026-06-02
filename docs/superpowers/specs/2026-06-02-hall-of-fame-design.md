# Hall of Fame — Design Spec

> **⚠️ Reconciliation note (Claude Code · 2026-06-02).** Incorporated this date; consistent with CONTEXT.md + the ADRs + the Player Creation spec, and **additive to the reviewed build plan** (the plan ships a Hall-of-Fame *stub*; this spec is what replaces it later). Two clarifications for the V1 build: (1) the classifier label set referenced in §4 is the **4-label V1 set** from Player Creation spec §3.5 (Batter / Wicket-keeper Batter / Bowler / All-rounder) — the 9-label matrix in `PLAYER-CREATION-DECISIONS.md` §4 is a logged post-launch candidate; the "WK-Batter" arc-beat example here is a valid V1 label. (2) The new `Legend` fields `levelsWon` / `lifetimeTons` / `immortalised` / `retiredSeason` are **additive** to the plan's `LegendEntry` (which stores a full `Player` snapshot, so both arc-roles are derivable); they're stubbed until the Season loop and the real HoF screen exist. See `PROJECT_ROADMAP.md` → Decisions log (2026-06-02).

**Status:** Spec back-written from the locked hi-fi (`docs/mockups/player-creation-v2.html`, "Hall of Fame" frame). Buildable.
**Date:** 2026-06-02 · **Theme:** 4/5 bookend (career end) · **Companion to:** `2026-06-01-player-creation-design.md` (the career *start*).
**Sources of truth:** this spec (behaviour) · the v2 mockup (look) · `DESIGN_HANDOFF.md` §16 (visual system) · `PLAYER-CREATION-GODOT-BUILD-NOTES.md` (engine binds). Domain terms: `CONTEXT.md`.

---

## 1 · Purpose

The Hall of Fame is where a **hard-permadeath career comes to rest**. It is the only screen that persists a finished career, and the emotional payoff of the whole loop: it answers *"who did this Player become?"* with a single marquee beat — **where they started vs where they ended**.

It is a record, not a menu. The only forward action is to begin a **New Player**.

---

## 2 · When it's seen

1. **On career end** — after the death/retirement ritual (out of this spec), the Player lands here with the just-finished career as the **hero card**.
2. **On demand** — from any "Hall of Fame" entry point (e.g. a corner action on the cold-start / new-player screen), to browse past Legends.

Cold-start interaction with permadeath (per `ADR 0010` resume-first): a dead career does **not** resume. If the last career is over, cold start routes to New-Player creation; the Hall of Fame is reachable from there.

---

## 3 · Screen anatomy

**Header** — title + Legend count (`{n} Legends`). Corner gear (Settings) + info.

**Hero card** (the just-completed Legend — present only when arriving from a fresh career end; on-demand browsing shows the most recent Legend as hero):
- **Retire badge** — proud **gold** "★ Immortalised · S{retiredSeason}". (See §5 for the tone rule.)
- **Name** + meta line: `{seasonsPlayed} Seasons played · {levelsWon} Levels won`.
- **Career-arc beat** (the marquee — §4): two pills + arrow, `Started as {startRole} → Ended as {endRole}`.
- **Lifetime strip**: `{seasonsPlayed} Seasons` · `{levelsWon} Levels won` · `{lifetimeTons}` (₸, brand mark).
- Portrait: full-bg face-as-Form (§16.3), the Legend's `appearanceId`.

**Prior-Legends list** — newest-first scroll under the hero, header "Earlier Legends". **Portrait-card rows**: portrait + name + compact arc (`{startRole} → {endRole}`) + one headline stat (`{seasonsPlayed}`). The portrait persists down the whole list — it is the memory hook of a permadeath run.

---

## 4 · The career-arc beat (the marquee)

The single most important element. Renders `Started as {startRole} → Ended as {endRole}` as two label pills with an arrow between them, directly under the hero name.

- `startRole` = the **classifier label captured at creation** (`PlayerBuild.startRole`, persisted on "Begin Career").
- `endRole` = the classifier label **recomputed at retirement** from the Player's final attrs (which drift across a career via Shop upgrades / events).
- Both are stored on the `Legend` record. If `startRole == endRole`, still render both pills — a career that never changed shape is itself a story.
- Pills size to content (no truncation) so long roles like "WK-Batter" render in full.

Classifier label set + thresholds: see `PLAYER-CREATION-DECISIONS.md` §4 (matrix). The `±5` cutoff is V1; the balance harness owns final numbers.

---

## 5 · Retire-badge tone

**V1 default = proud gold** ("★ Immortalised") for every retired Legend.

Optional refinement (CSS for both ships in the mockup, gate when ready): reserve gold for a genuinely exceptional send-off and fall back to a sombre **bronze** "⚱ Retired" otherwise — driven by a `Legend.immortalised:bool`. Suggested trigger for `immortalised` (balance to confirm): a career that **won all 3 Levels**, or cleared some Seasons-played / lifetime-Tons threshold. Until that rule lands, all Legends are gold.

---

## 6 · Data model

Per `PLAYER-CREATION-GODOT-BUILD-NOTES.md` §1:

```
Legend     : name, country, appearanceId, retiredSeason:int,
             startRole:roleEnum, endRole:roleEnum,
             seasonsPlayed:int, levelsWon:int, lifetimeTons:int,
             immortalised:bool
HallOfFame : legends[Legend]   // newest-first; survives permadeath
```

`lifetimeTons` is optional flair — show it if tracked, omit the strip cell if not. Never render ₸ as `$`/`T`; use the brand mark (two-bail ≥14px, single-bail <14px).

---

## 7 · Behaviour & transitions

- **New Player** → Player Creation Screen 1 (the only forward move).
- **Tap a Legend row** → that Legend's record drill-down. Reuse the **Career Record sheet** pattern from `THEME-5-GODOT-BUILD-NOTES.md` §6 (portrait, ranks, records-with-context, totals); not separately designed here.
- **Gear** → Settings overlay. **Info** → context.
- List scrolls independently under the fixed hero card.

---

## 8 · Edge cases

- **First-ever career death** — Hall of Fame shows the hero card with an **empty** "Earlier Legends" list (no rows). Don't show a placeholder; the hero alone is correct.
- **No hero (pure browse)** — when opened on demand with no fresh death, the most recent Legend is the hero; the rest list below.
- **Career with 0 Levels won** — meta + lifetime strip still render (`0 Levels won`); the arc beat is the focus regardless of trophy count.
- **Very long roster** — portrait rows are the locked default; a compact-row variant exists in CSS for future use if scanning 50+ careers becomes the common case (not V1).

---

## 9 · Open / deferred (non-blocking)

- `immortalised` trigger rule (§5) — balance.
- Legend record drill-down — reuses Theme-5 §6 pattern; confirm at build.
- AUS portrait set / real name banks — Theme 6 (placeholders fine for build).
- Sort/filter on the list — not in V1 (newest-first only).
