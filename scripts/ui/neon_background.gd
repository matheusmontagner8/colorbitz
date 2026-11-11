## Fundo neon compartilhado por todas as telas: degradê azul-marinho → preto
## com partículas coloridas flutuando devagar. Criado pelo autoload GameState,
## então não "pisca" ao trocar de tela.
extends CanvasLayer

const BlockView = preload("res://scripts/block_view.gd")
const Fx = preload("res://scripts/fx.gd")

const TOP := Color("#0c1442")
const BOTTOM := Color("#02030a")

var _particles: CPUParticles2D


func _ready() -> void:
	layer = -100

	var grad := Gradient.new()
	grad.set_color(0, TOP)
	grad.set_color(1, BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 256
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_particles = CPUParticles2D.new()
	_particles.amount = 26
	_particles.lifetime = 16.0
	_particles.preprocess = 16.0
	_particles.texture = Fx.dot_texture()
	_particles.material = Fx.additive_material()
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.direction = Vector2.UP
	_particles.spread = 25.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 6.0
	_particles.initial_velocity_max = 22.0
	_particles.scale_amount_min = 0.12
	_particles.scale_amount_max = 0.35
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colors.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	colors.colors = PackedColorArray([BlockView.COLORS[0], BlockView.COLORS[1], BlockView.COLORS[2], BlockView.COLORS[3], BlockView.COLORS[4]])
	_particles.color_initial_ramp = colors
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	_particles.color_ramp = fade
	add_child(_particles)

	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var s := get_viewport().get_visible_rect().size
	_particles.position = s / 2.0
	_particles.emission_rect_extents = s / 2.0
