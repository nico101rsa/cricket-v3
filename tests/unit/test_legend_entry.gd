extends GutTest

const LegendEntry = preload("res://scripts/data/legend_entry.gd")
const Player = preload("res://scripts/data/player.gd")
const Attributes = preload("res://scripts/data/attributes.gd")
const ClassifierLabel = preload("res://scripts/domain/classifier_label.gd")

func _player(spw, sco, sat, sct, fpw, fco, fat, fct) -> Player:
	var p := Player.new()
	var s := Attributes.new()
	s.power = spw; s.composure = sco; s.attack = sat; s.control = sct
	var f := Attributes.new()
	f.power = fpw; f.composure = fco; f.attack = fat; f.control = fct
	p.starting_attributes = s
	p.attributes = f
	return p

func test_start_role_reads_starting_attributes():
	var e := LegendEntry.new()
	e.player = _player(50.0, 50.0, 12.5, 12.5, 50.0, 50.0, 12.5, 12.5)  # batter-shaped start
	assert_eq(e.start_role(), ClassifierLabel.Kind.BATTER)

func test_end_role_reads_final_attributes_and_can_differ():
	var e := LegendEntry.new()
	e.player = _player(50.0, 50.0, 12.5, 12.5, 12.5, 12.5, 50.0, 50.0)  # batter start, bowler-drifted end
	assert_eq(e.start_role(), ClassifierLabel.Kind.BATTER)
	assert_eq(e.end_role(), ClassifierLabel.Kind.BOWLER)

func test_new_stub_fields_default_to_zero_and_gold():
	var e := LegendEntry.new()
	assert_eq(e.levels_won, 0)
	assert_eq(e.retired_season, 0)
	assert_true(e.immortalised)
