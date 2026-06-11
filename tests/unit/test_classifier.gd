extends GutTest

const Classifier = preload("res://scripts/domain/classifier.gd")
const ClassifierLabel = preload("res://scripts/domain/classifier_label.gd")
const Attributes = preload("res://scripts/data/attributes.gd")

func _attrs(p: float, comp: float, att: float, ctrl: float) -> Attributes:
	var a := Attributes.new()
	a.power = p; a.composure = comp; a.attack = att; a.control = ctrl
	return a

# --- All-rounder default ---

func test_balanced_default_is_all_rounder():
	var label := Classifier.classify(_attrs(31.25, 31.25, 31.25, 31.25))
	assert_eq(label, ClassifierLabel.Kind.ALL_ROUNDER)

# --- Batter ---

func test_pure_batter_pattern():
	# Power=50, Composure=50, Attack=12.5, Control=12.5 — Composure - Power = 0 (< 12.5), so Batter not WK
	var label := Classifier.classify(_attrs(50, 50, 12.5, 12.5))
	assert_eq(label, ClassifierLabel.Kind.BATTER)

func test_minimal_batter_pattern_at_thresholds():
	# Power=37.5, Composure=37.5, Attack=25, Control=25 — Composure - Power = 0 (< 12.5), Batter
	var label := Classifier.classify(_attrs(37.5, 37.5, 25, 25))
	assert_eq(label, ClassifierLabel.Kind.BATTER)

# --- Wicket-keeper Batter (a Batter pattern where Composure leads Power by ≥ WK_GAP) ---

func test_wk_batter_when_composure_leads_power_by_gap():
	# Power=37.5, Composure=50, Attack=12.5, Control=25 — Comp-Pow = 12.5, all Batter conds met
	var label := Classifier.classify(_attrs(37.5, 50, 12.5, 25))
	assert_eq(label, ClassifierLabel.Kind.WK_BATTER)

func test_wk_batter_with_larger_composure_lead():
	var label := Classifier.classify(_attrs(37.5, 50, 18.75, 18.75))
	assert_eq(label, ClassifierLabel.Kind.WK_BATTER)

func test_not_wk_batter_when_composure_lead_is_under_gap():
	# Power=43.75, Composure=50, Att=6.25, Ctrl=25 — Comp-Pow = 6.25 < 12.5, falls back to Batter
	var label := Classifier.classify(_attrs(43.75, 50, 6.25, 25))
	assert_eq(label, ClassifierLabel.Kind.BATTER)

# --- Bowler ---

func test_pure_bowler_pattern():
	# Power=12.5, Composure=12.5, Attack=50, Control=50
	var label := Classifier.classify(_attrs(12.5, 12.5, 50, 50))
	assert_eq(label, ClassifierLabel.Kind.BOWLER)

func test_minimal_bowler_pattern_at_thresholds():
	# Power=25, Composure=25, Attack=37.5, Control=37.5
	var label := Classifier.classify(_attrs(25, 25, 37.5, 37.5))
	assert_eq(label, ClassifierLabel.Kind.BOWLER)

# --- All-rounder fallthrough ---

func test_mixed_high_attack_with_high_composure_is_all_rounder():
	# Power=25, Composure=43.75, Attack=43.75, Control=12.5 — fails Batter (Power<37.5), fails Bowler (Compos>25)
	var label := Classifier.classify(_attrs(25, 43.75, 43.75, 12.5))
	assert_eq(label, ClassifierLabel.Kind.ALL_ROUNDER)

func test_one_dimension_short_of_batter_is_all_rounder():
	# Power=37.5, Composure=31.25, Attack=25, Control=31.25 — Composure<37.5
	var label := Classifier.classify(_attrs(37.5, 31.25, 25, 31.25))
	assert_eq(label, ClassifierLabel.Kind.ALL_ROUNDER)

# --- Determinism ---

func test_classifier_is_pure():
	var a := _attrs(37.5, 50, 12.5, 25)
	var l1 := Classifier.classify(a)
	var l2 := Classifier.classify(a)
	assert_eq(l1, l2)
	# And: mutating a after first call does not affect either label.
	a.power = 6.25
	assert_eq(l1, ClassifierLabel.Kind.WK_BATTER)
