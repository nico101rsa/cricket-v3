class_name JokerRuntime
extends RefCounted

# Per-innings stateful layer for windowed-trigger jokers (C2c). The stateless
# JokerResolver handles per-ball conditions; this owns the decaying buffs that a
# Form event fires. See spec 2026-06-08-jokers-in-sim-7cC2c-form-windowed-design.md.
#
# Determinism: every method is driven by resolve_ball's deterministic output and
# the ball index — no RNG. An innings with no trigger jokers leaves `active` empty
# and tick_mults returns (1,1), so behaviour is byte-identical to pre-C2c.

const FORM_DOUBLE_WINDOW := 6  # Hot Streak: 2 Form events within this many balls

# C2e — Boost-press modifier magnitudes (pool-fixed, strawman; balance-tunable).
const BOOST_EXTEND_N := 2          # Power Up
const BOOST_AMPLIFY_MULT := 1.20  # Power Surge
const BOOST_AMPLIFY_N := 3
const BOOST_COMEBACK_MULT := 1.50  # The Comeback Press (3rd press)
const BOOST_COMEBACK_N := 6
const BOOST_COMEBACK_PRESS := 3
const BOOST_BATTERY_MULT := 1.10   # Boost Battery kicker
const BOOST_COMPOUND_BONUS := 1.25  # Compounding Pressure (favourable roll)
const BOOST_COMPOUND_GUARD := 0.85  # Compounding Pressure (defensive roll)

# Active buffs: each {side:int, target:int, mult:float, balls_left:int}.
var active: Array = []
# Innings-ball indices where a Player Form event fired (for the double trigger).
var form_event_balls: Array[int] = []
# C2e — how many Manager Boosts have been pressed this innings (for The Comeback Press).
var boost_press_count: int = 0
# C2f — DRS reviews remaining this innings (set by init_reviews when a DRSPolicy is used).
var reviews_left: int = 0

const DRS_MASTER_BONUS := 0.06      # The Review Master P(success) bonus
const DRS_BOWLING_BUFF_MULT := 1.20  # Bowler's Backing wicket buff
const DRS_BOWLING_BUFF_N := 6
# Bounded extra-review grants (replace the old "infinite retain-on-fail" mechanic,
# which had no scalar to tune — DB3 fallback, 2026-06-10). Base retain-on-success
# (keep your review when a decision is overturned) is unchanged.
const RETAIN_EXTRA_REVIEWS := 2     # The Captain's Call (#43) — spare reviews
const MASTER_EXTRA_REVIEWS := 2     # The Review Master (#45)

# Product of active buffs on the side that's batting/bowling this innings. Call at
# ball start; the returned (wicket_mult, runs_mult) multiplies the stateless mults.
func tick_mults(player_is_batting: bool) -> Vector2:
	var wm := 1.0
	var rm := 1.0
	for b in active:
		if (b["side"] == JokerEffect.Side.BATTING) != player_is_batting:
			continue
		if b["target"] == JokerEffect.Target.WICKET:
			wm *= b["mult"]
		else:
			rm *= b["mult"]
	return Vector2(wm, rm)

# Advance the runtime after a ball is resolved. Decays existing buffs first (those
# applied to the ball just played), then — if a Player Form event fired this ball —
# pushes new buffs from each matching trigger joker (so a window_n buff covers the
# *next* N balls). `ball` is the 1-based innings ball index just resolved.
func on_ball_end(jokers: Array, player_is_batting: bool, ball: int, formed: bool) -> void:
	# 1. decay
	for b in active:
		b["balls_left"] -= 1
	var kept: Array = []
	for b in active:
		if b["balls_left"] > 0:
			kept.append(b)
	active = kept

	if formed:
		_fire_form_event(jokers, player_is_batting, ball)

# C2g — a Form *source* (#2/#5/#11) fires a Form event when its condition holds
# (intent switch / survived Defensive over). If any joker carries this source, fire
# the Form channel so the consumer jokers (Ride the Wave, etc.) trigger.
func fire_form_source(jokers: Array, player_is_batting: bool, source: int, ball: int) -> void:
	for j in jokers:
		if j.form_source == source:
			_fire_form_event(jokers, player_is_batting, ball)
			return

# Record a Player Form event and push the windowed buffs it triggers. Shared by
# on_ball_end (boundary/wicket) and on_boost_press (Boost Adrenaline / Comeback).
func _fire_form_event(jokers: Array, player_is_batting: bool, ball: int) -> void:
	# Is this the 2nd Form event within the double window? (for Hot Streak)
	var is_double := false
	for prev in form_event_balls:
		if ball - prev < FORM_DOUBLE_WINDOW:
			is_double = true
			break
	form_event_balls.append(ball)

	for j in jokers:
		var fires := false
		match j.trigger:
			JokerEffect.Trigger.FORM_BAT:
				fires = player_is_batting and j.side == JokerEffect.Side.BATTING
			JokerEffect.Trigger.FORM_BOWL:
				fires = not player_is_batting and j.side == JokerEffect.Side.BOWLING
			JokerEffect.Trigger.FORM_DOUBLE_BAT:
				fires = player_is_batting and j.side == JokerEffect.Side.BATTING and is_double
		if fires:
			active.append({"side": j.side, "target": j.target, "mult": j.mult, "balls_left": j.window_n})

# C2d — a bowling change (setNextBowler) at a spell start. Pushes buffs that apply
# from the change over onward (balls_left = window_n), so call this *before*
# tick_mults at the spell's first ball. bowler_kind is a BowlingPlan.Kind; a
# CHANGE_* joker fires if its kind matches and its field_req (if any) matches.
func on_bowling_change(jokers: Array, bowler_kind: int, field_mode: int) -> void:
	for j in jokers:
		var fires := false
		match j.trigger:
			JokerEffect.Trigger.CHANGE_PACE:
				fires = bowler_kind == BowlingPlan.Kind.PACE
			JokerEffect.Trigger.CHANGE_SPIN:
				fires = bowler_kind == BowlingPlan.Kind.SPIN
			JokerEffect.Trigger.CHANGE_ANY:
				fires = true
		if fires and (j.field_req == -1 or field_mode == j.field_req):
			active.append({"side": j.side, "target": j.target, "mult": j.mult, "balls_left": j.window_n})

# C2e — a Manager Boost press. Pushes a side-aware base buff (runs while batting /
# wicket while bowling) of (mult, n) for the Player's current side, after the Boost
# Stack jokers modify it. Call at the press over's first ball, before tick_mults.
func on_boost_press(jokers: Array, player_is_batting: bool, intent: int, base_mult: float, base_n: int, ball: int) -> void:
	boost_press_count += 1
	var side := JokerEffect.Side.BATTING if player_is_batting else JokerEffect.Side.BOWLING
	var base_target := JokerEffect.Target.RUNS if player_is_batting else JokerEffect.Target.WICKET

	# Pedal to the Metal flips the press to Aggressive (enables Compounding Pressure).
	var eff_intent := intent
	for j in jokers:
		if j.boost_role == JokerEffect.BoostRole.PEDAL:
			eff_intent = BallResolver.Intent.AGGRESSIVE

	# Parameter modifiers (Power Up / Power Surge / Comeback Press) shape mult & n.
	var mult := base_mult
	var n := base_n
	for j in jokers:
		match j.boost_role:
			JokerEffect.BoostRole.EXTEND:
				n += BOOST_EXTEND_N
			JokerEffect.BoostRole.AMPLIFY:
				mult *= BOOST_AMPLIFY_MULT
				n += BOOST_AMPLIFY_N
			JokerEffect.BoostRole.COMEBACK:
				if boost_press_count == BOOST_COMEBACK_PRESS:
					mult *= BOOST_COMEBACK_MULT
					n += BOOST_COMEBACK_N

	# The base Boost buff (a baseline mechanic — fires even with no Boost jokers).
	active.append({"side": side, "target": base_target, "mult": mult, "balls_left": n})

	# Chain jokers (extra buffs / Form grants on the press).
	for j in jokers:
		match j.boost_role:
			JokerEffect.BoostRole.BATTERY:
				active.append({"side": side, "target": base_target, "mult": BOOST_BATTERY_MULT, "balls_left": n})
			JokerEffect.BoostRole.COMPOUND:
				if eff_intent == BallResolver.Intent.AGGRESSIVE:
					# runs +25% & wicket −15% (batting); mirror (bowling): wicket +25% & runs −15%.
					if player_is_batting:
						active.append({"side": side, "target": JokerEffect.Target.RUNS, "mult": BOOST_COMPOUND_BONUS, "balls_left": n})
						active.append({"side": side, "target": JokerEffect.Target.WICKET, "mult": BOOST_COMPOUND_GUARD, "balls_left": n})
					else:
						active.append({"side": side, "target": JokerEffect.Target.WICKET, "mult": BOOST_COMPOUND_BONUS, "balls_left": n})
						active.append({"side": side, "target": JokerEffect.Target.RUNS, "mult": BOOST_COMPOUND_GUARD, "balls_left": n})
			JokerEffect.BoostRole.ADRENALINE:
				_fire_form_event(jokers, player_is_batting, ball)
			JokerEffect.BoostRole.COMEBACK:
				_fire_form_event(jokers, player_is_batting, ball)

# C2f — set the per-innings DRS review count: base + grants (Spare Review #40,
# Review Master #45). Call once at innings start when a DRSPolicy is used.
func init_reviews(jokers: Array, base_reviews: int) -> void:
	reviews_left = base_reviews
	for j in jokers:
		match j.drs_role:
			JokerEffect.DRSRole.EXTRA_REVIEW:
				reviews_left += 1
			JokerEffect.DRSRole.RETAIN:
				reviews_left += RETAIN_EXTRA_REVIEWS
			JokerEffect.DRSRole.MASTER:
				reviews_left += MASTER_EXTRA_REVIEWS

# C2f — attempt a DRS review on a close decision. Returns whether it is overturned
# (batting: the Player survives; bowling: a wicket is claimed). Rolls exactly one
# randf when a review is available. On success the review is retained (base T20
# rule); on fail it is consumed. The Captain's Call / Review Master grant extra
# reviews up front (init_reviews) rather than the old infinite retain-on-fail.
# Fires success payoffs.
func try_review(jokers: Array, player_is_batting: bool, intent: int, base_p: float, ball: int, rng: RandomNumberGenerator) -> bool:
	if reviews_left <= 0:
		return false
	var p := base_p
	for j in jokers:
		match j.drs_role:
			JokerEffect.DRSRole.ACCURACY:
				if j.intent_req == -1 or intent == j.intent_req:
					p += j.drs_p_bonus
			JokerEffect.DRSRole.MASTER:
				p += DRS_MASTER_BONUS
	p = clampf(p, 0.0, 1.0)
	var success := rng.randf() < p
	if success:
		for j in jokers:
			match j.drs_role:
				JokerEffect.DRSRole.FORM_ON_SUCCESS, JokerEffect.DRSRole.MASTER:
					_fire_form_event(jokers, player_is_batting, ball)
				JokerEffect.DRSRole.BOWLING_BUFF:
					if not player_is_batting:
						active.append({"side": JokerEffect.Side.BOWLING, "target": JokerEffect.Target.WICKET, "mult": DRS_BOWLING_BUFF_MULT, "balls_left": DRS_BOWLING_BUFF_N})
	else:
		reviews_left -= 1
	return success
