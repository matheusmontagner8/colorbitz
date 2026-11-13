## Cartão de apresentação (veja scripts/intros.gd): escurece a tela e mostra
## desenho, título e explicação com letra grande. Só fecha no "Entendi!", para
## ninguém pular sem querer. Bloqueia toques no jogo enquanto está aberto.
extends "res://scripts/ui/overlay_panel.gd"

const BlockView = preload("res://scripts/block_view.gd")
const BadgeIcon = preload("res://scripts/ui/badge_icon.gd")
const Intros = preload("res://scripts/intros.gd")

const ICON_SIZE := 104.0

signal closed(id: String)

var id := ""
var title_label: Label
var text_label: Label
var _icons: HBoxContainer


func _init() -> void:
	super()
	color.a = 0.9
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.14, 0.98)
	sb.border_color = NEON_CYAN
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(32)
	sb.shadow_color = Color(NEON_CYAN, 0.3)
	sb.shadow_size = 18
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", sb)
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 26)
	panel.add_child(inner)
	title_label = Fx.make_label(inner, 56, NEON_CYAN.lightened(0.3))
	Fx.glow_label(title_label, NEON_CYAN, 16)
	_icons = HBoxContainer.new()
	_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	_icons.add_theme_constant_override("separation", 14)
	inner.add_child(_icons)
	text_label = Fx.make_label(inner, 31, Color.WHITE)
	var ok := Button.new()
	ok.text = "Entendi!"
	ok.theme_type_variation = &"AccentButton"
	ok.custom_minimum_size = Vector2(440, 116)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_close)
	inner.add_child(ok)


## Abre o cartão [param card_id]. [param goal_colors]: cores da meta da fase
## (para o ícone "goal"); [param arg]: valor do "%d" do texto, se houver.
func open(card_id: String, goal_colors: Array = [], arg: int = 0) -> void:
	id = card_id
	var card: Dictionary = Intros.CARDS[card_id]
	title_label.text = card.title
	var text: String = tr(card.text)
	text_label.text = text % arg if text.contains("%d") else text
	for child in _icons.get_children():
		child.queue_free()
	for icon in card.icon:
		if icon is String and icon == "goal":
			for c in goal_colors:
				_add_block(c, 0)
		elif icon is String and icon == "hole":
			_add_hole()
		elif icon is String and icon in ["chest", "crown", "medal"]:
			_icons.add_child(BadgeIcon.new(icon, BadgeIcon.GOLD, ICON_SIZE))
		elif icon is String and icon == "flame":
			_icons.add_child(BadgeIcon.new(icon, BadgeIcon.FLAME, ICON_SIZE))
		elif icon is String:  # "ice" / "ice2": bloco congelado
			_add_block(0, 2 if icon == "ice2" else 1)
		else:
			_add_block(int(icon), 0)
	modulate.a = 0.0
	visible = true
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	Audio.play_sfx("powerup")


func _add_block(color_index: int, ice: int) -> void:
	var block := BlockView.new()
	block.color_index = color_index
	block.ice = ice
	block.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.add_child(block)


func _add_hole() -> void:
	var hole := Panel.new()
	hole.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.008, 0.012, 0.035)
	sb.border_color = Color(NEON_CYAN, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	hole.add_theme_stylebox_override("panel", sb)
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.add_child(hole)


func _close() -> void:
	visible = false
	closed.emit(id)
