class_name Progress
extends RefCounted
## O que o jogo lembra entre as fases e entre uma partida e outra, salvo em
## user://progresso.cfg (vale também na web):
##   collected  fases em que o bicudinho pegou o graveto (fotos da pasta "gravetos")
##   beaten     fases vencidas (liberam o .exe da próxima no desktop)
##   music_on   se a música toca
##   docs       textos sobre o bicudinho já lidos (desbloqueados na pasta "trabalho")

const SAVE_PATH := "user://progresso.cfg"

static var collected: Array = []
static var beaten: Array = []
static var music_on := true
static var docs: Array = []
static var _loaded := false


static func load_once() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		collected = cfg.get_value("gravetos", "fases", [])
		beaten = cfg.get_value("fases", "vencidas", [])
		music_on = cfg.get_value("som", "musica", true)
		docs = cfg.get_value("textos", "lidos", [])


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gravetos", "fases", collected)
	cfg.set_value("fases", "vencidas", beaten)
	cfg.set_value("som", "musica", music_on)
	cfg.set_value("textos", "lidos", docs)
	cfg.save(SAVE_PATH)


## Guarda o graveto da fase. Devolve false se ele já estava na coleção.
static func add(level: int) -> bool:
	load_once()
	if collected.has(level):
		return false
	collected.append(level)
	save()
	return true


static func beat(level: int) -> void:
	load_once()
	if not beaten.has(level):
		beaten.append(level)
		save()


## A fase está liberada? A 1 sempre; as outras depois de vencer a anterior.
static func unlocked(level: int) -> bool:
	load_once()
	return level <= 1 or beaten.has(level - 1) or beaten.has(level)


## Desbloqueia um texto da pasta "trabalho". Devolve false se ele já estava lá.
static func unlock_doc(key: String) -> bool:
	load_once()
	if docs.has(key):
		return false
	docs.append(key)
	save()
	return true
