## Tela de derrota: mostra quanto faltou para a meta ("Faltou: 120 pontos",
## ou o bloco da cor/joia com o número) e uma barra com quanto da meta foi
## feito. Ver que chegou perto anima a tentar de novo.
## Recebe o dicionário de GameSession.shortfall().
extends VBoxContainer

const BlockView = preload("res://scripts/block_view.gd")
const Fx = preload("res://scripts/fx.gd")

## A partir desta fração da meta, a derrota conta como "quase".
const CLOSE_FRACTION := 0.8
const CLOSE_COLOR := Color("#FFE53D")
const BAR_COLOR := Color("#3DE0FF")
const NO_ICON := -1

var header: Label
var row: HBoxContainer
var bar: ProgressBar
var percent: Label

var _fill := StyleBoxFlat.new()


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(440, 22)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(11)
	_fill.set_corner_radius_all(11)
	_fill.shadow_size = 8
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", _fill)
	add_child(bar)
	percent = Fx.make_label(self, 26, Color(1, 1, 1, 0.65))


## Monta o texto e anima a barra até a fração da meta cumprida.
func show_for(shortfall: Dictionary) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var fraction: float = shortfall.get("fraction", 0.0)
	var close := fraction >= CLOSE_FRACTION
	header = Fx.make_label(row, 36, CLOSE_COLOR if close else Color.WHITE)
	header.text = "Quase! Faltou:" if close else "Faltou:"
	if close:
		Fx.glow_label(header, CLOSE_COLOR, 12)
	for part in shortfall.get("parts", []):
		var n: int = part.missing
		if int(part.icon) == NO_ICON:
			var text := Fx.make_label(row, 36, Color.WHITE)
			if shortfall.get("type", "") == "clear":
				text.text = tr("estourar 1 bloco") if n == 1 else tr("estourar %d blocos") % n
			else:
				text.text = tr("%d pontos") % n
		else:
			var chip := BlockView.new()
			chip.color_index = int(part.icon)
			chip.custom_minimum_size = Vector2(52, 52)
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(chip)
			Fx.make_label(row, 36, Color.WHITE).text = str(n)
	var col := CLOSE_COLOR if close else BAR_COLOR
	_fill.bg_color = col
	_fill.shadow_color = Color(col, 0.45)
	percent.text = tr("Você fez %d%% da meta") % roundi(fraction * 100.0)
	bar.value = 0.0
	visible = true
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_property(bar, "value", fraction * 100.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
