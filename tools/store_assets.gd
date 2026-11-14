## Gera os materiais da página da Google Play em store/<idioma>/:
##   feature_graphic.png        banner 1024x500
##   screenshot_1..8.png        capturas 1080x1920 (telas reais do jogo, com legenda)
## As telas são desenhadas numa SubViewport de 1080x1920 que mostra a tela do
## jogo (720x1280) ampliada, para sair em alta resolução em qualquer monitor.
## Não altera o save do jogador. Uso (precisa de janela, não use --headless):
##   godot --path . -s tools/store_assets.gd
extends SceneTree

const Progress = preload("res://scripts/progress.gd")
const Intros = preload("res://scripts/intros.gd")
const BlockView = preload("res://scripts/block_view.gd")
const Fx = preload("res://scripts/fx.gd")
const I18n = preload("res://scripts/i18n.gd")
const NeonBackground = preload("res://scripts/ui/neon_background.gd")

const OUT_DIR := "res://store/"
const GAME_SIZE := Vector2i(720, 1280)
const SHOT_SIZE := Vector2i(1080, 1920)
const FEATURE_SIZE := Vector2i(1024, 500)
const DEMO_DAY := 20769
const CAPTION_COLOR := Color("#3DE0FF")

## Pasta da loja -> idioma do jogo.
const LANGUAGES := {"pt-BR": "pt", "en-US": "en"}

## Legendas das capturas (em português; traduzidas por CAPTIONS_EN).
const CAPTIONS := [
	"Toque em grupos de blocos\nda mesma cor",
	"Grupos grandes viram bombas!",
	"Gelo, pedras, joias e coringas",
	"Um desafio novo todo dia",
	"Modo para daltônicos",
	"Modo infinito com fases chefe",
	"Ganhe patentes, baús e poderes",
	"60 fases + modo infinito",
]
const CAPTIONS_EN := [
	"Tap groups of blocks\nof the same color",
	"Big groups turn into bombs!",
	"Ice, stones, gems and wild blocks",
	"A new challenge every day",
	"Colorblind-friendly mode",
	"Infinite mode with boss levels",
	"Earn ranks, chests and powers",
	"60 levels + infinite mode",
]
const TAGLINE := {"pt": "Puzzle neon de estourar blocos", "en": "Neon block-popping puzzle"}

var _gs: Node
var _vp: SubViewport
var _scene: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_gs.save_enabled = false
	await _frames(1)
	_vp = SubViewport.new()
	_vp.size = SHOT_SIZE
	_vp.size_2d_override = GAME_SIZE
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_vp.add_child(NeonBackground.new())
	for folder in LANGUAGES:
		var lang: String = LANGUAGES[folder]
		I18n.apply(lang)
		TranslationServer.set_locale(lang)
		await _screenshots(OUT_DIR + folder + "/", lang)
		await _feature_graphic(OUT_DIR + folder + "/feature_graphic.png", lang)
	print("materiais da loja: ok")
	quit()


## Progresso de demonstração: campanha quase toda com 2 e 3 estrelas e o
## modo infinito até a fase 69 (a 70 é o chefe da captura).
func _demo_progress():
	var demo = Progress.new()
	for n in range(1, 70):
		demo.record_result(n, 3 if n % 3 != 0 else 2)
	demo.daily_claim_day = DEMO_DAY
	demo.powers_bonus = {"hammer": 4, "swap": 3}
	demo.tutorials = {"powers": true}
	for id in Intros.CARDS:
		Intros.mark_seen(id, demo)
	return demo


func _screenshots(dir: String, lang: String) -> void:
	_gs.progress = _demo_progress()
	_gs.progress.language = lang
	_gs.day_override = DEMO_DAY
	_gs.daily_mode = false
	_gs.apply_settings()
	var captions: Array = CAPTIONS if lang == "pt" else CAPTIONS_EN

	# 1. Jogo no meio da fase, com alguns grupos já estourados.
	var game = await _open_game(11)
	await _tap_groups(game, 2)
	await create_timer(1.0).timeout
	await _capture(dir + "screenshot_1.png", captions[0])

	# 2. Bomba recém-criada por um grupo grande.
	game._session.goal = {"type": "score", "target": 3500}
	game._session.board.load_rows([
		"1234512", "2345123", "3451234", "4512345", "5123451",
		"1200002", "2300003", "3400004", "4512345",
	])
	game._hud.build_goal_row(game._session)
	game._rebuild_blocks()
	game._update_hud()
	await _frames(3)
	_tap(game, Vector2i(3, 6))
	await create_timer(1.1).timeout
	await _capture(dir + "screenshot_2.png", captions[1])

	# 3. Peças especiais: joia, coringa, pedra e gelo.
	game = await _open_game(59)
	game._session.goal = {"type": "drop", "count": 3}
	game._session.board.load_rows([
		"0123401", "1234012", "2W40123", "3401234", "4S12340",
		"0123401", "123G012", "2341123", "3401234",
	])
	game._session.board.set_ice(2, 8, 2)
	game._session.board.set_ice(5, 3, 1)
	game._hud.build_goal_row(game._session)
	game._rebuild_blocks()
	game._update_hud()
	await _frames(3)
	await _capture(dir + "screenshot_3.png", captions[2])

	# 4. Fase diária.
	_gs.start_daily()
	game = await _open_scene("res://scenes/game.tscn")
	await _capture(dir + "screenshot_4.png", captions[3])
	_gs.daily_mode = false

	# 5. Modo daltônico.
	_gs.progress.colorblind = true
	_gs.apply_settings()
	game = await _open_game(40)
	await _capture(dir + "screenshot_5.png", captions[4])
	_gs.progress.colorblind = false
	_gs.apply_settings()

	# 6. Fase chefe (70) e 7. vitória com patente e baú.
	game = await _open_game(69)
	await _capture(dir + "screenshot_6.png", captions[5])
	game._session.status = game.GameSession.Status.WON
	game._session.moves_left = game._session.max_moves
	game._finish()
	await create_timer(5.0).timeout
	await _capture(dir + "screenshot_7.png", captions[6])

	# 8. Tela de fases rolada até o fim (palavra completa e modo infinito).
	var select = await _open_scene("res://scenes/level_select.tscn")
	var scroll: ScrollContainer = select.get_node("%Scroll")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(3)
	await _capture(dir + "screenshot_8.png", captions[7])
	_close_scene()


func _open_game(index: int) -> Node:
	_gs.daily_mode = false
	_gs.current_index = index
	return await _open_scene("res://scenes/game.tscn")


func _open_scene(path: String) -> Node:
	_close_scene()
	paused = false
	_scene = load(path).instantiate()
	_vp.add_child(_scene)
	await create_timer(0.7).timeout
	return _scene


func _close_scene() -> void:
	if _scene and is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null


## Captura a tela atual e monta a imagem da loja: legenda em cima e a tela
## do jogo embaixo, um pouco menor, com borda neon.
func _capture(out: String, caption: String) -> void:
	await RenderingServer.frame_post_draw
	var screen := _vp.get_texture().get_image()
	var frame := Control.new()
	frame.size = Vector2(GAME_SIZE)
	var bg := ColorRect.new()  # cobre a tela do jogo (o fundo neon fica por baixo)
	bg.color = Color(0, 0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(bg)
	var label := Label.new()
	label.text = caption
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # legenda longa quebra a linha
	label.add_theme_font_size_override("font_size", 50)
	label.add_theme_color_override("font_color", Color.WHITE)
	Fx.glow_label(label, CAPTION_COLOR, 16)
	label.position = Vector2(20, 24)
	label.size = Vector2(GAME_SIZE.x - 40, 170)
	var shot_scale := 0.8
	var shot_size := Vector2(GAME_SIZE) * shot_scale
	var shot_pos := Vector2((GAME_SIZE.x - shot_size.x) / 2.0, GAME_SIZE.y - shot_size.y - 30)
	var border := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.BLACK
	sb.border_color = CAPTION_COLOR
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(CAPTION_COLOR, 0.4)
	sb.shadow_size = 18
	border.add_theme_stylebox_override("panel", sb)
	border.position = shot_pos - Vector2(8, 8)
	border.size = shot_size + Vector2(16, 16)
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(screen)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.position = shot_pos
	tex.size = shot_size
	if _scene:
		_scene.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(frame)
	frame.add_child(border)
	frame.add_child(tex)
	frame.add_child(label)
	_vp.add_child(layer)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)  # a Play não aceita transparência
	assert(img.get_size() == SHOT_SIZE, "%s: %s" % [out, img.get_size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	img.save_png(out)
	print("salvo %s" % out)
	layer.queue_free()
	if _scene:
		_scene.visible = true
	await _frames(1)


## Banner 1024x500: título com uma cor por letra, fileira de blocos e frase.
func _feature_graphic(out: String, lang: String) -> void:
	var vp := SubViewport.new()
	vp.size = FEATURE_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(NeonBackground.new())
	var center := CenterContainer.new()
	center.size = Vector2(FEATURE_SIZE)
	vp.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var blocks := HBoxContainer.new()
	blocks.alignment = BoxContainer.ALIGNMENT_CENTER
	blocks.add_theme_constant_override("separation", 14)
	box.add_child(blocks)
	for i in BlockView.COLORS.size():
		var block := BlockView.new()
		block.color_index = i
		block.custom_minimum_size = Vector2(70, 70)
		blocks.add_child(block)
	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 2)
	box.add_child(title)
	var word := "Colorbitz"
	for i in word.length():
		var col := BlockView.color_of(i)
		var letter := Label.new()
		letter.text = word[i]
		letter.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		letter.add_theme_font_size_override("font_size", 150)
		letter.add_theme_color_override("font_color", col.lightened(0.35))
		Fx.glow_label(letter, col, 24)
		title.add_child(letter)
	var tagline := Fx.make_label(box, 44, Color(1, 1, 1, 0.9))
	tagline.text = TAGLINE[lang]
	tagline.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	assert(img.get_size() == FEATURE_SIZE)
	img.save_png(out)
	print("salvo %s" % out)
	vp.queue_free()


func _tap_groups(game, n: int) -> void:
	var taps := 0
	var board = game._session.board
	for y in range(board.height - 1, -1, -1):
		for x in board.width:
			if taps >= n:
				return
			if board.find_group(x, y).size() >= 3:
				_tap(game, Vector2i(x, y))
				taps += 1
				await create_timer(0.9).timeout


func _tap(game, cell: Vector2i) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = (Vector2(cell) + Vector2(0.5, 0.5)) * game._cell
	game._on_board_input(ev)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
