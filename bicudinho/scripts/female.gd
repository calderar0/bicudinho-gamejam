class_name Female
extends Node2D
## A bicudinha, o objetivo do bicudinho. A origem do nó fica nos pés.
## Parada (female_idle) até o bicudinho chegar; aí fica feliz (female_happy). Ela sempre encara
## o alvo (`target`, o bicudinho), mesmo que ele venha do outro lado.
##
## Arte: quadros em arquivos separados, res://art/female_idle_01.png... e
## res://art/female_happy_01.png... (sem arte, desenha um placeholder rosa).

## Para onde cada arte olha no arquivo: a parada olha para a direita, a feliz para a esquerda.
const IDLE_ART_DIR := 1
const HAPPY_ART_DIR := -1
## Só vira para o outro lado se o alvo passar disso (em px) para além dela: evita ficar
## girando quando o bicudinho está em cima dela.
const TURN_MARGIN := 4.0

var happy := false
## Quem ela encara (o bicudinho). Sem alvo, fica como a arte vem.
var target: Node2D = null

var _dir := -1   # lado para onde ela olha agora: 1 direita, -1 esquerda (o bicudinho chega pela esquerda)
var _time := 0.0
var _frames_cache: Dictionary = {}


func set_happy(value: bool) -> void:
	if happy == value:
		return
	happy = value
	_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if target != null:
		var dx := target.global_position.x - global_position.x
		if dx > TURN_MARGIN:
			_dir = 1
		elif dx < -TURN_MARGIN:
			_dir = -1
	queue_redraw()


## Quadros de res://art/<nome>_01.png, <nome>_02.png... (ou <nome>.png). Vazio se não existe.
func _get_frames(art_name: String) -> Array:
	if _frames_cache.has(art_name):
		return _frames_cache[art_name]
	var frames: Array = []
	var single := "res://art/%s.png" % art_name
	if ResourceLoader.exists(single):
		frames.append(load(single))
	else:
		var i := 1
		while true:
			var path := "res://art/%s_%02d.png" % [art_name, i]
			if not ResourceLoader.exists(path):
				break
			frames.append(load(path))
			i += 1
	_frames_cache[art_name] = frames
	return frames


func _draw() -> void:
	var frames := _get_frames("female_happy" if happy else "female_idle")
	if frames.is_empty():
		frames = _get_frames("female_idle")  # sem a arte feliz, continua parada
	if frames.is_empty():
		_draw_placeholder()
		return
	var fps := Tuning.FEMALE_HAPPY_FPS if happy else Tuning.FEMALE_IDLE_FPS
	var t: Texture2D = frames[int(_time * fps) % frames.size()]
	var size := t.get_size()
	# espelha só quando o lado que a arte olha não é o lado do alvo
	var art_dir := HAPPY_ART_DIR if happy else IDLE_ART_DIR
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 if _dir == art_dir else -1.0, 1.0))
	# centro-inferior nos pés
	draw_texture(t, Vector2(-size.x / 2.0, -size.y + Tuning.SPRITE_Y_ADJUST))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_placeholder() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-float(_dir), 1.0))  # o bico fica do lado do alvo
	draw_rect(Rect2(-6, -14, 12, 14), Color("d9a8b0"))   # corpo
	draw_rect(Rect2(-5, -6, 9, 5), Color("f1e3e5"))      # barriga
	draw_rect(Rect2(-4, -12, 2, 2), Color.BLACK)         # olho
	draw_rect(Rect2(-9, -11, 4, 2), Color("3a2a1a"))     # bico
	if happy:
		draw_rect(Rect2(-3, -22, 6, 4), Color("e0457b"))  # coração
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
