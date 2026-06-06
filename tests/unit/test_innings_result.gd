extends GutTest

func test_holds_fields() -> void:
	var batters := [
		{"position": 1, "is_player": false, "power": 5, "composure": 5, "runs": 12, "balls": 10, "out": true},
		{"position": 2, "is_player": true, "power": 8, "composure": 7, "runs": 40, "balls": 30, "out": false},
	]
	var fall := [{"wicket": 1, "score": 12, "batter": 1, "ball": 10}]
	var r := InningsResult.new(52, 1, 40, fall, batters)
	assert_eq(r.total, 52)
	assert_eq(r.wickets, 1)
	assert_eq(r.balls, 40)
	assert_eq(r.fall_of_wickets.size(), 1)
	assert_eq(r.batters.size(), 2)

func test_player_line_returns_player_row() -> void:
	var batters := [
		{"position": 1, "is_player": false, "power": 5, "composure": 5, "runs": 12, "balls": 10, "out": true},
		{"position": 2, "is_player": true, "power": 8, "composure": 7, "runs": 40, "balls": 30, "out": false},
	]
	var r := InningsResult.new(52, 1, 40, [], batters)
	var line := r.player_line()
	assert_true(line["is_player"], "player_line returns the player's row")
	assert_eq(line["runs"], 40)
	assert_eq(line["position"], 2)

func test_player_line_empty_when_no_player() -> void:
	var r := InningsResult.new(0, 0, 0, [], [])
	assert_eq(r.player_line(), {}, "no player -> empty dict")
