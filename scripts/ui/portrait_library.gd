class_name PortraitLibrary
extends RefCounted

# (appearance bucket, raw form int) -> portrait texture (spec DP5).
# Portraits carry NO data -- flavour only. Unknown inputs clamp to white/steady.
# Lazy load() + cache: 16 small PNGs, loaded at most once each.

static var _cache: Dictionary = {}

static func path(bucket: int, band: int) -> String:
	var b_key := Appearance.to_key(bucket)
	if b_key.is_empty():
		b_key = "white"
	var f_key := FormBand.key(band) if band >= FormBand.Band.COLD and band <= FormBand.Band.HOT else "steady"
	return "res://assets/portraits/%s-%s.png" % [b_key, f_key]

static func texture_for(bucket: int, form: int) -> Texture2D:
	var p := path(bucket, FormBand.of(form))
	if not _cache.has(p):
		_cache[p] = load(p)
	return _cache[p]
