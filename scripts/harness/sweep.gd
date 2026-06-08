class_name Sweep
extends RefCounted

# Model-agnostic sweep engine: run each arm n times through a scenario Callable,
# collecting metric records. Paired seeds across arms (arm k's i-th run uses
# base_seed + i, the same for every arm) so arm-to-arm differences aren't RNG
# noise. See spec 2026-06-08-balance-harness-platform-7c1-design.md §4.

# arms: Array of {name: String, config: Variant}
# scenario: Callable(config, rng: RandomNumberGenerator) -> Dictionary
# Returns: Array of {name: String, records: Array[Dictionary]} in arm order.
static func run(arms: Array, n: int, scenario: Callable, base_seed: int = 1) -> Array:
	var out: Array = []
	for arm in arms:
		var records: Array = []
		for i in range(n):
			var rng := RandomNumberGenerator.new()
			rng.seed = base_seed + i
			records.append(scenario.call(arm["config"], rng))
		out.append({"name": arm["name"], "records": records})
	return out

# Pull one numeric field across an arm's records into a flat Array.
static func values_of(records: Array, field: String) -> Array:
	var v: Array = []
	for r in records:
		v.append(r[field])
	return v
