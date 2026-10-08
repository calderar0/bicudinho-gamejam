class_name Bicudinho
extends CharacterBody2D
## O bicudinho. A origem do nó fica nos pés. Colisão de 12x14 px.
## Passo 1: andar, pular com altura variável, coyote time e buffer de pulo.
## Passo 2: perigos do mapa, ser empurrado pela janela e ser esmagado.
## Usa a arte de res://art/ se existir; sem ela, desenha um placeholder.
##
## Arte: quadros em arquivos separados, <nome>_01.png, <nome>_02.png...
## (ou <nome>.png para animações de um quadro só).

signal died(cause: String)

var facing := 1
var coyote := 0.0
var jump_buffer := 0.0
var anim_time := 0.0
var dead := false

## Função que recebe a caixa do bicudinho (Rect2) e devolve "river", "trash" ou "".
var hazard_check: Callable = Callable()

# medição de pulo (só quando Tuning.DEBUG_MEASURE está ligado)
var _was_on_floor := false
var _measuring := false
var _start := Vector2.ZERO
var _min_y := 0.0

var _frames_cache: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3  # camada 1 (mundo) + camada 2 (vidro)


func box_rect() -> Rect2:
	return Rect2(
		global_position + Vector2(-Tuning.BIRD_BOX.x / 2.0, -Tuning.BIRD_BOX.y),
		Tuning.BIRD_BOX)


func _physics_process(delta: float) -> void:
	if dead:
		return
	anim_time += delta

	# entrada horizontal
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1

	# chão e coyote time
	var on_floor := is_on_floor()
	if on_floor:
		coyote = Tuning.COYOTE_TIME
	else:
		coyote = maxf(coyote - delta, 0.0)

	# buffer de pulo
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = Tuning.JUMP_BUFFER

	# pulo
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = Tuning.JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0

	# altura variável: soltar o botão corta a subida
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= Tuning.JUMP_CUT

	# horizontal com aceleração e atrito
	var accel := Tuning.GROUND_ACCEL if on_floor else Tuning.AIR_ACCEL
	var friction := Tuning.GROUND_FRICTION if on_floor else Tuning.AIR_FRICTION
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * Tuning.RUN_SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# gravidade
	velocity.y = minf(velocity.y + Tuning.GRAVITY * delta, Tuning.MAX_FALL_SPEED)

	move_and_slide()
	_check_hazard()

	if Tuning.DEBUG_MEASURE:
		_measure()


func _measure() -> void:
	var now := is_on_floor()
	if _was_on_floor and not now:
		_measuring = true
		_start = global_position
		_min_y = global_position.y
	elif not now:
		_min_y = minf(_min_y, global_position.y)
	elif _measuring and not _was_on_floor:
		_measuring = false
		var height := _start.y - _min_y
		var distance := absf(global_position.x - _start.x)
		print("altura %.1f px (%.2f tiles) | distância %.1f px (%.2f tiles)" % [
			height, height / Tuning.TILE, distance, distance / Tuning.TILE])
	_was_on_floor = now


# --- Perigos, empurrão da janela e morte --------------------------------------

func _check_hazard() -> void:
	if not hazard_check.is_valid():
		return
	var kind: String = hazard_check.call(box_rect())
	if kind != "":
		die(kind)


## A janela empurra o bicudinho para dentro quando uma borda se move contra ele.
## Se há uma parede do outro lado, ele é esmagado.
func enforce_inside(interior: Rect2) -> void:
	if dead:
		return
	var box := box_rect()
	var dx := 0.0
	var dy := 0.0
	if box.position.x < interior.position.x:
		dx = interior.position.x - box.position.x
	elif box.end.x > interior.end.x:
		dx = interior.end.x - box.end.x
	if box.position.y < interior.position.y:
		dy = interior.position.y - box.position.y
	elif box.end.y > interior.end.y:
		dy = interior.end.y - box.end.y
	if dx == 0.0 and dy == 0.0:
		return
	var saved_mask := collision_mask
	collision_mask = 1  # ignora o próprio vidro ao ser empurrado
	var blocked := false
	if dx != 0.0 and move_and_collide(Vector2(dx, 0)) != null:
		blocked = true
	if dy != 0.0 and move_and_collide(Vector2(0, dy)) != null:
		blocked = true
	collision_mask = saved_mask
	if blocked:
		die("crush")


func die(cause: String) -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	modulate = Color(1.0, 0.45, 0.45)
	died.emit(cause)


# --- Desenho -------------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _draw_art():
		return
	_draw_placeholder()


## Quadros de res://art/<nome>.png (um quadro) ou <nome>_01.png, <nome>_02.png...
## Devolve um array vazio se não existir nenhum.
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


func _art_name() -> String:
	if is_on_floor():
		if absf(velocity.x) > 10.0:
			return "bicudinho_walk"
		return "bicudinho_idle"
	return "bicudinho_jump" if velocity.y < 0.0 else "bicudinho_fall"


## Se a arte do estado atual não existe, usa o primeiro quadro do andar.
## Devolve false se não há arte nenhuma (aí desenha o placeholder).
func _draw_art() -> bool:
	var art_name := _art_name()
	var frames := _get_frames(art_name)
	var idx := 0
	if frames.is_empty():
		frames = _get_frames("bicudinho_walk")
		if frames.is_empty():
			return false
	else:
		var fps := Tuning.WALK_FPS if art_name == "bicudinho_walk" else Tuning.IDLE_FPS
		idx = int(anim_time * fps) % frames.size()
	var t: Texture2D = frames[idx]
	var size := t.get_size()
	draw_set_transform(Vector2(0, Tuning.SPRITE_Y_ADJUST), 0.0, Vector2(facing, 1))
	draw_texture(t, Vector2(-size.x / 2.0, -size.y))  # centro-inferior nos pés
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _draw_placeholder() -> void:
	var bob := 0.0
	if is_on_floor() and absf(velocity.x) > 10.0:
		bob = -absf(sin(anim_time * 16.0)) * 2.0  # andar em saltinhos
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1))
	draw_rect(Rect2(-6, -14, 12, 14), Color("b5833c"))   # corpo
	draw_rect(Rect2(-5, -6, 9, 5), Color("ead9a6"))      # barriga
	draw_rect(Rect2(2, -12, 2, 2), Color.BLACK)          # olho
	draw_rect(Rect2(6, -11, 4, 2), Color("3a2a1a"))      # bico
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
