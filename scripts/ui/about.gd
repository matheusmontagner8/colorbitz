## Tela "Sobre" (aberta pelas Opções): versão, relatar problema, política de
## privacidade, créditos e as licenças que o jogo precisa mostrar (Godot
## Engine e seus componentes, fonte Fredoka).
extends Control

const Fx = preload("res://scripts/fx.gd")
const DragScroll = preload("res://scripts/ui/drag_scroll.gd")

const REPO_URL := "https://github.com/matheusmontagner8/colorbitz"
const PRIVACY_URL := REPO_URL + "/blob/main/PRIVACY.md"
const ISSUE_URL := REPO_URL + "/issues/new"
const NEON_CYAN := Color("#3DE0FF")
const SECTION_COLOR := Color("#FFE53D")
const TEXT_COLOR := Color(1, 1, 1, 0.8)
const LICENSE_COLOR := Color(1, 1, 1, 0.6)
const FONT_NOTICE := "Fredoka\nCopyright 2016 The Fredoka Project Authors\n(https://github.com/hafontia/Fredoka-One)\nSIL Open Font License 1.1"

var drag: DragScroll
var third_party_button: Button


func _ready() -> void:
	Audio.play_music("menu")
	%BackButton.pressed.connect(GameState.go_to_options)
	drag = DragScroll.new(%Scroll)
	add_child(drag)
	var title := Fx.make_label(%List, 80, NEON_CYAN)
	title.text = "Colorbitz"
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	Fx.glow_label(title, NEON_CYAN, 18)
	Fx.make_label(%List, 32, TEXT_COLOR).text = tr("Versão %s") % GameState.version()
	_spacer(8)
	_button("Relatar problema", func(): OS.shell_open(issue_url())).theme_type_variation = &"AccentButton"
	_button("Política de privacidade", func(): OS.shell_open(PRIVACY_URL))
	_button("Código-fonte", func(): OS.shell_open(REPO_URL))
	_section("Créditos")
	_text("Feito com Godot Engine (godotengine.org).\nSons e músicas criados pelo próprio jogo.\nFonte Fredoka, de The Fredoka Project Authors.", TEXT_COLOR, 28)
	_section("Licenças")
	_license(FONT_NOTICE)
	_license("Godot Engine\n" + Engine.get_license_text())
	third_party_button = _button("Ver componentes do Godot", _show_third_party)


## Endereço para abrir uma issue no GitHub com a versão e o aparelho já
## preenchidos (a pessoa vê tudo antes de enviar).
static func issue_url() -> String:
	var body := "%s %s\n%s %s %s\n%s %s\n\n%s\n" % [
		"Versão:", GameState.version(),
		"Aparelho:", OS.get_name(), OS.get_version(),
		"Modelo:", OS.get_model_name(),
		"O que aconteceu:",
	]
	return "%s?title=%s&body=%s" % [ISSUE_URL, "Problema no jogo".uri_encode(), body.uri_encode()]


## Componentes de terceiros do Godot (FreeType, etc.) com direitos autorais e
## o texto de cada licença. Só monta ao pedir: é um texto longo.
func _show_third_party() -> void:
	var at := third_party_button.get_index()
	third_party_button.queue_free()
	var parts := []
	for component in Engine.get_copyright_info():
		var lines := [String(component.name)]
		for part in component.parts:
			for c in part.copyright:
				lines.append("© " + String(c))
			lines.append(String(part.license))
		parts.append("\n".join(lines))
	var notices := _license("\n\n".join(parts))
	%List.move_child(notices, at)
	var info := Engine.get_license_info()
	for license_name in info:
		_license(String(license_name) + "\n" + String(info[license_name]))


func _section(text: String) -> void:
	_spacer(12)
	var l := Fx.make_label(%List, 40, SECTION_COLOR)
	l.text = text
	Fx.glow_label(l, SECTION_COLOR, 10)


func _text(text: String, col: Color, font_size: int) -> Label:
	var l := Fx.make_label(%List, font_size, col)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Texto de licença: em inglês, sem tradução, alinhado à esquerda.
func _license(text: String) -> Label:
	var l := _text(text, LICENSE_COLOR, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(480, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		if not drag.dragged:  # soltar o dedo depois de rolar não aperta o botão
			on_pressed.call())
	%List.add_child(b)
	return b


func _spacer(height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	%List.add_child(s)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go_to_options()
