extends Control

# Real Hall of Fame. Replaces the Phase-7 stub. See HoF build spec §3.
# Skeleton-styled (Theme 6 polishes visuals). The one live element is the
# career-arc beat (startRole -> endRole), derived from each Legend's snapshot.

signal begin_new_player()

const BADGE_GOLD := Color("d4af37")

@onready var _count: Label = $Layout/Header/Count
@onready var _hero: VBoxContainer = $Layout/Hero
@onready var _hero_portrait: TextureRect = $Layout/Hero/HeroPortrait
@onready var _hero_badge: Label = $Layout/Hero/Badge
@onready var _hero_name: Label = $Layout/Hero/HeroName
@onready var _hero_meta: Label = $Layout/Hero/Meta
@onready var _hero_arc: Label = $Layout/Hero/Arc
@onready var _hero_strip: Label = $Layout/Hero/Strip
@onready var _earlier_header: Label = $Layout/EarlierHeader
@onready var _earlier_list: VBoxContainer = $Layout/EarlierScroll/EarlierList
@onready var _new_player_btn: Button = $Layout/NewPlayerBtn

func _ready() -> void:
	_new_player_btn.pressed.connect(func(): begin_new_player.emit())
	_hero_badge.add_theme_color_override("font_color", BADGE_GOLD)
	render_archive(SaveManager.load_legends())

# Pure render from an archive -- injectable for tests. The archive is stored
# oldest-first (SaveManager appends), so the hero is the last entry and the
# earlier list walks backwards from the second-to-last down to index 0.
func render_archive(arc: LegendsArchive) -> void:
	_count.text = "%d Legends" % arc.entries.size()
	# remove_child detaches synchronously so a re-render's get_child_count() is
	# correct immediately; queue_free() alone is deferred and would leave stale
	# rows (e.g. from the _ready() render) counted within the same frame.
	for c in _earlier_list.get_children():
		_earlier_list.remove_child(c)
		c.queue_free()

	if arc.entries.is_empty():
		_hero.visible = false
		_earlier_header.visible = false
		return

	_hero.visible = true
	_render_hero(arc.entries.back())

	var earlier_count := arc.entries.size() - 1
	_earlier_header.visible = earlier_count > 0
	for i in range(arc.entries.size() - 2, -1, -1):
		_earlier_list.add_child(_make_row(arc.entries[i]))

func _render_hero(e: LegendEntry) -> void:
	_hero_portrait.texture = PortraitLibrary.texture_for(e.player.appearance, e.player.form_points)
	_hero_badge.text = _badge_text(e)
	_hero_name.text = e.player.name.display_caps()
	_hero_meta.text = "%s played · %s won" % [_plural(e.seasons_played, "Season"), _plural(e.levels_won, "Level")]
	_hero_arc.text = "%s   →   %s" % [_role(e.start_role()), _role(e.end_role())]
	_hero_strip.text = "%s · %s won · ₸%d" % [_plural(e.seasons_played, "Season"), _plural(e.levels_won, "Level"), e.player.tons_balance]

# "1 Season" / "2 Seasons" — only the count of 1 takes the singular noun.
func _plural(n: int, noun: String) -> String:
	return "%d %s" % [n, noun if n == 1 else noun + "s"]

func _badge_text(e: LegendEntry) -> String:
	# Drop the "· S{n}" suffix while there is no Season system to make it meaningful.
	if e.retired_season > 0:
		return "★ Immortalised · S%d" % e.retired_season
	return "★ Immortalised"

func _role(kind: int) -> String:
	return ClassifierLabel.display_name(kind)

func _make_row(e: LegendEntry) -> Control:
	# Portrait swatch on the left, a stacked text block on the right (name over a
	# compact arc + headline stat). The text block fills the remaining width and
	# wraps rather than running off the edge — long roles ("WICKET-KEEPER BATTER")
	# would otherwise overflow the column and clip on the right.
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.add_theme_constant_override("separation", 12)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(40, 40)
	swatch.color = AppearancePicker.placeholder_tint(e.player.appearance)
	row.add_child(swatch)

	var text_block := VBoxContainer.new()
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # take the width left of the swatch
	var name_label := Label.new()
	name_label.text = e.player.name.display_caps()
	text_block.add_child(name_label)
	var detail := Label.new()
	detail.text = "%s → %s · %s" % [
		_role(e.start_role()), _role(e.end_role()), _plural(e.seasons_played, "Season")]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD  # wrap within the column, never clip
	text_block.add_child(detail)
	row.add_child(text_block)
	return row
