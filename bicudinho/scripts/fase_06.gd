extends LevelBase
## Fase 6, Notas. O bloco de notas é o elevador, e a dica de como usá-lo está nele mesmo.
##
## A janela é fixa e mostra as colunas 10 a 37 e as linhas 3 a 19. O chão fica na linha 18.
## O graveto está numa beirada 9 tiles acima do chão (colunas 29 a 37): pulando não dá.
## Só o comecinho (colunas 0 a 12) é chão; o resto é rio: cair do elevador é perigo.
## O dica.txt começa com o topo dentro da janela, perto do chão, mas o fim do texto fica
## para fora da tela, embaixo. Para ler tudo é preciso arrastar a janela para cima, e isso
## tira a plataforma do lugar: ler a dica fecha o caminho (por um tempo).
## O elevador: em cima do título, pule; no ar, arraste a janela para baixo dele e solte antes
## de ele pousar. Enquanto é arrastada ela não é chão, então ele cai: é em passos curtos.


func _setup_level() -> void:
	window_rect = Rect2(160, 48, 448, 272)
	bird_start = Vector2(184, 288)
	exit_feet = Vector2(560, 144)           # o graveto, na beirada alta
	note_text = "Quer chegar lá no alto?\nLeia até o fim...\n\n\n\nPule e, no ar, arraste esta\njanela para baixo de você.\nSolte antes de pousar.\nRepita até chegar!"
	note_pos = Vector2(224, 264)            # o topo é um degrau; o fim do texto fica fora da tela
	note_size = Vector2(176, 112)
	level_name = "Fase 6: Notas"
	loose_doc = "comida"                     # texto solto no desktop (vai para a pasta "trabalho")
	next_level = "res://scenes/level_07.tscn"


func _paint_map(g: Array) -> void:
	paint(g, 0, 18, 12, 19, "#")    # chão de partida
	paint(g, 13, 18, 39, 19, "~")   # rio: cair do elevador agora é perigo
	paint(g, 29, 9, 39, 10, "#")    # beirada alta do graveto (9 tiles acima do chão)
