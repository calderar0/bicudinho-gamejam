class_name MiniWindow
extends Node2D
## Mini-janela (bloco de notas): moldura, barra de título, botão de fechar,
## arrastável pela barra. Fica acima de tudo. O topo é uma plataforma de mão única
## (pula por baixo, pousa em cima), só na parte que fica dentro da janela do jogo e
## desligada enquanto é arrastada. O nó-pai repassa o mouse (handle_press etc.).

signal closed

const TEX_FRAME := preload("res://art/ui/minwin_frame.png")
const TEX_TITLEBAR := preload("res://art/ui/window_titlebar.png")
const TEX_BUTTONS := preload("res://art/ui/window_buttons.png")
const BTN := 16.0
const TITLE_H := 24.0
const PAD := 6.0
const FRAME_MARGIN := 3  # 9-slice: preto + cinza

var title := "notas.txt"
var text := ""
var size := Vector2(200, 80)   # área de conteúdo, sem a barra de título

var _frame_style: StyleBoxTexture
var _title_style: StyleBoxTexture
var _hover_close := false
var _pressing_close := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var drag_start := Vector2.ZERO   # onde estava antes de arrastar (para voltar se o lugar for proibido)
var _platform: CollisionShape2D
var platform_body: StaticBody2D   # quem colide: a fase descobre se o bicudinho está em cima
var _platform_shape := RectangleShape2D.new()


func _ready() -> void:
	z_index = 100
	var body := StaticBody2D.new()
	platform_body = body
	body.collision_layer = 1   # mundo
	body.collision_mask = 0
	_platform = CollisionShape2D.new()
	_platform.shape = _platform_shape
	_platform.one_way_collision = true
	_platform.one_way_collision_margin = _platform_h()  # a aderência: pega quem cai um pouco abaixo do topo
	_platform.disabled = true
	body.add_child(_platform)
	add_child(body)
	_frame_style = StyleBoxTexture.new()
	_frame_style.texture = TEX_FRAME
	_frame_style.set_texture_margin(SIDE_LEFT, FRAME_MARGIN)
	_frame_style.set_texture_margin(SIDE_RIGHT, FRAME_MARGIN)
	_frame_style.set_texture_margin(SIDE_BOTTOM, FRAME_MARGIN)
	_frame_style.set_texture_margin(SIDE_TOP, 0)
	_title_style = StyleBoxTexture.new()
	_title_style.texture = TEX_TITLEBAR
	_title_style.set_texture_margin(SIDE_LEFT, 4)
	_title_style.set_texture_margin(SIDE_RIGHT, 4)
	_title_style.set_texture_margin(SIDE_TOP, 4)
	_title_style.set_texture_margin(SIDE_BOTTOM, 3)


func outer_rect() -> Rect2:
	return Rect2(position, size + Vector2(0, TITLE_H))


## A faixa do topo que vira chão, cortada pela área interna da janela do jogo
## (regra de ouro). Vazia se o topo não encosta nela.
func platform_rect(interior: Rect2) -> Rect2:
	return Rect2(position, Vector2(size.x, _platform_h())).intersection(interior)


## Chamado a cada quadro de física: liga a plataforma só se a janela está aberta, parada
## e com o topo dentro da janela do jogo.
func update_platform(interior: Rect2) -> void:
	var r := platform_rect(interior)
	var on := visible and not _dragging and r.has_area()
	if on:
		if _platform_shape.size != r.size:
			_platform_shape.size = r.size
		_platform.position = r.get_center() - position
	if _platform.disabled == on:
		_platform.set_deferred("disabled", not on)


func _close_rect() -> Rect2:
	return Rect2(position + Vector2(size.x - 6.0 - BTN, 4), Vector2(BTN, BTN))


func _title_rect() -> Rect2:
	return Rect2(position, Vector2(size.x, TITLE_H))


func is_dragging() -> bool:
	return _dragging


## Devolve true se o clique foi nesta janela (e foi consumido).
func handle_press(p: Vector2) -> bool:
	if not visible or not outer_rect().has_point(p):
		return false
	if _close_rect().has_point(p):
		_pressing_close = true
	elif _title_rect().has_point(p):
		_dragging = true
		_drag_offset = position - p
		drag_start = position
	queue_redraw()
	return true


func handle_motion(p: Vector2) -> bool:
	if _dragging:
		var max_pos := Vector2(Tuning.SCREEN_W, Tuning.SCREEN_H - Tuning.TASKBAR_H) - outer_rect().size
		position = (p + _drag_offset).round().clamp(Vector2.ZERO, max_pos)
	var h := visible and _close_rect().has_point(p)
	var entered := h and not _hover_close
	if h != _hover_close:
		_hover_close = h
		queue_redraw()
	return entered


func handle_release(p: Vector2) -> void:
	if _pressing_close and _close_rect().has_point(p):
		close()
	_pressing_close = false
	_dragging = false
	queue_redraw()


func open() -> void:
	visible = true
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _draw() -> void:
	draw_style_box(_title_style, Rect2(0, 0, size.x, TITLE_H))
	draw_string(ThemeDB.fallback_font, Vector2(7, 16), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f2f1ed"))
	var state := 0
	if _pressing_close:
		state = 2
	elif _hover_close:
		state = 1
	draw_texture_rect_region(TEX_BUTTONS, Rect2(size.x - 6.0 - BTN, 4, BTN, BTN),
		Rect2(state * BTN, 0, BTN, BTN))
	draw_style_box(_frame_style, Rect2(0, TITLE_H, size.x, size.y))
	draw_multiline_string(ThemeDB.fallback_font, Vector2(PAD, TITLE_H + PAD + 8), text,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0, 8, -1, Color("2b2b3a"))


## Espessura da plataforma: a linha do topo mais a aderência que desce dela.
func _platform_h() -> float:
	return maxf(5.0, Tuning.POPUP_PLATFORM_GRIP)
