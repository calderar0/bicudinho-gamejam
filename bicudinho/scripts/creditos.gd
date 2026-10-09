extends LevelBase
## Créditos jogáveis. O bicudinho e a bicudinha andam juntos até o brejo, por uma ponte feita
## dos nomes de quem fez o jogo. Ninguém precisa fazer nada: é só olhar.
## Para mudar os nomes, edite NAMES: cada nome vira um ícone da ponte (o rio se ajusta).

const NAMES := [
	["Bianca", "Valenciani"], ["Felipe", "Calderaro"], ["Letícia Akemi", "Ikemoto"],
]

var _names_layer: Node2D


func _setup_level() -> void:
	window_rect = Rect2(32, 48, 576, 272)
	bird_start = Vector2(88, 288)
	exit_feet = Vector2(568, 288)
	goal = "brejo"
	auto_walk = true
	lock_icons = true   # a ponte de nomes é a cena: não sai do lugar
	win_text = "Obrigado por jogar!"
	icons_data = []
	for i in NAMES.size():
		icons_data.append({"type": "file", "x": 224 + 32 * i, "y": 288, "draggable": false})
	level_name = "Créditos"


func _paint_map(g: Array) -> void:
	var last := 13 + NAMES.size() * 2            # cada ícone cobre 2 tiles do rio
	paint(g, 0, 18, 13, 19, "#")    # chão
	paint(g, 14, 18, last, 19, "~") # rio, coberto pela ponte de nomes
	paint(g, last + 1, 18, 39, 19, "#")   # chão do brejo


func _ready() -> void:
	super._ready()
	female = Female.new()
	female.position = bird_start - Vector2(24, 0)
	female.target = bird
	add_child(female)
	_names_layer = Node2D.new()
	_names_layer.z_index = 30
	_names_layer.draw.connect(_draw_names)
	add_child(_names_layer)
	_names_layer.queue_redraw()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _won and female != null:
		female.position = Vector2(bird.position.x - 24.0 * bird.facing, bird.position.y)  # ela vai junto


func _draw_names() -> void:
	var font := ThemeDB.fallback_font
	_names_layer.draw_string(font, Vector2(win.rect.position.x, 88), "Bicudinho",
		HORIZONTAL_ALIGNMENT_CENTER, win.rect.size.x, 16, Color("2f3a8f"))
	_names_layer.draw_string(font, Vector2(win.rect.position.x, 104), "feito para a GameRex 2026",
		HORIZONTAL_ALIGNMENT_CENTER, win.rect.size.x, 8, Color("2f3a8f"))
	for i in NAMES.size():
		var x := 224.0 + 32.0 * i
		var y := 240.0 if i % 2 == 0 else 262.0   # alterna a altura para os nomes não se encostarem
		_names_layer.draw_string(font, Vector2(x - 34.0, y), NAMES[i][0], HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Color("2b2b3a"))
		_names_layer.draw_string(font, Vector2(x - 34.0, y + 9.0), NAMES[i][1], HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Color("2b2b3a"))


## Fim: os dois felizes no brejo, e fica assim (não recomeça sozinho).
func _win_level() -> void:
	_won = true
	bird.celebrate()
	female.set_happy(true)
	Audio.stop_music()
	Audio.play("sfx_win_level", 0.0, Tuning.WIN_VOLUME_DB)
	queue_redraw()
