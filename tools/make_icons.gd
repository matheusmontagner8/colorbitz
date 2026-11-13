## Gera os ícones do app a partir do mesmo desenho do icon.svg (4 blocos neon):
##   assets/icon/icon_192.png                 ícone comum (Android antigo)
##   assets/icon/adaptive_foreground_432.png  frente do ícone adaptativo (só os blocos)
##   assets/icon/adaptive_background_432.png  fundo do ícone adaptativo (degradê)
##   assets/icon/adaptive_monochrome_432.png  ícone temático do Android 13+ (silhueta)
##   assets/icon/play_store_512.png           ícone da página da Play Store
## O Android recorta o ícone adaptativo em formatos diferentes (círculo,
## quadrado arredondado...): o desenho fica dentro do círculo central de 264 px
## (a "zona segura" de 66 dp em 108 dp) para nunca ser cortado.
## Uso: godot --headless --path . -s tools/make_icons.gd
extends SceneTree

const OUT_DIR := "res://assets/icon/"
## Lado (px) da grade de blocos na frente do ícone adaptativo: com os cantos
## arredondados, os cantos da grade encostam no círculo da zona segura.
const ADAPTIVE_GRID := 200.0
const STORE_GRID := 360.0

const BACKGROUND := """<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
	<stop offset="0" stop-color="#0c1442"/><stop offset="1" stop-color="#02030a"/></linearGradient>"""

## Os 4 blocos do icon.svg, em coordenadas de 0 a 128 (grade de 16 a 112).
const GRID := """<g fill="none" stroke-linejoin="round">
	<rect x="16" y="16" width="42" height="42" rx="10" stroke="#2E9BFF" stroke-opacity="0.3" stroke-width="10"/>
	<rect x="16" y="16" width="42" height="42" rx="10" stroke="#2E9BFF" stroke-width="4" fill="#0d2a4d"/>
	<circle cx="37" cy="37" r="9" stroke="#9fd0ff" stroke-width="3.5"/>
	<rect x="70" y="16" width="42" height="42" rx="10" stroke="#B05CFF" stroke-opacity="0.3" stroke-width="10"/>
	<rect x="70" y="16" width="42" height="42" rx="10" stroke="#B05CFF" stroke-width="4" fill="#2a1450"/>
	<rect x="83" y="29" width="16" height="16" stroke="#dcb8ff" stroke-width="3.5"/>
	<rect x="16" y="70" width="42" height="42" rx="10" stroke="#2BFF88" stroke-opacity="0.3" stroke-width="10"/>
	<rect x="16" y="70" width="42" height="42" rx="10" stroke="#2BFF88" stroke-width="4" fill="#0d4028"/>
	<polygon points="37,81 47,99 27,99" stroke="#a8ffd0" stroke-width="3.5"/>
	<rect x="70" y="70" width="42" height="42" rx="10" stroke="#FF4FD8" stroke-opacity="0.3" stroke-width="10"/>
	<rect x="70" y="70" width="42" height="42" rx="10" stroke="#FF4FD8" stroke-width="4" fill="#4d1442"/>
	<polygon points="91,80 101,91 91,102 81,91" stroke="#ffc0f0" stroke-width="3.5"/>
</g>"""

## Silhueta para o ícone temático (o Android pinta com a cor do tema).
const MONO_GRID := """<g fill="none" stroke="#ffffff" stroke-linejoin="round">
	<rect x="16" y="16" width="42" height="42" rx="10" stroke-width="5"/>
	<circle cx="37" cy="37" r="9" stroke-width="4"/>
	<rect x="70" y="16" width="42" height="42" rx="10" stroke-width="5"/>
	<rect x="83" y="29" width="16" height="16" stroke-width="4"/>
	<rect x="16" y="70" width="42" height="42" rx="10" stroke-width="5"/>
	<polygon points="37,81 47,99 27,99" stroke-width="4"/>
	<rect x="70" y="70" width="42" height="42" rx="10" stroke-width="5"/>
	<polygon points="91,80 101,91 91,102 81,91" stroke-width="4"/>
</g>"""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_render("icon_192.png", 192, FileAccess.get_file_as_string("res://icon.svg"))
	_render("adaptive_foreground_432.png", 432, _svg(432, "", _centered(GRID, 432, ADAPTIVE_GRID)))
	_render("adaptive_background_432.png", 432, _svg(432, BACKGROUND, '<rect width="432" height="432" fill="url(#bg)"/>'))
	_render("adaptive_monochrome_432.png", 432, _svg(432, "", _centered(MONO_GRID, 432, ADAPTIVE_GRID)))
	# A Play Store aplica o próprio arredondamento: o ícone é um quadrado cheio.
	_render("play_store_512.png", 512, _svg(512, BACKGROUND,
		'<rect width="512" height="512" fill="url(#bg)"/>' + _centered(GRID, 512, STORE_GRID)))
	quit()


## Grade (16..112 no desenho original) centralizada com [param grid] px de lado.
func _centered(content: String, canvas: int, grid: float) -> String:
	var k := grid / 96.0
	return '<g transform="translate(%f %f) scale(%f) translate(-64 -64)">%s</g>' % [canvas / 2.0, canvas / 2.0, k, content]


func _svg(canvas: int, defs: String, body: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><defs>%s</defs>%s</svg>' \
		% [canvas, canvas, canvas, canvas, defs, body]


func _render(file_name: String, px: int, svg: String) -> void:
	var img := Image.new()
	var size_match := RegEx.create_from_string('width="(\\d+)"').search(svg)
	var scale := float(px) / float(size_match.get_string(1))
	var err := img.load_svg_from_string(svg, scale)
	assert(err == OK, "SVG inválido: %s" % file_name)
	assert(img.get_width() == px and img.get_height() == px, "%s: %dx%d" % [file_name, img.get_width(), img.get_height()])
	img.save_png(OUT_DIR + file_name)
	print("gerado %s (%dx%d)" % [file_name, px, px])
