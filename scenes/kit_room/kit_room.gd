extends Control

# The Kit Room — the live season's shop screen (spec 2026-07-02, Rung 2).
# In-house functional skin (DK2-7): clean, on-language (Palette/UIStyle/Fonts),
# hi-fi via the design track is a later rung. Three modes:
#   set_visit(play, visit)  — "starter" (3 free Commons) or "visit" (buy/sell/hold/train)
#   set_carryover(play)     — season end: elect the one joker that survives (DK2-6)
# The screen is dumb: every action routes through SeasonPlay.apply_shop_action, and
# all money maths lives in ShopResolver/Economy. No emoji (Barlow tofu).

signal done()
signal carryover_elected(id: String)

const VISIT_LABELS := {0: "SEASON START", 1: "AFTER MATCH 3", 2: "AFTER MATCH 5",
	3: "BEFORE THE SEMI-FINAL", 4: "BEFORE THE FINAL"}

var _play: SeasonPlay
var _visit: Dictionary = {}
var _mode: String = ""
var _col: VBoxContainer

func set_visit(play: SeasonPlay, visit: Dictionary) -> void:
	_play = play
	_visit = visit
	_mode = String(visit.get("kind", ""))
	_rebuild()

func set_carryover(play: SeasonPlay) -> void:
	_play = play
	_mode = "carryover"
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.free()   # immediate: _rebuild re-runs after in-visit actions same-frame
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	scroll.add_child(margin)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_col)
	_header()
	match _mode:
		"starter": _starter_body()
		"visit": _visit_body()
		"carryover": _carryover_body()

func _header() -> void:
	var label: String = "SEASON END — CARRY-OVER" if _mode == "carryover" \
		else String(VISIT_LABELS.get(int(_visit.get("visit", -1)), ""))
	var kicker := _lbl("KIT ROOM · %s" % label, 11, Palette.WHITE_DIM)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(kicker)
	var bal := _lbl("₸ %d" % _play.shop_balance(), 24, Palette.GOLD)
	bal.name = "Balance"
	bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.weigh(bal, Fonts.W_HEADLINE, true)
	_col.add_child(bal)

func _starter_body() -> void:
	_col.add_child(_lbl("Pick a free joker to start the season", 13, Palette.WHITE))
	var box := VBoxContainer.new()
	box.name = "StarterBox"
	box.add_theme_constant_override("separation", 10)
	_col.add_child(box)
	for id in (_visit["offer"] as Array):
		var jid: String = id
		var b := _row_btn("%s\nCOMMON · FREE\n%s" % [_jname(jid), JokerCatalog.describe(jid)])
		b.pressed.connect(func():
			if _play.apply_shop_action({"kind": "pick", "id": jid}):
				done.emit())
		box.add_child(b)
	var skip := _cta("SKIP  >", Palette.WHITE_DIM)
	skip.name = "ContinueBtn"
	skip.pressed.connect(func():
		_play.apply_shop_action({"kind": "skip"})
		done.emit())
	_col.add_child(skip)

func _visit_body() -> void:
	var offer: Dictionary = _visit["offer"]
	var paid_used: bool = _play.paid_action_used()
	# --- the shelf ---
	_col.add_child(_section("ON THE SHELF"))
	var i := 0
	for rarity in ["common", "rare", "legendary"]:
		var id: String = offer.get(rarity, "")
		if id == "":
			continue
		var jid := id
		var price: int = offer["prices"][jid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_l := _lbl("%s\n%s · ₸ %d\n%s" % [_jname(jid), rarity.to_upper(), price,
			JokerCatalog.describe(jid)], 13, Palette.WHITE)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var buy := _small_btn("BUY")
		buy.name = "BuyBtn%d" % i
		buy.disabled = paid_used or _play.shop_balance() < price \
			or jid in _play.shop_owned()
		buy.pressed.connect(func():
			if _play.apply_shop_action({"kind": "buy", "id": jid}):
				_rebuild())
		row.add_child(buy)
		var hold := _small_btn("HOLD")
		hold.pressed.connect(func():
			if _play.apply_shop_action({"kind": "hold", "id": jid}):
				_rebuild())
		row.add_child(hold)
		_col.add_child(row)
		i += 1
	if i == 0:
		_col.add_child(_lbl("Nothing on the shelf this visit.", 12, Palette.WHITE_DIM))
	# --- your bench ---
	if not _play.shop_owned().is_empty():
		_col.add_child(_section("YOUR JOKERS"))
		for oid_v in _play.shop_owned():
			var oid: String = oid_v
			var orow := HBoxContainer.new()
			orow.add_theme_constant_override("separation", 8)
			var ol := _lbl("%s\n%s" % [_jname(oid), JokerCatalog.describe(oid)], 13, Palette.WHITE)
			ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			orow.add_child(ol)
			var sell := _small_btn("SELL ₸%d" % _play.sell_refund_of(oid))
			sell.pressed.connect(func():
				if _play.apply_shop_action({"kind": "sell", "id": oid}):
					_rebuild())
			orow.add_child(sell)
			_col.add_child(orow)
	# --- training ---
	_col.add_child(_section("TRAINING (+1)"))
	for attr_v in ["power", "composure", "attack", "control"]:
		var attr: String = attr_v
		var cur: float = _play.train_value_of(attr)
		var cost: int = _play.train_cost_of(attr)
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 8)
		var tl := _lbl("%s  %d → %d" % [attr.to_upper(), int(cur), int(cur) + 1],
			13, Palette.WHITE)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trow.add_child(tl)
		var tb := _small_btn("TRAIN ₸%d" % cost)
		tb.disabled = paid_used or cur >= 60.0 or _play.shop_balance() < cost
		tb.pressed.connect(func():
			if _play.apply_shop_action({"kind": "train", "attr": attr}):
				_rebuild())
		trow.add_child(tb)
		_col.add_child(trow)
	var cta := _cta("CONTINUE  >", Palette.GOLD)
	cta.name = "ContinueBtn"
	cta.pressed.connect(func():
		_play.apply_shop_action({"kind": "skip"})
		done.emit())
	_col.add_child(cta)

func _carryover_body() -> void:
	_col.add_child(_lbl("Pick ONE joker to carry into next season", 13, Palette.WHITE))
	var box := VBoxContainer.new()
	box.name = "CarryBox"
	box.add_theme_constant_override("separation", 10)
	_col.add_child(box)
	for id_v in _play.shop_owned():
		var jid: String = id_v
		var b := _row_btn("%s\n%s" % [_jname(jid), JokerCatalog.describe(jid)])
		b.pressed.connect(func(): carryover_elected.emit(jid))
		box.add_child(b)
	var none := _cta("CARRY NOTHING  >", Palette.WHITE_DIM)
	none.name = "ContinueBtn"
	none.pressed.connect(func(): carryover_elected.emit(""))
	_col.add_child(none)

# --- helpers ---

func _jname(id: String) -> String:
	for g in JokerCatalog.implemented_groups():
		if g["id"] == id:
			return g["jname"]
	return id

func _lbl(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	Fonts.weigh(l, Fonts.W_BOLD)
	return l

func _section(txt: String) -> Label:
	var l := _lbl(txt, 11, Palette.WHITE_DIM)
	Fonts.weigh(l, Fonts.W_LABEL)
	return l

func _row_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_stylebox_override("normal", UIStyle.panel())
	b.add_theme_color_override("font_color", Palette.WHITE)
	Fonts.weigh(b, Fonts.W_BOLD)
	return b

func _small_btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_stylebox_override("normal", UIStyle.panel())
	b.add_theme_color_override("font_color", Palette.GOLD)
	b.add_theme_font_size_override("font_size", 11)
	Fonts.weigh(b, Fonts.W_BOLD)
	return b

func _cta(txt: String, col: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_stylebox_override("normal", UIStyle.cta(col))
	b.add_theme_color_override("font_color", Palette.BG)
	b.add_theme_font_size_override("font_size", 15)
	Fonts.weigh(b, Fonts.W_BOLD)
	return b
