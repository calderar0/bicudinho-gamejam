extends LevelBase
## Fase 5, Esconde. Ensina que a janela do jogo também cobre o desktop: tem uma pasta
## escondida atrás dela.
##
## A janela começa grande, mostrando as colunas 2 a 37 e as linhas 3 a 19, e cobre quase a
## tela toda (não sobra desktop à vista). A altura é fixa; a largura encolhe até 448 px.
##   0-12   chão de partida (linha 18)
##   13-26  rio de 14 tiles: impossível sem ajuda (como na fase 2)
##   27-39  barranco 6 tiles acima do chão, com o graveto
## A pasta está atrás da janela, em x = 48 (colunas 3 e 4), na altura do meio. Encolhendo pela
## borda esquerda ela vai aparecendo; com a borda em x >= 96 ela sai de trás por inteiro e vira
## um ícone comum. Aí é arrastar para dentro da janela, no meio do rio, e usar de degrau.


func _setup_level() -> void:
	window_rect = Rect2(32, 48, 576, 272)
	window_min = Vector2(448, 272)          # encolhe a largura até 448 (borda esquerda até x = 160)
	window_max = Vector2(576, 272)
	bird_start = Vector2(184, 288)          # longe da borda esquerda: encolher não empurra
	exit_feet = Vector2(552, 192)           # o graveto, em cima do barranco
	next_level = "res://scenes/level_06.tscn"
	icons_data = [
		{"type": "folder", "x": 48, "y": 208, "label": "galhos", "behind": true, "contents": [
			{"kind": "text", "name": "achou.txt", "text": "Achou a pasta escondida!\nArraste ela para o meio do rio."},
		]},
	]
	level_name = "Fase 5: Esconde"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 12, 19, "#")    # chão de partida
	paint(g, 13, 18, 26, 19, "~")   # rio (14 tiles)
	paint(g, 27, 12, 39, 19, "#")   # barranco da bicudinha (6 tiles)
	paint(g, 12, 17, 12, 17, "^")   # lixo na beira do rio
	paint(g, 27, 11, 28, 11, "^")   # lixo na beirada do barranco
