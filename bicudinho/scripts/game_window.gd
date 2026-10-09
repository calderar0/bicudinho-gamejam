class_name GameWindow
extends Node2D
## A janela falsa do jogo.
## `rect` é a área interna (o que existe). As bordas são vidro sólido: 4 corpos
## estáticos que seguem a janela. A barra de título (painel azul) fica colada
## em cima do interior; os outros lados têm a moldura branca e cinza.

signal rect_changed
signal hit_limit                          # o redimensionamento bateu no mínimo/máximo
signal button_pressed(button: int)        # clicou e soltou num botão da barra de título

# flags dos lados que estão sendo arrastados
const L := 1
const R := 2
const T := 4
const B := 8
const MOVE := 16   # arrastando pela barra de título (move a janela inteira)

# botões da barra de título (linha em art/ui/window_buttons.png), da direita para a esquerda
enum { BTN_CLOSE, BTN_MAXIMIZE, BTN_RESTORE, BTN_MINIMIZE }
const BUTTONS := [BTN_CLOSE, BTN_MAXIMIZE, BTN_MINIMIZE]
const BTN_SIZE := 16.0
const BTN_GAP := 2.0       # espaço entre os botões
const BTN_MARGIN := 6.0    # da borda direita da barra até o botão de fechar
# colunas da folha de botões
const STATE_NORMAL := 0
const STATE_HOVER := 1
const STATE_PRESSED := 2

const TEX_TITLEBAR := preload("res://art/ui/window_titlebar.png")   # 9-slice, miolo azul
const TEX_BODY := preload("res://art/ui/minwin_frame.png")           # 9-slice, sem topo
const TEX_BUTTONS := preload("res://art/ui/window_buttons.png")
const HIGHLIGHT := Color("f2f1ed")   # filete claro por fora da janela

var hover_button := -1
var pressed_button := -1
var _at_limit := false
var _title_style: StyleBoxTexture
var _body_style: StyleBoxTexture

var rect := Rect2()      # interior atual
var target := Rect2()    # interior desejado (o atual persegue com velocidade limitada)
var min_size := Vector2.ZERO
var max_size := Vector2.ZERO
var drag_sides := 0      # 0 = não está redimensionando
## "(Não respondendo)": barra de título esbranquiçada, sem redimensionar e botões mortos.
var frozen := false

var _drag_start_mouse := Vector2.ZERO
var _drag_start_rect := Rect2()
var _glass_shapes: Array[CollisionShape2D] = []
var _cracks: Array = []
## Recorte da arte do vidro usado na rachadura (a placa à esquerda de cada quadro) e o
## ponto dela que encosta na borda batida (meio da placa).
const CRACK_SRC := Rect2(0, 0, 40, 32)
const CRACK_CENTER := Vector2(11, 16)
var _crack_frames: Array[Texture2D] = []
## Penas (vidas) desenhadas na barra de título; sem a arte, um placeholder.
const FEATHER_PATH := "res://art/hud_feather.png"
const FEATHER_LOST_PATH := "res://art/hud_feather_lost.png"
var lives := Tuning.LIVES
## Nome da fase, escrito na barra de título antes das penas.
var title_text := ""
var _feather_tex: Texture2D = null
var _feather_lost_tex: Texture2D = null


func setup(interior: Rect2, min_s: Vector2, max_s: Vector2) -> void:
	if ResourceLoader.exists(FEATHER_PATH):
		_feather_tex = load(FEATHER_PATH)
	if ResourceLoader.exists(FEATHER_LOST_PATH):
		_feather_lost_tex = load(FEATHER_LOST_PATH)
	for n in [2, 3, 4]:
		var path := "res://art/glass_%02d.png" % n
		if ResourceLoader.exists(path):
			_crack_frames.append(load(path) as Texture2D)
	rect = interior
	target = interior
	min_size = min_s
	max_size = max_s
	_title_style = StyleBoxTexture.new()
	_title_style.texture = TEX_TITLEBAR
	_title_style.set_texture_margin(SIDE_LEFT, 4)
	_title_style.set_texture_margin(SIDE_RIGHT, 4)
	_title_style.set_texture_margin(SIDE_TOP, 4)
	_title_style.set_texture_margin(SIDE_BOTTOM, 3)
	_body_style = StyleBoxTexture.new()
	_body_style.texture = TEX_BODY
	_body_style.draw_center = false  # o miolo é o jogo
	_body_style.set_texture_margin(SIDE_LEFT, 3)
	_body_style.set_texture_margin(SIDE_RIGHT, 3)
	_body_style.set_texture_margin(SIDE_BOTTOM, 3)
	for i in 4:
		var body := StaticBody2D.new()
		body.collision_layer = 2   # vidro
		body.collision_mask = 0
		body.add_to_group("glass")
		var cs := CollisionShape2D.new()
		cs.shape = RectangleShape2D.new()
		body.add_child(cs)
		add_child(body)
		_glass_shapes.append(cs)
	_update_glass()


func is_resizable() -> bool:
	return min_size.x < max_size.x or min_size.y < max_size.y


## Retângulo externo: interior + moldura (esquerda, direita, base) + barra de título.
func outer_rect() -> Rect2:
	var g := Tuning.GLASS_THICKNESS
	var t := Tuning.TITLEBAR_H
	return Rect2(rect.position - Vector2(g, t), rect.size + Vector2(g * 2.0, g + t))


## Quadro da rachadura número i (glass_02, 03, 04, e fica no 04), ou null sem a arte.
## A arte é carregada já na criação: carregar no meio do _draw desenha um quadrado branco.
func _crack_texture(i: int) -> Texture2D:
	return _crack_frames[mini(i, 2)] if _crack_frames.size() == 3 else null


func set_lives(value: int) -> void:
	lives = value
	queue_redraw()


func add_crack(pos: Vector2) -> void:
	_cracks.append({"pos": pos, "seed": randi()})
	queue_redraw()


# --- Botões da barra de título ------------------------------------------------

func button_rect(index: int) -> Rect2:
	var o := outer_rect()
	var x := o.end.x - BTN_MARGIN - BTN_SIZE * (index + 1) - BTN_GAP * index
	var y := o.position.y + floorf((Tuning.TITLEBAR_H - BTN_SIZE) / 2.0)
	return Rect2(x, y, BTN_SIZE, BTN_SIZE)


## Botão (BTN_*) sob o ponto p, ou -1.
func button_at(p: Vector2) -> int:
	if frozen:
		return -1
	for i in BUTTONS.size():
		if button_rect(i).has_point(p):
			return BUTTONS[i]
	return -1


## Atualiza o hover. Devolve true se entrou num botão novo (para tocar o som).
func update_hover(p: Vector2) -> bool:
	var b := button_at(p) if drag_sides == 0 else -1
	if b == hover_button:
		return false
	hover_button = b
	queue_redraw()
	return b != -1


func press_button(b: int) -> void:
	pressed_button = b
	queue_redraw()


func release_button(p: Vector2) -> void:
	var b := pressed_button
	pressed_button = -1
	queue_redraw()
	if b != -1 and button_at(p) == b:
		button_pressed.emit(b)


# --- Redimensionar ------------------------------------------------------------

## Lados (flags) da zona de arrasto sob o ponto p, ou 0 se não há.
func side_at(p: Vector2) -> int:
	if frozen or not is_resizable() or button_at(p) != -1:
		return 0
	var o := outer_rect()
	if not o.grow(3.0).has_point(p):
		return 0
	var grab := Tuning.RESIZE_GRAB
	var corner := Tuning.RESIZE_CORNER
	var s := 0
	if p.x <= o.position.x + grab:
		s |= L
	elif p.x >= o.end.x - grab:
		s |= R
	if p.y <= o.position.y + grab:
		s |= T
	elif p.y >= o.end.y - grab:
		s |= B
	if s == 0:
		return 0
	# cantos: perto de uma quina, pega os dois lados
	if (s & (L | R)) != 0 and (s & (T | B)) == 0:
		if p.y <= o.position.y + corner:
			s |= T
		elif p.y >= o.end.y - corner:
			s |= B
	elif (s & (T | B)) != 0 and (s & (L | R)) == 0:
		if p.x <= o.position.x + corner:
			s |= L
		elif p.x >= o.end.x - corner:
			s |= R
	# eixos travados pela fase (mínimo == máximo)
	if min_size.x >= max_size.x:
		s &= ~(L | R)
	if min_size.y >= max_size.y:
		s &= ~(T | B)
	return s


## O ponto está na barra de título (fora dos botões)? Dá para arrastar a janela por ali.
func title_at(p: Vector2) -> bool:
	if frozen or button_at(p) != -1:
		return false
	var o := outer_rect()
	return Rect2(o.position, Vector2(o.size.x, Tuning.TITLEBAR_H)).has_point(p)


func begin_resize(sides: int, mouse: Vector2) -> void:
	drag_sides = sides
	_drag_start_mouse = mouse
	_drag_start_rect = target


## Chame todo frame enquanto o botão estiver pressionado.
func update_resize(mouse: Vector2) -> void:
	if drag_sides == 0:
		return
	var d := mouse - _drag_start_mouse
	var r := _drag_start_rect
	var s := Tuning.SNAP
	if drag_sides == MOVE:
		# mover: o mesmo tamanho, em outro lugar (dentro da tela)
		var nl := clampf(snappedf(r.position.x + d.x, s), 16.0, Tuning.SCREEN_W - 16.0 - r.size.x)
		var nt := clampf(snappedf(r.position.y + d.y, s), 32.0,
			Tuning.SCREEN_H - Tuning.TASKBAR_H - Tuning.GLASS_THICKNESS - r.size.y)
		target = Rect2(Vector2(nl, nt), r.size)
		return
	var l := r.position.x
	var t := r.position.y
	var rr := r.end.x
	var b := r.end.y
	if drag_sides & L:
		l = snappedf(r.position.x + d.x, s)
	if drag_sides & R:
		rr = snappedf(r.end.x + d.x, s)
	if drag_sides & T:
		t = snappedf(r.position.y + d.y, s)
	if drag_sides & B:
		b = snappedf(r.end.y + d.y, s)

	# limites da tela (cabem o vidro, a barra de título e a barra de tarefas)
	l = maxf(l, 16.0)
	rr = minf(rr, Tuning.SCREEN_W - 16.0)
	t = maxf(t, 32.0)
	b = minf(b, Tuning.SCREEN_H - Tuning.TASKBAR_H - Tuning.GLASS_THICKNESS)

	# tamanho mínimo e máximo da fase
	var w0 := rr - l
	var h0 := b - t
	if rr - l > max_size.x:
		if drag_sides & L:
			l = rr - max_size.x
		else:
			rr = l + max_size.x
	elif rr - l < min_size.x:
		if drag_sides & L:
			l = rr - min_size.x
		else:
			rr = l + min_size.x
	if b - t > max_size.y:
		if drag_sides & T:
			t = b - max_size.y
		else:
			b = t + max_size.y
	elif b - t < min_size.y:
		if drag_sides & T:
			t = b - min_size.y
		else:
			b = t + min_size.y

	target = Rect2(l, t, rr - l, b - t)

	# avisa uma vez quando o mouse passa do limite (som de "não dá")
	var clamped := not is_equal_approx(w0, rr - l) or not is_equal_approx(h0, b - t)
	if clamped and not _at_limit:
		hit_limit.emit()
	_at_limit = clamped


func end_resize() -> void:
	drag_sides = 0
	_at_limit = false


# --- Física -------------------------------------------------------------------

## O ideal é a janela rodar antes do bicudinho: use process_physics_priority = -10.
func _physics_process(delta: float) -> void:
	if rect == target:
		return
	var speed := Tuning.RESIZE_SPEED * delta
	var l := move_toward(rect.position.x, target.position.x, speed)
	var t := move_toward(rect.position.y, target.position.y, speed)
	var r := move_toward(rect.end.x, target.end.x, speed)
	var b := move_toward(rect.end.y, target.end.y, speed)
	rect = Rect2(l, t, r - l, b - t)
	_update_glass()
	rect_changed.emit()
	queue_redraw()


func _update_glass() -> void:
	var g := Tuning.GLASS_COLLIDER
	var rects: Array[Rect2] = [
		Rect2(rect.position.x - g, rect.position.y - g, rect.size.x + g * 2.0, g),  # topo
		Rect2(rect.position.x - g, rect.end.y, rect.size.x + g * 2.0, g),            # base
		Rect2(rect.position.x - g, rect.position.y, g, rect.size.y),                 # esquerda
		Rect2(rect.end.x, rect.position.y, g, rect.size.y),                          # direita
	]
	for i in 4:
		var rs := _glass_shapes[i].shape as RectangleShape2D
		rs.size = rects[i].size
		_glass_shapes[i].position = rects[i].get_center()


# --- Desenho ------------------------------------------------------------------

func _draw() -> void:
	var tb_h := Tuning.TITLEBAR_H
	var o := outer_rect()

	# filete claro por fora (esquerda, topo e base), como na referência
	draw_rect(Rect2(o.position.x - 1, o.position.y, 1, o.size.y), HIGHLIGHT)
	draw_rect(Rect2(o.position.x, o.position.y - 1, o.size.x, 1), HIGHLIGHT)
	draw_rect(Rect2(o.position.x, o.end.y, o.size.x, 1), HIGHLIGHT)

	# corpo: moldura branca e cinza nos lados e na base (o vidro)
	draw_style_box(_body_style, Rect2(o.position.x, rect.position.y, o.size.x, o.end.y - rect.position.y))
	# barra de título: painel azul com borda rosa
	draw_style_box(_title_style, Rect2(o.position, Vector2(o.size.x, tb_h)))
	_draw_title(o, tb_h)

	# botões: coluna = estado, linha = tipo
	for i in BUTTONS.size():
		var btn: int = BUTTONS[i]
		var state := STATE_NORMAL
		if btn == pressed_button:
			state = STATE_PRESSED
		elif btn == hover_button:
			state = STATE_HOVER
		var src := Rect2(state * BTN_SIZE, btn * BTN_SIZE, BTN_SIZE, BTN_SIZE)
		draw_texture_rect_region(TEX_BUTTONS, button_rect(i), src)

	if frozen:
		# travada: um véu branco na barra (as penas continuam visíveis) e o aviso
		draw_rect(Rect2(o.position, Vector2(o.size.x, tb_h)), Color(1, 1, 1, 0.55))
		_draw_title(o, tb_h)

	# cantos de baixo: dica de que dá para redimensionar
	if is_resizable() and not frozen:
		var c := Color(1, 1, 1, 0.85)
		draw_rect(Rect2(Vector2(o.position.x, o.end.y - 3), Vector2(3, 3)), c)
		draw_rect(Rect2(o.end - Vector2(3, 3), Vector2(3, 3)), c)

	# rachaduras: a cada batida, um quadro mais quebrado da arte do vidro (glass_02 a 04),
	# com a placa deitada na borda batida e as trincas abrindo para dentro da janela
	for i in _cracks.size():
		var p: Vector2 = _cracks[i].pos
		var tex := _crack_texture(i)
		if tex == null:
			var rng := RandomNumberGenerator.new()
			rng.seed = _cracks[i].seed
			for k in 5:
				var ang := rng.randf() * TAU
				draw_line(p, p + Vector2.from_angle(ang) * rng.randf_range(4.0, 10.0), Color(1, 1, 1, 0.9), 1.0)
			continue
		var d := {"left": p.x - rect.position.x, "right": rect.end.x - p.x,
			"top": p.y - rect.position.y, "bottom": rect.end.y - p.y}
		var side: String = d.keys().reduce(func(a, b): return a if d[a] <= d[b] else b)
		match side:
			"left":
				draw_set_transform(Vector2(rect.position.x, p.y))
			"right":
				draw_set_transform(Vector2(rect.end.x, p.y), 0.0, Vector2(-1, 1))
			"top":
				draw_set_transform(Vector2(p.x, rect.position.y), PI / 2.0, Vector2(1, -1))
			"bottom":
				draw_set_transform(Vector2(p.x, rect.end.y), -PI / 2.0)
		draw_texture_rect_region(tex, Rect2(Vector2(-CRACK_CENTER.x, -CRACK_CENTER.y), CRACK_SRC.size), CRACK_SRC)
	draw_set_transform(Vector2.ZERO)


## Penas (vidas) no canto esquerdo da barra de título: acompanham a janela quando ela muda.
func _draw_lives(origin: Vector2) -> void:
	var full := _feather_tex
	var lost := _feather_lost_tex
	for i in Tuning.LIVES:
		var at := origin + Vector2(18.0 * i, 0)
		var has := i < lives
		if full != null:
			if has:
				draw_texture_rect(full, Rect2(at, Vector2(16, 16)), false)
			elif lost != null:
				draw_texture_rect(lost, Rect2(at, Vector2(16, 16)), false)
			else:
				draw_texture_rect(full, Rect2(at, Vector2(16, 16)), false, Color(1, 1, 1, 0.25))  # perdida: só um fantasma
			continue
		# placeholder: uma pena branca inclinada (cheia) ou só o contorno (perdida)
		var vane := PackedVector2Array([Vector2(3, 14), Vector2(4, 9), Vector2(8, 4), Vector2(14, 1),
			Vector2(12, 7), Vector2(7, 12)])
		for k in vane.size():
			vane[k] += at
		if has:
			draw_colored_polygon(vane, Color("f2f1ed"))
		else:
			draw_colored_polygon(vane, Color(1, 1, 1, 0.12))
		vane.append(vane[0])
		draw_polyline(vane, Color("1a1a2e") if has else Color(1, 1, 1, 0.35), 1.0)
		draw_line(at + Vector2(1, 15), at + Vector2(13, 3), Color("a0522d") if has else Color(1, 1, 1, 0.35), 1.0)


## Barra de título: o nome da fase (e "(Não respondendo)" se travada) e, logo depois, as penas.
func _draw_title(o: Rect2, tb_h: float) -> void:
	var font := ThemeDB.fallback_font
	var t := title_text
	if frozen:
		t += " (Não respondendo)"
	var x := o.position.x + 8.0
	# janela estreita: se o nome não cabe junto com as penas antes dos botões, ele sai
	var room := o.size.x - 8.0 - (BTN_SIZE + BTN_GAP) * BUTTONS.size() - BTN_MARGIN - 18.0 * Tuning.LIVES
	if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8.0 > room:
		t = ""
	if t != "":
		draw_string(font, Vector2(x, o.position.y + 16.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color("2b2b3a") if frozen else Color("f2f1ed"))
		x += font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8.0
	_draw_lives(Vector2(x, o.position.y + (tb_h - 16.0) / 2.0))
