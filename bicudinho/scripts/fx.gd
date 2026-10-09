extends Node2D
## Efeitos visuais ("game feel"): partículas (poeira, cacos de vidro, penas), tremor de tela,
## flash branco e pausa de impacto. É um autoload chamado "Fx": qualquer script chama
## Fx.glass_hit(...), Fx.death(...) e assim por diante. Os números ficam no tuning.gd.
## Código escrito com ajuda de IA (AI-generated).

const MAX_PARTS := 200
const DUST_COLOR := Color("e9dcc0")
const DASH_COLOR := Color("dff4ff")
const SHARD_COLORS: Array[Color] = [Color(0.78, 0.92, 1.0), Color(1, 1, 1), Color(0.55, 0.75, 0.95)]
const FEATHER_COLORS: Array[Color] = [Color("b5833c"), Color("ead9a6"), Color("6b4a2a")]
const SPARK_COLORS: Array[Color] = [Color("ffe066"), Color("fff6c8"), Color("9be36b"), Color("f2b84b")]


class Part:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 1.0
	var size := 1.0
	var color := Color.WHITE
	var gravity := 0.0
	var drag := 0.0


var _parts: Array[Part] = []
var _rng := RandomNumberGenerator.new()
var _shake_left := 0.0
var _shake_total := 1.0
var _shake_amp := 0.0
var _shaking := false
var _flash := 0.0
var _was_active := false


func _ready() -> void:
	z_index = 150  # acima do jogo, abaixo do menu Iniciar (200)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	# o tremor mostra uma faixa fina de fora da tela: que seja preta, não cinza
	RenderingServer.set_default_clear_color(Color.BLACK)


## Limpa tudo (o bicudinho chama ao nascer, então reiniciar a fase não deixa nada para trás).
func clear() -> void:
	_parts.clear()
	_flash = 0.0
	_shake_left = 0.0
	_shaking = false
	Engine.time_scale = 1.0
	get_viewport().canvas_transform = Transform2D.IDENTITY
	queue_redraw()


# --- Efeitos prontos -----------------------------------------------------------

## Poeira dos dois lados dos pés ao pousar. strength vai de 0 (leve) a 1 (queda forte).
func dust_land(pos: Vector2, strength: float) -> void:
	var n := 4 + roundi(6.0 * strength)
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var vel := Vector2(side * _r(25.0, 70.0) * (0.6 + strength), -_r(4.0, 26.0))
		_spawn(pos + Vector2(side * _r(1.0, 5.0), -1.0), vel, _r(0.25, 0.45),
			2.0 if _rng.randf() < 0.5 else 1.0, DUST_COLOR, 140.0, 5.0)


## Um sopro pequeno de poeira ao pular.
func dust_jump(pos: Vector2) -> void:
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		_spawn(pos + Vector2(side * _r(1.0, 4.0), -1.0), Vector2(side * _r(15.0, 45.0), -_r(2.0, 14.0)),
			_r(0.18, 0.32), 1.0, DUST_COLOR, 100.0, 5.0)


## Rastro de vento no começo da disparada (dir = direção da disparada).
func dash_puff(pos: Vector2, dir: Vector2) -> void:
	for i in 7:
		var ang := (-dir).angle() + _r(-0.7, 0.7)
		_spawn(pos, Vector2.from_angle(ang) * _r(30.0, 90.0), _r(0.15, 0.3),
			2.0 if _rng.randf() < 0.4 else 1.0, DASH_COLOR, 0.0, 6.0)


## Bateu no vidro: cacos, penas, tremor, pausa de impacto e um flash branco.
func glass_hit(contact: Vector2, bird_pos: Vector2, dir: Vector2) -> void:
	var base := (-dir).angle()
	for i in 18:
		var ang := base + _r(-1.7, 1.7)
		_spawn(contact, Vector2.from_angle(ang) * _r(40.0, 150.0), _r(0.5, 0.9),
			2.0 if _rng.randf() < 0.4 else 1.0, SHARD_COLORS[_rng.randi() % SHARD_COLORS.size()], 320.0, 0.6)
	for i in 6:
		_spawn(bird_pos, Vector2(_r(-50.0, 50.0), -_r(20.0, 70.0)), _r(0.7, 1.1), 2.0,
			FEATHER_COLORS[_rng.randi() % FEATHER_COLORS.size()], 60.0, 1.6)
	shake(Tuning.FX_SHAKE_GLASS.x, Tuning.FX_SHAKE_GLASS.y)
	flash(Tuning.FX_FLASH_ALPHA)
	hitstop(Tuning.FX_HITSTOP)


## Morte: explosão de penas e tremor mais forte.
func death(pos: Vector2) -> void:
	var center := pos + Vector2(0, -7)
	for i in 20:
		var ang := _r(0.0, TAU)
		_spawn(center, Vector2.from_angle(ang) * _r(30.0, 120.0) + Vector2(0, -30), _r(0.6, 1.0),
			2.0 if _rng.randf() < 0.5 else 1.0, FEATHER_COLORS[_rng.randi() % FEATHER_COLORS.size()], 260.0, 0.8)
	shake(Tuning.FX_SHAKE_DEATH.x, Tuning.FX_SHAKE_DEATH.y)


## Pegou o graveto: pausa curtinha, flash leve, tremidinho e uma chuva de faíscas.
func twig_get(pos: Vector2) -> void:
	sparkle(pos, 28, 1.0)
	flash(0.25)
	shake(2.0, 0.18)
	hitstop(0.07)


## Faíscas douradas e verdes saindo de pos (n faíscas, força de 0 a 1).
func sparkle(pos: Vector2, n: int, strength: float) -> void:
	for i in n:
		var ang := _r(0.0, TAU)
		var spd := _r(40.0, 140.0) * strength
		_spawn(pos, Vector2.from_angle(ang) * spd + Vector2(0, -40.0 * strength), _r(0.5, 0.9),
			2.0 if _rng.randf() < 0.4 else 1.0, SPARK_COLORS[_rng.randi() % SPARK_COLORS.size()], 120.0, 1.2)


# --- Peças soltas ----------------------------------------------------------------

## Treme a tela: amplitude em px, duração em s. Some aos poucos.
func shake(amp: float, dur: float) -> void:
	var left_amp := _shake_amp * (_shake_left / _shake_total) if _shake_left > 0.0 else 0.0
	if amp < left_amp:
		return  # já existe um tremor mais forte rolando
	_shake_amp = amp
	_shake_total = maxf(dur, 0.01)
	_shake_left = _shake_total


func flash(alpha: float) -> void:
	_flash = maxf(_flash, alpha)


## Congela o jogo por um instante (dá peso à batida). Usa tempo real, não o do jogo.
func hitstop(dur: float) -> void:
	if dur <= 0.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0


func _r(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func _spawn(pos: Vector2, vel: Vector2, life: float, size: float, color: Color,
		gravity: float, drag: float) -> void:
	if _parts.size() >= MAX_PARTS:
		return
	var p := Part.new()
	p.pos = pos
	p.vel = vel
	p.life = life
	p.max_life = life
	p.size = size
	p.color = color
	p.gravity = gravity
	p.drag = drag
	_parts.append(p)


# --- Atualização e desenho -------------------------------------------------------

func _process(delta: float) -> void:
	for i in range(_parts.size() - 1, -1, -1):
		var p := _parts[i]
		p.life -= delta
		if p.life <= 0.0:
			_parts.remove_at(i)
			continue
		p.vel.y += p.gravity * delta
		p.vel *= maxf(0.0, 1.0 - p.drag * delta)
		p.pos += p.vel * delta
	_flash = maxf(_flash - delta * 4.0, 0.0)

	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		var amp := _shake_amp * (_shake_left / _shake_total)
		var off := Vector2(_r(-1.0, 1.0), _r(-1.0, 1.0)) * amp
		get_viewport().canvas_transform = Transform2D(0.0, off.round())
		_shaking = true
	elif _shaking:
		get_viewport().canvas_transform = Transform2D.IDENTITY
		_shaking = false

	var active := not _parts.is_empty() or _flash > 0.0
	if active or _was_active:
		queue_redraw()
	_was_active = active


func _draw() -> void:
	for p in _parts:
		var c := p.color
		c.a *= clampf(p.life / (p.max_life * 0.5), 0.0, 1.0)  # some na segunda metade da vida
		var s := Vector2(p.size, p.size)
		draw_rect(Rect2((p.pos - s / 2.0).floor(), s), c)
	if _flash > 0.0:
		draw_rect(Rect2(-10, -10, Tuning.SCREEN_W + 20, Tuning.SCREEN_H + 20), Color(1, 1, 1, _flash))
