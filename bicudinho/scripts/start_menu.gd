class_name StartMenu
extends Node2D
## Botão Iniciar (losango) na barra de tarefas e o menu que ele abre:
## Shutdown (desliga o jogo), Sound (liga/desliga o som), Music (só a música) e Restart
## (reinicia a fase).
## Fica acima de tudo e consome os cliques que pegar.

const TEX_START := preload("res://art/ui/start_button.png")
const TEX_ICONS := preload("res://art/ui/startmenu_icons.png")   # desligar, alto-falante, reiniciar
const TEX_PANEL := preload("res://art/ui/window_border.png")
const TEX_LIST := preload("res://art/ui/minwin_frame.png")

enum { ITEM_SHUTDOWN, ITEM_SOUND, ITEM_MUSIC, ITEM_RESTART }
const ITEM_COUNT := 4
## Ícone de cada item em startmenu_icons.png (-1 = desenhado por código: a nota da música).
const ITEM_ICON := [0, 1, -1, 2]
const MENU_SIZE := Vector2(132, 100)
const ITEM_H := 22.0
const TEXT_COLOR := Color("f2f1ed")
const HOVER_COLOR := Color("65dcd6")   # ciano dos botões em hover
const DOT_COLORS := [Color("d85525"), Color("66993a"), Color("c0bfbd"),
	Color("2ba5d1"), Color("edbc55"), Color("c0bfbd")]

var is_open := false
var _hover := -1             # item do menu sob o mouse
var _hover_start := false
var _shut_down := false      # tela de "pode desligar" (no navegador o jogo não fecha)
var _panel_style: StyleBoxTexture
var _list_style: StyleBoxTexture


func _ready() -> void:
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel_style = StyleBoxTexture.new()
	_panel_style.texture = TEX_PANEL
	_list_style = StyleBoxTexture.new()
	_list_style.texture = TEX_LIST
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_panel_style.set_texture_margin(side, 4)
		_list_style.set_texture_margin(side, 3)
	_list_style.set_texture_margin(SIDE_TOP, 0)


func _start_rect() -> Rect2:
	return Rect2(4, Tuning.SCREEN_H - Tuning.TASKBAR_H + 2, 16, 16)


func _menu_rect() -> Rect2:
	return Rect2(Vector2(2, Tuning.SCREEN_H - Tuning.TASKBAR_H - MENU_SIZE.y), MENU_SIZE)


func _item_rect(i: int) -> Rect2:
	var m := _menu_rect()
	return Rect2(m.position.x + 60, m.position.y + 6 + i * ITEM_H, MENU_SIZE.x - 64, 18)


func _item_at(p: Vector2) -> int:
	if not is_open:
		return -1
	for i in ITEM_COUNT:
		if _item_rect(i).has_point(p):
			return i
	return -1


func _process(_delta: float) -> void:
	var m := get_global_mouse_position()
	var item := _item_at(m)
	var start := _start_rect().has_point(m)
	if (item != _hover and item != -1) or (start and not _hover_start):
		Audio.play("sfx_ui_hover", 0.05, -4.0)
	if item != _hover or start != _hover_start:
		_hover = item
		_hover_start = start
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _shut_down:
		# qualquer clique ou tecla "liga o computador" de novo
		if (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
			get_viewport().set_input_as_handled()
			get_tree().paused = false
			get_tree().reload_current_scene()
		return
	if is_open and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if _start_rect().has_point(p):
		Audio.play("sfx_ui_click")
		_set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open:
		var item := _item_at(p)
		if item != -1:
			Audio.play("sfx_ui_click")
			_activate(item)
		elif not _menu_rect().has_point(p):
			_set_open(false)   # clicou fora: fecha o menu e deixa o clique seguir
			return
		get_viewport().set_input_as_handled()


func _set_open(v: bool) -> void:
	is_open = v
	queue_redraw()


func _activate(item: int) -> void:
	match item:
		ITEM_SHUTDOWN:
			_shutdown()
		ITEM_SOUND:
			Audio.toggle_mute()
			queue_redraw()
		ITEM_MUSIC:
			Audio.set_music_on(not Audio.is_music_on())
			queue_redraw()
		ITEM_RESTART:
			get_tree().reload_current_scene()


func _shutdown() -> void:
	is_open = false
	if OS.has_feature("web"):
		# no navegador não dá para fechar a aba: mostra a tela clássica de desligado
		_shut_down = true
		AudioServer.set_bus_mute(0, true)
		get_tree().paused = true
		queue_redraw()
	else:
		get_tree().quit()


func _draw() -> void:
	if _shut_down:
		draw_rect(Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H), Color.BLACK)
		var msg := "It's now safe to turn off your computer."
		draw_string(ThemeDB.fallback_font, Vector2(0, Tuning.SCREEN_H / 2.0), msg,
			HORIZONTAL_ALIGNMENT_CENTER, Tuning.SCREEN_W, 8, Color("edbc55"))
		draw_string(ThemeDB.fallback_font, Vector2(0, Tuning.SCREEN_H / 2.0 + 16), "(click to restart)",
			HORIZONTAL_ALIGNMENT_CENTER, Tuning.SCREEN_W, 8, Color("c0bfbd"))
		return

	# botão Iniciar (desce 1 px quando o menu está aberto)
	var s := _start_rect()
	if is_open:
		s.position.y += 1
	draw_texture(TEX_START, s.position)
	if _hover_start and not is_open:
		draw_rect(s.grow(1), HOVER_COLOR, false, 1.0)

	if not is_open:
		return
	var m := _menu_rect()
	draw_style_box(_panel_style, m)

	# lista branca à esquerda, com bolinhas coloridas (decorativa por enquanto)
	var list := Rect2(m.position + Vector2(6, 6), Vector2(50, m.size.y - 12))
	draw_style_box(_list_style, list)
	draw_rect(Rect2(list.position, Vector2(list.size.x, 1)), Color.BLACK)
	for i in DOT_COLORS.size():
		var y := list.position.y + 6 + i * 10.0
		var x := list.position.x + 6
		draw_rect(Rect2(x + 1, y, 3, 5), DOT_COLORS[i])
		draw_rect(Rect2(x, y + 1, 5, 3), DOT_COLORS[i])
		draw_rect(Rect2(x + 9, y + 1, 28, 3), Color("c0bfbd"))

	# itens: ícone 16x16 + texto
	var labels := ["Shutdown", "Sound on" if Audio.is_muted() else "Sound off",
		"Music on" if not Audio.is_music_on() else "Music off", "Restart"]
	for i in ITEM_COUNT:
		var r := _item_rect(i)
		if ITEM_ICON[i] >= 0:
			draw_texture_rect_region(TEX_ICONS, Rect2(r.position + Vector2(1, 1), Vector2(16, 16)),
				Rect2(ITEM_ICON[i] * 16, 0, 16, 16))
		else:
			_draw_music_icon(r.position + Vector2(1, 1), Audio.is_music_on())
		if i == ITEM_SOUND and Audio.is_muted():
			# X vermelho por cima das ondas do alto-falante
			var c := r.position + Vector2(10, 4)
			for k in 5:
				draw_rect(Rect2(c + Vector2(k, k), Vector2(1, 1)), Color("d85525"))
				draw_rect(Rect2(c + Vector2(4 - k, k), Vector2(1, 1)), Color("d85525"))
		var col := HOVER_COLOR if i == _hover else TEXT_COLOR
		draw_string(ThemeDB.fallback_font, r.position + Vector2(21, 13), labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## Ícone da música no estilo dos outros (quadrado colorido 16x16): uma nota branca, com um
## X vermelho quando a música está desligada.
func _draw_music_icon(at: Vector2, on: bool) -> void:
	draw_rect(Rect2(at, Vector2(16, 16)), Color("2f3a8f"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(14, 14)), Color("edbc55"))
	var o := at + Vector2(4, 3)
	draw_rect(Rect2(o + Vector2(5, 0), Vector2(1, 8)), Color.WHITE)    # haste
	draw_rect(Rect2(o + Vector2(6, 0), Vector2(3, 2)), Color.WHITE)    # bandeirinha
	draw_rect(Rect2(o + Vector2(2, 7), Vector2(4, 3)), Color.WHITE)    # cabeça da nota
	if not on:
		var c := at + Vector2(10, 4)
		for k in 5:
			draw_rect(Rect2(c + Vector2(k, k), Vector2(1, 1)), Color("d85525"))
			draw_rect(Rect2(c + Vector2(4 - k, k), Vector2(1, 1)), Color("d85525"))
