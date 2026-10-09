extends LevelBase
## Fase 1, Brejo. Ensina andar, pular, a disparada e o vidro. Janela fixa.
##
## Ritmo (colunas do mapa; a janela mostra as colunas 2 a 37 e as linhas 3 a 19):
##   2-8    chão plano: andar
##   9-12   degrau de 2 tiles: pular
##   13-16  poça de 4 tiles: primeiro risco, pulo simples
##   17-19  chão seguro (respiro antes do desafio), com um vidro de 2 tiles na coluna 18:
##          andando, só bloqueia; dá para pular por cima ou estilhaçar na disparada
##          (quebra, atordoa e custa uma pena)
##   20-29  poça de 10 tiles, e o outro lado é 2 tiles mais alto. Planar ganha
##          distância mas perde altura, então só passa com a disparada.
##   30-32  pouso elevado (2 tiles)
##   33-37  barranco de mais 3 tiles com o graveto, colado no vidro da direita.
##          Quem dispara forte rumo a ela bate no vidro, fica atordoado e cai
##          no barranco: a lição do vidro acontece sem castigo.


func _setup_level() -> void:
	window_rect = Rect2(32, 48, 576, 272)  # janela fixa
	level_name = "Fase 1: Brejo"
	loose_doc = "bicudinho"                     # texto solto no desktop (vai para a pasta "trabalho")
	bird_start = Vector2(72, 288)          # pés sobre o chão (linha 18 do mapa)
	exit_feet = Vector2(576, 208)          # o graveto fica em cima do barranco (topo em y=208)
	next_level = "res://scenes/level_02.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 39, 19, "#")    # chão
	paint(g, 9, 16, 12, 17, "#")    # degrau de 2 tiles
	paint(g, 13, 18, 16, 19, "~")   # poça pequena (4)
	paint(g, 20, 18, 29, 19, "~")   # poça grande (10): precisa da disparada
	paint(g, 30, 16, 32, 17, "#")   # pouso elevado (2 tiles): planar não alcança
	paint(g, 33, 13, 39, 17, "#")   # barranco final (mais 3 tiles)
	paint(g, 18, 16, 18, 16, "|")   # vidro (1x2 tiles, marca a célula de cima)
