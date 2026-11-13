## Itens de publicação: versão, backup do Android e área segura da tela.
extends "res://tests/test_case.gd"

const SafeArea = preload("res://scripts/safe_area.gd")

const CANVAS := Vector2(720, 1600)  # tela 9:20 com "expand": mais alta que 1280


func _android_options() -> ConfigFile:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	return cfg


func test_version_matches_android_export() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	assert_true(version.split(".").size() == 3, "versão no formato 1.2.3: %s" % version)
	var cfg := _android_options()
	assert_eq(str(cfg.get_value("preset.0.options", "version/name")), version, "export usa a mesma versão")
	assert_true(int(cfg.get_value("preset.0.options", "version/code")) >= 2)


func test_android_backup_allowed() -> void:
	var cfg := _android_options()
	assert_true(cfg.get_value("preset.0.options", "user_data_backup/allow", false),
		"save vai junto no backup do Android (troca de celular)")


func test_safe_area_without_cutout_is_zero() -> void:
	var window := Vector2(1080, 2400)
	var m := SafeArea.insets(window, Rect2(Vector2.ZERO, window), CANVAS)
	assert_eq([m.left, m.top, m.right, m.bottom], [0.0, 0.0, 0.0, 0.0])
	m = SafeArea.insets(Vector2.ZERO, Rect2(), CANVAS)
	assert_eq(m.top, 0.0, "sem janela: zero")


func test_safe_area_converts_pixels_to_game_units() -> void:
	# Entalhe de 120 px em cima e barra de gestos de 60 px embaixo, numa tela
	# de 1080x2400 desenhada como 720x1600 (fator 2/3).
	var m := SafeArea.insets(Vector2(1080, 2400), Rect2(0, 120, 1080, 2400 - 120 - 60), CANVAS)
	assert_eq(m.top, 80.0)
	assert_eq(m.bottom, 40.0)
	assert_eq(m.left, 0.0)
	assert_eq(m.right, 0.0)


func test_safe_area_is_limited() -> void:
	var m := SafeArea.insets(Vector2(1080, 2400), Rect2(0, 1500, 1080, 100), CANVAS)
	assert_eq(m.top, CANVAS.y * SafeArea.MAX_FRACTION, "valor estranho do aparelho fica limitado")


func test_safe_area_shrinks_control() -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	SafeArea.apply(c, {"left": 10.0, "top": 80.0, "right": 20.0, "bottom": 40.0})
	assert_eq([c.offset_left, c.offset_top, c.offset_right, c.offset_bottom], [10.0, 80.0, -20.0, -40.0])
	c.free()
