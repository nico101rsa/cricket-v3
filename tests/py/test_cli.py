import random

from conftest import xis
from cricket.cli import main, play
from cricket.scorecard import render_innings, render_match, render_xi
from cricket.sim.match import simulate_match


def test_play_is_deterministic_and_complete():
    out = play(1, "Cape Town", "Sydney")
    assert out == play(1, "Cape Town", "Sydney")
    assert "Newlands CC" in out and "Manly Seasiders" in out
    assert "RESULT:" in out and "Toss:" in out
    assert "Fall of wickets" in out


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


def test_main_runs(capsys):
    assert main(["play", "--seed", "3", "--home", "Durban", "--away", "Perth", "--no-xi"]) == 0
    out = capsys.readouterr().out
    assert "Durban" in out and "Perth" in out and "RESULT:" in out
    assert " XI\n" not in out
