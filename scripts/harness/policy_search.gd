class_name PolicySearch
extends RefCounted

# E1 self-play helpers (spec 2026-06-10-selfplay-baseline-7cE1-design.md D7).
# A static no-joker policy = one batting Intent per phase x one bowler Kind per
# phase = 27 x 8 = 216. Pure functions only; the oracle composes them.

const INTENTS := [BallResolver.Intent.DEFENSIVE, BallResolver.Intent.BALANCED, BallResolver.Intent.AGGRESSIVE]
const KINDS := [BowlingPlan.Kind.PACE, BowlingPlan.Kind.SPIN]

const INTENT_LETTER := {
	BallResolver.Intent.DEFENSIVE: "D",
	BallResolver.Intent.BALANCED: "B",
	BallResolver.Intent.AGGRESSIVE: "A",
}
const KIND_LETTER := {
	BowlingPlan.Kind.PACE: "P",
	BowlingPlan.Kind.SPIN: "S",
}


# All 216 policies in a stable order (intent loops outer, bowling inner).
static func enumerate() -> Array:
	var out: Array = []
	for pp_i in INTENTS:
		for mid_i in INTENTS:
			for death_i in INTENTS:
				for pp_b in KINDS:
					for mid_b in KINDS:
						for death_b in KINDS:
							out.append({
								"pp_intent": pp_i, "mid_intent": mid_i, "death_intent": death_i,
								"pp_bowl": pp_b, "mid_bowl": mid_b, "death_bowl": death_b,
							})
	return out


static func intent_plan_of(p: Dictionary) -> IntentPlan:
	var plan := IntentPlan.new()
	plan.powerplay = p["pp_intent"]
	plan.middle = p["mid_intent"]
	plan.death = p["death_intent"]
	# E2: optional state-rule keys (absent on static policies -> rules disabled).
	plan.chase_up_rr = p.get("up", -1.0)
	plan.chase_down_rr = p.get("down", -1.0)
	plan.collapse_wkts = p.get("collapse", -1)
	return plan


static func bowling_plan_of(p: Dictionary) -> BowlingPlan:
	var plan := BowlingPlan.new()
	plan.powerplay = p["pp_bowl"]
	plan.middle = p["mid_bowl"]
	plan.death = p["death_bowl"]
	return plan


# Compact display label, e.g. "A/B/A·P/S/P" (textbook). Adaptive policies
# (E2 rule keys present) get a "+u9d6c4" suffix; "-" = that rule is off.
static func label_of(p: Dictionary) -> String:
	var s := "%s/%s/%s·%s/%s/%s" % [
		INTENT_LETTER[p["pp_intent"]], INTENT_LETTER[p["mid_intent"]], INTENT_LETTER[p["death_intent"]],
		KIND_LETTER[p["pp_bowl"]], KIND_LETTER[p["mid_bowl"]], KIND_LETTER[p["death_bowl"]],
	]
	if p.has("up"):
		var u := "-" if p["up"] < 0.0 else str(int(p["up"]))
		var d := "-" if p["down"] < 0.0 else str(int(p["down"]))
		var c := "-" if p["collapse"] < 0 else str(int(p["collapse"]))
		s += "+u%sd%sc%s" % [u, d, c]
	return s


# The textbook start point: attack PP, build middle, slog death; pace/spin/pace.
static func textbook() -> Dictionary:
	return {
		"pp_intent": BallResolver.Intent.AGGRESSIVE,
		"mid_intent": BallResolver.Intent.BALANCED,
		"death_intent": BallResolver.Intent.AGGRESSIVE,
		"pp_bowl": BowlingPlan.Kind.PACE,
		"mid_bowl": BowlingPlan.Kind.SPIN,
		"death_bowl": BowlingPlan.Kind.PACE,
	}


# All-BALANCED intent + textbook rotation (the pre-rung-4a "no plan" player).
static func balanced() -> Dictionary:
	return {
		"pp_intent": BallResolver.Intent.BALANCED,
		"mid_intent": BallResolver.Intent.BALANCED,
		"death_intent": BallResolver.Intent.BALANCED,
		"pp_bowl": BowlingPlan.Kind.PACE,
		"mid_bowl": BowlingPlan.Kind.SPIN,
		"death_bowl": BowlingPlan.Kind.PACE,
	}


# Argmax over win rates; ties go to the LOWER index (stable).
static func best_index(win_rates: Array) -> int:
	var best := 0
	for i in range(1, win_rates.size()):
		if win_rates[i] > win_rates[best]:
			best = i
	return best


# The ADR 0003 "naive" player: one uniform draw from the policy list per match.
static func random_policy(policies: Array, rng: RandomNumberGenerator) -> Dictionary:
	return policies[rng.randi_range(0, policies.size() - 1)]


# --- E2 adaptive space (spec 2026-06-11-stateaware-policy-7cE2-design.md §5) ---
# An adaptive policy = a static policy dict + rule keys "up"/"down"/"collapse"
# (IntentPlan.chase_up_rr / chase_down_rr / collapse_wkts; -1 = off).

const RULE_UP := [-1.0, 8.0, 9.0, 10.0, 11.0]
const RULE_DOWN := [-1.0, 5.0, 6.0, 7.0]
const RULE_COLLAPSE := [-1, 3, 4, 5]


# The bowling-balance static equilibrium: B/A/B·P/S/P.
static func static_equilibrium() -> Dictionary:
	return {
		"pp_intent": BallResolver.Intent.BALANCED,
		"mid_intent": BallResolver.Intent.AGGRESSIVE,
		"death_intent": BallResolver.Intent.BALANCED,
		"pp_bowl": BowlingPlan.Kind.PACE,
		"mid_bowl": BowlingPlan.Kind.SPIN,
		"death_bowl": BowlingPlan.Kind.PACE,
	}


# The 4 intent bases (DS4), all bowling textbook P/S/P.
static func adaptive_bases() -> Array:
	var runner_up := static_equilibrium()
	runner_up["death_intent"] = BallResolver.Intent.AGGRESSIVE  # B/A/A
	return [static_equilibrium(), runner_up, textbook(), balanced()]


# 4 bases x 5 up x 4 down x 4 collapse = 320 adaptive candidates. Rules-off
# combos duplicate their static base — kept as sanity anchors in the screen.
static func enumerate_adaptive() -> Array:
	var out: Array = []
	for base in adaptive_bases():
		for up in RULE_UP:
			for down in RULE_DOWN:
				for col in RULE_COLLAPSE:
					var p := (base as Dictionary).duplicate()
					p["up"] = up
					p["down"] = down
					p["collapse"] = col
					out.append(p)
	return out
