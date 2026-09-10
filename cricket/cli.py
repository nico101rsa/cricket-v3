"""Command line entry point: `python -m cricket play [--seed N] [--home CITY] [--away CITY]`."""
from __future__ import annotations

import argparse
import random

from cricket.mock import mock_fixture
from cricket.model import pick_xi
from cricket.names import CITIES
from cricket.scorecard import render_match, render_match_narrow, render_xi, render_xi_narrow
from cricket.sim.intent import IntentPlan
from cricket.sim.match import simulate_match
from cricket.tuning import BallTuning, InningsTuning


def play(seed: int, home_city: str, away_city: str, show_xi: bool = True, wide: bool = False) -> str:
    """Play one match and return the scorecard. Narrow (phone) format by default."""
    home, away = mock_fixture(seed, home_city, away_city)
    hxi, axi = pick_xi(home), pick_xi(away)
    rng = random.Random(seed * 7919 + 1)
    m = simulate_match(hxi, axi, BallTuning(), InningsTuning(), rng,
                       IntentPlan.adaptive(), IntentPlan.adaptive())
    xi_fn = render_xi if wide else render_xi_narrow
    parts = []
    if show_xi:
        parts += [xi_fn(hxi), "", xi_fn(axi), ""]
    parts.append(render_match(m) if wide else render_match_narrow(m))
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
    p.add_argument("--wide", action="store_true", help="full-width scorecard (default fits a phone)")
    args = ap.parse_args(argv)
    if args.cmd == "play":
        print(play(args.seed, args.home, args.away, not args.no_xi, args.wide))
    return 0
