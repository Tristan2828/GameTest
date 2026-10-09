extends GutTest

const DELTA: float = 1.0 / 60.0


func _crypt_brain() -> BossBrain:
	var stage := Stages.get_stage(1)
	return BossBrain.new(stage.boss_phase_one, stage.boss_phase_two)


func _patterns_over(brain: BossBrain, seconds: float, hp_ratio: float) -> Array[int]:
	var patterns: Array[int] = []
	for i: int in roundi(seconds / DELTA):
		var step := brain.tick(DELTA, hp_ratio)
		if step != null:
			patterns.append(step.pattern)
	return patterns


func test_waits_for_the_intro_before_attacking() -> void:
	assert_eq(_patterns_over(_crypt_brain(), BossBrain.INTRO_DELAY - 0.1, 1.0).size(), 0)


func test_phase_one_cycles_rings_spiral_and_fans() -> void:
	var patterns := _patterns_over(_crypt_brain(), 20.0, 1.0)
	assert_has(patterns, ShotPatterns.Id.RING_24)
	assert_has(patterns, ShotPatterns.Id.SPIRAL)
	assert_has(patterns, ShotPatterns.Id.AIMED_FAN_7)
	assert_does_not_have(patterns, ShotPatterns.Id.DOUBLE_SPIRAL)


func test_half_health_switches_to_faster_phase_two() -> void:
	var brain := _crypt_brain()
	_patterns_over(brain, 5.0, 1.0)
	var patterns := _patterns_over(brain, 20.0, 0.4)
	assert_eq(brain.phase, 2)
	assert_has(patterns, ShotPatterns.Id.DOUBLE_SPIRAL)
	assert_does_not_have(patterns, ShotPatterns.Id.SPIRAL)
	var phase_one_rate := _patterns_over(_crypt_brain(), 20.0, 1.0).size()
	assert_gt(patterns.size(), phase_one_rate, "phase 2 attacks more often")


func test_empty_script_never_attacks() -> void:
	assert_eq(_patterns_over(BossBrain.new(), 10.0, 1.0).size(), 0)
