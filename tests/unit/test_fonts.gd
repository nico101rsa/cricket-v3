extends GutTest

# Barlow Semi Condensed font slice. Locks the design weight map (in-match-v4.md §Fonts)
# and the project-wide wiring: spec weight (CSS 900/800/700/600/body) → the right
# Barlow SC face, tabular numerals on demand, and the project default font set.

func test_each_spec_weight_loads_a_font():
	for w in [Fonts.W_HEADLINE, Fonts.W_BOLD, Fonts.W_LABEL, Fonts.W_MEDIUM, Fonts.W_BODY]:
		var f := Fonts.weight(w)
		assert_not_null(f, "spec weight %d resolves to a font" % w)
		assert_true(f is Font, "spec weight %d is a Font" % w)

func test_weight_map_picks_the_designed_faces():
	# in-match-v4.md: /900→ExtraBold, /800→Bold, /700→SemiBold, /600→Medium, body→Regular.
	assert_string_contains(_path(Fonts.weight(Fonts.W_HEADLINE)), "ExtraBold")
	assert_string_contains(_path(Fonts.weight(Fonts.W_BOLD)), "Bold")
	assert_string_contains(_path(Fonts.weight(Fonts.W_LABEL)), "SemiBold")
	assert_string_contains(_path(Fonts.weight(Fonts.W_MEDIUM)), "Medium")
	assert_string_contains(_path(Fonts.weight(Fonts.W_BODY)), "Regular")

func test_distinct_weights_are_distinct_faces():
	var paths := {}
	for w in [Fonts.W_HEADLINE, Fonts.W_BOLD, Fonts.W_LABEL, Fonts.W_MEDIUM, Fonts.W_BODY]:
		paths[_path(Fonts.weight(w))] = true
	assert_eq(paths.size(), 5, "five spec weights map to five different Barlow faces")

func test_tabular_returns_a_variation_with_tnum():
	var f := Fonts.weight(Fonts.W_BOLD, true)
	assert_true(f is FontVariation, "tabular request returns a FontVariation")
	var fv := f as FontVariation
	var tag := Fonts.tag("tnum")
	assert_true(fv.opentype_features.has(tag), "tabular variation enables the tnum feature")
	assert_eq(int(fv.opentype_features[tag]), 1, "tnum is on")

func test_tabular_variation_wraps_the_same_weight():
	var fv := Fonts.weight(Fonts.W_BOLD, true) as FontVariation
	assert_string_contains(_path(fv.base_font), "Bold")

func test_italic_loads():
	assert_string_contains(_path(Fonts.italic()), "Italic")

func test_weigh_applies_a_font_override_to_a_control():
	var l := Label.new()
	Fonts.weigh(l, Fonts.W_HEADLINE)
	assert_true(l.has_theme_font_override("font"), "weigh() sets the font override")
	assert_string_contains(_path(l.get_theme_font("font")), "ExtraBold")
	l.free()

func test_project_default_font_is_barlow():
	# The single project-wide wiring line: every screen inherits Barlow by default.
	var path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	assert_string_contains(path, "BarlowSemiCondensed", "project default font is Barlow SC")
	var res := load(path)
	assert_not_null(res, "the project default font resource loads")
	assert_true(res is Font, "the project default font is a Font")

func _path(f: Font) -> String:
	if f is FontVariation:
		return (f as FontVariation).base_font.resource_path
	return f.resource_path
