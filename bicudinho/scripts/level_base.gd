class_name LevelBase
extends Node2D
## Base de todas as fases. Monta o desktop falso, a janela com vidro, o mapa, os ícones
## arrastáveis, o bicudinho, o objetivo (a bicudinha), as janelas de pasta e de foto, a
## vitória, a morte e o mouse.
##
## COMO CRIAR UMA FASE NOVA
##   1. Crie scripts/fase_0N.gd com `extends LevelBase` e escreva só dois métodos:
##        func _setup_level() -> void:   # os dados da fase (veja a lista abaixo)
##        func _paint_map(g: Array) -> void:   # o mapa, com paint(g, x0, y0, x1, y1, "#")
##   2. Crie scenes/level_0N.tscn: um Node2D com esse script no nó raiz.
##   3. Na fase anterior, ponha `next_level = "res://scenes/level_0N.tscn"`.
## Não escreva _ready() na fase (se precisar, chame super._ready() primeiro).
##
## Legenda do mapa (40x21 tiles de 16 px): #  chão   =  plataforma fina   ~  rio   .  vazio
## Regra de ouro: só existe o que está dentro da janela (tiles, ícones, objetivo, bicudinha).

const COLS := 40
const ROWS := 21
const BICUDINHO_SCENE := preload("res://scenes/bicudinho.tscn")
const TASKBAR_TEX := preload("res://art/ui/taskbar.png")
const WIN_RESTART_TIME := 1.5   # segundos entre chegar no objetivo e ir para a próxima fase

# --- Dados da fase: a fase preenche estes campos em _setup_level() -----------------

## Área interna da janela, em px do desktop. Deixe uma margem de pelo menos
## Tuning.ICON_SIZE + 3 px nos lados onde ficam ícones, senão não dá para largá-los ali.
var window_rect := Rect2(32, 48, 576, 272)
## Tamanho mínimo e máximo da janela. Zero = igual ao window_rect (janela fixa).
var window_min := Vector2.ZERO
var window_max := Vector2.ZERO
## Onde o bicudinho nasce: os pés (o centro da base dele).
var bird_start := Vector2(72, 288)
## Onde fica o objetivo: o centro da base dele, o "chão" em que ele está.
var exit_feet := Vector2(560, 288)
## O que espera na saída:
##   "twig" (o padrão): um graveto. Ele pega e segue para a próxima fase, sem festa.
##   "female": a bicudinha, com os dois felizes (só na última fase).
##   "brejo": o ícone do brejo.
var goal := "twig"
## Ícones do desktop (x e y são px do canto superior esquerdo). Cada um é um dicionário:
##   {"type": "folder", "x": 0, "y": 64, "draggable": true, "label": "nome"}
## Tipos: folder, trash, image, file, app, virus, notepad, viewer, help.
## Duplo clique abre o que o ícone guarda (todos os campos abaixo são opcionais):
##   "contents": [ arquivos ]  -> abre uma janela de pasta com esses arquivos (pode ser [])
##   "photo": "nome"           -> abre uma foto direto (veja arquivos de foto abaixo)
##   "text": "conteúdo"        -> abre um texto direto
## Um arquivo (dentro de "contents") é {"kind": "image", "name": "rio_01.jpg", "photo":
## "rio_01", "caption": "legenda", "credit": "Foto: autor (licença)"} ou
## {"kind": "text", "name": "leia-me.txt", "text": "conteúdo"}.
## As fotos ficam em res://art/photos/<photo>.jpg (ou .png, .webp): reduza antes para no
## máximo uns 480x300 px, para o jogo web não pesar.
var icons_data: Array = []
## Bloco de notas da fase ("" = sem). Abre sozinho se note_open_at_start; para poder abrir de
## novo, ponha um ícone {"type": "notepad", "label": "dica.txt", "draggable": false}.
var note_text := ""
var note_title := "dica.txt"
var note_pos := Vector2(8, 216)
var note_size := Vector2(136, 60)
var note_open_at_start := true
## Texto da barra de tarefas e mensagem que aparece quando vence.
var hint := "Espaço no ar: preparar | setas: mirar | segurar ↑ caindo: planar | R: reiniciar"
## Vazio: o texto padrão do objetivo ("Pegou um graveto!" ou "Achou a bicudinha!").
var win_text := ""
## Próxima fase (caminho da cena). Vazio: recomeça esta (ainda não existe a próxima).
var next_level := ""
var wallpaper_color := Color("4d8f66")
var sky_color := Color("a4d8ea")

# --- Estado -------------------------------------------------------------------------

var win: GameWindow
var tiles: TileWorld
var bird: Bicudinho
var icons: Array[DeskIcon] = []
var panes: Array[GlassPane] = []
var exit_icon: DeskIcon
var female: Female
var twig: Twig

var _restarting := false
var _won := false
var _drag_icon: DeskIcon = null
var _drag_offset := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _start_menu: StartMenu
var _overlay: Node2D   # desenha a sombra de onde o ícone vai cair
## Janelas de interface (bloco de notas, pastas, foto, texto). A última está por cima.
var _windows: Array[MiniWindow] = []
## Mini-janela em que o bicudinho pisou por último (ele desenha logo acima dela), ou null.
var _bird_window: MiniWindow = null
var _notepad: MiniWindow = null
var _viewer: PhotoWindow = null
var _text_window: MiniWindow = null
var _folder_windows: Dictionary = {}   # DeskIcon -> FolderWindow


## A fase sobrescreve: preenche os campos acima.
func _setup_level() -> void:
	pass


## A fase sobrescreve: pinta o mapa com paint(g, x0, y0, x1, y1, "#").
func _paint_map(_g: Array) -> void:
	pass


func _ready() -> void:
	_setup_level()
	if window_min == Vector2.ZERO:
		window_min = window_rect.size
	if window_max == Vector2.ZERO:
		window_max = window_rect.size

	win = GameWindow.new()
	win.process_physics_priority = -10  # a janela se move antes do bicudinho
	win.setup(window_rect, window_min, window_max)

	tiles = TileWorld.new()
	tiles.setup(_build_map())
	add_child(tiles)

	for spot in tiles.glass_spots:
		var pane := GlassPane.new()
		pane.position = spot
		add_child(pane)
		panes.append(pane)

	for entry: Dictionary in icons_data:
		_add_icon_from_data(entry)

	var s := Tuning.ICON_SIZE
	exit_icon = _add_icon("brejo", Vector2(exit_feet.x - s / 2.0, exit_feet.y - s), false)
	# o graveto ou a bicudinha É o destino: a árvore não se desenha, mas o ícone continua
	# valendo (chegar nele vence, e some se a janela o cortar)
	if goal == "female":
		female = Female.new()
		female.position = exit_feet
		add_child(female)
		exit_icon.show_art = false
	elif goal == "twig":
		twig = Twig.new()
		twig.position = exit_feet
		add_child(twig)
		exit_icon.show_art = false

	bird = BICUDINHO_SCENE.instantiate() as Bicudinho
	bird.position = bird_start
	bird.hazard_check = Callable(tiles, "hazard_hit")
	bird.died.connect(_on_bird_died)
	bird.glass_hit.connect(win.add_crack)  # a batida no vidro desenha uma rachadura
	bird.lives_changed.connect(win.set_lives)  # penas na barra de título da janela
	win.set_lives(bird.lives)
	add_child(bird)
	if female != null:
		female.target = bird  # a bicudinha sempre encara o bicudinho

	add_child(win)  # a moldura e o vidro desenham por cima do mundo

	_overlay = Node2D.new()
	_overlay.z_index = 19  # acima do vidro, abaixo do ícone na mão (z 20)
	_overlay.draw.connect(_draw_drop_shadow)
	add_child(_overlay)

	_start_menu = StartMenu.new()
	add_child(_start_menu)  # o menu fica acima de tudo e pega o clique primeiro

	if note_text != "":
		_notepad = MiniWindow.new()
		_notepad.title = note_title
		_notepad.text = note_text
		_notepad.size = note_size
		_notepad.position = note_pos
		_register_window(_notepad)
		_notepad.visible = note_open_at_start

	win.rect_changed.connect(_on_rect_changed)
	win.hit_limit.connect(Audio.play.bind("sfx_window_limit"))
	win.button_pressed.connect(_on_window_button)
	_on_rect_changed()
	Audio.resume_music()  # a vitória para a música; ao recomeçar, ela volta


# --- Mapa ---------------------------------------------------------------------------

func _build_map() -> PackedStringArray:
	var g: Array = []
	for y in ROWS:
		var row: Array = []
		row.resize(COLS)
		row.fill(".")
		g.append(row)
	_paint_map(g)
	var rows := PackedStringArray()
	for row in g:
		rows.append("".join(row))
	return rows


## Pinta um retângulo de tiles (colunas x0..x1, linhas y0..y1, inclusive) com o caractere ch.
func paint(g: Array, x0: int, y0: int, x1: int, y1: int, ch: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			g[y][x] = ch


# --- Ícones -------------------------------------------------------------------------

func _add_icon(type: String, pos: Vector2, can_drag: bool, label := "") -> DeskIcon:
	var ic := DeskIcon.new()
	ic.setup(type, pos, can_drag, label)
	add_child(ic)
	icons.append(ic)
	return ic


## Cria um ícone a partir de uma entrada de icons_data (inclui o que ele abre).
func _add_icon_from_data(entry: Dictionary) -> void:
	var label := str(entry.get("label", ""))
	var ic := _add_icon(str(entry.type), Vector2(float(entry.x), float(entry.y)),
		bool(entry.get("draggable", true)), label)
	if entry.has("contents"):
		ic.is_container = true
		ic.contents = entry.contents
	elif entry.has("photo"):
		ic.file_data = {"kind": "image", "name": label, "photo": entry.photo,
			"caption": entry.get("caption", ""), "credit": entry.get("credit", "")}
	elif entry.has("text"):
		ic.file_data = {"kind": "text", "name": label, "text": entry.text}


func _on_rect_changed() -> void:
	tiles.set_interior(win.rect)
	for pane in panes:
		pane.update_inside(win.rect)
	if Tuning.ICON_PUSH_OUT:
		_push_icons_out()
	for ic in icons:
		ic.update_inside(win.rect)
	if female != null:
		female.visible = exit_icon.visible  # regra de ouro: ela só existe junto do objetivo
	if twig != null:
		twig.visible = exit_icon.visible
	bird.enforce_inside(win.rect)
	queue_redraw()


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
	Audio.play("sfx_ui_click", 0.05, -6.0)


## Onde o ícone cairia: encaixado na grade de 16 px e dentro da tela.
func _snap_drop(pos: Vector2) -> Vector2:
	var s := Tuning.SNAP
	var max_x := floorf((Tuning.SCREEN_W - Tuning.ICON_SIZE) / s) * s
	var max_y := floorf((Tuning.SCREEN_H - Tuning.TASKBAR_H - Tuning.ICON_SIZE) / s) * s
	return Vector2(
		clampf(snappedf(pos.x, s), 0.0, max_x),
		clampf(snappedf(pos.y, s), 0.0, max_y))


func _end_icon_drag() -> void:
	var ic := _drag_icon
	_drag_icon = null
	var p := _snap_drop(ic.position)
	ic.dragging = false
	ic.z_index = 0
	if p == _drag_origin or _drop_valid(ic, p):
		ic.position = p
		Audio.play("sfx_ui_click", 0.05, -3.0)
	else:
		ic.position = _drag_origin  # lugar proibido: o ícone volta
		Audio.play("sfx_window_limit")
	ic.update_inside(win.rect)
	_overlay.queue_redraw()


## Não pode ser largado na borda da janela, sobre o bicudinho, dentro de terra, sobre o
## objetivo ou sobre outro ícone.
func _drop_valid(ic: DeskIcon, p: Vector2) -> bool:
	var r := Rect2(p, Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE))
	var fully_inside := win.rect.encloses(r)
	if not fully_inside and win.outer_rect().intersects(r):
		return false  # meio dentro, meio fora: na moldura da janela
	if fully_inside:
		if bird.box_rect().intersects(r) or r.intersects(exit_icon.rect()):
			return false
		if tiles.solid_overlaps(r):
			return false
		for pane in panes:
			if not pane.broken and pane.rect().intersects(r):
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


## A sombra de onde o ícone vai cair: verde pode largar, vermelho não.
func _draw_drop_shadow() -> void:
	if _drag_icon == null:
		return
	var p := _snap_drop(_drag_icon.position)
	var ok := p == _drag_origin or _drop_valid(_drag_icon, p)
	var shadow := Color(0.3, 1, 0.4, 0.45) if ok else Color(1, 0.3, 0.3, 0.45)
	_overlay.draw_rect(Rect2(p, Vector2(Tuning.ICON_SIZE, Tuning.ICON_SIZE)), shadow)


# --- Janelas de interface: notas, pastas, fotos e textos ----------------------------

## Põe a janela na cena e na lista (por cima das outras). O menu Iniciar continua no topo.
func _register_window(w: MiniWindow) -> void:
	_windows.append(w)
	add_child(w)
	_keep_menu_on_top()
	_restack()


func _keep_menu_on_top() -> void:
	if _start_menu != null:
		move_child(_start_menu, get_child_count() - 1)


## Traz a janela para a frente de todas as outras.
func _raise(w: MiniWindow) -> void:
	_windows.erase(w)
	_windows.append(w)
	move_child(w, get_child_count() - 1)
	_keep_menu_on_top()
	_restack()


## Empilha as mini-janelas de 2 em 2 no z (100, 102, 104...): o vão entre elas é onde o
## bicudinho entra quando está em cima de uma (veja _update_bird_layer).
func _restack() -> void:
	for i in _windows.size():
		_windows[i].z_index = 100 + 2 * i
	_update_bird_layer()


## O bicudinho fica atrás das mini-janelas, como o resto do jogo. Só quando pisa no topo de
## uma ele passa a desenhar logo acima dela (e abaixo das que estão por cima dela). Continua
## assim no ar até pousar em outra coisa.
func _update_bird_layer() -> void:
	if bird == null:
		return
	if bird.is_on_floor():
		_bird_window = null
		for i in bird.get_slide_collision_count():
			var col := bird.get_slide_collision(i)
			if col.get_normal().y > -0.5:
				continue
			for w in _windows:
				if col.get_collider() == w.platform_body:
					_bird_window = w
	if _bird_window != null and not _bird_window.visible:
		_bird_window = null
	bird.z_index = _bird_window.z_index + 1 if _bird_window != null else 0


## A janela aberta que está por cima, ou null.
func _top_window() -> MiniWindow:
	for i in range(_windows.size() - 1, -1, -1):
		if _windows[i].visible:
			return _windows[i]
	return null


## Cascata: cada janela aberta nova aparece um pouco mais abaixo e à direita.
func _place_window(w: MiniWindow) -> void:
	var open_count := 0
	for other in _windows:
		if other != w and other.visible:
			open_count += 1
	var o := w.outer_rect().size
	var pos := Vector2(200, 70) + Vector2(18, 16) * open_count
	pos.x = clampf(pos.x, 0.0, Tuning.SCREEN_W - o.x)
	pos.y = clampf(pos.y, 0.0, Tuning.SCREEN_H - Tuning.TASKBAR_H - o.y)
	w.position = pos


func _open_icon(ic: DeskIcon) -> void:
	match ic.opens():
		"notepad":
			_open_notepad()
		"folder":
			_open_folder(ic)
		"file":
			_open_file(ic.file_data)


func _open_notepad() -> void:
	if _notepad == null:
		return
	_notepad.open()
	_raise(_notepad)
	Audio.play("sfx_window_open")


func _open_folder(ic: DeskIcon) -> void:
	var fw: FolderWindow = _folder_windows.get(ic)
	if fw == null:
		fw = FolderWindow.new()
		fw.file_opened.connect(_open_file)
		_register_window(fw)
		fw.setup_files(ic.label if ic.label != "" else "pasta", ic.contents)
		_place_window(fw)
		_folder_windows[ic] = fw
	fw.open()
	_raise(fw)
	Audio.play("sfx_window_open")


## Abre um arquivo (de uma pasta ou de um ícone direto): foto no visualizador, texto no bloco.
func _open_file(file: Dictionary) -> void:
	match str(file.get("kind", "image")):
		"image":
			_open_photo(file)
		"text":
			_open_text(file)


func _open_photo(file: Dictionary) -> void:
	var first := _viewer == null
	if first:
		_viewer = PhotoWindow.new()
		_register_window(_viewer)
	_viewer.show_photo(str(file.get("photo", "")), str(file.get("caption", "")),
		str(file.get("credit", "")), str(file.get("name", "foto")))
	if first or not _viewer.visible:
		_place_window(_viewer)
	_viewer.open()
	_raise(_viewer)
	Audio.play("sfx_window_open")


func _open_text(file: Dictionary) -> void:
	var first := _text_window == null
	if first:
		_text_window = MiniWindow.new()
		_register_window(_text_window)
	var text := str(file.get("text", ""))
	_text_window.title = str(file.get("name", "texto.txt"))
	_text_window.text = text
	var text_h := ThemeDB.fallback_font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, 188.0, 8).y
	_text_window.size = Vector2(200, maxf(50.0, text_h + MiniWindow.PAD * 2.0 + 6.0))
	if first or not _text_window.visible:
		_place_window(_text_window)
	_text_window.open()
	_raise(_text_window)
	Audio.play("sfx_window_open")


# --- Objetivo, vitória e morte ----------------------------------------------------------

func _physics_process(_delta: float) -> void:
	for w in _windows:
		w.update_platform(win.rect)  # o topo das mini-janelas é plataforma
	_update_bird_layer()
	if _won or _restarting or bird.dead:
		return
	# o objetivo só existe (visível) quando está inteiro dentro da janela
	if exit_icon.visible and bird.box_rect().intersects(exit_icon.rect()):
		_win_level()


func _win_level() -> void:
	_won = true
	if female != null:
		bird.celebrate()  # última fase: para e fica feliz
		female.set_happy(true)  # ela também fica feliz e solta um coração
	else:
		bird.celebrate(false)  # pega o graveto e para, sem festa
		if twig != null:
			twig.pick_up()
	Audio.stop_music()
	Audio.play("sfx_win_level", 0.0, Tuning.WIN_VOLUME_DB)
	queue_redraw()
	await get_tree().create_timer(WIN_RESTART_TIME).timeout
	if next_level != "":
		get_tree().change_scene_to_file(next_level)
	else:
		get_tree().reload_current_scene()  # sem próxima fase ainda: recomeça


func _on_bird_died(_cause: String) -> void:
	if _restarting or _won:
		return
	_restarting = true
	await get_tree().create_timer(Tuning.DEATH_RESTART_TIME).timeout
	get_tree().reload_current_scene()


# --- Mouse e teclado --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("ui_cancel"):
		var top := _top_window()
		if top != null:
			top.close()  # Esc fecha a janela de cima (o menu Iniciar já consumiu o Esc dele)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if not event.pressed:
			win.release_button(m)
			for w in _windows:
				var was_dragging := w.is_dragging()
				w.handle_release(m)
				# o topo virou chão em cima do bicudinho: lugar proibido, a janela volta
				if was_dragging and w.platform_rect(win.rect).intersects(bird.box_rect()):
					w.position = w.drag_start
					Audio.play("sfx_window_limit")
			return
		# ordem de prioridade: janelas de interface (a de cima primeiro), botões da janela do
		# jogo, ícones, bordas da janela do jogo
		for i in range(_windows.size() - 1, -1, -1):
			var w := _windows[i]
			if w.handle_press(m):
				_raise(w)
				return
		var btn := win.button_at(m)
		if btn != -1:
			win.press_button(btn)
			Audio.play("sfx_ui_click")
			return
		var ic := _icon_at(m)
		if ic != null:
			if event.double_click and ic.opens() != "":
				_open_icon(ic)
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


## Algum elemento de interface (menu Iniciar aberto ou janela) está sob o ponto m?
## Aí a janela do jogo e os ícones que ficam por baixo não reagem (nem o cursor muda).
func _ui_covers(m: Vector2) -> bool:
	if _start_menu.is_open:
		var menu := Rect2(
			Vector2(2, Tuning.SCREEN_H - Tuning.TASKBAR_H - StartMenu.MENU_SIZE.y),
			StartMenu.MENU_SIZE)
		if menu.has_point(m):
			return true
	for w in _windows:
		if w.visible and w.outer_rect().has_point(m):
			return true
	return false


func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	# arrastos por polling: continuam mesmo se o mouse passar por outro nó
	if _drag_icon != null:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drag_icon.position = m - _drag_offset
			_overlay.queue_redraw()
		else:
			_end_icon_drag()
	elif win.drag_sides != 0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			win.update_resize(m)
		else:
			win.end_resize()
	for w in _windows:
		if not w.visible:
			continue
		if w.is_dragging() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			w.handle_release(m)
		if w.handle_motion(m):
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
		shape = Input.CURSOR_ARROW  # por cima do menu ou de uma janela: cursor normal
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


# --- Fundo: desktop falso -----------------------------------------------------------

func _draw() -> void:
	var area := Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H - Tuning.TASKBAR_H)
	draw_rect(area, wallpaper_color)
	draw_rect(win.rect, sky_color)  # o céu só existe dentro da janela
	draw_texture_rect(TASKBAR_TEX, Rect2(0, Tuning.SCREEN_H - Tuning.TASKBAR_H, Tuning.SCREEN_W, Tuning.TASKBAR_H), false)
	draw_string(ThemeDB.fallback_font, Vector2(26, Tuning.SCREEN_H - 5), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f2f1ed"))
	var text := win_text
	if text == "":
		text = "Achou a bicudinha!" if goal == "female" else "Pegou um graveto!"
	if _won:
		draw_string(ThemeDB.fallback_font, win.rect.get_center() + Vector2(-60, -40), text,
			HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color("2f3a8f"))

