extends Node2D
## Fase 1, Brejo. Ensina andar, pular, a disparada e o vidro. Janela fixa.
## Tudo é montado por código, então a cena só precisa deste script no nó raiz.
##
## Ritmo (colunas do mapa; a janela mostra as colunas 2 a 37 e as linhas 3 a 19):
##   2-8    chão plano: andar
##   9-12   degrau de 2 tiles: pular
##   13-16  poça de 4 tiles: primeiro risco, pulo simples
##   17-19  chão seguro (respiro antes do desafio)
##   20-29  poça de 10 tiles, e o outro lado é 2 tiles mais alto. Planar ganha
##          distância mas perde altura, então só passa com a disparada.
##   30-32  pouso elevado (2 tiles)
##   33-37  barranco de mais 3 tiles com a saída, colado no vidro da direita.
##          Quem dispara forte rumo à saída bate no vidro, fica atordoado e cai
##          no barranco: a lição do vidro acontece sem castigo.

const COLS := 40
const ROWS := 21
const BICUDINHO_SCENE := preload("res://scenes/bicudinho.tscn")

# Área interna da janela (em px do desktop). Mínimo = máximo: janela fixa na fase 1.
const WINDOW_RECT := Rect2(32, 48, 576, 272)
const WINDOW_MIN := Vector2(576, 272)
const WINDOW_MAX := Vector2(576, 272)
const BIRD_START := Vector2(72, 288)  # pés sobre o chão (linha 18 do mapa)

const EXIT_CELL := Vector2i(35, 12)   # tile do icon_brejo (em cima do barranco)
const EXIT_COLOR := Color("2f7d3a")
const EXIT_REED := Color("c9a86a")
const WIN_RESTART_TIME := 1.5

const WALLPAPER_COLOR := Color("4d8f66")
const SKY_COLOR := Color("a4d8ea")
const TASKBAR_TEX := preload("res://art/ui/taskbar.png")

var win: GameWindow
var tiles: TileWorld
var bird: Bicudinho
var _restarting := false
var _won := false
var _time := 0.0


func _ready() -> void:
	win = GameWindow.new()
	win.process_physics_priority = -10  # a janela se move antes do bicudinho
	win.setup(WINDOW_RECT, WINDOW_MIN, WINDOW_MAX)

	tiles = TileWorld.new()
	tiles.setup(_build_map())
	add_child(tiles)

	bird = BICUDINHO_SCENE.instantiate() as Bicudinho
	bird.position = BIRD_START
	bird.hazard_check = Callable(tiles, "hazard_hit")
	bird.died.connect(_on_bird_died)
	bird.glass_hit.connect(win.add_crack)  # a batida no vidro desenha uma rachadura
	add_child(bird)

	add_child(win)  # por último: a moldura e o vidro desenham por cima de tudo

	add_child(StartMenu.new())  # por último: o menu fica acima de tudo e pega o clique primeiro

	win.rect_changed.connect(_on_rect_changed)
	win.hit_limit.connect(Audio.play.bind("sfx_window_limit"))
	win.button_pressed.connect(_on_window_button)
	_on_rect_changed()
	Audio.resume_music()  # a vitória para a música; ao recomeçar, ela volta


## Mapa de 40x21 tiles. Legenda em tile_world.gd.
func _build_map() -> PackedStringArray:
	var g: Array = []
	for y in ROWS:
		var row: Array = []
		row.resize(COLS)
		row.fill(".")
		g.append(row)
	_paint(g, 0, 18, 39, 19, "#")    # chão
	_paint(g, 9, 16, 12, 17, "#")    # degrau de 2 tiles
	_paint(g, 13, 18, 16, 19, "~")   # poça pequena (4)
	_paint(g, 20, 18, 29, 19, "~")   # poça grande (10): precisa da disparada
	_paint(g, 30, 16, 32, 17, "#")   # pouso elevado (2 tiles): planar não alcança
	_paint(g, 33, 13, 39, 17, "#")   # barranco final (mais 3 tiles)
	var rows := PackedStringArray()
	for row in g:
		rows.append("".join(row))
	return rows


func _paint(g: Array, x0: int, y0: int, x1: int, y1: int, ch: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			g[y][x] = ch


func _on_rect_changed() -> void:
	tiles.set_interior(win.rect)
	bird.enforce_inside(win.rect)
	queue_redraw()


func _on_bird_died(_cause: String) -> void:
	if _restarting or _won:
		return
	_restarting = true
	await get_tree().create_timer(Tuning.DEATH_RESTART_TIME).timeout
	get_tree().reload_current_scene()


# --- Saída (icon_brejo) -------------------------------------------------------

func _exit_rect() -> Rect2:
	return Rect2(Vector2(EXIT_CELL) * Tuning.TILE, Vector2(Tuning.TILE, Tuning.TILE))


func _physics_process(delta: float) -> void:
	_time += delta
	if _won or _restarting or bird.dead:
		return
	var exit := _exit_rect()
	# regra de ouro: a saída só existe dentro da janela
	if win.rect.encloses(exit) and exit.intersects(bird.box_rect()):
		_win()


func _win() -> void:
	_won = true
	Audio.stop_music()
	Audio.play("sfx_win_level", 0.0, Tuning.WIN_VOLUME_DB)
	bird.set_physics_process(false)
	await get_tree().create_timer(WIN_RESTART_TIME).timeout
	get_tree().reload_current_scene()  # sem fase 2 ainda: recomeça


# --- Mouse --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if not event.pressed:
			win.release_button(m)
			return
		var btn := win.button_at(m)
		if btn != -1:
			win.press_button(btn)
			Audio.play("sfx_ui_click")
			return
		var sides := win.side_at(m)
		if sides != 0:
			win.begin_resize(sides, m)
			Audio.play("sfx_ui_click", 0.05, -6.0)


## Botões da janela do jogo: só de enfeite por enquanto. Fechar o jogo "não pode".
func _on_window_button(btn: int) -> void:
	if btn == GameWindow.BTN_CLOSE:
		Audio.play("sfx_window_limit")


func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	# o arrasto é lido por polling, para não travar se o mouse passar por outro nó
	if win.drag_sides != 0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			win.update_resize(m)
		else:
			win.end_resize()
	if win.update_hover(m):
		Audio.play("sfx_ui_hover", 0.05, -4.0)
	_update_cursor(m)
	queue_redraw()  # a saída pisca


func _update_cursor(m: Vector2) -> void:
	var sides := win.drag_sides if win.drag_sides != 0 else win.side_at(m)
	var shape := Input.CURSOR_ARROW
	if sides != 0:
		var h := sides & (GameWindow.L | GameWindow.R)
		var v := sides & (GameWindow.T | GameWindow.B)
		if h != 0 and v != 0:
			var same := (h == GameWindow.L) == (v == GameWindow.T)
			shape = Input.CURSOR_FDIAGSIZE if same else Input.CURSOR_BDIAGSIZE
		elif h != 0:
			shape = Input.CURSOR_HSIZE
		else:
			shape = Input.CURSOR_VSIZE
	Input.set_default_cursor_shape(shape)


# --- Fundo: desktop falso -----------------------------------------------------

func _draw() -> void:
	var area := Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H - Tuning.TASKBAR_H)
	draw_rect(area, WALLPAPER_COLOR)
	draw_rect(win.rect, SKY_COLOR)  # o céu só existe dentro da janela
	_draw_exit()
	draw_texture_rect(TASKBAR_TEX, Rect2(0, Tuning.SCREEN_H - Tuning.TASKBAR_H, Tuning.SCREEN_W, Tuning.TASKBAR_H), false)
	draw_string(ThemeDB.fallback_font, Vector2(26, Tuning.SCREEN_H - 5),
		"Espaço no ar: preparar | setas: mirar | segurar ↑ caindo: planar | R: reiniciar",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f2f1ed"))


## Placeholder do icon_brejo: moita com taboas e um brilho pulsando.
func _draw_exit() -> void:
	var exit := _exit_rect()
	if not win.rect.encloses(exit):
		return
	var glow := 0.25 + 0.15 * sin(_time * 4.0)
	draw_rect(exit.grow(3), Color(1, 1, 0.6, glow))
	draw_rect(Rect2(exit.position + Vector2(1, 9), Vector2(14, 7)), EXIT_COLOR)
	for x in [3, 7, 11]:
		draw_rect(Rect2(exit.position + Vector2(x, 2), Vector2(1, 8)), EXIT_COLOR.darkened(0.2))
		draw_rect(Rect2(exit.position + Vector2(x - 1, 1), Vector2(3, 3)), EXIT_REED)
	if _won:
		draw_string(ThemeDB.fallback_font, win.rect.get_center() + Vector2(-60, -40),
			"Achou o brejo!", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color("2f3a8f"))
