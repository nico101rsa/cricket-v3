class_name Fonts
extends RefCounted

# Barlow Semi Condensed — the app-wide typeface (design's v3.3, weight map in
# docs/design-inbox/in-match-v4.md §Fonts). Scenes set font SIZE per-label; this
# is the one place that owns the FACE + WEIGHT. The project default font (set in
# project.godot → gui/theme/custom_font) is the Regular face, so every screen is
# Barlow by default; call Fonts.weigh(label, weight) where the design wants bold.
#
# "spec weight" = the CSS weight design wrote (900/800/700/600/body). It maps to a
# toned-down Barlow face (e.g. /900 → ExtraBold, not Black) per design's table.

const DIR := "res://assets/fonts/"

# Design spec weights (the numbers in the design docs), NOT the Barlow file weight.
const W_HEADLINE := 900   # result headline      → ExtraBold
const W_BOLD := 800       # scores/names/figures → Bold
const W_LABEL := 700      # panel labels         → SemiBold
const W_MEDIUM := 600     # "vs", secondary meta → Medium
const W_BODY := 400       # commentary/narration → Regular

const _FILES := {
	W_HEADLINE: "BarlowSemiCondensed-ExtraBold.ttf",
	W_BOLD: "BarlowSemiCondensed-Bold.ttf",
	W_LABEL: "BarlowSemiCondensed-SemiBold.ttf",
	W_MEDIUM: "BarlowSemiCondensed-Medium.ttf",
	W_BODY: "BarlowSemiCondensed-Regular.ttf",
}

static var _faces := {}        # spec weight -> FontFile
static var _tabular := {}      # spec weight -> FontVariation (tnum on)
static var _italic: FontFile = null

# The Barlow face for a design spec weight. tabular=true wraps it in a FontVariation
# with lining tabular figures (tnum) — use it on numbers so scores don't jiggle.
static func weight(spec_weight: int, tabular: bool = false) -> Font:
	var base := _face(spec_weight)
	if not tabular:
		return base
	if not _tabular.has(spec_weight):
		var fv := FontVariation.new()
		fv.base_font = base
		fv.opentype_features = {
			tag("tnum"): 1,  # tabular figures
			tag("lnum"): 1,  # lining figures
		}
		_tabular[spec_weight] = fv
	return _tabular[spec_weight]

static func italic() -> FontFile:
	if _italic == null:
		_italic = load(DIR + "BarlowSemiCondensed-Italic.ttf")
	return _italic

# Apply a weight to a control as a theme font override (the per-label seam scenes
# use alongside add_theme_font_size_override). For RichTextLabel pass slot "normal_font".
static func weigh(ctrl: Control, spec_weight: int, tabular: bool = false, slot: String = "font") -> void:
	ctrl.add_theme_font_override(slot, weight(spec_weight, tabular))

# OpenType feature tag int (e.g. "tnum"). name_to_tag is non-static — go via the
# primary TextServer interface.
static func tag(feature: String) -> int:
	return TextServerManager.get_primary_interface().name_to_tag(feature)

static func _face(spec_weight: int) -> FontFile:
	if not _faces.has(spec_weight):
		_faces[spec_weight] = load(DIR + _FILES[spec_weight])
	return _faces[spec_weight]
