extends GutTest

const Attributes = preload("res://scripts/data/attributes.gd")

func test_defaults_are_balanced_card():
	var a := Attributes.new()
	assert_eq(a.power, 31.25)
	assert_eq(a.composure, 31.25)
	assert_eq(a.attack, 31.25)
	assert_eq(a.control, 31.25)

func test_sum_returns_total_of_four():
	var a := Attributes.new()
	a.power = 43.75; a.composure = 37.5; a.attack = 25.0; a.control = 18.75
	assert_eq(a.sum(), 125.0)

func test_is_valid_creation_distribution_for_fresh_default():
	# World-scale v2: a fresh hero is 11/11/11/11 (sum 44, all in [3, 25]).
	var a := Attributes.new()
	a.power = 11.0; a.composure = 11.0; a.attack = 11.0; a.control = 11.0
	assert_true(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_wrong_total():
	var a := Attributes.new()
	a.power = 25.0; a.composure = 25.0; a.attack = 25.0; a.control = 25.0  # sum = 100, not 44
	assert_false(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_below_min():
	var a := Attributes.new()
	a.power = 1.0; a.composure = 14.0; a.attack = 14.0; a.control = 15.0  # sum 44 but power below min 3
	assert_false(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_over_cap():
	var a := Attributes.new()
	a.power = 30.0; a.composure = 5.0; a.attack = 5.0; a.control = 4.0  # sum 44 but power above cap 25
	assert_false(a.is_valid_creation_distribution())

func test_duplicate_returns_independent_copy():
	var a := Attributes.new()
	a.power = 43.75
	var b := a.duplicate_typed()
	b.power = 6.25
	assert_eq(a.power, 43.75, "original unchanged")
	assert_eq(b.power, 6.25, "copy mutated independently")
