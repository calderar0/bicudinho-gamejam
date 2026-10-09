extends Node2D
## Tela de entrada do jogo: o login do "computador" do Quito. Fundo com o papel de parede,
## foto de perfil (art/ui/menu_bg.png, inteira), o usuário "Quito" e o campo de senha.
## A senha é fixa (PASSWORD, sem diferenciar maiúsculas). Certa: entra no desktop principal.
## Errada: o campo treme. "Esqueceu a senha?" mostra uma dica e, no segundo clique, a senha.
## O botão do canto de baixo desliga o jogo.

const WALLPAPER := preload("res://art/ui/wallpaper.png")
const AVATAR := preload("res://art/ui/menu_bg.png")
const TEX_ICONS := preload("res://art/ui/startmenu_icons.png")   # o 1º ícone é o de desligar
const DESKTOP_SCENE := "res://scenes/desktop.tscn"
const PASSWORD := "bicudinha"
const USER := "Quito"

const PHOTO := Rect2(256, 64, 128, 128)          # a foto de perfil (64x64 ampliada 2x)
const FIELD := Rect2(236, 232, 150, 16)          # campo de senha
const GO := Rect2(390, 231, 18, 18)              # botão de seta (entrar)
const POWER := Rect2(8, 336, 16, 16)             # botão de desligar: o ícone quadrado do menu Iniciar
const FORGOT := Rect2(270, 274, 100, 12)         # link "Esqueceu a senha?"
const MAX_LEN := 20
const INK := Color("f2f1ed")
const ACCENT := Color("3a7bc8")
const HOVER := Color("65dcd6")

var _typed := ""
var _error := ""
var _shake := 0.0
var _blink := 0.0
var _entering := false
var _hover_go := false
var _hover_power := false
var _hover_forgot := false
var _help := 0   # 0 nada, 1 dica, 2 senha à mostra


func _ready() -> void:
	Audio.resume_music()


func _process(delta: float) -> void:
	_blink += delta
	_shake = maxf(_shake - delta, 0.0)
	var m := get_global_mouse_position()
	var hg := GO.has_point(m)
	var hp := POWER.has_point(m)
	var hf := FORGOT.has_point(m) and _help < 2
	if (hg and not _hover_go) or (hp and not _hover_power) or (hf and not _hover_forgot):
		Audio.play("sfx_ui_hover", 0.05, -4.0)
	_hover_go = hg
	_hover_power = hp
	_hover_forgot = hf
	var hand := hg or hp or hf
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hand else
		(Input.CURSOR_IBEAM if FIELD.has_point(m) else Input.CURSOR_ARROW))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _entering:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if GO.has_point(m):
			_submit()
		elif FORGOT.has_point(m) and _help < 2:
			Audio.play("sfx_ui_click", 0.05, -6.0)
			_help += 1
		elif POWER.has_point(m):
			Audio.play("sfx_ui_click")
			if not OS.has_feature("web"):
				get_tree().quit()
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_submit()
			KEY_BACKSPACE:
				_typed = _typed.substr(0, maxi(_typed.length() - 1, 0))
			KEY_ESCAPE:
				_typed = ""
			_:
				if event.unicode >= 32 and _typed.length() < MAX_LEN:
					_typed += char(event.unicode)
					_error = ""
		_blink = 0.0
		get_viewport().set_input_as_handled()


func _submit() -> void:
	Audio.play("sfx_ui_click")
	if _typed.strip_edges().to_lower() == PASSWORD:
		_entering = true
		_error = ""
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		await get_tree().create_timer(0.7).timeout
		get_tree().change_scene_to_file(DESKTOP_SCENE)
	else:
		Audio.play("sfx_window_limit")
		_error = "Senha incorreta."
		_typed = ""
		_shake = 0.35


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_texture_rect(WALLPAPER, Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H), false)
	draw_rect(Rect2(0, 0, Tuning.SCREEN_W, Tuning.SCREEN_H), Color(0.05, 0.15, 0.35, 0.35))  # tom azulado

	# canto de cima: o idioma, de enfeite
	draw_rect(Rect2(8, 8, 22, 14), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(8, 8, 22, 14), Color(1, 1, 1, 0.5), false, 1.0)
	draw_string(font, Vector2(8, 18), "PT", HORIZONTAL_ALIGNMENT_CENTER, 22, 8, INK)

	# foto de perfil com moldura clara
	draw_rect(PHOTO.grow(6), Color(1, 1, 1, 0.25))
	draw_rect(PHOTO.grow(6), Color(1, 1, 1, 0.7), false, 1.0)
	draw_rect(PHOTO.grow(2), Color(0.1, 0.2, 0.35))
	draw_texture_rect(AVATAR, PHOTO, false)

	_shadow_text(font, USER, Vector2(0, 220), 16, INK)

	if _entering:
		_shadow_text(font, "Bem-vindo!", Vector2(0, 246), 12, INK)
		return

	# campo de senha (treme quando erra)
	var f := FIELD
	if _shake > 0.0:
		f.position.x += sin(_shake * 60.0) * 4.0
	draw_rect(f.grow(1), Color(0.1, 0.2, 0.35))
	draw_rect(f, Color.WHITE)
	if _typed == "":
		draw_string(font, f.position + Vector2(4, 12), "Senha", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("8a8d99"))
	else:
		draw_string(font, f.position + Vector2(4, 12), "•".repeat(_typed.length()), HORIZONTAL_ALIGNMENT_LEFT,
			f.size.x - 8, 8, Color("2b2b3a"))
	if fmod(_blink, 1.0) < 0.5:   # cursor de texto piscando
		var cx := f.position.x + 4 + font.get_string_size("•".repeat(_typed.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_rect(Rect2(cx, f.position.y + 3, 1, 10), Color("2b2b3a"))

	# botão de entrar: círculo azul com seta
	var c := GO.get_center()
	draw_circle(c, 9.0, Color.WHITE)
	draw_circle(c, 8.0, HOVER if _hover_go else ACCENT)
	draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), Color.WHITE, 2.0)
	draw_line(c + Vector2(1, -3), c + Vector2(4, 0), Color.WHITE, 2.0)
	draw_line(c + Vector2(1, 3), c + Vector2(4, 0), Color.WHITE, 2.0)

	if _error != "":
		_shadow_text(font, _error, Vector2(0, 264), 8, Color("ffd2c8"))
	# ajuda: link, depois a dica, depois a senha
	var link := "Esqueceu a senha?" if _help == 0 else "Mostrar a senha"
	if _help < 2:
		var lc := HOVER if _hover_forgot else INK
		_shadow_text(font, link, Vector2(0, FORGOT.position.y + 10), 8, lc)
		var lw := font.get_string_size(link, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_rect(Rect2((Tuning.SCREEN_W - lw) / 2.0, FORGOT.position.y + 12, lw, 1), lc)  # sublinhado
	if _help >= 1:
		_shadow_text(font, "Dica: é quem ele procura no fim da viagem.", Vector2(0, 300), 8, INK)
	if _help >= 2:
		_shadow_text(font, "A senha é: " + PASSWORD, Vector2(0, 314), 10, HOVER)

	# rodapé: o nome do jogo e o botão de desligar
	_shadow_text(font, "Quito  ·  GameRex 2026", Vector2(0, 342), 10, INK)
	# desligar: só o ícone quadrado (o mesmo do menu Iniciar), com contorno ciano no hover
	draw_texture_rect_region(TEX_ICONS, POWER, Rect2(0, 0, 16, 16))
	if _hover_power:
		draw_rect(POWER.grow(1), HOVER, false, 1.0)


func _shadow_text(font: Font, s: String, at: Vector2, size: int, c: Color) -> void:
	draw_string(font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_CENTER, Tuning.SCREEN_W, size, Color(0, 0, 0, 0.55))
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_CENTER, Tuning.SCREEN_W, size, c)
