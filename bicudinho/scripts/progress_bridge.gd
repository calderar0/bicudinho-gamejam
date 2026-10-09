class_name ProgressBridge
extends StaticBody2D
## Barra de progresso "Copiando arquivos..." que é uma ponte: a parte preenchida é chão e
## cresce sozinha da esquerda para a direita até completar em `duration` segundos.
## Regra de ouro: só desenha e colide a parte dentro da janela do jogo.

const H := 8.0
const FRAME := Color("f2f1ed")
const FILL := Color("3fbf5a")
const BLOCK_GAP := 2.0

var area := Rect2()        # a barra inteira (em px do desktop); o topo é o chão
var duration := 20.0
var progress := 0.0        # 0 a 1
var interior := Rect2()

var _shape: CollisionShape2D
var _rs := RectangleShape2D.new()


func setup(bar: Rect2, seconds: float) -> void:
	area = bar
	duration = seconds


func _ready() -> void:
	collision_layer = 1   # mundo
	collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = _rs
	_shape.disabled = true
	add_child(_shape)


func update_inside(r: Rect2) -> void:
	interior = r
	queue_redraw()


func _physics_process(delta: float) -> void:
	progress = minf(progress + delta / duration, 1.0)
	var solid := Rect2(area.position, Vector2(area.size.x * progress, H)).intersection(interior)
	if solid.size.x >= 1.0:
		_rs.size = solid.size
		_shape.position = solid.get_center()
		_shape.disabled = false
	else:
		_shape.disabled = true
	queue_redraw()


func _draw() -> void:
	var bar := Rect2(area.position, Vector2(area.size.x, H))
	var vis := bar.intersection(interior)
	if not vis.has_area():
		return
	draw_rect(vis, Color(0, 0, 0, 0.35))
	# blocos verdes, como numa barra de cópia de arquivos
	var filled := area.size.x * progress
	var x := 0.0
	while x + 6.0 <= filled:
		var b := Rect2(area.position + Vector2(x + 1.0, 1.0), Vector2(6.0, H - 2.0)).intersection(interior)
		if b.has_area():
			draw_rect(b, FILL)
		x += 6.0 + BLOCK_GAP
	draw_rect(vis, FRAME, false, 1.0)
	var label := "Copiando arquivos... %d%%" % int(progress * 100.0)
	var at := area.position + Vector2(0, -4)
	if interior.has_point(at + Vector2(2, -4)):
		draw_string(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("2b2b3a"))
