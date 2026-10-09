class_name GlassPane
extends StaticBody2D
## Vidro da fase: uma placa fina de 1x2 tiles (16x32 px), "|" no mapa (a célula de cima).
## O bicudinho não enxerga: andar contra só bloqueia; bater na disparada estilhaça a placa
## (abre passagem), atordoa e tira uma pena (veja Bicudinho._hit_glass).
## Regra de ouro: só desenha e colide a parte dentro da janela do jogo.
##
## Arte: art/glass_01.png (inteiro) a glass_05.png (cacos no chão), 64x64. A placa fica no
## canto de cima à esquerda de cada quadro (SRC), com o meio em x = PANE_CENTER_X.

const SIZE := Vector2(16, 32)
const COLLIDER_W := 8.0
const SRC := Rect2(0, 0, 40, 32)    # a placa e os cacos que voam para a direita
const PANE_CENTER_X := 11.0
const COLOR := Color(0.75, 0.9, 1.0, 0.6)   # placeholder sem arte

var broken := false
var interior := Rect2()

var _shape: CollisionShape2D
var _frames: Array[Texture2D] = []
var _frame := 0
var _time := 0.0


func _ready() -> void:
	add_to_group("glass")
	collision_layer = 2   # vidro
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(COLLIDER_W, SIZE.y)
	_shape.shape = rs
	_shape.position = SIZE / 2.0
	add_child(_shape)
	for i in range(1, 6):
		var path := "res://art/glass_%02d.png" % i
		if ResourceLoader.exists(path):
			_frames.append(load(path) as Texture2D)


func rect() -> Rect2:
	return Rect2(position, SIZE)


## Chamado quando a janela muda: liga a colisão só se a placa encosta na área interna.
func update_inside(r: Rect2) -> void:
	interior = r
	_shape.set_deferred("disabled", broken or not rect().intersects(r))
	queue_redraw()


func shatter() -> void:
	if broken:
		return
	broken = true
	_shape.set_deferred("disabled", true)
	_time = 0.0
	_frame = 1
	Audio.play("sfx_glass_crack")  # toca quando o som existir
	queue_redraw()


func _process(delta: float) -> void:
	if not broken or _frame >= _frames.size() - 1:
		return
	_time += delta
	var f := mini(1 + int(_time * Tuning.GLASS_BREAK_FPS), _frames.size() - 1)
	if f != _frame:
		_frame = f
		queue_redraw()


func _draw() -> void:
	var dest := Rect2(Vector2(SIZE.x / 2.0 - PANE_CENTER_X, 0), SRC.size)
	var clip := Rect2(interior.position - position, interior.size)  # interior em coordenadas locais
	var vis := dest.intersection(clip)
	if not vis.has_area():
		return
	if _frames.is_empty():
		if not broken:
			draw_rect(Rect2(SIZE.x / 2.0 - 3.0, 0, 6, SIZE.y).intersection(clip), COLOR)
		return
	# recorta o pedaço da arte que cabe dentro da janela
	var src := Rect2(SRC.position + (vis.position - dest.position), vis.size)
	draw_texture_rect_region(_frames[_frame], vis, src)
