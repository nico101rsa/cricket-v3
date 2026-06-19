# AMENDMENT → in-match v2 (deltas on top of merged v1 / PR #88)

> Review answered: `docs/design-inbox/in-match-REVIEW.md`. The v1 build is a faithful skeleton —
> these are **deltas**, not a re-spec. Apply on top of v1; everything not mentioned here is locked as built.
> Fresh reference attached: **`Key Moment Card - enriched reference.png`** (the enriched card on the same
> `40/2 · Powerplay Exit` fixture you built, + the 6-variant content matrix). No new Palette/UIStyle tokens
> are needed for any of this.

---

## 1 · Key Moment card — fill the body  ⟵ the #1 ask

The card currently renders **title + question + two bare buttons** floating mid-card with ~50% dead
vertical space. The v1 spec already describes the full card body in the Overlay System section, but it
landed as the minimum. **It was under-built, not mis-built** — pin it explicitly:

### Card body anatomy (top → bottom), inside `moment_card`, `14px` pad
The MomentCard is a VBox with **`alignment` distributing top vs bottom** (Godot: put the Scene row on
`size_flags_vertical = EXPAND`, everything else shrink). Result = ctx+actor pinned to the top, narr+choices
pinned to the bottom, the glyph eats the slack between them. **No dead gap.**

```
MomentCard (PanelContainer, expand, moment_card(:moment), radius 13, pad 14)
└─ VBox (separation 0; Scene child carries the expand)
   ├─ Ctx     Label   — 10px UPPER, +1.6 tracking, GOLD, centered
   │                    text = "{score} · {overs} overs left · {phase}"   e.g. "40/2 · 13 overs left · middle"
   ├─ Actor   PanelContainer (inner) — bg Color(0,0,0,0.45), radius 9, pad 10, HBox gap 12, margin-top 10
   │          ├─ Portrait 62×78, portrait_ring(Palette.skill_ring(stars))   ← SAME ring token as the batter chips, bigger size
   │          └─ VBox: Name 17/800 GOLD · Tag 10 WHITE_MID · Stats 9 UPPER WHITE_DIM
   │                   Stats = "{runs} ({balls}) · OVR {ovr}"   (batting)  /  "{figs} · OVR {ovr}"  (bowling)
   ├─ Scene   Label (EXPAND, centered) — emoji ~42px   ← the only expanding row; per-variant glyph
   ├─ Narr    Label — 13px italic, centered, WHITE_SOFT, BBCode [b]→GOLD; margin-bottom 12
   └─ Choices HBox separation 8 — two Choice buttons:
              VBox[ Verb 14/800 · Stake 9 WHITE_MID ]    ← Stake sublabel is the missing legibility piece
```

Deltas vs what's built:
- **ADD the Ctx line** (was absent).
- **ADD the Actor mini-card** — portrait + name + tag + stats. This is the single biggest gap.
- **ADD the Scene glyph** as the expand row (also fixes the dead space).
- **Narr**: keep it a sentence that *names both options in prose* (not a bare "How do you play the middle overs?").
- **Choices**: keep the verbs, **add the stake sublabel** under each. Accents unchanged: left `BLUE`, right `RED`.

### Actor binding
- **Batting moments** → actor = the **on-strike batter**. Tag = their job this ball.
- **Bowling moments** → actor = **your bowler**. Tag = their job this ball.
- Portrait ring = that player's `★` tier (reuse `Palette.skill_ring`). Stats line is real (runs/balls or figures + OVR).

### Variant content matrix (glyph · narration · two choices w/ stakes)
Bind by `keyMoment.type`. Verbs/stakes are the shipped copy — use verbatim.

**Batting (you're batting):**

| type | glyph | phase word | narration (`[b]`=gold) | left verb / stake | right verb / stake |
|---|---|---|---|---|---|
| Powerplay Exit (ov 7) | ⚡ | middle | Powerplay's done. **Anchor** and build a platform, or **hunt** and keep the rate climbing? | ← ANCHOR / Build a platform | HUNT → / Chase the rate |
| Wicket Crisis (1st middle wkt) | 🩸 | rebuild | Wicket down. **Rebuild** and protect the innings, or **counter-attack** and seize the momentum? | ← REBUILD / Protect wickets | COUNTER → / Seize momentum |
| Death Plan (ov 16) | 💀 | death | Death overs. **Twos & fours** for a reliable 50+, or **six-or-bust** and go boom-or-bust? | ← 2s & 4s / Reliable 50+ | BIG HITS → / Boom or bust |

**Bowling (you're defending):**

| type | glyph | phase word | narration | left verb / stake | right verb / stake |
|---|---|---|---|---|---|
| Powerplay Exit (ov 7) | 🎯 | field set | Powerplay over. **Attack** with slips and catchers, or **contain** and protect the boundary? | ← ATTACK / Slips in | CONTAIN → / Spread the field |
| New Batsman In | 🔥 | fresh batter | New man in. **Bounce** him and test the technique, or **york** him and go for the stumps? | ← BOUNCER / Test technique | YORKER → / Go for stumps |
| Death Defence (ov 16) | 💀 | death defence | Defending at the death. **Yorkers** for low risk, or **slower balls** to force the miscue? | ← YORKERS / Low risk | SLOWER → / Force the error |

**Boost & DRS overlays reuse this exact same card skeleton** (already built that way). So once the Key Moment
card carries actor + scene + narr + stakes, **Boost and DRS inherit it for free** — confirm they pick up the
same layout (Boost: actor = "YOUR CALL", green accents; DRS: actor = your dismissed batsman, accept=RED/review=BLUE).

---

## 2 · Bowler row — drop the fake figures, lead with econ  ✅ accept the sim constraint

Your sim is statistical and doesn't track opposition bowler wickets, so `1/24` was never real. **Don't invent it.**
Re-cut the row so every value is real:

- **REMOVE** the `wkts/runs (overs)` figure block on the right.
- **Right-side figure** = the real **economy**: `ECON` microlabel (8px UPPER `WHITE_DIM`) above the number,
  econ value 15px/800 `WHITE` tabular. This makes the bare "7.2" read as a labelled stat, not a mystery number.
- Stat line stays: `type · n★ · econ`. Drop the duplicate "econ" word from the stat line now that the
  figure is labelled (so it reads `spin · 4★` on the left, `ECON 7.2` on the right).
- Everything else (opponent-amber tint, name in `opp_accent`) unchanged.

This is exactly what the build already approximated — just formalising it so the row never implies tracked figures it doesn't have.

---

## 3 · Player names — keep as flavour, no visual signal  ✅

Names are flavour, numbers are real — **don't** style the scorecard to flag this. Visually distinguishing
"fake" names would break immersion and add noise for zero player benefit. Leave names as-is.
(Squad confirm is still open — use the season-hub fixture-1 squad when it lands; keep current placeholders until then.)

---

## 4 · Fonts — name the face + weights

Adopt **Barlow Semi Condensed** (Google Fonts, free) across the whole In-Match screen. It's tabular,
sporty, and ships the full weight range the spec leans on. Map the spec's weights:

| spec weight | Barlow SC weight | used for |
|---|---|---|
| /900 | 800 ExtraBold | result headline |
| /800 | 700 Bold | scores, names, figures, verbs, banners, micro-labels |
| /700 | 600 SemiBold | panel labels |
| /600 | 500 Medium | "vs", secondary meta |
| body | 400 Regular | commentary, narration (italic = Barlow SC Italic 400) |

All numerals stay tabular (`font_features` / lining). If you'd rather keep one face for numerals only,
Barlow Semi Condensed already has clean lining figures — no second face needed.

---

## Net token impact: **none.** Everything above reuses shipped tokens
(`moment_card`, `portrait_ring`, `skill_ring`, gold/blue/red/green choice accents, `panel`). The only
non-token change is loading the Barlow Semi Condensed font resource.

## Re-render targets after applying
`docs/mockups/latest/in-match.png` (auto-sim) is fine as-is — the deltas above are mostly the overlay states.
Please re-render **`...-keymoment.png`** (it's the one that changes most) and a Boost shot so we can confirm
the card body inheritance. Then we loop.
