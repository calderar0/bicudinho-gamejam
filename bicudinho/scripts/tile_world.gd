class_name TileWorld
extends Node2D
## Tiles da fase a partir de um mapa em texto (16x16 px por caractere).
## Regra de ouro: só existe (desenha e colide) o que encosta na área interna da janela.
##
## Legenda do mapa:  #  chão    =  plataforma fina    ~  rio (perigo)    .  vazio

const GROUND_COLOR := Color("6b4c33")
const GRASS_COLOR := Color("5aad4e")
const PLATFORM_COLOR := Color("4a8a40")
const WATER_COLOR := Color("3a7bc8")
const WAVE_COLOR := Color("8fc0f0")

var interior := Rect2()
## Cada célula: {ch, rect, shape (CollisionShape2D ou null), top_open}
var cells: Array = []
## Cada perigo: {rect, kind}
var hazards: Array = []

var _time := 0.0


func setup(rows: PackedStringArray) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1   # mundo
	body.collision_mask = 0
	add_child(body)

	var solid_shape := RectangleShape2D.new()
	solid_shape.size = Vector2(Tuning.TILE, Tuning.TILE)

	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var ch := row[x]
			var r := Rect2(x * Tuning.TILE, y * Tuning.TILE, Tuning.TILE, Tuning.TILE)
			match ch:
				"#":
					var above_is_solid := y > 0 and x < rows[y - 1].length() and rows[y - 1][x] == "#"
					var cs := CollisionShape2D.new()
					cs.shape = solid_shape
					cs.position = r.get_center()
					body.add_child(cs)
					cells.append({"ch": ch, "rect": r, "shape": cs, "top_open": not above_is_solid})
				"=":
					var cs := CollisionShape2D.new()
					var ps := RectangleShape2D.new()
					ps.size = Vector2(Tuning.TILE, 5)
					cs.shape = ps
					cs.one_way_collision = true
					cs.position = r.position + Vector2(8, 2.5)
					body.add_child(cs)
					cells.append({"ch": ch, "rect": r, "shape": cs, "top_open": true})
				"~":
					cells.append({"ch": ch, "rect": r, "shape": null, "top_open": true})
					hazards.append({"rect": r, "kind": "river"})


## Chamado toda vez que a janela muda de tamanho.
func set_interior(r: Rect2) -> void:
	interior = r
	for c in cells:
		var cs: CollisionShape2D = c.shape
		if cs != null:
			cs.disabled = not (c.rect as Rect2).intersects(r)
	queue_redraw()


## Devolve "river" se a caixa toca um perigo ativo (dentro da janela), senão "".
func hazard_hit(box: Rect2) -> String:
	var b := box.grow(-2.0)
	for h in hazards:
		var hr: Rect2 = h.rect
		if hr.intersects(interior) and hr.intersection(interior).intersects(b):
			return h.kind
	return ""


func _process(delta: float) -> void:
	_time += delta
	if not hazards.is_empty():
		queue_redraw()  # a água é animada


func _draw() -> void:
	var wave := int(_time * 4.0)
	for c in cells:
		var r: Rect2 = c.rect
		if not r.intersects(interior):
			continue
		var visible_part := r.intersection(interior)
		match c.ch:
			"#":
				draw_rect(visible_part, GROUND_COLOR)
				draw_rect(Rect2(r.position + Vector2(3, 8), Vector2(2, 2)).intersection(interior), GROUND_COLOR.darkened(0.2))
				if c.top_open:
					draw_rect(Rect2(r.position, Vector2(16, 3)).intersection(interior), GRASS_COLOR)
			"=":
				draw_rect(Rect2(r.position, Vector2(16, 5)).intersection(interior), PLATFORM_COLOR)
			"~":
				draw_rect(visible_part, WATER_COLOR)
				var offset := (wave + int(r.position.x / 16.0)) % 4
				draw_rect(Rect2(r.position + Vector2(offset * 4, 3), Vector2(4, 1)).intersection(interior), WAVE_COLOR)
