extends GutTest

func test_defaults() -> void:
	var p := DRSPolicy.new()
	assert_eq(p.base_reviews, 2)  # T20 rule: 2 unsuccessful reviews per innings
	assert_almost_eq(p.base_p, 0.4, 0.0001)
