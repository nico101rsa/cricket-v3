# Cricket Sim · Design Handoff

A self-contained brief to continue designing this game. Read top-to-bottom — you'll have everything you need.

> **Status (2026-05-21):** game shape and scope are now defined in `CONTEXT.md` (domain glossary) and `docs/adr/0001`–`0002` (decision records). Where this doc's older framing conflicts with those, **they win.** Sections 1, 2, 6, 7, 11, 12 have been revised to reconcile; the in-match design (§3–5, §16) and visual system (§8) are unchanged and still authoritative.

---

## TL;DR

Mobile **roguelite cricket-career** that mashes **Balatro** (deck-builder with stacking modifiers — "jokers"), **Reigns** (swipe-decision cards), and **management** (a light career layer) into **~2:45 matches**. You are a single rising **Player** — a cricketer who captains in-Match — climbing a Career grid from club cricket toward the top. The sim auto-plays most of each match in a stats-rich data-viz feed; you make the few decisions that matter. Visual identity is **broadcast-chrome over Card Portrait avatars**, no 3D pitch view. Primary target: **South Africa & Australia**.

We have locked the **in-match screen design** and the game shape (see `CONTEXT.md`). Screens still to design: main menu, pre-match, result, the Career grid, Offers, Pay/upgrade. Squad/draft/scouting screens are deferred with the full management sim — see ADR 0002.

---

## 1. Game concept

### One-liner
You are a single rising cricketer — the **Player** — who captains your team in each ~2:45 match (5–8 critical decision moments wrapped around auto-played sim segments). You climb a **Career grid**: Levels (Club → City → Province) crossed with Tours (eight difficulty steps). Each grid cell is a **Season** — a ~20–30-minute playthrough (a 7-game league phase, then playoffs). Win the **Premium tour** at the top Level to complete the Career. (Full model: `CONTEXT.md`.)

### The three influences (and how they map)

| Influence | What it brings | How it lands here |
|---|---|---|
| **Reigns** | Swipe-decision cards · one-thumb · narrative prompts · binary choices | Used for **key moments** during a match (powerplay exit, wicket crisis, death plan, final-over bowling). Also used for **Manager Boost** interventions. |
| **Balatro** | Deck-builder · stacking modifiers · combos · "jokers" | A **Season** is the roguelite unit: between matches you draft **Jokers** that stack and combo. Jokers reset each Season; your Player's stats persist (rogue*lite*). |
| **Management** | Career trade-offs over time | A *light* career layer: Teams send **Offers** (team strength vs **Pay**), Pay is performance-scaled and buys Player upgrades, **Affinity** rewards loyalty. The full squad-management sim is deferred — see ADR 0002. |

### Match length: 2:45 (locked)

Research-backed (see Section 6 below). Long enough that each of the 5–8 decisions gets ~20–30 seconds of breathing room, short enough that several matches fit a typical mobile session.

---

## 2. Target market: South Africa & Australia

Primary target is **South Africa & Australia** — creator-fit over market-fit (see ADR 0001: the creator is South African, living in Australia, with playtest friends in both). India is deferred — possibly added later as content, but no longer a design driver. The constraints that survive that change:

- **No 3D pitch view** — Real Cricket / WCC3 own the broadcast-sim space with massive licensing moats; we can't compete on their axis with a fictional roster. A 2D data-viz match is also far cheaper to build well.
- **No real-league trade dress** — SA20, BBL, IPL: avoid their logos, kits, brand marks, named awards. See Section 7.
- **English-first commentary** — fake it with TTS-mocked samples + a language pill in the UI. (Hindi/Tamil/Telugu were India-targeting features — deferred.)
- **Stats density is welcomed, not feared** — cricket fans treat stat panels as entertainment, not friction. This is *why* the data-viz auto-sim works.
- **Franchise-style colour palettes** — descriptive team colours (see the 10-nation palette, §16.2) carry team identity without using licensed logos.
- **Fictional players & teams** — sidesteps player/board licensing entirely while staying culturally legible.

---

## 3. The match — locked design

### Match flow (60–90 sec wall time per innings)

```
PRE-MATCH (deck/tactics setup)            ← future screen, not yet designed
  ↓
1st INNINGS · BAT (~30s)
  Opening (2s)
  Auto-sim PP (4s)
  ⚡ Key Moment: PP Exit (3s swipe)
  Auto-sim middle (7s)
  ⚡ Key Moment: Wicket Crisis (3s swipe)
  Auto-sim build (5s)
  ⚡ Key Moment: Death Plan (3s swipe)
  Auto-sim death (3s)
  ↓
INNINGS BREAK (2s)
  ↓
2nd INNINGS · BOWL (~30s)
  Field set (2s)
  Auto-sim their PP (5s)
  ⚡ Key Moment: Bowling Change (3s swipe)
  Auto-sim middle (7s)
  ⚡ Key Moment: Star Bat on 49 (3s swipe)
  Auto-sim late (5s)
  ⚡ Key Moment: Final Over · ball-by-ball (5s, 6 micro-swipes)
  ↓
RESULT (5–10s · scorecard + decision recap + Play Again)
```

### Key-moment types (8 total — not every match hits all)

| Moment | Trigger | Decision pattern |
|---|---|---|
| ⚡ Powerplay Exit | End of over 6 (always) | Anchor vs Hunt |
| 🩸 Wicket Crisis | Lose key wicket (variable) | Settle new bat vs back to attack |
| 🏏 Milestone Ball | Batter on 49 or 99 (variable) | Play safe vs push the RR |
| 🎯 Bowling Change | Bowler stats decay (variable) | Spinner vs Wildcard vs Pace |
| 🛡 Field Set | Every bowling change | Defensive vs Catching trap |
| 💀 Death Plan | Overs 16+ (always) | 2s & 4s vs Big hits |
| 📞 DRS Review | Close call (rare) | Burn review vs save it |
| 🏆 Final Over | Final over of innings (always) | 6 ball-by-ball micro-swipes (yorker/slower/bouncer) |

---

## 4. The in-match screen (LOCKED) — see `mockups/match-screen-final.html`

### Layout, top to bottom

```
┌─────────────────────────────────────┐
│ NOTCH                                │
├─────────────────────────────────────┤
│ [RED IPL-style HEADER]               │  Team-vs-team banner
│   MUMBAI 🏏  vs  CHENNAI              │
├─────────────────────────────────────┤
│ [SCOREBAR]                            │  Score (gold), overs, CRR
│   72/2          1ST INNINGS           │  Target / chase on right
│   9.4 ov · 7.6   72 · 2 down          │
├─────────────────────────────────────┤
│ [BATTER STRIP — 2 chips, 50/50]      │  Striker highlighted gold
│   [pic] SHARMA 41*    [pic] SURYA 19* │
├─────────────────────────────────────┤
│ [BOWLER ROW — full-width, red-tinted]│
│  BOWL  [pic] KHAN spin 4★    1/24 (2.4)│
├─────────────────────────────────────┤
│ [COMMENTARY · Hindi pill + italic]   │
│  हि  "Sharma working it for two..."   │
├─────────────────────────────────────┤
│                                       │
│  ┌─ VIZ PANEL: Run Rate ──────┐     │  Current vs required
│  │  7.6 CRR     72 runs · 2W   │     │  (or chase target)
│  └───────────────────────────────┘  │
│                                       │
│  ┌─ VIZ PANEL: This Over ────┐     │  6 ball slots
│  │  [1][4][·][2][?][?]         │     │  filled live
│  └───────────────────────────────┘  │
│                                       │
│  ┌─ VIZ PANEL: Partnership ──┐     │  Names + runs(balls)
│  │  SHARMA & SURYA   32 (28)   │     │  + growing bar
│  │  ████████░░░░░░░░░░░         │     │
│  └───────────────────────────────┘  │
│                                       │
├─────────────────────────────────────┤
│ [DOCK — auto-sim bar + boost button] │
│  [▶▶ ────────────────]    (⚡ BOOST) │  Round green button
│                              ³        │  with count badge
└─────────────────────────────────────┘
```

### Two modes

1. **AUTO-SIM** — the resting state. Sim plays in 4–7 sec bursts. Score ticks, dot grid fills, commentary updates. The dock progress bar fills toward the next key moment. ~95% of in-match time.

2. **KEY MOMENT** — Reigns card overlay slides over the viz panels (matchup strip stays visible on top). Pulsing gold/red banner. Medium-size Card Portrait of the relevant player. Narrative prompt. Two-button swipe. Card animates left/right on choice. ~5% of in-match time.

3. **(Bonus) BOOST USED** — Manager Boost button triggers a green-tinted Reigns overlay. Same structure but green palette. Up to 3 per match.

### What's where — design rules

- **Chrome (header + scorebar)** is always visible, always the same.
- **Matchup strip (batters + bowler)** is always visible — you never lose track of who's playing.
- **Commentary line** updates as balls happen — short, dramatic, Hindi pill.
- **Viz panels** scroll/swap with mode. Currently 3 panels in auto-sim; replaced by Reigns card during key moment.
- **Dock (auto-sim + boost)** persists in auto-sim, hidden during a key-moment overlay.

---

## 5. Player avatars — locked: **Card Portrait** style — see `mockups/player-avatars-styles.html`

### Style spec
FIFA Ultimate Team / Marvel Snap / Hearthstone aesthetic. **Framed bust** with face, helmet/cap, jersey number, achievement badge in the frame, star rating, team-coloured frame.

### Three sizes
- **LARGE** (~88×110px) — squad/profile screens. Full detail.
- **MEDIUM** (~64×80px) — Reigns key-moment actor slot. Face, helmet, beard, number, badge, stars.
- **TINY** (~26×32px) — matchup strip chips, data-viz panels. Just helmet/cap colour + face + jersey colour. No text overlays.

### Three orthogonal layers stacking on one base avatar

1. **Achievement layer** (intentional, status-signal): captain marker, top-scorer badge, trophy stars, country flag, jersey number. IP-safe — see Section 7.
2. **Wear/history layer** (emergent, experience-signal): hat dirt/scuff, bat condition, jersey fade, beard length. These **age over seasons** — a veteran *looks* like a veteran without you reading text.
3. **Identity layer** (procedurally generated, stable per player, who-they-are): hair, facial hair, build, skin tone, accessories. Seeded by player ID so it never changes. ~6–10 variations per slot → thousands of unique combinations without 500 hand-drawn portraits.

### Example player data structure
```json
{
  "key": "SHARMA",
  "team": "mumbai",
  "role": "bat",
  "captain": true,
  "veteran": true,
  "beard": "grey",
  "face": "tan",
  "stars": 4,
  "number": 10,
  "badge": "CAPT",
  "helmet": "gold",
  "dirty": true
}
```

---

## 6. Match length: 2:45 (research-backed)

| Comp | Per-match | Why it matters |
|---|---|---|
| Cricket League (Miniclip) | 3–5 min | Dominant Indian casual cricket benchmark (92% IN downloads). The slot we're competing for. |
| Real Cricket Swipe | sub-3 min | Reviews call out *thinness / shallow decision moments*. Cautionary tale for going too short. |
| Balatro single ante | 3–5 min | Genre-correct cadence for "decisions with consequences inside a roguelike run." |
| Reigns single reign | sub-2 min | Successful at short length but reigns are *strung together inside a single session*. |
| Typical mobile session | short, several/day | At 2:45 you fit several matches per session with breathing room — the "one more match" loop fires repeatedly. |

**Concrete number: 2:45.** Each of 7 decisions gets ~22 sec of breathing room. Fits 3-min ad cap. Leaves 15 sec headroom for result screen + Play Again prompt.

**One fixed match length.** Every match is 2:45 — no separate short/long match modes. Cricket League, Reigns, Balatro all shipped a single core loop length.

---

## 7. IP-safe iconography rules (IMPORTANT — read this before designing more)

**Personal project · steering safe on IP.** Do **not** use trade dress from real leagues — SA20, BBL, IPL or any other.

### Banned
- "Orange Cap" / "Purple Cap" naming or the BCCI/IPL colour+concept pairing (orange for top batter, purple for top wicket-taker)
- Direct mimicry of IPL franchise logos, kits, brand marks
- Real player names/likenesses

### Safe
- The **concept** of award caps is fine — many sports use achievement markers
- **Generic** colour-coded jerseys (Mumbai-blue, Chennai-yellow — these are descriptive colours, not the licensed logos)
- **Fictional** player names ("Sharma" as a common surname is fine; "Rohit Sharma" with portrait of the real player is not)
- Our own achievement vocabulary:
  - **Gold helmet / gold frame** → your captain
  - **★ stars (1–4)** → player tier
  - **Text badges** (`CAPT` / `STAR` / `RKE` / `VET`) → role/tier, no colour-coded league awards
  - **Dirty/scuffed equipment** → emergent veteran signal
  - **Jersey colour** → team identity (you pick palette per franchise — pick distinctive but not IPL-derivative)

(Not legal advice — for a release worth a 30-min IP-attorney chat first.)

---

## 8. Visual style guide

### Colour palette

| Use | Hex | Notes |
|---|---|---|
| Background | `#1a1a22` | Dark slate |
| Phone bezel | `#0d0d12` | Near-black |
| Header gradient | `#c41e3a → #8b0000` | IPL-style red |
| Score / accent gold | `#ffd166` | Primary "wow" colour |
| Warning / required RR | `#f5a623` | Orange-amber |
| Danger / opponent / wicket | `#ef6c6c` / `#c41e3a` | Reds |
| Friendly / team / single | `#4a90e2` / `#6ec1e4` | Blues |
| Boost / positive action | `#2ecc71 → #16a34a` | Bright green gradient |
| Veteran-cap gold | `#f5cb50 → #b8860b` | Helmet metal |
| Mumbai jersey | `#1e88e5 → #0d47a1` | Blue gradient |
| Chennai jersey | `#ffd744 → #c08800` | Yellow gradient |
| Surface raised | `rgba(255,255,255,0.04)` | Panel BG |
| Borders / dividers | `rgba(255,255,255,0.1)` | Subtle |

### Type
- System font stack: `-apple-system, BlinkMacSystemFont, sans-serif`
- Size scale (mobile): `8 / 9 / 10 / 11 / 12 / 14 / 16 / 22 / 26 / 36` px
- Weights: 400 / 700 / 800 / 900
- All caps + letterspacing 1–2px for **labels**, plain title-case for body
- `font-variant-numeric: tabular-nums` for any stat row

### Spacing
- 4px base unit
- Standard gaps: 4 / 6 / 8 / 10 / 14 / 18 / 24 px
- Phone padding: 14px inner
- Border-radius: panels 8px, cards 12px, buttons 8–10px, round buttons 50%

### Iconography
- Emoji as placeholders (🏏 ⚡ 💀 🎯 🛡 🩸 🔄 🎙️) — replace with custom icon set later
- ★ for stars (filled) / ☆ (empty)
- ▶▶ for fast-forward

### Motion / animation
- Score bump: `scale(1.15)` ease 250ms when a ball lands
- Ball-result pop: `scale(0 → 1.3 → 1)` ease 400ms
- Reigns card shake on choice: `translateX ±30px rotate ±3deg` ease 350ms then fade
- Boost button glow: `opacity 0.4 → 0.8` 2.4s infinite
- Banner pulse on key moment: `opacity 1 → 0.75` 1.4s infinite

---

## 9. Manager Boost mechanic (semi-locked — strawman)

- **3 boosts per match**, scarce resource
- Tapping the round green button mid-sim **interrupts** with a green Reigns card
- Card offers **2 boost choices** drawn from a context-aware pool:
  - **Pep Talk** — +20% dot ball % for next 6 balls
  - **Field Switch** — force a strike rotation
  - **Substitution** — sub in a fresher bowler
  - **DRS Review** — challenge the umpire on the last appeal
  - **Captain's Word** — next key-moment decision gets a +10% favourable outcome
- Tracked on result screen ("Boosts used: 2/3") for replay/sharing tension

This solves the "am I really playing during auto-sim?" risk and adds a Balatro-style consumable layer.

---

## 10. Reference mockups in this folder

All mockup HTML is in `docs/mockups/`. Open them in a browser to see the visual treatment.

| File | What it shows |
|---|---|
| `match-screen-final.html` | **The locked design**. 4 phone frames: AUTO-SIM, KEY MOMENT, BOOST USED, RESULT. This is the source of truth for the in-match screen. |
| `playable-prototype.html` | **Playable** version with portraits. Tap-through the 70-sec demo match. Useful for feeling the pacing and decision rhythm. |
| `player-avatars-styles.html` | Three art-style options for player avatars (Silhouette / Cartoon / Card Portrait). We picked **Card Portrait**. Useful to see the rejected alternatives. |

Tip: when feeding these to Claude.ai for further design, **paste the relevant HTML directly** so Claude can see the actual styles, sizes, and CSS. The screenshots alone lose detail.

---

## 11. Screens still to design

The in-match screen is locked. Everything else is open.

**Note (2026-05-21):** items 3, 4, 9, 11 (squad, player detail, player development, draft/scouting) are deferred with the full management sim — see ADR 0002. New screens this list predates: the **Career grid**, the **Offer** screen, the **Pay/upgrade** screen.

Suggested order:

### High priority (needed to ship a playable game)
1. **Main menu / home** — Play Match, Squad, League, Settings, etc.
2. **Pre-match screen** — opponent, conditions, your XI, tactic deck preview, Play button
3. **Squad screen** — your full squad with Card Portraits, ratings, role filters, captain selection
4. **Player detail / profile** — full Card Portrait at LARGE size, full stats, career trajectory, equip-tactic-card slot
5. **League table / standings** — your team's position, points, NRR, top scorers, fixtures
6. **Result deep-dive** — extended scorecard with batting/bowling figures, partnership graph, decision recap

### Medium priority (season meta)
7. **Season hub** — current month, upcoming fixtures, season objectives, deck-builder access
8. **Deck builder / tactic shop** — Balatro-style; spend match rewards to acquire new tactic cards (jokers) for next match
9. **Player development** — train players, manage fitness/wear, retire veterans
10. **Achievements / records** — best individual scores, longest winning streaks, etc.

### Lower priority (depth + monetisation)
11. **Draft / scouting** — pick up new players between seasons
12. **Tutorial / first-run onboarding** — interactive walkthrough of one match
13. **Settings** — language (English first), audio toggles, account, etc.
14. **Store** — IAP for cosmetics / boosts / season pass

### Cultural-flavour extras
15. **Commentary playback** — English audio samples library, pick voice persona
16. **Stadium select** — flavour skins for different cities

---

## 12. Open design questions

Status as of 2026-05-21:

- ~~**Career length**~~ — **Resolved.** A Career = climbing the grid to win the Premium tour at the top Level (`CONTEXT.md`). First build ships 3 Levels.
- ~~**Match modes**~~ — **Resolved.** No quickplay/career split — the career *is* the game; every match is 2:45.
- ~~**Player-relationship spectrum**~~ — **Resolved-ish.** You are *one* Player you grow; other players are squad strength. Deep player-collection is deferred (ADR 0002).
- **Joker count & stacking limits** — open. 4 slots shown in-Match (§16.7); pool size and stacking caps TBD (Gameplay & Jokers themes).
- **Modifier / Tour difficulty tuning** — open (Gameplay & balance theme).
- **Monetisation model** — open, low priority (personal project).
- **Multiplayer** — deferred (solo-only for first build).
- ~~**Failing a Season**~~ — **Resolved.** Fail a Season (4th or worse) → retry the cell, keep all progress; the cost is a Season on the lifetime tally (`CONTEXT.md`).

---

## 13. What I'd ask Claude.ai to design next

If you want a concrete starting prompt to paste into a fresh Claude.ai conversation:

> I'm designing a mobile cricket sim game. Attached is a design handoff doc capturing what's already locked, and three HTML mockups showing the in-match screen. I want to design the **[Squad screen / Pre-match screen / League table / etc.]** next. Use the same Card Portrait avatar style, IPL-style broadcast chrome, gold/red/blue palette, and IP-safe iconography rules from the doc. Build mockup HTML I can preview in a browser. Show 2–3 options for the layout and recommend one.

Attach this doc + the relevant mockup HTML files.

---

## 14. Tone / voice / vibe references

- **Broadcast chrome** = Star Sports / JioCinema cricket coverage (persistent scorebar, ticker, multi-language commentary)
- **Card aesthetic** = FIFA Ultimate Team + Marvel Snap (premium frames, jersey number, achievement badge)
- **Decision drama** = Reigns (one card, two choices, weighty narrative prompts under 12 words)
- **Stat density** = Dream11 / Cricinfo (Indians love stats — show more, not less)
- **Run feel** = Balatro (one match = one ante; modifier stacking; consumable items; meta-progression between matches)
- **Match pacing** = Cricket League (snackable, ~3 min, complete arcs)

---

## 15. Tech notes (so design respects constraints)

- **Mobile-first**, vertical, 9:16-ish phone frame
- **iOS + Android** target
- **Runs on 3GB RAM phones** — keep visual density modest, no 3D, no large textures
- **Offline-capable** preferred (no real-time multiplayer in v1)
- **Localisation slots** for Hindi / Tamil / Telugu / English from day 1

---

*Last updated: 2026-05-18. Personal project — Nico McDonald.*

---

## 16. Hi-Fi v1 addendum — design system evolution (claude.ai, 2026-05-19)

Reference: `docs/mockups/in-match-hi-fi-v1.html`

The hi-fi pass on claude.ai significantly evolved the visual system. The locked aesthetic (dark slate bg, red gradient header, gold accent, system font, tabular nums) is unchanged — but several new concepts emerged and should propagate to every other screen designed from here on.

### 16.1 CSS variable system (NEW · canonical)

Fully tokenised. Use these vars everywhere — no hardcoded hexes.

```css
:root {
  --bg: #0f0f14;            --bg-2: #16161e;
  --bezel: #0d0d12;         --bezel-edge: #2a2a35;
  --red: #c41e3a;           --red-dark: #8b0000;       --red-bright: #ef6c6c;
  --gold: #ffd166;          --gold-warn: #f5a623;
  --green: #2ecc71;         --green-dark: #16a34a;
  --blue: #4a90e2;          --blue-bright: #6ec1e4;
  --blue-mum-1: #1e88e5;    --blue-mum-2: #0d47a1;
  --yellow-che-1: #ffd744;  --yellow-che-2: #c08800;
  --white-soft: rgba(255,255,255,0.85);
  --white-mid:  rgba(255,255,255,0.65);
  --white-dim:  rgba(255,255,255,0.45);
  --white-faint:rgba(255,255,255,0.25);
  --surface:    rgba(255,255,255,0.04);
  --surface-2:  rgba(255,255,255,0.07);
  --border:     rgba(255,255,255,0.08);
  --border-strong: rgba(255,255,255,0.15);
  /* country palette — swap via body[data-country] */
  --country-1: #c41e3a;     --country-2: #8b0000;
  --country-glow: rgba(196,30,58,0.35);
  --country-accent: #ef6c6c;
}
```

### 16.2 10-nation country system (NEW)

Default = India (red). `body[data-country="aus|eng|sa|nz|pak|sri|wi|ban|afg"]` swaps the header gradient + accent + glow. Team names auto-swap per country (Mumbai/Chennai → Sydney/Perth → London/Manchester etc.). **This is the canonical multi-region pattern — use it on every screen, not just the match.**

| Country | Palette |
|---|---|
| India 🇮🇳 | `#c41e3a / #8b0000`, accent `#ef6c6c` (default) |
| Australia 🇦🇺 | `#0E703F / #063a20`, accent `#FFCD00` |
| England 🏴 | `#1E2761 / #0a1238`, accent `#C8102E` |
| South Africa 🇿🇦 | `#007749 / #003e26`, accent `#FFB81C` |
| New Zealand 🇳🇿 | `#262626 / #000000`, accent `#cccccc` |
| Pakistan 🇵🇰 | `#01411C / #001b0a`, accent `#7CB342` |
| Sri Lanka 🇱🇰 | `#1F4788 / #0d2654`, accent `#FFCC00` |
| West Indies 🌴 | `#7B1A1A / #3a0808`, accent `#FFD700` |
| Bangladesh 🇧🇩 | `#006A4E / #003524`, accent `#F42A41` |
| Afghanistan 🇦🇫 | `#1A4097 / #0a1f4d`, accent `#D32011` |

### 16.3 Portrait — evolved to "split-bg" (REPLACES Section 5 fidelity)

The frame is now a horizontal **split** within the portrait BG: top half = sky (skill tier), bottom half = ground (confidence tier), with a 1px horizon line between. Elite (`skill-4`) gets a **golden sun** in the upper-right of the sky.

| Skill tier | Sky | Meaning |
|---|---|---|
| `skill-4` | gold/amber + ☀ sun | elite (4★) |
| `skill-3` | sky blue | default (3★) |
| `skill-2` | silver/grey | 2★ |
| `skill-1` | charcoal | rookie (1★) |

| Confidence | Ground | Meaning |
|---|---|---|
| `conf-hot` | gold/amber | in form / streaking |
| `conf-steady` | green | reliable / current |
| `conf-tired` | brown | fatigued |
| `conf-cold` | grey | out of form |

**Why this matters:** the portrait now carries *two extra layers* (current skill *and* current form) at a glance — no text needed. A veteran with dirty helmet on green ground = experienced and feeling good. A rookie on brown ground = green and struggling. This is a much stronger emergent-storytelling lever than what Section 5 originally specified.

The achievement/wear/identity 3-layer model from Section 5 still applies on top.

Portrait sizes are now: `tiny` (28×34), `med` (72×92). Large variant TBD for squad screens.

### 16.4 Player intent indicator (NEW)

Each batter chip now shows current **intent** under their runs:
- "Attacking" · "Hunting" · "Slogging" — aggressive
- "Consolidating" · "Anchoring" — steady
- "Searching for Single" — desperate (no boundaries)
- "Set" / "Settled" / "Building"

On-strike intent = gold; off-strike = grey. Replaces "the asterisk is the only state indicator" with something narratively richer.

### 16.5 Scorebar with par-RR indicator (EVOLVED)

The score block now has a 3rd column: **par RR delta**. Above target = `+5` in blue/green; below = `−0.4` in red. Tells you at a glance if you're winning before reading any stats.

### 16.6 CRR worm chart — REPLACES the data-viz panels (Section 4)

**Important: the 3 viz panels (Run Rate / This Over / Partnership) from the original locked design are SUPERSEDED.** They're replaced by a single richer chart that *is* the emotional centre of the screen now.

Layers (back to front):
1. **Background** = stadium night scene: two-tone sky/grass split, floodlights L+R (`✦`), moon at upper-right, crowd-silhouette bowl-shape SVG procedurally generated with ellipse "heads" in 4 rows.
2. **Bars** = one per over so far + faint ghost bars for upcoming overs. Height = runs that over. Colour: blue (default), gold (boundary-heavy), red (wicket). Current over has animated pulse stripe.
3. **CRR worm** = white line over the bars showing CRR trajectory per over, white dots at each over, pulsing gold halo at the current position.
4. **Target line** = dashed red horizontal line at the required RR.
5. **Legend** (CRR · target) in a small blurred backdrop pill.
6. **Axis labels** = over numbers at the bottom.

This is one chart doing 5 things — replaces three separate panels and reads as "watching cricket" instead of "reading a spreadsheet". **Use this pattern (stadium scene as data-viz canvas) for any other in-match charts we design.**

### 16.7 Jokers panel — Balatro layer goes first-class (NEW)

Below the chart: a row of **4 joker slots**.

- **Common** — white pip, neutral border
- **Rare** — blue pip, blue border + soft glow, blue gradient bg
- **Legendary** — gold pip, gold border + glow, dark purple gradient bg
- **Empty** — dashed border, "+slot 4 · earn"

Each card shows: emoji icon (e.g. 🌶 👑 🛡), name (`HOT STREAK`), effect (`×2 if 3 in row`). Cards with synergies show a **gold pill hanging below** (e.g. "+ pairs Captain").

**This formalises the Balatro layer** as first-class UI — your stacking modifiers aren't tooltip text anymore. Section 1's "Balatro" influence is now genuinely visible in the moment-to-moment screen.

### 16.8 Water-meter Boost button — evolved (REPLACES Section 9 strawman)

The boost is no longer a "3 per match" counter. It's a **water-meter that refills over time**.

- Round 66px button (unchanged)
- Bottom-up water fill animates over ~12 seconds (empty → full)
- States:
  - **Charging** (< 50%) — dim, not pressable, shows `5%` / `34%` etc.
  - **Available** (50–99%) — glowing green, ramping
  - **Full** (100%) — max glow, urgent pulse
- **The fill % IS the boost strength** — use early for a weaker effect, wait for max
- Click → resets to 5%, starts charging again

This is much better than the strawman in Section 9. **It solves "should I save my boost?" tension elegantly** — the answer is always a live trade-off between strength and time. The pep-talk / field-switch / substitution menu still appears on click; only the gating model changed.

Match-length tuning: at ~2:45 per match, a 12-sec recharge gives ~13 max-strength uses possible — natural cap is "as many as you can fit". Adjust the recharge interval to throttle.

### 16.9 Dock indicator — "thinking…" (EVOLVED)

Replaces the ▶▶ progress bar. A subtle "next ball ⋯" pill with three animated bobbing dots. Doesn't compete visually with the chart, communicates "sim is running" without claiming attention.

### 16.10 Stats-strip (NEW · optional)

A thin horizontal row above/below the chart for tactical context: `MATCHUP` (mini-gradient bar with a needle, red→amber→gold→green), `FIELD` pill (red `DEFENSIVE` / `ATTACKING`), `DRS` pips (green dots, dimmed when used). Use when surfacing tactical info matters; can hide in calm phases.

### 16.11 Header stadium icon / venue badge (NEW)

The header now has a venue badge on the right with a tiny stadium silhouette icon and uppercase 2-3 letter venue code (`MUM` / `CHE` / `MCG` etc.). Cheap detail, big "feels like broadcast" payoff.

### 16.12 Updated frame status

In hi-fi now:
- ✅ Auto-sim (with chart + jokers + water-boost)
- ✅ Key Moment — Powerplay Exit example
- ✅ Boost Used — green Reigns variant

Still to build in hi-fi:
- ⏳ Result screen (highest priority — closes the match arc)
- ⏳ 5 more key-moment variants: Wicket Crisis · Milestone Ball · Bowling Change · Field Set · DRS Review · Final Over ball-by-ball
- ⏳ Innings break transition
- ⏳ All other screens (squad, league, pre-match, season hub, etc.)

### 16.13 What overrides what

Where Sections 4 / 5 / 9 of this doc conflict with this addendum, **the addendum wins**. Specifically:
- Section 4's three viz panels → REPLACED by the CRR worm chart (Section 16.6)
- Section 5's three avatar layers → still applies, but now stacked on the split-bg portrait (Section 16.3), not the original framed bust
- Section 9's Manager Boost strawman → REPLACED by the water-meter model (Section 16.8)

Everything else in the original doc still holds.

---

*Hi-Fi addendum last updated: 2026-05-19.*
