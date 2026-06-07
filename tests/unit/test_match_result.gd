extends GutTest

func _result(outcome: int, runs: int, wkts: int, balls_left: int) -> MatchResult:
	var r := MatchResult.new()
	r.innings1 = InningsResult.new(150, 8, 120, [], [])
	r.innings2 = InningsResult.new(140, 6, 120, [], [])
	r.player_bats_first = true
	r.outcome = outcome
	r.margin_runs = runs
	r.margin_wickets = wkts
	r.balls_remaining = balls_left
	return r

func test_holds_fields() -> void:
	var r := _result(MatchResult.Outcome.PLAYER_WIN, 10, 0, 0)
	assert_eq(r.innings1.total, 150, "innings1 stored")
	assert_eq(r.innings2.total, 140, "innings2 stored")
	assert_true(r.player_bats_first, "bats-first flag stored")
	assert_eq(r.outcome, MatchResult.Outcome.PLAYER_WIN, "outcome stored")
	assert_eq(r.margin_runs, 10, "margin_runs stored")

func test_player_won_true_on_player_win() -> void:
	assert_true(_result(MatchResult.Outcome.PLAYER_WIN, 10, 0, 0).player_won(), "PLAYER_WIN -> player_won")
	assert_false(_result(MatchResult.Outcome.OPPONENT_WIN, 10, 0, 0).player_won(), "OPPONENT_WIN -> not player_won")
	assert_false(_result(MatchResult.Outcome.TIE, 0, 0, 0).player_won(), "TIE -> not player_won")

func test_is_tie_true_on_tie() -> void:
	assert_true(_result(MatchResult.Outcome.TIE, 0, 0, 0).is_tie(), "TIE -> is_tie")
	assert_false(_result(MatchResult.Outcome.PLAYER_WIN, 10, 0, 0).is_tie(), "win -> not tie")

func test_margin_text_runs() -> void:
	var r := _result(MatchResult.Outcome.PLAYER_WIN, 14, 0, 0)
	assert_eq(r.margin_text(), "won by 14 runs", "runs-margin text")

func test_margin_text_wickets() -> void:
	var r := _result(MatchResult.Outcome.PLAYER_WIN, 0, 6, 8)
	assert_eq(r.margin_text(), "won by 6 wickets (8 balls left)", "wickets-margin text")

func test_margin_text_tie() -> void:
	var r := _result(MatchResult.Outcome.TIE, 0, 0, 0)
	assert_eq(r.margin_text(), "match tied", "tie text")
