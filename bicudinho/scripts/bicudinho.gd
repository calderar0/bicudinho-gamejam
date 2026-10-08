class_name Bicudinho
extends CharacterBody2D
## O bicudinho. A origem do nó fica nos pés. Colisão de 12x14 px.
## Passo 1: andar, pular com altura variável, coyote time e buffer de pulo.
## Passo 2: perigos do mapa, ser empurrado pela janela e ser esmagado.
## Passo 3: preparar voo (pausa com mira) e disparada; o vidro atordoa na disparada.
## Extra: planar segurando a ação de Tuning.GLIDE_ACTION enquanto cai.
## Usa a arte de res://art/ se existir; sem ela, desenha um placeholder.
##
## Arte: quadros em arquivos separados, <nome>_01.png, <nome>_02.png...
## (ou <nome>.png para animações de um quadro só).

signal died(cause: String)
signal glass_hit(pos: Vector2)

enum State { NORMAL, PREPARE, DASH, STUN }

var state: State = State.NORMAL
var has_dash := true          # uma disparada por pulo; volta ao tocar o chão
var facing := 1
var coyote := 0.0
var jump_buffer := 0.0
var anim_time := 0.0
var dead := false
var _step_phase := 0.0
var gliding := false

## Função que recebe a caixa do bicudinho (Rect2) e devolve "river", "trash" ou "".
var hazard_check: Callable = Callable()

var _air_time := 0.0      # tempo desde que saiu do chão (anima o pulo)
var _glide_left := 0.0    # tempo de planar que ainda resta neste pulo
var _state_time := 0.0    # tempo dentro do estado atual (prepare, dash, stun, morte)
var _dash_dir := Vector2.RIGHT
var _dash_travelled := 0.0

# medição de pulo (só quando Tuning.DEBUG_MEASURE está ligado)
var _was_on_floor := false
var _measuring := false
var _start := Vector2.ZERO
var _min_y := 0.0

var _frames_cache: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3  # camada 1 (mundo) + camada 2 (vidro)
	_glide_left = Tuning.GLIDE_TIME


func box_rect() -> Rect2:
	return Rect2(
		global_position + Vector2(-Tuning.BIRD_BOX.x / 2.0, -Tuning.BIRD_BOX.y),
		Tuning.BIRD_BOX)


func _physics_process(delta: float) -> void:
	if dead:
		_state_time += delta  # só para animar a morte
		return
	anim_time += delta
	match state:
		State.NORMAL:
			_normal(delta)
		State.PREPARE:
			_prepare(delta)
		State.DASH:
			_dash(delta)
		State.STUN:
			_stun(delta)
	if not dead:
		_check_hazard()
	if Tuning.DEBUG_MEASURE:
		_measure()


# --- Estado NORMAL: andar, pular e planar -------------------------------------

func _normal(delta: float) -> void:
	# entrada horizontal
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1

	# chão, coyote time, tempo no ar e disparada disponível
	var on_floor := is_on_floor()
	if on_floor:
		coyote = Tuning.COYOTE_TIME
		has_dash = true
		_air_time = 0.0
		_glide_left = Tuning.GLIDE_TIME
	else:
		coyote = maxf(coyote - delta, 0.0)
		_air_time += delta

	# buffer de pulo
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	var pressed := Input.is_action_just_pressed("jump")
	if pressed:
		jump_buffer = Tuning.JUMP_BUFFER

	if jump_buffer > 0.0 and coyote > 0.0:
		# pulo
		velocity.y = Tuning.JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
		Audio.play("sfx_jump", 0.05)
	elif pressed and not on_floor and has_dash and _air_time > Tuning.PREPARE_MIN_AIR_TIME \
			and not test_move(global_transform, Vector2(0, Tuning.PREPARE_GROUND_CLEARANCE)):
		# segundo toque no ar (longe do chão): preparar o voo
		_start_prepare()
		return

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

	# gravidade, ou planar (segurar a ação de planar enquanto cai)
	gliding = not on_floor and velocity.y > 0.0 and _glide_left > 0.0 \
			and Input.is_action_pressed(Tuning.GLIDE_ACTION)
	if gliding:
		_glide_left -= delta
		if velocity.y > Tuning.GLIDE_FALL_SPEED:
			velocity.y = move_toward(velocity.y, Tuning.GLIDE_FALL_SPEED, Tuning.GLIDE_BRAKE * delta)
		else:
			velocity.y = minf(velocity.y + Tuning.GRAVITY * delta, Tuning.GLIDE_FALL_SPEED)
	else:
		velocity.y = minf(velocity.y + Tuning.GRAVITY * delta, Tuning.MAX_FALL_SPEED)

	move_and_slide()
	_step_sounds(delta)


# --- Estado PREPARE: a pausa em que ele mira ----------------------------------

func _start_prepare() -> void:
	state = State.PREPARE
	_state_time = 0.0
	gliding = false
	velocity = Vector2(velocity.x * 0.3, minf(velocity.y, 0.0) * 0.3)


## Direção mirada com as setas (8 direções). Sem seta, vai para onde ele olha.
func _read_aim() -> Vector2:
	var v := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	if v == Vector2.ZERO:
		v = Vector2(facing, 0)
	return v.normalized()


func _prepare(delta: float) -> void:
	_state_time += delta
	var aim := _read_aim()
	if aim.x != 0.0:
		facing = 1 if aim.x > 0.0 else -1
	# pairando: gravidade quase zero e a velocidade horizontal some rápido
	velocity.y += Tuning.GRAVITY * Tuning.PREPARE_GRAVITY_SCALE * delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	move_and_slide()
	if is_on_floor():
		state = State.NORMAL  # pousou durante a pausa: cancela
		return
	if _state_time >= Tuning.PREPARE_TIME:
		_start_dash(aim)


# --- Estado DASH: voo rápido em linha reta ------------------------------------

func _start_dash(aim: Vector2) -> void:
	state = State.DASH
	_state_time = 0.0
	_dash_dir = aim
	_dash_travelled = 0.0
	has_dash = false
	velocity = Vector2.ZERO
	if aim.x != 0.0:
		facing = 1 if aim.x > 0.0 else -1


func _dash(delta: float) -> void:
	_state_time += delta
	var remaining := Tuning.DASH_DISTANCE - _dash_travelled
	var step := _dash_dir * Tuning.DASH_SPEED * delta
	if step.length() > remaining:
		step = step.normalized() * remaining
	var col := move_and_collide(step)
	if col == null:
		_dash_travelled += step.length()
		if _dash_travelled >= Tuning.DASH_DISTANCE - 0.01:
			_end_dash(true)
		return
	_dash_travelled += col.get_travel().length()
	var hit := col.get_collider()
	if hit is Node and (hit as Node).is_in_group("glass"):
		_hit_glass(col.get_position())
	else:
		_end_dash(false)  # bateu em parede ou chão: só para


func _end_dash(natural: bool) -> void:
	state = State.NORMAL
	velocity = _dash_dir * Tuning.DASH_SPEED * Tuning.DASH_EXIT_SPEED_SCALE if natural else Vector2.ZERO


## Aplica a regra do vidro (Tuning.GLASS_RULE) quando a disparada bate nele.
func _hit_glass(pos: Vector2) -> void:
	match Tuning.GLASS_RULE:
		Tuning.GlassRule.BLOCK:
			_end_dash(false)
		Tuning.GlassRule.STUN:
			state = State.STUN
			_state_time = 0.0
			velocity = -_dash_dir * 60.0  # um pequeno tranco para trás
			glass_hit.emit(pos)
		Tuning.GlassRule.KILL:
			glass_hit.emit(pos)
			die("glass")


# --- Estado STUN: atordoado ----------------------------------------------------

func _stun(delta: float) -> void:
	_state_time += delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	velocity.y = minf(velocity.y + Tuning.GRAVITY * delta, Tuning.MAX_FALL_SPEED)
	move_and_slide()
	if _state_time >= Tuning.STUN_TIME:
		state = State.NORMAL


# --- Medição, perigos, empurrão da janela e morte -----------------------------

## Passos no ritmo de Tuning.STEPS_PER_SECOND enquanto anda no chão.
func _step_sounds(delta: float) -> void:
	if not is_on_floor() or absf(velocity.x) <= 10.0:
		_step_phase = 0.0
		return
	var before := int(_step_phase)
	_step_phase += delta * Tuning.STEPS_PER_SECOND
	if int(_step_phase) != before:
		Audio.play("sfx_step", 0.08, Tuning.STEP_VOLUME_DB)


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


## Congela e começa a animação de morte. Quem escuta o sinal `died` reinicia a fase.
func die(cause: String) -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	_state_time = 0.0
	died.emit(cause)


# --- Desenho -------------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not _draw_art():
		_draw_placeholder()
	if state == State.STUN and not dead:
		_draw_stars()


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
	if dead:
		return "bicudinho_dead"
	match state:
		State.PREPARE:
			return "bicudinho_prepare"
		State.DASH:
			return "bicudinho_dash"
		State.STUN:
			return "bicudinho_stun"
	if is_on_floor():
		if absf(velocity.x) > 10.0:
			return "bicudinho_walk"
		return "bicudinho_idle"
	if gliding:
		return "bicudinho_glide"
	return "bicudinho_jump" if velocity.y < 0.0 else "bicudinho_fall"


## Qual arte usar quando a do estado ainda não existe, em ordem de preferência.
func _fallbacks(art_name: String) -> Array[String]:
	match art_name:
		"bicudinho_idle":
			return ["bicudinho_walk"]
		"bicudinho_glide":
			return ["bicudinho_prepare", "bicudinho_fall", "bicudinho_jump"]
		"bicudinho_prepare":
			return ["bicudinho_glide", "bicudinho_fall", "bicudinho_jump"]
		"bicudinho_dash":
			return ["bicudinho_prepare", "bicudinho_fall", "bicudinho_jump"]
		"bicudinho_stun":
			return ["bicudinho_fall", "bicudinho_jump"]
		"bicudinho_fall":
			return ["bicudinho_jump"]
		"bicudinho_jump":
			return ["bicudinho_walk"]
	return []


func _loop_fps(art_name: String) -> float:
	match art_name:
		"bicudinho_walk":
			return Tuning.WALK_FPS
		"bicudinho_idle":
			return Tuning.IDLE_FPS
		"bicudinho_fall":
			return Tuning.FALL_FPS
		"bicudinho_prepare":
			return Tuning.PREPARE_FPS
		"bicudinho_dash":
			return Tuning.DASH_FPS
	return Tuning.GLIDE_FPS  # planar: bater de asas


## Andar, parado, queda, planar, preparar e disparar repetem; o pulinho e a morte
## tocam uma vez e ficam no último quadro. Na disparada o sprite gira para apontar
## a direção. Devolve false se não há arte nenhuma (aí vai o placeholder).
func _draw_art() -> bool:
	var art_name := _art_name()
	var used := art_name
	var frames := _get_frames(art_name)
	if frames.is_empty():
		if dead:
			return false  # sem arte da morte: o placeholder desenha o bicudinho deitado
		for alt: String in _fallbacks(art_name):
			frames = _get_frames(alt)
			if not frames.is_empty():
				used = alt
				break
	if frames.is_empty():
		return false

	var idx := 0
	if art_name == "bicudinho_dead":
		idx = mini(int(_state_time * Tuning.DEAD_FPS), frames.size() - 1)
	elif art_name == "bicudinho_idle" and used != art_name:
		idx = 0  # parado sem arte própria: primeiro quadro do andar
	elif used == "bicudinho_jump":
		if art_name == "bicudinho_jump":
			idx = mini(int(_air_time * Tuning.JUMP_FPS), frames.size() - 1)
		else:
			idx = frames.size() - 1
	elif used == "bicudinho_walk" and art_name != "bicudinho_walk":
		idx = 0
	else:
		# preparar e disparar começam do primeiro quadro; o resto usa o tempo geral
		var t_anim := _state_time if (state == State.PREPARE or state == State.DASH) else anim_time
		idx = int(t_anim * _loop_fps(used)) % frames.size()

	var t: Texture2D = frames[idx]
	var size := t.get_size()
	# na disparada, gira em torno do meio do corpo
	var pivot := Vector2.ZERO
	var angle := 0.0
	if state == State.DASH and not dead:
		pivot = Vector2(0, -8)
		angle = atan2(_dash_dir.y, absf(_dash_dir.x)) * facing
	draw_set_transform(pivot + Vector2(0, Tuning.SPRITE_Y_ADJUST), angle, Vector2(facing, 1))
	draw_texture(t, Vector2(-size.x / 2.0, -size.y) - pivot)  # centro-inferior nos pés
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _draw_placeholder() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	if dead:
		# deitado, escurecido
		draw_rect(Rect2(-7, -5, 14, 5), Color("6b4a2a"))
		draw_rect(Rect2(-5, -7, 9, 2), Color("ead9a6"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var body := Color("b5833c")
	match state:
		State.PREPARE:
			body = body.lightened(0.35)
		State.DASH:
			body = Color("f2c14e")
		State.STUN:
			body = Color("8a8ad0")
	var bob := 0.0
	if state == State.NORMAL and is_on_floor() and absf(velocity.x) > 10.0:
		bob = -absf(sin(anim_time * 16.0)) * 2.0  # andar em saltinhos
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1))
	draw_rect(Rect2(-6, -14, 12, 14), body)               # corpo
	draw_rect(Rect2(-5, -6, 9, 5), Color("ead9a6"))      # barriga
	draw_rect(Rect2(2, -12, 2, 2), Color.BLACK)          # olho
	draw_rect(Rect2(6, -11, 4, 2), Color("3a2a1a"))      # bico
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Estrelinhas girando em cima da cabeça enquanto está atordoado.
func _draw_stars() -> void:
	var a := anim_time * 8.0
	for i in 3:
		var ang := a + i * TAU / 3.0
		draw_rect(Rect2(cos(ang) * 6.0 - 1.0, -20.0 + sin(ang) * 2.0, 2.0, 2.0), Color("ffe94d"))
