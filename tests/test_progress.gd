extends "res://tests/test_case.gd"

const Progress = preload("res://scripts/progress.gd")

const TEST_PATH := "user://test_progress.json"
const LEVELS := [{"id": 1}, {"id": 2}, {"id": 3}]


func _cleanup() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_only_first_level_unlocked_at_start() -> void:
	var p := Progress.new()
	assert_true(p.is_unlocked(0, LEVELS))
	assert_false(p.is_unlocked(1, LEVELS))
	assert_false(p.is_unlocked(3, LEVELS), "índice fora da lista")


func test_winning_unlocks_next_level() -> void:
	var p := Progress.new()
	p.record_result(1, 1)
	assert_true(p.is_unlocked(1, LEVELS))
	assert_false(p.is_unlocked(2, LEVELS))


func test_float_and_int_ids_are_the_same_level() -> void:
	var p := Progress.new()
	p.record_result(1, 2)
	assert_eq(p.stars_for(1.0), 2, "id do JSON vem como float")
	p.record_result(2.0, 3)
	assert_eq(p.stars_for(2), 3)
	var json_levels: Array = JSON.parse_string('[{"id": 1}, {"id": 2}, {"id": 3}]')
	assert_true(p.is_unlocked(2, json_levels))
	assert_eq(p.to_dict().stars.keys(), ["1", "2"])


func test_keeps_best_stars() -> void:
	var p := Progress.new()
	assert_true(p.record_result(1, 2))
	assert_false(p.record_result(1, 1), "resultado pior não substitui")
	assert_eq(p.stars_for(1), 2)
	assert_true(p.record_result(1, 3))
	assert_eq(p.stars_for(1), 3)
	p.record_result(2, 1)
	assert_eq(p.total_stars(), 4)


func test_save_and_load_roundtrip() -> void:
	_cleanup()
	var p := Progress.new()
	p.record_result(1, 3)
	p.record_result(2, 1)
	p.music_on = false
	assert_eq(p.save_to(TEST_PATH), OK)
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "temporário removido")

	var loaded := Progress.new()
	assert_true(loaded.load_from(TEST_PATH))
	assert_eq(loaded.stars_for(1), 3)
	assert_eq(loaded.stars_for(2), 1)
	assert_true(loaded.sound_on)
	assert_false(loaded.music_on)
	assert_true(loaded.is_unlocked(2, LEVELS))

	assert_eq(p.save_to(TEST_PATH), OK, "sobrescrever save existente")
	_cleanup()


func test_missing_save_starts_fresh() -> void:
	_cleanup()
	var p := Progress.new()
	assert_false(p.load_from(TEST_PATH))
	assert_eq(p.total_stars(), 0)
	assert_true(p.sound_on)


func test_corrupted_save_starts_fresh() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{isso não é json")
	f.close()
	var p := Progress.new()
	p.record_result(1, 3)
	assert_false(p.load_from(TEST_PATH))
	assert_eq(p.total_stars(), 0, "estado anterior é descartado")
	_cleanup()


func test_from_dict_sanitizes_values() -> void:
	var p := Progress.new()
	p.from_dict({"stars": {"1": 7.0, "2": -1}, "settings": "lixo"})
	assert_eq(p.stars_for(1), 3)
	assert_eq(p.stars_for(2), 0)
	assert_true(p.music_on)
