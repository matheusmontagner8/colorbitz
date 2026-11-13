extends "res://tests/test_case.gd"

const BlockView = preload("res://scripts/block_view.gd")


func test_colorblind_palette_switch() -> void:
	assert_eq(BlockView.COLORBLIND_COLORS.size(), BlockView.COLORS.size(), "mesma quantidade de cores")
	BlockView.colorblind = true
	assert_eq(BlockView.color_of(0), BlockView.COLORBLIND_COLORS[0])
	assert_eq(BlockView.color_of(BlockView.GEM), BlockView.GEM_COLOR, "especiais não mudam")
	BlockView.colorblind = false
	assert_eq(BlockView.color_of(0), BlockView.COLORS[0])


func test_colorblind_palette_avoids_special_colors() -> void:
	var specials := [BlockView.GEM_COLOR, BlockView.STONE_COLOR, BlockView.WILD_COLOR, BlockView.BOMB_COLOR]
	for c in BlockView.COLORBLIND_COLORS:
		for s in specials:
			var d := Vector3(c.r - s.r, c.g - s.g, c.b - s.b).length()
			assert_true(d > 0.25, "cor %s parecida demais com especial %s" % [c.to_html(false), s.to_html(false)])
