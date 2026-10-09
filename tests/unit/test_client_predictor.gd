extends GutTest


func _predictor_with_history() -> ClientPredictor:
	var predictor := ClientPredictor.new()
	for seq: int in range(1, 6):
		predictor.record(seq, Vector2(seq * 10, 0))
	return predictor


func test_matching_server_state_needs_no_correction() -> void:
	var predictor := _predictor_with_history()
	assert_eq(predictor.reconcile(2, Vector2(20, 0)), Vector2.ZERO)


func test_returns_error_when_prediction_was_wrong() -> void:
	var predictor := _predictor_with_history()
	assert_eq(predictor.reconcile(2, Vector2(23, 4)), Vector2(3, 4))


func test_later_predictions_are_shifted_by_the_error() -> void:
	var predictor := _predictor_with_history()
	predictor.reconcile(2, Vector2(23, 4))
	# Seq 4 was predicted at (40, 0) but is now known to be (43, 4).
	assert_eq(predictor.reconcile(4, Vector2(43, 4)), Vector2.ZERO)


func test_acknowledged_history_is_dropped() -> void:
	var predictor := _predictor_with_history()
	predictor.reconcile(3, Vector2(30, 0))
	assert_eq(predictor.history_size(), 2)


func test_unknown_sequence_is_ignored() -> void:
	var predictor := _predictor_with_history()
	assert_eq(predictor.reconcile(99, Vector2(500, 500)), Vector2.ZERO)


func test_tiny_errors_are_ignored() -> void:
	var predictor := _predictor_with_history()
	assert_eq(predictor.reconcile(1, Vector2(10.1, 0)), Vector2.ZERO)


func test_history_is_capped() -> void:
	var predictor := ClientPredictor.new()
	for seq: int in ClientPredictor.MAX_HISTORY * 2:
		predictor.record(seq, Vector2.ZERO)
	assert_eq(predictor.history_size(), ClientPredictor.MAX_HISTORY)
