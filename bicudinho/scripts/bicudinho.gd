class_name Bicudinho
extends CharacterBody2D
## O bicudinho. A origem do nó fica nos pés. Colisão de 12x14 px.
## Passo 1: andar, pular com altura variável, coyote time e buffer de pulo.
## Passo 2: perigos do mapa, ser empurrado pela janela e ser esmagado.
## Passo 3: preparar voo (pausa com mira) e disparada; o vidro atordoa na disparada.
## Extra: planar segurando a ação de Tuning.GLIDE_ACTION enquanto cai.
## Efeitos (fx.gd): esmagar e esticar, poeira, fantasma da disparada, piscar ao perder pena.
## Usa a arte de res://art/ se existir; sem ela, desenha um placeholder.
##
## Arte: quadros em arquivos separados, <nome>_01.png, <nome>_02.png...
## (ou <nome>.png para animações de um quadro só).

signal died(cause: String)
signal glass_hit(pos: Vector2)
signal lives_changed(lives: int)

enum State { NORMAL, PREPARE, DASH, STUN }

var state: State = State.NORMAL
var has_dash := true          # uma disparada por pulo; volta ao tocar o chão
var facing := 1
var coyote := 0.0
var jump_buffer := 0.0
var anim_time := 0.0
var dead := false
var lives := Tuning.LIVES     # penas: cada batida no vidro tira uma
## Anda sozinho para a frente e vira ao bater numa parede; o teclado não faz nada (fase da
## bicudinha e créditos: o jogador só usa o mouse).
var auto_walk := false
## A base da janela subindo rápido lança o bicudinho para cima (trampolim).
var launch_enabled := false
var happy := false            # chegou ao objetivo: fica parado e feliz
var frozen := false           # chegou ao objetivo: para (feliz ou não)
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

# efeitos visuais
var _squash := Vector2.ONE      # esmagar e esticar (escala do desenho, a base fica nos pés)
var _vy_before := 0.0           # velocidade vertical antes de mover (para saber a força do pouso)
var _fx_was_floor := false
var _blink := 0.0               # tempo que ainda pisca depois de perder uma pena
var _ghost_timer := 0.0
var _ghosts: Array = []         # fantasmas da disparada: {pos, tex, pivot, angle, facing, age}
var _cur_tex: Texture2D = null  # o quadro desenhado agora (os fantasmas copiam dele)
var _cur_pivot := Vector2.ZERO
var _cur_angle := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3  # camada 1 (mundo) + camada 2 (vidro)
	_glide_left = Tuning.GLIDE_TIME
	Fx.clear()  # recomeçar a fase não herda partículas, tremor nem pausa de impacto


func box_rect() -> Rect2:
	return Rect2(
		global_position + Vector2(-Tuning.BIRD_BOX.x / 2.0, -Tuning.BIRD_BOX.y),
		Tuning.BIRD_BOX)


func _physics_process(delta: float) -> void:
	if dead:
		_state_time += delta  # só para animar a morte
		return
	anim_time += delta
	if frozen:
		return  # chegou e parou (só a animação roda)
	_vy_before = velocity.y
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
		_landing_fx()
	if Tuning.DEBUG_MEASURE:
		_measure()


# --- Estado NORMAL: andar, pular e planar -------------------------------------

func _normal(delta: float) -> void:
	# entrada horizontal
	var dir := Input.get_axis("move_left", "move_right")
	if auto_walk:
		dir = float(facing)
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
	var pressed := Input.is_action_just_pressed("jump") and not auto_walk
	if pressed:
		jump_buffer = Tuning.JUMP_BUFFER

	if jump_buffer > 0.0 and coyote > 0.0:
		# pulo
		velocity.y = Tuning.JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
		Audio.play("sfx_jump", 0.05)
		_squash = Tuning.FX_JUMP_STRETCH
		Fx.dust_jump(global_position)
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
			and Input.is_action_pressed(Tuning.GLIDE_ACTION) and not auto_walk
	if gliding:
		_glide_left -= delta
		if velocity.y > Tuning.GLIDE_FALL_SPEED:
			velocity.y = move_toward(velocity.y, Tuning.GLIDE_FALL_SPEED, Tuning.GLIDE_BRAKE * delta)
		else:
			velocity.y = minf(velocity.y + Tuning.GRAVITY * delta, Tuning.GLIDE_FALL_SPEED)
	else:
		velocity.y = minf(velocity.y + Tuning.GRAVITY * delta, Tuning.MAX_FALL_SPEED)

	move_and_slide()
	if auto_walk and is_on_wall() and get_wall_normal().x * facing < 0.0:
		facing = -facing  # andando sozinho: bateu na parede (ou no vidro), dá meia-volta
	# bateu de lado numa quina de terra no ar, empurrando contra ela: sobe nela
	if not is_on_floor() and is_on_wall() and dir * get_wall_normal().x < 0.0:
		_try_ledge_assist(dir)
	_step_sounds(delta)


# --- Estado PREPARE: a pausa em que ele mira ----------------------------------

func _start_prepare() -> void:
	state = State.PREPARE
	_state_time = 0.0
	gliding = false
	_clear_input_memory()  # o toque de pulo já foi gasto em preparar o voo
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
	Audio.play("sfx_dash", 0.05)
	_squash = Vector2.ONE
	_ghost_timer = 0.0  # o primeiro fantasma já nasce neste quadro
	Fx.dash_puff(global_position + Vector2(0, -7), aim)


func _dash(delta: float) -> void:
	_state_time += delta
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = Tuning.FX_GHOST_INTERVAL
		_spawn_ghost()
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
		_hit_glass(col.get_position(), hit as Node)
	elif absf(col.get_normal().x) > 0.7 and _try_ledge_assist(_dash_dir.x):
		pass  # subiu na quina: a disparada continua
	else:
		_end_dash(false)  # bateu em parede ou chão: só para


## Bateu de lado na terra perto do topo? Sobe na quina em vez de escorregar.
## Contra o vidro nunca funciona: o vidro tem a altura inteira da janela.
func _try_ledge_assist(dir_x: float) -> bool:
	if dir_x == 0.0:
		return false
	var side := Vector2(signf(dir_x) * 2.0, 0.0)
	for lift in range(1, int(Tuning.LEDGE_ASSIST) + 1):
		var up := Vector2(0.0, -lift)
		if test_move(global_transform, up):
			return false  # teto em cima: não cabe
		if not test_move(global_transform.translated(up), side):
			global_position += up
			velocity.y = minf(velocity.y, 0.0)
			return true
	return false


func _end_dash(natural: bool) -> void:
	state = State.NORMAL
	velocity = _dash_dir * Tuning.DASH_SPEED * Tuning.DASH_EXIT_SPEED_SCALE if natural else Vector2.ZERO


## Aplica a regra do vidro (Tuning.GLASS_RULE) quando a disparada bate nele.
## O vidro da fase (GlassPane) se estilhaça; a borda da janela ganha uma rachadura.
## Toda batida tira uma pena; sem penas, ele morre.
func _hit_glass(pos: Vector2, hit: Node) -> void:
	if hit.has_method("shatter"):
		hit.shatter()
	else:
		glass_hit.emit(pos)
	lives -= 1
	lives_changed.emit(lives)
	_blink = Tuning.FX_BLINK_TIME
	Fx.glass_hit(pos, global_position + Vector2(0, -7), _dash_dir)
	if lives <= 0:
		die("glass")
		return
	match Tuning.GLASS_RULE:
		Tuning.GlassRule.BLOCK:
			_end_dash(false)
		Tuning.GlassRule.STUN:
			state = State.STUN
			_state_time = 0.0
			_clear_input_memory()
			velocity = -_dash_dir * 60.0  # um pequeno tranco para trás
		Tuning.GlassRule.KILL:
			die("glass")


# --- Estado STUN: atordoado ----------------------------------------------------

## Atordoado: não lê nenhuma tecla (nada fica "na fila") e só cai e desliza até parar.
func _stun(delta: float) -> void:
	_state_time += delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	velocity.y = minf(velocity.y + Tuning.GRAVITY * delta, Tuning.MAX_FALL_SPEED)
	move_and_slide()
	if _state_time >= Tuning.STUN_TIME:
		_clear_input_memory()  # volta ao normal sem ação pronta (sem pulo automático)
		state = State.NORMAL


## Esquece o toque de pulo guardado (buffer) e o coyote time. Sem isso, um toque que
## sobrou de antes do stun virava um pulo sozinho assim que ele voltava ao chão.
func _clear_input_memory() -> void:
	jump_buffer = 0.0
	coyote = 0.0


# --- Efeitos visuais -------------------------------------------------------------

## Acabou de pousar depois de cair rápido: achata e levanta poeira.
func _landing_fx() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _fx_was_floor and state != State.DASH \
			and _vy_before >= Tuning.FX_LAND_MIN_SPEED:
		var k := clampf(_vy_before / Tuning.MAX_FALL_SPEED, 0.0, 1.0)
		var s := Tuning.FX_LAND_SQUASH_MAX * k
		_squash = Vector2(1.0 + s, 1.0 - s)
		Fx.dust_land(global_position, k)
	_fx_was_floor = on_floor


## Deixa uma cópia esmaecida do quadro atual para trás (o rastro da disparada).
func _spawn_ghost() -> void:
	if _cur_tex == null:
		return
	_ghosts.append({
		"pos": global_position, "tex": _cur_tex, "pivot": _cur_pivot,
		"angle": _cur_angle, "facing": facing, "age": 0.0})
	if _ghosts.size() > 16:
		_ghosts.remove_at(0)


func _draw_ghosts() -> void:
	for g: Dictionary in _ghosts:
		var tex: Texture2D = g["tex"]
		var c := Tuning.FX_GHOST_COLOR
		c.a = Tuning.FX_GHOST_ALPHA * (1.0 - float(g["age"]) / Tuning.FX_GHOST_LIFE)
		var at: Vector2 = (g["pos"] as Vector2) - global_position
		var pivot: Vector2 = g["pivot"]
		draw_set_transform(at + pivot + Vector2(0, Tuning.SPRITE_Y_ADJUST), g["angle"],
			Vector2(g["facing"], 1))
		draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()) - pivot, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	elif launch_enabled and state == State.NORMAL and dy <= -Tuning.LAUNCH_MIN_PUSH:
		velocity.y = minf(velocity.y, -Tuning.LAUNCH_SPEED)  # a base subiu rápido: trampolim
		Audio.play("sfx_jump", 0.05)
		_squash = Tuning.FX_JUMP_STRETCH


## Chegou ao objetivo (a bicudinha): para tudo e fica feliz. Chamado pela fase.
## Chegou ao objetivo: para. cheer = fica feliz (só na última fase, com a bicudinha).
func celebrate(cheer := true) -> void:
	frozen = true
	happy = cheer
	velocity = Vector2.ZERO
	gliding = false
	_state_time = 0.0


## Congela e começa a animação de morte. Quem escuta o sinal `died` reinicia a fase.
func die(cause: String) -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	_state_time = 0.0
	_squash = Vector2.ONE
	_blink = 0.0
	Audio.play("sfx_death")
	Fx.death(global_position)
	died.emit(cause)


# --- Desenho -------------------------------------------------------------------

func _process(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, Tuning.FX_SQUASH_RECOVER * delta))
	_blink = maxf(_blink - delta, 0.0)
	var blinking := _blink > 0.0 and int(_blink / Tuning.FX_BLINK_RATE) % 2 == 0
	modulate.a = 0.3 if blinking else 1.0
	for i in range(_ghosts.size() - 1, -1, -1):
		_ghosts[i]["age"] += delta
		if _ghosts[i]["age"] >= Tuning.FX_GHOST_LIFE:
			_ghosts.remove_at(i)
	queue_redraw()


func _draw() -> void:
	_draw_ghosts()
	if not _draw_art():
		_draw_placeholder()
	# estrelinhas desenhadas por código só quando a arte do stun não existe
	if state == State.STUN and not dead and _get_frames("bicudinho_stun").is_empty():
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
	if happy:
		return "bicudinho_happy"
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
		"bicudinho_happy":
			return ["bicudinho_idle", "bicudinho_walk"]
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
		"bicudinho_stun":
			return Tuning.STUN_FPS
		"bicudinho_happy":
			return Tuning.HAPPY_FPS
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
		# preparar, disparar e atordoado começam do primeiro quadro; o resto usa o tempo geral
		var from_start := state == State.PREPARE or state == State.DASH or state == State.STUN
		var t_anim := _state_time if from_start else anim_time
		idx = int(t_anim * _loop_fps(used)) % frames.size()

	var t: Texture2D = frames[idx]
	var size := t.get_size()
	# na disparada, gira em torno do meio do corpo
	var pivot := Vector2.ZERO
	var angle := 0.0
	if state == State.DASH and not dead:
		pivot = Vector2(0, -8)
		angle = atan2(_dash_dir.y, absf(_dash_dir.x)) * facing
	_cur_tex = t
	_cur_pivot = pivot
	_cur_angle = angle
	var sq := Vector2.ONE if state == State.DASH else _squash  # esmagar e esticar (base nos pés)
	draw_set_transform(pivot + Vector2(0, Tuning.SPRITE_Y_ADJUST), angle, Vector2(facing * sq.x, sq.y))
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
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing * _squash.x, _squash.y))
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
