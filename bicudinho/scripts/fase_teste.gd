extends Node2D
## Cena de teste dos passos 2 a 4: desktop falso, janela redimensionável com vidro,
## mapa, ícones arrastáveis, bicudinho e a bicudinha. Tudo é montado por código, então
## a cena só precisa deste script no nó raiz.

const COLS := 40
const ROWS := 21
const BICUDINHO_SCENE := preload("res://scenes/bicudinho.tscn")

# Área interna inicial da janela (em px do desktop) e limites de tamanho.
const WINDOW_RECT := Rect2(48, 48, 544, 272)
const WINDOW_MIN := Vector2(160, 112)
const WINDOW_MAX := Vector2(544, 272)

const WALLPAPER_COLOR := Color("4d8f66")
const SKY_COLOR := Color("a4d8ea")
const TASKBAR_TEX := preload("res://art/ui/taskbar.png")

## Ícones da fase de teste (32x32 = 2x2 tiles). Fora da janela só aparecem os arrastáveis
## (e o bloco de notas). A janela deixa 45 px livres de cada lado para caber um ícone.
const ICONS := [
	{"type": "folder", "x": 0, "y": 64, "draggable": true},
	{"type": "folder", "x": 0, "y": 96, "draggable": true},
	{"type": "file", "x": 0, "y": 128, "draggable": true},
	{"type": "notepad", "x": 608, "y": 64, "draggable": false},
	{"type": "virus", "x": 480, "y": 256, "draggable": false},
]
## A saída da fase: o ícone do brejo. Fica no chão, depois do degrau alto.
const EXIT_POS := Vector2(544, 256)
const NOTEPAD_TEXT := "O poço é largo.\nArraste as pastas para dentro da janela e use como degraus."

var win: GameWindow
var tiles: TileWorld
var bird: Bicudinho
var icons: Array[DeskIcon] = []
var exit_icon: DeskIcon
var female: Female

var _restarting := false
var _won := false
var _drag_icon: DeskIcon = null
var _drag_offset := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _notepad: MiniWindow
var _start_menu: StartMenu


func _ready() -> void:
	win = GameWindow.new()
	win.process_physics_priority = -10  # a janela se move antes do bicudinho
	win.setup(WINDOW_RECT, WINDOW_MIN, WINDOW_MAX)

	tiles = TileWorld.new()
	tiles.setup(_build_map())
	add_child(tiles)

	for entry: Dictionary in ICONS:
		_add_icon(entry.type, Vector2(entry.x, entry.y), entry.draggable)
	exit_icon = _add_icon("brejo", EXIT_POS, false)

	# a bicudinha espera no brejo, em pé no chão. Ela É o destino: a árvore e o brilho do
	# ícone não se desenham, mas o ícone continua valendo (chegar nele vence, some se cortado).
	female = Female.new()
	female.position = Vector2(EXIT_POS.x + Tuning.ICON_SIZE / 2.0, EXIT_POS.y + Tuning.ICON_SIZE)
	add_child(female)
	exit_icon.show_art = false

	bird = BICUDINHO_SCENE.instantiate() as Bicudinho
	bird.position = Vector2(72, 288)  # pés sobre o chão (linha 18 do mapa)
	bird.hazard_check = Callable(tiles, "hazard_hit")
	bird.died.connect(_on_bird_died)
	bird.glass_hit.connect(win.add_crack)  # a batida no vidro desenha uma rachadura
	add_child(bird)
	female.target = bird  # a bicudinha sempre encara o bicudinho

	add_child(win)  # a moldura e o vidro desenham por cima do mundo

	_notepad = MiniWindow.new()
	_notepad.title = "notas.txt"
	_notepad.text = NOTEPAD_TEXT
	_notepad.size = Vector2(200, 84)
	_notepad.position = Vector2(400, 60)
	_notepad.visible = false
	add_child(_notepad)  # mini-janela: acima de tudo, fora da regra de ouro

	_start_menu = StartMenu.new()
	add_child(_start_menu)  # por último: o menu fica acima de tudo e pega o clique primeiro

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
	_paint(g, 12, 18, 20, 19, "~")   # poço de rio (9 tiles: só com a disparada ou com pastas)
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


func _add_icon(type: String, pos: Vector2, can_drag: bool) -> DeskIcon:
	var ic := DeskIcon.new()
	ic.setup(type, pos, can_drag)
	add_child(ic)
	icons.append(ic)
	return ic


func _on_rect_changed() -> void:
	tiles.set_interior(win.rect)
	if Tuning.ICON_PUSH_OUT:
		_push_icons_out()
	for ic in icons:
		ic.update_inside(win.rect)
	female.visible = exit_icon.visible  # regra de ouro: ela só existe junto da saída
	bird.enforce_inside(win.rect)
	queue_redraw()


func _on_bird_died(_cause: String) -> void:
	if _restarting:
		return
	_restarting = true
	await get_tree().create_timer(Tuning.DEATH_RESTART_TIME).timeout
	get_tree().reload_current_scene()


# --- Saída da fase (provisório até o passo 6) ---------------------------------

func _physics_process(_delta: float) -> void:
	if _won or bird.dead:
		return
	# a saída só existe (visível) quando está inteira dentro da janela
	if exit_icon.visible and bird.box_rect().intersects(exit_icon.rect()):
		_win_level()


func _win_level() -> void:
	_won = true
	bird.celebrate()  # para e fica feliz
	female.set_happy(true)  # ela também fica feliz e solta um coração
	Audio.play("sfx_win_level")
	queue_redraw()
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()


# --- Mouse --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("ui_cancel") and _notepad.visible:
		_notepad.close()  # Esc fecha a mini-janela (o menu Iniciar já consumiu o Esc dele)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if not event.pressed:
			win.release_button(m)
			_notepad.handle_release(m)
			return
		# ordem de prioridade: mini-janela, botões da janela, ícones, bordas da janela
		if _notepad.visible and _notepad.handle_press(m):
			return
		var btn := win.button_at(m)
		if btn != -1:
			win.press_button(btn)
			Audio.play("sfx_ui_click")
			return
		var ic := _icon_at(m)
		if ic != null:
			if event.double_click and ic.opens() == "notepad":
				_open_notepad()
			elif ic.draggable:
				_start_icon_drag(ic, m)
			return
		var sides := win.side_at(m)
		if sides != 0:
			win.begin_resize(sides, m)
			Audio.play("sfx_ui_click", 0.05, -6.0)


## Botões da janela do jogo: só de enfeite por enquanto. Fechar o jogo "não pode".
func _on_window_button(btn: int) -> void:
	if btn == GameWindow.BTN_CLOSE:
		Audio.play("sfx_window_limit")


func _open_notepad() -> void:
	_notepad.open()
	Audio.play("sfx_window_open")


# --- Ícones: arrastar e largar --------------------------------------------------

func _icon_at(m: Vector2) -> DeskIcon:
	for i in range(icons.size() - 1, -1, -1):
		var ic := icons[i]
		if ic.visible and ic.rect().has_point(m):
			return ic
	return null


func _start_icon_drag(ic: DeskIcon, m: Vector2) -> void:
	_drag_icon = ic
	_drag_offset = m - ic.position
	_drag_origin = ic.position
	ic.dragging = true
	ic.z_index = 20  # acima do vidro enquanto está na mão
	ic.update_inside(win.rect)  # solta a colisão enquanto segura
	Audio.play("sfx_ui_click")


func _end_icon_drag() -> void:
	var ic := _drag_icon
	_drag_icon = null
	var s := Tuning.SNAP
	var max_x := floorf((Tuning.SCREEN_W - Tuning.ICON_SIZE) / s) * s
	var max_y := floorf((Tuning.SCREEN_H - Tuning.TASKBAR_H - Tuning.ICON_SIZE) / s) * s
	var p := Vector2(
		clampf(snappedf(ic.position.x, s), 0.0, max_x),
		clampf(snappedf(ic.position.y, s), 0.0, max_y))
	ic.dragging = false
	ic.z_index = 0
	if p == _drag_origin or _drop_valid(ic, p):
		ic.position = p
		Audio.play("sfx_icon_drop")
	else:
		ic.position = _drag_origin  # lugar proibido: o ícone volta
		Audio.play("sfx_icon_blocked")
	ic.update_inside(win.rect)


## Não pode ser largado na borda da janela, sobre o bicudinho, dentro de parede ou
## sobre outro ícone.
func _drop_valid(ic: DeskIcon, p: Vector2) -> bool:
	var r := Rect2(p, Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE))
	var fully_inside := win.rect.encloses(r)
	if not fully_inside and win.outer_rect().intersects(r):
		return false  # meio dentro, meio fora: na moldura da janela
	if fully_inside:
		if bird.box_rect().intersects(r):
			return false
		if tiles.solid_overlaps(r):
			return false
	for other in icons:
		if other != ic and other.rect().intersects(r):
			return false
	return true


## A janela não engole ícone: se uma borda passa por cima de um ícone arrastável (metade
## dentro, metade fora), ele é empurrado para fora, para o lado mais próximo que esteja livre.
## Ícones inteiros dentro ou inteiros fora não se mexem.
func _push_icons_out() -> void:
	var outer := win.outer_rect()
	var s := Tuning.ICON_SIZE
	for ic in icons:
		if not ic.draggable or ic.dragging:
			continue
		var r := ic.rect()
		if win.rect.encloses(r) or not outer.intersects(r):
			continue
		var candidates: Array[Vector2] = [
			Vector2(outer.position.x - s, r.position.y),  # para a esquerda
			Vector2(outer.end.x, r.position.y),           # para a direita
			Vector2(r.position.x, outer.position.y - s),  # para cima
			Vector2(r.position.x, outer.end.y),           # para baixo
		]
		var best := Vector2.ZERO
		var best_dist := INF
		for c in candidates:
			if _spot_free(ic, c) and c.distance_to(ic.position) < best_dist:
				best = c
				best_dist = c.distance_to(ic.position)
		if best_dist < INF:
			ic.position = best


## O ícone cabe em p: dentro da área do desktop e sem encostar em outro ícone.
func _spot_free(ic: DeskIcon, p: Vector2) -> bool:
	var s := Tuning.ICON_SIZE
	var r := Rect2(p, Vector2(s, s))
	if r.position.x < 0.0 or r.position.y < 0.0 \
			or r.end.x > Tuning.SCREEN_W or r.end.y > Tuning.SCREEN_H - Tuning.TASKBAR_H:
		return false
	for other in icons:
		if other != ic and other.rect().intersects(r):
			return false
	return true


## Algum elemento de interface (menu Iniciar aberto ou mini-janela) está sob o ponto m?
## Aí a janela do jogo e os ícones que ficam por baixo não reagem (nem o cursor muda).
func _ui_covers(m: Vector2) -> bool:
	if _start_menu.is_open:
		var menu := Rect2(
			Vector2(2, Tuning.SCREEN_H - Tuning.TASKBAR_H - StartMenu.MENU_SIZE.y),
			StartMenu.MENU_SIZE)
		if menu.has_point(m):
			return true
	return _notepad.visible and _notepad.outer_rect().has_point(m)


# --- Cada frame ----------------------------------------------------------------

func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	# arrastos por polling: continuam mesmo se o mouse passar por outro nó
	if _drag_icon != null:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drag_icon.position = m - _drag_offset
		else:
			_end_icon_drag()
	elif win.drag_sides != 0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			win.update_resize(m)
		else:
			win.end_resize()
	if _notepad.visible:
		if _notepad.is_dragging() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_notepad.handle_release(m)
		if _notepad.handle_motion(m):
			Audio.play("sfx_ui_hover", 0.05, -4.0)
	# botões da janela: sem hover quando algo da interface está por cima
	if win.update_hover(Vector2(-100, -100) if _ui_covers(m) else m):
		Audio.play("sfx_ui_hover", 0.05, -4.0)
	_update_cursor(m)


func _update_cursor(m: Vector2) -> void:
	var shape := Input.CURSOR_ARROW
	if _drag_icon != null:
		shape = Input.CURSOR_DRAG
	elif _ui_covers(m):
		shape = Input.CURSOR_ARROW  # por cima do menu ou da mini-janela: cursor normal
	else:
		var ic := _icon_at(m)
		if ic != null:
			if ic.draggable or ic.opens() != "":
				shape = Input.CURSOR_POINTING_HAND
		else:
			var sides := win.drag_sides if win.drag_sides != 0 else win.side_at(m)
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
		"Espaço no ar: preparar | setas: mirar | segurar ↑ caindo: planar | R: reiniciar | arraste os ícones",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f2f1ed"))
	if _won:
		draw_string(ThemeDB.fallback_font, Vector2(0, 40), "Fase concluída!",
			HORIZONTAL_ALIGNMENT_CENTER, Tuning.SCREEN_W, 16, Color("f2c14e"))
