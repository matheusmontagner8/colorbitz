## Menu principal: Jogar, Opções e Sair.
extends Control

const BlockView = preload("res://scripts/block_view.gd")
const Fx = preload("res://scripts/fx.gd")

const TITLE := "Colorbitz"


func _ready() -> void:
	Audio.play_music("menu")
	%PlayButton.pressed.connect(GameState.go_to_level_select)
	%OptionsButton.pressed.connect(GameState.go_to_options)
	%QuitButton.pressed.connect(get_tree().quit)
	_build_title()
	_build_logo()


## Cada letra numa cor neon, pulsando em sequência.
func _build_title() -> void:
	for i in TITLE.length():
		var col := BlockView.color_of(i)
		var letter := Label.new()
		letter.text = TITLE[i]
		letter.add_theme_font_size_override("font_size", 112)
		letter.add_theme_color_override("font_color", col.lightened(0.35))
		Fx.glow_label(letter, col, 22)
		%TitleBox.add_child(letter)
		_pulse(letter, i * 0.12, 1.08)


func _build_logo() -> void:
	for i in BlockView.COLORS.size():
		var block := BlockView.new()
		block.color_index = i
		block.custom_minimum_size = Vector2(64, 64)
		%Logo.add_child(block)
		_pulse(block, 0.4 + i * 0.15, 1.12)


func _pulse(node: Control, delay: float, amount: float) -> void:
	await get_tree().process_frame  # espera o container definir o tamanho
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	var t := node.create_tween().set_loops()
	t.tween_interval(delay)
	t.tween_property(node, "scale", Vector2.ONE * amount, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_interval(maxf(0.0, 2.2 - delay))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
