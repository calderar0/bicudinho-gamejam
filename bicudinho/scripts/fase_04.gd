extends LevelBase
## Fase 4, Corta. Ensina a encolher: subir a base da janela corta o rio para fora,
## e o vidro de baixo vira chão.
##
## A janela mostra as colunas 2 a 37 e as linhas 3 a 19. A largura é fixa; a altura vai de
## 272 até 128 (a base sobe até y = 176). O rio ocupa as linhas 15 a 19, de ponta a ponta.
##   1-5    plataforma de partida (topo y = 208), segura, em cima do rio
##   16-18  plataforma do meio (topo y = 176)
##   31-38  plataforma da saída (topo y = 128), com o graveto
## Sem cortar, os vãos são de 10 e 12 tiles com o rio embaixo, e no meio de cada um tem uma
## parede de vidro (colunas 11 e 24, de y = 64 a 160): o pulo bate nela, e a disparada
## quebra o vidro mas atordoa, e ele cai no rio.
## Subindo a base, o vidro vira chão e cada plataforma fica a um pulo simples dele
## (com a base no mínimo, a saída fica 3 tiles acima do chão de vidro). Embaixo das paredes de
## vidro sobra 1 tile acima do chão de vidro: ele passa andando.
## O risco: encolher pelo topo empurra o bicudinho para baixo, até o rio. A borda certa
## é a de baixo. O mínimo de altura deixa a saída e o graveto dentro da janela.


func _setup_level() -> void:
	window_rect = Rect2(32, 48, 576, 272)
	window_min = Vector2(576, 128)          # a base pode subir até y = 176
	window_max = Vector2(576, 272)
	bird_start = Vector2(56, 208)           # na plataforma de partida, nunca no rio
	exit_feet = Vector2(560, 128)           # o graveto, na plataforma alta da direita
	# sem dica.txt: o topo da mini-janela é plataforma e viraria ponte sobre os vãos
	level_name = "Fase 4: Corta"
	loose_doc = "nome"                     # texto solto no desktop (vai para a pasta "trabalho")
	next_level = "res://scenes/level_05.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 0, 15, 39, 20, "~")    # rio de ponta a ponta
	paint(g, 1, 13, 5, 14, "#")     # plataforma de partida
	paint(g, 16, 11, 18, 12, "#")   # plataforma do meio
	paint(g, 31, 8, 38, 9, "#")     # plataforma da saída
	for col in [11, 24]:            # paredes de vidro no meio dos vãos (3 placas de 1x2)
		for row in [4, 6, 8]:
			paint(g, col, row, col, row, "|")
