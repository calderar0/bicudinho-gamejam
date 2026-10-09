extends CanvasLayer
## Botão de tamanho de tela no canto da barra de tarefas (e a tecla F11).
##   Windows (.exe): cada clique passa por 1x, 2x, 3x... e tela cheia; a escolha fica salva.
##   Navegador: o navegador manda no tamanho da janela, então o botão só liga e desliga
##   a tela cheia.
##   Rodando dentro do editor (jogo embutido): não faz nada, a janela embutida só aceita
##   o modo janela. Para testar o botão, exporte ou desligue "Embed Game on Next Play".
## É um autoload chamado "ScreenMode". Código escrito com ajuda de IA (AI-generated).

const SETTINGS_PATH := "user://screen.cfg"
const BTN := Rect2(620, 342, 16, 16)    # mude aqui para mover o botão
const DECOR := 40                        # folga para a barra de título do Windows
const MAX_SCALE := 4
const COLOR_IDLE := Color("3a4596")
const COLOR_HOVER := Color("4a55a8")
const ICON_IDLE := Color("f2f1ed")
const ICON_HOVER := Color("65dcd6")

var _web := OS.has_feature("web")
var _embedded := Engine.is_embedded_in_editor()   # jogo rodando dentro do editor: só modo janela
var _scale := 2              # 1, 2, 3... = janela; 0 = tela cheia
var _last_windowed := 2
var _hover := false
var _armed := false          # apertou em cima do botão (o clique vale ao soltar)
var _canvas: Node2D


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_button)
	add_child(_canvas)
	_detect()
	if not _web and not _embedded:
		_load()


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F11 and not _web:
		_toggle_full()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_hover = BTN.has_point(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_armed = BTN.has_point(event.position)
			if _armed:
				get_viewport().set_input_as_handled()
		elif _armed:
			_armed = false
			get_viewport().set_input_as_handled()
			if BTN.has_point(event.position):
				_next()  # no navegador a tela cheia só vale dentro de um clique: soltar conta


# --- Escolha do tamanho ----------------------------------------------------------

## Descobre o tamanho atual da janela (a do projeto abre em 2x).
func _detect() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		_scale = 0
	else:
		_scale = clampi(roundi(float(get_window().size.x) / Tuning.SCREEN_W), 1, MAX_SCALE)
		_last_windowed = _scale


## Tamanhos que cabem no monitor, mais a tela cheia (0).
func _options() -> Array[int]:
	var opts: Array[int] = []
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	for s in range(1, MAX_SCALE + 1):
		if Tuning.SCREEN_W * s <= area.size.x and Tuning.SCREEN_H * s + DECOR <= area.size.y:
			opts.append(s)
	opts.append(0)
	return opts


func _next() -> void:
	if _embedded:
		return  # a janela embutida do editor não troca de tamanho nem vai à tela cheia
	if _web:
		_toggle_full()
		return
	var opts := _options()
	var i := opts.find(_scale)
	_scale = opts[(i + 1) % opts.size()]
	_apply()
	_save()


func _toggle_full() -> void:
	if _embedded:
		return
	if _web:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if _scale == 0:
		_scale = _last_windowed
	else:
		_last_windowed = _scale
		_scale = 0
	_apply()
	_save()


func _apply() -> void:
	if _scale == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	_last_windowed = _scale
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame  # deixa o Windows sair da tela cheia antes de trocar o tamanho
	var win := get_window()
	var sz := Vector2i(Tuning.SCREEN_W, Tuning.SCREEN_H) * _scale
	win.size = sz
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	win.position = area.position + (area.size - sz) / 2


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("screen", "scale", _scale)
	cfg.save(SETTINGS_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var saved := int(cfg.get_value("screen", "scale", _scale))
	if saved < 0 or saved > MAX_SCALE or saved == _scale:
		return
	if saved != 0 and not _options().has(saved):
		return  # o monitor de hoje não comporta esse tamanho
	_scale = saved
	_apply()


# --- Desenho do botão ------------------------------------------------------------

func _draw_button() -> void:
	var r := BTN
	_canvas.draw_rect(r, COLOR_HOVER if _hover else COLOR_IDLE)
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.35))
	_canvas.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color(0, 0, 0, 0.5))
	var c := ICON_HOVER if _hover else ICON_IDLE
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	# quatro cantinhos: apontam para fora (entrar na tela cheia) ou para dentro (sair)
	var inset := 5.0 if full else 3.0
	var x0 := r.position.x + inset
	var y0 := r.position.y + inset
	var x1 := r.end.x - inset - 1.0
	var y1 := r.end.y - inset - 1.0
	var n := 3.0
	_canvas.draw_rect(Rect2(x0, y0, n, 1), c)
	_canvas.draw_rect(Rect2(x0, y0, 1, n), c)
	_canvas.draw_rect(Rect2(x1 - n + 1, y0, n, 1), c)
	_canvas.draw_rect(Rect2(x1, y0, 1, n), c)
	_canvas.draw_rect(Rect2(x0, y1, n, 1), c)
	_canvas.draw_rect(Rect2(x0, y1 - n + 1, 1, n), c)
	_canvas.draw_rect(Rect2(x1 - n + 1, y1, n, 1), c)
	_canvas.draw_rect(Rect2(x1, y1 - n + 1, 1, n), c)
