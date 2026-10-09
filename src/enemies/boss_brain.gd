class_name BossBrain
extends RefCounted
## Attack schedule for the Bone Warden (host only). Pure logic: tick() says which
## attack to perform; the arena turns attacks into bullet patterns.
##
## Phase 1 cycles: 3 ring bursts, a spiral, 3 aimed fans (one per player each).
## Below 50% HP it switches to phase 2: faster, with a double spiral.

enum Attack { NONE, RING, SPIRAL, DOUBLE_SPIRAL, FANS }

const INTRO_DELAY: float = 2.5
const PHASE_TWO_HP_RATIO: float = 0.5

## Each step: [attack, seconds to wait after it].
const PHASE_ONE: Array[Array] = [
	[Attack.RING, 0.7], [Attack.RING, 0.7], [Attack.RING, 1.8],
	[Attack.SPIRAL, 3.2],
	[Attack.FANS, 0.9], [Attack.FANS, 0.9], [Attack.FANS, 2.2],
]
const PHASE_TWO: Array[Array] = [
	[Attack.RING, 0.5], [Attack.RING, 0.5], [Attack.RING, 0.5], [Attack.RING, 1.4],
	[Attack.DOUBLE_SPIRAL, 3.0],
	[Attack.FANS, 0.6], [Attack.FANS, 0.6], [Attack.FANS, 0.6], [Attack.FANS, 1.6],
]

var phase: int = 1

var _wait: float = INTRO_DELAY
var _step: int = 0


## Returns the attack to perform this tick (usually NONE).
func tick(delta: float, hp_ratio: float) -> Attack:
	if phase == 1 and hp_ratio <= PHASE_TWO_HP_RATIO:
		phase = 2
		_step = 0
		_wait = minf(_wait, 1.0)
	_wait -= delta
	if _wait > 0.0:
		return Attack.NONE
	var steps := PHASE_ONE if phase == 1 else PHASE_TWO
	var step: Array = steps[_step % steps.size()]
	_step += 1
	_wait += step[1]
	return step[0]
