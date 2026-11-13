## Rolagem por arrasto para um ScrollContainer cheio de botões (fases,
## conquistas). No celular, o toque que começa em cima de um botão fica com
## o botão e a rolagem padrão do Godot só funciona nos espaços entre eles,
## parecendo travada. Aqui o arrasto funciona em qualquer ponto da lista, com
## embalo ao soltar, e o mouse/roda continua funcionando no PC.
## Um arrasto não vale como toque: os botões checam [member dragged].
extends Node

## Distância (px da tela do jogo) para o toque virar arrasto.
const DRAG_THRESHOLD := 16.0
## Quanto o embalo perde por segundo (maior = para mais rápido).
const FRICTION := 5.0
const MIN_SPEED := 30.0
const WHEEL_STEP := 120.0

var scroll: ScrollContainer
## O toque atual (ou o último) virou arrasto: botões devem ignorá-lo.
var dragged := false

var _pressed := false
var _start := Vector2.ZERO
var _pos := 0.0  # rolagem em float (scroll_vertical é inteiro)
var _velocity := 0.0
var _last_motion_usec := 0


func _init(target: ScrollContainer) -> void:
	scroll = target
	# A rolagem padrão por toque fica desligada (senão rola em dobro nos espaços).
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.follow_focus = false


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		if not _inside(mb.position) and not _pressed:
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pressed = true
					dragged = false
					_start = mb.position
					_velocity = 0.0
					_pos = scroll.scroll_vertical
				else:
					_pressed = false
					# Dedo parado antes de soltar: sem embalo.
					if absf(_velocity) < MIN_SPEED or Time.get_ticks_usec() - _last_motion_usec > 80000:
						_velocity = 0.0
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_velocity = 0.0
					_scroll_to(scroll.scroll_vertical + (WHEEL_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -WHEEL_STEP))
		return
	var mm := event as InputEventMouseMotion
	if mm and _pressed:
		if not dragged and absf(mm.position.y - _start.y) > DRAG_THRESHOLD:
			dragged = true
		if dragged:
			_scroll_to(_pos - mm.relative.y)
			var now := Time.get_ticks_usec()
			var dt := maxf((now - _last_motion_usec) / 1000000.0, 0.001)
			_last_motion_usec = now
			_velocity = lerpf(_velocity, -mm.relative.y / dt, 0.5)


func _process(delta: float) -> void:
	if _pressed or _velocity == 0.0:
		return
	if scroll.scroll_vertical != roundi(_pos):  # alguém mudou a rolagem: para o embalo
		_velocity = 0.0
		_pos = scroll.scroll_vertical
		return
	_scroll_to(_pos + _velocity * delta)
	_velocity *= exp(-FRICTION * delta)
	var bar := scroll.get_v_scroll_bar()
	if absf(_velocity) < MIN_SPEED or scroll.scroll_vertical <= 0 or scroll.scroll_vertical >= bar.max_value - bar.page:
		_velocity = 0.0


func _scroll_to(value: float) -> void:
	var bar := scroll.get_v_scroll_bar()
	_pos = clampf(value, 0.0, maxf(0.0, bar.max_value - bar.page))
	scroll.scroll_vertical = roundi(_pos)


func _inside(pos: Vector2) -> bool:
	return scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(pos)
