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


# --- Narrow format: fits a phone screen (NARROW columns). This is the default. ---

NARROW = 36

def _short(p, width: int) -> str:
    s = p.surname if len(p.surname) <= width else p.surname[: width - 1] + "."
    return f"{s:<{width}}"


def _wrap(prefix: str, items: list[str], width: int = NARROW) -> list[str]:
    """Comma-join items into lines no wider than width, first line prefixed."""
    lines, cur = [], prefix
    for it in items:
        piece = it if cur in (prefix, "  ") else ", " + it
        if len(cur) + len(piece) + 1 > width and cur not in (prefix, "  "):   # +1 = trailing comma
            lines.append(cur + ",")
            cur = "  " + it
        else:
            cur += piece
    lines.append(cur)
    return lines


def _fit(line: str, sep: str, width: int = NARROW, tail: str | None = None) -> list[str]:
    """Break a line in two if it is too wide: at the first sep, or before
    the given tail (the part that moves to the second line)."""
    if len(line) <= width:
        return [line]
    if tail is not None:
        return [line[: -len(tail)].rstrip(), "  " + tail]
    head, _, rest = line.partition(sep)
    return [head + sep.rstrip(), "  " + rest]


def _result_lines(m: MatchResult) -> list[str]:
    if m.winner is None:
        return ["Match tied"]
    if m.margin_runs > 0:
        margin = f"won by {m.margin_runs} run{'' if m.margin_runs == 1 else 's'}"
        extra = []
    else:
        margin = f"won by {m.margin_wickets} wicket{'' if m.margin_wickets == 1 else 's'},"
        extra = [f"  {m.balls_remaining} ball{'' if m.balls_remaining == 1 else 's'} left"]
    return _fit(f"{m.winner.name} {margin}", " ", tail=margin) + extra


def _score(inn: InningsResult) -> str:
    return f"{inn.total}/{inn.wickets} ({inn.overs_text} ov)"


def render_xi_narrow(xi: XI) -> str:
    lines = [f"{xi.team.name} XI", " #  Name         Role    Bat   Bowl"]
    for i, p in enumerate(xi.batting_order, 1):
        a = p.attrs
        bowls = "*" if p in xi.bowlers else " "
        bat = f"{a.power:.0f}/{a.composure:.0f}"
        bowl = f"{a.attack:.0f}/{a.control:.0f}"
        lines.append(f"{i:>2}{bowls} {_short(p, 11)}  {_role(p):<7} {bat:<5} {bowl:<5}")
    lines.append("Bat = pow/comp, Bowl = att/con")
    lines.append("* = one of the five bowlers")
    return "\n".join(lines)


def render_innings_narrow(inn: InningsResult) -> str:
    t = inn.xi.team
    lines = _fit(f"{t.name.upper()} {_score(inn)}", " ", tail=_score(inn))
    for b in inn.batters:
        if not b.batted:
            continue
        how = f"b {b.dismissed_by.surname}" if b.out else "not out"
        lines.append(f"{_short(b.player, 12)} {b.runs:>3} ({b.balls:>2})  {how}")
    if inn.fall:
        lines += _wrap("Fall: ", [f"{f.wicket}-{f.score}" for f in inn.fall])
    lines.append("Bowling       O-R-W     Econ")
    for c in inn.bowlers:
        figs = f"{c.overs_text}-{c.runs}-{c.wickets}"
        lines.append(f"{_short(c.player, 12)}  {figs:<9} {c.economy:>5.2f}")
    return "\n".join(lines)


def render_match_narrow(m: MatchResult) -> str:
    h, a = m.home.team, m.away.team
    i1, i2 = m.innings1, m.innings2
    lines = [
        *_fit(f"{h.name} v {a.name}", " v "),
        *_fit(f"Toss: {m.toss_winner.name}, batted first", ", "),
        "",
        *_fit(f"{i1.xi.team.name} {_score(i1)}", " ", tail=_score(i1)),
        *_fit(f"{i2.xi.team.name} {_score(i2)}", " ", tail=_score(i2)),
        *_result_lines(m),
        "",
        render_innings_narrow(i1),
        "",
        render_innings_narrow(i2),
    ]
    return "\n".join(lines)
