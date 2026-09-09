import random

import pytest

from cricket.mock import SQUAD_SHAPE, mock_fixture, mock_team
from cricket.model import Attributes, BowlKind, Player, Role, Team, XI, pick_xi


def test_same_seed_same_squads():
    a = mock_fixture(42)
    b = mock_fixture(42)
    assert [p.to_dict() for p in a[0].squad] == [p.to_dict() for p in b[0].squad]
    assert a[1].to_dict() == b[1].to_dict()
    assert mock_fixture(43)[0].to_dict() != a[0].to_dict()


def test_squad_shape_and_names():
    home, away = mock_fixture(1)
    for t in (home, away):
        assert len(t.squad) == 15
        assert [p.role for p in t.squad] == SQUAD_SHAPE
        assert len({p.name for p in t.squad}) == 15
        assert all(19 <= p.age <= 35 for p in t.squad)
    assert home.country == "SA" and away.country == "AUS"
    assert home.name == "Newlands CC" and away.name == "Manly Seasiders"


def test_mock_attributes_sit_on_archetypes():
    for seed in range(1, 30):
        for t in mock_fixture(seed):
            for p in t.squad:
                a = p.attrs
                if p.role == Role.BATTER:
                    assert 40 <= a.power <= 60 and 40 <= a.composure <= 60
                    assert 10 <= a.attack <= 15
                elif p.role == Role.BOWLER:
                    assert 5 <= a.power <= 7.5
                    hi, lo = (a.attack, a.control) if p.bowl_kind == BowlKind.PACE else (a.control, a.attack)
                    assert 35 <= hi <= 52.5 and 15 <= lo <= 22.5
                else:
                    assert 25 <= a.power <= 37.5


def test_pick_xi_shape():
    for seed in range(1, 30):
        for t in mock_fixture(seed):
            xi = pick_xi(t)
            assert len(xi.batting_order) == 11 and len(set(map(id, xi.batting_order))) == 11
            assert all(p in t.squad for p in xi.batting_order)
            roles = [p.role for p in xi.batting_order]
            assert roles[:6] == [Role.BATTER] * 6 and roles[6] == Role.ALLROUNDER and roles[7:] == [Role.BOWLER] * 4
            kinds = [p.bowl_kind for p in xi.batting_order[7:]]
            assert kinds.count(BowlKind.PACE) == 2 and kinds.count(BowlKind.SPIN) == 2
            assert len(xi.bowlers) == 5 and all(b in xi.batting_order for b in xi.bowlers)
            # the five bowlers are the XI's five best by bowling
            best = sorted(xi.batting_order, key=lambda p: -p.attrs.bowling)[:5]
            assert {id(b) for b in best} == {id(b) for b in xi.bowlers}


def test_xi_validation():
    t, _ = mock_fixture(1)
    with pytest.raises(ValueError):
        XI(t, t.squad[:10], t.squad[:5])
    with pytest.raises(ValueError):
        XI(t, t.squad[:11], t.squad[:4])
    with pytest.raises(ValueError):
        XI(t, t.squad[:11], t.squad[10:15])


def test_pick_xi_needs_eleven():
    t = Team("Tiny", "Cape Town", "SA", mock_fixture(1)[0].squad[:9])
    with pytest.raises(ValueError):
        pick_xi(t)


def test_team_roundtrip():
    t, _ = mock_fixture(9)
    again = Team.from_dict(t.to_dict())
    assert again.to_dict() == t.to_dict()
    assert again.squad[0].attrs.batting == t.squad[0].attrs.batting


def test_mock_team_unknown_city():
    with pytest.raises(KeyError):
        mock_team("Atlantis", 0, random.Random(1))
