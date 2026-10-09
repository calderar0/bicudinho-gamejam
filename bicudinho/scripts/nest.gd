class_name Nest
extends Node2D
## O ninho final dos dois bicudinhos: uma taboa alta com o ninho no topo (art/nest.png,
## 128x128). A origem do nó fica no chão, no meio da base da taboa. Só decora: não colide.

const ART := preload("res://art/nest.png")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var s := ART.get_size()
	draw_texture(ART, Vector2(-s.x / 2.0, -s.y))
