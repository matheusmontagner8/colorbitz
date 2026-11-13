## Palavra do modo infinito em quadrados neon ("MODO" / "INFINITO"): as letras
## reveladas acendem, cada uma numa cor; as outras aparecem apagadas com "?".
## Cada fase múltipla de 5 da campanha revela uma letra (veja Endless).
extends VBoxContainer

const BlockView = preload("res://scripts/block_view.gd")
const Fx = preload("res://scripts/fx.gd")

const HIDDEN_COLOR := Color(0.35, 0.4, 0.6)

var tile_size := 52.0
## Quadrados na ordem das letras (sem os espaços).
var tiles: Array[PanelContainer] = []


func _init(size_px: float = 52.0) -> void:
	tile_size = size_px
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Monta a frase (cada palavra numa linha) com [param revealed] letras acesas.
func setup(phrase: String, revealed: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	tiles.clear()
	for word in phrase.split(" ", false):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		for letter in word:
			var i := tiles.size()
			var tile := _tile(letter, i, i < revealed)
			row.add_child(tile)
			tiles.append(tile)


## Animação da letra recém-revelada: cresce, gira um pouco e brilha.
func pop(index: int) -> void:
	if index < 0 or index >= tiles.size():
		return
	var tile := tiles[index]
	await get_tree().process_frame  # espera o container definir o tamanho
	if not is_instance_valid(tile):
		return
	tile.pivot_offset = tile.size / 2.0
	tile.scale = Vector2.ONE * 0.2
	tile.rotation = -0.5
	var t := tile.create_tween().set_parallel(true)
	t.tween_property(tile, "scale", Vector2.ONE * 1.25, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(tile, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(tile, "scale", Vector2.ONE, 0.2)
	Audio.play_sfx("powerup")


func _tile(letter: String, index: int, lit: bool) -> PanelContainer:
	var col: Color = BlockView.COLORS[index % BlockView.COLORS.size()] if lit else HIDDEN_COLOR
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(tile_size, tile_size)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(tile_size * 0.22))
	sb.set_border_width_all(3)
	sb.border_color = col if lit else Color(col, 0.45)
	sb.bg_color = Color(col.darkened(0.6), 0.9) if lit else Color(0.04, 0.05, 0.12, 0.8)
	if lit:
		sb.shadow_color = Color(col, 0.45)
		sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # letra solta, não é texto
	label.text = letter if lit else "?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(tile_size * 0.62))
	label.add_theme_color_override("font_color", col.lightened(0.45) if lit else Color(col, 0.6))
	if lit:
		Fx.glow_label(label, col, 8)
	panel.add_child(label)
	return panel
