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

func test_is_valid_creation_distribution_for_balanced_default():
	var a := Attributes.new()
	assert_true(a.is_valid_creation_distribution(), "default 31.25x4 sums to 125, all in [5,50]")

func test_is_valid_creation_distribution_rejects_wrong_total():
	var a := Attributes.new()
	a.power = 50.0; a.composure = 50.0; a.attack = 50.0; a.control = 50.0  # sum = 200
	assert_false(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_below_min():
	var a := Attributes.new()
	a.power = 0.0; a.composure = 37.5; a.attack = 37.5; a.control = 50.0  # sum = 125 but power below min
	assert_false(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_over_cap():
	var a := Attributes.new()
	a.power = 56.25; a.composure = 31.25; a.attack = 18.75; a.control = 18.75  # sum = 125 but power above cap
	assert_false(a.is_valid_creation_distribution())

func test_duplicate_returns_independent_copy():
	var a := Attributes.new()
	a.power = 43.75
	var b := a.duplicate_typed()
	b.power = 6.25
	assert_eq(a.power, 43.75, "original unchanged")
	assert_eq(b.power, 6.25, "copy mutated independently")
