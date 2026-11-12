extends "res://tests/test_case.gd"

## Todos os scripts do jogo compilam (pega erros de digitação em telas que
## os outros testes não carregam). Roda no CI também.


func test_all_scripts_compile() -> void:
	var count := 0
	for path in _scripts("res://scripts"):
		var script := load(path) as GDScript
		assert_true(script != null and script.can_instantiate(), "não compila: %s" % path)
		count += 1
	assert_true(count > 20, "encontrou os scripts (%d)" % count)


func _scripts(dir: String) -> Array:
	var result := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			result.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		result += _scripts(dir + "/" + d)
	return result
