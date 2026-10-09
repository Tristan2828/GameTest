class_name BossStep
extends Resource
## One step of a boss's attack script: fire a pattern, then wait.

enum Aim {
	## Fire at `angle` (radians).
	FIXED,
	## One volley aimed at each living player.
	AT_EACH_PLAYER,
	## Aimed at the closest living player.
	AT_NEAREST,
	## Each use turns `angle` further (rotating crosses, sweeping walls).
	SPIN,
}

## ShotPatterns.Id of the pattern to fire.
@export var pattern: int = 0
@export var aim: Aim = Aim.FIXED
@export var angle: float = 0.0
## Seconds to wait after this step before the next one.
@export var wait: float = 1.0
