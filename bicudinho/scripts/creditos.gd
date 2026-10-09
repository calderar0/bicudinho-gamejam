extends LevelBase
## Créditos jogáveis. O bicudinho e a bicudinha andam juntos até o brejo, por uma ponte feita
## dos nomes de quem fez o jogo. Ninguém precisa fazer nada: é só olhar.
## Para mudar os nomes, edite NAMES ([nome, função]): cada um vira um ícone da ponte (o rio se ajusta).

const NAMES := [
	["Letícia Akemi Ikemoto", "Arte e Game Design"],
	["Felipe Calderaro", "Programação e Game Design"],
	["Bianca Valenciani", "Sons e Game Design"],
]

var _names_layer: Node2D

## O voo final até o ninho (art/nest.png fica com a base em exit_feet; o ninho está lá em cima).
const FLY_TIME := 1.2
const FLY_ARC := 40.0
const NEST_SPOT_BIRD := Vector2(13, -92)     # onde os pés dele pousam, a partir do pé da taboa
const NEST_SPOT_FEMALE := Vector2(-17, -92)


func _setup_level() -> void:
	window_rect = Rect2(32, 48, 576, 272)
	bird_start = Vector2(88, 288)
	exit_feet = Vector2(568, 288)
	goal = "brejo"
	with_nest = true    # os dois andam juntos até o ninho
	auto_walk = true
	lock_icons = true   # a ponte de nomes é a cena: não sai do lugar
	win_text = "Obrigado por jogar!"
	icons_data = []
	for i in NAMES.size():
		icons_data.append({"type": "file", "x": _bridge_col() * 16 + 32 * i, "y": 288, "draggable": false})
	level_name = "Créditos"


func _paint_map(g: Array) -> void:
	var first := _bridge_col()
	var last := first + NAMES.size() * 2 - 1     # cada ícone cobre 2 tiles do rio
	paint(g, 0, 18, first - 1, 19, "#")   # chão
	paint(g, first, 18, last, 19, "~")    # rio, coberto pela ponte de nomes
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
	_names_layer.draw_string(font, Vector2(win.rect.position.x, 88), "Quito",
		HORIZONTAL_ALIGNMENT_CENTER, win.rect.size.x, 16, Color("2f3a8f"))
	_names_layer.draw_string(font, Vector2(win.rect.position.x, 104), "feito para a GameRex 2026",
		HORIZONTAL_ALIGNMENT_CENTER, win.rect.size.x, 8, Color("2f3a8f"))
	# a equipe em lista no céu: o nome e, embaixo, a função
	for i in NAMES.size():
		var y := 176.0 + i * 28.0   # abaixo do "Obrigado por jogar!" (que aparece no fim)
		_names_layer.draw_string(font, Vector2(win.rect.position.x, y), NAMES[i][0],
			HORIZONTAL_ALIGNMENT_CENTER, win.rect.size.x, 10, Color("2b2b3a"))
		_names_layer.draw_string(font, Vector2(win.rect.position.x, y + 11.0), NAMES[i][1],
			HORIZONTAL_ALIGNMENT_CENTER, win.rect.size.x, 8, Color("3a4a8a"))


## Fim: chegando ao pé da taboa, os dois voam juntos até o ninho, lá no alto, e ficam
## felizes lá em cima. Fica assim (não recomeça sozinho).
func _win_level() -> void:
	_won = true
	bird.frozen = true
	bird.velocity = Vector2.ZERO
	bird.flying = true
	Audio.stop_music()
	Audio.play("sfx_jump", 0.05)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_fly.bind(bird, bird.position, exit_feet + NEST_SPOT_BIRD), 0.0, 1.0, FLY_TIME)
	tw.tween_method(_fly.bind(female, female.position, exit_feet + NEST_SPOT_FEMALE), 0.0, 1.0, FLY_TIME)
	await tw.finished
	bird.flying = false
	bird.facing = -1   # no ninho, ele vira para ela
	bird.celebrate()
	female.set_happy(true)
	Fx.sparkle(exit_feet + Vector2(-4, -96), 24, 0.8)
	Audio.play("sfx_win_level", 0.0, Tuning.WIN_VOLUME_DB)
	queue_redraw()


## Um passo do voo (t de 0 a 1): arco que sobe acima da reta, devagar no começo e no fim.
func _fly(t: float, who: Node2D, from: Vector2, to: Vector2) -> void:
	var e := t * t * (3.0 - 2.0 * t)
	var mid := (from + to) / 2.0 + Vector2(0, -FLY_ARC)
	who.position = from.lerp(mid, e).lerp(mid.lerp(to, e), e)


## Primeira coluna da ponte: a ponte de nomes fica no meio da janela (coluna 20 = x 320).
func _bridge_col() -> int:
	return 20 - NAMES.size()
