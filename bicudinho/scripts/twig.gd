class_name Twig
extends Node2D
## O graveto, objetivo das fases (menos a da bicudinha e os créditos).
## A origem do nó fica no chão, no meio do graveto.
## Pego, ele "salta" (cresce, com raios de luz girando atrás) e sai voando em arco, girando,
## até a pasta "gravetos" do desktop. Ao chegar, avisa (arrived) e some.
##
## Arte: res://art/twig.png (32x32, a base da imagem fica no chão). Sem arte, placeholder marrom.

signal arrived

const ART_PATH := "res://art/twig.png"
const POP_TIME := 0.35        # o salto: cresce e brilha no lugar
const FLY_TIME := 0.75        # o voo até a pasta
const POP_SCALE := 1.8
const END_SCALE := 0.5
const FLY_ARC := 70.0         # quanto o voo sobe acima da reta (px)
const SPINS := 2.0            # voltas durante o voo
const COLOR := Color("6b4c33")
const RAY_COLOR := Color(1.0, 0.92, 0.5)
const ART_BOTTOM_MARGIN := 2.0   # linhas transparentes embaixo do PNG (para pousar no chão)

var picked := false

var _tex: Texture2D = null
var _time := 0.0
var _start := Vector2.ZERO
var _target := Vector2.ZERO
var _has_target := false
var _done := false


func _ready() -> void:
	z_index = 1
	if ResourceLoader.exists(ART_PATH):
		_tex = load(ART_PATH) as Texture2D


## Pega o graveto. target: para onde ele voa (o meio da pasta "gravetos"); sem alvo, só sobe.
func pick_up(target := Vector2.INF) -> void:
	if picked:
		return
	picked = true
	_time = 0.0
	_start = position
	_has_target = target != Vector2.INF
	_target = target if _has_target else position + Vector2(0, -80)
	z_index = 160   # por cima da moldura e das mini-janelas enquanto voa
	Audio.play("sfx_twig_pick")  # toca quando o som existir


func _process(delta: float) -> void:
	_time += delta
	if picked and not _done:
		var t := clampf((_time - POP_TIME) / FLY_TIME, 0.0, 1.0)
		if t > 0.0:
			# arco: curva de Bézier com o ponto de controle acima do meio do caminho
			var mid := (_start + _target) / 2.0 + Vector2(0, -FLY_ARC)
			var e := t * t * (3.0 - 2.0 * t)   # começa e termina devagar
			position = _start.lerp(mid, e).lerp(mid.lerp(_target, e), e)
		if t >= 1.0:
			_done = true
			arrived.emit()
	queue_redraw()


func _draw() -> void:
	if _done:
		return
	var dy := -roundf((sin(_time * 3.0) + 1.0) / 2.0)   # balancinho de 1 px para cima
	var s := 1.0
	var rot := 0.0
	if picked:
		dy = 0.0
		if _time < POP_TIME:
			var k := _time / POP_TIME
			s = 1.0 + (POP_SCALE - 1.0) * sin(k * PI * 0.5)
			_draw_rays(k)
		else:
			var t := clampf((_time - POP_TIME) / FLY_TIME, 0.0, 1.0)
			s = lerpf(POP_SCALE, END_SCALE, t)
			rot = t * TAU * SPINS
	# a arte gira e escala em volta do meio dela (16 px acima do chão)
	draw_set_transform(Vector2(0, -16 + dy), rot, Vector2(s, s))
	if _tex != null:
		var sz := _tex.get_size()
		draw_texture(_tex, Vector2(-sz.x / 2.0, -sz.y / 2.0 + ART_BOTTOM_MARGIN))
	else:
		for k in 12:
			draw_rect(Rect2(-6.0 + k, 4.0 - k * 0.5, 2, 2), COLOR)
	draw_set_transform(Vector2.ZERO)


## Raios de luz girando atrás do graveto no salto (k vai de 0 a 1).
func _draw_rays(k: float) -> void:
	var c := Vector2(0, -16)
	var a := 1.0 - k
	for i in 8:
		var ang := _time * 3.0 + i * TAU / 8.0
		var len := 18.0 + 22.0 * k
		draw_line(c + Vector2.from_angle(ang) * 8.0, c + Vector2.from_angle(ang) * len,
			Color(RAY_COLOR, 0.8 * a), 2.0)
	draw_circle(c, 10.0 + 6.0 * k, Color(RAY_COLOR, 0.35 * a))
