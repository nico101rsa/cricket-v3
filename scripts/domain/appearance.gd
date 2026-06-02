class_name Appearance
extends RefCounted

# UI position 1..4 → lightest..darkest skin tone. See spec §3.3.
# Internal keys are stable string identifiers; UI shows only portraits, never these strings.
enum Bucket { WHITE = 0, MIXED = 1, INDIAN = 2, BLACK = 3 }

static func to_key(b: int) -> String:
	match b:
		Bucket.WHITE:  return "white"
		Bucket.MIXED:  return "mixed"
		Bucket.INDIAN: return "indian"
		Bucket.BLACK:  return "black"
		_: return ""

static func all() -> Array[int]:
	return [Bucket.WHITE, Bucket.MIXED, Bucket.INDIAN, Bucket.BLACK]
