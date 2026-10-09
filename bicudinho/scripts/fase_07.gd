extends LevelBase
## Fase 7, Enquadra. A base da janela sobe e desce, e cada altura esconde ou mostra um perigo.
##
## A largura é fixa; a base vai de y = 320 (tudo à vista) até y = 240.
##   0-5    chão de partida (topo y = 288)
##   6-19   rio largo (14 tiles): o rio que só existe se você olhar. Com a base em 288 ou
##          mais acima, ele some e o vidro vira chão: dá para atravessar andando.
##   20-39  chão do outro lado. Nas colunas 23 a 30 tem lixo no chão e uma marquise de terra
##          logo acima (y 224 a 256). Com a base em 272, o lixo some e entre o vidro e a
##          marquise sobra 1 tile: o bicudinho cabe. Subir mais faz da marquise uma parede
##          (e esmaga quem estiver embaixo dela).
##   33-37  um buraco no chão (topo y = 304) com o graveto. Para alcançar, é preciso BAIXAR a
##          base de novo: o rio e o lixo voltam, mas já ficaram para trás.
## Enquanto o graveto está fora da janela, o ícone do brejo aparece embaixo dela: a pista.


func _setup_level() -> void:
	window_rect = Rect2(32, 48, 576, 272)
	level_name = "Fase 7: Enquadra"
	window_min = Vector2(576, 192)          # a base sobe até y = 240
	window_max = Vector2(576, 272)
	bird_start = Vector2(56, 288)
	exit_feet = Vector2(560, 304)           # o graveto, no fundo do buraco
	next_level = "res://scenes/level_08.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 5, 19, "#")     # chão de partida
	paint(g, 6, 18, 19, 19, "~")    # rio largo
	paint(g, 20, 18, 39, 19, "#")   # chão do outro lado
	paint(g, 23, 14, 30, 15, "#")   # marquise de terra (embaixo dela só cabe 1 tile)
	paint(g, 23, 17, 30, 17, "^")   # lixo no chão, embaixo da marquise
	paint(g, 33, 18, 37, 18, ".")   # buraco no chão: o fundo é a linha 19
