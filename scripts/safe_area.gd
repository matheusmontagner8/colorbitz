## "Área segura" da tela: em celulares com entalhe ou furo para a câmera, ou
## com barra de gestos, parte da tela fica escondida. O GameState encolhe a
## cena atual por essas margens (o fundo neon continua na tela toda).
## Lógica pura: [method insets] só faz a conta, para poder ser testada.
extends RefCounted

## Uma margem nunca passa desta fração da tela (protege de valores estranhos).
const MAX_FRACTION := 0.15

## Ferramentas (tools/screenshot.gd) fingem um entalhe: margens em px da tela
## do jogo {left, top, right, bottom}. Vazio = usar o aparelho de verdade.
static var simulated: Dictionary = {}


## Margens em unidades da tela do jogo (720 de largura) a partir do tamanho
## da janela em pixels, da área segura (pixels, nas coordenadas da janela) e
## do tamanho da tela do jogo.
static func insets(window: Vector2, safe: Rect2, canvas: Vector2) -> Dictionary:
	var zero := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return zero
	var k := canvas / window
	var px := {
		"left": safe.position.x,
		"top": safe.position.y,
		"right": window.x - safe.end.x,
		"bottom": window.y - safe.end.y,
	}
	var result := {}
	for side in px:
		var horizontal: bool = side == "left" or side == "right"
		var value: float = px[side] * (k.x if horizontal else k.y)
		var limit: float = (canvas.x if horizontal else canvas.y) * MAX_FRACTION
		result[side] = clampf(roundf(value), 0.0, limit)
	return result


## Margens atuais: as simuladas, as do celular ou zero (no PC a "área segura"
## é a da tela do monitor, não da janela, então não vale).
static func current(viewport: Viewport) -> Dictionary:
	if not simulated.is_empty():
		return simulated
	if not OS.has_feature("mobile"):
		return insets(Vector2.ZERO, Rect2(), Vector2.ZERO)
	return insets(Vector2(DisplayServer.window_get_size()), Rect2(DisplayServer.get_display_safe_area()),
		viewport.get_visible_rect().size)


## Encolhe [param control] (que ocupa a tela toda) para dentro da área segura.
static func apply(control: Control, margins: Dictionary) -> void:
	control.offset_left = margins.left
	control.offset_top = margins.top
	control.offset_right = -margins.right
	control.offset_bottom = -margins.bottom
