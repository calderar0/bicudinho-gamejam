class_name GameWindow
extends Node2D
## A janela falsa do jogo.
## `rect` é a área interna (o que existe). As bordas são vidro sólido: 4 corpos
## estáticos que seguem a janela. A barra de título fica acima do vidro.

signal rect_changed

# flags dos lados que estão sendo arrastados
const L := 1
const R := 2
const T := 4
const B := 8

var rect := Rect2()      # interior atual
var target := Rect2()    # interior desejado (o atual persegue com velocidade limitada)
var min_size := Vector2.ZERO
var max_size := Vector2.ZERO
var drag_sides := 0      # 0 = não está redimensionando

var _drag_start_mouse := Vector2.ZERO
var _drag_start_rect := Rect2()
var _glass_shapes: Array[CollisionShape2D] = []
var _cracks: Array = []


func setup(interior: Rect2, min_s: Vector2, max_s: Vector2) -> void:
	rect = interior
	target = interior
	min_size = min_s
	max_size = max_s
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


## Retângulo externo: interior + vidro + barra de título.
func outer_rect() -> Rect2:
	var g := Tuning.GLASS_THICKNESS
	var t := Tuning.TITLEBAR_H
	return Rect2(rect.position - Vector2(g, g + t), rect.size + Vector2(g * 2.0, g * 2.0 + t))


func add_crack(pos: Vector2) -> void:
	_cracks.append({"pos": pos, "seed": randi()})
	queue_redraw()


# --- Redimensionar ------------------------------------------------------------

## Lados (flags) da zona de arrasto sob o ponto p, ou 0 se não há.
func side_at(p: Vector2) -> int:
	if not is_resizable():
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


func end_resize() -> void:
	drag_sides = 0


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
	var g := Tuning.GLASS_THICKNESS
	var tb_h := Tuning.TITLEBAR_H
	var o := outer_rect()
	var glass := Color(0.55, 0.82, 1.0, 0.6)
	var shine := Color(1, 1, 1, 0.55)

	# vidro: quatro faixas
	draw_rect(Rect2(rect.position.x - g, rect.position.y - g, rect.size.x + g * 2.0, g), glass)
	draw_rect(Rect2(rect.position.x - g, rect.end.y, rect.size.x + g * 2.0, g), glass)
	draw_rect(Rect2(rect.position.x - g, rect.position.y, g, rect.size.y), glass)
	draw_rect(Rect2(rect.end.x, rect.position.y, g, rect.size.y), glass)
	# reflexo
	draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, 1), shine)
	draw_rect(Rect2(rect.end.x, rect.position.y, 1, rect.size.y), shine)

	# barra de título
	var tb := Rect2(o.position, Vector2(o.size.x, tb_h))
	draw_rect(tb, Color("2b3a67"))
	draw_rect(Rect2(tb.position, Vector2(tb.size.x, 1)), Color("5b74c4"))
	draw_string(ThemeDB.fallback_font, tb.position + Vector2(5, 9), "bicudinho.exe",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e8eefc"))
	for i in 3:
		var bx := tb.end.x - 12.0 - i * 10.0
		draw_rect(Rect2(bx, tb.position.y + 3, 8, 7), Color("c9d4f5") if i != 0 else Color("d9534f"))

	# cantos brancos: dica de que dá para redimensionar
	if is_resizable():
		var c := Color(1, 1, 1, 0.85)
		var corners := [
			o.position + Vector2(0, tb_h),
			Vector2(o.end.x - 4, o.position.y + tb_h),
			Vector2(o.position.x, o.end.y - 4),
			o.end - Vector2(4, 4),
		]
		for corner in corners:
			draw_rect(Rect2(corner, Vector2(4, 4)), c)

	# rachaduras (usadas no passo 3, quando a disparada bate no vidro)
	for ck in _cracks:
		var rng := RandomNumberGenerator.new()
		rng.seed = ck.seed
		var p: Vector2 = ck.pos
		for i in 5:
			var ang := rng.randf() * TAU
			var length := rng.randf_range(4.0, 10.0)
			draw_line(p, p + Vector2.from_angle(ang) * length, Color(1, 1, 1, 0.9), 1.0)
