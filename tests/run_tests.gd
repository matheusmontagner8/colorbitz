## Executor de testes. Uso (na raiz do projeto):
##   godot --headless --path . -s tests/run_tests.gd
## Sai com código 1 se algum teste falhar (útil para CI).
extends SceneTree

const TESTS_DIR := "res://tests"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TESTS_DIR))
	files.sort()
	for file_name in files:
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")) or file_name == "test_case.gd":
			continue
		var script: GDScript = load(TESTS_DIR + "/" + file_name)
		print("\n== %s" % file_name)
		var seen := {}
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_") or seen.has(name):
				continue
			seen[name] = true
			var suite = script.new()
			suite.call(name)
			total += 1
			if suite.failures.is_empty():
				print("  ok   %s" % name)
			else:
				failed += 1
				print("  FALHOU %s" % name)
				for f in suite.failures:
					print("         - %s" % f)
	print("\n%d testes, %d falha(s)" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
