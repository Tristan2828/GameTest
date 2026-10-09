class_name BossBrain
extends RefCounted
## Runs a boss's attack script (host only). Pure logic: tick() returns the step
## to perform this tick (or null); the arena turns steps into bullet patterns.
## The script comes from the stage's StageDef: phase one, then phase two below
## half HP.

const INTRO_DELAY: float = 2.5
const PHASE_TWO_HP_RATIO: float = 0.5

var phase: int = 1

var _phase_one: Array[BossStep] = []
var _phase_two: Array[BossStep] = []
var _wait: float = INTRO_DELAY
var _step: int = 0


func _init(phase_one: Array[BossStep] = [], phase_two: Array[BossStep] = []) -> void:
	_phase_one = phase_one
	_phase_two = phase_two if not phase_two.is_empty() else phase_one


## The step to perform this tick, or null.
func tick(delta: float, hp_ratio: float) -> BossStep:
	if phase == 1 and hp_ratio <= PHASE_TWO_HP_RATIO:
		phase = 2
		_step = 0
		_wait = minf(_wait, 1.0)
	var steps := _phase_one if phase == 1 else _phase_two
	if steps.is_empty():
		return null
	_wait -= delta
	if _wait > 0.0:
		return null
	var step := steps[_step % steps.size()]
	_step += 1
	_wait += step.wait
	return step
