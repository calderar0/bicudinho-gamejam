extends LevelBase
## Fase 11, Noite. O monitor está quase desligando: tudo escuro, e o mouse é a lanterna.
##
## A lanterna é pequena e o bicudinho só tem um brilho fraco: é preciso iluminar cada passo.
## O chão fica na linha 18 (topo y = 288). Da esquerda para a direita:
##   0-4    chão de partida
##   5-9    poça (5) com uma plataforma fina no meio, 2 tiles acima
##   10-12  chão com um monte de lixo na coluna 12: pule por cima
##   13-18  poça (6) com uma plataforma fina mais alta (4 tiles acima)
##   19-21  chão com um vidro na coluna 20 (invisível no escuro): andando só bloqueia,
##          na disparada quebra e custa uma pena. Dá para pular por cima.
##   22-27  poça (6) com uma plataforma fina e estreita na coluna 25 (4 tiles acima):
##          pulo + disparada
##   28-30  chão com lixo na coluna 29
##   31-33  poça (3)
##   34-39  degrau de 3 tiles com o graveto


func _setup_level() -> void:
	window_rect = Rect2(32, 48, 576, 272)
	level_name = "Fase 11: Noite"
	loose_doc = "diario"                     # texto solto no desktop (vai para a pasta "trabalho")
	bird_start = Vector2(56, 288)
	exit_feet = Vector2(568, 240)
	wallpaper_color = Color("1d2b25")
	wallpaper_tint = Color(0.22, 0.26, 0.42)   # noite
	sky_color = Color("1b2440")
	next_level = "res://scenes/level_12.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 39, 19, "#")    # chão
	paint(g, 5, 18, 9, 19, "~")     # poça (5)
	paint(g, 7, 16, 7, 16, "=")     # apoio no meio da poça
	paint(g, 12, 17, 12, 17, "^")   # lixo
	paint(g, 13, 18, 18, 19, "~")   # poça (6)
	paint(g, 15, 14, 16, 14, "=")   # apoio alto
	paint(g, 20, 16, 20, 16, "|")   # vidro (1x2), no escuro: pule por cima e pouse na coluna 21
	paint(g, 22, 18, 27, 19, "~")   # poça (6)
	paint(g, 25, 14, 25, 14, "=")   # apoio alto e estreito (4 tiles): pulo + disparada
	paint(g, 29, 17, 29, 17, "^")   # lixo
	paint(g, 31, 18, 33, 19, "~")   # poça (3)
	paint(g, 34, 15, 39, 17, "#")   # degrau final com o graveto


func _ready() -> void:
	super._ready()
	var dark := DarkOverlay.new()
	dark.bird = bird
	dark.mouse_radius = 52.0
	dark.bird_radius = 14.0
	add_child(dark)
	world_nodes.append(dark)
	_keep_menu_on_top()
