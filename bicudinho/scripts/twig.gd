class_name Twig
extends Node2D
## O graveto, objetivo das fases (menos a última, onde o objetivo é a bicudinha).
## A origem do nó fica no chão, no meio do graveto. Quando o bicudinho pega, ele sobe e some.
##
## Arte: res://art/twig.png (32x32, a base da imagem fica no chão). Sem arte, placeholder marrom.

const ART_PATH := "res://art/twig.png"
const PICK_TIME := 0.4     # quanto tempo leva subindo e sumindo ao ser pego
const PICK_RISE := 12.0    # quanto sobe (px) enquanto some
const COLOR := Color("6b4c33")
const ART_BOTTOM_MARGIN := 2.0   # linhas transparentes embaixo do PNG (para pousar no chão)

var picked := false

var _tex: Texture2D = null
var _time := 0.0


func _ready() -> void:
	z_index = 1
	if ResourceLoader.exists(ART_PATH):
		_tex = load(ART_PATH) as Texture2D


func pick_up() -> void:
	if picked:
		return
	picked = true
	_time = 0.0
	Audio.play("sfx_twig_pick")  # toca quando o som existir


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # balança de leve; ao ser pego, sobe e some


func _draw() -> void:
	var a := 1.0
	var dy := -roundf((sin(_time * 3.0) + 1.0) / 2.0)   # balancinho de 1 px para cima
	if picked:
		var t := minf(_time / PICK_TIME, 1.0)
		a = 1.0 - t
		dy = -roundf(PICK_RISE * t)
		if a <= 0.0:
			return
	if _tex != null:
		var s := _tex.get_size()
		draw_texture(_tex, Vector2(-s.x / 2.0, -s.y + ART_BOTTOM_MARGIN + dy), Color(1, 1, 1, a))
	else:
		for k in 12:
			draw_rect(Rect2(-6.0 + k, -4.0 - k * 0.5 + dy, 2, 2), Color(COLOR, a))
