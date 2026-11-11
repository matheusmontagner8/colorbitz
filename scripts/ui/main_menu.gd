## Menu principal: Jogar, Opções e Sair.
extends Control

const BlockView = preload("res://scripts/block_view.gd")


func _ready() -> void:
	%PlayButton.pressed.connect(GameState.go_to_level_select)
	%OptionsButton.pressed.connect(GameState.go_to_options)
	%QuitButton.pressed.connect(get_tree().quit)
	for i in 4:
		var block := BlockView.new()
		block.color_index = i
		block.custom_minimum_size = Vector2(84, 84)
		%Logo.add_child(block)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
