## Camada de efeitos sobre o tabuleiro: partículas, textos flutuantes,
## textos de combinação e ondas de choque. Só visual, sem regra de jogo.
extends Control

const Fx = preload("res://scripts/fx.gd")


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Remove todos os efeitos (ex.: ao reiniciar a fase no meio de uma animação).
func clear() -> void:
	for child in get_children():
		child.queue_free()


## Explosão de partículas brilhantes na cor do bloco.
func burst(pos: Vector2, col: Color, big: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 14 if big else 9
	p.lifetime = 0.75
	p.texture = Fx.dot_texture()
	p.material = Fx.additive_material()
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 420.0 if big else 300.0
	p.gravity = Vector2(0, 900)
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.9
	p.color = col.lightened(0.2)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(p.queue_free)


## Texto (pontos, "Joia!") que sobe e some.
func float_text(text: String, pos: Vector2, col: Color, font_size: int) -> void:
	var l := Fx.make_label(self, font_size, col.lightened(0.5))
	l.text = text
	Fx.glow_label(l, col, 14)
	l.reset_size()
	l.position = pos - l.size / 2.0
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 110.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	t.chain().tween_callback(l.queue_free)


## Texto grande de combinação ("Incrível!") centrado em [param center].
func combo_text(text: String, col: Color, center: Vector2) -> void:
	var l := Fx.make_label(self, 92, col.lightened(0.55))
	l.text = text
	Fx.glow_label(l, col, 28)
	l.reset_size()
	l.position = center - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 0.3
	l.rotation = -0.08
	var t := create_tween()
	t.tween_property(l, "scale", Vector2.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector2.ONE, 0.12)
	t.tween_interval(0.45)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


## Onda de choque: anel neon que se expande até [param radius].
func shockwave(pos: Vector2, radius: float, col: Color) -> void:
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var state := {"r": 0.0, "a": 1.0}
	ring.draw.connect(func():
		ring.draw_arc(pos, state.r, 0.0, TAU, 48, Color(col, state.a), 3.0 + 9.0 * state.a, true))
	add_child(ring)
	var t := create_tween()
	t.tween_method(func(v: float):
		state.r = v * radius
		state.a = 1.0 - v
		ring.queue_redraw(), 0.0, 1.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(ring.queue_free)
