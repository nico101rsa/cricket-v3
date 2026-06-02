extends GutTest

const ClassifierLabel = preload("res://scripts/domain/classifier_label.gd")

func test_enum_has_four_labels():
	assert_eq(ClassifierLabel.Kind.BATTER,       0)
	assert_eq(ClassifierLabel.Kind.WK_BATTER,    1)
	assert_eq(ClassifierLabel.Kind.BOWLER,       2)
	assert_eq(ClassifierLabel.Kind.ALL_ROUNDER,  3)

func test_display_name_uses_caps_spec_strings():
	assert_eq(ClassifierLabel.display_name(ClassifierLabel.Kind.BATTER),      "BATTER")
	assert_eq(ClassifierLabel.display_name(ClassifierLabel.Kind.WK_BATTER),   "WICKET-KEEPER BATTER")
	assert_eq(ClassifierLabel.display_name(ClassifierLabel.Kind.BOWLER),      "BOWLER")
	assert_eq(ClassifierLabel.display_name(ClassifierLabel.Kind.ALL_ROUNDER), "ALL-ROUNDER")
