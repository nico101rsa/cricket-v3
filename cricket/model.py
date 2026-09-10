"""Players and teams. Attributes sit on Cricket v2's /100 card scale.

A player has four attributes: power and composure (batting), attack and
control (bowling). Bowlers also carry a kind (pace or spin) that the sim uses
for phase bonuses and the intent-vs-kind matchup.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import IntEnum


class BowlKind(IntEnum):
    PACE = 0
    SPIN = 1


class Role(IntEnum):
    BATTER = 0
    ALLROUNDER = 1
    BOWLER = 2


@dataclass
class Attributes:
    power: float
    composure: float
    attack: float
    control: float

    @property
    def batting(self) -> float:
        return self.power + self.composure

    @property
    def bowling(self) -> float:
        return self.attack + self.control

    def copy(self) -> "Attributes":
        return Attributes(self.power, self.composure, self.attack, self.control)


@dataclass
class Player:
    first_name: str
    surname: str
    age: int
    role: Role
    bowl_kind: BowlKind
    attrs: Attributes

    @property
    def name(self) -> str:
        return f"{self.first_name} {self.surname}"

    @property
    def short_name(self) -> str:
        return f"{self.first_name[0]}. {self.surname}"

    def to_dict(self) -> dict:
        return {
            "first_name": self.first_name,
            "surname": self.surname,
            "age": self.age,
            "role": self.role.name,
            "bowl_kind": self.bowl_kind.name,
            "attrs": {
                "power": self.attrs.power,
                "composure": self.attrs.composure,
                "attack": self.attrs.attack,
                "control": self.attrs.control,
            },
        }

    @staticmethod
    def from_dict(d: dict) -> "Player":
        a = d["attrs"]
        return Player(
            d["first_name"], d["surname"], int(d["age"]),
            Role[d["role"]], BowlKind[d["bowl_kind"]],
            Attributes(a["power"], a["composure"], a["attack"], a["control"]),
        )


@dataclass
class Team:
    name: str
    city: str
    country: str          # "SA" or "AUS"
    squad: list[Player] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "name": self.name, "city": self.city, "country": self.country,
            "squad": [p.to_dict() for p in self.squad],
        }

    @staticmethod
    def from_dict(d: dict) -> "Team":
        return Team(d["name"], d["city"], d["country"], [Player.from_dict(p) for p in d["squad"]])


@dataclass
class XI:
    """A picked eleven: batting order (11 players) and the five who bowl."""
    team: Team
    batting_order: list[Player]
    bowlers: list[Player]

    def __post_init__(self) -> None:
        if len(self.batting_order) != 11:
            raise ValueError(f"an XI needs 11 batters, got {len(self.batting_order)}")
        if len(self.bowlers) != 5:
            raise ValueError(f"an XI needs 5 bowlers, got {len(self.bowlers)}")
        for b in self.bowlers:
            if b not in self.batting_order:
                raise ValueError(f"bowler {b.name} is not in the XI")


def pick_xi(team: Team) -> XI:
    """Auto-pick the strongest XI from a squad: the 6 best batters, the best
    all-rounder and 4 bowlers (the 2 best pace and the 2 best spin, so the
    rotation can cover the pace and spin phases). Batting order = batters by
    batting strength, then the all-rounder, then bowlers by batting strength.
    The five bowlers are the XI's five best by bowling strength.
    """
    by_bowling = lambda p: -p.attrs.bowling
    batters = sorted((p for p in team.squad if p.role == Role.BATTER), key=lambda p: -p.attrs.batting)
    alls = sorted((p for p in team.squad if p.role == Role.ALLROUNDER), key=by_bowling)
    pace = sorted((p for p in team.squad if p.role == Role.BOWLER and p.bowl_kind == BowlKind.PACE), key=by_bowling)
    spin = sorted((p for p in team.squad if p.role == Role.BOWLER and p.bowl_kind == BowlKind.SPIN), key=by_bowling)
    bowlers = pace[:2] + spin[:2]
    if len(bowlers) < 4:
        spare = sorted((p for p in pace[2:] + spin[2:]), key=by_bowling)
        bowlers += spare[: 4 - len(bowlers)]
    chosen = batters[:6] + alls[:1] + bowlers
    if len(chosen) < 11:
        # Squad is oddly shaped: top up with the best remaining players by total.
        rest = sorted((p for p in team.squad if p not in chosen),
                      key=lambda p: -(p.attrs.batting + p.attrs.bowling))
        chosen += rest[: 11 - len(chosen)]
    if len(chosen) < 11:
        raise ValueError(f"{team.name} has only {len(team.squad)} players; an XI needs 11")
    top = sorted(chosen[:6], key=lambda p: -p.attrs.batting)
    tail = sorted(chosen[6:], key=lambda p: -p.attrs.batting)
    order = top + tail
    five = sorted(order, key=by_bowling)[:5]
    return XI(team, order, five)
