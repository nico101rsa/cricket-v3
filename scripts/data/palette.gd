class_name Palette
extends RefCounted

# Single source of truth for colour — the design "tokens" (Season Hub hi-fi v2 spec,
# docs/superpowers/specs/2026-06-18-season-hub-hifi-v2-spec.md). Pure constants +
# helpers; no scene/logic dependency. Country reskin = override ONLY the four
# country_* tokens via country_set() — nothing else moves.

# --- core surfaces (white-alpha over BG, per spec) ---
const BG := Color("0f0f14")
const SURFACE := Color(1, 1, 1, 0.04)
const SURFACE_2 := Color(1, 1, 1, 0.07)
const SURFACE_3 := Color(1, 1, 1, 0.10)
const BORDER := Color(1, 1, 1, 0.08)
const BORDER_STRONG := Color(1, 1, 1, 0.15)

# --- text ---
const WHITE := Color(1, 1, 1, 0.92)
const WHITE_SOFT := Color(1, 1, 1, 0.85)
const WHITE_MID := Color(1, 1, 1, 0.65)
const WHITE_DIM := Color(1, 1, 1, 0.45)

# --- accents ---
const GOLD := Color("ffd166")          # primary "wow" / Tons / OVR
const GOLD_WARN := Color("f5a623")     # CTA / stage gradient start
const GOLD_DEEP := Color("c9912b")
const GREEN := Color("2ecc71")
const GREEN_DARK := Color("16a34a")    # won fixtures
const RED := Color("c41e3a")
const RED_DARK := Color("8b0000")      # lost fixtures
const BLUE := Color("4a90e2")          # ★3 skill ring / rare joker

# --- in-match overlay cards (dramatic green-black, replaces v4's purple) ---
const MOMENT_1 := Color("16271d")        # key-moment / DRS card top
const MOMENT_2 := Color("0a130e")        # key-moment / DRS card bottom
const MOMENT_BOOST_1 := Color("123524")  # manager-boost card top
const MOMENT_BOOST_2 := Color("08160f")  # manager-boost card bottom

# --- joker rarity ---
const COMMON := Color("e8e8e8")
const RARE := Color("4f8cff")
const LEGENDARY := Color("ffc23c")

# --- §16.3 / spec skill-tier RING colour (portrait art fills the frame; tier = ring) ---
const SKILL_4 := GOLD                  # elite 4★
const SKILL_3 := BLUE                  # default 3★
const SKILL_2 := Color("79828d")       # 2★ silver
const SKILL_1 := Color("3a3d46")       # 1★ charcoal / ½★

# --- Form glow (form chip + portrait at small sizes) ---
const FORM_HOT := GOLD
const FORM_STEADY := GREEN
const FORM_TIRED := GOLD_WARN
const FORM_COLD := Color("808080")

# --- country tokens (SA default; AUS = the reskin) ---
const COUNTRY_1_SA := Color("007749")
const COUNTRY_2_SA := Color("003e26")
const COUNTRY_GLOW_SA := Color(0.0, 0.467, 0.286, 0.45)
const COUNTRY_ACCENT_SA := Color("FFB81C")

const COUNTRY_1_AUS := Color("d97706")
const COUNTRY_2_AUS := Color("7c3f00")
const COUNTRY_GLOW_AUS := Color(0.851, 0.467, 0.024, 0.45)
const COUNTRY_ACCENT_AUS := Color("ffd166")

# The four country_* tokens for a Country.Code (0 = SA, else AUS). Swapping these
# four recolours the header gradient + glow + the accent (current fixture / match
# label / affinity bar). Returns {grad1, grad2, glow, accent}.
static func country_set(code: int) -> Dictionary:
	if code == Country.Code.AUS:
		return {"grad1": COUNTRY_1_AUS, "grad2": COUNTRY_2_AUS,
			"glow": COUNTRY_GLOW_AUS, "accent": COUNTRY_ACCENT_AUS}
	return {"grad1": COUNTRY_1_SA, "grad2": COUNTRY_2_SA,
		"glow": COUNTRY_GLOW_SA, "accent": COUNTRY_ACCENT_SA}

# Skill-tier RING colour from a star rating (½★ reads as the 1★ charcoal tier).
static func skill_ring(stars: float) -> Color:
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
