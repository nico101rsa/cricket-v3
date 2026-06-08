extends GutTest

# A scenario that ignores config and returns the rng's first int — to inspect seeds.
func _seed_probe(_config, rng: RandomNumberGenerator) -> Dictionary:
	return {"r": rng.randi()}

# A scenario that echoes the config (a number) — to check config threading.
func _config_echo(config, _rng: RandomNumberGenerator) -> Dictionary:
	return {"v": config}

func test_run_shape() -> void:
	var arms := [{"name": "a", "config": 1}, {"name": "b", "config": 2}]
	var res := Sweep.run(arms, 5, _config_echo)
	assert_eq(res.size(), 2, "one entry per arm")
	assert_eq(res[0]["name"], "a", "arm name preserved")
	assert_eq(res[0]["records"].size(), 5, "n records for arm a")
	assert_eq(res[1]["records"].size(), 5, "n records for arm b")

func test_values_of() -> void:
	var arms := [{"name": "a", "config": 7}]
	var res := Sweep.run(arms, 4, _config_echo)
	var vals := Sweep.values_of(res[0]["records"], "v")
	assert_eq(vals, [7, 7, 7, 7], "config threaded into every record")

func test_paired_seeds_across_arms() -> void:
	# Both arms ignore config, so identical paired seeds -> identical record streams.
	var arms := [{"name": "a", "config": 0}, {"name": "b", "config": 0}]
	var res := Sweep.run(arms, 6, _seed_probe, 100)
	assert_eq(Sweep.values_of(res[0]["records"], "r"), Sweep.values_of(res[1]["records"], "r"),
		"arm a and arm b saw the same seed sequence (paired)")

func test_deterministic() -> void:
	var arms := [{"name": "a", "config": 0}]
	var r1 := Sweep.run(arms, 6, _seed_probe, 42)
	var r2 := Sweep.run(arms, 6, _seed_probe, 42)
	assert_eq(Sweep.values_of(r1[0]["records"], "r"), Sweep.values_of(r2[0]["records"], "r"),
		"same base_seed -> identical records")
