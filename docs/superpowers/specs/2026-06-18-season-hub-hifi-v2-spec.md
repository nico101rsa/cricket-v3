# PASTE THIS INTO YOUR GODOT AI

> Attach alongside this text:
> 1. **`season-hub-reference.png`** — the exact visual target (render of the screen).
> 2. **`hero-cap.png`** — the player portrait art; drop into `res://assets/portraits/`.
>
> Everything the AI needs is inline below — the image is the look, this text is the spec.

---

You are updating the **Season Hub** scene in my Godot cricket game (mobile, portrait, 9:16). I'm attaching a reference image of the finished screen and a portrait PNG. Rebuild the scene to match the reference exactly. It's a single dense screen — no scroll, no tabs, everything visible at once. The state shown is **season start**: Match 1, no games played yet.

## Hard rules
- **No debug chrome.** No window title bar, no traffic-light dots. The screen is full-bleed inside the device safe-area (13px inset). Only chrome is two round corner buttons: **ⓘ** top-left (context tooltip), **⚙** top-right (Settings).
- **Never show raw skill stats.** The internal `PWR/COM/ATT/CON` numbers must NOT appear anywhere. The player only ever sees **OVR** (a single roll-up) and **career averages**.
- **No full league table on this screen.** Standing is shown only by the header position pill + the fixtures chain. (Tapping the pill opens a separate table screen — just stub the signal.)
- **No hardcoded hex values.** Build ONE `Theme` resource with the tokens below and reference it everywhere, so the country palette can be swapped by overriding 4 tokens.

## Node tree
```
SeasonHub (Control, full-rect, margin 13)
├─ CornerInfo (Button, top-left, 26x26 round)
├─ CornerGear (Button, top-right, 26x26 round)
└─ VBox (separation 7)
   ├─ TopBar (PanelContainer — country gradient bg, glow shadow)
   │  └─ HBox: TeamBadge(30x30) · TeamId[VBox: name / meta-row] · PosPill[VBox: pos / pts]
   ├─ TonsBand (PanelContainer)
   │  └─ HBox: [TONS BANKED label + ₸ value]  ⟷  [SEASON 1 · CLUB / MATCH 1 of 7]
   ├─ FixturesPanel (PanelContainer)
   │  ├─ Header: "FIXTURES" + "season opens ●"
   │  └─ HBox: Fx x7 · VSeparator · StageFx x2 (SF, 🏆)
   ├─ PlayerCard (PanelContainer)
   │  └─ HBox: Portrait(92x122) · Who[VBox: name / role / OVR+formChip / careerStrip-or-empty]
   ├─ JokersPanel (PanelContainer)
   │  └─ Header "JOKERS BENCH" + "0/4" · HBox: Joker x4
   ├─ Affinity (PanelContainer)
   │  └─ HBox: 🤝 · VBox[label + next-bonus ⟷ / ProgressBar]
   └─ CTA (Button, gold gradient, 2 lines: "FIRST MATCH ▶" / "v Dusty Plains · home")
```
Every `PanelContainer` = bg `surface`, 1px `border`, corner_radius 11, content margin 9 (v) × 11 (h).

## Theme tokens (SA default palette)
| token | value |
|---|---|
| bg | #0f0f14 |
| surface | rgba(255,255,255,0.04) |
| surface-2 | rgba(255,255,255,0.07) |
| surface-3 | rgba(255,255,255,0.10) |
| border | rgba(255,255,255,0.08) |
| border-strong | rgba(255,255,255,0.15) |
| gold | #ffd166 |
| gold-warn | #f5a623 (CTA/stage gradient start → gold) |
| gold-deep | #c9912b |
| green / green-dark | #2ecc71 / #16a34a (won fixtures) |
| red / red-dark | #c41e3a / #8b0000 (lost fixtures) |
| blue | #4a90e2 (★3 skill ring, rare joker) |
| white-soft / -mid / -dim | rgba white .85 / .65 / .45 |
| **country-1 / country-2** | #007749 / #003e26 (header gradient) |
| **country-glow** | rgba(0,119,73,0.45) (header shadow + now-pulse) |
| **country-accent** | #FFB81C (current fixture, match label, affinity bar) |

Country swap later = override ONLY the four `country-*` tokens. Nothing else.

## Type
System font. Sizes(px): labels 8.5–9 (UPPERCASE, +1.6 letter-spacing, weight 800), body 10–12, names 14–15 (weight 900), OVR 17, Tons value 24. All numeric values use tabular/mono figures. Radii: panels 11, portrait/cards 9, buttons 13, dots 50%.

## Component specs

**Header** — gradient `country-1 → country-2`, soft `country-glow` drop shadow. Badge = team code "KK". Name "Karoo Kings" (900). Meta row = `★½` (gold) + a small chip "CLUB". Position pill (dark, right) = big number over "PTS" — show **`—` / 0 PTS** until a result exists (do NOT show fake "1st").

**Tons band** — left: "TONS BANKED" label + `₸ 120` (gold, 24px). The ₸ is a brand glyph (capital T struck by two bails), NOT a dollar sign — render `hero-cap`'s sibling SVG or a Label with the ₸ texture. Right: "SEASON 1 · CLUB" + "MATCH 1 of 7" (accent). Use match-about-to-play index, so 1 not 0.

**Fixtures chain** — 7 league dots + divider + 2 gold stage chips (SF, 🏆 final). Per dot: won = green fill, lost = red fill, upcoming = neutral with "M2…M7", current = `country-1` fill + `country-accent` ring + pulse animation (1.6s). 3-letter opp code caption under each (DUS, RIV, OLD, SAL, BUS, HAR, GRA). At season start, match 1 = the pulsing "now" dot, rest neutral.

**Player card** — Portrait 92×122 using `hero-cap.png`, corner_radius 9, with a **skill glow ring** colored by star tier (★1 #3a3d46, ★2 #79828d, ★3 blue, ★4 gold — Bongani ★½ → grey). Star-corner top-right (`★½`), jersey number bottom-center (`—` until assigned). Right side: name "B. KGOSI" (900), role "DURBAN · TOP-ORDER BAT", then a row with the **OVR tile** (gold rounded square, "33" / "OVR") + a **form chip** ("Tired", amber). Below: since `matches == 0`, show a dashed **empty-state box**: "No matches yet. Batting & bowling averages appear here once Karoo Kings have played." (Once games exist, replace with 2 batting [Avg, SR] + 2 bowling [Avg, Econ] stat cells — never zeros.)

**Jokers bench** — 4 slots. Empty = dashed border, "+ Win to earn". Slot 4 locked = "🔒 1st Level win". When filled later, apply rarity skins: common (plain), rare (blue border+glow), legendary (gold border + purple gradient).

**Affinity** — handshake icon + "AFFINITY · KAROO KINGS" label + right "building · +3% form at full" + a thin ProgressBar (~12%) filled `country-2 → country-accent`.

**CTA** — full-width gold gradient button, 2 lines: "FIRST MATCH ▶" (use "NEXT MATCH" after match 1) and small "v Dusty Plains · home".

## Data this screen binds (wire to my existing model)
```
Team        → badge code · name · stars · palette
SeasonState → leaguePos|"—" · points · level("Club") · matchIndex → "MATCH n of 7"
tonsBanked  → ₸ value
fixtures[]  → 7 Fx (result/stage/oppCode) + SF + final stage chips
Player      → portrait(stars→ring, form→face) · name · role · ovr · formChip
              · career{bat.avg, bat.sr, bowl.avg, bowl.econ}  OR empty-state if matches==0
ownedJokers → 0..4 slots (rarity skin); slot 4 locked until first Level win
affinity    → progress % + next-bonus copy
nextFixture → CTA label + "v {opp}"
```

## Transitions (stub the signals)
- CTA → Pre-Match scene
- Gear → Settings overlay · Info → context tooltip
- Position pill → League table (stub) · Player card / Jokers → drill-downs (stub)

Build the `Theme` resource first, then the scene tree, then bind the data. Match the reference image's spacing and proportions. Ask me before inventing any content not specified here.
