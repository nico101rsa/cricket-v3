"""Command line entry point: `python -m cricket play [--seed N] [--home CITY] [--away CITY]`."""
from __future__ import annotations

import argparse
import random

from cricket.mock import mock_fixture
from cricket.model import pick_xi
from cricket.names import CITIES
from cricket.scorecard import render_match, render_xi
from cricket.sim.intent import IntentPlan
from cricket.sim.match import simulate_match
from cricket.tuning import BallTuning, InningsTuning


def play(seed: int, home_city: str, away_city: str, show_xi: bool = True) -> str:
    home, away = mock_fixture(seed, home_city, away_city)
    hxi, axi = pick_xi(home), pick_xi(away)
    rng = random.Random(seed * 7919 + 1)
    m = simulate_match(hxi, axi, BallTuning(), InningsTuning(), rng,
                       IntentPlan.adaptive(), IntentPlan.adaptive())
    parts = []
    if show_xi:
        parts += [render_xi(hxi), "", render_xi(axi), ""]
    parts.append(render_match(m))
    return "\n".join(parts)


def main(argv: list[str] | None = None) -> int:
    all_cities = CITIES["SA"] + CITIES["AUS"]
    ap = argparse.ArgumentParser(prog="cricket", description="Cricket v3 - text cricket management")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("play", help="play one T20 between two mock teams")
    p.add_argument("--seed", type=int, default=1, help="seed for squads and the match (default 1)")
    p.add_argument("--home", default="Cape Town", choices=all_cities, metavar="CITY")
    p.add_argument("--away", default="Sydney", choices=all_cities, metavar="CITY")
    p.add_argument("--no-xi", action="store_true", help="skip the team sheets")
    args = ap.parse_args(argv)
    if args.cmd == "play":
        print(play(args.seed, args.home, args.away, not args.no_xi))
    return 0
