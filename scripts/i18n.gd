## Idiomas do jogo. O texto em português do próprio código é a chave; as
## traduções ficam em data/lang/<idioma>.json ({"texto em pt": "tradução"}).
## Rótulos e botões se traduzem sozinhos (auto_translate do Godot); textos
## montados com números usam tr("Fase %d") % n nas telas ou I18n.t() em
## funções estáticas.
extends RefCounted

const LANG_DIR := "res://data/lang/"
## Idiomas disponíveis (o primeiro é o do código, sem arquivo).
const LANGUAGES := ["pt", "en"]
const NAMES := {"pt": "Português", "en": "English"}

static var _loaded := false


## Carrega os arquivos de tradução no TranslationServer (uma vez).
static func load_translations() -> void:
	if _loaded:
		return
	_loaded = true
	for lang in LANGUAGES.slice(1):
		var messages := load_messages(lang)
		var t := Translation.new()
		t.locale = lang
		for key in messages:
			t.add_message(key, messages[key])
		TranslationServer.add_translation(t)


static func load_messages(lang: String) -> Dictionary:
	var path := LANG_DIR + lang + ".json"
	if not FileAccess.file_exists(path):
		push_error("Tradução não encontrada: %s" % path)
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Idioma efetivo: o escolhido nas opções ou, se vazio, o do aparelho
## (português para quem usa o celular em português, inglês para o resto).
static func resolve(choice: String) -> String:
	if choice in LANGUAGES:
		return choice
	return "pt" if OS.get_locale_language() == "pt" else "en"


static func apply(choice: String) -> void:
	load_translations()
	TranslationServer.set_locale(resolve(choice))


static func current() -> String:
	return "pt" if TranslationServer.get_locale().begins_with("pt") else "en"


## Traduz fora de um Node (funções estáticas).
static func t(text: String) -> String:
	return TranslationServer.translate(text)
