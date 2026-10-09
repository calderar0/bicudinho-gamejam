class_name AdWindow
extends MiniWindow
## Pop-up de propaganda ("VOCÊ GANHOU!"). Abre sozinho, atrapalha a visão e, como toda
## mini-janela, o topo é plataforma. Fecha sozinho depois de `life` segundos (ou no X).
## Quem abre é a fase (veja fase_09.gd), que reaproveita as janelas fechadas.

const FLASH := [Color("ffe14d"), Color("ff5aa5")]

var life := 0.0   # segundos até fechar sozinho
var _t := 0.0


func show_ad(pos: Vector2, seconds: float, headline: String) -> void:
	position = pos
	life = seconds
	text = headline
	_t = 0.0
	open()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	life -= delta
	if life <= 0.0 and not is_dragging():
		close()
	queue_redraw()  # o texto pisca


func _draw() -> void:
	var saved := text
	text = ""  # a moldura desenha sem texto; o texto do anúncio vem grande e piscando
	super._draw()
	text = saved
	var c: Color = FLASH[int(_t * 4.0) % 2]
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(3, TITLE_H + 3, size.x - 6, size.y - 6), Color("2f3a8f"))
	draw_string(font, Vector2(0, TITLE_H + size.y / 2.0 + 2), text, HORIZONTAL_ALIGNMENT_CENTER,
		size.x, 12, c)
	# a barrinha de tempo: quanto falta para o anúncio sumir sozinho
	draw_rect(Rect2(3, TITLE_H + size.y - 5, (size.x - 6) * clampf(life / 7.0, 0.0, 1.0), 2), c)
