## Tela de resultado: título, estrelas (aparecem uma a uma, com som), pontos,
## poderes ganhos (ou, na derrota, quanto faltou para a meta), um aviso (portão de estrelas ou fase diária) e os botões.
extends "res://scripts/ui/overlay_panel.gd"

const StarsView = preload("res://scripts/ui/stars_view.gd")
const WordTiles = preload("res://scripts/ui/word_tiles.gd")
const NearMiss = preload("res://scripts/ui/near_miss.gd")
const ChestBar = preload("res://scripts/ui/chest_bar.gd")
const BadgeIcon = preload("res://scripts/ui/badge_icon.gd")

const WIN_COLOR := Color("#2BFF88")
const LOSE_COLOR := Color("#FF4FD8")
const INFO_COLOR := Color("#FFE53D")

signal next_pressed
signal retry_pressed
signal back_pressed

var title: Label
var stars: StarsView
## Derrota: quanto faltou para a meta (no lugar das estrelas).
var near_miss: NearMiss
var score_label: Label
var power_label: Label
## Aviso abaixo dos pontos: portão de estrelas ou recorde da fase diária.
var info_label: Label
## Letras de "MODO INFINITO" (só ao revelar uma letra nova).
var letters: WordTiles
## Modo infinito: estrelas no baú e a patente nova (se ganhou uma).
var chest: ChestBar
var rank_row: HBoxContainer
var next_button: Button
var back_button: Button


func _init() -> void:
	super()
	title = Fx.make_label(box, 72, Color.WHITE)
	stars = StarsView.new()
	stars.custom_minimum_size = Vector2(380, 120)
	box.add_child(stars)
	near_miss = NearMiss.new()
	near_miss.visible = false
	box.add_child(near_miss)
	score_label = Fx.make_label(box, 38, Color(1, 1, 1, 0.75))
	power_label = Fx.make_label(box, 30, WIN_COLOR)
	Fx.glow_label(power_label, WIN_COLOR, 10)
	info_label = Fx.make_label(box, 30, INFO_COLOR)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size.x = 520
	letters = WordTiles.new(56.0)
	letters.visible = false
	box.add_child(letters)
	rank_row = HBoxContainer.new()
	rank_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rank_row.add_theme_constant_override("separation", 14)
	rank_row.visible = false
	box.add_child(rank_row)
	chest = ChestBar.new()
	chest.visible = false
	box.add_child(chest)
	add_spacer(16)
	next_button = add_button("Próxima fase", func(): next_pressed.emit())
	next_button.theme_type_variation = &"AccentButton"
	add_button("Tentar de novo", func(): retry_pressed.emit())
	back_button = add_button("Fases", func(): back_pressed.emit())


## Prepara os textos (antes de [method present]).
## [param info] vazio esconde o aviso; [param power_text] vazio esconde os poderes.
func set_texts(won: bool, score_text: String, power_text: String, info: String, info_color: Color = INFO_COLOR) -> void:
	var col := WIN_COLOR if won else LOSE_COLOR
	title.text = "Vitória!" if won else "Não foi dessa vez"
	title.add_theme_color_override("font_color", col.lightened(0.3))
	Fx.glow_label(title, col, 22)
	score_label.text = score_text
	power_label.text = power_text
	power_label.visible = power_text != ""
	info_label.text = info
	info_label.visible = info != ""
	info_label.add_theme_color_override("font_color", info_color)
	stars.visible = won
	near_miss.visible = false
	chest.visible = false
	rank_row.visible = false
	letters.visible = false


## Modo infinito: anima o baú de [param from] a [param to] estrelas.
func show_chest(from: int, to: int, opened: bool) -> void:
	chest.visible = true
	chest.animate(from, to, opened)


## Patente nova: medalha grande com o nome, entrando com um pulo.
func show_rank(rank_name: String, col: Color) -> void:
	for child in rank_row.get_children():
		child.queue_free()
	var medal := BadgeIcon.new("medal", col, 96.0)
	rank_row.add_child(medal)
	var label := Fx.make_label(rank_row, 40, col.lightened(0.2))
	label.text = tr("Patente %s") % rank_name
	Fx.glow_label(label, col, 14)
	rank_row.visible = true
	rank_row.pivot_offset = Vector2(rank_row.size.x / 2.0, 48)
	rank_row.scale = Vector2.ONE * 0.2
	var t := rank_row.create_tween()
	t.tween_interval(0.5)
	t.tween_property(rank_row, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Derrota: mostra quanto faltou (GameSession.shortfall()).
func show_shortfall(shortfall: Dictionary) -> void:
	near_miss.show_for(shortfall)


## Mostra a palavra com [param revealed] letras e anima a última revelada.
func show_letters(phrase: String, revealed: int) -> void:
	letters.setup(phrase, revealed)
	letters.visible = true
	letters.pop(revealed - 1)


## Mostra a tela com fade e as estrelas aparecendo uma a uma.
func present(star_count: int) -> void:
	stars.count = 0
	modulate.a = 0.0
	visible = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	for i in star_count:
		t.tween_interval(0.3)
		t.tween_callback(func():
			stars.count = i + 1
			Audio.play_sfx("star", 1.0 + i * 0.12))
