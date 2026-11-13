extends "res://tests/test_case.gd"

const I18n = preload("res://scripts/i18n.gd")
const LevelLoader = preload("res://scripts/level_loader.gd")
const Achievements = preload("res://scripts/achievements.gd")
const Daily = preload("res://scripts/daily.gd")

## Textos de cena que não são traduzidos (nomes próprios e ícones).
const SCENE_IGNORE := ["II", "Colorbitz", "Idioma: Português"]  # o último é trocado pelo código


func _en() -> Dictionary:
	return I18n.load_messages("en")


## Marcadores de formato (%d, %s...) na ordem em que aparecem.
func _placeholders(text: String) -> Array:
	var re := RegEx.new()
	re.compile("%[0-9]*[ds]")
	var found := []
	for m in re.search_all(text):
		found.append(m.get_string())
	return found


func test_english_file_is_valid() -> void:
	var en := _en()
	assert_true(en.size() > 100, "tem as traduções")
	for key in en:
		assert_true(String(en[key]).strip_edges() != "", "tradução vazia: %s" % key)
		assert_eq(_placeholders(en[key]), _placeholders(key), "marcadores diferentes em: %s" % key)
		assert_eq(String(en[key]).count("\n"), String(key).count("\n"), "quebras de linha diferentes em: %s" % key)


## Cada entrada numa linha só: quebras de linha só como \n escapado (o
## leitor do Godot aceita quebra real dentro do texto, mas o arquivo deixa de
## ser JSON válido para outras ferramentas).
func test_english_file_one_entry_per_line() -> void:
	var re := RegEx.new()
	re.compile("^\t\"(?:[^\"\\\\]|\\\\.)*\": \"(?:[^\"\\\\]|\\\\.)*\",?$")
	var lines := FileAccess.get_file_as_string(I18n.LANG_DIR + "en.json").split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if line.strip_edges() in ["", "{", "}"]:
			continue
		assert_true(re.search(line) != null, "en.json linha %d fora do formato: %s" % [i + 1, line])


## Todo tr("...") e I18n.t("...") do código precisa estar traduzido.
func test_every_tr_call_is_translated() -> void:
	var en := _en()
	var re := RegEx.new()
	re.compile("(?:\\btr|I18n\\.t)\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	var checked := 0
	for path in _files("res://scripts", ".gd"):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var key := m.get_string(1).c_unescape()
			checked += 1
			assert_true(en.has(key), "%s: falta traduzir \"%s\"" % [path.get_file(), key])
	assert_true(checked > 30, "encontrou as chamadas tr() (%d)" % checked)


func test_scene_texts_are_translated() -> void:
	var en := _en()
	var re := RegEx.new()
	re.compile("(?m)^text = \"((?:[^\"\\\\]|\\\\.)*)\"")
	for path in _files("res://scenes", ".tscn"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			var key := m.get_string(1).c_unescape()
			if key not in SCENE_IGNORE:
				assert_true(en.has(key), "%s: falta traduzir \"%s\"" % [path.get_file(), key])


func test_data_texts_are_translated() -> void:
	var en := _en()
	for level in LevelLoader.load_levels():
		if level.has("tip"):
			assert_true(en.has(level.tip), "dica da fase %d" % int(level.id))
	for a in Achievements.LIST:
		assert_true(en.has(a.title) and en.has(a.desc), "conquista %s" % a.id)
	for t in Daily.TEMPLATES:
		assert_true(en.has(t.name), "fase diária %s" % t.name)


func test_language_choice() -> void:
	assert_eq(I18n.resolve("en"), "en")
	assert_eq(I18n.resolve("pt"), "pt")
	assert_true(I18n.resolve("") in I18n.LANGUAGES, "automático cai num idioma existente")
	assert_eq(I18n.resolve("xx"), I18n.resolve(""), "desconhecido = automático")


func test_translation_server_uses_file() -> void:
	I18n.load_translations()
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(I18n.t("Jogar"), "Play")
	assert_eq(I18n.t("Fase %d") % 7, "Level 7")
	TranslationServer.set_locale("pt")
	assert_eq(I18n.t("Jogar"), "Jogar", "português é o próprio texto")
	TranslationServer.set_locale(before)


func _files(dir: String, ext: String) -> Array:
	var result := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			result.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		result += _files(dir + "/" + d, ext)
	return result
