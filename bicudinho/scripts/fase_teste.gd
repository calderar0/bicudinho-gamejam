extends Node2D
## Cena de teste do passo 2: desktop falso, janela redimensionável com vidro, mapa e bicudinho.
## Tudo é montado por código, então a cena só precisa deste script no nó raiz.

const COLS := 40
const ROWS := 21
const BICUDINHO_SCENE := preload("res://scenes/bicudinho.tscn")

# Área interna inicial da janela (em px do desktop) e limites de tamanho.
const WINDOW_RECT := Rect2(32, 48, 576, 272)
const WINDOW_MIN := Vector2(160, 112)
const WINDOW_MAX := Vector2(576, 272)

const WALLPAPER_COLOR := Color("4d8f66")
const SKY_COLOR := Color("a4d8ea")
const TASKBAR_TEX := preload("res://art/ui/taskbar.png")

var win: GameWindow
var tiles: TileWorld
var bird: Bicudinho
var _restarting := false


func _ready() -> void:
	win = GameWindow.new()
	win.process_physics_priority = -10  # a janela se move antes do bicudinho
	win.setup(WINDOW_RECT, WINDOW_MIN, WINDOW_MAX)

	tiles = TileWorld.new()
	tiles.setup(_build_map())
	add_child(tiles)

	bird = BICUDINHO_SCENE.instantiate() as Bicudinho
	bird.position = Vector2(72, 288)  # pés sobre o chão (linha 18 do mapa)
	bird.hazard_check = Callable(tiles, "hazard_hit")
	bird.died.connect(_on_bird_died)
	add_child(bird)

	add_child(win)  # por último: a moldura e o vidro desenham por cima de tudo

	add_child(StartMenu.new())  # por último: o menu fica acima de tudo e pega o clique primeiro

	win.rect_changed.connect(_on_rect_changed)
	win.hit_limit.connect(Audio.play.bind("sfx_window_limit"))
	win.button_pressed.connect(_on_window_button)
	_on_rect_changed()


## Mapa de 40x21 tiles. Troque os números para criar suas próprias fases.
func _build_map() -> PackedStringArray:
	var g: Array = []
	for y in ROWS:
		var row: Array = []
		row.resize(COLS)
		row.fill(".")
		g.append(row)
	_paint(g, 0, 18, 39, 19, "#")    # chão
	_paint(g, 14, 18, 19, 19, "~")   # poço de rio (6 tiles)
	_paint(g, 26, 15, 29, 17, "#")   # degrau alto (3 tiles)
	_paint(g, 20, 13, 24, 13, "=")   # plataforma fina
	_paint(g, 36, 12, 37, 17, "#")   # parede perto da borda direita
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
	if _restarting:
		return
	_restarting = true
	await get_tree().create_timer(Tuning.DEATH_RESTART_TIME).timeout
	get_tree().reload_current_scene()


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
	draw_texture_rect(TASKBAR_TEX, Rect2(0, Tuning.SCREEN_H - Tuning.TASKBAR_H, Tuning.SCREEN_W, Tuning.TASKBAR_H), false)
	draw_string(ThemeDB.fallback_font, Vector2(26, Tuning.SCREEN_H - 5),
		"bicudinho.exe", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f2f1ed"))
