## Barra do baú de estrelas do modo infinito: ícone do baú, barra e "12/30".
## Na tela de resultado, anima do valor anterior até o novo (e, se o baú
## abriu, enche até o fim antes de recomeçar).
extends HBoxContainer

const BadgeIcon = preload("res://scripts/ui/badge_icon.gd")
const Fx = preload("res://scripts/fx.gd")
const Endless = preload("res://scripts/endless.gd")

const BAR_COLOR := Color("#FFD54A")

var icon: BadgeIcon
var bar: ProgressBar
var label: Label


func _init(width: float = 300.0) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon = BadgeIcon.new("chest", BAR_COLOR, 54.0)
	add_child(icon)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = Endless.CHEST_STARS
	bar.custom_minimum_size = Vector2(width, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_COLOR
	fill.set_corner_radius_all(9)
	fill.shadow_color = Color(BAR_COLOR, 0.45)
	fill.shadow_size = 6
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	label = Fx.make_label(self, 28, Color(1, 1, 1, 0.85))
	label.custom_minimum_size.x = 80


## Mostra [param stars] estrelas no baú, sem animação.
func set_stars(stars: int) -> void:
	bar.value = stars
	label.text = "%d/%d" % [stars, Endless.CHEST_STARS]


## Anima de [param from] até [param to]; [param opened] = o baú encheu no meio.
func animate(from: int, to: int, opened: bool) -> void:
	set_stars(from)
	var t := create_tween()
	t.tween_interval(0.4)
	if opened:
		t.tween_property(bar, "value", float(Endless.CHEST_STARS), 0.5)
		t.tween_callback(func():
			label.text = "%d/%d" % [Endless.CHEST_STARS, Endless.CHEST_STARS]
			_bounce_icon()
			bar.value = 0.0)
	t.tween_property(bar, "value", float(to), 0.5)
	t.tween_callback(func(): label.text = "%d/%d" % [to, Endless.CHEST_STARS])


func _bounce_icon() -> void:
	icon.pivot_offset = icon.size / 2.0
	var t := create_tween()
	t.tween_property(icon, "scale", Vector2.ONE * 1.4, 0.15).set_trans(Tween.TRANS_BACK)
	t.tween_property(icon, "scale", Vector2.ONE, 0.2)
	Audio.play_sfx("powerup")
