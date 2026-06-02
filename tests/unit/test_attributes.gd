extends GutTest

const Attributes = preload("res://scripts/data/attributes.gd")

func test_defaults_are_five_each():
	var a := Attributes.new()
	assert_eq(a.power, 5)
	assert_eq(a.composure, 5)
	assert_eq(a.attack, 5)
	assert_eq(a.control, 5)

func test_sum_returns_total_of_four():
	var a := Attributes.new()
	a.power = 7; a.composure = 6; a.attack = 4; a.control = 3
	assert_eq(a.sum(), 20)

func test_is_valid_creation_distribution_for_balanced_default():
	var a := Attributes.new()
	assert_true(a.is_valid_creation_distribution(), "default 5/5/5/5 sums to 20, all in [1,8]")

func test_is_valid_creation_distribution_rejects_wrong_total():
	var a := Attributes.new()
	a.power = 8; a.composure = 8; a.attack = 8; a.control = 8  # sum = 32
	assert_false(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_zero():
	var a := Attributes.new()
	a.power = 0; a.composure = 6; a.attack = 6; a.control = 8  # sum = 20 but power is below min
	assert_false(a.is_valid_creation_distribution())

func test_is_valid_creation_distribution_rejects_over_cap():
	var a := Attributes.new()
	a.power = 9; a.composure = 5; a.attack = 3; a.control = 3  # sum = 20 but power is above max
	assert_false(a.is_valid_creation_distribution())

func test_duplicate_returns_independent_copy():
	var a := Attributes.new()
	a.power = 7
	var b := a.duplicate_typed()
	b.power = 1
	assert_eq(a.power, 7, "original unchanged")
	assert_eq(b.power, 1, "copy mutated independently")
