class_name Palette
extends RefCounted

# Single source of truth for colour (DESIGN_HANDOFF §8 + §16.3). Pure constants
# + two display helpers; no scene/logic dependency. Every screen reads from here
# so the look is consistent and changing a hex changes it everywhere.

# --- core surfaces ---
const BG := Color("1a1a22")            # app background (dark slate)
const SURFACE := Color("2a2a35")       # raised panel bg (reads as a card over BG)
const BORDER := Color("3d3d4a")        # panel border / divider
const WHITE := Color("f2f2f5")
const WHITE_DIM := Color("9a9aa6")     # secondary label text

# --- accents ---
const GOLD := Color("ffd166")          # primary "wow" / Tons / player highlight
const WARN := Color("f5a623")
const DANGER := Color("ef6c6c")        # loss / opponent
const BLUE := Color("4a90e2")
const GREEN := Color("2ecc71")         # positive action

# --- country accent (ADR 0001) ---
const SA := Color("1f7a4d")
const AUS := Color("e3a008")

# --- joker rarity (matches the existing scene constants) ---
const COMMON := Color("e8e8e8")
const RARE := Color("4f8cff")
const LEGENDARY := Color("ffc23c")

# --- §16.3 portrait skill-tier background ---
const SKILL_4 := Color("f5cb50")       # elite gold
const SKILL_3 := Color("4a90e2")       # default sky blue
const SKILL_2 := Color("9aa0a6")       # silver
const SKILL_1 := Color("3a3a44")       # rookie charcoal

# --- §16.3 Form glow (portrait frame colour) ---
const FORM_HOT := GOLD
const FORM_STEADY := GREEN
const FORM_TIRED := Color("b8860b")
const FORM_COLD := Color("808080")

# Skill tier background from a team/player star rating.
static func skill_bg(stars: float) -> Color:
	if stars >= 3.5: return SKILL_4
	if stars >= 2.5: return SKILL_3
	if stars >= 1.5: return SKILL_2
	return SKILL_1

# Form glow colour from the SeasonView.form int (display-only banding).
static func form_glow(form: int) -> Color:
	if form >= 2: return FORM_HOT
	if form == 1: return FORM_STEADY
	if form == 0: return FORM_TIRED
	return FORM_COLD
