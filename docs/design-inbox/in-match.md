# PASTE THIS INTO YOUR GODOT AI

> Attach alongside this text:
> 1. **`in-match-reference.png`** — the exact visual target (all 5 states, 390×844 each).
>
> This is a **translation, not a redesign.** The locked layout is `docs/mockups/match-screen-final.html`
> ("revised layout v4"). This spec pins its sizes, spacing and tokens so the Godot build matches on
> the first pass, **re-themed to the shipped SA / Karoo Kings palette** via `Palette.country_set(Country.Code.ZA)`.
> Only the colours change from v4 — the structure is identical. Names/numbers in the render are
> illustrative placeholders; bind them from the match model.

---

You are building the **In-Match** scene in my Godot cricket game (mobile, 390×844 portrait, 9:16).
It is **one dense screen, no scroll**, 13px safe-area inset. The live match plays inside it; the
Key Moment / Boost / DRS cards are **modal pauses drawn over the same screen** (the scoreboard +
matchup stay visible behind them). Five built states — see the reference image, left to right:
**Auto-sim · Key Moment · Boost · DRS · Result.**

## Hard rules (game)
- **OVR + match stats only.** Never show raw `PWR/COM/ATT/CON`. Batters read `runs* (balls)` + `★` tier;
  bowlers read figures `wkts/runs (overs)` + `econ` + `★` tier. The actor card shows `OVR nn`.
- **Cricket score formats:** SA team score = **runs/wickets** (`72/2`); bowling figures = **wkts/runs** (`1/24`).
  (AUS reskin flips the team score to `2/72` — handled by the same country swap, not this screen's logic.)
- **Currency** is **₸** — not used on this screen (no money shown); listed only so you don't introduce `$`.
- **Country reskin = the four `country_*` tokens only.** SA default (green) shown here. Bowling/opponent
  team is drawn in the **other** country accent (amber) for contrast — see Re-theme below.
- **Modal overlays pause the sim;** they never navigate away. The matchup chrome behind them is dimmed
  by a scrim, not unloaded.
- **Buildable:** Labels / Panels / StyleBoxFlat / ProgressBar only. No CSS gradients/filters — gradients
  are approximated (solid blend + a glow `shadow_color`), exactly as `UIStyle.header()` already does.

## Layout / vertical rhythm
Top-anchored stack, `VBox` separation **7**, inside a full-rect Control with margin **13**. Reading order
(locked in v4): **HEADER → SCOREBAR → BATTERS → BOWLER → COMMENTARY → BODY**. The **BODY** is `flex`/expand:
it holds the viz panels (Auto-sim) or an overlay (Key Moment/Boost/DRS) or the Result block, and it eats
the vertical slack so there's no dead gap. The **dock** (auto-sim bar + round BOOST) pins to the bottom of
the body.

---

## NODE TREE (Auto-sim — the base state)
```
InMatch (Control, full-rect, margin 13)
└─ VBox (separation 7)
   ├─ Header (PanelContainer — country header bg + glow)
   │  └─ HBox: BatBadge(22) + BatName  ·  "vs"  ·  OppName + OppBadge(22)
   ├─ Scorebar (PanelContainer)
   │  └─ HBox: VBox[ScoreBig / ScoreMeta]  ⟷  VBox[sub / TargetBig / sub]  (right-aligned)
   ├─ Batters (HBox, separation 7, equal width)
   │  ├─ ChipStrike (PanelContainer)  : Portrait(30×36 ring) + VBox[Name / runs]
   │  └─ ChipOff    (PanelContainer)  : Portrait(30×36 ring) + VBox[Name / runs]
   ├─ BowlerRow (PanelContainer — opponent-accent tint)
   │  └─ HBox: "BOWL" lbl · Portrait(30×36) · VBox[Name / spin·4★·ov·econ] · Figures(right)
   ├─ Commentary (PanelContainer — left accent bar)
   │  └─ HBox: LangChip · CommentaryLabel(italic)
   └─ Body (Control, expand)
      └─ VBox (separation 7, expand)
         ├─ VizRunRate (PanelContainer)   : label + HBox[CRR big ⟷ runs/down]
         ├─ VizThisOver (PanelContainer)  : label + GridContainer(6 cols) of BallCell
         ├─ VizPartnership (PanelContainer): label + HBox[names ⟷ runs(balls)] + ProgressBar
         └─ Dock (HBox, separation 12, bottom-anchored)
            ├─ AutoSimBar (PanelContainer, expand) : "▶▶" · ProgressBar · "2×"
            └─ BoostButton (round 60×60)
```
Every `PanelContainer` above = **`UIStyle.panel()`** unless noted (bg `SURFACE`, 1px `BORDER`, radius 11,
content margin 9v × 11h).

---

## PER-BLOCK SPECS  (size · spacing · type · token)

### Header  — `UIStyle.header(set.grad1, set.grad2, set.glow)`
- Height ~40. Content margin 10v × 11h (header() default). Radius 11.
- bg = `country_set(ZA)` blend `COUNTRY_1_SA #007749 → COUNTRY_2_SA #003e26`; `shadow_color = COUNTRY_GLOW_SA`, `shadow_size 10`.
- **BatBadge / OppBadge:** 22×22, radius 6, bg `Color(0,0,0,0.28)`, label 9px/900. Bat badge text = `COUNTRY_ACCENT_SA #FFB81C`; Opp badge text = opponent accent (amber `#f59e0b`).
- **BatName** 13px/800 `WHITE`. **"vs"** 11px/600 `WHITE_MID`. **OppName** 13px/700 `WHITE_SOFT`.

### Scorebar  — `UIStyle.panel()`, border overridden to `Color(COUNTRY_1_SA, a=0.4)`
- Height ~64. Padding 10v × 13h.
- **ScoreBig** 30px/800 `GOLD`, tabular. **ScoreMeta** 11px `WHITE_MID`, UPPER, +1 tracking.
- **Target (right):** sub 10px UPPER `COUNTRY_ACCENT` ("1ST INNINGS" / "CHASING" / "RESULT");
  TargetBig 19px/800 `WHITE`; second sub 10px `WHITE_DIM`.

### Batter chips  — base `UIStyle.panel()`; on-strike `UIStyle.goal_panel()`
- Two equal HBox cells, separation 7. Each: padding 7v × 9h, radius 9, gap 9.
- **On-strike** reuses `goal_panel()` (faint gold tint + gold border) — Name renders `GOLD`.
- **Off-strike** = `panel()` — Name `WHITE`.
- **Portrait** 30×36, radius 8, `UIStyle.portrait_ring(Palette.skill_ring(stars))` (3px tier ring;
  4★ gold, 3★ blue, 2★ silver, 1★ charcoal). Art = TextureRect behind the ring; placeholder = team-tinted fill.
- **Name** 13px/800, ellipsis. **runs** 11px `WHITE_MID` tabular; leading `★` = `GOLD` when on strike.

### Bowler row  — opponent-accent tinted full-width row  ⚠ new token `UIStyle.team_row(accent)` (see below)
- Height ~46. Padding 7v × 9h, radius 9, gap 9.
- Tint: bg `Color(opp_accent, 0.12)`, border `Color(opp_accent, 0.5)` 1px. `opp_accent` = the **opponent's**
  `country_set().accent` (amber at SA default).
- **"BOWL"** label 9px/800 UPPER `opp_accent`. **Name** 13px/800 `opp_accent`.
  **stat** 10px `WHITE_MID` (`spin · 4★ · 2.4 ov · econ 8.9`). **Figures** 15px/800 `WHITE` tabular;
  the `(2.4)` overs suffix 10px/600 `WHITE_DIM`.

### Commentary  — `UIStyle.panel()` with `border_width_left = 3`, `border_color = GOLD_WARN`, radius 0/9/9/0
- Height ~32. Padding 7v × 11h, gap 8.
- **LangChip** bg `GOLD_WARN`, text `#000` 8px/800, padding 2×5, radius 4 (locale tag, e.g. `ZU` / `AF`).
- **Commentary** 11px italic `WHITE_SOFT`. (Copy bound from the commentary engine.)

### Viz · Run rate  — `UIStyle.panel()`
- panel label 9px UPPER `WHITE_DIM`. **CRR** 34px/800 `GOLD`, sub 8px `WHITE_DIM`.
- Right "required/runs" value 21px/800 `RED` (urgency), sub 8px `WHITE_DIM`.

### Viz · This over  — `UIStyle.panel()` + 6-col GridContainer  ⚠ new token `UIStyle.ball_cell(kind)`
- 6 square cells, separation 6, `aspect 1`, radius 6, 14px/800 tabular. Cell fills by outcome:
  - `dot` → `SURFACE_2`, text `WHITE_DIM`
  - `run` (1–3) → `Color(BLUE,0.22)`, text light-blue
  - `four` → `GOLD`, text `#000`
  - `six` → `GREEN_DARK`, text `#fff`
  - `wicket` → `RED`, text `#fff`
  - `pending` → `SURFACE_2` @ 40% opacity, `?`

### Viz · Partnership  — `UIStyle.panel()` + `UIStyle.bar_track()/bar_fill(COUNTRY_ACCENT)`
- meta row 12px (`WHITE_SOFT` names ⟷ `GOLD` runs). Bar height 8, radius 4, fill `COUNTRY_ACCENT`.

### Dock
- HBox, separation 12, anchored to body bottom.
- **AutoSimBar** (`expand`), height 56, radius 13 ⚠ new token `UIStyle.autosim_bar()`:
  bg `Color(COUNTRY_ACCENT,0.12)`, border `Color(COUNTRY_ACCENT,0.4)` 1px. Contents: "▶▶" 14px/800 `COUNTRY_ACCENT`,
  a `bar_track()`/`bar_fill(COUNTRY_ACCENT)` 5px progress, speed "2×" 11px/800 `WHITE_MID`.
  *(v4 collapsed the discrete Back/Step/Speed controls into this one bar — see Open Questions.)*
- **BoostButton** ⚠ new token `UIStyle.boost_button()`: 60×60 round, bg `GREEN_DARK` (radial approximated:
  solid `GREEN_DARK` + `shadow_color = Palette.form_glow(2)` i.e. GREEN glow, `shadow_size 10`),
  2px `GREEN_DARK` border. Bolt ⚡ 22px + "BOOST" 9px/800. **Count badge** top-right: 22×22 round,
  bg `GOLD`, text `#000` 12px/900, 2px `GREEN_DARK` border. States: `BOOST (3)` available →
  pressed dims + count −1 → `0` = disabled (grey via `SKILL_1`).

---

## OVERLAY SYSTEM (Key Moment · Boost · DRS) — modal pause
All three share one skeleton drawn over the Body:
```
Overlay (Control, full-rect over Body)
├─ Scrim (ColorRect rgba(0,0,0,0.78))
└─ VBox (margin 8, separation 9)
   ├─ Banner (PanelContainer, radius 9, 8px pad, 13px/800, +2 tracking, centered)
   └─ MomentCard (PanelContainer, expand, radius 13, 14px pad)  ⚠ new token UIStyle.moment_card(kind)
      ├─ Ctx     (10px UPPER, +1.6 tracking, centered)
      ├─ Actor   (inner Panel rgba(0,0,0,0.45), radius 9, 10px pad, gap 12)
      │          : Portrait(62×78, portrait_ring) + VBox[Name 17/800 · tag 10 · stats 9 UPPER]
      ├─ Scene   (expand, centered emoji ~42px)        ← decorative state glyph
      ├─ Narr    (13px italic, centered, <b>=GOLD)      ← the question
      └─ Choices (HBox, separation 8): two Choice buttons (radius 9, 11px pad)
                 verb 14/800 · stake 9 WHITE_MID
```
**Banner / card colour by kind:**

| kind | Banner bg / text | Card bg (`moment_card`) | Ctx | Choice accents |
|---|---|---|---|---|
| **Key Moment** | `GOLD_WARN` / `#1a1205` | deep green-black `MOMENT_1→MOMENT_2` | `GOLD` | left `BLUE`, right `RED` |
| **Boost** | `GREEN_DARK` / `#fff` | `MOMENT_BOOST_1→2` | `#6dd49a` | both `GREEN` |
| **DRS** | `BLUE` / `#06203f` | `MOMENT_1→2` | light-blue | Accept `RED`, Review `BLUE` |

- **Key Moment** — title `⚡ KEY MOMENT ⚡`. Batting variants: ⚡ Powerplay Exit (over 7) · 🩸 Wicket Crisis
  (first middle wicket) · 💀 Death Plan (over 16). Bowling variants: 🎯 Powerplay Exit · 🔥 New Batsman In ·
  💀 Death Defence. Two-button call; ctx line = score + over + phase.
- **Boost** — title `⚡ MANAGER BOOST ⚡`. ctx = `timeout · n boosts left`. Actor name = `YOUR CALL`, tag =
  "burn a boost?". Two green choices. Firing this decrements the dock BOOST count (`3→2`).
- **DRS** — fires **only when YOU'RE given out**. Banner `⚖ DRS · REVIEW?`. ctx = dismissal + "umpire's call".
  Actor = your batsman, tag "Given OUT — …". Choices: **✗ ACCEPT** (take the wicket) · **REVIEW ↑ (n left)**.
  On Review → **outcome popup** (centered Panel ~230 wide, `moment_card` bg, `BORDER_STRONG`): big result
  `✅ NOT OUT` (`GREEN`) / `❌ OUT` (`#ef6c6c`) + detail line + an **OK** button (`SURFACE_2`). Wrong call
  spends a review; correct one is retained. *(Reference shows the NOT-OUT popup inset over the decision.)*

---

## RESULT state
Body holds a centered block (no viz, no dock). Header `def`, Scorebar shows **WON** (`GREEN`) / **LOST**
(`RED`) + margin, Target = `+1 league point` (`COUNTRY_ACCENT`). Commentary bar stays.
- **Headline** 30px/900 `GREEN`(won)/`RED`(lost). **Margin** 12px `WHITE_MID` (`vs Opp · date · level`).
- **Innings lines** ×2 — `panel()` rows, 13px, score `GOLD` bold: `KAROO KINGS 1st  162/5 (20)`.
- **Decision recap** — `panel()` w/ `border_width_left 3` `COUNTRY_1_SA`, bg `Color(COUNTRY_1_SA,0.08)`:
  title 9px UPPER `COUNTRY_ACCENT`, bullets 11px `WHITE_SOFT`, values `GOLD` (PP exit / death plan /
  bowling change / boosts used / DRS retained).
- **CTA** `UIStyle.cta(GOLD)` — `PLAY AGAIN ▶`, 14px/800 `#1a1205`.

---

## RE-THEME MAP  (v4 red → SA, what changed)
| v4 (Mumbai/Chennai red) | → SA / Karoo Kings token |
|---|---|
| header `#c41e3a→#8b0000` | `COUNTRY_1_SA→COUNTRY_2_SA` + `COUNTRY_GLOW_SA` |
| target / autosim amber `#f5a623` | `COUNTRY_ACCENT_SA #FFB81C` |
| bowler red tint | **opponent** `country_set().accent` (amber) |
| commentary lang `हि` | SA locale tag `ZU` (isiZulu) — bound |
| moment card purple `#2c1a4d` | **new** deep green-black `MOMENT_*` (token below) |
| result headline blue / start-btn red | won = `GREEN` · CTA = `GOLD` |
GOLD / BLUE / RED / GREEN ball + choice semantics are **unchanged** (they encode outcomes/affordances, not team).

## Type scale (px)
micro-labels 8–9 (UPPER, +1–1.6 tracking, 700–800) · body 10–11 · names 13 (/800) · figures 15 ·
score 30 · CRR 34 · headline 30 (/900). All numbers tabular.

## Data bindings (wire to the match model)
```
match.battingTeam/bowlingTeam → name · badge · country palette (mine vs opp accent)
innings   → "72/2" · "9.4 ov · CRR 7.6" · target/chasing line
striker / nonStriker → portrait(stars→ring) · name · runs*(balls) · onStrike
bowler    → portrait · name · type · stars · figures wkts/runs(overs) · econ
thisOver[]→ up to 6 BallCell kinds (dot/run/four/six/wicket/pending)
partnership → names · runs(balls) · % of innings (bar)
commentary → langTag + line
boosts    → remaining count (dock badge + Boost overlay)
keyMoment → trigger(phase) · title · ctx · 2 choices
drs       → triggered(playerOut) · dismissal · reviewsLeft · outcome
result    → won/lost · margin · leaguePts · innings lines · decision recap
```

## Transitions (stub signals)
BoostButton → Boost overlay · choice → apply + resume · KeyMoment auto-fires on trigger → resume ·
DRS Review → outcome popup → OK resume · Result CTA → next match / hub.

---

## NEW tokens to add (design needs these — please name + add to Palette/UIStyle)
1. **`Palette.MOMENT_1 #16271d` / `MOMENT_2 #0a130e`** and **`MOMENT_BOOST_1 #123524` / `MOMENT_BOOST_2 #08160f`**
   — the dramatic overlay-card background (replaces v4's purple). Approximate the gradient as a solid blend
   + soft shadow, like `header()`.
2. **`UIStyle.moment_card(kind)`** → StyleBoxFlat for the overlay card (radius 13, the MOMENT bg above,
   1px `BORDER` @ low alpha, soft black shadow). `kind ∈ {moment, boost, drs}`.
3. **`UIStyle.banner(kind)`** → the overlay top banner (radius 9): moment=`GOLD_WARN`, boost=`GREEN_DARK`,
   drs=`BLUE`. (Or just three `pill()`-style boxes if you'd rather not add a helper.)
4. **`UIStyle.team_row(accent)`** → the opponent-tinted bowler row (bg `Color(accent,0.12)`, border
   `Color(accent,0.5)`). *Optional* — can be done with `panel()` + per-instance border override.
5. **`UIStyle.ball_cell(kind)`** → the 6-ball over cells (5 fills listed above). Small helper; or build inline.
6. **`UIStyle.autosim_bar()`** → the dock's accent-tinted progress bar shell (bg/border from `COUNTRY_ACCENT`).
7. **`UIStyle.boost_button()`** → the 60×60 round green BOOST control + GOLD count badge (custom; needs a
   dedicated style since `corner_btn()` is square/26px).

## Open questions (confirm before/after first build)
- **Controls bar:** the original request lists Back · Step · Play/Pause · Speed · BOOST, but locked **v4**
  collapses these into the single auto-sim bar + round BOOST. I built to v4. If you want the discrete
  Back/Step buttons back, say so and I'll respec the dock.
- **Opponent colour:** opponent is drawn in the AUS amber accent for contrast. If two same-country teams
  meet, I'll fall back the opponent to a neutral (`WHITE_MID` border). OK?
- **Player names/numbers** in the render (Kgosi, Naidoo, Pretorius, Du Plessis, Mkhize, Botha, Swart) are
  **placeholders** — confirm the real squad / opponent (Dusty Plains = the season-hub fixture 1) or I'll keep them generic.
