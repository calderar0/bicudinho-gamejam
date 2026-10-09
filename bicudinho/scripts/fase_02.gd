extends Node2D
## Fase 2, Arrasta. Ensina que ícones do desktop viram chão dentro da janela. Janela fixa.
## Tudo é montado por código, então a cena só precisa deste script no nó raiz.
##
## A janela mostra as colunas 10 a 37 e as linhas 4 a 17. O chão fica na linha 16.
##   10-16  chão de partida
##   17-30  rio de 14 tiles
##   31-37  barranco de 8 tiles de altura com a saída
## Sem ajuda é impossível: pulo + disparada sobe ~9 tiles mas só anda ~7 para o lado,
## e planar ganha distância perdendo altura. Uma pasta no meio do rio, uns 4 tiles
## acima do chão, resolve (com disparadas); duas pastas deixam fácil.
##
## Ícones: fora da janela são só ícones do desktop (com nome embaixo). Dentro da
## janela viram um bloco sólido de 1 tile. Arrastar solta na grade de 16 px.

const COLS := 40
const ROWS := 21
const BICUDINHO_SCENE := preload("res://scenes/bicudinho.tscn")

# Área interna da janela (em px do desktop). Mínimo = máximo: janela fixa na fase 2.
const WINDOW_RECT := Rect2(160, 64, 448, 224)
const WINDOW_MIN := Vector2(448, 224)
const WINDOW_MAX := Vector2(448, 224)
const BIRD_START := Vector2(200, 256)  # pés sobre o chão (linha 16 do mapa)

const EXIT_CELL := Vector2i(34, 7)    # tile do icon_brejo (em cima do barranco)
const EXIT_COLOR := Color("2f7d3a")
const EXIT_REED := Color("c9a86a")
const WIN_RESTART_TIME := 1.5

## Ícones do desktop: tipo, célula (coluna, linha) e nome.
const ICONS := [
	{"type": "folder", "cell": Vector2i(1, 2), "label": "fotos_rio"},
	{"type": "folder", "cell": Vector2i(1, 6), "label": "lixo"},
	{"type": "image", "cell": Vector2i(1, 10), "label": "brejo.png"},
]

# Bloco de notas com a pista (fecha no X, arrasta pela barra).
const NOTE_POS := Vector2(8, 216)
const NOTE_SIZE := Vector2(136, 60)
const NOTE_TEXT := "Os ícones do desktop viram chão dentro da janela.\nArraste uma pasta!"

const WALLPAPER_COLOR := Color("4d8f66")
const SKY_COLOR := Color("a4d8ea")
const TASKBAR_TEX := preload("res://art/ui/taskbar.png")

var win: GameWindow
var tiles: TileWorld
var bird: Bicudinho
var note: MiniWindow
var overlay: Node2D          # desenha o ícone sendo arrastado por cima de tudo
var icons: Array = []        # {type, cell, label, shape}
var _drag := -1              # índice do ícone sendo arrastado, -1 = nenhum
var _drag_offset := Vector2.ZERO
var _drag_pos := Vector2.ZERO
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

	_build_icons()

	bird = BICUDINHO_SCENE.instantiate() as Bicudinho
	bird.position = BIRD_START
	bird.hazard_check = Callable(tiles, "hazard_hit")
	bird.died.connect(_on_bird_died)
	bird.glass_hit.connect(win.add_crack)  # a batida no vidro desenha uma rachadura
	add_child(bird)

	add_child(win)  # a moldura e o vidro desenham por cima do mundo

	overlay = Node2D.new()
	overlay.z_index = 90
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	note = MiniWindow.new()
	note.title = "dica.txt"
	note.text = NOTE_TEXT
	note.size = NOTE_SIZE
	note.position = NOTE_POS
	add_child(note)

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
	_paint(g, 0, 16, 39, 17, "#")    # chão
	_paint(g, 17, 16, 30, 17, "~")   # rio (14 tiles)
	_paint(g, 31, 8, 39, 15, "#")    # barranco da saída (8 tiles)
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
	_update_icon_shapes()
	queue_redraw()


func _on_bird_died(_cause: String) -> void:
	if _restarting or _won:
		return
	_restarting = true
	await get_tree().create_timer(Tuning.DEATH_RESTART_TIME).timeout
	get_tree().reload_current_scene()


# --- Ícones -------------------------------------------------------------------

func _build_icons() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1   # mundo: o bicudinho pisa e a quina funciona
	body.collision_mask = 0
	add_child(body)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Tuning.TILE, Tuning.TILE)
	for data in ICONS:
		var cs := CollisionShape2D.new()
		cs.shape = shape
		body.add_child(cs)
		icons.append({"type": data.type, "cell": data.cell, "label": data.label, "shape": cs})


func _icon_rect(i: int) -> Rect2:
	return _cell_rect(icons[i].cell)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * Tuning.TILE, Vector2(Tuning.TILE, Tuning.TILE))


## Regra de ouro: o ícone só é chão se estiver inteiro dentro da janela (e não sendo arrastado).
func _icon_solid(i: int) -> bool:
	return i != _drag and win.rect.encloses(_icon_rect(i))


func _update_icon_shapes() -> void:
	for i in icons.size():
		var cs: CollisionShape2D = icons[i].shape
		cs.position = _icon_rect(i).get_center()
		cs.disabled = not _icon_solid(i)


func _icon_at(p: Vector2) -> int:
	for i in range(icons.size() - 1, -1, -1):
		if _icon_rect(i).has_point(p):
			return i
	return -1


func _drop_cell() -> Vector2i:
	var center := _drag_pos + Vector2(Tuning.TILE, Tuning.TILE) / 2.0
	return Vector2i((center / Tuning.TILE).floor())


## Pode largar aqui? Não pode na moldura da janela, em cima de terra, do bicudinho,
## da saída, de outro ícone, nem na barra de tarefas.
func _can_drop(cell: Vector2i, i: int) -> bool:
	var r := _cell_rect(cell)
	var desktop := Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H - Tuning.TASKBAR_H)
	if not desktop.encloses(r):
		return false
	var inside := win.rect.encloses(r)
	if not inside and win.outer_rect().intersects(r):
		return false  # metade dentro, ou em cima da moldura e da barra de título
	if inside:
		for c in tiles.cells:
			if c.ch != "~" and (c.rect as Rect2).intersects(r):
				return false
		if r.intersects(bird.box_rect()) or r.intersects(_exit_rect()):
			return false
	for j in icons.size():
		if j != i and icons[j].cell == cell:
			return false
	return true


func _start_drag(i: int, m: Vector2) -> void:
	_drag = i
	_drag_offset = _icon_rect(i).position - m
	_drag_pos = _icon_rect(i).position
	_update_icon_shapes()
	Audio.play("sfx_ui_click", 0.05, -6.0)


func _end_drag() -> void:
	var cell := _drop_cell()
	if _can_drop(cell, _drag):
		icons[_drag].cell = cell
		Audio.play("sfx_ui_click", 0.05, -3.0)
	else:
		Audio.play("sfx_window_limit")  # volta para onde estava
	_drag = -1
	_update_icon_shapes()


# --- Saída (icon_brejo) -------------------------------------------------------

func _exit_rect() -> Rect2:
	return _cell_rect(EXIT_CELL)


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
	get_tree().reload_current_scene()  # sem fase 3 ainda: recomeça


# --- Mouse --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if not event.pressed:
			note.handle_release(m)
			win.release_button(m)
			return
		if note.handle_press(m):
			return
		var btn := win.button_at(m)
		if btn != -1:
			win.press_button(btn)
			Audio.play("sfx_ui_click")
			return
		var icon := _icon_at(m)
		if icon != -1:
			_start_drag(icon, m)
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
	# arrastos lidos por polling, para não travar se o mouse passar por outro nó
	if _drag != -1:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drag_pos = m + _drag_offset
		else:
			_end_drag()
	if win.drag_sides != 0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			win.update_resize(m)
		else:
			win.end_resize()
	if note.handle_motion(m):
		Audio.play("sfx_ui_hover", 0.05, -4.0)
	if win.update_hover(m):
		Audio.play("sfx_ui_hover", 0.05, -4.0)
	_update_cursor(m)
	queue_redraw()  # a saída pisca
	overlay.queue_redraw()


func _update_cursor(m: Vector2) -> void:
	if _drag != -1:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		return
	if _icon_at(m) != -1:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		return
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


# --- Desenho ------------------------------------------------------------------

func _draw() -> void:
	var area := Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H - Tuning.TASKBAR_H)
	draw_rect(area, WALLPAPER_COLOR)
	draw_rect(win.rect, SKY_COLOR)  # o céu só existe dentro da janela
	for i in icons.size():
		if i == _drag:
			continue
		var r := _icon_rect(i)
		if _icon_solid(i):
			_draw_icon(self, r.position, icons[i].type, true)
		else:
			_draw_icon(self, r.position, icons[i].type, false)
			_draw_label(r.position, icons[i].label)
	_draw_exit()
	draw_texture_rect(TASKBAR_TEX, Rect2(0, Tuning.SCREEN_H - Tuning.TASKBAR_H, Tuning.SCREEN_W, Tuning.TASKBAR_H), false)
	draw_string(ThemeDB.fallback_font, Vector2(26, Tuning.SCREEN_H - 5),
		"Mouse: arrastar ícones | Espaço no ar: preparar | ↑ caindo: planar | R: reiniciar",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f2f1ed"))


## O ícone sendo arrastado e a sombra de onde ele vai cair (verde pode, vermelho não).
func _draw_overlay() -> void:
	if _drag == -1:
		return
	var cell := _drop_cell()
	var ok := _can_drop(cell, _drag)
	var shadow := Color(0.3, 1, 0.4, 0.45) if ok else Color(1, 0.3, 0.3, 0.45)
	overlay.draw_rect(_cell_rect(cell), shadow)
	_draw_icon(overlay, _drag_pos, icons[_drag].type, false)


## Placeholders do icon_folder e do icon_image. `solid` desenha o contorno de bloco.
func _draw_icon(canvas: CanvasItem, pos: Vector2, type: String, solid: bool) -> void:
	match type:
		"folder":
			canvas.draw_rect(Rect2(pos + Vector2(1, 3), Vector2(6, 3)), Color("d9a43c"))
			canvas.draw_rect(Rect2(pos + Vector2(1, 5), Vector2(14, 10)), Color("f2c75c"))
			canvas.draw_rect(Rect2(pos + Vector2(1, 14), Vector2(14, 1)), Color("b8862e"))
		"image":
			canvas.draw_rect(Rect2(pos + Vector2(1, 2), Vector2(14, 12)), Color("f2f1ed"))
			canvas.draw_rect(Rect2(pos + Vector2(2, 3), Vector2(12, 10)), Color("a4d8ea"))
			canvas.draw_rect(Rect2(pos + Vector2(2, 9), Vector2(12, 4)), Color("5aad4e"))
			canvas.draw_rect(Rect2(pos + Vector2(10, 4), Vector2(2, 2)), Color("f2d64c"))
	if solid:
		canvas.draw_rect(Rect2(pos, Vector2(Tuning.TILE, Tuning.TILE)), Color(0, 0, 0, 0.6), false, 1.0)


func _draw_label(pos: Vector2, label: String) -> void:
	var font := ThemeDB.fallback_font
	var at := pos + Vector2(-16, 26)
	draw_string(font, at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, 48, 8, Color(0, 0, 0, 0.6))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 48, 8, Color("f2f1ed"))


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
