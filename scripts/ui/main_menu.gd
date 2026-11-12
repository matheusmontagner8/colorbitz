## Menu principal: Jogar, Fase diária, Conquistas, Opções e Sair.
## Na primeira abertura do dia mostra a recompensa diária.
extends Control

const BlockView = preload("res://scripts/block_view.gd")
const Fx = preload("res://scripts/fx.gd")
const Daily = preload("res://scripts/daily.gd")
const PowerButton = preload("res://scripts/ui/power_button.gd")

const TITLE := "Colorbitz"
const NEON_CYAN := Color("#3DE0FF")
const NEON_PINK := Color("#FF4FD8")
const GOLD := Color("#FFE53D")

## Popup da recompensa diária (null se não houver recompensa hoje).
var reward_overlay: Control


func _ready() -> void:
	Audio.play_music("menu")
	%PlayButton.pressed.connect(GameState.go_to_level_select)
	%DailyButton.pressed.connect(GameState.play_daily)
	%AchievementsButton.pressed.connect(GameState.go_to_achievements)
	%OptionsButton.pressed.connect(GameState.go_to_options)
	%QuitButton.pressed.connect(get_tree().quit)
	_build_title()
	_build_logo()
	_update_daily_button()
	GameState.check_achievements()  # libera as que o jogador já cumpriu antes
	if GameState.progress.can_claim_daily(GameState.today()):
		_build_reward_overlay()


func _update_daily_button() -> void:
	var day: int = GameState.today()
	if GameState.progress.daily_won_today(day):
		%DailyButton.text = "Fase diária (vencida)"
	else:
		%DailyButton.text = "Fase diária: %s" % Daily.level_for(day).name


# --- Recompensa diária ----------------------------------------------------------

func _build_reward_overlay() -> void:
	var day: int = GameState.today()
	var streak: int = GameState.progress.streak_if_claimed(day)
	var reward := Daily.reward_for_streak(streak)
	reward_overlay = ColorRect.new()
	reward_overlay.color = Color(0.01, 0.015, 0.06, 0.96)
	reward_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(reward_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	reward_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)
	var title := _label(box, 60, NEON_CYAN)
	title.text = "Recompensa diária"
	Fx.glow_label(title, NEON_CYAN, 18)
	var sub := _label(box, 34, GOLD)
	sub.text = "Primeiro dia!" if streak == 1 else "%d dias seguidos!" % streak
	box.add_child(_build_streak_row(Daily.cycle_day(streak)))
	var prize_day := not reward.is_empty()
	var hint := _label(box, 28, Color(1, 1, 1, 0.75))
	var left: int = Daily.STREAK_CYCLE - Daily.cycle_day(streak)
	if prize_day:
		hint.text = "Prêmio do 7º dia seguido!"
		hint.add_theme_color_override("font_color", GOLD)
	elif left == 1:
		hint.text = "Volte amanhã para ganhar o prêmio:"
	else:
		hint.text = "Volte todo dia! Faltam %d dias\npara o prêmio:" % left
	var powers := HBoxContainer.new()
	powers.alignment = BoxContainer.ALIGNMENT_CENTER
	powers.add_theme_constant_override("separation", 24)
	box.add_child(powers)
	for p in Daily.STREAK_REWARD:
		var pb := PowerButton.new()
		pb.power = p
		pb.count = int(Daily.STREAK_REWARD[p])
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		powers.add_child(pb)
		if prize_day:
			_pulse(pb, 0.0, 1.08)
		else:
			pb.modulate.a = 0.45  # prêmio ainda por vir
	var take := Button.new()
	take.text = "Pegar!" if prize_day else "Continuar"
	take.theme_type_variation = &"AccentButton"
	take.custom_minimum_size = Vector2(440, 116)
	take.pressed.connect(_claim_reward)
	box.add_child(take)


## Sete casinhas: dias já resgatados no ciclo, o de hoje em destaque e o 7º dourado.
func _build_streak_row(today_slot: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in range(1, Daily.STREAK_CYCLE + 1):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(76, 92)
		var col := GOLD if i == Daily.STREAK_CYCLE else NEON_CYAN
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(4 if i == today_slot else 2)
		if i < today_slot:
			sb.bg_color = Color(col, 0.35)
			sb.border_color = Color(col, 0.7)
		elif i == today_slot:
			sb.bg_color = Color(NEON_PINK, 0.3)
			sb.border_color = NEON_PINK
			sb.shadow_color = Color(NEON_PINK, 0.5)
			sb.shadow_size = 12
		else:
			sb.bg_color = Color(0.08, 0.1, 0.22, 0.9)
			sb.border_color = Color(col, 0.35)
		slot.add_theme_stylebox_override("panel", sb)
		var n := Label.new()
		n.text = str(i)
		n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.add_theme_font_size_override("font_size", 38)
		n.add_theme_color_override("font_color", Color.WHITE if i <= today_slot else Color(1, 1, 1, 0.45))
		slot.add_child(n)
		row.add_child(slot)
	return row


func _claim_reward() -> void:
	if reward_overlay == null:
		return
	var reward: Dictionary = GameState.claim_daily_reward()
	if not reward.is_empty():
		Audio.play_sfx("win")
		GameState.vibrate(60)
	var t := reward_overlay.create_tween()
	t.tween_property(reward_overlay, "modulate:a", 0.0, 0.25)
	t.tween_callback(reward_overlay.queue_free)
	reward_overlay = null


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


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
		if reward_overlay:
			_claim_reward()
		else:
			get_tree().quit()
