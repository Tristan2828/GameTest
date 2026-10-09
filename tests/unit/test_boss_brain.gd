extends GutTest

const DELTA: float = 1.0 / 60.0


func _attacks_over(brain: BossBrain, seconds: float, hp_ratio: float) -> Array[int]:
	var attacks: Array[int] = []
	for i: int in roundi(seconds / DELTA):
		var attack := brain.tick(DELTA, hp_ratio)
		if attack != BossBrain.Attack.NONE:
			attacks.append(attack)
	return attacks


func test_waits_for_the_intro_before_attacking() -> void:
	var brain := BossBrain.new()
	assert_eq(_attacks_over(brain, BossBrain.INTRO_DELAY - 0.1, 1.0).size(), 0)


func test_phase_one_cycles_rings_spiral_and_fans() -> void:
	var attacks := _attacks_over(BossBrain.new(), 20.0, 1.0)
	assert_has(attacks, BossBrain.Attack.RING)
	assert_has(attacks, BossBrain.Attack.SPIRAL)
	assert_has(attacks, BossBrain.Attack.FANS)
	assert_does_not_have(attacks, BossBrain.Attack.DOUBLE_SPIRAL)


func test_half_health_switches_to_faster_phase_two() -> void:
	var brain := BossBrain.new()
	_attacks_over(brain, 5.0, 1.0)
	var attacks := _attacks_over(brain, 20.0, 0.4)
	assert_eq(brain.phase, 2)
	assert_has(attacks, BossBrain.Attack.DOUBLE_SPIRAL)
	assert_does_not_have(attacks, BossBrain.Attack.SPIRAL)
	var phase_one_rate := _attacks_over(BossBrain.new(), 20.0, 1.0).size()
	assert_gt(attacks.size(), phase_one_rate, "phase 2 attacks more often")
