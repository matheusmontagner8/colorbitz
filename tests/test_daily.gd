extends "res://tests/test_case.gd"

const Daily = preload("res://scripts/daily.gd")
const LevelLoader = preload("res://scripts/level_loader.gd")


func test_day_changes_at_midnight_in_brasilia() -> void:
	# 12/11/2026 02:59 UTC = 11/11 23:59 em Brasília; 03:00 UTC = 12/11 00:00.
	var before := Time.get_unix_time_from_datetime_string("2026-11-12T02:59:00")
	var after := Time.get_unix_time_from_datetime_string("2026-11-12T03:00:00")
	assert_eq(Daily.day_number(after) - Daily.day_number(before), 1)
	assert_eq(Daily.date_text(Daily.day_number(after)), "12/11/2026")
	assert_eq(Daily.date_text(Daily.day_number(before)), "11/11/2026")


func test_streak_rewards_cycle_every_7_days() -> void:
	for streak in range(1, 7):
		assert_eq(Daily.reward_for_streak(streak), {}, "dia %d só conta a sequência" % streak)
	assert_eq(Daily.reward_for_streak(7), {"hammer": 2, "swap": 2})
	assert_eq(Daily.reward_for_streak(8), {}, "recomeça o ciclo")
	assert_eq(Daily.reward_for_streak(14), {"hammer": 2, "swap": 2})
	assert_eq(Daily.cycle_day(14), 7)


func test_daily_level_is_the_same_for_everyone() -> void:
	var day := 20769
	assert_eq(Daily.level_for(day), Daily.level_for(day))
	var a = LevelLoader.build_session(Daily.level_for(day))
	var b = LevelLoader.build_session(Daily.level_for(day))
	assert_eq(a.board.to_rows(), b.board.to_rows(), "mesma semente, mesmo tabuleiro")
	var c = LevelLoader.build_session(Daily.level_for(day + 7))
	assert_eq(Daily.level_for(day + 7).name, Daily.level_for(day).name, "mesmo modelo na semana seguinte")
	assert_true(a.board.to_rows() != c.board.to_rows(), "outro dia, outro tabuleiro")


func test_every_template_builds_a_playable_board() -> void:
	for i in Daily.TEMPLATES.size():
		var s = LevelLoader.build_session(Daily.level_for(20769 + i))
		assert_true(s.board.has_moves(), "modelo %d" % i)
		assert_true(s.goal_target() > 0, "modelo %d tem meta" % i)


func test_reward_text() -> void:
	assert_eq(Daily.reward_text({"hammer": 1}), "+1 Martelo")
	assert_eq(Daily.reward_text({"hammer": 2, "swap": 2}), "+2 Martelo e +2 Troca")
