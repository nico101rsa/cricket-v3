"""Plain-text scorecard rendering. The game prints data; Claude narrates."""
from __future__ import annotations

from cricket.model import XI, Role
from cricket.sim.innings import InningsResult
from cricket.sim.match import MatchResult


def _role(p) -> str:
    if p.role == Role.BATTER:
        return "bat"
    if p.role == Role.ALLROUNDER:
        return "ar-" + ("pace" if p.bowl_kind.name == "PACE" else "spin")
    return "pace" if p.bowl_kind.name == "PACE" else "spin"


def render_xi(xi: XI) -> str:
    lines = [f"{xi.team.name} ({xi.team.city}) XI", "  #  Name                    Age  Role     Pow  Com  Att  Con"]
    for i, p in enumerate(xi.batting_order, 1):
        a = p.attrs
        bowls = "*" if p in xi.bowlers else " "
        lines.append(f"  {i:>2} {p.name:<22}{bowls} {p.age:>3}  {_role(p):<8} {a.power:>4.0f} {a.composure:>4.0f} {a.attack:>4.0f} {a.control:>4.0f}")
    lines.append("  * = one of the five bowlers")
    return "\n".join(lines)


def render_innings(inn: InningsResult) -> str:
    t = inn.xi.team
    head = f"{t.name.upper()}  {inn.total}/{inn.wickets} ({inn.overs_text} ov, RR {inn.run_rate:.2f})"
    if inn.target:
        head += f"  target {inn.target}"
    lines = [head]
    for b in inn.batters:
        if not b.batted:
            continue
        how = f"b {b.dismissed_by.short_name}" if b.out else "not out"
        lines.append(f"  {b.player.short_name:<16} {how:<18} {b.runs:>3} ({b.balls:>2})  4s {b.fours}  6s {b.sixes}  SR {b.strike_rate:>5.1f}")
    dnb = [b.player.short_name for b in inn.batters if not b.batted]
    if dnb:
        lines.append(f"  Did not bat: {', '.join(dnb)}")
    if inn.fall:
        fow = ", ".join(f"{f.wicket}-{f.score} ({f.batter.player.surname}, {f.over_text} ov)" for f in inn.fall)
        lines.append(f"  Fall of wickets: {fow}")
    lines.append("  Bowling            O    R  W   Econ  Dots")
    for c in inn.bowlers:
        lines.append(f"  {c.player.short_name:<16} {c.overs_text:>4} {c.runs:>4}  {c.wickets}  {c.economy:>5.2f}  {c.dots:>4}")
    pp, mid, death = inn.phase_runs
    lines.append(f"  Runs by phase: powerplay {pp}, middle {mid}, death {death}")
    return "\n".join(lines)


def render_match(m: MatchResult) -> str:
    h, a = m.home.team, m.away.team
    lines = [
        f"{h.name} ({h.city}) v {a.name} ({a.city})  -  T20",
        f"Toss: {m.toss_winner.name} won and chose to bat",
        "",
        render_innings(m.innings1),
        "",
        render_innings(m.innings2),
        "",
        f"RESULT: {m.result_line()}",
    ]
    return "\n".join(lines)
