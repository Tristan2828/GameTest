class_name ClientPredictor
extends RefCounted
## Bookkeeping for client-side prediction of the local player.
##
## Each tick the client remembers where it predicted itself to be after input #N.
## When a host snapshot says "after input #N you were at X", we compare. If they
## differ, that error is returned so the player can shift itself, and every
## later prediction (built on the wrong starting point) is shifted by it too.

## Ignore differences smaller than this (pixels). Tiny float noise isn't worth fixing.
const MIN_ERROR: float = 0.25
## Errors at least this big are snapped instead of smoothed.
const SNAP_DISTANCE: float = 64.0
const MAX_HISTORY: int = 180

var _history: Dictionary[int, Vector2] = {}


func record(seq: int, predicted_position: Vector2) -> void:
	_history[seq] = predicted_position
	_history.erase(seq - MAX_HISTORY)


## Returns how far off our prediction for `ack_seq` was (zero if close enough).
func reconcile(ack_seq: int, server_position: Vector2) -> Vector2:
	if not _history.has(ack_seq):
		return Vector2.ZERO
	var error := server_position - _history[ack_seq]
	for seq: int in _history.keys():
		if seq <= ack_seq:
			_history.erase(seq)
	if error.length() < MIN_ERROR:
		return Vector2.ZERO
	for seq: int in _history.keys():
		_history[seq] += error
	return error


func history_size() -> int:
	return _history.size()
