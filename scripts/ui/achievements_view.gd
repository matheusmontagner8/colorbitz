## Tela de conquistas: lista com troféu, descrição, progresso e prêmio.
extends Control

const Achievements = preload("res://scripts/achievements.gd")
const Daily = preload("res://scripts/daily.gd")

const GOLD := Color("#FFE53D")
const DONE_COLOR := Color("#2BFF88")
const LOCKED_COLOR := Color(0.42, 0.47, 0.66)
const BAR_COLOR := Color("#3DE0FF")


func _ready() -> void:
	Audio.play_music("menu")
	%BackButton.pressed.connect(GameState.go_to_menu)
	var progress = GameState.progress
	var done := 0
	for a in Achievements.LIST:
		var unlocked: bool = progress.has_achievement(a.id)
		done += 1 if unlocked else 0
		%List.add_child(_row(a, unlocked, mini(progress.stat_value(a.stat), int(a.goal))))
	%StarsLabel.text = "%d de %d conquistas" % [done, Achievements.LIST.size()]


func _row(a: Dictionary, unlocked: bool, value: int) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.content_margin_left = 20
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	sb.bg_color = Color(0.06, 0.08, 0.2, 0.92) if unlocked else Color(0.04, 0.05, 0.12, 0.85)
	sb.border_color = Color(GOLD, 0.8) if unlocked else Color(LOCKED_COLOR, 0.35)
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	row.add_child(_trophy(GOLD if unlocked else LOCKED_COLOR))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)
	var title := _label(texts, 34, GOLD if unlocked else Color(1, 1, 1, 0.85))
	title.text = a.title
	var desc := _label(texts, 24, Color(1, 1, 1, 0.65))
	desc.text = a.desc
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var goal := int(a.goal)
	if unlocked:
		var ok := _label(texts, 24, DONE_COLOR)
		ok.text = "Concluída! (%s)" % Daily.reward_text(a.reward)
	else:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		texts.add_child(line)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = goal
		bar.value = value
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.1)
		bg.set_corner_radius_all(8)
		var fill := StyleBoxFlat.new()
		fill.bg_color = BAR_COLOR
		fill.set_corner_radius_all(8)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		line.add_child(bar)
		var count := _label(line, 24, Color(1, 1, 1, 0.75))
		count.text = "%d/%d" % [value, goal]
		var prize := _label(texts, 22, Color(DONE_COLOR, 0.7))
		prize.text = "Prêmio: %s" % Daily.reward_text(a.reward)
	return panel


## Troféu desenhado (taça, alças e base), para não depender de emoji na fonte.
func _trophy(col: Color) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func():
		var c := icon.size / 2.0
		icon.draw_circle(c, 36, Color(col, 0.14))
		var cup := PackedVector2Array([c + Vector2(-20, -24), c + Vector2(20, -24), c + Vector2(14, 0), c + Vector2(0, 8), c + Vector2(-14, 0)])
		icon.draw_colored_polygon(cup, col)
		for side in [-1, 1]:
			icon.draw_arc(c + Vector2(20 * side, -14), 9, -PI / 2 if side == 1 else PI / 2, PI / 2 if side == 1 else PI * 1.5, 10, col, 4.0, true)
		icon.draw_rect(Rect2(c + Vector2(-4, 6), Vector2(8, 12)), col)
		icon.draw_rect(Rect2(c + Vector2(-16, 18), Vector2(32, 8)), col))
	return icon


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go_to_menu()
