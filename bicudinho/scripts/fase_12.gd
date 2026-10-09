extends LevelBase
## Fase 12, a bicudinha. Os papéis se invertem: o bicudinho anda sozinho para a frente e dá
## meia-volta ao bater no vidro; o teclado não faz nada. Só o mouse, para proteger o caminho.
##
## A janela começa estreita (colunas 2 a 11): ele fica indo e voltando em segurança. O chão
## tem duas poças de 2 tiles (colunas 15-16 e 25-26), do tamanho exato de um ícone. As duas
## pastas ficam no desktop, em cima da janela. Estique a janela, largue uma pasta em cada poça
## (o topo dela fica no nível do chão) e deixe ele andar até a bicudinha.
## Dica de ritmo: estique quando ele estiver indo para a esquerda.


func _setup_level() -> void:
	window_rect = Rect2(32, 112, 160, 208)
	window_min = Vector2(160, 208)
	window_max = Vector2(576, 208)
	bird_start = Vector2(72, 288)
	exit_feet = Vector2(568, 288)
	goal = "female"                         # a fase da bicudinha: os dois felizes
	auto_walk = true
	icons_data = [
		{"type": "folder", "x": 288, "y": 32, "label": "ninho"},
		{"type": "folder", "x": 352, "y": 32, "label": "galhos"},
	]
	level_name = "Fase 12: A bicudinha"
	next_level = "res://scenes/creditos.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 39, 19, "#")    # chão
	paint(g, 15, 18, 16, 19, "~")   # poça (2 tiles = 1 ícone)
	paint(g, 25, 18, 26, 19, "~")   # poça (2 tiles = 1 ícone)
