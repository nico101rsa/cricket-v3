import random

from conftest import xis
from cricket.cli import main, play
from cricket.scorecard import NARROW, render_innings, render_match, render_match_narrow, render_xi, render_xi_narrow
from cricket.sim.match import simulate_match


def test_play_is_deterministic_and_complete():
    out = play(1, "Cape Town", "Sydney")
    assert out == play(1, "Cape Town", "Sydney")
    assert "Newlands CC" in out and "Manly Seasiders" in out
    assert "won by" in out or "Match tied" in out
    assert "Toss:" in out and "Fall:" in out


def test_different_seed_different_match():
    assert play(1, "Cape Town", "Sydney") != play(2, "Cape Town", "Sydney")


def test_scorecard_rows_reconcile(tuning, itun):
    h, a = xis(11)
    m = simulate_match(h, a, tuning, itun, random.Random(11))
    card = render_match(m)
    assert f"{m.innings1.total}/{m.innings1.wickets}" in card
    assert f"target {m.innings1.total + 1}" in card
    assert m.result_line() in card
    assert render_innings(m.innings1).count("\n") >= 8
    assert "* = one of the five bowlers" in render_xi(h)


def test_narrow_card_fits_a_phone(tuning, itun):
    from cricket.mock import mock_fixture
    from cricket.model import pick_xi
    pairs = [("Cape Town", "Sydney"), ("Pietermaritzburg", "Darwin"), ("Durban", "Hobart")]
    for seed in range(1, 40):
        home, away = mock_fixture(seed, *pairs[seed % len(pairs)])
        h, a = pick_xi(home), pick_xi(away)
        m = simulate_match(h, a, tuning, itun, random.Random(seed))
        for text in (render_match_narrow(m), render_xi_narrow(h), render_xi_narrow(a)):
            for line in text.splitlines():
                assert len(line) <= NARROW, f"{line!r} is {len(line)} wide"
        card = render_match_narrow(m)
        assert f"{m.innings1.total}/{m.innings1.wickets}" in card
        assert m.winner is None or m.winner.name in card


def test_wide_flag_selects_the_full_card():
    narrow = play(1, "Cape Town", "Sydney", show_xi=False)
    wide = play(1, "Cape Town", "Sydney", show_xi=False, wide=True)
    assert "RESULT:" in wide and "Runs by phase" in wide
    assert "RESULT:" not in narrow
    assert max(len(l) for l in narrow.splitlines()) <= NARROW


def test_main_runs(capsys):
    assert main(["play", "--seed", "3", "--home", "Durban", "--away", "Perth", "--no-xi"]) == 0
    out = capsys.readouterr().out
    assert "Toss:" in out and ("won by" in out or "Match tied" in out)
    assert " XI\n" not in out
    assert main(["play", "--seed", "3", "--home", "Durban", "--away", "Perth", "--wide"]) == 0
    assert "RESULT:" in capsys.readouterr().out
