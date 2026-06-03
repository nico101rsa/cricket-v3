extends GutTest

const Classifier = preload("res://scripts/domain/classifier.gd")
const ClassifierLabel = preload("res://scripts/domain/classifier_label.gd")
const Attributes = preload("res://scripts/data/attributes.gd")

func _attrs(p: int, comp: int, att: int, ctrl: int) -> Attributes:
	var a := Attributes.new()
	a.power = p; a.composure = comp; a.attack = att; a.control = ctrl
	return a

# --- All-rounder default ---

func test_balanced_default_is_all_rounder():
	var label := Classifier.classify(_attrs(5, 5, 5, 5))
	assert_eq(label, ClassifierLabel.Kind.ALL_ROUNDER)

# --- Batter ---

func test_pure_batter_pattern():
	# Power=8, Composure=8, Attack=2, Control=2 — Composure - Power = 0 (< 2), so Batter not WK
	var label := Classifier.classify(_attrs(8, 8, 2, 2))
	assert_eq(label, ClassifierLabel.Kind.BATTER)

func test_minimal_batter_pattern_at_thresholds():
	# Power=6, Composure=6, Attack=4, Control=4 — Composure - Power = 0 (< 2), Batter
	var label := Classifier.classify(_attrs(6, 6, 4, 4))
	assert_eq(label, ClassifierLabel.Kind.BATTER)

# --- Wicket-keeper Batter (a Batter pattern where Composure leads Power by ≥2) ---

func test_wk_batter_when_composure_leads_power_by_two():
	# Power=6, Composure=8, Attack=2, Control=4 — Comp-Pow = 2, all Batter conds met
	var label := Classifier.classify(_attrs(6, 8, 2, 4))
	assert_eq(label, ClassifierLabel.Kind.WK_BATTER)

func test_wk_batter_with_larger_composure_lead():
	var label := Classifier.classify(_attrs(6, 8, 3, 3))
	assert_eq(label, ClassifierLabel.Kind.WK_BATTER)

func test_not_wk_batter_when_composure_lead_is_only_one():
	# Power=7, Composure=8, Att=1, Ctrl=4 — Comp-Pow = 1 < 2, falls back to Batter
	var label := Classifier.classify(_attrs(7, 8, 1, 4))
	assert_eq(label, ClassifierLabel.Kind.BATTER)

# --- Bowler ---

func test_pure_bowler_pattern():
	# Power=2, Composure=2, Attack=8, Control=8
	var label := Classifier.classify(_attrs(2, 2, 8, 8))
	assert_eq(label, ClassifierLabel.Kind.BOWLER)

func test_minimal_bowler_pattern_at_thresholds():
	# Power=4, Composure=4, Attack=6, Control=6
	var label := Classifier.classify(_attrs(4, 4, 6, 6))
	assert_eq(label, ClassifierLabel.Kind.BOWLER)

# --- All-rounder fallthrough ---

func test_mixed_high_attack_with_high_composure_is_all_rounder():
	# Power=4, Composure=7, Attack=7, Control=2 — fails Batter (Power<6), fails Bowler (Compos>4)
	var label := Classifier.classify(_attrs(4, 7, 7, 2))
	assert_eq(label, ClassifierLabel.Kind.ALL_ROUNDER)

func test_one_dimension_short_of_batter_is_all_rounder():
	# Power=6, Composure=5, Attack=4, Control=5 — Composure<6
	var label := Classifier.classify(_attrs(6, 5, 4, 5))
	assert_eq(label, ClassifierLabel.Kind.ALL_ROUNDER)

# --- Determinism ---

func test_classifier_is_pure():
	var a := _attrs(6, 8, 2, 4)
	var l1 := Classifier.classify(a)
	var l2 := Classifier.classify(a)
	assert_eq(l1, l2)
	# And: mutating a after first call does not affect either label.
	a.power = 1
	assert_eq(l1, ClassifierLabel.Kind.WK_BATTER)
