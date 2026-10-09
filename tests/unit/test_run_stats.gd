extends GutTest


func test_add_and_total() -> void:
	var stats := RunStats.new()
	stats.add(1, RunStats.Stat.KILLS, 5)
	stats.add(1, RunStats.Stat.KILLS, 2)
	stats.add(7, RunStats.Stat.KILLS, 4)
	assert_eq(stats.get_stat(1, RunStats.Stat.KILLS), 7)
	assert_eq(stats.get_stat(99, RunStats.Stat.KILLS), 0)
	assert_eq(stats.total(RunStats.Stat.KILLS), 11)
	stats.set_stat(7, RunStats.Stat.DAMAGE, 300)
	assert_eq(stats.get_stat(7, RunStats.Stat.DAMAGE), 300)


func test_every_stat_has_a_label() -> void:
	assert_eq(RunStats.STAT_LABELS.size(), RunStats.Stat.size())


func test_encode_decode_round_trip() -> void:
	var stats := RunStats.new()
	stats.add(1, RunStats.Stat.DAMAGE, 1234)
	stats.add(55, RunStats.Stat.DOWNS, 2)
	stats.run_seconds = 312.5
	stats.stage_reached = 2
	stats.team_level = 9
	stats.bosses_defeated = 1
	stats.fell_to = "The Mire Hag"
	var copy := RunStats.decode(stats.encode())
	assert_eq(copy.get_stat(1, RunStats.Stat.DAMAGE), 1234)
	assert_eq(copy.get_stat(55, RunStats.Stat.DOWNS), 2)
	assert_almost_eq(copy.run_seconds, 312.5, 0.01)
	assert_eq(copy.stage_reached, 2)
	assert_eq(copy.team_level, 9)
	assert_eq(copy.bosses_defeated, 1)
	assert_eq(copy.fell_to, "The Mire Hag")
	assert_false(copy.victory)


func test_awards_only_in_coop_and_not_on_ties() -> void:
	var solo := RunStats.new()
	solo.add(1, RunStats.Stat.DAMAGE, 500)
	assert_eq(solo.awards_for(1).size(), 0)
	var coop := RunStats.new()
	coop.add(1, RunStats.Stat.DAMAGE, 500)
	coop.add(2, RunStats.Stat.DAMAGE, 300)
	coop.add(1, RunStats.Stat.KILLS, 10)
	coop.add(2, RunStats.Stat.KILLS, 10)
	assert_has(coop.awards_for(1), "Most damage")
	assert_does_not_have(coop.awards_for(1), "Most kills")
	assert_does_not_have(coop.awards_for(2), "Most kills")


func test_format_time() -> void:
	assert_eq(RunStats.format_time(0.0), "0:00")
	assert_eq(RunStats.format_time(245.9), "4:05")
	assert_eq(RunStats.format_time(3723.0), "1:02:03")
