extends GutTest

const Appearance = preload("res://scripts/domain/appearance.gd")

func test_four_buckets_in_canonical_tone_order():
	assert_eq(Appearance.Bucket.WHITE,  0)
	assert_eq(Appearance.Bucket.MIXED,  1)
	assert_eq(Appearance.Bucket.INDIAN, 2)
	assert_eq(Appearance.Bucket.BLACK,  3)

func test_to_key_returns_canonical_string():
	assert_eq(Appearance.to_key(Appearance.Bucket.WHITE),  "white")
	assert_eq(Appearance.to_key(Appearance.Bucket.MIXED),  "mixed")
	assert_eq(Appearance.to_key(Appearance.Bucket.INDIAN), "indian")
	assert_eq(Appearance.to_key(Appearance.Bucket.BLACK),  "black")

func test_all_buckets_returns_ordered_list():
	var all := Appearance.all()
	assert_eq(all.size(), 4)
	assert_eq(all[0], Appearance.Bucket.WHITE)
	assert_eq(all[3], Appearance.Bucket.BLACK)
