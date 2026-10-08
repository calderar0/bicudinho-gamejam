extends CharacterBody2D
## O bicudinho. A origem do nó fica nos pés. Colisão de 12x14 px.
## Passo 1: andar, pular com altura variável, coyote time e buffer de pulo.

var facing := 1
var coyote := 0.0
var jump_buffer := 0.0
var anim_time := 0.0

# medição de pulo (só quando Tuning.DEBUG_MEASURE está ligado)
var _was_on_floor := false
var _measuring := false
var _start := Vector2.ZERO
var _min_y := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3  # camada 1 (mundo) + camada 2 (vidro)


func _physics_process(delta: float) -> void:
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


func _process(_delta: float) -> void:
	queue_redraw()


# --- Placeholder ---------------------------------------------------------------
# Quando a arte chegar, troque este desenho por um Sprite2D/AnimatedSprite2D.

func _draw() -> void:
	var bob := 0.0
	if is_on_floor() and absf(velocity.x) > 10.0:
		bob = -absf(sin(anim_time * 16.0)) * 2.0  # andar em saltinhos
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1))
	draw_rect(Rect2(-6, -14, 12, 14), Color("b5833c"))   # corpo
	draw_rect(Rect2(-5, -6, 9, 5), Color("ead9a6"))      # barriga
	draw_rect(Rect2(2, -12, 2, 2), Color.BLACK)          # olho
	draw_rect(Rect2(6, -11, 4, 2), Color("3a2a1a"))      # bico
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
